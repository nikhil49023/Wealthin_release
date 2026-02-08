"""
WealthIn Agent Service - Founder's OS Backend
FastAPI backend implementing the Sense-Plan-Act agentic architecture:

PERCEPTION LAYER (Sensing):
- Local PDF Parser (pdfplumber) for e-statements
- Zoho Vision Bridge for receipt image OCR

COGNITION LAYER (Thinking):  
- Sarvam Indic Expert for regional language support
- Zoho Catalyst QuickML for general chat

ACTION LAYER (Doing):
- Tool Dispatcher for budgets, goals, payments, transactions
- Investment calculators (SIP, FD, EMI, RD)
"""

import os
import logging
import tempfile
from contextlib import asynccontextmanager
from typing import Optional, List, Dict, Any

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
import json
from datetime import datetime

# Service imports - The Three Layers
from services.pdf_parser_advanced import pdf_parser_service, AdvancedPDFParser
from services.investment_calculator import investment_calculator
from services.transaction_categorizer import transaction_categorizer, categorize_transaction
from services.ai_tools_service import ai_tools_service, ai_agent_service, AgentQueryRequest # Import new AI service
from services.sarvam_service import sarvam_service
from services.zoho_vision_service import zoho_vision_service
from services.database_service import database_service, Budget, Goal, Transaction, ScheduledPayment
from services.analytics_service import analytics_service
from services.financial_calculator import FinancialCalculator
from services.web_search_service import web_search_service
from services.pdf_parser_advanced import pdf_parser_service, ReceiptParser, AdvancedPDFParser
from services.deep_research_agent import get_deep_research_agent

load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# Lifespan context manager (replaces deprecated @app.on_event)
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize services on startup, cleanup on shutdown."""
    logger.info("Starting WealthIn Agent Service...")
    await database_service.initialize()
    logger.info("Database initialized successfully")
    yield
    logger.info("Shutting down WealthIn Agent Service...")


app = FastAPI(
    title="WealthIn Founder's OS",
    description="Agentic AI backend for Indian entrepreneurs - Sense, Plan, Act",
    version="3.0.0",
    lifespan=lifespan
)

# CORS middleware for Flutter - configurable via environment
cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Analytics & Calculator Routes ---

@app.post("/analytics/refresh/{user_id}")
async def refresh_analytics(user_id: str):
    await analytics_service.refresh_daily_trends(user_id)
    return {"status": "success", "message": "Trends refreshed"}

@app.get("/analytics/monthly/{user_id}")
async def get_monthly_trends(user_id: str):
    trends = await analytics_service.get_monthly_trends(user_id)
    prediction = await analytics_service.predict_next_month_expenses(user_id)
    return {
        "monthly_data": trends,
        "next_month_prediction": prediction
    }

class SavingsRateRequest(BaseModel):
    income: float
    expenses: float

@app.post("/calculator/savings-rate")
async def calc_savings_rate(data: SavingsRateRequest):
    rate = FinancialCalculator.calculate_savings_rate(data.income, data.expenses)
    return {"savings_rate_percentage": round(rate, 2)}

class CompoundInterestRequest(BaseModel):
    principal: float
    rate: float
    years: int
    monthly_contribution: float = 0

@app.post("/calculator/compound-interest")
async def calc_compound_interest(data: CompoundInterestRequest):
    result = FinancialCalculator.calculate_compound_interest(
        data.principal, data.rate, data.years, data.monthly_contribution
    )
    return result

class PerCapitaRequest(BaseModel):
    total_income: float
    family_size: int

@app.post("/calculator/per-capita")
async def calc_per_capita(data: PerCapitaRequest):
    pci = FinancialCalculator.calculate_per_capita_income(data.total_income, data.family_size)
    return {"per_capita_income": round(pci, 2)}

class EmergencyFundRequest(BaseModel):
    current_savings: float
    monthly_expenses: float
    target_months: int = 6

@app.post("/calculator/emergency-fund")
async def calc_emergency_fund(data: EmergencyFundRequest):
    return FinancialCalculator.calculate_emergency_fund_status(
        data.current_savings, data.monthly_expenses, data.target_months
    )

@app.get("/dashboard/{user_id}")
async def get_dashboard_data(user_id: str):
    """
    Get aggregated dashboard data for the user.
    Includes: summary, budgets, goals, upcoming payments, recent transactions, cashflow.
    """
    return await database_service.get_dashboard_data(user_id)

@app.get("/insights/daily/{user_id}")
async def get_daily_insight(user_id: str):
    """
    Get a daily AI-generated financial insight for the user.
    """
    return await ai_tools_service.generate_daily_insight(user_id)

# --- End Analytics Routes ---


# ============== Request/Response Models ==============

class AgentRequest(BaseModel):
    query: str
    context: dict = {}
    user_id: Optional[str] = None

class AgenticChatRequest(BaseModel):
    """Request model for agentic chat with tool execution"""
    query: str
    user_context: Optional[dict] = None
    conversation_history: Optional[List[dict]] = None
    user_id: Optional[str] = None


class DeepResearchRequest(BaseModel):
    """Request model for deep agentic research"""
    query: str
    user_context: Optional[dict] = None
    max_iterations: int = 3
    user_id: Optional[str] = None

class ActionConfirmRequest(BaseModel):
    """Request to confirm and execute an AI-suggested action"""
    action_type: str
    action_data: dict
    user_id: Optional[str] = None


class SIPRequest(BaseModel):
    monthly_investment: float
    expected_rate: float  # Annual rate in %
    duration_months: int


class FDRequest(BaseModel):
    principal: float
    rate: float  # Annual rate in %
    tenure_months: int
    compounding: str = "quarterly"


class EMIRequest(BaseModel):
    principal: float
    rate: float  # Annual rate in %
    tenure_months: int
    include_amortization: bool = False


class RDRequest(BaseModel):
    monthly_deposit: float
    rate: float  # Annual rate in %
    tenure_months: int


class GoalSIPRequest(BaseModel):
    target_amount: float
    duration_months: int
    expected_rate: float


class LumpsumRequest(BaseModel):
    principal: float
    rate: float
    duration_years: int


class CAGRRequest(BaseModel):
    initial_value: float
    final_value: float
    years: float


class CategorizeRequest(BaseModel):
    description: str
    amount: float
    tx_type: str = "expense"


class BatchCategorizeRequest(BaseModel):
    transactions: List[Dict[str, Any]]


class AnalyzeSpendingRequest(BaseModel):
    transactions: List[Dict[str, Any]]


# ============== CRUD Request Models ==============

class CreateBudgetRequest(BaseModel):
    user_id: str
    name: str
    amount: float
    category: str
    icon: str = "wallet"
    period: str = "monthly"
    start_date: Optional[str] = None

class UpdateBudgetRequest(BaseModel):
    name: Optional[str] = None
    amount: Optional[float] = None
    spent: Optional[float] = None
    icon: Optional[str] = None
    category: Optional[str] = None

class CreateGoalRequest(BaseModel):
    user_id: str
    name: str
    target_amount: float
    deadline: Optional[str] = None
    icon: str = "flag"
    notes: Optional[str] = None

class UpdateGoalRequest(BaseModel):
    name: Optional[str] = None
    target_amount: Optional[float] = None
    deadline: Optional[str] = None
    status: Optional[str] = None
    icon: Optional[str] = None
    notes: Optional[str] = None

class AddFundsRequest(BaseModel):
    amount: float

class CreateTransactionRequest(BaseModel):
    user_id: str
    amount: float
    description: str
    category: str
    type: str  # 'income' or 'expense'
    date: Optional[str] = None
    payment_method: Optional[str] = None
    notes: Optional[str] = None
    receipt_url: Optional[str] = None
    is_recurring: bool = False

class UpdateTransactionRequest(BaseModel):
    amount: Optional[float] = None
    description: Optional[str] = None
    category: Optional[str] = None
    type: Optional[str] = None
    date: Optional[str] = None
    payment_method: Optional[str] = None
    notes: Optional[str] = None

class CreateScheduledPaymentRequest(BaseModel):
    user_id: str
    name: str
    amount: float
    category: str
    frequency: str = "monthly"
    due_date: str
    is_autopay: bool = False
    reminder_days: int = 3
    notes: Optional[str] = None

class UpdateScheduledPaymentRequest(BaseModel):
    name: Optional[str] = None
    amount: Optional[float] = None
    category: Optional[str] = None
    frequency: Optional[str] = None
    is_autopay: Optional[bool] = None
    reminder_days: Optional[int] = None
    status: Optional[str] = None
    notes: Optional[str] = None


# ============== Health Check ==============

@app.get("/")
def read_root():
    return {
        "status": "active",
        "service": "WealthIn Agent",
        "version": "3.0.0",
        "endpoints": [
            "/agent/chat",
            "/agent/agentic-chat",
            "/agent/confirm-action",
            "/agent/tools",
            "/agent/scan-document",
            "/calculator/sip",
            "/calculator/fd",
            "/calculator/emi",
            "/calculator/rd",
            "/calculator/lumpsum",
            "/calculator/cagr",
            "/calculator/goal-sip",
            "/categorize",
            "/categorize/batch",
            "/analyze/spending"
        ]
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


# ============== AI Chat Endpoints ==============

@app.post("/agent/chat")
async def agent_chat(request: AgentRequest):
    """
    Chat with the AI financial advisor.
    Supports context-aware conversations with user transaction history.
    """
    context_str = str(request.context) if request.context else ""
    
    # Build enhanced prompt with financial context
    system_context = """You are WealthIn, a friendly AI financial advisor for Indian entrepreneurs.
You can help with:
- Budgeting and expense tracking
- Investment advice (SIP, FD, mutual funds)
- Tax planning and GST
- Business finance tips
- Debt management

Be concise, helpful, and use Indian Rupee (₹) for amounts."""
    
    full_context = f"{system_context}\n\nUser Context: {context_str}"
    
    # Use the AI tools service for chat
    result = await ai_tools_service.process_with_tools(request.query, {"context": context_str})
    return {"response": result.response, "user_id": request.user_id}


@app.post("/agent/agentic-chat")
async def agentic_chat(request: AgenticChatRequest):
    """
    Agentic chat with tool/function calling capabilities.
    Uses OpenAI for function calling to execute financial actions.
    
    Returns:
    - response: The AI's response text
    - action_taken: Whether an action was executed
    - action_type: Type of action (create_budget, add_transaction, etc.)
    - action_data: Data for the action (to be saved by Flutter)
    - needs_confirmation: Whether Flutter should show a confirmation dialog
    """
    try:
        result = await ai_tools_service.process_with_tools(
            query=request.query,
            user_context=request.user_context
        )
        
        return {
            "response": result.response,
            "action_taken": result.action_taken,
            "action_type": result.action_type,
            "action_data": result.action_data,
            "needs_confirmation": result.needs_confirmation,
            "user_id": request.user_id
        }
    except Exception as e:
        return {
            "response": f"I'm having trouble processing your request: {str(e)}",
            "action_taken": False,
            "error": str(e)
        }


@app.post("/agent/confirm-action")
async def confirm_action(request: ActionConfirmRequest):
    """
    Confirm and finalize an AI-suggested action.
    Called by Flutter after user confirms an action.
    
    Note: Actual data persistence happens in Flutter (local DB).
    This endpoint just validates and returns success confirmation.
    """
    return {
        "success": True,
        "message": f"Action '{request.action_type}' confirmed. Data saved locally.",
        "action_type": request.action_type,
        "action_data": request.action_data
    }


@app.get("/agent/tools")
async def get_available_tools():
    """Get list of available AI tools/actions."""
    from services.ai_tools_service import FINANCIAL_TOOLS
    return {
        "tools": [
            {"name": tool["name"], "description": tool["description"]}
            for tool in FINANCIAL_TOOLS
        ]
    }


@app.post("/agent/scan-document")
async def scan_document(file: UploadFile = File(...)):
    """
    Scan and extract transactions from PDF bank statements.
    Supports HDFC, ICICI, SBI, and generic formats.
    """
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")
    
    # Use tempfile for safe file handling
    with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as tmp:
        tmp.write(await file.read())
        temp_path = tmp.name
    
    try:
        # Use AdvancedPDFParser for robust extraction
        # It handles Text, Tables, OCR, and PhonePe formats
        result = await pdf_parser_service.extract_transactions(temp_path, document_type='auto')
        transactions = result.get('transactions', [])
        
        # Auto-categorize extracted transactions if category is missing or 'Uncategorized'
        # The parser already does some categorization, but we can enhance it with AI
        for tx in transactions:
            if not tx.get('category') or tx.get('category') in ['Uncategorized', 'Miscellaneous']:
                pass # Let AI categorizer handle it if needed
                
        # Format for response (ensure all fields are present)
        formatted_transactions = []
        for tx in transactions:
            # tx is a dict because extract_transactions returns list of dicts (via asdict)
            formatted_transactions.append({
                "date": tx.get('date'),
                "description": tx.get('description'),
                "amount": tx.get('amount'),
                "type": tx.get('transaction_type', 'expense'),
                "category": tx.get('category', 'Uncategorized'),
                "merchant": tx.get('merchant'),
                "source": tx.get('source')
            })
            
        if formatted_transactions:
            formatted_transactions = await transaction_categorizer.categorize_batch(formatted_transactions)
        
        return {
            "filename": file.filename,
            "transactions": formatted_transactions,
            "count": len(formatted_transactions),
            "note": f"Extracted using {', '.join(result.get('method', []))}",
            "metadata": {
                "document_type": result.get('document_type'),
                "bank_detected": result.get('bank')
            }
        }
    except Exception as e:
        logger.error(f"Error scanning document: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)


@app.post("/agent/scan-receipt")
async def scan_receipt(file: UploadFile = File(...)):
    """
    PERCEPTION LAYER: Scan a receipt image using Zoho Vision.
    Extracts structured data: merchant, amount, items, category.
    Triggers when user takes a photo of a physical receipt.
    """
    allowed_types = [".jpg", ".jpeg", ".png", ".webp"]
    ext = os.path.splitext(file.filename or "")[1].lower()
    
    if ext not in allowed_types:
        raise HTTPException(
            status_code=400, 
            detail=f"Unsupported image format. Use: {', '.join(allowed_types)}"
        )
    
    try:
        image_bytes = await file.read()
        
        if zoho_vision_service.is_configured:
            # Use Zoho Vision for high-quality OCR
            receipt = await zoho_vision_service.extract_receipt(image_bytes, file.filename)
            
            return {
                "success": True,
                "source": "zoho_vision",
                "data": {
                    "merchant_name": receipt.merchant_name,
                    "date": receipt.date,
                    "total_amount": receipt.total_amount,
                    "currency": receipt.currency,
                    "items": receipt.items,
                    "category": receipt.category,
                    "payment_method": receipt.payment_method,
                    "confidence": receipt.confidence,
                },
                "suggested_transaction": {
                    "description": f"{receipt.merchant_name}",
                    "amount": receipt.total_amount,
                    "type": "expense",
                    "category": receipt.category or "Shopping",
                    "date": receipt.date,
                }
            }
        else:
            # Fallback: Use Gemini for basic extraction
            import base64
            image_b64 = base64.b64encode(image_bytes).decode('utf-8')
            
            prompt = f"Extract merchant name, total amount, and date from this receipt. Return as JSON."
            # Note: Gemini multimodal would need different implementation
            
            return {
                "success": False,
                "source": "fallback",
                "error": "Zoho Vision not configured. Please set ZOHO_CLIENT_ID and ZOHO_CLIENT_SECRET.",
                "data": None
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/agent/indic-chat")
async def indic_chat(request: AgentRequest):
    """
    COGNITION LAYER: Chat in Indian regional languages using Sarvam AI.
    Provides culturally relevant financial advice in Hindi, Telugu, Tamil, etc.
    """
    if not sarvam_service.is_configured:
        # Fallback to OpenAI/Gemini
        return await agent_chat(request)
    
    try:
        detected_lang = sarvam_service.detect_language(request.query)
        is_indic = sarvam_service.is_indic_query(request.query)
        
        if is_indic:
            response = await sarvam_service.get_financial_advice_indic(
                request.query,
                detected_lang
            )
            return {
                "response": response,
                "language": detected_lang,
                "source": "sarvam",
                "user_id": request.user_id
            }
        else:
            # Not Indic, use regular chat
            return await agent_chat(request)
            
    except Exception as e:
        # Fallback on error
        return await agent_chat(request)


@app.post("/agent/deep-research")
async def deep_research(request: DeepResearchRequest):
    """
    Deep Research Agentic Loop.
    Performs multi-step research: PLAN → SEARCH → BROWSE → REFLECT → SYNTHESIZE.
    
    Returns:
    - report: Comprehensive research report (markdown)
    - sources: List of URLs referenced
    - status_log: Step-by-step execution log for UI streaming
    - iterations: Number of research iterations performed
    """
    try:
        agent = get_deep_research_agent()
        result = await agent.research(
            query=request.query,
            context=request.user_context,
        )
        
        return {
            "success": True,
            "report": result.get("report", ""),
            "sources": result.get("sources", []),
            "status_log": result.get("status_log", []),
            "iterations": result.get("iterations", 0),
            "user_id": request.user_id,
        }
    except Exception as e:
        logger.error(f"Deep research error: {e}")
        return {
            "success": False,
            "error": str(e),
            "report": f"Research failed: {str(e)}",
            "sources": [],
            "status_log": [f"❌ Error: {str(e)}"],
        }


# ============== Investment Calculator Endpoints ==============

@app.post("/calculator/sip")
async def calculate_sip(request: SIPRequest) -> dict:
    """
    Calculate SIP (Systematic Investment Plan) returns.
    """
    result = investment_calculator.calculate_sip(
        monthly_investment=request.monthly_investment,
        expected_rate=request.expected_rate,
        duration_months=request.duration_months
    )
    return {
        "monthly_investment": result.monthly_investment,
        "duration_months": result.duration_months,
        "expected_rate": result.expected_rate,
        "total_invested": result.total_invested,
        "future_value": result.future_value,
        "wealth_gained": result.wealth_gained,
        "returns_percentage": round((result.wealth_gained / result.total_invested) * 100, 2) if result.total_invested > 0 else 0
    }


@app.post("/calculator/fd")
async def calculate_fd(request: FDRequest) -> dict:
    """
    Calculate Fixed Deposit maturity amount.
    """
    result = investment_calculator.calculate_fd(
        principal=request.principal,
        rate=request.rate,
        tenure_months=request.tenure_months,
        compounding=request.compounding
    )
    return {
        "principal": result.principal,
        "rate": result.rate,
        "tenure_months": result.tenure_months,
        "maturity_amount": result.maturity_amount,
        "interest_earned": result.interest_earned,
        "effective_annual_rate": result.effective_annual_rate
    }


@app.post("/calculator/emi")
async def calculate_emi(request: EMIRequest) -> dict:
    """
    Calculate EMI (Equated Monthly Installment) for loans.
    """
    result = investment_calculator.calculate_emi(
        principal=request.principal,
        rate=request.rate,
        tenure_months=request.tenure_months,
        include_amortization=request.include_amortization
    )
    return {
        "principal": result.principal,
        "rate": result.rate,
        "tenure_months": result.tenure_months,
        "emi": result.emi,
        "total_payment": result.total_payment,
        "total_interest": result.total_interest,
        "amortization_schedule": result.amortization_schedule if request.include_amortization else []
    }


@app.post("/calculator/rd")
async def calculate_rd(request: RDRequest) -> dict:
    """
    Calculate RD (Recurring Deposit) maturity amount.
    """
    result = investment_calculator.calculate_rd(
        monthly_deposit=request.monthly_deposit,
        rate=request.rate,
        tenure_months=request.tenure_months
    )
    return {
        "monthly_deposit": result.monthly_deposit,
        "rate": result.rate,
        "tenure_months": result.tenure_months,
        "maturity_amount": result.maturity_amount,
        "total_deposited": result.total_deposited,
        "interest_earned": result.interest_earned
    }


@app.post("/calculator/lumpsum")
async def calculate_lumpsum(request: LumpsumRequest) -> dict:
    """
    Calculate lumpsum investment returns.
    """
    return investment_calculator.calculate_lumpsum(
        principal=request.principal,
        rate=request.rate,
        duration_years=request.duration_years
    )


@app.post("/calculator/cagr")
async def calculate_cagr(request: CAGRRequest) -> dict:
    """
    Calculate CAGR (Compound Annual Growth Rate).
    """
    cagr = investment_calculator.calculate_cagr(
        initial_value=request.initial_value,
        final_value=request.final_value,
        years=request.years
    )
    return {
        "initial_value": request.initial_value,
        "final_value": request.final_value,
        "years": request.years,
        "cagr": cagr
    }


@app.post("/calculator/goal-sip")
async def calculate_goal_sip(request: GoalSIPRequest) -> dict:
    """
    Calculate required monthly SIP to reach a financial goal.
    """
    monthly_sip = investment_calculator.calculate_goal_sip(
        target_amount=request.target_amount,
        duration_months=request.duration_months,
        expected_rate=request.expected_rate
    )
    return {
        "target_amount": request.target_amount,
        "duration_months": request.duration_months,
        "expected_rate": request.expected_rate,
        "required_monthly_sip": monthly_sip
    }


# ============== Categorization Endpoints ==============

@app.post("/categorize")
async def categorize_transaction(request: CategorizeRequest) -> dict:
    """
    Categorize a single transaction using AI.
    """
    category = await transaction_categorizer.categorize_single(
        description=request.description,
        amount=request.amount,
        tx_type=request.tx_type
    )
    return {
        "description": request.description,
        "amount": request.amount,
        "type": request.tx_type,
        "category": category
    }


@app.post("/categorize/batch")
async def categorize_batch(request: BatchCategorizeRequest) -> dict:
    """
    Categorize multiple transactions efficiently.
    """
    categorized = await transaction_categorizer.categorize_batch(request.transactions)
    return {
        "transactions": categorized,
        "count": len(categorized)
    }


# ============== BUDGET CRUD Endpoints ==============

@app.post("/budgets")
async def create_budget(request: CreateBudgetRequest):
    """Create a new budget"""
    from datetime import datetime
    budget = Budget(
        id=None,
        user_id=request.user_id,
        name=request.name,
        amount=request.amount,
        spent=0,
        icon=request.icon,
        category=request.category,
        period=request.period,
        start_date=request.start_date or datetime.utcnow().date().isoformat(),
        end_date=None,
        created_at='',
        updated_at=''
    )
    created = await database_service.create_budget(budget)
    return {"success": True, "budget": created.__dict__}


@app.get("/budgets/{user_id}")
async def get_budgets(user_id: str):
    """Get all budgets for a user"""
    budgets = await database_service.get_budgets(user_id)
    return {"budgets": [b.__dict__ for b in budgets], "count": len(budgets)}


@app.get("/budgets/{user_id}/{budget_id}")
async def get_budget(user_id: str, budget_id: int):
    """Get a specific budget"""
    budget = await database_service.get_budget(budget_id, user_id)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    return {"budget": budget.__dict__}


@app.put("/budgets/{user_id}/{budget_id}")
async def update_budget(user_id: str, budget_id: int, request: UpdateBudgetRequest):
    """Update a budget"""
    updates = {k: v for k, v in request.dict().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")
    
    budget = await database_service.update_budget(budget_id, user_id, updates)
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    return {"success": True, "budget": budget.__dict__}


@app.delete("/budgets/{user_id}/{budget_id}")
async def delete_budget(user_id: str, budget_id: int):
    """Delete a budget"""
    deleted = await database_service.delete_budget(budget_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Budget not found")
    return {"success": True, "message": "Budget deleted"}


# ============== GOAL CRUD Endpoints ==============

@app.post("/goals")
async def create_goal(request: CreateGoalRequest):
    """Create a new savings goal"""
    goal = Goal(
        id=None,
        user_id=request.user_id,
        name=request.name,
        target_amount=request.target_amount,
        current_amount=0,
        deadline=request.deadline,
        status='active',
        icon=request.icon,
        notes=request.notes,
        created_at='',
        updated_at=''
    )
    created = await database_service.create_goal(goal)
    return {"success": True, "goal": created.__dict__}


@app.get("/goals/{user_id}")
async def get_goals(user_id: str):
    """Get all goals for a user"""
    goals = await database_service.get_goals(user_id)
    return {"goals": [g.__dict__ for g in goals], "count": len(goals)}


@app.get("/goals/{user_id}/{goal_id}")
async def get_goal(user_id: str, goal_id: int):
    """Get a specific goal"""
    goal = await database_service.get_goal(goal_id, user_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    return {"goal": goal.__dict__}


@app.put("/goals/{user_id}/{goal_id}")
async def update_goal(user_id: str, goal_id: int, request: UpdateGoalRequest):
    """Update a goal"""
    updates = {k: v for k, v in request.dict().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")
    
    goal = await database_service.update_goal(goal_id, user_id, updates)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    return {"success": True, "goal": goal.__dict__}


@app.post("/goals/{user_id}/{goal_id}/add-funds")
async def add_funds_to_goal(user_id: str, goal_id: int, request: AddFundsRequest):
    """Add funds to a savings goal"""
    goal = await database_service.add_funds_to_goal(goal_id, user_id, request.amount)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    return {
        "success": True, 
        "goal": goal.__dict__,
        "message": f"Added ₹{request.amount:,.2f} to {goal.name}"
    }


@app.delete("/goals/{user_id}/{goal_id}")
async def delete_goal(user_id: str, goal_id: int):
    """Delete a goal"""
    deleted = await database_service.delete_goal(goal_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Goal not found")
    return {"success": True, "message": "Goal deleted"}


# ============== TRANSACTION CRUD Endpoints ==============

@app.post("/transactions")
async def create_transaction(request: CreateTransactionRequest):
    """Create a new transaction"""
    from datetime import datetime
    
    # Auto-categorize if category not provided meaningfully
    if request.category == 'uncategorized' or not request.category:
        category = await transaction_categorizer.categorize_single(
            request.description, request.amount, request.type
        )
    else:
        category = request.category
    
    transaction = Transaction(
        id=None,
        user_id=request.user_id,
        amount=request.amount,
        description=request.description,
        category=category,
        type=request.type,
        date=request.date or datetime.utcnow().date().isoformat(),
        payment_method=request.payment_method,
        notes=request.notes,
        receipt_url=request.receipt_url,
        is_recurring=request.is_recurring,
        created_at=''
    )
    created = await database_service.create_transaction(transaction)
    return {"success": True, "transaction": created.__dict__}


@app.get("/transactions/{user_id}")
async def get_transactions(
    user_id: str, 
    limit: int = 50, 
    offset: int = 0,
    category: Optional[str] = None,
    type: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Get transactions with optional filtering"""
    transactions = await database_service.get_transactions(
        user_id, limit, offset, category, type, start_date, end_date
    )
    return {"transactions": [t.__dict__ for t in transactions], "count": len(transactions)}


@app.get("/transactions/{user_id}/{transaction_id}")
async def get_transaction(user_id: str, transaction_id: int):
    """Get a specific transaction"""
    transaction = await database_service.get_transaction(transaction_id, user_id)
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return {"transaction": transaction.__dict__}


@app.put("/transactions/{user_id}/{transaction_id}")
async def update_transaction(user_id: str, transaction_id: int, request: UpdateTransactionRequest):
    """Update a transaction"""
    updates = {k: v for k, v in request.dict().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")
    
    transaction = await database_service.update_transaction(transaction_id, user_id, updates)
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return {"success": True, "transaction": transaction.__dict__}


@app.delete("/transactions/{user_id}/{transaction_id}")
async def delete_transaction(user_id: str, transaction_id: int):
    """Delete a transaction"""
    deleted = await database_service.delete_transaction(transaction_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return {"success": True, "message": "Transaction deleted"}


@app.get("/transactions/{user_id}/summary")
async def get_spending_summary(user_id: str, start_date: str, end_date: str):
    """Get spending summary for a date range"""
    summary = await database_service.get_spending_summary(user_id, start_date, end_date)
    return {"summary": summary}


# ============== SCHEDULED PAYMENT CRUD Endpoints ==============

@app.post("/scheduled-payments")
async def create_scheduled_payment(request: CreateScheduledPaymentRequest):
    """Create a new scheduled payment"""
    payment = ScheduledPayment(
        id=None,
        user_id=request.user_id,
        name=request.name,
        amount=request.amount,
        category=request.category,
        frequency=request.frequency,
        due_date=request.due_date,
        next_due_date=request.due_date,  # Initially same as due_date
        is_autopay=request.is_autopay,
        status='active',
        reminder_days=request.reminder_days,
        last_paid_date=None,
        notes=request.notes,
        created_at='',
        updated_at=''
    )
    created = await database_service.create_scheduled_payment(payment)
    return {"success": True, "payment": created.__dict__}


@app.get("/scheduled-payments/{user_id}")
async def get_scheduled_payments(user_id: str, status: Optional[str] = None):
    """Get all scheduled payments for a user"""
    payments = await database_service.get_scheduled_payments(user_id, status)
    return {"payments": [p.__dict__ for p in payments], "count": len(payments)}


@app.get("/scheduled-payments/{user_id}/{payment_id}")
async def get_scheduled_payment(user_id: str, payment_id: int):
    """Get a specific scheduled payment"""
    payment = await database_service.get_scheduled_payment(payment_id, user_id)
    if not payment:
        raise HTTPException(status_code=404, detail="Scheduled payment not found")
    return {"payment": payment.__dict__}


@app.put("/scheduled-payments/{user_id}/{payment_id}")
async def update_scheduled_payment(user_id: str, payment_id: int, request: UpdateScheduledPaymentRequest):
    """Update a scheduled payment"""
    updates = {k: v for k, v in request.dict().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")
    
    payment = await database_service.update_scheduled_payment(payment_id, user_id, updates)
    if not payment:
        raise HTTPException(status_code=404, detail="Scheduled payment not found")
    return {"success": True, "payment": payment.__dict__}


@app.post("/scheduled-payments/{user_id}/{payment_id}/mark-paid")
async def mark_payment_paid(user_id: str, payment_id: int):
    """Mark a scheduled payment as paid"""
    payment = await database_service.mark_payment_paid(payment_id, user_id)
    if not payment:
        raise HTTPException(status_code=404, detail="Scheduled payment not found")
    return {
        "success": True, 
        "payment": payment.__dict__,
        "message": f"Payment '{payment.name}' marked as paid. Next due: {payment.next_due_date}"
    }


@app.delete("/scheduled-payments/{user_id}/{payment_id}")
async def delete_scheduled_payment(user_id: str, payment_id: int):
    """Delete a scheduled payment"""
    deleted = await database_service.delete_scheduled_payment(payment_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Scheduled payment not found")
    return {"success": True, "message": "Scheduled payment deleted"}


@app.get("/scheduled-payments/{user_id}/upcoming")
async def get_upcoming_payments(user_id: str, days: int = 7):
    """Get payments due in the next N days"""
    payments = await database_service.get_upcoming_payments(user_id, days)
    return {"payments": [p.__dict__ for p in payments], "count": len(payments)}


# ============== DASHBOARD Endpoint ==============

@app.get("/dashboard/{user_id}")
async def get_dashboard(user_id: str, start_date: Optional[str] = None, end_date: Optional[str] = None):
    """Get aggregated dashboard data for a user"""
    data = await database_service.get_dashboard_data(user_id, start_date, end_date)
    return {"dashboard": data}


# ============== Transaction Import Endpoints ==============

@app.post("/transactions/import/pdf")
async def import_transactions_from_pdf(
    user_id: str,
    file: UploadFile = File(...)
):
    """
    Import transactions from a bank statement PDF.
    Uses intelligent parsing for Indian bank formats.
    """
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")
    
    temp_path = None
    try:
        # Save to temp file
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as tmp:
            tmp.write(await file.read())
            temp_path = tmp.name
        
        # Extract transactions using enhanced parser
        # Note: extract_transactions takes a file path
        result = await pdf_parser_service.extract_transactions(temp_path)
        
        if result.get('status') == 'error':
            raise HTTPException(status_code=400, detail=result.get('error', 'Failed to parse PDF'))
        
        # Save extracted transactions to database
        saved_transactions = []
        for tx in result['transactions']:
                # Use category from parser if available, else standard fallback
                category = tx.get('extra_data', {}).get('category', 'Other')
                
                transaction = Transaction(
                    id=None,
                    user_id=user_id,
                    amount=tx['amount'],
                    description=tx['description'],
                    category=category,
                    type=tx['transaction_type'],
                    date=tx['date'],
                    time=tx.get('extra_data', {}).get('time'),
                    merchant=tx.get('merchant'),
                    payment_method=result.get('bank', 'Unknown'),
                    notes=f"Imported from {file.filename}. Confidence: {tx.get('confidence', 0)}",
                    receipt_url=None,
                    is_recurring=False,
                    created_at=""
                )
                created = await database_service.create_transaction(transaction)
                saved_transactions.append(created.__dict__)
        
        return {
            "success": True,
            "bank_detected": result.get('bank', 'generic'),
            "imported_count": len(saved_transactions),
            "transactions": saved_transactions
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Import PDF error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)


@app.post("/transactions/import/image")
async def import_transaction_from_image(
    user_id: str,
    file: UploadFile = File(...)
):
    """
    Import a transaction from a receipt image using Vision OCR.
    Supports handwritten, scanned, and photographed receipts.
    Uses Zoho Catalyst VLM for intelligent extraction.
    """
    allowed_types = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"]
    ext = os.path.splitext(file.filename or "")[1].lower()
    
    if ext not in allowed_types:
        raise HTTPException(
            status_code=400, 
            detail=f"Unsupported image format. Use: {', '.join(allowed_types)}"
        )
    
    try:
        image_bytes = await file.read()
        
        if not zoho_vision_service.is_configured:
            raise HTTPException(
                status_code=503, 
                detail="Vision service not configured. Please set up Zoho Catalyst credentials."
            )
        
        # Extract receipt data using Zoho Vision
        receipt = await zoho_vision_service.extract_receipt(image_bytes, file.filename)
        
        # Auto-categorize based on merchant
        category = receipt.category or await transaction_categorizer.categorize_single(
            receipt.merchant_name,
            receipt.total_amount or 0.0,
            "expense"
        )
        
        # Create transaction
        transaction = Transaction(
            id=None,
            user_id=user_id,
            amount=receipt.total_amount,
            description=receipt.merchant_name or "Receipt",
            category=category,
            type='expense',
            date=receipt.date,
            payment_method=receipt.payment_method or 'Cash',
            notes=f"Items: {', '.join(receipt.items[:3]) if receipt.items else 'N/A'}",
            receipt_url=None,
            is_recurring=False,
            created_at=''
        )
        created = await database_service.create_transaction(transaction)
        
        return {
            "success": True,
            "source": "zoho_vision",
            "confidence": receipt.confidence,
            "extracted_data": {
                "merchant_name": receipt.merchant_name,
                "total_amount": receipt.total_amount,
                "date": receipt.date,
                "items": receipt.items,
                "category": category,
            },
            "transaction": created.__dict__
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/transactions/import/batch")
async def import_transactions_batch(
    user_id: str,
    transactions: List[Dict[str, Any]]
):
    """
    Import multiple transactions at once.
    Used after preview/confirmation in the Flutter app.
    """
    try:
        saved = []
        for tx_data in transactions:
            # Auto-categorize if needed
            category = tx_data.get('category', 'Other')
            if category in ['Other', 'uncategorized', '']:
                category = await transaction_categorizer.categorize_single(
                    tx_data.get('description', ''),
                    tx_data.get('amount', 0),
                    tx_data.get('type', 'expense')
                )
            
            transaction = Transaction(
                id=None,
                user_id=user_id,
                amount=tx_data.get('amount', 0),
                description=tx_data.get('description', ''),
                category=category,
                type=tx_data.get('type', 'expense'),
                date=tx_data.get('date', ''),
                payment_method=tx_data.get('payment_method', ''),
                notes=tx_data.get('notes', ''),
                receipt_url=None,
                is_recurring=False,
                created_at=''
            )
            created = await database_service.create_transaction(transaction)
            saved.append(created.__dict__)
        
        return {
            "success": True,
            "imported_count": len(saved),
            "transactions": saved
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== Trends Analysis Endpoints ==============

@app.get("/trends/{user_id}")
async def get_user_trends(user_id: str, period_days: int = 30):
    """
    Get comprehensive spending trends analysis for a user.
    Returns insights for the AI advisor to provide personalized responses.
    """
    from services.trends_service import trends_service
    
    try:
        # Fetch user transactions
        transactions = await database_service.get_transactions(
            user_id, limit=500, offset=0
        )
        
        # Convert to dict format
        tx_dicts = [t.__dict__ for t in transactions]
        
        # Analyze trends
        trends = await trends_service.analyze_transactions(tx_dicts, user_id, period_days)
        
        return {
            "success": True,
            "trends": trends_service.trends_to_dict(trends)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/trends/{user_id}/ai-context")
async def get_ai_context(user_id: str):
    """
    Get AI-ready context summary of user's financial trends.
    This is used by the AI advisor to provide personalized responses.
    """
    from services.trends_service import trends_service
    
    try:
        transactions = await database_service.get_transactions(
            user_id, limit=500, offset=0
        )
        tx_dicts = [t.__dict__ for t in transactions]
        
        trends = await trends_service.analyze_transactions(tx_dicts, user_id)
        
        return {
            "success": True,
            "ai_context": trends.ai_context,
            "summary": {
                "total_income": trends.total_income,
                "total_expenses": trends.total_expenses,
                "savings_rate": trends.savings_rate,
                "top_categories": [c['category'] for c in trends.top_spending_categories[:3]],
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============== Analysis Endpoints ==============

@app.post("/analyze/spending")
async def analyze_spending(request: AnalyzeSpendingRequest) -> dict:
    """
    Analyze spending patterns and provide category-wise breakdown.
    """
    # First, ensure all transactions are categorized
    categorized = await transaction_categorizer.categorize_batch(request.transactions)
    
    # Get spending by category
    spending_by_category = transaction_categorizer.get_spending_by_category(categorized)
    
    # Calculate totals
    total_expense = sum(
        tx.get("amount", 0) for tx in categorized 
        if tx.get("type") == "expense"
    )
    total_income = sum(
        tx.get("amount", 0) for tx in categorized 
        if tx.get("type") == "income"
    )
    
    # Generate AI insights
    insights = []
    if spending_by_category:
        top_category = list(spending_by_category.keys())[0]
        top_amount = spending_by_category[top_category]
        insights.append(f"Your highest spending category is {top_category} at ₹{top_amount:,.2f}")
        
        if total_income > 0:
            savings_rate = ((total_income - total_expense) / total_income) * 100
            if savings_rate < 20:
                insights.append("⚠️ Your savings rate is below 20%. Consider reducing discretionary spending.")
            elif savings_rate > 30:
                insights.append("✅ Great savings rate! Consider investing the surplus.")
    
    return {
        "spending_by_category": spending_by_category,
        "total_expense": round(total_expense, 2),
        "total_income": round(total_income, 2),
        "net_savings": round(total_income - total_expense, 2),
        "savings_rate": round(((total_income - total_expense) / total_income * 100), 2) if total_income > 0 else 0,
        "insights": insights,
        "transaction_count": len(categorized)
    }


# ============== LLM Inference Endpoints ==============

# LLM Inference Request/Response Models
class LLMInferenceRequest(BaseModel):
    """Request for LLM inference"""
    prompt: str
    tools: Optional[List[Dict[str, Any]]] = Field(default=None, description="Available tools/functions")
    max_tokens: int = Field(default=2048, description="Maximum tokens to generate")
    temperature: float = Field(default=0.7, description="Temperature for sampling (0.0-1.0)")
    format: str = Field(default="nemotron", description="Response format: nemotron, openai, or raw")

class ToolCall(BaseModel):
    """Tool call extracted from model response"""
    name: str
    arguments: Dict[str, Any]

class NemotronResponse(BaseModel):
    """Response in Nemotron function calling format"""
    text: str
    tool_call: Optional[ToolCall] = None
    finish_reason: str = Field(default="stop")
    tokens_used: int = Field(default=0)
    is_local: bool = Field(default=False)
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

class LLMInferenceResponse(BaseModel):
    """Response from LLM inference"""
    success: bool
    response: Optional[str] = None
    tool_call: Optional[ToolCall] = None
    tokens_used: int = 0
    mode: str = Field(default="cloud", description="Which inference mode was used")
    error: Optional[str] = None

# ============== LLM Inference Routes ==============

@app.post("/llm/inference")
async def llm_inference(request: LLMInferenceRequest) -> LLMInferenceResponse:
    """
    Perform LLM inference with tool calling support
    
    Supports Nemotron function calling format:
    {"type": "tool_call", "tool_call": {"name": "...", "arguments": {...}}}
    
    This endpoint is called by the Flutter frontend's LLMInferenceRouter
    when local inference is not available.
    """
    try:
        print(f"[LLM] Inference request: {request.prompt[:100]}...")
        print(f"[LLM] Format: {request.format}, Tools: {len(request.tools or [])}")
        
        # TODO: Implement actual LLM inference using:
        # - ollama for Sarvam-1 local models
        # - Hugging Face transformers for other models
        # - Optional cloud API fallback
        
        # For now, return a mock response indicating that the endpoint works
        # In production, this would call the actual LLM
        
        # Extract potential tool calls from the response
        tool_call = None
        # Tool extraction logic would go here
        
        response_text = f"Mock inference response: {request.prompt}"
        
        return LLMInferenceResponse(
            success=True,
            response=response_text,
            tool_call=tool_call,
            tokens_used=len(request.prompt.split()),
            mode="cloud-nemotron",
            error=None
        )
        
    except Exception as e:
        print(f"[LLM] Inference error: {e}")
        return LLMInferenceResponse(
            success=False,
            response=None,
            tool_call=None,
            tokens_used=0,
            mode="cloud-nemotron",
            error=str(e)
        )

@app.post("/llm/parse-tool-call")
async def parse_tool_call(response: str = ""):
    """
    Parse tool calls from LLM response (Nemotron format)
    
    Expected format:
    {"type": "tool_call", "tool_call": {"name": "create_budget", "arguments": {...}}}
    """
    try:
        if not response:
            return {"success": False, "error": "Empty response"}
        
        # Try to extract JSON from response
        import re
        regex = re.compile(r'\{[\s\S]*\}')
        match = regex.search(response)
        
        if not match:
            return {"success": False, "error": "No JSON found in response"}
        
        json_str = match.group(0)
        data = json.loads(json_str)
        
        # Check for Nemotron format
        if data.get('type') == 'tool_call' and data.get('tool_call'):
            tool_call = data['tool_call']
            return {
                "success": True,
                "tool_call": {
                    "name": tool_call.get('name'),
                    "arguments": tool_call.get('arguments', {})
                }
            }
        
        return {"success": False, "error": "Not a valid Nemotron tool call"}
        
    except json.JSONDecodeError as e:
        return {"success": False, "error": f"JSON parse error: {e}"}
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.get("/llm/status")
async def llm_status():
    """
    Get LLM inference status and capabilities
    """
    return {
        "status": "available",
        "modes": ["local-nemotron", "cloud-nemotron", "openai-fallback"],
        "default_mode": "cloud-nemotron",
        "format": "nemotron-function-calling",
        "max_tokens": 4096,
        "supported_models": [
            "sarvam-1-1b-q4",
            "sarvam-1-3b-q4",
            "sarvam-1-full"
        ],
        "endpoints": {
            "inference": "/llm/inference",
            "parse": "/llm/parse-tool-call",
            "status": "/llm/status"
        }
    }


# ============== New Web Search & PDF Endpoints ==============

@app.post("/search/finance")
async def search_finance(
    query: str,
    limit: int = 5,
    category: Optional[str] = None,
):
    """
    Search for financial news, tax updates, investment info
    
    Categories: finance_news, tax, investment, schemes, interest_rates
    Returns cached results when available (6-12h TTL)
    """
    from services.web_search_service import web_search_service
    
    try:
        results = await web_search_service.search_finance_news(
            query,
            limit=limit,
            category=category
        )
        
        return {
            "success": True,
            "query": query,
            "category": category,
            "results_count": len(results),
            "results": [
                {
                    "title": r.title,
                    "url": r.url,
                    "snippet": r.snippet,
                    "date": r.date,
                    "relevance": r.relevance_score,
                }
                for r in results
            ]
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "results": []
        }


@app.post("/search/tax-updates")
async def search_tax_updates(query: str = "income tax India 2025", limit: int = 5):
    """Search for current tax updates and guidelines"""
    from services.web_search_service import web_search_service
    
    results = await web_search_service.search_tax_updates(query, limit)
    return {
        "success": True,
        "category": "tax",
        "results_count": len(results),
        "results": [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
            }
            for r in results
        ]
    }


@app.post("/search/schemes")
async def search_schemes(query: str, limit: int = 5):
    """Search for government schemes and benefits"""
    from services.web_search_service import web_search_service
    
    results = await web_search_service.search_schemes(query, limit)
    return {
        "success": True,
        "category": "schemes",
        "query": query,
        "results_count": len(results),
        "results": [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
            }
            for r in results
        ]
    }


@app.post("/search/interest-rates")
async def search_interest_rates(query: str = "current interest rates India", limit: int = 5):
    """Search for current interest rates and market data"""
    from services.web_search_service import web_search_service
    
    results = await web_search_service.search_interest_rates(query, limit)
    return {
        "success": True,
        "category": "interest_rates",
        "results_count": len(results),
        "results": [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
            }
            for r in results
        ]
    }


# ============== Advanced PDF Parsing with OCR ==============

@app.post("/extract-transactions")
async def extract_transactions_advanced(
    file: UploadFile = File(...),
    document_type: str = "auto",  # auto, receipt, bank_statement
):
    """
    Extract transactions from PDF with OCR and multi-method parsing
    
    Supports:
    - Bank statements (HDFC, SBI, ICICI, Axis)
    - Receipts (e-commerce, restaurants, retail)
    - Invoices
    
    Methods used (in order):
    1. Table extraction (most reliable for structured data)
    2. OCR for scanned documents
    3. Pattern matching for unstructured text
    """
    from services.pdf_parser_advanced import pdf_parser_service
    import tempfile
    import os
    
    temp_filename = None
    try:
        # Save file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            content = await file.read()
            tmp.write(content)
            temp_filename = tmp.name
        
        # Extract transactions
        results = await pdf_parser_service.extract_transactions(
            temp_filename,
            document_type=document_type
        )
        
        return results
    
    except Exception as e:
        logger.error(f"PDF extraction error: {e}")
        return {
            "success": False,
            "error": str(e),
            "transactions": [],
            "count": 0,
        }
    
    finally:
        # Clean up temp file
        if temp_filename and os.path.exists(temp_filename):
            os.remove(temp_filename)


@app.post("/extract-receipt")
async def extract_receipt(file: UploadFile = File(...)):
    """
    Extract data from receipt image/PDF
    Returns: merchant, amount, date, items, category
    """
    from services.pdf_parser_advanced import ReceiptParser
    import tempfile
    import os
    import asyncio
    
    temp_filename = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            content = await file.read()
            tmp.write(content)
            temp_filename = tmp.name
        
        # Extract receipt data
        receipt_data = await asyncio.to_thread(
            ReceiptParser.extract_from_image,
            temp_filename
        )
        
        if not receipt_data:
            receipt_data = {}
        
        return {
            "success": bool(receipt_data),
            "merchant": receipt_data.get('merchant'),
            "amount": receipt_data.get('amount'),
            "date": receipt_data.get('date'),
            "category": receipt_data.get('category'),
            "items": receipt_data.get('items', []),
            "confidence": receipt_data.get('confidence', 0.8),
        }
    
    except Exception as e:
        logger.error(f"Receipt extraction error: {e}")
        return {
            "success": False,
            "error": str(e),
        }
    
    finally:
        if temp_filename and os.path.exists(temp_filename):
            os.remove(temp_filename)


# ============== Run Server ==============

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
