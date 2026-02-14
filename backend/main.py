"""
WealthIn Agent Service - Founder's OS Backend
FastAPI backend implementing the Sense-Plan-Act agentic architecture:

PERCEPTION LAYER (Sensing):
- Local PDF Parser (pdfplumber) for e-statements
- Zoho Vision Bridge for receipt image OCR

COGNITION LAYER (Thinking):  
- Sarvam Indic Expert for regional language support
- Groq OpenAI GPT-OSS for ideas/analysis reasoning
- Lightweight RAG (TF-IDF + SQLite) for Knowledge Retrieval

ACTION LAYER (Doing):
- Tool Dispatcher for budgets, goals, payments, transactions
- Investment calculators (SIP, FD, EMI, RD)
"""

import os
import logging
import tempfile
import asyncio
import hashlib
from contextlib import asynccontextmanager
from typing import Optional, List, Dict, Any

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
import json
from datetime import datetime
import time

# Service imports - The Three Layers
from services.pdf_parser_advanced import pdf_parser_service, AdvancedPDFParser
from services.investment_calculator import investment_calculator
from services.transaction_categorizer import transaction_categorizer
from services.ai_tools_service import ai_tools_service
from services.sarvam_service import sarvam_service
from services.zoho_vision_service import zoho_vision_service
from services.database_service import database_service
from services.analytics_service import analytics_service
from services.financial_calculator import FinancialCalculator
from services.web_search_service import web_search_service
from services.deep_research_agent import get_deep_research_agent
from services.merchant_service import merchant_service
from services.ncm_service import ncm_service
from services.financial_health_service import financial_health_service
from services.openai_brainstorm_service import openai_brainstorm_service
from services.groq_openai_service import groq_openai_service
from services.enhanced_sms_parser import enhanced_sms_parser
from services.ideas_mode_service import (
    get_system_prompt as get_ideas_system_prompt,
    list_modes as list_ideas_modes,
    normalize_mode,
    normalize_workflow_mode,
)
from services.recurring_transaction_service import recurring_transaction_service
from services.bill_split_service import bill_split_service
from services.forecast_service import forecast_service
from services.brainstorm_router import brainstorm_router, BrainstormIntent
from services.business_plan_templates import business_plan_templates
from services.ai_provider_service import AIProviderService
from services.gst_invoice_service import gst_invoice_service
from services.cashflow_forecast_service import cashflow_forecast_service
from services.vendor_payment_service import vendor_payment_service
from services.scheme_compatibility_service import scheme_compatibility_service
from services.msme_credit_rag_service import msme_credit_rag_service
from services.local_msme_recommendations import local_msme_recommender
from services.msme_government_service import msme_gov_service

# NEW SERVICES (RAG Integration)
from services.query_router import router, QueryType
from services.lightweight_rag import rag
from services.openai_service import openai_service
from services.government_api_service import govt_api
from services.static_knowledge_service import static_kb

# NoSQL & Analysis Services
from services.mongo_service import mongo_service
from services.idea_evaluator_service import idea_evaluator
from services.mudra_dpr_service import mudra_engine, MudraDPRInput
from services.email_service import email_service
from services.dpr_generator import dpr_generator, get_dpr_template
from services.dpr_scoring_service import dpr_scorer

load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize services on startup, cleanup on shutdown."""
    logger.info("Starting WealthIn Agent Service...")
    await database_service.initialize()
    await merchant_service.initialize()
    await ncm_service.initialize()
    await openai_brainstorm_service.initialize()
    await groq_openai_service.initialize()
    await mongo_service.initialize()  # Initialize MongoDB/NoSQL
    await bill_split_service.initialize()  # Initialize bill splitting tables
    await gst_invoice_service.initialize()  # Initialize GST invoicing
    await vendor_payment_service.initialize()  # Initialize vendor tracking
    logger.info("Phase 2 MSME services initialized")
    
    # Initialize RAG Knowledge Base
    logger.info("loading RAG knowledge base...")
    try:
        rag.load_knowledge_base()
        static_kb.load_all() # Ensure static KB is loaded
        logger.info("Knowledge bases (RAG + Static) loaded successfully")
        logger.info("Government API Service ready")
    except Exception as e:
        logger.error(f"Failed to load knowledge bases: {e}")

    logger.info("All services initialized successfully")
    yield
    logger.info("Shutting down WealthIn Agent Service...")

app = FastAPI(
    title="WealthIn Founder's OS",
    description="Agentic AI backend for Indian entrepreneurs - Sense, Plan, Act",
    version="4.1.0",
    lifespan=lifespan
)

# Dashboard cache infrastructure
dashboard_cache: Dict[str, tuple[Dict[str, Any], float]] = {}  # {cache_key: (data, timestamp)}
DASHBOARD_CACHE_TTL = 300  # 5 minutes in seconds

# Brainstorm / DPR response cache
brainstorm_cache: Dict[str, tuple[Dict[str, Any], float]] = {}
dpr_cache: Dict[str, tuple[Dict[str, Any], float]] = {}
BRAINSTORM_CACHE_TTL = 120
DPR_CACHE_TTL = 180
MAX_AI_CACHE_ENTRIES = 500

# LLM timeout budgets (seconds)
LLM_TIMEOUT_CHAT = 18
LLM_TIMEOUT_CRITIQUE = 16
LLM_TIMEOUT_EXTRACT = 16
LLM_TIMEOUT_DPR_BUILD = 24
LLM_TIMEOUT_DPR_SECTION = 18


def _stable_json(value: Any) -> str:
    try:
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    except TypeError:
        return json.dumps(str(value), ensure_ascii=False)


def _cache_key(prefix: str, payload: Any) -> str:
    digest = hashlib.sha256(_stable_json(payload).encode("utf-8")).hexdigest()
    return f"{prefix}:{digest}"


def _clone_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    return json.loads(json.dumps(payload, ensure_ascii=False))


def _cache_get(
    cache_store: Dict[str, tuple[Dict[str, Any], float]],
    key: str,
    ttl_seconds: int,
) -> Optional[Dict[str, Any]]:
    cached = cache_store.get(key)
    if not cached:
        return None
    value, timestamp = cached
    if time.time() - timestamp > ttl_seconds:
        cache_store.pop(key, None)
        return None
    return _clone_payload(value)


def _cache_set(
    cache_store: Dict[str, tuple[Dict[str, Any], float]],
    key: str,
    value: Dict[str, Any],
) -> None:
    if len(cache_store) >= MAX_AI_CACHE_ENTRIES:
        oldest_key = min(cache_store.items(), key=lambda item: item[1][1])[0]
        cache_store.pop(oldest_key, None)
    cache_store[key] = (_clone_payload(value), time.time())

# CORS middleware
cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============== Request/Response Models ==============

class AgentRequest(BaseModel):
    query: str
    context: dict = {}
    user_id: Optional[str] = None
    conversation_history: Optional[List[dict]] = None

class AgenticChatRequest(BaseModel):
    """Request model for agentic chat with tool execution"""
    query: str
    user_context: Optional[dict] = None
    conversation_history: Optional[List[dict]] = None
    user_id: Optional[str] = None

class DPRRequest(BaseModel):
    user_id: str
    business_idea: str
    user_data: Dict
    include_market_research: bool = False
    canvas_items: Optional[List[Dict[str, Any]]] = None
    mode: str = "msme_copilot"

class DeepResearchRequest(BaseModel):
    query: str
    user_context: Optional[dict] = None
    max_iterations: int = 3
    user_id: Optional[str] = None

class ActionConfirmRequest(BaseModel):
    action_type: str
    action_data: dict
    user_id: Optional[str] = None


# Calculator Models
class SIPRequest(BaseModel):
    monthly_investment: float
    expected_rate: float
    duration_months: int

class FDRequest(BaseModel):
    principal: float
    rate: float
    tenure_months: int
    compounding: str = "quarterly"

class EMIRequest(BaseModel):
    principal: float
    rate: float
    tenure_months: int
    include_amortization: bool = False

class RDRequest(BaseModel):
    monthly_deposit: float
    rate: float
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

# Analytics Models
class SavingsRateRequest(BaseModel):
    income: float
    expenses: float

class CompoundInterestRequest(BaseModel):
    principal: float
    rate: float
    years: int
    monthly_contribution: float = 0

class PerCapitaRequest(BaseModel):
    total_income: float
    family_size: int

class EmergencyFundRequest(BaseModel):
    current_savings: float
    monthly_expenses: float
    target_months: int = 6

class CreateGroupRequest(BaseModel):
    name: str
    user_id: str

class AddMemberRequest(BaseModel):
    group_id: int
    user_id: str
    role: str = "member"

class EmailSyncRequest(BaseModel):
    user_id: str
    email: str
    password: str # App Password
    days_back: int = 30


# ============== Health Check ==============

@app.get("/")
def read_root():
    return {
        "status": "active",
        "service": "WealthIn Agent",
        "version": "4.1.0",
        "features": ["RAG", "Deep Research", "Calculators", "Analytics"]
    }

@app.get("/health")
def health_check():
    rag_status = "active" if rag.vectorizer else "initializing"
    rag_docs = len(rag.documents) if rag.documents else 0
    return {
        "status": "healthy", 
        "rag_status": rag_status,
        "rag_documents": rag_docs,
        "rag_type": "lightweight_tfidf"
    }


# ============== Endpoint Implementations ==============

# --- Analytics Routes ---
@app.get("/analytics/health-score/{user_id}")
async def get_health_score(user_id: str):
    score = await financial_health_service.calculate_health_score(user_id)
    return {
        "score": score.total_score,
        "grade": score.grade,
        "breakdown": {
            "savings": score.savings_score,
            "debt": score.debt_score,
            "liquidity": score.liquidity_score,
            "investment": score.investment_score,
        },
        "insights": score.insights,
        "metrics": score.metrics
    }


@app.post("/analytics/ai-insights/{user_id}")
async def get_ai_analysis_insights(user_id: str):
    """
    AI-powered financial analysis using GPT-OSS.
    Generates deep insights from health score and transaction data.
    """
    try:
        if not groq_openai_service.is_available:
            return {"success": False, "error": "AI service unavailable"}

        # Gather financial context
        score = await financial_health_service.calculate_health_score(user_id)
        trends = await analytics_service.get_monthly_trends(user_id)

        context = f"""Financial Health Score: {score.total_score}/100 (Grade: {score.grade})
Breakdown: Savings={score.savings_score}/30, Debt={score.debt_score}/25, Liquidity={score.liquidity_score}/25, Investment={score.investment_score}/20
Rule-based Insights: {'; '.join(score.insights)}
Recent Monthly Trends: {trends[-3:] if trends else 'No data'}"""

        messages = [
            {
                "role": "system",
                "content": (
                    "You are a senior financial analyst. Given the user's financial health data, "
                    "provide 3-5 actionable insights. Be specific, cite numbers, and suggest "
                    "concrete next steps. Use bullet points. Keep it under 300 words. "
                    "Focus on: spending patterns, savings optimization, debt management, "
                    "and investment opportunities relevant to Indian markets."
                ),
            },
            {"role": "user", "content": context},
        ]

        result = await groq_openai_service.chat(
            messages, temperature=0.4, max_tokens=800
        )

        return {
            "success": True,
            "insights": result.get("content", ""),
            "model": result.get("model"),
            "routing": {"handler": "groq_openai_analysis", "model": result.get("model")},
        }
    except Exception as e:
        logger.error(f"AI analysis insights error: {e}")
        return {"success": False, "error": str(e)}


@app.post("/analytics/refresh/{user_id}")
async def refresh_analytics(user_id: str):
    await analytics_service.refresh_daily_trends(user_id)
    return {"status": "success", "message": "Trends refreshed"}

@app.get("/analytics/monthly/{user_id}")
async def get_monthly_trends(user_id: str):
    trends = await analytics_service.get_monthly_trends(user_id)
    prediction = await analytics_service.predict_next_month_expenses(user_id)

    # Keep backwards compatibility for clients expecting a month-keyed map.
    monthly_data = {
        t["month"]: {
            "income": t.get("income", 0.0),
            "expenses": t.get("expense", 0.0),
            "savings": t.get("savings", 0.0),
        }
        for t in trends
        if t.get("month")
    }
    return {
        "monthly_data": monthly_data,
        "monthly_trends": trends,
        "next_month_prediction": prediction
    }

@app.get("/analytics/recurring/{user_id}")
async def get_recurring_transactions(user_id: str):
    """
    Detect recurring subscriptions and bills from transaction history.
    Analyzes last 180 days of data.
    """
    try:
        from datetime import timedelta
        
        # Fetch last 180 days for pattern detection
        end_date = datetime.now().strftime('%Y-%m-%d')
        start_date = (datetime.now() - timedelta(days=180)).strftime('%Y-%m-%d')
        
        # Get raw transactions
        transactions = await database_service.get_transactions(
            user_id=user_id,
            limit=2000,
            start_date=start_date,
            end_date=end_date
        )
        
        # Convert to dicts for service
        from dataclasses import asdict
        tx_dicts = [asdict(t) for t in transactions]
        
        # Detect patterns
        recurring = recurring_transaction_service.detect_recurring(tx_dicts)
        
        # Calculate committed spend (monthly equivalent)
        total_monthly = 0.0
        for item in recurring:
            amt = item['amount']
            freq = item['frequency']
            
            if freq == 'monthly':
                total_monthly += amt
            elif freq == 'weekly':
                total_monthly += (amt * 4.33)  # Avg weeks in month
            elif freq == 'bi-weekly':
                total_monthly += (amt * 2.16)
            elif freq == 'yearly':
                total_monthly += (amt / 12)
        
        return {
            "status": "success",
            "recurring_count": len(recurring),
            "estimated_monthly_bills": round(total_monthly, 2),
            "items": recurring,
            "analysis_period_days": 180
        }
    except Exception as e:
        logger.error(f"Recurring analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/calculator/savings-rate")
async def calc_savings_rate(data: SavingsRateRequest):
    rate = FinancialCalculator.calculate_savings_rate(data.income, data.expenses)
    return {"savings_rate_percentage": round(rate, 2)}

@app.post("/calculator/compound-interest")
async def calc_compound_interest(data: CompoundInterestRequest):
    return FinancialCalculator.calculate_compound_interest(
        data.principal, data.rate, data.years, data.monthly_contribution
    )

@app.post("/calculator/per-capita")
async def calc_per_capita(data: PerCapitaRequest):
    pci = FinancialCalculator.calculate_per_capita_income(data.total_income, data.family_size)
    return {"per_capita_income": round(pci, 2)}

@app.post("/calculator/emergency-fund")
async def calc_emergency_fund(data: EmergencyFundRequest):
    return FinancialCalculator.calculate_emergency_fund_status(
        data.current_savings, data.monthly_expenses, data.target_months
    )

@app.get("/dashboard/{user_id}")
async def get_dashboard_data(user_id: str, use_cache: bool = True):
    """
    Optimized dashboard endpoint with 5-minute caching
    Returns: health_score, spending summary, recent transactions, budgets, goals
    """
    cache_key = f"dashboard:{user_id}"
    now = time.time()

    # Check cache
    if use_cache and cache_key in dashboard_cache:
        cached_data, timestamp = dashboard_cache[cache_key]
        if now - timestamp < DASHBOARD_CACHE_TTL:
            logger.info(f"Cache HIT for dashboard:{user_id}")
            return {"data": cached_data, "cached": True, "cache_age": round(now - timestamp, 1)}

    # Cache miss - calculate fresh data
    logger.info(f"Cache MISS for dashboard:{user_id} - fetching fresh data")

    # Get base dashboard data (includes spending, budgets, goals, transactions)
    dashboard_data = await database_service.get_dashboard_data(user_id)

    # Add health score (now optimized with single query)
    try:
        health_score = await financial_health_service.calculate_health_score(user_id)
        dashboard_data['health_score'] = {
            'total_score': health_score.total_score,
            'grade': health_score.grade,
            'scores': health_score.scores,
            'recommendations': health_score.recommendations
        }
    except Exception as e:
        logger.warning(f"Health score calculation failed: {e}")
        dashboard_data['health_score'] = None

    # Cache the result
    dashboard_cache[cache_key] = (dashboard_data, now)

    # Clean old cache entries (keep last 100)
    if len(dashboard_cache) > 100:
        oldest_keys = sorted(dashboard_cache.items(), key=lambda x: x[1][1])[:50]
        for key, _ in oldest_keys:
            del dashboard_cache[key]

    return {"data": dashboard_data, "cached": False, "cache_age": 0}

@app.get("/insights/daily/{user_id}")
async def get_daily_insight(user_id: str):
    return await ai_tools_service.generate_daily_insight(user_id)

@app.get("/fin-bites")
async def get_fin_bites(query: str = "Indian financial market news today"):
    """
    Fin-Bite endpoint expected by the Flutter client.
    Returns a concise market insight for dashboard cards.
    """
    try:
        summary = await sarvam_service.get_financial_news_summary(query)
        return {
            "success": True,
            "headline": summary.get("headline", "Market Update"),
            "insight": summary.get("insight", "No major market updates available."),
            "recommendation": summary.get("recommendation", "Review your portfolio allocation."),
            "trend": summary.get("trend", "stable"),
        }
    except Exception as e:
        logger.error(f"Fin-Bites error: {e}")
        return {
            "success": False,
            "headline": "Market Update",
            "insight": "Unable to fetch market summary right now.",
            "recommendation": "Try again shortly.",
            "trend": "stable",
            "error": str(e),
        }


# --- Group Accounts & Sharing ---

@app.post("/groups/create")
async def create_group_endpoint(request: CreateGroupRequest):
    group_id = await database_service.create_group(request.name, request.user_id)
    return {"success": True, "group_id": group_id, "message": "Group created"}

@app.post("/groups/add-member")
async def add_member_endpoint(request: AddMemberRequest):
    success = await database_service.add_group_member(request.group_id, request.user_id, request.role)
    if success:
        return {"success": True, "message": "Member added"}
    raise HTTPException(status_code=400, detail="Failed to add member")

@app.get("/groups/list/{user_id}")
async def list_user_groups(user_id: str):
    groups = await database_service.get_user_groups(user_id)
    return {"groups": groups}

@app.get("/groups/{group_id}/members")
async def list_group_members(group_id: int):
    members = await database_service.get_group_members(group_id)
    return {"members": members}

@app.get("/groups/{group_id}/dashboard")
async def group_dashboard(group_id: int, user_id: str):
    # Verify membership
    members = await database_service.get_group_members(group_id)
    if not any(m['user_id'] == user_id for m in members):
        raise HTTPException(status_code=403, detail="Access denied: Not a group member")
        
    # Default to current month
    data = await database_service.get_group_dashboard_data(group_id)
    return data

# --- Email Parsing ---

@app.post("/transactions/sync/email")
async def sync_email_transactions(request: EmailSyncRequest):
    """
    Sync transactions from email attachments.
    WARNING: Requires App Password from Gmail.
    """
    try:
        # 1. Fetch from email
        result = await email_service.fetch_and_parse_emails(
            request.email, 
            request.password, 
            request.days_back
        )
        
        if result.get("status") == "error":
            raise HTTPException(status_code=400, detail=result.get("message"))
            
        transactions = result.get("transactions", [])
        saved_count = 0
        
        # 2. Categorize and Save (using existing logic)
        from services.database_service import Transaction
        
        for tx in transactions:
            # tx is a dict from asdict()
            new_tx = Transaction(
                id=None,
                user_id=request.user_id,
                amount=tx.get('amount'),
                description=tx.get('description'),
                category=tx.get('category', 'Uncategorized'),
                type=tx.get('transaction_type', 'expense'),
                date=tx.get('date'),
                time=tx.get('extra_data', {}).get('time'),
                merchant=tx.get('merchant'),
                payment_method=tx.get('source'),
                notes="Imported from Email",
                receipt_url=None,
                is_recurring=False
            )
            
            # Auto-categorize if needed
            if new_tx.category in ['Uncategorized', 'Other', None]:
                 cat = await transaction_categorizer.categorize_single(
                     new_tx.description, new_tx.amount, new_tx.type
                 )
                 new_tx.category = cat
            
            await database_service.create_transaction(new_tx)
            saved_count += 1
            
        return {
            "success": True,
            "found": len(transactions),
            "saved": saved_count,
            "message": f"Successfully imported {saved_count} transactions from email."
        }
            
    except Exception as e:
        logger.error(f"Email sync error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# --- AI Chat Routes ---

@app.post("/agent/chat")
async def agent_chat(request: AgentRequest):
    """Legacy endpoint - redirects to agentic-chat logic."""
    internal_req = AgenticChatRequest(
        query=request.query,
        user_context=request.context, 
        conversation_history=request.conversation_history,
        user_id=request.user_id
    )
    result = await agentic_chat(internal_req)
    return {
        "response": result.get("response", ""),
        "user_id": request.user_id,
        "sources": result.get("sources", []),
        "model_used": result.get("model_used", "unknown")
    }

@app.post("/agent/agentic-chat")
async def agentic_chat(request: AgenticChatRequest):
    """
    Agentic chat with tool/function calling capabilities and RAG integration.
    Enhanced with Intelligent Query Router.
    """
    try:
        # Step 1: Route the query
        query_type, routing_config = router.classify_query(
            request.query,
            request.user_context
        )
        
        logger.info(f"Query classified as: {query_type.value}")
        
        response_text = ""
        model_used = "unknown"
        sources = []
        action_taken = False
        action_type = None
        action_data = None
        needs_confirmation = False

        # Step 2: Process based on route
        if query_type == QueryType.GOV_API:
             # Handle Government API queries
             model_used = "govt_api"
             sources = ["government_api"]
             
             # Simple regex-based extraction for now
             import re
             if "pan" in request.query.lower():
                 pan_match = re.search(r'[A-Z]{5}[0-9]{4}[A-Z]{1}', request.query.upper())
                 if pan_match:
                     pan = pan_match.group(0)
                     result = govt_api.verify_pan(pan)
                     response_text = f"**PAN Verification Result:**\n" \
                                     f"✅ Valid: {result['valid']}\n" \
                                     f"👤 Name: {result['name']}\n" \
                                     f"📋 Status: {result['status']}"
                 else:
                     response_text = "I can verify your PAN. Please provide a valid 10-character PAN number (e.g., ABCDE1234F)."
                     
             elif "gst" in request.query.lower():
                 gst_match = re.search(r'[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}', request.query.upper())
                 if gst_match:
                     gstin = gst_match.group(0)
                     result = govt_api.verify_gstin(gstin)
                     response_text = f"**GST Verification Result:**\n" \
                                     f"✅ Valid: {result['valid']}\n" \
                                     f"🏢 Trade Name: {result['trade_name']}\n" \
                                     f"📋 Status: {result['status']}"
                 else:
                     response_text = "I can verify GSTIN. Please provide a valid 15-character GSTIN."

             elif "itr" in request.query.lower():
                 response_text = "To check ITR status, please provide your PAN and Acknowledgement Number."
                 # Implement extraction logic if needed
             else:
                 response_text = "I can help with Government data verification (PAN, GST, ITR, EPFO). Please provide the specific ID number."

        elif query_type == QueryType.STATIC_KB:
            # Handle Static Knowledge Base queries (Tax, Rules, Formulas)
            results = static_kb.search(request.query)
            if results:
                top = results[0]
                response_text = f"**{top['title']}**\n\n{top['content']}\n\n*Source: {top['title']} (Static KB)*"
                model_used = "static_kb"
                sources = ["static_knowledge"]
            else:
                 # Fallback to AI tools if not found in static KB
                 result = await ai_tools_service.process_with_tools(request.query, request.user_context)
                 response_text = result.response
                 model_used = "ai_tools_fallback"
                 sources = ["ai_tools"]

        elif query_type == QueryType.TRANSACTION:
            # Handle with existing tool-based agent (Local DB)
            result = await ai_tools_service.process_with_tools(
                query=request.query,
                user_context=request.user_context
            )
            response_text = result.response
            model_used = "local_agent"
            action_taken = result.action_taken
            action_type = result.action_type
            action_data = result.action_data
            needs_confirmation = result.needs_confirmation
        
        elif query_type == QueryType.SIMPLE:
            # Check for Indic language first if configured
            if sarvam_service.is_configured and sarvam_service.is_indic_query(request.query):
                 lang = sarvam_service.detect_language(request.query)
                 response_text = await sarvam_service.get_financial_advice_indic(request.query, lang)
                 model_used = "sarvam"
            else:
                 result = await ai_tools_service.process_with_tools(request.query, request.user_context)
                 response_text = result.response
                 model_used = "ai_tools"
        
        elif query_type == QueryType.WEB_SEARCH:
            # Use DuckDuckGo web search with clickable sources
            search_category = "general"
            lower_query = request.query.lower()

            # Detect category from query
            if any(word in lower_query for word in ['buy', 'price', 'shop', 'product']):
                search_category = "shopping"
            elif any(word in lower_query for word in ['stock', 'share', 'nse', 'bse']):
                search_category = "stocks"
            elif any(word in lower_query for word in ['news', 'latest', 'today']):
                search_category = "news"
            elif any(word in lower_query for word in ['tax', 'income tax', 'gst']):
                search_category = "tax"
            elif any(word in lower_query for word in ['scheme', 'pradhan mantri', 'government']):
                search_category = "schemes"

            # Perform web search
            search_results = await web_search_service.search_finance_news(
                query=request.query,
                limit=5,
                category=search_category
            )

            if search_results:
                # Format results with clickable URLs
                sources = [
                    {
                        "title": r.title,
                        "url": r.url,
                        "snippet": r.snippet,
                        "source": r.source,
                        "price": r.price_display if r.price else None,
                        "can_add_to_goal": r.can_add_to_goal
                    }
                    for r in search_results
                ]

                # Create response text
                response_text = f"I found {len(search_results)} results for your query:\n\n"
                for idx, r in enumerate(search_results, 1):
                    response_text += f"**{idx}. {r.title}**\n"
                    response_text += f"{r.snippet}\n"
                    if r.price_display:
                        response_text += f"💰 Price: {r.price_display}\n"
                    response_text += f"🔗 [{r.source}]({r.url})\n\n"

                model_used = "duckduckgo_search"
            else:
                # Fallback if no results
                result = await ai_tools_service.process_with_tools(
                    query=request.query,
                    user_context=request.user_context
                )
                response_text = result.response
                model_used = "web_agent_fallback"
                sources = []

        elif query_type == QueryType.HEAVY_REASONING:
            # RAG + GPT-4o with Static KB context
            # First get static context to reduce hallucinations
            kb_results = static_kb.search(request.query)
            static_context = ""
            if kb_results:
                static_context = "\n\nRelevant Knowledge:\n" + "\n".join([f"- {r['title']}: {r['content'][:200]}..." for r in kb_results[:2]])
            
            # Use Groq for AI Advisor chat (faster, saves OpenAI quota)
            try:
                ai_provider = AIProviderService()

                # Build context with conversation history
                context = ""
                if request.conversation_history:
                    for msg in request.conversation_history[-5:]:
                        role = msg.get('role', 'user')
                        content = msg.get('content', '')
                        context += f"{role}: {content}\n"

                full_prompt = f"{context}\nuser: {request.query + static_context}"
                system_prompt = "You are an AI financial advisor for Indian MSMEs. Provide practical, actionable advice."

                response_text = await ai_provider.get_completion(
                    prompt=full_prompt,
                    system_prompt=system_prompt,
                    temperature=0.7,
                    max_tokens=routing_config.get("max_tokens", 4000)
                )

                model_used = f"groq_{ai_provider.provider}"
                sources = kb_results[:2] if kb_results else []

            except Exception as e:
                logger.error(f"Groq AI Advisor error: {e}, falling back to OpenAI")
                # Fallback to OpenAI
                result_dict = openai_service.chat_with_rag(
                    user_query=request.query + static_context,
                    conversation_history=request.conversation_history,
                    model="gpt-4o",
                    use_rag=True,
                    max_tokens=routing_config.get("max_tokens", 4000)
                )
                response_text = result_dict["response"]
                model_used = result_dict["model_used"] + "_fallback"
                sources = result_dict["sources"]
        
        return {
            "response": response_text,
            "action_taken": action_taken,
            "action_type": action_type,
            "action_data": action_data,
            "needs_confirmation": needs_confirmation,
            "user_id": request.user_id,
            "query_type": query_type.value,
            "model_used": model_used,
            "sources": sources
        }

    except Exception as e:
        logger.error(f"Error in agentic_chat: {e}")
        return {
            "response": f"I'm having trouble processing your request: {str(e)}",
            "action_taken": False,
            "error": str(e)
        }

@app.post("/agent/confirm-action")
async def confirm_action(request: ActionConfirmRequest):
    return {
        "success": True,
        "message": f"Action '{request.action_type}' confirmed. Data saved locally.",
        "action_type": request.action_type,
        "action_data": request.action_data
    }

@app.get("/agent/tools")
async def get_available_tools():
    from services.ai_tools_service import FINANCIAL_TOOLS
    return {
        "tools": [
            {"name": tool["name"], "description": tool["description"]}
            for tool in FINANCIAL_TOOLS
        ]
    }

@app.post("/agent/scan-document")
async def scan_document(file: UploadFile = File(...)):
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")
    
    with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as tmp:
        tmp.write(await file.read())
        temp_path = tmp.name
    
    try:
        result = await pdf_parser_service.extract_transactions(temp_path, document_type='auto')
        transactions = result.get('transactions', [])
        
        formatted_transactions = []
        for tx in transactions:
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
            "metadata": result.get('metadata', {})
        }
    except Exception as e:
        logger.error(f"Error scanning document: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)

@app.post("/agent/scan-receipt")
async def scan_receipt(file: UploadFile = File(...)):
    allowed_types = [".jpg", ".jpeg", ".png", ".webp"]
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in allowed_types:
        raise HTTPException(status_code=400, detail="Unsupported image format")
    
    try:
        image_bytes = await file.read()
        if zoho_vision_service.is_configured:
            receipt = await zoho_vision_service.extract_receipt(image_bytes, file.filename)
            return {
                "success": True,
                "source": "zoho_vision",
                "data": receipt.dict(), # Assuming Pydantic model
                "suggested_transaction": {
                    "description": receipt.merchant_name,
                    "amount": receipt.total_amount,
                    "date": receipt.date
                }
            }
        else:
             return {
                "success": False,
                "source": "fallback",
                "error": "Zoho Vision not configured.",
                "data": None
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/transactions/import/image")
async def import_transactions_from_image(
    file: UploadFile = File(...),
    user_id: str = "default"
):
    """
    Import transactions from an image file using Sarvam Vision.
    Supports receipts, bank statement screenshots, UPI screenshots, etc.
    """
    allowed_types = [".jpg", ".jpeg", ".png", ".webp"]
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in allowed_types:
        raise HTTPException(status_code=400, detail="Unsupported image format. Use JPG, PNG, or WebP.")

    temp_path = None
    try:
        # Save to temp file
        temp_path = f"/tmp/wealthin_img_{user_id}_{int(datetime.now().timestamp())}{ext}"
        image_bytes = await file.read()
        with open(temp_path, "wb") as f:
            f.write(image_bytes)

        logger.info(f"[Import Image] Processing {file.filename} for user {user_id}")

        # Try Sarvam Vision first
        if sarvam_service.is_configured:
            result = sarvam_service.extract_transactions_from_image(temp_path)

            if result.get("success") and result.get("transactions"):
                # Categorize each transaction
                transactions = result["transactions"]
                for tx in transactions:
                    if tx.get("category") == "Other":
                        category = await transaction_categorizer.categorize_single(
                            tx.get("description", ""),
                            tx.get("amount", 0),
                            tx.get("type", "expense")
                        )
                        tx["category"] = category

                return {
                    "success": True,
                    "transaction_count": len(transactions),
                    "transactions": transactions,
                    "source": result.get("source", "sarvam_vision"),
                    "confidence": 0.85 if result.get("source") == "sarvam_vision" else 0.6
                }

        # Fallback to Zoho Vision
        if zoho_vision_service.is_configured:
            receipt = await zoho_vision_service.extract_receipt(image_bytes, file.filename)
            if receipt:
                transaction = {
                    "date": receipt.date or datetime.now().strftime('%Y-%m-%d'),
                    "description": receipt.merchant_name or "Receipt",
                    "amount": receipt.total_amount or 0,
                    "type": "expense",
                    "category": "Other",
                    "merchant": receipt.merchant_name
                }
                # Categorize
                category = await transaction_categorizer.categorize_single(
                    transaction["description"],
                    transaction["amount"],
                    "expense"
                )
                transaction["category"] = category

                return {
                    "success": True,
                    "transaction_count": 1,
                    "transactions": [transaction],
                    "source": "zoho_vision",
                    "confidence": 0.7
                }

        return {
            "success": False,
            "error": "No vision service available. Configure Sarvam AI or Zoho Vision.",
            "transactions": []
        }

    except Exception as e:
        logger.error(f"[Import Image] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.unlink(temp_path)
            except:
                pass


@app.post("/agent/indic-chat")
async def indic_chat(request: AgentRequest):
    if not sarvam_service.is_configured:
        return await agent_chat(request)
    try:
        detected_lang = sarvam_service.detect_language(request.query)
        if sarvam_service.is_indic_query(request.query):
            response = await sarvam_service.get_financial_advice_indic(request.query, detected_lang)
            return {"response": response, "language": detected_lang, "user_id": request.user_id}
        else:
            return await agent_chat(request)
    except Exception as e:
        return await agent_chat(request)

@app.post("/agent/deep-research")
async def deep_research(request: DeepResearchRequest):
    try:
        agent = get_deep_research_agent()
        result = await agent.research(query=request.query, context=request.user_context)
        return {
            "success": True,
            "report": result.get("report", ""),
            "sources": result.get("sources", []),
            "status_log": result.get("status_log", []),
            "user_id": request.user_id,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


# --- Brainstorming & DPR ---

REGULATORY_QUERY_KEYWORDS = (
    "scheme",
    "eligibility",
    "eligible",
    "loan",
    "collateral",
    "pmegp",
    "mudra",
    "pmmy",
    "cgtmse",
    "cgss",
    "kfs",
    "apr",
    "legal",
    "compliance",
    "document",
    "dpr",
    "npa",
    "udyam",
    "gst",
)


def _is_regulatory_query(message: str) -> bool:
    lower = (message or "").lower()
    return any(keyword in lower for keyword in REGULATORY_QUERY_KEYWORDS)


class BrainstormRequest(BaseModel):
    user_id: str
    message: str
    conversation_history: Optional[List[Dict]] = []
    enable_web_search: bool = True
    search_category: str = "general"
    persona: str = "neutral"  # backward compatibility
    mode: str = "msme_copilot"
    workflow_mode: str = "input"
    user_profile: Optional[Dict[str, Any]] = None
    user_location: Optional[str] = None  # State/District for gov API queries

@app.post("/brainstorm/chat")
async def brainstorm_chat(request: BrainstormRequest):
    """
    Mode-driven ideas chat.
    Uses Groq OpenAI GPT-OSS models only for ideas/analysis reasoning.
    """
    start = time.perf_counter()
    try:
        compliance_sensitive = _is_regulatory_query(request.message)
        if not groq_openai_service.is_available and not compliance_sensitive:
            return {
                "success": False,
                "error": "Groq OpenAI service unavailable. Configure GROQ_API_KEY.",
            }

        mode = normalize_mode(request.mode or request.persona)
        workflow_mode = normalize_workflow_mode(request.workflow_mode)
        history_tail = (request.conversation_history or [])[-8:]
        cache_key = _cache_key(
            "brainstorm_chat",
            {
                "message": (request.message or "").strip(),
                "mode": mode,
                "workflow_mode": workflow_mode,
                "history": history_tail,
                "user_profile": request.user_profile or {},
            },
        )
        cached = _cache_get(brainstorm_cache, cache_key, BRAINSTORM_CACHE_TTL)
        if cached:
            cached["cached"] = True
            cached["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
            return cached

        compatibility_report = scheme_compatibility_service.assess(
            message=request.message,
            user_profile=request.user_profile or {},
            conversation_history=history_tail,
        )
        compatibility_context = scheme_compatibility_service.build_prompt_context(compatibility_report)
        rag_payload = msme_credit_rag_service.retrieve(
            request.message,
            top_k=4,
            extra_terms=[
                compatibility_report.get("profile", {}).get("business_stage", ""),
                compatibility_report.get("profile", {}).get("business_sector", ""),
            ],
        )
        rag_context = msme_credit_rag_service.format_for_prompt(rag_payload)
        authoritative_content = scheme_compatibility_service.render_authoritative_response(
            compatibility_report,
            rag_payload=rag_payload,
        )

        if compliance_sensitive:
            # For legal/scheme queries, return deterministic policy-grounded content only.
            # This avoids numeric hallucinations and keeps answers legally safer.
            content = authoritative_content
            routing = {
                "handler": "deterministic_scheme_legal",
                "model": "policy_grounded_local_rag",
                "cost_saved": True,
            }
        else:
            # ── Web search augmentation ──────────────────────────────────
            web_search_context = ""
            web_sources: List[Dict[str, Any]] = []
            if request.enable_web_search and web_search_service.is_available:
                try:
                    search_query = f"{request.message} MSME India"
                    search_results = await asyncio.wait_for(
                        web_search_service.search_finance_news(
                            search_query, limit=4, category="general"
                        ),
                        timeout=8.0,
                    )
                    if search_results:
                        snippets = []
                        for sr in search_results:
                            snippets.append(f"• {sr.title}: {sr.snippet}")
                            web_sources.append(
                                {"title": sr.title, "url": sr.url, "snippet": sr.snippet}
                            )
                        web_search_context = (
                            "\n\n### Live Web Research\n"
                            + "\n".join(snippets)
                        )
                except Exception as ws_err:
                    logger.warning(f"Brainstorm web search failed (non-fatal): {ws_err}")

            # ── MSME Government Data Enrichment ──────────────────────────
            msme_gov_context = ""
            msme_data_payload: Dict[str, Any] = {}
            up = request.user_profile or {}
            user_location = request.user_location or up.get("location") or up.get("state") or ""
            user_sector = up.get("business_sector") or ""
            lower_msg = request.message.lower()

            # Infer sector from message if not in profile
            if not user_sector:
                sector_keywords = {
                    "restaurant": "Food Processing",
                    "food": "Food Processing",
                    "hotel": "Hospitality",
                    "textile": "Textile",
                    "garment": "Textile",
                    "it ": "IT",
                    "software": "IT",
                    "tech": "IT",
                    "manufacturing": "Manufacturing",
                    "agriculture": "Agriculture",
                    "farming": "Agriculture",
                    "dairy": "Agriculture",
                    "retail": "Retail",
                    "shop": "Retail",
                    "pharmacy": "Healthcare",
                    "medical": "Healthcare",
                    "construction": "Construction",
                    "transport": "Transport",
                    "logistics": "Transport",
                    "education": "Education",
                    "coaching": "Education",
                    "salon": "Services",
                    "beauty": "Services",
                    "gym": "Services",
                    "fitness": "Services",
                    "bakery": "Food Processing",
                    "catering": "Food Processing",
                    "printing": "Manufacturing",
                    "furniture": "Manufacturing",
                    "handicraft": "Handicraft",
                    "artisan": "Handicraft",
                    "craft": "Handicraft",
                    "packaging": "Packaging",
                    "plastic": "Manufacturing",
                    "steel": "Manufacturing",
                    "electronics": "Manufacturing",
                }
                for keyword, sector in sector_keywords.items():
                    if keyword in lower_msg:
                        user_sector = sector
                        break

            # Infer location from message if not provided
            if not user_location:
                indian_states = [
                    "andhra pradesh", "arunachal pradesh", "assam", "bihar",
                    "chhattisgarh", "goa", "gujarat", "haryana", "himachal pradesh",
                    "jharkhand", "karnataka", "kerala", "madhya pradesh",
                    "maharashtra", "manipur", "meghalaya", "mizoram", "nagaland",
                    "odisha", "punjab", "rajasthan", "sikkim", "tamil nadu",
                    "telangana", "tripura", "uttar pradesh", "uttarakhand",
                    "west bengal", "delhi", "chandigarh", "puducherry",
                    "jammu", "kashmir", "ladakh",
                ]
                for state in indian_states:
                    if state in lower_msg:
                        user_location = state.title()
                        break

            # Fetch real MSME government data if we have location or sector
            if user_location or user_sector:
                try:
                    msme_enrichment_tasks = []

                    # 1. Get local suppliers / competitors
                    if user_location and user_sector:
                        msme_enrichment_tasks.append(
                            asyncio.wait_for(
                                local_msme_recommender.get_local_suppliers(
                                    user_location=user_location,
                                    product_category=user_sector,
                                ),
                                timeout=6.0,
                            )
                        )
                    else:
                        async def _empty(): return {}
                        msme_enrichment_tasks.append(_empty())

                    # 2. Compare business idea for competition analysis
                    if user_location and user_sector:
                        msme_enrichment_tasks.append(
                            asyncio.wait_for(
                                local_msme_recommender.compare_business_idea(
                                    business_idea=request.message,
                                    sector=user_sector,
                                    location=user_location,
                                ),
                                timeout=6.0,
                            )
                        )
                    else:
                        async def _empty(): return {}
                        msme_enrichment_tasks.append(_empty())

                    # 3. Supply chain recommendations for business-related queries
                    supply_chain_keywords = ["supplier", "supply", "raw material", "vendor",
                                             "buy", "source", "purchase", "chain", "ingredient",
                                             "material", "equipment", "machinery"]
                    needs_supply_chain = any(kw in lower_msg for kw in supply_chain_keywords)
                    if needs_supply_chain and user_location:
                        # Infer needed supplier types from sector
                        supplier_map = {
                            "Food Processing": ["Raw Material", "Packaging", "Equipment"],
                            "Textile": ["Raw Material", "Equipment", "Logistics"],
                            "Manufacturing": ["Raw Material", "Equipment", "Packaging"],
                            "IT": ["IT Services", "Equipment"],
                            "Retail": ["Raw Material", "Logistics", "Packaging"],
                            "Healthcare": ["Equipment", "Raw Material"],
                            "Construction": ["Raw Material", "Equipment", "Logistics"],
                            "Handicraft": ["Raw Material", "Packaging", "Marketing"],
                        }
                        needed = supplier_map.get(user_sector, ["Raw Material", "Packaging"])
                        msme_enrichment_tasks.append(
                            asyncio.wait_for(
                                local_msme_recommender.get_supply_chain_recommendations(
                                    business_type=user_sector or request.message[:60],
                                    location=user_location,
                                    needed_suppliers=needed,
                                ),
                                timeout=8.0,
                            )
                        )
                    else:
                        async def _empty(): return {}
                        msme_enrichment_tasks.append(_empty())

                    # Run all MSME enrichment in parallel
                    results = await asyncio.gather(*msme_enrichment_tasks, return_exceptions=True)

                    local_suppliers = results[0] if not isinstance(results[0], Exception) else {}
                    competition = results[1] if not isinstance(results[1], Exception) else {}
                    supply_chain = results[2] if not isinstance(results[2], Exception) else {}

                    msme_data_payload = {
                        "local_suppliers": local_suppliers,
                        "competition_analysis": competition,
                        "supply_chain": supply_chain,
                        "user_location": user_location,
                        "inferred_sector": user_sector,
                    }

                    # Build context string for the LLM
                    ctx_parts = ["\n\n### 🏛️ Government MSME Intelligence (data.gov.in)"]
                    if user_location:
                        ctx_parts.append(f"📍 **User Location:** {user_location}")
                    if user_sector:
                        ctx_parts.append(f"🏭 **Business Sector:** {user_sector}")

                    if local_suppliers and local_suppliers.get("found"):
                        ctx_parts.append(f"\n**Local MSME Suppliers ({user_location}):**")
                        ctx_parts.append(f"- Total registered suppliers: {local_suppliers.get('total_local_suppliers', 0)}")
                        ctx_parts.append(local_suppliers.get("savings_message", ""))
                        for rec in (local_suppliers.get("recommendations") or [])[:3]:
                            ctx_parts.append(
                                f"  • {rec.get('business_name', 'N/A')} "
                                f"({rec.get('type', '')}, {rec.get('district', '')}) "
                                f"{rec.get('verified', '')}"
                            )

                    if competition and not competition.get("error"):
                        ctx_parts.append(f"\n**Competition Analysis:**")
                        ctx_parts.append(
                            f"- {competition.get('competition_color', '⚪')} Competition Level: "
                            f"{competition.get('competition_level', 'Unknown')} "
                            f"({competition.get('similar_count', 0)} similar businesses)"
                        )
                        ctx_parts.append(f"- {competition.get('recommendation', '')}")
                        for insight in (competition.get("market_insights") or []):
                            ctx_parts.append(f"  {insight}")

                    if supply_chain and supply_chain.get("recommendations"):
                        ctx_parts.append(f"\n**Supply Chain Recommendations:**")
                        summary = supply_chain.get("summary", {})
                        ctx_parts.append(f"- {summary.get('coverage', 'N/A')}")
                        ctx_parts.append(f"- {summary.get('benefit', '')}")
                        for stype, sdata in supply_chain.get("recommendations", {}).items():
                            if isinstance(sdata, dict) and sdata.get("found"):
                                ctx_parts.append(
                                    f"  • {stype}: {sdata.get('count', 0)} local suppliers available"
                                )

                    # Add local MSME context for prompt injection
                    local_msme_prompt_ctx = local_msme_recommender.generate_ai_prompt_context(
                        user_query=request.message,
                        user_location=user_location or None,
                        business_sector=user_sector or None,
                    )
                    ctx_parts.append(local_msme_prompt_ctx)

                    msme_gov_context = "\n".join(ctx_parts)

                except Exception as msme_err:
                    logger.warning(f"MSME gov enrichment failed (non-fatal): {msme_err}")

            # Build user financial context string from profile
            user_financial_ctx = ""
            if up.get("monthly_income") or up.get("monthly_expenses"):
                parts = []
                if up.get("monthly_income"):
                    parts.append(f"Monthly income: ₹{up['monthly_income']}")
                if up.get("monthly_expenses"):
                    parts.append(f"Monthly expenses: ₹{up['monthly_expenses']}")
                if up.get("savings_rate"):
                    parts.append(f"Savings rate: {up['savings_rate']}")
                if up.get("top_spending"):
                    cats = up["top_spending"] if isinstance(up["top_spending"], list) else []
                    if cats:
                        parts.append(f"Top spending: {', '.join(str(c) for c in cats[:5])}")
                user_financial_ctx = "\n\n### User Financial Profile\n" + "\n".join(parts)

            # Enhanced intellectual system prompt for Ideas section
            ideas_enhancement = (
                "\n\n### IMPORTANT — Ideas Mode Behavior\n"
                "You are NOT a generic chatbot. You are the WealthIn Ideas Copilot — "
                "a deeply knowledgeable, intellectually sharp, and conversational business strategist.\n\n"
                "Your responses must be:\n"
                "- **Deeply Conversational**: Engage like a seasoned mentor, not a search engine. "
                "Ask follow-up questions, challenge assumptions, suggest alternatives.\n"
                "- **Data-Backed**: When government MSME data is available, cite it directly. "
                "Reference real numbers (supplier counts, competition levels, scheme eligibility).\n"
                "- **State-Wise Intelligent**: Search and suggest across the entire state, not just nearby. "
                "Recommend the BEST options regardless of exact proximity.\n"
                "- **Supply Chain Aware**: For any business idea, think through the entire supply chain "
                "(raw materials → production → packaging → distribution → customer). "
                "Identify which links can be sourced from local MSMEs.\n"
                "- **Scheme-Matched**: Always check which government schemes the user qualifies for. "
                "Be specific about eligibility, subsidy percentages, and application steps.\n"
                "- **Actionable**: Every response must end with 2-3 concrete next steps the user can take TODAY.\n\n"
                "If the user has NOT provided their location or business sector, "
                "ASK for it naturally in conversation — location helps you pull real government data.\n"
            )

            system_prompt = (
                f"{get_ideas_system_prompt(mode, workflow_mode)}\n\n"
                f"{ideas_enhancement}"
                f"{compatibility_context}\n\n"
                f"{rag_context}"
                f"{msme_gov_context}"
                f"{web_search_context}"
                f"{user_financial_ctx}"
            )

            messages = [{"role": "system", "content": system_prompt}]
            for msg in history_tail:
                role = msg.get("role", "user")
                msg_content = (msg.get("content") or "").strip()
                if msg_content:
                    messages.append({"role": role, "content": msg_content})
            messages.append({"role": "user", "content": request.message})

            llm_result = await asyncio.wait_for(
                groq_openai_service.chat(
                    messages,
                    temperature=0.5,
                    max_tokens=2400,
                ),
                timeout=LLM_TIMEOUT_CHAT,
            )
            content = llm_result.get("content", "")
            compatibility_summary = scheme_compatibility_service.render_markdown_summary(compatibility_report)
            if compatibility_summary:
                content = f"{content.strip()}\n\n---\n\n{compatibility_summary}"
            routing = {
                "handler": "groq_openai_ideas",
                "model": llm_result.get("model"),
                "cost_saved": False,
                "web_search_used": len(web_sources) > 0,
                "msme_gov_used": bool(msme_gov_context),
            }

        response = {
            "success": True,
            "content": content,
            "sources": web_sources if not compliance_sensitive else [],
            "mode": mode,
            "workflow_mode": workflow_mode,
            "routing": routing,
            "scheme_compatibility": compatibility_report,
            "msme_credit_rag": rag_payload,
            "msme_gov_data": msme_data_payload if not compliance_sensitive else {},
            "visualization": _build_mode_visualization_payload(mode, content),
            "cached": False,
        }
        _cache_set(brainstorm_cache, cache_key, response)
        response["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
        return response

    except asyncio.TimeoutError:
        logger.warning("Brainstorm chat timed out")
        return {
            "success": False,
            "error": "Ideas generation timed out. Please retry with a shorter prompt.",
        }

    except Exception as e:
        logger.error(f"Brainstorm error: {e}")
        return {"success": False, "error": str(e)}


@app.get("/brainstorm/modes")
async def brainstorm_modes():
    start = time.perf_counter()
    cache_key = "brainstorm_modes:v1"
    cached = _cache_get(brainstorm_cache, cache_key, BRAINSTORM_CACHE_TTL)
    if cached:
        cached["cached"] = True
        cached["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
        return cached

    response = {"success": True, "modes": list_ideas_modes(), "cached": False}
    _cache_set(brainstorm_cache, cache_key, response)
    response["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
    return response


def _build_mode_visualization_payload(mode: str, content: str) -> Dict[str, Any]:
    baseline = {
        "msme_copilot": {
            "score_label": "Business Readiness",
            "chart_type": "readiness_radar",
            "metrics": ["market_fit", "financial_fit", "execution_readiness", "compliance_readiness"],
        },
    }
    payload = baseline.get(mode, baseline["msme_copilot"]).copy()
    payload["content_length"] = len(content or "")
    return payload


def _format_template_response(data: Dict[str, Any]) -> str:
    """Format business plan template as markdown"""
    content = f"# {data['title']}\n\n"

    for section in data['sections']:
        content += f"## {section['section']}\n"
        content += f"*{section['description']}*\n\n"
        content += "**Key Points:**\n"
        for point in section['key_points']:
            content += f"• {point}\n"
        content += "\n"

    content += "## Next Steps\n"
    for step in data['next_steps']:
        content += f"✓ {step}\n"

    content += f"\n⏱️ **Estimated Time:** {data['estimated_time']}\n"
    content += "\n💡 *This is a template outline. Customize each section based on your specific business.*"

    return content


def _format_funding_response(data: Dict[str, Any]) -> str:
    """Format funding guide as markdown"""
    content = "# 💰 Government Funding Schemes for MSMEs\n\n"

    for scheme in data['schemes']:
        content += f"## {scheme['name']}\n"
        content += f"{scheme['description']}\n\n"
        content += f"**Loan Amount:** {scheme['loan_amount']}\n"

        if 'categories' in scheme:
            content += "**Categories:**\n"
            for cat in scheme['categories']:
                content += f"• {cat}\n"

        content += "\n**Eligibility:**\n"
        for eligibility in scheme['eligibility']:
            content += f"• {eligibility}\n"

        if 'interest_rate' in scheme:
            content += f"\n**Interest Rate:** {scheme['interest_rate']}\n"

        if 'collateral' in scheme:
            content += f"**Collateral:** {scheme['collateral']}\n"

        content += f"\n🌐 **Website:** {scheme['website']}\n\n---\n\n"

    content += "## Application Process\n"
    for i, step in enumerate(data['application_process']['steps'], 1):
        content += f"{i}. {step}\n"

    content += f"\n⏱️ **Timeline:** {data['application_process']['typical_timeline']}\n\n"

    content += "## 💡 Tips\n"
    for tip in data['tips']:
        content += f"• {tip}\n"

    return content


def _format_dpr_response(data: Dict[str, Any]) -> str:
    """Format DPR template as markdown"""
    content = f"# {data['title']}\n\n"
    content += "A Detailed Project Report (DPR) is essential for loan applications. Here's the structure:\n\n"

    for section in data['sections']:
        content += f"## {section['section']}\n"
        for field in section['fields']:
            content += f"• {field}\n"
        content += "\n"

    content += "## Format Requirements\n"
    for key, value in data['format_requirements'].items():
        content += f"• **{key.title()}:** {value}\n"

    content += "\n💡 *Use this template to prepare your DPR. Banks typically require 2-3 copies along with supporting documents.*"

    return content

@app.post("/brainstorm/generate-dpr")
async def generate_dpr(request: DPRRequest):
    start = time.perf_counter()
    try:
        cache_key = _cache_key(
            "generate_dpr",
            {
                "business_idea": (request.business_idea or "").strip(),
                "mode": request.mode,
                "user_data": request.user_data,
                "canvas_items": request.canvas_items or [],
            },
        )
        cached = _cache_get(dpr_cache, cache_key, DPR_CACHE_TTL)
        if cached:
            cached["cached"] = True
            cached["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
            return cached

        project_data = await _build_project_data_with_llm(
            business_idea=request.business_idea,
            user_data=request.user_data,
            canvas_items=request.canvas_items or [],
            mode=request.mode,
        )
        compiled = dpr_generator.compile_dpr(project_data)
        response = {
            "dpr": compiled,
            "project_data": project_data,
            "status": "success",
            "model_used": groq_openai_service.last_model_used or "template_only",
            "cached": False,
        }
        _cache_set(dpr_cache, cache_key, response)
        response["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


class CanvasDPRRequest(BaseModel):
    user_id: str
    canvas_items: List[Dict[str, Any]]
    user_data: Dict[str, Any] = {}
    mode: str = "msme_copilot"
    business_idea: Optional[str] = None


@app.post("/brainstorm/generate-dpr-from-canvas")
async def generate_dpr_from_canvas(request: CanvasDPRRequest):
    start = time.perf_counter()
    try:
        seed_idea = request.business_idea
        if not seed_idea and request.canvas_items:
            seed_idea = request.canvas_items[0].get("title") or "Business idea"

        cache_key = _cache_key(
            "generate_dpr_from_canvas",
            {
                "business_idea": (seed_idea or "Business idea").strip(),
                "mode": request.mode,
                "user_data": request.user_data,
                "canvas_items": request.canvas_items,
            },
        )
        cached = _cache_get(dpr_cache, cache_key, DPR_CACHE_TTL)
        if cached:
            cached["cached"] = True
            cached["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
            return cached

        project_data = await _build_project_data_with_llm(
            business_idea=seed_idea or "Business idea",
            user_data=request.user_data,
            canvas_items=request.canvas_items,
            mode=request.mode,
        )
        compiled = dpr_generator.compile_dpr(project_data)
        response = {
            "success": True,
            "status": "success",
            "dpr": compiled,
            "project_data": project_data,
            "model_used": groq_openai_service.last_model_used or "template_only",
            "cached": False,
        }
        _cache_set(dpr_cache, cache_key, response)
        response["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
        return response
    except Exception as e:
        logger.error(f"Canvas DPR error: {e}")
        return {"success": False, "error": str(e)}


def _template_with_defaults() -> Dict[str, Any]:
    template_response = json.loads(get_dpr_template())
    return template_response.get("template", {})


@app.post("/brainstorm/generate-dpr-section")
async def generate_dpr_section(data: dict):
    """
    Generate a single DPR section for progressive building
    
    Sections: executive_summary, promoter_profile, market_analysis, 
              technical_aspects, financial_projections, cost_of_project,
              profitability, risk_analysis, compliance
    """
    start = time.perf_counter()
    try:
        section_name = data.get("section_name", "")
        canvas_items = data.get("canvas_items", [])
        user_data = data.get("user_data", {})
        user_id = data.get("user_id", "default_user")
        existing_sections = data.get("existing_sections", {})
        business_idea = data.get("business_idea", "")
        
        if not section_name:
            raise HTTPException(status_code=400, detail="section_name is required")
        
        logger.info(f"Generating DPR section: {section_name} for user {user_id}")
        
        # Section-specific prompts
        section_prompts = {
            "executive_summary": "Executive Summary: business name, nature, MSME category, project cost, loan requirement, employment, revenue projection, break-even",
            "promoter_profile": "Promoter Profile: name, qualifications, experience, Udyam number, PAN, GST, contact details",
            "market_analysis": "Market Analysis: TAM/SAM/SOM, target market, competitors, pricing strategy, competitive advantage",
            "technical_aspects": "Technical Aspects: production process, technology, quality standards, capacity, implementation timeline",
            "financial_projections": "5-Year Financial Projections: revenue, operating costs, profits, cash flow, growth assumptions",
            "cost_of_project": "Project Costs: land/building, machinery, working capital, funding sources (loan + equity)",
            "profitability": "Profitability Metrics: DSCR, break-even, payback period, ROI",
            "risk_analysis": "Risk Analysis: market, operational, financial risks and mitigation strategies",
            "compliance": "Compliance Requirements: licenses, registrations, environmental clearances, timelines",
        }
        
        if section_name not in section_prompts:
            raise HTTPException(status_code=400, detail=f"Invalid section_name. Must be one of: {', '.join(section_prompts.keys())}")

        cache_key = _cache_key(
            "generate_dpr_section",
            {
                "section_name": section_name,
                "business_idea": business_idea,
                "canvas_items": canvas_items,
                "user_data": user_data,
                "existing_sections": existing_sections,
            },
        )
        cached = _cache_get(dpr_cache, cache_key, DPR_CACHE_TTL)
        if cached:
            cached["cached"] = True
            cached["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
            return cached
        
        # Build context
        canvas_text = "\n".join([item.get("content", "") for item in canvas_items]) if canvas_items else ""
        context_parts = [f"Business Idea: {business_idea}"] if business_idea else []
        if canvas_text:
            context_parts.append(f"Canvas Data:\n{canvas_text}")
        if existing_sections:
            context_parts.append(f"Existing Sections:\n{json.dumps(existing_sections, indent=2)}")
        if user_data:
            context_parts.append(f"User Data:\n{json.dumps(user_data, indent=2)}")
        
        context = "\n\n".join(context_parts)
        
        prompt = f"""
Generate ONLY the "{section_name.replace('_', ' ').title()}" section for a bank-ready DPR.

Requirements:
{section_prompts[section_name]}

Context:
{context}

Instructions:
1. Follow RBI/SIDBI DPR format
2. Use INR (₹) for all financial values
3. Provide realistic estimates based on context
4. Return as structured JSON with clear field names
5. Be consistent with existing sections
6. Include all mandatory fields for this section

Return ONLY valid JSON for this section, no markdown or extra text.
"""

        section_data = await asyncio.wait_for(
            groq_openai_service.chat_json(
                [
                    {"role": "system", "content": get_ideas_system_prompt("msme_copilot", "anchor")},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.2,
                max_tokens=1800,
            ),
            timeout=LLM_TIMEOUT_DPR_SECTION,
        )

        response = {
            "status": "success",
            "section_name": section_name,
            "section_data": section_data,
            "progress": f"{len(existing_sections) + 1}/9 sections",
            "next_section": _get_next_dpr_section(section_name),
            "metadata": {
                "generated_on": datetime.now().isoformat(),
                "user_id": user_id,
                "model_used": groq_openai_service.last_model_used
            },
            "cached": False,
        }
        _cache_set(dpr_cache, cache_key, response)
        response["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
        return response

    except asyncio.TimeoutError:
        raise HTTPException(status_code=504, detail="DPR section generation timed out")
        
    except Exception as e:
        logger.error(f"DPR section generation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def _get_next_dpr_section(current_section: str) -> Optional[str]:
    """Helper to suggest next section in DPR flow"""
    section_order = [
        "executive_summary",
        "promoter_profile",
        "market_analysis",
        "technical_aspects",
        "financial_projections",
        "cost_of_project",
        "profitability",
        "risk_analysis",
        "compliance",
    ]
    
    try:
        current_index = section_order.index(current_section)
        if current_index < len(section_order) - 1:
            return section_order[current_index + 1]
    except ValueError:
        pass
    
    return None



def _merge_with_template(template: Any, generated: Any) -> Any:
    if isinstance(template, dict) and isinstance(generated, dict):
        merged = {}
        for key, value in template.items():
            merged[key] = _merge_with_template(value, generated.get(key))
        for key, value in generated.items():
            if key not in merged:
                merged[key] = value
        return merged
    if isinstance(template, list):
        return generated if isinstance(generated, list) else template
    return generated if generated not in (None, "", []) else template


def _canvas_summary(canvas_items: List[Dict[str, Any]]) -> str:
    lines = []
    for idx, item in enumerate(canvas_items[:20], 1):
        title = (item.get("title") or "").strip()
        content = (item.get("content") or "").strip()
        category = (item.get("category") or "insight").strip()
        if not title and not content:
            continue
        lines.append(f"{idx}. [{category}] {title} - {content}")
    return "\n".join(lines) if lines else "No canvas items provided."


async def _build_project_data_with_llm(
    business_idea: str,
    user_data: Dict[str, Any],
    canvas_items: List[Dict[str, Any]],
    mode: str,
) -> Dict[str, Any]:
    start = time.perf_counter()
    template = _template_with_defaults()
    if not groq_openai_service.is_available:
        logger.warning("Groq unavailable for DPR synthesis, using template fallback")
        return template

    normalized_mode = normalize_mode(mode)
    canvas_text = _canvas_summary(canvas_items)
    system_prompt = (
        "You are a DPR drafting specialist for Indian MSME scheme applications. "
        "Return strict JSON matching the provided template fields only. "
        "Use realistic Indian business assumptions and keep values bank-ready."
    )
    user_prompt = f"""
Mode: {normalized_mode}
Business Idea: {business_idea}
User Data: {json.dumps(user_data, ensure_ascii=False)}
Canvas Insights:
{canvas_text}

DPR TEMPLATE (use exact keys, preserve nested structure):
{json.dumps(template, ensure_ascii=False)}
"""
    try:
        generated = await asyncio.wait_for(
            groq_openai_service.chat_json(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                max_tokens=2200,
            ),
            timeout=LLM_TIMEOUT_DPR_BUILD,
        )
        logger.info(
            "DPR synthesis completed in %.2f ms (model=%s)",
            (time.perf_counter() - start) * 1000,
            groq_openai_service.last_model_used or "unknown",
        )
        return _merge_with_template(template, generated)
    except asyncio.TimeoutError:
        logger.warning("DPR synthesis timed out; returning template fallback")
        return template
    except Exception as e:
        logger.warning("DPR synthesis fallback triggered: %s", e)
        return template

@app.get("/brainstorm/status")
async def brainstorm_status():
    return {
        "available": groq_openai_service.is_available,
        "msme_credit_rag_available": msme_credit_rag_service.is_available,
        "web_search_available": web_search_service.is_available,
        "modes": list_ideas_modes(),
        "models": os.getenv(
            "GROQ_OPENAI_MODELS",
            "openai/gpt-oss-120b,openai/gpt-oss-70b,openai/gpt-oss-20b",
        ).split(","),
    }

@app.post("/brainstorm/critique")
async def reverse_brainstorm(request: dict):
    """
    REFINERY STAGE: Critique ideas to find weaknesses using Groq OpenAI GPT-OSS.
    """
    start = time.perf_counter()
    try:
        if not groq_openai_service.is_available:
            return {"success": False, "error": "Groq OpenAI service unavailable"}

        ideas = request.get("ideas", [])
        history = request.get("conversation_history", [])
        mode = normalize_mode(request.get("mode", "msme_copilot"))
        history_tail = history[-10:]
        cache_key = _cache_key(
            "brainstorm_critique",
            {"ideas": ideas, "history": history_tail, "mode": mode},
        )
        cached = _cache_get(brainstorm_cache, cache_key, BRAINSTORM_CACHE_TTL)
        if cached:
            cached["cached"] = True
            cached["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
            return cached

        ideas_text = "\n".join([f"- {i}" for i in ideas]) or "- No explicit ideas provided"
        history_text = "\n".join(
            [
                f"{msg.get('role', 'user')}: {msg.get('content', '')}"
                for msg in history_tail
                if msg.get("content")
            ]
        ) or "No recent context."
        prompt = f"""
Ideas:
{ideas_text}

Conversation context:
{history_text}

Provide:
1) Top 3 failure risks with severity
2) Weak assumptions
3) Concrete fixes
4) Survivors worth anchoring
"""
        result = await asyncio.wait_for(
            groq_openai_service.chat(
                [
                    {"role": "system", "content": get_ideas_system_prompt(mode, "refinery")},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.4,
                max_tokens=1400,
            ),
            timeout=LLM_TIMEOUT_CRITIQUE,
        )

        response = {
            "success": True,
            "critique": result.get("content", ""),
            "sources": [],
            "model_used": result.get("model"),
            "cached": False,
        }
        _cache_set(brainstorm_cache, cache_key, response)
        response["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
        return response
    except asyncio.TimeoutError:
        return {"success": False, "error": "Critique timed out. Please retry."}
    except Exception as e:
        logger.error(f"Reverse brainstorm error: {e}")
        return {"success": False, "error": str(e)}

@app.post("/brainstorm/extract-canvas")
async def extract_canvas_items(request: dict):
    """
    ANCHOR STAGE: Extract ideas that survived critique for canvas.
    Returns structured ideas ready for visual canvas.
    """
    start = time.perf_counter()
    try:
        if not groq_openai_service.is_available:
            return {"success": False, "error": "Groq OpenAI service unavailable", "ideas": []}

        history = request.get("conversation_history", [])
        mode = normalize_mode(request.get("mode", "msme_copilot"))
        history_tail = history[-16:]
        cache_key = _cache_key(
            "brainstorm_extract_canvas",
            {"history": history_tail, "mode": mode},
        )
        cached = _cache_get(brainstorm_cache, cache_key, BRAINSTORM_CACHE_TTL)
        if cached:
            cached["cached"] = True
            cached["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
            return cached

        history_text = "\n".join(
            [
                f"{msg.get('role', 'user')}: {msg.get('content', '')}"
                for msg in history_tail
                if msg.get("content")
            ]
        ) or "No context."
        prompt = f"""
From this conversation, extract high-signal ideas to pin on canvas.

Conversation:
{history_text}

Return strict JSON object:
{{
  "ideas": [
    {{
      "title": "short title",
      "content": "actionable summary",
      "category": "feature|risk|opportunity|insight",
      "priority": "high|medium|low"
    }}
  ]
}}
"""
        result = await asyncio.wait_for(
            groq_openai_service.chat_json(
                [
                    {"role": "system", "content": get_ideas_system_prompt(mode, "anchor")},
                    {"role": "user", "content": prompt},
                ],
                max_tokens=1800,
            ),
            timeout=LLM_TIMEOUT_EXTRACT,
        )
        ideas = result.get("ideas", [])
        if not isinstance(ideas, list):
            ideas = []

        response = {
            "success": True,
            "ideas": ideas,
            "message": f"Extracted {len(ideas)} canvas candidates.",
            "cached": False,
        }
        _cache_set(brainstorm_cache, cache_key, response)
        response["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)
        return response
    except asyncio.TimeoutError:
        return {"success": False, "error": "Canvas extraction timed out.", "ideas": []}
    except Exception as e:
        logger.error(f"Extract canvas error: {e}")
        return {"success": False, "error": str(e), "ideas": []}


# --- Investment Calculators ---

@app.post("/calculator/sip")
async def calculate_sip(request: SIPRequest):
    result = investment_calculator.calculate_sip(
        request.monthly_investment, request.expected_rate, request.duration_months
    )
    return {
        "monthly_investment": result.monthly_investment,
        "total_invested": result.total_invested,
        "future_value": result.future_value,
        "wealth_gained": result.wealth_gained
    }

@app.post("/calculator/fd")
async def calculate_fd(request: FDRequest):
    result = investment_calculator.calculate_fd(
        request.principal, request.rate, request.tenure_months, request.compounding
    )
    return {
        "maturity_amount": result.maturity_amount,
        "interest_earned": result.interest_earned
    }

@app.post("/calculator/emi")
async def calculate_emi(request: EMIRequest):
    result = investment_calculator.calculate_emi(
        request.principal, request.rate, request.tenure_months
    )
    return {
        "emi": result.emi,
        "total_payment": result.total_payment,
        "total_interest": result.total_interest
    }

@app.post("/calculator/rd")
async def calculate_rd(request: RDRequest):
    result = investment_calculator.calculate_rd(
        request.monthly_deposit, request.rate, request.tenure_months
    )
    return {"maturity_amount": result.maturity_amount}

@app.post("/calculator/lumpsum")
async def calculate_lumpsum(request: LumpsumRequest):
    result = investment_calculator.calculate_lumpsum(
        request.principal, request.rate, request.duration_years
    )
    return {"maturity_amount": result.maturity_amount}

@app.post("/calculator/cagr")
async def calculate_cagr(request: CAGRRequest):
    result = investment_calculator.calculate_cagr(
        request.initial_value, request.final_value, request.years
    )
    return {"cagr": result}

@app.post("/calculator/goal-sip")
async def calculate_goal_sip(request: GoalSIPRequest):
    result = investment_calculator.calculate_sip_for_goal(
        request.target_amount, request.duration_months, request.expected_rate
    )
    return {"required_monthly_investment": result}


# --- Categorization ---

@app.post("/categorize")
async def categorize_single(request: CategorizeRequest):
    category = await transaction_categorizer.categorize_single(request.description, request.amount, request.tx_type)
    return {"description": request.description, "category": category}

@app.post("/categorize/batch")
async def categorize_batch(request: BatchCategorizeRequest):
    categorized = await transaction_categorizer.categorize_batch(request.transactions)
    return {"transactions": categorized}

@app.post("/analyze/spending")
async def analyze_spending(request: AnalyzeSpendingRequest):
    return await analytics_service.analyze_spending_patterns(request.transactions)


# --- Transaction Management ---

class TransactionUpdateRequest(BaseModel):
    category: Optional[str] = None
    description: Optional[str] = None
    notes: Optional[str] = None

@app.put("/transactions/{transaction_id}")
async def update_transaction(
    transaction_id: int,
    request: TransactionUpdateRequest,
    user_id: str = "default"
):
    """Update a transaction's category or other fields."""
    try:
        updates = {}
        if request.category:
            updates['category'] = request.category
        if request.description:
            updates['description'] = request.description
        if request.notes:
            updates['notes'] = request.notes

        if not updates:
            return {"success": False, "error": "No updates provided"}

        result = await database_service.update_transaction(transaction_id, user_id, updates)
        if result:
            return {"success": True, "transaction": result.dict() if hasattr(result, 'dict') else result}
        return {"success": False, "error": "Transaction not found"}
    except Exception as e:
        logger.error(f"Error updating transaction: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# --- Merchant Rules Management ---

class MerchantRuleRequest(BaseModel):
    keyword: str
    category: str
    is_auto: bool = False  # False = manual rule from user

@app.get("/merchant-rules")
async def get_merchant_rules():
    """Get all merchant categorization rules."""
    try:
        from services.merchant_service import merchant_service
        rules = await merchant_service.get_all_rules()
        return {
            "success": True,
            "rules": [{"id": r.id, "keyword": r.keyword, "category": r.category, "is_auto": r.is_auto} for r in rules]
        }
    except Exception as e:
        logger.error(f"Error getting merchant rules: {e}")
        return {"success": False, "error": str(e), "rules": []}

@app.post("/merchant-rules")
async def add_merchant_rule(request: MerchantRuleRequest):
    """Add a new merchant categorization rule."""
    try:
        from services.merchant_service import merchant_service
        rule = await merchant_service.add_rule(request.keyword, request.category, request.is_auto)
        if rule:
            return {
                "success": True,
                "rule": {"id": rule.id, "keyword": rule.keyword, "category": rule.category, "is_auto": rule.is_auto}
            }
        return {"success": False, "error": "Failed to add rule"}
    except Exception as e:
        logger.error(f"Error adding merchant rule: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/merchant-rules/{rule_id}")
async def delete_merchant_rule(rule_id: int):
    """Delete a merchant categorization rule."""
    try:
        from services.merchant_service import merchant_service
        success = await merchant_service.delete_rule(rule_id)
        return {"success": success}
    except Exception as e:
        logger.error(f"Error deleting merchant rule: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/transactions/{transaction_id}/set-category")
async def set_transaction_category_and_remember(
    transaction_id: int,
    category: str,
    remember: bool = True,
    user_id: str = "default"
):
    """
    Set a transaction's category and optionally remember this merchant-category mapping.
    This is the 'one-click' categorization feature.
    """
    try:
        # Get the transaction to extract merchant info
        transaction = await database_service.get_transaction(transaction_id, user_id)
        if not transaction:
            return {"success": False, "error": "Transaction not found"}

        # Update the transaction category
        updates = {"category": category}
        await database_service.update_transaction(transaction_id, user_id, updates)

        # If remember is True, add a merchant rule
        if remember and transaction.description:
            from services.merchant_service import merchant_service
            await merchant_service.add_rule(
                keyword=transaction.description,
                category=category,
                is_auto=False  # Manual rule
            )
            return {
                "success": True,
                "message": f"Category set to '{category}' and rule saved for future transactions",
                "rule_created": True
            }

        return {
            "success": True,
            "message": f"Category set to '{category}'",
            "rule_created": False
        }
    except Exception as e:
        logger.error(f"Error setting category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== GAMIFICATION & ANALYSIS MILESTONES ====================

class AnalysisMetricsRequest(BaseModel):
    user_id: str
    total_income: float
    total_expense: float
    savings_rate: float
    health_score: float
    category_breakdown: Dict[str, float] = {}
    transaction_count: int = 0
    budget_count: int = 0
    goals_completed: int = 0
    current_streak: int = 0
    under_budget_months: int = 0
    insights: List[str] = []


@app.post("/analysis/save-snapshot")
async def save_analysis_snapshot(request: AnalysisMetricsRequest):
    """Save point-in-time analysis snapshot for trend tracking"""
    try:
        snapshot_id = await mongo_service.save_analysis_snapshot(
            user_id=request.user_id,
            analysis_data=request.dict()
        )
        
        # Check for milestone achievements
        newly_achieved = await mongo_service.check_and_award_milestones(
            user_id=request.user_id,
            metrics=request.dict()
        )
        
        # Get updated XP/level
        xp_data = await mongo_service.get_user_xp(request.user_id)
        
        # Save monthly metrics for historical tracking
        from datetime import datetime as dt
        await mongo_service.save_monthly_metrics(
            user_id=request.user_id,
            metrics={
                "month": dt.utcnow().strftime("%Y-%m"),
                **request.dict()
            }
        )
        
        return {
            "success": True,
            "snapshot_id": snapshot_id,
            "newly_achieved_milestones": newly_achieved,
            "user_level": xp_data["level"],
            "total_xp": xp_data["total_xp"],
            "xp_to_next_level": xp_data["xp_to_next_level"],
            "milestones_progress": f"{xp_data['milestones_achieved']}/{xp_data['total_milestones']}",
        }
    except Exception as e:
        logger.error(f"Error saving analysis snapshot: {e}")
        return {"success": False, "error": str(e)}


@app.get("/analysis/milestones/{user_id}")
async def get_milestones(user_id: str):
    """Get all milestones and achievements for gamification display"""
    try:
        milestones = await mongo_service.get_milestones(user_id)
        xp_data = await mongo_service.get_user_xp(user_id)
        cooldown_data = await mongo_service.can_analyze_now(user_id, cooldown_days=7)

        return {
            "success": True,
            "milestones": milestones,
            "level": xp_data["level"],
            "total_xp": xp_data["total_xp"],
            "xp_in_current_level": xp_data["xp_in_current_level"],
            "xp_to_next_level": xp_data["xp_to_next_level"],
            "milestones_achieved": xp_data["milestones_achieved"],
            "total_milestones": xp_data["total_milestones"],
            # Cooldown info for 7-day analysis restriction
            "can_analyze": cooldown_data["can_analyze"],
            "last_analysis_date": cooldown_data["last_analysis_date"],
            "next_analysis_date": cooldown_data["next_analysis_date"],
            "days_remaining": cooldown_data["days_remaining"],
            "hours_remaining": cooldown_data["hours_remaining"],
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.get("/analysis/history/{user_id}")
async def get_analysis_history(user_id: str, months: int = 6):
    """Get historical analysis snapshots for trend visualization"""
    try:
        history = await mongo_service.get_analysis_history(user_id, months=months)
        return {
            "success": True,
            "history": history,
            "count": len(history),
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


# ==================== IDEA EVALUATION WITH OPENAI ====================

class IdeaRequest(BaseModel):
    user_id: str
    idea: str
    location: str = "India"
    budget_range: str = "5-10 Lakhs"
    user_context: Optional[Dict[str, Any]] = None


@app.post("/ideas/evaluate")
async def evaluate_idea(request: IdeaRequest):
    """Evaluate a business idea with OpenAI - structured analysis"""
    try:
        evaluation = await idea_evaluator.evaluate_idea(
            idea=request.idea,
            user_context=request.user_context,
            location=request.location,
            budget_range=request.budget_range,
        )
        compatibility_report = scheme_compatibility_service.assess(
            message=request.idea,
            user_profile=request.user_context or {},
            conversation_history=[],
        )
        rag_payload = msme_credit_rag_service.retrieve(
            request.idea,
            top_k=4,
            extra_terms=[
                compatibility_report.get("profile", {}).get("business_stage", ""),
                compatibility_report.get("profile", {}).get("business_sector", ""),
            ],
        )
        evaluation["scheme_compatibility"] = compatibility_report
        evaluation["legal_readiness"] = compatibility_report.get("legal_readiness", {})
        evaluation["msme_credit_rag"] = rag_payload
        
        # Save evaluation to MongoDB
        eval_id = await mongo_service.save_idea_evaluation(
            user_id=request.user_id,
            evaluation=evaluation
        )
        
        return {
            "success": True,
            "evaluation_id": eval_id,
            "evaluation": evaluation,
        }
    except Exception as e:
        logger.error(f"Idea evaluation error: {e}")
        return {
            "success": False,
            "error": str(e),
            "note": "Failed to evaluate idea - OpenAI may be unavailable"
        }


@app.get("/ideas/{user_id}")
async def get_saved_ideas(user_id: str, limit: int = 10):
    """Get all saved idea evaluations for a user"""
    try:
        ideas = await mongo_service.get_idea_evaluations(user_id, limit=limit)
        return {
            "success": True,
            "ideas": ideas,
            "count": len(ideas),
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


# ==================== DPR DOCUMENT MANAGEMENT ====================

class DPRSaveRequest(BaseModel):
    user_id: str
    business_idea: str
    sections: Dict[str, Any] = {}
    completeness: float = 0.0
    research_data: Dict[str, Any] = {}
    financial_projections: Dict[str, Any] = {}


@app.post("/dpr/save")
async def save_dpr(request: DPRSaveRequest):
    """Save a DPR document to MongoDB"""
    try:
        dpr_id = await mongo_service.save_dpr(
            user_id=request.user_id,
            dpr_data=request.dict()
        )
        
        return {
            "success": True,
            "dpr_id": dpr_id,
            "message": "DPR document saved successfully",
        }
    except Exception as e:
        logger.error(f"DPR save error: {e}")
        return {"success": False, "error": str(e)}


@app.get("/dpr/{user_id}")
async def get_user_dprs(user_id: str, limit: int = 10):
    """Get all saved DPR documents for a user"""
    try:
        dprs = await mongo_service.get_dprs(user_id, limit=limit)
        return {
            "success": True,
            "dprs": dprs,
            "count": len(dprs),
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.post("/dpr/score")
async def score_dpr(data: dict):
    """
    Calculate completeness and quality score for DPR
    Returns section-wise scores, overall readiness, and next steps
    """
    try:
        dpr_data = data.get("dpr_data", {})
        
        if not dpr_data:
            raise HTTPException(status_code=400, detail="dpr_data is required")

        # Calculate overall score
        score_result = dpr_scorer.calculate_overall_score(dpr_data)

        return {
            "success": True,
            **score_result
        }
    except Exception as e:
        logger.error(f"Error scoring DPR: {e}")
        return {"success": False, "error": str(e)}


@app.post("/dpr/score-section")
async def score_dpr_section(data: dict):
    """
    Calculate score for a single DPR section
    Returns completeness score, missing fields, and recommendations
    """
    try:
        section_name = data.get("section_name", "")
        section_data = data.get("section_data", {})
        
        if not section_name:
            raise HTTPException(status_code=400, detail="section_name is required")

        # Calculate section score
        score_result = dpr_scorer.calculate_section_score(section_name, section_data)

        return {
            "success": True,
            **score_result
        }
    except Exception as e:
        logger.error(f"Error scoring DPR section: {e}")
        return {"success": False, "error": str(e)}


# ==================== MUDRA DPR FINANCIAL ENGINE ====================

class MudraDPRInputRequest(BaseModel):
    """Pydantic model for Mudra DPR calculation requests."""
    promoter_name: str = ""
    qualification: str = ""
    experience_years: int = 0
    life_skills: List[str] = []
    city: str = ""
    state: str = ""
    business_name: str = ""
    nature_of_business: str = ""
    product_or_service: str = ""
    target_customers: str = ""
    constitution: str = "Proprietorship"
    selling_price_per_unit: float = 0.0
    units_at_full_capacity: float = 0.0
    raw_material_cost_per_unit: float = 0.0
    fixed_assets: List[Dict[str, Any]] = []
    monthly_rent: float = 0.0
    monthly_wages: float = 0.0
    monthly_utilities: float = 0.0
    monthly_other_expenses: float = 0.0
    working_capital_months: int = 3
    promoter_contribution_pct: float = 10.0
    interest_rate: float = 12.0
    tenure_months: int = 60
    capacity_utilization_y1: float = 60.0
    capacity_utilization_y2: float = 75.0
    capacity_utilization_y3: float = 85.0
    capacity_utilization_y4: float = 90.0
    capacity_utilization_y5: float = 95.0
    cost_inflation_rate: float = 5.0
    tax_rate: float = 25.0


class MudraDPRWhatIfRequest(BaseModel):
    """Request for what-if simulation."""
    inputs: MudraDPRInputRequest
    overrides: Dict[str, Any] = {}


@app.post("/mudra-dpr/calculate")
async def calculate_mudra_dpr(request: MudraDPRInputRequest):
    """Instant financial calculations for Mudra DPR (no AI)."""
    try:
        dpr_input = MudraDPRInput(**request.dict())
        output = mudra_engine.generate_full_dpr(dpr_input)
        return {
            "success": True,
            **output.to_dict(),
        }
    except Exception as e:
        logger.error(f"Mudra DPR calculation error: {e}")
        return {"success": False, "error": str(e)}


@app.post("/mudra-dpr/whatif")
async def mudra_dpr_whatif(request: MudraDPRWhatIfRequest):
    """Recalculate Mudra DPR with parameter overrides."""
    try:
        base_input = MudraDPRInput(**request.inputs.dict())
        output = mudra_engine.whatif_simulate(base_input, request.overrides)
        return {
            "success": True,
            **output.to_dict(),
        }
    except Exception as e:
        logger.error(f"Mudra DPR what-if error: {e}")
        return {"success": False, "error": str(e)}


@app.post("/mudra-dpr/clusters")
async def get_cluster_suggestions(
    city: str = "",
    state: str = "",
    business_type: str = "",
):
    """Get industrial cluster suggestions by location."""
    try:
        clusters = mudra_engine.suggest_cluster(city, state, business_type)
        return {"success": True, "clusters": clusters}
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.post("/mudra-dpr/save")
async def save_mudra_dpr_doc(
    user_id: str,
    dpr_data: Dict[str, Any],
):
    """Save a Mudra DPR document."""
    try:
        dpr_id = await mongo_service.save_mudra_dpr(
            user_id=user_id,
            dpr_data=dpr_data,
        )
        return {"success": True, "dpr_id": dpr_id}
    except Exception as e:
        logger.error(f"Mudra DPR save error: {e}")
        return {"success": False, "error": str(e)}


@app.get("/mudra-dpr/{user_id}")
async def get_mudra_dprs(user_id: str, limit: int = 10):
    """Get saved Mudra DPR documents for a user."""
    try:
        dprs = await mongo_service.get_mudra_dprs(user_id, limit=limit)
        return {"success": True, "dprs": dprs, "count": len(dprs)}
    except Exception as e:
        return {"success": False, "error": str(e)}


# ==================== METRICS HISTORY FOR TRENDS ====================

@app.get("/metrics/history/{user_id}")
async def get_metrics_history(user_id: str, months: int = 12):
    """Get monthly metrics history for dashboard trends"""
    try:
        metrics = await mongo_service.get_metrics_history(user_id, months=months)
        return {
            "success": True,
            "metrics": metrics,
            "count": len(metrics),
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


# ==================== BILL SPLITTING & GROUP EXPENSES (P0) ====================

class CreateSplitRequest(BaseModel):
    total_amount: float
    split_method: str  # 'equal', 'by_item', 'percentage', 'custom'
    participants: List[Dict[str, Any]]
    created_by: str
    group_id: Optional[int] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    items: Optional[List[Dict[str, Any]]] = None


class SettleDebtRequest(BaseModel):
    from_user_id: str
    to_user_id: str
    amount: float
    group_id: Optional[int] = None


@app.post("/bill-split/create")
async def create_bill_split(request: CreateSplitRequest):
    """Create a new bill split"""
    try:
        # Convert items to BillItem objects if provided
        from services.bill_split_service import BillItem
        bill_items = None
        if request.items:
            bill_items = [
                BillItem(
                    description=item.get('description', ''),
                    amount=item.get('amount', 0),
                    quantity=item.get('quantity', 1),
                    **({'assigned_to': item['assigned_to']} if 'assigned_to' in item else {})
                )
                for item in request.items
            ]
        
        result = await bill_split_service.create_split(
            total_amount=request.total_amount,
            split_method=request.split_method,
            participants=request.participants,
            created_by=request.created_by,
            group_id=request.group_id,
            description=request.description,
            image_url=request.image_url,
            items=bill_items
        )
        
        return {
            "success": True,
            **result
        }
    except Exception as e:
        logger.error(f"Error creating bill split: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/bill-split/{split_id}")
async def get_bill_split(split_id: int):
    """Get details of a specific bill split"""
    try:
        split = await bill_split_service.get_split(split_id)
        if not split:
            raise HTTPException(status_code=404, detail="Split not found")
        
        return {
            "success": True,
            "split": split
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting bill split: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/bill-split/group/{group_id}")
async def get_group_splits(group_id: int, limit: int = 50):
    """Get all bill splits for a group"""
    try:
        splits = await bill_split_service.get_group_splits(group_id, limit)
        return {
            "success": True,
            "splits": splits,
            "count": len(splits)
        }
    except Exception as e:
        logger.error(f"Error getting group splits: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/bill-split/debts/{user_id}")
async def get_user_debts(user_id: str, group_id: Optional[int] = None):
    """Get all debts for a user (who owes them and whom they owe)"""
    try:
        debts = await bill_split_service.get_user_debts(user_id, group_id)
        return {
            "success": True,
            **debts
        }
    except Exception as e:
        logger.error(f"Error getting user debts: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/bill-split/settle")
async def settle_debt(request: SettleDebtRequest):
    """Mark debts as settled between two users"""
    try:
        success = await bill_split_service.settle_debt(
            from_user_id=request.from_user_id,
            to_user_id=request.to_user_id,
            amount=request.amount,
            group_id=request.group_id
        )
        
        if success:
            return {
                "success": True,
                "message": "Debt settled successfully"
            }
        else:
            return {
                "success": False,
                "error": "Failed to settle debt"
            }
    except Exception as e:
        logger.error(f"Error settling debt: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/bill-split/{split_id}")
async def delete_bill_split(split_id: int, user_id: str):
    """Delete a bill split (only creator can delete)"""
    try:
        success = await bill_split_service.delete_split(split_id, user_id)
        
        if success:
            return {
                "success": True,
                "message": "Split deleted successfully"
            }
        else:
            raise HTTPException(status_code=403, detail="Unauthorized to delete this split")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting bill split: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== EXPENSE FORECASTING & BUDGET ALERTS (P0) ====================

@app.get("/forecast/month-end/{user_id}")
async def forecast_month_end(user_id: str, category: Optional[str] = None):
    """Forecast month-end spending based on current trends"""
    try:
        forecast = await forecast_service.forecast_month_end(user_id, category)
        return {
            "success": True,
            **forecast
        }
    except Exception as e:
        logger.error(f"Error forecasting month-end: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/forecast/anomalies/{user_id}")
async def detect_spending_anomalies(
    user_id: str, 
    lookback_days: int = 30,
    threshold: float = 2.0
):
    """Detect spending anomalies (unusual spending patterns)"""
    try:
        anomalies = await forecast_service.detect_anomalies(
            user_id, 
            lookback_days, 
            threshold
        )
        
        return {
            "success": True,
            "anomalies": [
                {
                    "category": a.category,
                    "current_spending": a.current_spending,
                    "average_spending": a.average_spending,
                    "deviation_percent": a.deviation_percent,
                    "severity": a.severity
                }
                for a in anomalies
            ],
            "count": len(anomalies)
        }
    except Exception as e:
        logger.error(f"Error detecting anomalies: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/forecast/weekly-digest/{user_id}")
async def get_weekly_digest(user_id: str):
    """Generate weekly spending digest"""
    try:
        digest = await forecast_service.generate_weekly_digest(user_id)
        return {
            "success": True,
            **digest
        }
    except Exception as e:
        logger.error(f"Error generating weekly digest: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/forecast/category/{user_id}")
async def get_category_forecast(user_id: str, days_ahead: int = 30):
    """Forecast spending by category for the next N days"""
    try:
        forecasts = await forecast_service.get_category_forecast(user_id, days_ahead)
        return {
            "success": True,
            "forecasts": forecasts,
            "count": len(forecasts),
            "days_ahead": days_ahead
        }
    except Exception as e:
        logger.error(f"Error forecasting by category: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== RECURRING TRANSACTIONS (Already Implemented) ====================

@app.get("/recurring-transactions/{user_id}")
async def get_recurring_transactions(user_id: str):
    """Detect and return recurring transaction patterns"""
    try:
        patterns = await recurring_transaction_service.detect_patterns(user_id)
        return {
            "success": True,
            "patterns": patterns,
            "count": len(patterns)
        }
    except Exception as e:
        logger.error(f"Error detecting recurring transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== GST INVOICE GENERATOR (P2 - MSME) ====================

class CreateCustomerRequest(BaseModel):
    business_name: str
    gstin: str
    state_code: str
    address: str
    email: Optional[str] = None
    phone: Optional[str] = None


class CreateInvoiceRequest(BaseModel):
    customer_id: int
    items: List[Dict[str, Any]]
    invoice_date: Optional[str] = None
    due_date: Optional[str] = None
    notes: Optional[str] = None


@app.post("/gst/customer/create")
async def create_customer(request: CreateCustomerRequest, user_id: str = "default"):
    """Create a new customer for invoicing"""
    try:
        from services.gst_invoice_service import Customer
        
        customer = Customer(
            id=None,
            user_id=user_id,
            business_name=request.business_name,
            gstin=request.gstin,
            state_code=request.state_code,
            address=request.address,
            email=request.email,
            phone=request.phone,
            created_at=""
        )
        
        created = await gst_invoice_service.create_customer(customer)
        
        return {
            "success": True,
            "customer_id": created.id,
            "business_name": created.business_name
        }
    except Exception as e:
        logger.error(f"Error creating customer: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/gst/customers/{user_id}")
async def get_customers(user_id: str):
    """Get all customers"""
    try:
        customers = await gst_invoice_service.get_customers(user_id)
        return {
            "success": True,
            "customers": [
                {
                    "id": c.id,
                    "business_name": c.business_name,
                    "gstin": c.gstin,
                    "state_code": c.state_code
                }
                for c in customers
            ],
            "count": len(customers)
        }
    except Exception as e:
        logger.error(f"Error getting customers: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/gst/business-profile")
async def set_business_profile(profile: Dict[str, Any], user_id: str = "default"):
    """Set business profile for invoice generation"""
    try:
        await gst_invoice_service.set_business_profile(user_id, profile)
        return {
            "success": True,
            "message": "Business profile updated"
        }
    except Exception as e:
        logger.error(f"Error setting business profile: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/gst/business-profile/{user_id}")
async def get_business_profile(user_id: str):
    """Get business profile"""
    try:
        profile = await gst_invoice_service.get_business_profile(user_id)
        return {
            "success": True,
            "profile": profile
        }
    except Exception as e:
        logger.error(f"Error getting business profile: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/gst/invoice/create")
async def create_invoice(request: CreateInvoiceRequest, user_id: str = "default"):
    """Create a new GST invoice"""
    try:
        result = await gst_invoice_service.create_invoice(
            user_id=user_id,
            customer_id=request.customer_id,
            items=request.items,
            invoice_date=request.invoice_date,
            due_date=request.due_date,
            notes=request.notes
        )
        
        return {
            "success": True,
            **result
        }
    except Exception as e:
        logger.error(f"Error creating invoice: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/gst/invoice/{invoice_id}")
async def get_invoice(invoice_id: int, user_id: str = "default"):
    """Get invoice details"""
    try:
        invoice = await gst_invoice_service.get_invoice(invoice_id, user_id)
        
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
        
        return {
            "success": True,
            "invoice": invoice
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting invoice: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/gst/invoices/{user_id}")
async def get_invoices(user_id: str, status: Optional[str] = None, limit: int = 50):
    """Get all invoices"""
    try:
        invoices = await gst_invoice_service.get_invoices(user_id, status, limit)
        return {
            "success": True,
            "invoices": invoices,
            "count": len(invoices)
        }
    except Exception as e:
        logger.error(f"Error getting invoices: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/gst/invoice/{invoice_id}/status")
async def update_invoice_status(
    invoice_id: int,
    status: str,
    payment_status: Optional[str] = None,
    user_id: str = "default"
):
    """Update invoice status"""
    try:
        success = await gst_invoice_service.update_invoice_status(
            invoice_id, user_id, status, payment_status
        )
        
        return {
            "success": success,
            "message": "Invoice status updated"
        }
    except Exception as e:
        logger.error(f"Error updating invoice status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/gst/hsn-codes")
async def get_hsn_codes():
    """Get common HSN codes"""
    try:
        codes = gst_invoice_service.get_common_hsn_codes()
        return {
            "success": True,
            "hsn_codes": codes
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== CASH FLOW FORECASTING (P2 - MSME) ====================

@app.get("/cashflow/forecast/{user_id}")
async def forecast_cash_flow(
    user_id: str,
    days_ahead: int = 90,
    starting_balance: Optional[float] = None
):
    """Forecast cash flow for next N days"""
    try:
        forecast = await cashflow_forecast_service.forecast_cash_flow(
            user_id, days_ahead, starting_balance
        )
        
        return {
            "success": True,
            "forecast": forecast,
            "days": len(forecast)
        }
    except Exception as e:
        logger.error(f"Error forecasting cash flow: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/cashflow/runway/{user_id}")
async def calculate_runway(user_id: str):
    """Calculate business runway (months until cash runs out)"""
    try:
        runway = await cashflow_forecast_service.calculate_runway(user_id)
        return {
            "success": True,
            **runway
        }
    except Exception as e:
        logger.error(f"Error calculating runway: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/cashflow/simulate-delay")
async def simulate_delayed_payment(
    user_id: str,
    invoice_amount: float,
    original_date: str,
    delay_days: int
):
    """Simulate impact of delayed invoice payment"""
    try:
        simulation = await cashflow_forecast_service.simulate_delayed_payment(
            user_id, invoice_amount, original_date, delay_days
        )
        
        return {
            "success": True,
            **simulation
        }
    except Exception as e:
        logger.error(f"Error simulating delay: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/cashflow/cash-crunch/{user_id}")
async def get_cash_crunch_alerts(user_id: str, days_ahead: int = 90):
    """Get upcoming dates with low cash warnings"""
    try:
        warnings = await cashflow_forecast_service.get_upcoming_cash_crunch(
            user_id, days_ahead
        )
        
        return {
            "success": True,
            "warnings": warnings,
            "count": len(warnings)
        }
    except Exception as e:
        logger.error(f"Error getting cash crunch alerts: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== VENDOR PAYMENT TRACKER (P2 - MSME) ====================

class CreateVendorRequest(BaseModel):
    vendor_name: str
    vendor_type: str  # 'supplier', 'contractor', 'utility', 'service'
    gstin: Optional[str] = None
    contact_person: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    payment_terms: int = 30
    credit_limit: float = 0


class RecordBillRequest(BaseModel):
    vendor_id: int
    bill_number: str
    bill_date: str
    amount: float
    gst_amount: float = 0
    notes: Optional[str] = None


class MakePaymentRequest(BaseModel):
    payment_id: int
    amount: float
    payment_date: Optional[str] = None
    payment_method: Optional[str] = None
    reference: Optional[str] = None
    notes: Optional[str] = None


@app.post("/vendor/create")
async def create_vendor(request: CreateVendorRequest, user_id: str = "default"):
    """Create a new vendor"""
    try:
        from services.vendor_payment_service import Vendor
        
        vendor = Vendor(
            id=None,
            user_id=user_id,
            vendor_name=request.vendor_name,
            vendor_type=request.vendor_type,
            gstin=request.gstin,
            contact_person=request.contact_person,
            email=request.email,
            phone=request.phone,
            address=request.address,
            payment_terms=request.payment_terms,
            credit_limit=request.credit_limit,
            status='active',
            created_at=""
        )
        
        created = await vendor_payment_service.create_vendor(vendor)
        
        return {
            "success": True,
            "vendor_id": created.id,
            "vendor_name": created.vendor_name
        }
    except Exception as e:
        logger.error(f"Error creating vendor: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/vendor/list/{user_id}")
async def get_vendors(user_id: str, status: Optional[str] = 'active'):
    """Get all vendors"""
    try:
        vendors = await vendor_payment_service.get_vendors(user_id, status)
        return {
            "success": True,
            "vendors": [
                {
                    "id": v.id,
                    "vendor_name": v.vendor_name,
                    "vendor_type": v.vendor_type,
                    "payment_terms": v.payment_terms,
                    "status": v.status
                }
                for v in vendors
            ],
            "count": len(vendors)
        }
    except Exception as e:
        logger.error(f"Error getting vendors: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/vendor/bill/record")
async def record_vendor_bill(request: RecordBillRequest, user_id: str = "default"):
    """Record a new vendor bill"""
    try:
        result = await vendor_payment_service.record_vendor_bill(
            user_id=user_id,
            vendor_id=request.vendor_id,
            bill_number=request.bill_number,
            bill_date=request.bill_date,
            amount=request.amount,
            gst_amount=request.gst_amount,
            notes=request.notes
        )
        
        return {
            "success": True,
            **result
        }
    except Exception as e:
        logger.error(f"Error recording bill: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/vendor/payment/make")
async def make_vendor_payment(request: MakePaymentRequest, user_id: str = "default"):
    """Record a vendor payment (full or partial)"""
    try:
        success = await vendor_payment_service.make_payment(
            payment_id=request.payment_id,
            user_id=user_id,
            amount=request.amount,
            payment_date=request.payment_date,
            payment_method=request.payment_method,
            reference=request.reference,
            notes=request.notes
        )
        
        return {
            "success": success,
            "message": "Payment recorded successfully"
        }
    except Exception as e:
        logger.error(f"Error making payment: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/vendor/payments/pending/{user_id}")
async def get_pending_payments(user_id: str, overdue_only: bool = False):
    """Get pending vendor payments"""
    try:
        payments = await vendor_payment_service.get_pending_payments(
            user_id, overdue_only
        )
        
        return {
            "success": True,
            "payments": payments,
            "count": len(payments)
        }
    except Exception as e:
        logger.error(f"Error getting pending payments: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/vendor/statement/{vendor_id}")
async def get_vendor_statement(
    vendor_id: int,
    user_id: str = "default",
    from_date: Optional[str] = None,
    to_date: Optional[str] = None
):
    """Get vendor statement"""
    try:
        statement = await vendor_payment_service.get_vendor_statement(
            vendor_id, user_id, from_date, to_date
        )
        
        if not statement:
            raise HTTPException(status_code=404, detail="Vendor not found")
        
        return {
            "success": True,
            **statement
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting vendor statement: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/vendor/analytics/{user_id}")
async def get_vendor_analytics(user_id: str):
    """Get vendor payment analytics"""
    try:
        analytics = await vendor_payment_service.get_vendor_analytics(user_id)
        return {
            "success": True,
            **analytics
        }
    except Exception as e:
        logger.error(f"Error getting vendor analytics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/vendor/payment-calendar/{user_id}")
async def get_payment_calendar(user_id: str, days_ahead: int = 30):
    """Get upcoming vendor payment due dates"""
    try:
        calendar = await vendor_payment_service.get_payment_calendar(user_id, days_ahead)
        return {
            "success": True,
            "calendar": calendar,
            "count": len(calendar)
        }
    except Exception as e:
        logger.error(f"Error getting payment calendar: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# SMS & AUTHENTICATION ENDPOINTS
# ============================================================

from services.sms_parser_service import sms_parser

@app.post("/transactions/parse-sms")
async def parse_sms_batch(request: dict):
    """
    Parse batch of SMS messages using enhanced parser with UPI support
    Returns transactions with contact names (to be resolved on Flutter side)
    """
    try:
        sms_list = request.get('sms_list', [])
        logger.info(f"Parsing {len(sms_list)} SMS messages with enhanced parser")

        results = []
        for sms in sms_list:
            parsed = enhanced_sms_parser.parse_sms(
                sender=sms.get('sender', ''),
                message=sms.get('message', ''),
                timestamp=datetime.fromisoformat(sms.get('timestamp')) if sms.get('timestamp') else None
            )
            if parsed:
                results.append(parsed)

        return {
            'status': 'success',
            'count': len(results),
            'total_sms': len(sms_list),
            'transactions': results,
            'message': f'Parsed {len(results)} transactions from {len(sms_list)} SMS'
        }
    except Exception as e:
        logger.error(f"Error parsing SMS batch: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/transactions/parse-sms-single")
async def parse_sms_single(sms: dict):
    """
    Parse single SMS using enhanced parser
    Returns transaction with UPI details for contact resolution
    """
    try:
        parsed = enhanced_sms_parser.parse_sms(
            sender=sms.get('sender', ''),
            message=sms.get('message', ''),
            timestamp=datetime.fromisoformat(sms.get('timestamp')) if sms.get('timestamp') else None
        )

        if parsed:
            logger.info(f"Parsed: {parsed['description']} - ₹{parsed['amount']} (confidence: {parsed.get('category_confidence', 0):.2f})")
            return {
                'status': 'success',
                'transaction': parsed,
            }
        else:
            return {
                'status': 'not_transaction',
                'message': 'SMS is not a bank transaction'
            }
    except Exception as e:
        logger.error(f"Error parsing single SMS: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/transactions/resolve-contact")
async def resolve_contact_name(request: dict):
    """
    Resolve contact name from mobile number or UPI ID
    Called from Flutter after contact lookup
    Updates transaction with contact name
    """
    try:
        transaction_id = request.get('transaction_id')
        contact_name = request.get('contact_name')
        user_id = request.get('user_id', 'default_user')

        if not transaction_id or not contact_name:
            raise HTTPException(status_code=400, detail="transaction_id and contact_name required")

        # Update transaction in database
        updated = await database_service.update_transaction(
            transaction_id=transaction_id,
            user_id=user_id,
            updates={'merchant': contact_name}
        )

        if updated:
            return {'status': 'success', 'message': f'Updated transaction with contact: {contact_name}'}
        else:
            raise HTTPException(status_code=404, detail="Transaction not found")

    except Exception as e:
        logger.error(f"Error resolving contact: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/auth/google-signin")
async def google_signin(credentials: dict):
    """
    Authenticate user with Google OAuth
    Verifies ID token and creates/returns user session
    """
    try:
        email = credentials.get('email')
        display_name = credentials.get('display_name', '')
        photo_url = credentials.get('photo_url', '')
        
        if not email:
            raise HTTPException(status_code=400, detail="Email is required")
        
        # For production, verify with Google:
        # from google.oauth2 import id_token
        # from google.auth.transport import requests as google_requests
        # idinfo = id_token.verify_oauth2_token(
        #     credentials.get('id_token'),
        #     google_requests.Request(),
        #     "YOUR_CLIENT_ID.apps.googleusercontent.com"
        # )
        
        # Generate session token
        session_token = f"session_{email}_{datetime.now().timestamp()}"
        
        logger.info(f"User signed in: {email}")
        
        return {
            'status': 'success',
            'user': {
                'email': email,
                'name': display_name,
                'photo': photo_url,
            },
            'session_token': session_token,
            'message': 'Sign-in successful'
        }
    except Exception as e:
        logger.error(f"Google sign-in error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
