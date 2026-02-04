"""
WealthIn Python Sidecar v3.0 - Production Backend
Handles: Local Database, LLM Integration, Transaction Import, Trend Analysis
"""
import os
import base64
import json
import re
import tempfile
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from io import BytesIO

from fastapi import FastAPI, HTTPException, UploadFile, File, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# PDF processing
try:
    import pdfplumber
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False

# PDF generation
try:
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib import colors
    from reportlab.lib.units import inch
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False

# Local modules
from database import (
    init_database, create_transaction, get_transactions, bulk_create_transactions,
    delete_transaction, analyze_trends, get_trends, get_dashboard_data,
    create_budget, get_budgets, update_budget, delete_budget,
    create_goal, get_goals, add_funds_to_goal,
    get_ai_context, save_chat_message, get_chat_history
)
from llm_service import llm_service, process_with_tools

# ==================== APP INITIALIZATION ====================

app = FastAPI(
    title="WealthIn Backend",
    version="3.0",
    description="Local-first financial management backend"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize database on startup
@app.on_event("startup")
async def startup():
    init_database()
    print("WealthIn Backend started successfully")

# ==================== MODELS ====================

class TransactionCreate(BaseModel):
    user_id: str
    amount: float
    description: str
    category: str = "Other"
    type: str  # 'income' or 'expense'
    date: Optional[str] = None
    time: Optional[str] = None
    payment_method: Optional[str] = None
    notes: Optional[str] = None

class BudgetCreate(BaseModel):
    user_id: str
    name: str
    category: str
    amount: float
    period: str = "monthly"
    icon: str = "wallet"

class GoalCreate(BaseModel):
    user_id: str
    name: str
    target_amount: float
    deadline: Optional[str] = None
    icon: str = "flag"
    notes: Optional[str] = None

class ChatRequest(BaseModel):
    user_id: str
    message: str
    conversation_history: Optional[List[Dict[str, str]]] = None

class TransactionImportRequest(BaseModel):
    user_id: str
    document_base64: str
    mime_type: str
    source: str = "pdf"

class InvestmentCalc(BaseModel):
    calc_type: str  # sip, fd, emi, rd
    principal: float
    rate: float
    duration_months: int
    monthly_investment: Optional[float] = None

# ==================== HEALTH CHECK ====================

@app.get("/")
@app.get("/health")
def health_check():
    return {
        "status": "active",
        "service": "wealthin-backend",
        "version": "3.0",
        "database": "sqlite",
        "pdf_support": PDF_AVAILABLE
    }

# ==================== DASHBOARD ====================

@app.get("/dashboard/{user_id}")
def get_dashboard(user_id: str):
    """Get comprehensive dashboard data from real transactions"""
    try:
        data = get_dashboard_data(user_id)
        return {"success": True, "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== TRANSACTIONS ====================

@app.post("/transactions")
def api_create_transaction(transaction: TransactionCreate):
    """Create a new transaction"""
    try:
        result = create_transaction(
            user_id=transaction.user_id,
            amount=transaction.amount,
            description=transaction.description,
            category=transaction.category,
            type=transaction.type,
            date=transaction.date,
            time=transaction.time,
            payment_method=transaction.payment_method,
            notes=transaction.notes
        )
        return {"success": True, "transaction": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/transactions/{user_id}")
def api_get_transactions(
    user_id: str,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    type: Optional[str] = None,
    category: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Get transactions with optional filtering"""
    try:
        transactions = get_transactions(
            user_id=user_id,
            limit=limit,
            offset=offset,
            type=type,
            category=category,
            start_date=start_date,
            end_date=end_date
        )
        return {"success": True, "transactions": transactions, "count": len(transactions)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/transactions/{user_id}/{transaction_id}")
def api_delete_transaction(user_id: str, transaction_id: int):
    """Delete a transaction"""
    try:
        success = delete_transaction(user_id, transaction_id)
        if success:
            return {"success": True, "message": "Transaction deleted"}
        else:
            raise HTTPException(status_code=404, detail="Transaction not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== TRANSACTION IMPORT ====================

@app.post("/transactions/import/pdf")
async def import_from_pdf(
    file: UploadFile = File(...),
    user_id: str = Query(...)
):
    """Import transactions from PDF bank statement"""
    if not PDF_AVAILABLE:
        raise HTTPException(status_code=500, detail="PDF processing not available")
    
    try:
        # Save uploaded file temporarily
        content = await file.read()
        
        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        
        extracted_text = ""
        try:
            with pdfplumber.open(tmp_path) as pdf:
                for page in pdf.pages:
                    text = page.extract_text()
                    if text:
                        extracted_text += text + "\n"
        finally:
            os.unlink(tmp_path)
        
        if not extracted_text.strip():
            raise HTTPException(status_code=400, detail="No text found in PDF")
        
        # Parse transactions from text
        transactions = parse_bank_statement(extracted_text)
        
        # Detect bank
        bank_detected = detect_bank(extracted_text)
        
        # Save transactions to database
        if transactions:
            count = bulk_create_transactions(user_id, transactions, source='pdf_import')
            return {
                "success": True,
                "bank_detected": bank_detected,
                "transactions": transactions,
                "imported_count": count
            }
        else:
            return {
                "success": True,
                "bank_detected": bank_detected,
                "transactions": [],
                "imported_count": 0,
                "message": "No transactions could be parsed from the PDF"
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/transactions/import/image")
async def import_from_image(
    file: UploadFile = File(...),
    user_id: str = Query(...)
):
    """Import transaction from receipt image (placeholder for OCR)"""
    try:
        content = await file.read()
        
        # For now, return a placeholder response
        # In production, integrate with OCR service (Google Vision, Tesseract, etc.)
        return {
            "success": True,
            "transaction": {
                "description": "Receipt scan - manual entry required",
                "amount": 0,
                "type": "expense",
                "category": "Other",
                "date": datetime.now().strftime('%Y-%m-%d')
            },
            "confidence": 0.0,
            "message": "OCR processing requires manual verification"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def parse_bank_statement(text: str) -> List[Dict[str, Any]]:
    """Parse transactions from bank statement text"""
    transactions = []
    
    # Common patterns for Indian bank statements
    patterns = [
        # Pattern: DD-MM-YYYY or DD/MM/YYYY followed by description and amount
        r'(\d{2}[-/]\d{2}[-/]\d{4})\s+(.+?)\s+([\d,]+\.?\d*)\s*(CR|DR)?',
        # Pattern: Amount followed by CR/DR
        r'(.+?)\s+([\d,]+\.?\d*)\s+(CR|DR)\s*(\d{2}[-/]\d{2}[-/]\d{4})?',
    ]
    
    lines = text.split('\n')
    
    for line in lines:
        line = line.strip()
        if not line or len(line) < 10:
            continue
        
        # Try each pattern
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                try:
                    groups = match.groups()
                    
                    # Extract date
                    date_str = None
                    for g in groups:
                        if g and re.match(r'\d{2}[-/]\d{2}[-/]\d{4}', str(g)):
                            date_str = g
                            break
                    
                    # Parse date
                    if date_str:
                        date_str = date_str.replace('/', '-')
                        try:
                            parsed_date = datetime.strptime(date_str, '%d-%m-%Y')
                            date = parsed_date.strftime('%Y-%m-%d')
                        except:
                            date = datetime.now().strftime('%Y-%m-%d')
                    else:
                        date = datetime.now().strftime('%Y-%m-%d')
                    
                    # Extract amount
                    amount = 0
                    for g in groups:
                        if g and re.match(r'[\d,]+\.?\d*$', str(g).replace(',', '')):
                            amount = float(str(g).replace(',', ''))
                            break
                    
                    if amount == 0:
                        continue
                    
                    # Extract description
                    description = ""
                    for g in groups:
                        if g and not re.match(r'[\d,]+\.?\d*$', str(g).replace(',', '')) and \
                           not re.match(r'\d{2}[-/]\d{2}[-/]\d{4}', str(g)) and \
                           g not in ['CR', 'DR', 'cr', 'dr']:
                            description = g.strip()
                            break
                    
                    if not description:
                        description = "Bank transaction"
                    
                    # Determine type (CR = income, DR = expense)
                    tx_type = 'expense'
                    for g in groups:
                        if g and str(g).upper() == 'CR':
                            tx_type = 'income'
                            break
                    
                    # Categorize based on description
                    category = categorize_transaction(description)
                    
                    transactions.append({
                        'description': description[:100],  # Limit length
                        'amount': amount,
                        'type': tx_type,
                        'category': category,
                        'date': date
                    })
                    break
                    
                except Exception as e:
                    continue
    
    return transactions

def detect_bank(text: str) -> Optional[str]:
    """Detect bank from statement text"""
    text_lower = text.lower()
    
    banks = {
        'hdfc': ['hdfc bank', 'hdfcbank'],
        'icici': ['icici bank', 'icicibank'],
        'sbi': ['state bank of india', 'sbi'],
        'axis': ['axis bank', 'axisbank'],
        'kotak': ['kotak mahindra', 'kotak bank'],
        'yes': ['yes bank'],
        'pnb': ['punjab national bank', 'pnb'],
        'bob': ['bank of baroda', 'bob'],
        'canara': ['canara bank'],
        'idfc': ['idfc first', 'idfc bank'],
    }
    
    for bank_name, keywords in banks.items():
        for keyword in keywords:
            if keyword in text_lower:
                return bank_name.upper()
    
    return None

def categorize_transaction(description: str) -> str:
    """Categorize transaction based on description"""
    desc_lower = description.lower()
    
    categories = {
        'Food': ['swiggy', 'zomato', 'restaurant', 'food', 'cafe', 'pizza', 'burger', 'dominos', 'kfc', 'mcdonalds', 'grocery', 'supermarket', 'bigbasket', 'blinkit', 'zepto'],
        'Transport': ['uber', 'ola', 'rapido', 'metro', 'bus', 'petrol', 'fuel', 'parking', 'toll', 'irctc', 'railway', 'flight', 'airport'],
        'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'mall', 'store', 'shop'],
        'Entertainment': ['netflix', 'prime', 'hotstar', 'spotify', 'movie', 'cinema', 'pvr', 'inox', 'game'],
        'Utilities': ['electricity', 'water', 'gas', 'internet', 'wifi', 'broadband', 'jio', 'airtel', 'vi', 'bsnl', 'bill'],
        'Health': ['hospital', 'clinic', 'pharmacy', 'medical', 'medicine', 'doctor', 'apollo', 'practo', '1mg', 'netmeds'],
        'Education': ['school', 'college', 'tuition', 'course', 'udemy', 'coursera', 'book', 'stationery'],
        'Investment': ['mutual fund', 'sip', 'stock', 'zerodha', 'groww', 'upstox', 'investment', 'fd', 'ppf'],
        'Salary': ['salary', 'payroll', 'income'],
        'Transfer': ['upi', 'neft', 'imps', 'rtgs', 'transfer', 'payment'],
    }
    
    for category, keywords in categories.items():
        for keyword in keywords:
            if keyword in desc_lower:
                return category
    
    return 'Other'

# ==================== TRENDS & ANALYSIS ====================

@app.get("/trends/{user_id}")
def api_get_trends(
    user_id: str,
    period: str = Query("monthly", regex="^(weekly|monthly|quarterly|yearly)$")
):
    """Get spending trends and insights"""
    try:
        trends = get_trends(user_id, period)
        return {"success": True, "trends": trends}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/trends/{user_id}/analyze")
def api_analyze_trends(
    user_id: str,
    period: str = Query("monthly", regex="^(weekly|monthly|quarterly|yearly)$")
):
    """Force recalculate trends"""
    try:
        trends = analyze_trends(user_id, period)
        return {"success": True, "trends": trends}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== BUDGETS ====================

@app.post("/budgets")
def api_create_budget(budget: BudgetCreate):
    """Create a new budget"""
    try:
        result = create_budget(
            user_id=budget.user_id,
            name=budget.name,
            category=budget.category,
            amount=budget.amount,
            period=budget.period,
            icon=budget.icon
        )
        return {"success": True, "budget": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/budgets/{user_id}")
def api_get_budgets(user_id: str):
    """Get all budgets for a user"""
    try:
        budgets = get_budgets(user_id)
        return {"success": True, "budgets": budgets}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/budgets/{user_id}/{budget_id}")
def api_update_budget(user_id: str, budget_id: int, updates: Dict[str, Any]):
    """Update a budget"""
    try:
        success = update_budget(user_id, budget_id, **updates)
        if success:
            return {"success": True, "message": "Budget updated"}
        raise HTTPException(status_code=404, detail="Budget not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/budgets/{user_id}/{budget_id}")
def api_delete_budget(user_id: str, budget_id: int):
    """Delete a budget"""
    try:
        success = delete_budget(user_id, budget_id)
        if success:
            return {"success": True, "message": "Budget deleted"}
        raise HTTPException(status_code=404, detail="Budget not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== GOALS ====================

@app.post("/goals")
def api_create_goal(goal: GoalCreate):
    """Create a new savings goal"""
    try:
        result = create_goal(
            user_id=goal.user_id,
            name=goal.name,
            target_amount=goal.target_amount,
            deadline=goal.deadline,
            icon=goal.icon,
            notes=goal.notes
        )
        return {"success": True, "goal": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/goals/{user_id}")
def api_get_goals(user_id: str):
    """Get all goals for a user"""
    try:
        goals = get_goals(user_id)
        return {"success": True, "goals": goals}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/goals/{user_id}/{goal_id}/add-funds")
def api_add_funds_to_goal(user_id: str, goal_id: int, amount: float = Query(...)):
    """Add funds to a goal"""
    try:
        result = add_funds_to_goal(user_id, goal_id, amount)
        if result:
            return {"success": True, "goal": result}
        raise HTTPException(status_code=404, detail="Goal not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== AI CHAT ====================

@app.post("/chat")
async def api_chat(request: ChatRequest):
    """AI-powered financial advisor chat"""
    try:
        # Get user's financial context
        context = get_ai_context(request.user_id)
        
        # Build messages
        messages = request.conversation_history or []
        messages.append({'role': 'user', 'content': request.message})
        
        # Save user message
        save_chat_message(request.user_id, 'user', request.message)
        
        # Process with potential tool execution
        result = await process_with_tools(
            query=request.message,
            user_context=context,
            user_id=request.user_id
        )
        
        if result['type'] == 'tool_call':
            response_text = result.get('confirmation', result['raw_response'])
            return {
                "success": True,
                "response": response_text,
                "action_type": result['action'],
                "action_data": result['parameters'],
                "needs_confirmation": True
            }
        else:
            response_text = result['response']
            
            # Save AI response
            save_chat_message(request.user_id, 'assistant', response_text)
            
            return {
                "success": True,
                "response": response_text,
                "action_taken": False
            }
            
    except Exception as e:
        return {
            "success": False,
            "response": f"I'm having trouble processing your request. Error: {str(e)}",
            "action_taken": False
        }

@app.get("/chat/history/{user_id}")
def api_get_chat_history(user_id: str, limit: int = Query(20, ge=1, le=100)):
    """Get chat history"""
    try:
        history = get_chat_history(user_id, limit)
        return {"success": True, "history": history}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/chat/context/{user_id}")
def api_get_ai_context(user_id: str):
    """Get user's financial context for AI"""
    try:
        context = get_ai_context(user_id)
        return {"success": True, "context": context}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== CALCULATORS ====================

@app.post("/calculate/sip")
def calculate_sip(amount: float = 5000, rate: float = 12, months: int = 60):
    """Calculate SIP returns"""
    monthly_rate = rate / 12 / 100
    total_invested = amount * months
    
    if monthly_rate == 0:
        future_value = total_invested
    else:
        future_value = amount * (((1 + monthly_rate) ** months - 1) / monthly_rate) * (1 + monthly_rate)
    
    return {
        "success": True,
        "data": {
            "total_invested": round(total_invested, 2),
            "future_value": round(future_value, 2),
            "total_returns": round(future_value - total_invested, 2),
            "return_percentage": round(((future_value - total_invested) / total_invested) * 100, 2)
        }
    }

@app.post("/calculate/fd")
def calculate_fd(principal: float = 100000, rate: float = 7, months: int = 12):
    """Calculate FD maturity"""
    years = months / 12
    maturity_value = principal * ((1 + rate / 400) ** (4 * years))
    
    return {
        "success": True,
        "data": {
            "principal": round(principal, 2),
            "maturity_value": round(maturity_value, 2),
            "total_interest": round(maturity_value - principal, 2)
        }
    }

@app.post("/calculate/emi")
def calculate_emi(principal: float = 1000000, rate: float = 8.5, months: int = 240):
    """Calculate loan EMI"""
    monthly_rate = rate / 12 / 100
    
    if monthly_rate == 0:
        emi = principal / months
    else:
        emi = principal * monthly_rate * ((1 + monthly_rate) ** months) / (((1 + monthly_rate) ** months) - 1)
    
    total_payment = emi * months
    
    return {
        "success": True,
        "data": {
            "emi": round(emi, 2),
            "total_payment": round(total_payment, 2),
            "total_interest": round(total_payment - principal, 2),
            "principal": round(principal, 2)
        }
    }

# ==================== DAILY INSIGHTS ====================

@app.get("/insights/daily/{user_id}")
def get_daily_insight(user_id: str):
    """Get AI-generated daily financial insight"""
    try:
        # Get trends for insight generation
        trends = get_trends(user_id, 'monthly')
        
        total_income = trends.get('total_income', 0)
        total_expense = trends.get('total_expense', 0)
        savings_rate = trends.get('savings_rate', 0)
        top_category = trends.get('top_expense_category')
        top_amount = trends.get('top_expense_amount', 0)
        
        # Determine trend and generate insight
        if total_income == 0 and total_expense == 0:
            return {
                "headline": "📊 Start Your Financial Journey",
                "insight_text": "Import your bank statements or add transactions to get personalized insights.",
                "recommendation": "Use the import feature to scan your bank statement PDF.",
                "trend_indicator": "stable",
                "category_highlight": None,
                "amount_highlight": None
            }
        
        if savings_rate >= 30:
            return {
                "headline": "🎉 Excellent Savings!",
                "insight_text": f"You're saving {savings_rate:.1f}% of your income - above the 20% benchmark!",
                "recommendation": "Consider investing the surplus in mutual funds for better returns.",
                "trend_indicator": "up",
                "category_highlight": top_category,
                "amount_highlight": top_amount
            }
        elif savings_rate >= 15:
            return {
                "headline": "📈 Good Progress",
                "insight_text": f"Savings rate of {savings_rate:.1f}% is healthy. Room for improvement.",
                "recommendation": f"Try reducing {top_category} expenses by 10% next month.",
                "trend_indicator": "stable",
                "category_highlight": top_category,
                "amount_highlight": top_amount
            }
        else:
            return {
                "headline": "⚠️ Spending Alert",
                "insight_text": f"Your savings rate is {savings_rate:.1f}%, below the recommended 20%.",
                "recommendation": "Set up a budget and track daily expenses to improve.",
                "trend_indicator": "down",
                "category_highlight": top_category,
                "amount_highlight": top_amount
            }
            
    except Exception as e:
        return {
            "headline": "📊 Your Financial Snapshot",
            "insight_text": "Add more transactions for personalized insights.",
            "recommendation": "Track your expenses for better financial awareness.",
            "trend_indicator": "stable",
            "category_highlight": None,
            "amount_highlight": None
        }

# ==================== LLM STATUS ====================

@app.get("/llm/status")
def get_llm_status():
    """Get LLM service status and available providers"""
    return llm_service.get_status()

# ==================== RUN SERVER ====================

def find_available_port(start_port: int = 8000, max_attempts: int = 10) -> int:
    """Find an available port starting from start_port"""
    import socket
    for offset in range(max_attempts):
        port = start_port + offset
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('', port))
                return port
            except OSError:
                continue
    return start_port  # Fallback to default

if __name__ == "__main__":
    preferred_port = int(os.getenv("PORT", 8000))
    port = find_available_port(preferred_port)
    if port != preferred_port:
        print(f"[Backend] Port {preferred_port} busy, using port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
