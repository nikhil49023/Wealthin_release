"""
WealthIn Agent Service - Founder's OS Backend
FastAPI backend implementing the Sense-Plan-Act agentic architecture:

PERCEPTION LAYER (Sensing):
- Local PDF Parser (pdfplumber) for e-statements
- Zoho Vision Bridge for receipt image OCR

COGNITION LAYER (Thinking):  
- Sarvam Indic Expert for regional language support
- Zoho Catalyst QuickML for general chat
- Lightweight RAG (TF-IDF + SQLite) for Knowledge Retrieval

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
    await mongo_service.initialize()  # Initialize MongoDB/NoSQL
    
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
async def get_dashboard_data(user_id: str):
    return await database_service.get_dashboard_data(user_id)

@app.get("/insights/daily/{user_id}")
async def get_daily_insight(user_id: str):
    return await ai_tools_service.generate_daily_insight(user_id)


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
            
            # Use OpenAI service
            result_dict = openai_service.chat_with_rag(
                user_query=request.query + static_context,
                conversation_history=request.conversation_history,
                model="gpt-4o",
                use_rag=True, # Still use RAG for other docs if needed
                max_tokens=routing_config.get("max_tokens", 4000)
            )
            response_text = result_dict["response"]
            model_used = result_dict["model_used"]
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

class BrainstormRequest(BaseModel):
    user_id: str
    message: str
    conversation_history: Optional[List[Dict]] = []
    enable_web_search: bool = True
    search_category: str = "general"
    persona: str = "neutral"  # Thinking hat persona

@app.post("/brainstorm/chat")
async def brainstorm_chat(request: BrainstormRequest):
    """Chat with AI using selected persona (thinking hat)."""
    try:
        result = await openai_brainstorm_service.brainstorm(
            user_message=request.message,
            conversation_history=request.conversation_history,
            enable_web_search=request.enable_web_search,
            search_category=request.search_category,
            persona=request.persona
        )
        return {
            "success": True,
            "content": result.content,
            "sources": result.sources
        }
    except Exception as e:
        logger.error(f"Brainstorm error: {e}")
        return {"success": False, "error": str(e)}

@app.post("/brainstorm/generate-dpr")
async def generate_dpr(request: DPRRequest):
    try:
        market_research = None
        # Future: Integrate web search here
        
        dpr_content = openai_service.generate_dpr(
            business_idea=request.business_idea,
            user_data=request.user_data,
            market_research=market_research
        )
        return {
            "dpr": dpr_content,
            "status": "success",
            "model_used": "gpt-4o"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/brainstorm/status")
async def brainstorm_status():
    return {
        "available": openai_brainstorm_service.is_available,
        "web_search_available": web_search_service.is_available,
        "personas": list(openai_brainstorm_service.PERSONAS.keys())
    }

@app.post("/brainstorm/critique")
async def reverse_brainstorm(request: dict):
    """
    REFINERY STAGE: Critique ideas to find weaknesses.
    Uses reverse brainstorming psychology.
    """
    try:
        ideas = request.get("ideas", [])
        history = request.get("conversation_history", [])

        result = await openai_brainstorm_service.reverse_brainstorm(
            ideas=ideas,
            conversation_history=history
        )

        return {
            "success": True,
            "critique": result.content,
            "sources": result.sources
        }
    except Exception as e:
        logger.error(f"Reverse brainstorm error: {e}")
        return {"success": False, "error": str(e)}

@app.post("/brainstorm/extract-canvas")
async def extract_canvas_items(request: dict):
    """
    ANCHOR STAGE: Extract ideas that survived critique for canvas.
    Returns structured ideas ready for visual canvas.
    """
    try:
        history = request.get("conversation_history", [])

        result = await openai_brainstorm_service.extract_canvas_candidates(
            conversation_history=history
        )

        return {
            "success": True,
            "ideas": result["ideas"],
            "message": result["message"]
        }
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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
