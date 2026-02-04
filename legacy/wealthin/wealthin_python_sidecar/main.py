"""
WealthIn Agentic Sidecar - Enhanced Python Backend
Handles: PDF extraction, Vision model calls, DPR generation, Financial calculations
"""
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uvicorn
import os
import base64
import json
import re
import pdfplumber
import tempfile
from datetime import datetime, timedelta
from reportlab.lib.pagesizes import letter, A4
from reportlab.pdfgen import canvas
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib import colors
from reportlab.lib.units import inch
from io import BytesIO

app = FastAPI(title="WealthIn Agentic Sidecar", version="2.0")

# CORS for Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================
# MODELS
# ============================================

class AgentToolCall(BaseModel):
    """Represents a parsed tool call from the LLM"""
    tool_name: str
    parameters: Dict[str, Any]
    confirmation_message: Optional[str] = None

class AgentRequest(BaseModel):
    """Request from Serverpod to execute an agent task"""
    user_message: str
    user_context: Optional[Dict[str, Any]] = None
    transactions: Optional[List[Dict[str, Any]]] = None
    available_tools: Optional[List[str]] = None

class AgentResponse(BaseModel):
    """Response containing either text or a tool call"""
    response_type: str  # 'text', 'tool_call', 'action_card'
    text_response: Optional[str] = None
    tool_call: Optional[AgentToolCall] = None
    action_card: Optional[Dict[str, Any]] = None

class TransactionExtractionRequest(BaseModel):
    """Request to extract transactions from a document"""
    document_base64: str
    mime_type: str  # 'application/pdf', 'image/png', etc.
    source: str  # 'pdf', 'vision', 'bank_statement'

class ExtractedTransaction(BaseModel):
    """A single extracted transaction"""
    description: str
    date: str
    time: Optional[str] = None
    type: str  # 'income' or 'expense'
    amount: float

class BankStatementInfo(BaseModel):
    """Metadata from bank statement"""
    bank_name: Optional[str] = None
    account_number: Optional[str] = None
    account_holder: Optional[str] = None
    statement_period: Optional[str] = None
    opening_balance: Optional[float] = None
    closing_balance: Optional[float] = None

class PDFExtractionResult(BaseModel):
    """Full result from PDF extraction"""
    success: bool
    transactions: List[Dict[str, Any]] = []
    bank_info: Optional[BankStatementInfo] = None
    raw_text: Optional[str] = None
    page_count: int = 0
    error: Optional[str] = None

class DocumentGenerationRequest(BaseModel):
    """Request to generate a document"""
    doc_type: str  # 'loan_application', 'project_report', 'invoice', 'receipt'
    title: str
    content: Dict[str, Any]
    user_info: Optional[Dict[str, Any]] = None

class DailyInsightRequest(BaseModel):
    """Request for AI-generated daily insight"""
    transactions: List[Dict[str, Any]]
    user_profile: Optional[Dict[str, Any]] = None
    
class DailyInsight(BaseModel):
    """AI-generated daily financial insight"""
    headline: str
    insight_text: str
    recommendation: str
    trend_indicator: str  # 'up', 'down', 'stable'
    category_highlight: Optional[str] = None
    amount_highlight: Optional[float] = None

class InvestmentCalculation(BaseModel):
    """Request for investment calculations"""
    calc_type: str  # 'sip', 'fd', 'emi', 'rd', 'roi'
    principal: float
    rate: float  # Annual rate in %
    duration_months: int
    monthly_investment: Optional[float] = None

class InvestmentResult(BaseModel):
    """Result of investment calculation"""
    calc_type: str
    principal: float
    total_value: float
    total_interest: float
    monthly_breakdown: Optional[List[Dict[str, float]]] = None

# ============================================
# TOOL DEFINITIONS (for Function Calling)
# ============================================

AGENT_TOOLS = [
    {
        "name": "upsert_budget",
        "description": "Create or update a budget limit for a spending category",
        "parameters": {
            "type": "object",
            "properties": {
                "category": {"type": "string", "description": "The category name (e.g., 'Food', 'Transport')"},
                "limit": {"type": "number", "description": "Monthly spending limit in INR"},
                "period": {"type": "string", "enum": ["monthly", "weekly"], "description": "Budget period"}
            },
            "required": ["category", "limit"]
        }
    },
    {
        "name": "create_savings_goal",
        "description": "Set a new financial savings target with optional deadline",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Goal name"},
                "target_amount": {"type": "number", "description": "Target amount in INR"},
                "deadline": {"type": "string", "description": "Target date (YYYY-MM-DD)"}
            },
            "required": ["name", "target_amount"]
        }
    },
    {
        "name": "add_debt",
        "description": "Track a new loan, EMI, or debt",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Debt name"},
                "principal": {"type": "number", "description": "Principal amount"},
                "interest_rate": {"type": "number", "description": "Annual interest rate %"},
                "emi": {"type": "number", "description": "Monthly EMI"},
                "tenure_months": {"type": "integer", "description": "Loan tenure in months"}
            },
            "required": ["name", "principal"]
        }
    },
    {
        "name": "schedule_payment",
        "description": "Set up a recurring payment reminder",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Payment name"},
                "amount": {"type": "number", "description": "Payment amount"},
                "frequency": {"type": "string", "enum": ["daily", "weekly", "monthly"], "description": "Payment frequency"},
                "next_due": {"type": "string", "description": "Next due date (YYYY-MM-DD)"}
            },
            "required": ["name", "amount", "frequency"]
        }
    },
    {
        "name": "analyze_investment",
        "description": "Calculate returns for an investment opportunity",
        "parameters": {
            "type": "object",
            "properties": {
                "investment_type": {"type": "string", "enum": ["sip", "fd", "rd", "emi"], "description": "Type of investment"},
                "principal": {"type": "number", "description": "Investment amount"},
                "rate": {"type": "number", "description": "Expected annual return %"},
                "duration_months": {"type": "integer", "description": "Investment duration in months"}
            },
            "required": ["investment_type", "principal", "rate", "duration_months"]
        }
    },
    {
        "name": "generate_cashflow_analysis",
        "description": "Generate a detailed cashflow analysis from transactions",
        "parameters": {
            "type": "object",
            "properties": {
                "period": {"type": "string", "enum": ["week", "month", "quarter", "year"], "description": "Analysis period"}
            },
            "required": ["period"]
        }
    }
]

# ============================================
# FINANCIAL CALCULATORS
# ============================================

def calculate_sip(monthly_investment: float, rate: float, months: int) -> Dict:
    """Calculate SIP returns"""
    monthly_rate = rate / 12 / 100
    total_invested = monthly_investment * months
    
    if monthly_rate == 0:
        future_value = total_invested
    else:
        future_value = monthly_investment * (((1 + monthly_rate) ** months - 1) / monthly_rate) * (1 + monthly_rate)
    
    return {
        "total_invested": round(total_invested, 2),
        "future_value": round(future_value, 2),
        "total_returns": round(future_value - total_invested, 2),
        "return_percentage": round(((future_value - total_invested) / total_invested) * 100, 2) if total_invested > 0 else 0
    }

def calculate_fd(principal: float, rate: float, months: int) -> Dict:
    """Calculate Fixed Deposit maturity"""
    years = months / 12
    # Quarterly compounding
    maturity_value = principal * ((1 + rate / 400) ** (4 * years))
    
    return {
        "principal": round(principal, 2),
        "maturity_value": round(maturity_value, 2),
        "total_interest": round(maturity_value - principal, 2),
        "effective_rate": round(((maturity_value / principal) ** (1 / years) - 1) * 100, 2) if years > 0 else 0
    }

def calculate_emi(principal: float, rate: float, months: int) -> Dict:
    """Calculate EMI for a loan"""
    monthly_rate = rate / 12 / 100
    
    if monthly_rate == 0:
        emi = principal / months
    else:
        emi = principal * monthly_rate * ((1 + monthly_rate) ** months) / (((1 + monthly_rate) ** months) - 1)
    
    total_payment = emi * months
    total_interest = total_payment - principal
    
    return {
        "emi": round(emi, 2),
        "total_payment": round(total_payment, 2),
        "total_interest": round(total_interest, 2),
        "principal": round(principal, 2)
    }

def calculate_rd(monthly_deposit: float, rate: float, months: int) -> Dict:
    """Calculate Recurring Deposit maturity"""
    quarterly_rate = rate / 400
    total_deposited = monthly_deposit * months
    
    # Simplified RD calculation
    maturity = 0
    for i in range(months):
        remaining_months = months - i
        quarters = remaining_months / 3
        maturity += monthly_deposit * ((1 + quarterly_rate) ** quarters)
    
    return {
        "total_deposited": round(total_deposited, 2),
        "maturity_value": round(maturity, 2),
        "total_interest": round(maturity - total_deposited, 2)
    }

# ============================================
# ENDPOINTS
# ============================================

@app.get("/")
def health_check():
    return {"status": "active", "service": "wealthin-agentic-sidecar", "version": "2.0"}

@app.get("/tools")
def get_available_tools():
    """Return all available agent tools for function calling"""
    return {"tools": AGENT_TOOLS}

@app.post("/calculate/sip")
def api_calculate_sip(principal: float = 5000, rate: float = 12, months: int = 60):
    """Calculate SIP returns"""
    result = calculate_sip(principal, rate, months)
    return {"success": True, "data": result}

@app.post("/calculate/fd")
def api_calculate_fd(principal: float = 100000, rate: float = 7, months: int = 12):
    """Calculate FD maturity"""
    result = calculate_fd(principal, rate, months)
    return {"success": True, "data": result}

@app.post("/calculate/emi")
def api_calculate_emi(principal: float = 1000000, rate: float = 8.5, months: int = 240):
    """Calculate loan EMI"""
    result = calculate_emi(principal, rate, months)
    return {"success": True, "data": result}

@app.post("/calculate/rd")
def api_calculate_rd(monthly: float = 5000, rate: float = 6.5, months: int = 24):
    """Calculate RD maturity"""
    result = calculate_rd(monthly, rate, months)
    return {"success": True, "data": result}

@app.post("/investment/analyze", response_model=InvestmentResult)
def analyze_investment(calc: InvestmentCalculation):
    """Unified investment calculator endpoint"""
    try:
        if calc.calc_type == "sip":
            monthly = calc.monthly_investment or calc.principal
            result = calculate_sip(monthly, calc.rate, calc.duration_months)
            return InvestmentResult(
                calc_type="sip",
                principal=result["total_invested"],
                total_value=result["future_value"],
                total_interest=result["total_returns"]
            )
        elif calc.calc_type == "fd":
            result = calculate_fd(calc.principal, calc.rate, calc.duration_months)
            return InvestmentResult(
                calc_type="fd",
                principal=calc.principal,
                total_value=result["maturity_value"],
                total_interest=result["total_interest"]
            )
        elif calc.calc_type == "emi":
            result = calculate_emi(calc.principal, calc.rate, calc.duration_months)
            return InvestmentResult(
                calc_type="emi",
                principal=calc.principal,
                total_value=result["total_payment"],
                total_interest=result["total_interest"]
            )
        elif calc.calc_type == "rd":
            monthly = calc.monthly_investment or calc.principal
            result = calculate_rd(monthly, calc.rate, calc.duration_months)
            return InvestmentResult(
                calc_type="rd",
                principal=result["total_deposited"],
                total_value=result["maturity_value"],
                total_interest=result["total_interest"]
            )
        else:
            raise HTTPException(status_code=400, detail=f"Unknown calculation type: {calc.calc_type}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/agent/parse-tool-call")
def parse_tool_call(response_text: str):
    """Parse an LLM response to extract tool calls"""
    try:
        # Try to find JSON in the response
        json_match = re.search(r'\{[\s\S]*\}', response_text)
        if json_match:
            parsed = json.loads(json_match.group())
            if "action" in parsed or "tool_name" in parsed:
                tool_name = parsed.get("action") or parsed.get("tool_name")
                params = parsed.get("parameters") or parsed.get("params") or {}
                confirmation = parsed.get("confirmation_message") or parsed.get("message")
                return {
                    "success": True,
                    "is_tool_call": True,
                    "tool_call": {
                        "tool_name": tool_name,
                        "parameters": params,
                        "confirmation_message": confirmation
                    }
                }
        return {"success": True, "is_tool_call": False, "text": response_text}
    except json.JSONDecodeError:
        return {"success": True, "is_tool_call": False, "text": response_text}

@app.post("/cashflow/analyze")
def analyze_cashflow(transactions: List[Dict[str, Any]], period: str = "month"):
    """Analyze cashflow from transactions"""
    try:
        total_income = sum(t.get("amount", 0) for t in transactions if t.get("type") == "income")
        total_expense = sum(t.get("amount", 0) for t in transactions if t.get("type") == "expense")
        net_flow = total_income - total_expense
        
        # Category breakdown
        expense_by_category = {}
        for t in transactions:
            if t.get("type") == "expense":
                cat = t.get("category", "Other")
                expense_by_category[cat] = expense_by_category.get(cat, 0) + t.get("amount", 0)
        
        income_by_category = {}
        for t in transactions:
            if t.get("type") == "income":
                cat = t.get("category", "Other")
                income_by_category[cat] = income_by_category.get(cat, 0) + t.get("amount", 0)
        
        savings_rate = round((net_flow / total_income * 100), 1) if total_income > 0 else 0
        
        return {
            "success": True,
            "data": {
                "total_income": round(total_income, 2),
                "total_expense": round(total_expense, 2),
                "net_cashflow": round(net_flow, 2),
                "savings_rate": savings_rate,
                "expense_breakdown": [{"name": k, "value": round(v, 2)} for k, v in expense_by_category.items()],
                "income_breakdown": [{"name": k, "value": round(v, 2)} for k, v in income_by_category.items()],
                "period": period
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/transactions/extract-text")
async def extract_text_from_pdf(request: TransactionExtractionRequest):
    try:
        if request.source == 'pdf' and request.document_base64:
             # Decode PDF
             pdf_bytes = base64.b64decode(request.document_base64)
             
             extracted_text = ""
             with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
                 tmp.write(pdf_bytes)
                 tmp_path = tmp.name
                 
             try:
                 with pdfplumber.open(tmp_path) as pdf:
                     for page in pdf.pages:
                         text = page.extract_text()
                         if text:
                             extracted_text += text + "\n"
             finally:
                 if os.path.exists(tmp_path):
                     os.remove(tmp_path)
                 
             if not extracted_text.strip():
                 raise HTTPException(status_code=400, detail="No readable text found in PDF. It might be an image-only PDF.")

             # Construct prompts
             system_prompt = """You are an expert financial analyst. Extract all transactions from the provided text.
Each transaction must have: description, date (YYYY-MM-DD), type (income/expense), amount (number).
Return ONLY a valid JSON array of transaction objects."""
             
             user_prompt = f"""Analyze the following text from a bank statement and extract all financial transactions:
---
{extracted_text[:30000]}
---

Return a JSON array like:
[{{"description": "UPI/swiggy", "date": "2024-01-28", "type": "expense", "amount": 250.00}}]"""
             
             return {
                "system_prompt": system_prompt,
                "user_prompt": user_prompt,
                "model": "crm-di-qwen_text_14b-fp8-it"
             }
        else:
             raise HTTPException(status_code=400, detail="Invalid source or missing document data")
             
    except Exception as e:
        print(f"Error extracting PDF: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# DAILY INSIGHTS (AI-Powered FinBite)
# ============================================

def _analyze_spending_trends(transactions: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Analyze spending patterns from transactions"""
    if not transactions:
        return {"trend": "stable", "top_category": None, "total_spent": 0, "total_income": 0}
    
    # Calculate totals
    total_expense = sum(t.get("amount", 0) for t in transactions if t.get("type") == "expense")
    total_income = sum(t.get("amount", 0) for t in transactions if t.get("type") == "income")
    
    # Category breakdown for expenses
    expense_by_category = {}
    for t in transactions:
        if t.get("type") == "expense":
            cat = t.get("category", "Other")
            expense_by_category[cat] = expense_by_category.get(cat, 0) + t.get("amount", 0)
    
    # Find top spending category
    top_category = None
    max_amount = 0
    for cat, amount in expense_by_category.items():
        if amount > max_amount:
            max_amount = amount
            top_category = cat
    
    # Determine trend based on savings rate
    savings_rate = ((total_income - total_expense) / total_income * 100) if total_income > 0 else 0
    if savings_rate > 30:
        trend = "up"  # Positive - saving well
    elif savings_rate < 10:
        trend = "down"  # Concerning - low savings
    else:
        trend = "stable"
    
    return {
        "trend": trend,
        "top_category": top_category,
        "top_category_amount": max_amount,
        "total_spent": total_expense,
        "total_income": total_income,
        "savings_rate": round(savings_rate, 1),
        "expense_breakdown": expense_by_category
    }


@app.post("/insights/daily", response_model=DailyInsight)
def get_daily_insight(request: DailyInsightRequest):
    """Generate AI-powered daily financial insight (FinBite)"""
    try:
        analysis = _analyze_spending_trends(request.transactions)
        
        # Generate context-aware insights
        total_spent = analysis["total_spent"]
        total_income = analysis["total_income"]
        savings_rate = analysis["savings_rate"]
        top_category = analysis["top_category"]
        top_amount = analysis.get("top_category_amount", 0)
        trend = analysis["trend"]
        
        # Dynamic insight generation based on financial health
        if trend == "up":
            # Good financial health
            headlines = [
                "🎉 Excellent savings this month!",
                "💪 You're on track with your goals!",
                "✨ Strong financial performance!",
            ]
            insights = [
                f"You've saved {savings_rate}% of your income. That's above the recommended 20% benchmark!",
                f"Your disciplined spending is paying off. Net savings: ₹{total_income - total_spent:,.0f}",
                f"Keep it up! At this rate, you'll build a solid emergency fund quickly.",
            ]
            recommendations = [
                "Consider investing the surplus in mutual funds or PPF for better returns.",
                "This would be a good time to increase your SIP contributions.",
                "Review your investment portfolio to optimize returns.",
            ]
        elif trend == "down":
            # Needs attention
            headlines = [
                "⚠️ Spending alert",
                "📊 Budget review needed",
                "💡 Let's optimize spending",
            ]
            insights = [
                f"Your savings rate is {savings_rate}%, below the healthy 20% mark.",
                f"Expenses (₹{total_spent:,.0f}) are consuming most of your income.",
                f"Your {top_category} spending (₹{top_amount:,.0f}) might need attention.",
            ]
            recommendations = [
                f"Try to reduce {top_category} expenses by 15% next month.",
                "Set up a weekly spending limit to stay on track.",
                "Consider the 50-30-20 rule: 50% needs, 30% wants, 20% savings.",
            ]
        else:
            # Stable/moderate
            headlines = [
                "📈 Steady progress",
                "✓ On track this month",
                "🔄 Consistent performance",
            ]
            insights = [
                f"You're saving {savings_rate}% of income - that's reasonable but can improve.",
                f"Total spending: ₹{total_spent:,.0f} across all categories.",
                f"Top spending area: {top_category or 'Various'} at ₹{top_amount:,.0f}",
            ]
            recommendations = [
                "Small changes in daily expenses can boost savings by 5-10%.",
                f"Review your {top_category} spending for optimization opportunities.",
                "Consider automating your savings with a recurring transfer.",
            ]
        
        # Select random insight variant for variety
        import random
        idx = random.randint(0, len(headlines) - 1)
        
        return DailyInsight(
            headline=headlines[idx],
            insight_text=insights[idx],
            recommendation=recommendations[idx],
            trend_indicator=trend,
            category_highlight=top_category,
            amount_highlight=top_amount if top_amount > 0 else None
        )
        
    except Exception as e:
        # Fallback insight on error
        return DailyInsight(
            headline="📊 Your Financial Snapshot",
            insight_text="Add more transactions to get personalized insights.",
            recommendation="Track your daily expenses for better financial awareness.",
            trend_indicator="stable",
            category_highlight=None,
            amount_highlight=None
        )


# ============================================
# DOCUMENT GENERATION
# ============================================

def _generate_loan_application_pdf(content: Dict[str, Any], user_info: Dict[str, Any]) -> bytes:
    """Generate a loan application PDF using ReportLab"""
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=72, leftMargin=72, topMargin=72, bottomMargin=18)
    
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=18, spaceAfter=20, alignment=1)
    heading_style = ParagraphStyle('Heading', parent=styles['Heading2'], fontSize=14, spaceAfter=10, spaceBefore=15)
    body_style = ParagraphStyle('Body', parent=styles['Normal'], fontSize=11, spaceAfter=8)
    
    story = []
    
    # Title
    story.append(Paragraph("LOAN APPLICATION FORM", title_style))
    story.append(Spacer(1, 12))
    
    # Applicant Details
    story.append(Paragraph("1. APPLICANT DETAILS", heading_style))
    applicant_data = [
        ["Full Name:", content.get("applicant_name", user_info.get("name", ""))],
        ["Date of Birth:", content.get("dob", "")],
        ["Address:", content.get("address", "")],
        ["Phone:", content.get("phone", user_info.get("phone", ""))],
        ["Email:", content.get("email", user_info.get("email", ""))],
        ["PAN Number:", content.get("pan", "")],
        ["Aadhaar Number:", content.get("aadhaar", "")],
    ]
    table = Table(applicant_data, colWidths=[2*inch, 4*inch])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
    ]))
    story.append(table)
    
    # Loan Details
    story.append(Paragraph("2. LOAN DETAILS", heading_style))
    loan_data = [
        ["Loan Type:", content.get("loan_type", "Personal Loan")],
        ["Loan Amount:", f"₹{content.get('loan_amount', 0):,.2f}"],
        ["Loan Tenure:", f"{content.get('tenure_months', 0)} months"],
        ["Purpose:", content.get("purpose", "")],
    ]
    table = Table(loan_data, colWidths=[2*inch, 4*inch])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
    ]))
    story.append(table)
    
    # Employment Details
    story.append(Paragraph("3. EMPLOYMENT DETAILS", heading_style))
    emp_data = [
        ["Employment Type:", content.get("employment_type", "Salaried")],
        ["Employer Name:", content.get("employer", "")],
        ["Monthly Income:", f"₹{content.get('monthly_income', 0):,.2f}"],
        ["Years in Service:", content.get("years_in_service", "")],
    ]
    table = Table(emp_data, colWidths=[2*inch, 4*inch])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
    ]))
    story.append(table)
    
    # Declaration
    story.append(Spacer(1, 20))
    story.append(Paragraph("DECLARATION", heading_style))
    declaration_text = """I hereby declare that all the information provided above is true and correct to the best of my knowledge. 
    I authorize the lender to verify the details and obtain credit information from any credit bureau."""
    story.append(Paragraph(declaration_text, body_style))
    
    story.append(Spacer(1, 40))
    story.append(Paragraph(f"Date: {datetime.now().strftime('%d-%m-%Y')}", body_style))
    story.append(Spacer(1, 20))
    story.append(Paragraph("Signature: ____________________", body_style))
    
    doc.build(story)
    return buffer.getvalue()


def _generate_invoice_pdf(content: Dict[str, Any], user_info: Dict[str, Any]) -> bytes:
    """Generate an invoice PDF using ReportLab"""
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=50, leftMargin=50, topMargin=50, bottomMargin=30)
    
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=20, spaceAfter=20, alignment=1)
    heading_style = ParagraphStyle('Heading', parent=styles['Heading2'], fontSize=12, spaceAfter=8)
    body_style = ParagraphStyle('Body', parent=styles['Normal'], fontSize=10, spaceAfter=6)
    
    story = []
    
    # Header with Invoice number
    invoice_no = content.get("invoice_number", f"INV-{datetime.now().strftime('%Y%m%d%H%M')}")
    story.append(Paragraph("INVOICE", title_style))
    story.append(Paragraph(f"Invoice No: {invoice_no}", body_style))
    story.append(Paragraph(f"Date: {content.get('date', datetime.now().strftime('%d-%m-%Y'))}", body_style))
    story.append(Spacer(1, 15))
    
    # From/To Section
    from_to_data = [
        ["FROM:", "TO:"],
        [content.get("from_name", user_info.get("name", "")), content.get("to_name", "")],
        [content.get("from_address", ""), content.get("to_address", "")],
        [content.get("from_phone", user_info.get("phone", "")), content.get("to_phone", "")],
    ]
    table = Table(from_to_data, colWidths=[3*inch, 3*inch])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(table)
    story.append(Spacer(1, 20))
    
    # Items Table
    items = content.get("items", [])
    item_data = [["#", "Description", "Qty", "Rate", "Amount"]]
    subtotal = 0
    for i, item in enumerate(items, 1):
        qty = item.get("quantity", 1)
        rate = item.get("rate", 0)
        amount = qty * rate
        subtotal += amount
        item_data.append([str(i), item.get("description", ""), str(qty), f"₹{rate:,.2f}", f"₹{amount:,.2f}"])
    
    # Add totals
    tax_rate = content.get("tax_rate", 0)
    tax_amount = subtotal * (tax_rate / 100)
    total = subtotal + tax_amount
    
    item_data.append(["", "", "", "Subtotal:", f"₹{subtotal:,.2f}"])
    if tax_rate > 0:
        item_data.append(["", "", "", f"Tax ({tax_rate}%):", f"₹{tax_amount:,.2f}"])
    item_data.append(["", "", "", "TOTAL:", f"₹{total:,.2f}"])
    
    table = Table(item_data, colWidths=[0.5*inch, 3*inch, 0.7*inch, 1*inch, 1.2*inch])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (-2, -3), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#f0f0f0')),
        ('GRID', (0, 0), (-1, -4), 0.5, colors.grey),
        ('LINEABOVE', (-2, -3), (-1, -3), 1, colors.black),
        ('LINEABOVE', (-2, -1), (-1, -1), 1.5, colors.black),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('ALIGN', (2, 0), (-1, -1), 'RIGHT'),
    ]))
    story.append(table)
    
    # Notes
    story.append(Spacer(1, 30))
    if content.get("notes"):
        story.append(Paragraph("Notes:", heading_style))
        story.append(Paragraph(content.get("notes", ""), body_style))
    
    # Footer
    story.append(Spacer(1, 40))
    story.append(Paragraph("Thank you for your business!", ParagraphStyle('Center', parent=body_style, alignment=1)))
    
    doc.build(story)
    return buffer.getvalue()


def _generate_receipt_pdf(content: Dict[str, Any], user_info: Dict[str, Any]) -> bytes:
    """Generate a payment receipt PDF"""
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=72, leftMargin=72, topMargin=72, bottomMargin=30)
    
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=18, spaceAfter=20, alignment=1)
    body_style = ParagraphStyle('Body', parent=styles['Normal'], fontSize=11, spaceAfter=8)
    
    story = []
    
    receipt_no = content.get("receipt_number", f"REC-{datetime.now().strftime('%Y%m%d%H%M')}")
    story.append(Paragraph("PAYMENT RECEIPT", title_style))
    story.append(Spacer(1, 10))
    
    receipt_data = [
        ["Receipt No:", receipt_no],
        ["Date:", content.get("date", datetime.now().strftime("%d-%m-%Y"))],
        ["", ""],
        ["Received From:", content.get("received_from", "")],
        ["Amount:", f"₹{content.get('amount', 0):,.2f}"],
        ["Payment Mode:", content.get("payment_mode", "Cash")],
        ["", ""],
        ["For:", content.get("description", "")],
    ]
    
    table = Table(receipt_data, colWidths=[2*inch, 4*inch])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
    ]))
    story.append(table)
    
    story.append(Spacer(1, 50))
    story.append(Paragraph("Authorized Signature: ____________________", body_style))
    
    doc.build(story)
    return buffer.getvalue()


def _generate_project_report_pdf(content: Dict[str, Any], user_info: Dict[str, Any]) -> bytes:
    """Generate a project/business report PDF"""
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=72, leftMargin=72, topMargin=72, bottomMargin=30)
    
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=20, spaceAfter=20, alignment=1)
    heading_style = ParagraphStyle('Heading', parent=styles['Heading2'], fontSize=14, spaceAfter=10, spaceBefore=15)
    body_style = ParagraphStyle('Body', parent=styles['Normal'], fontSize=11, spaceAfter=8, leading=14)
    
    story = []
    
    # Title
    story.append(Paragraph(content.get("title", "PROJECT REPORT"), title_style))
    story.append(Paragraph(f"Prepared by: {content.get('prepared_by', user_info.get('name', ''))}", body_style))
    story.append(Paragraph(f"Date: {content.get('date', datetime.now().strftime('%d-%m-%Y'))}", body_style))
    story.append(Spacer(1, 20))
    
    # Sections
    sections = content.get("sections", [])
    for section in sections:
        story.append(Paragraph(section.get("heading", ""), heading_style))
        story.append(Paragraph(section.get("content", ""), body_style))
    
    # Financial Summary if provided
    if content.get("financial_summary"):
        story.append(Paragraph("FINANCIAL SUMMARY", heading_style))
        fin_data = content.get("financial_summary", {})
        fin_table_data = [
            ["Total Investment:", f"₹{fin_data.get('total_investment', 0):,.2f}"],
            ["Expected Revenue:", f"₹{fin_data.get('expected_revenue', 0):,.2f}"],
            ["Projected Profit:", f"₹{fin_data.get('projected_profit', 0):,.2f}"],
            ["Break-even Period:", fin_data.get("breakeven_period", "N/A")],
        ]
        table = Table(fin_table_data, colWidths=[2.5*inch, 3*inch])
        table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 11),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ]))
        story.append(table)
    
    doc.build(story)
    return buffer.getvalue()


@app.post("/documents/generate")
def generate_document(request: DocumentGenerationRequest):
    """Generate a document (loan application, invoice, receipt, project report)"""
    try:
        user_info = request.user_info or {}
        content = request.content or {}
        
        if request.doc_type == "loan_application":
            pdf_bytes = _generate_loan_application_pdf(content, user_info)
        elif request.doc_type == "invoice":
            pdf_bytes = _generate_invoice_pdf(content, user_info)
        elif request.doc_type == "receipt":
            pdf_bytes = _generate_receipt_pdf(content, user_info)
        elif request.doc_type == "project_report":
            pdf_bytes = _generate_project_report_pdf(content, user_info)
        else:
            raise HTTPException(status_code=400, detail=f"Unknown document type: {request.doc_type}")
        
        # Return base64 encoded PDF
        pdf_base64 = base64.b64encode(pdf_bytes).decode('utf-8')
        
        return {
            "success": True,
            "document_type": request.doc_type,
            "title": request.title,
            "pdf_base64": pdf_base64,
            "filename": f"{request.doc_type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error generating document: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/documents/templates")
def get_document_templates():
    """Return available document templates and their required fields"""
    return {
        "templates": [
            {
                "type": "loan_application",
                "name": "Loan Application",
                "description": "Apply for personal, home, or vehicle loans",
                "required_fields": ["applicant_name", "loan_amount", "loan_type"],
                "optional_fields": ["dob", "address", "phone", "email", "pan", "aadhaar", "tenure_months", "purpose", "employment_type", "employer", "monthly_income"]
            },
            {
                "type": "invoice",
                "name": "Invoice",
                "description": "Generate professional invoices for goods or services",
                "required_fields": ["to_name", "items"],
                "optional_fields": ["invoice_number", "date", "from_name", "from_address", "to_address", "tax_rate", "notes"]
            },
            {
                "type": "receipt",
                "name": "Payment Receipt",
                "description": "Issue receipts for payments received",
                "required_fields": ["received_from", "amount", "description"],
                "optional_fields": ["receipt_number", "date", "payment_mode"]
            },
            {
                "type": "project_report",
                "name": "Project Report",
                "description": "Create detailed project or business reports",
                "required_fields": ["title", "sections"],
                "optional_fields": ["prepared_by", "date", "financial_summary"]
            }
        ]
    }


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
