# WealthIn Flutter-Python Bridge
# Complete embedded backend - handles all agentic tool calls AND LLM inference
# Pure Python implementation for Chaquopy compatibility

import json
from typing import Optional, Dict, Any, List
import re
from datetime import datetime, timedelta
import math
import urllib.request
import urllib.error
import ssl
import base64
import os
import urllib.parse


try:
    from sarvamai import SarvamAI
    _HAS_SARVAM_SDK = True
except ImportError:
    _HAS_SARVAM_SDK = False



# ==================== CONFIG & KEYS ====================
_sarvam_api_key = "sk_vqh8cfif_MWrqmgK4dyzLoIOqxJn8udIc" # Default/Fallback
_zoho_creds = {
    "project_id": "24392000000011167",
    "org_id": "60056122667",
    "client_id": "1000.S502C4RR4OX00EXMKPMKP246HJ9LYY",
    "client_secret": "267a55dc05912009bb6ee13aabe1ea4e00c303e94d",
    "refresh_token": "1000.9d9d2a78dd2bab8c51eb351f9f6d979f.904b8b7a8543ec3281d18749911184fd"
}

def set_config(config_json: str) -> str:
    """Set API keys and configuration dynamically."""
    global _sarvam_api_key, _zoho_creds
    try:
        config = json.loads(config_json)
        if "sarvam_api_key" in config and config["sarvam_api_key"]:
            _sarvam_api_key = config["sarvam_api_key"]
            
        if "zoho_creds" in config:
            _zoho_creds.update(config["zoho_creds"])
            
        return json.dumps({"success": True, "message": "Configuration updated"})
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def health_check() -> str:
    """
    Check the health of the Python environment.
    Returns status of various components for the Flutter Settings screen.
    """
    global _sarvam_api_key
    
    components = {
        "python": True,  # If we're running this, Python is working
        "sarvam_configured": bool(_sarvam_api_key),
        "pdf_parser_available": False,
        "tools_count": len(AVAILABLE_TOOLS),
    }
    
    # Check if PDF parser is available
    try:
        import fitz
        components["pdf_parser_available"] = True
        components["pdf_engine"] = "pymupdf"
    except ImportError:
        try:
            import pdfplumber
            components["pdf_parser_available"] = True
            components["pdf_engine"] = "pdfplumber"
        except ImportError:
            components["pdf_engine"] = "none"
    
    return json.dumps({
        "success": True,
        "status": "ready",
        "components": components,
        "sarvam_configured": components["sarvam_configured"],
        "pdf_parser_available": components["pdf_parser_available"],
    })



# ==================== TOOL DEFINITIONS ====================
# These are the tools available for the LLM to call

AVAILABLE_TOOLS = [
    {
        "name": "calculate_sip",
        "description": "Calculate SIP (Systematic Investment Plan) returns",
        "parameters": {
            "monthly_investment": "float - Monthly investment amount",
            "annual_rate": "float - Expected annual return rate (%)",
            "years": "int - Investment duration in years"
        }
    },
    {
        "name": "calculate_emi",
        "description": "Calculate EMI (Equated Monthly Installment) for loans",
        "parameters": {
            "principal": "float - Loan principal amount",
            "annual_rate": "float - Annual interest rate (%)",
            "tenure_months": "int - Loan tenure in months"
        }
    },
    {
        "name": "calculate_compound_interest",
        "description": "Calculate compound interest on investments",
        "parameters": {
            "principal": "float - Initial investment",
            "annual_rate": "float - Annual interest rate (%)",
            "years": "float - Investment period in years",
            "compounds_per_year": "int - Compounding frequency (default 12)"
        }
    },
    {
        "name": "calculate_fire_number",
        "description": "Calculate FIRE (Financial Independence Retire Early) target",
        "parameters": {
            "annual_expenses": "float - Annual living expenses",
            "withdrawal_rate": "float - Safe withdrawal rate (default 4%)"
        }
    },
    {
        "name": "calculate_emergency_fund",
        "description": "Analyze emergency fund adequacy",
        "parameters": {
            "monthly_expenses": "float - Monthly expenses",
            "current_savings": "float - Current emergency savings",
            "target_months": "int - Target months of coverage (default 6)"
        }
    },
    {
        "name": "categorize_transaction",
        "description": "Categorize a transaction based on description",
        "parameters": {
            "description": "str - Transaction description",
            "amount": "float - Transaction amount"
        }
    },
    {
        "name": "analyze_spending",
        "description": "Analyze spending patterns from transactions",
        "parameters": {
            "transactions": "list - List of transaction objects"
        }
    },
    {
        "name": "calculate_savings_rate",
        "description": "Calculate savings rate from income and expenses",
        "parameters": {
            "income": "float - Total income",
            "expenses": "float - Total expenses"
        }
    },
    {
        "name": "get_financial_advice",
        "description": "Get personalized financial advice based on user data",
        "parameters": {
            "income": "float - Monthly income",
            "expenses": "float - Monthly expenses",
            "savings": "float - Current savings",
            "debt": "float - Total debt",
            "goals": "list - Financial goals"
        }
    },
    {
        "name": "calculate_debt_payoff",
        "description": "Calculate debt payoff timeline and strategy",
        "parameters": {
            "debts": "list - List of debts with balance, rate, min_payment",
            "extra_payment": "float - Extra monthly payment available"
        }
    },
    {
        "name": "project_net_worth",
        "description": "Project future net worth based on current trajectory",
        "parameters": {
            "current_net_worth": "float - Current net worth",
            "monthly_savings": "float - Monthly savings rate",
            "investment_return": "float - Expected annual return (%)",
            "years": "int - Projection period in years"
        }
    },
    {
        "name": "calculate_tax_savings",
        "description": "Calculate tax savings under Indian tax law (80C, 80D, etc.)",
        "parameters": {
            "income": "float - Annual income",
            "investments_80c": "float - 80C investments (PPF, ELSS, etc.)",
            "health_insurance_80d": "float - Health insurance premium",
            "home_loan_interest": "float - Home loan interest (Section 24)"
        }
    },
    {
        "name": "web_search",
        "description": "Search the internet using DuckDuckGo. Use for finding prices, products, hotels, news, reviews, etc. Add context to your query for better results (e.g., 'iPhone 15 price Amazon India' or 'best hotels in Goa MakeMyTrip').",
        "parameters": { 
            "query": "str - Search query - be specific for better results"
        }
    },
    # === AGENTIC ACTION TOOLS ===
    {
        "name": "create_budget",
        "description": "Create a new budget for tracking expenses in a category",
        "parameters": {
            "category": "str - Budget category (e.g., Food, Transport, Shopping)",
            "amount": "float - Monthly budget limit in INR",
            "period": "str - Budget period: 'weekly', 'monthly', or 'yearly'"
        },
        "requires_confirmation": True
    },
    {
        "name": "create_savings_goal",
        "description": "Create a new savings goal",
        "parameters": {
            "name": "str - Goal name (e.g., 'Vacation to Goa', 'New Laptop')",
            "target_amount": "float - Target amount to save in INR",
            "deadline": "str - Optional deadline (YYYY-MM-DD format)"
        },
        "requires_confirmation": True
    },
    {
        "name": "add_transaction",
        "description": "Add a new expense or income transaction",
        "parameters": {
            "amount": "float - Transaction amount in INR",
            "description": "str - What was this for",
            "category": "str - Category (Food, Transport, Shopping, etc.)",
            "type": "str - 'expense' or 'income'"
        },
        "requires_confirmation": True
    },
    {
        "name": "parse_pdf_statement",
        "description": "Parse bank statement directly from PDF file",
        "parameters": {
            "file_path": "str - Path to the PDF file"
        }
    }
]

# Agentic Actions Storage (for confirmation flow)
_pending_actions = {}



# ==================== TOOL EXECUTOR ====================

def execute_tool(tool_name: str, args: Dict[str, Any]) -> str:
    """
    Execute a tool by name with given arguments.
    This is the main entry point for the LLM to call tools.
    """
    try:
        tool_functions = {
            "calculate_sip": calculate_sip_maturity,
            "calculate_emi": calculate_emi,
            "calculate_compound_interest": calculate_compound_interest,
            "calculate_fire_number": calculate_fire_number,
            "calculate_emergency_fund": calculate_emergency_fund,
            "categorize_transaction": categorize_transaction,
            "analyze_spending": analyze_spending_trends,
            "calculate_savings_rate": calculate_savings_rate,
            "get_financial_advice": get_financial_advice,
            "calculate_debt_payoff": calculate_debt_payoff,
            "project_net_worth": project_net_worth,
            "calculate_tax_savings": calculate_tax_savings,
            "extract_receipt": extract_receipt_from_path,
            "parse_bank_statement": parse_bank_statement,
            "parse_pdf_statement": parse_pdf_directly,
            # Agentic Action Tools
            "create_budget": prepare_create_budget,
            "create_savings_goal": prepare_create_goal,
            "add_transaction": prepare_add_transaction,
        }
        
        # Route ALL search-related tools to unified web_search
        search_tools = ["web_search", "search_shopping", "search_news", "search_amazon", 
                       "search_flipkart", "search_myntra", "search_hotels", "search_maps"]
        if tool_name in search_tools:
            query = args.get("query", "")
            return execute_web_search(query)
        
        if tool_name not in tool_functions:
            return json.dumps({
                "success": False,
                "error": f"Unknown tool: {tool_name}",
                "available_tools": list(tool_functions.keys()) + ["web_search"]
            })
        
        # Call the tool function with args
        result = tool_functions[tool_name](**args)
        return result
        
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"Tool execution error: {str(e)}",
            "tool": tool_name
        })


# ==================== AGENTIC ACTION TOOLS ====================

def prepare_create_budget(category: str, amount: float, period: str = "monthly") -> str:
    """Prepare budget creation - requires user confirmation."""
    action_id = f"budget_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    _pending_actions[action_id] = {
        "type": "create_budget",
        "data": {"category": category, "amount": amount, "period": period},
        "created_at": datetime.now().isoformat()
    }
    return json.dumps({
        "success": True,
        "requires_confirmation": True,
        "action_id": action_id,
        "action_type": "create_budget",
        "action_data": {
            "category": category,
            "amount": amount,
            "period": period
        },
        "confirmation_message": f"📊 Create a **{period}** budget of **₹{amount:,.0f}** for **{category}**?",
        "buttons": ["✅ Yes, create it", "❌ Cancel"]
    })


def prepare_create_goal(name: str, target_amount: float, deadline: str = None) -> str:
    """Prepare savings goal creation - requires user confirmation."""
    action_id = f"goal_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    _pending_actions[action_id] = {
        "type": "create_savings_goal",
        "data": {"name": name, "target_amount": target_amount, "deadline": deadline},
        "created_at": datetime.now().isoformat()
    }
    deadline_text = f" by **{deadline}**" if deadline else ""
    return json.dumps({
        "success": True,
        "requires_confirmation": True,
        "action_id": action_id,
        "action_type": "create_savings_goal",
        "action_data": {
            "name": name,
            "target_amount": target_amount,
            "deadline": deadline
        },
        "confirmation_message": f"🎯 Create savings goal **'{name}'** for **₹{target_amount:,.0f}**{deadline_text}?",
        "buttons": ["✅ Yes, create it", "❌ Cancel"]
    })


def prepare_add_transaction(amount: float, description: str, category: str, type: str = "expense") -> str:
    """Prepare transaction addition - requires user confirmation."""
    action_id = f"tx_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    _pending_actions[action_id] = {
        "type": "add_transaction",
        "data": {"amount": amount, "description": description, "category": category, "type": type},
        "created_at": datetime.now().isoformat()
    }
    icon = "💸" if type == "expense" else "💰"
    return json.dumps({
        "success": True,
        "requires_confirmation": True,
        "action_id": action_id,
        "action_type": "add_transaction",
        "action_data": {
            "amount": amount,
            "description": description,
            "category": category,
            "type": type
        },
        "confirmation_message": f"{icon} Add **{type}** of **₹{amount:,.0f}** for **{description}** ({category})?",
        "buttons": ["✅ Yes, add it", "❌ Cancel"]
    })


def confirm_action(action_id: str) -> str:
    """Confirm and execute a pending action."""
    if action_id not in _pending_actions:
        return json.dumps({"success": False, "error": "Action not found or expired"})
    
    action = _pending_actions.pop(action_id)
    return json.dumps({
        "success": True,
        "action_confirmed": True,
        "action_type": action["type"],
        "action_data": action["data"],
        "message": f"✅ {action['type'].replace('_', ' ').title()} confirmed! The app will now save this."
    })


def cancel_action(action_id: str) -> str:
    """Cancel a pending action."""
    if action_id in _pending_actions:
        _pending_actions.pop(action_id)
    return json.dumps({
        "success": True,
        "action_cancelled": True,
        "message": "❌ Action cancelled."
    })


# ==================== DIRECT PDF PARSING ====================

MAX_PDF_PAGES = 5  # Maximum pages allowed for PDF parsing

def _get_pdf_page_count(file_path: str) -> int:
    """Get the number of pages in a PDF file."""
    try:
        try:
            import pdfplumber
            with pdfplumber.open(file_path) as pdf:
                return len(pdf.pages)
        except ImportError:
            try:
                import fitz  # PyMuPDF
                doc = fitz.open(file_path)
                count = len(doc)
                doc.close()
                return count
            except ImportError:
                # If no PDF library available, return -1 to skip validation
                return -1
    except Exception:
        return -1


def _parse_pdf_with_sarvam(file_path: str) -> dict:
    """Parse PDF using Sarvam AI Document Intelligence API."""
    global _sarvam_api_key
    
    if not _sarvam_api_key:
        return {"success": False, "error": "Sarvam API key not configured"}
    
    try:
        # Step 1: Create a Document Intelligence job
        create_job_url = "https://api.sarvam.ai/v1/document-intelligence/jobs"
        job_body = {
            "language": "en-IN",
            "output_format": "json"  # Use JSON for easier parsing
        }
        
        req = urllib.request.Request(
            create_job_url,
            data=json.dumps(job_body).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'api-subscription-key': _sarvam_api_key
            },
            method='POST'
        )
        
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        with urllib.request.urlopen(req, timeout=30, context=context) as response:
            job_data = json.loads(response.read().decode('utf-8'))
        
        job_id = job_data.get('job_id')
        if not job_id:
            return {"success": False, "error": "Failed to create document job"}
        
        print(f"[Sarvam] Created job: {job_id}")
        
        # Step 2: Get upload URL
        upload_url_endpoint = f"https://api.sarvam.ai/v1/document-intelligence/jobs/{job_id}/upload-links"
        req = urllib.request.Request(
            upload_url_endpoint,
            headers={
                'api-subscription-key': _sarvam_api_key
            },
            method='GET'
        )
        
        with urllib.request.urlopen(req, timeout=30, context=context) as response:
            upload_data = json.loads(response.read().decode('utf-8'))
        
        upload_url = upload_data.get('upload_url')
        if not upload_url:
            return {"success": False, "error": "Failed to get upload URL"}
        
        # Step 3: Upload the PDF file
        with open(file_path, 'rb') as f:
            pdf_bytes = f.read()
        
        upload_req = urllib.request.Request(
            upload_url,
            data=pdf_bytes,
            headers={
                'Content-Type': 'application/pdf'
            },
            method='PUT'
        )
        
        with urllib.request.urlopen(upload_req, timeout=60, context=context) as response:
            pass  # Upload successful
        
        print(f"[Sarvam] Uploaded PDF to {job_id}")
        
        # Step 4: Start processing
        start_url = f"https://api.sarvam.ai/v1/document-intelligence/jobs/{job_id}/start"
        req = urllib.request.Request(
            start_url,
            headers={
                'api-subscription-key': _sarvam_api_key
            },
            method='POST'
        )
        
        with urllib.request.urlopen(req, timeout=30, context=context) as response:
            pass  # Job started
        
        print(f"[Sarvam] Job {job_id} started")
        
        # Step 5: Poll for completion (max 60 seconds)
        status_url = f"https://api.sarvam.ai/v1/document-intelligence/jobs/{job_id}"
        import time
        max_attempts = 30
        for attempt in range(max_attempts):
            time.sleep(2)
            
            req = urllib.request.Request(
                status_url,
                headers={
                    'api-subscription-key': _sarvam_api_key
                },
                method='GET'
            )
            
            with urllib.request.urlopen(req, timeout=30, context=context) as response:
                status_data = json.loads(response.read().decode('utf-8'))
            
            job_state = status_data.get('job_state', '')
            print(f"[Sarvam] Job state: {job_state} (attempt {attempt + 1}/{max_attempts})")
            
            if job_state == 'Completed':
                break
            elif job_state in ['Failed', 'Error']:
                return {"success": False, "error": f"Document processing failed: {job_state}"}
        else:
            return {"success": False, "error": "Document processing timed out"}
        
        # Step 6: Download the output
        download_url = f"https://api.sarvam.ai/v1/document-intelligence/jobs/{job_id}/download"
        req = urllib.request.Request(
            download_url,
            headers={
                'api-subscription-key': _sarvam_api_key
            },
            method='GET'
        )
        
        with urllib.request.urlopen(req, timeout=60, context=context) as response:
            output_data = response.read()
        
        # Parse the output (JSON format contains structured document data)
        try:
            parsed_output = json.loads(output_data.decode('utf-8'))
            # Extract text content from the structured output
            text_content = ""
            if isinstance(parsed_output, dict):
                # Handle different output structures
                if 'pages' in parsed_output:
                    for page in parsed_output['pages']:
                        text_content += page.get('text', '') + "\n\n--- PAGE BREAK ---\n\n"
                elif 'content' in parsed_output:
                    text_content = parsed_output['content']
                elif 'text' in parsed_output:
                    text_content = parsed_output['text']
                else:
                    text_content = json.dumps(parsed_output)
            else:
                text_content = str(parsed_output)
            
            if text_content:
                return {"success": True, "text": text_content, "source": "sarvam_di"}
            else:
                return {"success": False, "error": "Empty output from document intelligence"}
                
        except json.JSONDecodeError:
            # Output might be plain text
            text_content = output_data.decode('utf-8')
            if text_content:
                return {"success": True, "text": text_content, "source": "sarvam_di"}
            else:
                return {"success": False, "error": "Could not parse document output"}
        
    except urllib.error.HTTPError as e:
        error_body = ""
        try:
            error_body = e.read().decode('utf-8')
        except:
            pass
        return {"success": False, "error": f"Sarvam API error {e.code}: {error_body}"}
    except Exception as e:
        return {"success": False, "error": f"Sarvam DI error: {str(e)}"}


def parse_pdf_directly(file_path: str) -> str:
    """Parse bank statement from PDF. Uses Sarvam Document Intelligence when available,
    falls back to local parsing with pdfplumber/PyMuPDF."""
    try:
        # Check page count first
        page_count = _get_pdf_page_count(file_path)
        if page_count > MAX_PDF_PAGES:
            return json.dumps({
                "success": False,
                "error": f"PDF has {page_count} pages. Maximum allowed is {MAX_PDF_PAGES} pages. Please upload a shorter document.",
                "page_limit_exceeded": True,
                "page_count": page_count,
                "max_pages": MAX_PDF_PAGES
            })
        
        if page_count > 0:
            print(f"[PDF Parser] Processing PDF with {page_count} page(s)")
        
        # Try Sarvam Document Intelligence first (if API key available)
        if _sarvam_api_key:
            print("[PDF Parser] Attempting Sarvam Document Intelligence...")
            sarvam_result = _parse_pdf_with_sarvam(file_path)
            
            if sarvam_result.get('success') and sarvam_result.get('text'):
                print("[PDF Parser] Sarvam DI succeeded, parsing extracted text...")
                return parse_bank_statement_text(sarvam_result['text'])
            else:
                print(f"[PDF Parser] Sarvam DI failed: {sarvam_result.get('error')}, falling back to local parsing")
        
        # Fallback to local PDF parsing
        text = ""
        
        # Try pdfplumber first
        try:
            import pdfplumber
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text() or ""
                    text += page_text + "\n\n--- PAGE BREAK ---\n\n"
        except ImportError:
            # Fallback to PyMuPDF
            try:
                import fitz  # PyMuPDF
                doc = fitz.open(file_path)
                for page in doc:
                    text += page.get_text() + "\n\n--- PAGE BREAK ---\n\n"
                doc.close()
            except ImportError:
                # Last resort: use system poppler-utils
                import subprocess
                try:
                    result = subprocess.run(
                        ["pdftotext", "-layout", file_path, "-"],
                        capture_output=True, text=True, timeout=30
                    )
                    text = result.stdout
                except:
                    return json.dumps({
                        "success": False,
                        "error": "No PDF parser available. Install pdfplumber or PyMuPDF."
                    })
        
        if not text.strip():
            return json.dumps({
                "success": False,
                "error": "Could not extract text from PDF"
            })
        
        # Parse the extracted text
        return parse_bank_statement_text(text)
        
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"PDF parsing error: {str(e)}"
        })



def get_available_tools() -> str:
    """Get list of available tools for the LLM."""
    return json.dumps({
        "success": True,
        "tools": AVAILABLE_TOOLS
    })


# ==================== ZOHO CONFIG ====================
_zoho_creds = {
    "project_id": "24392000000011167",
    "org_id": "60056122667",
    "client_id": "1000.S502C4RR4OX00EXMKPMKP246HJ9LYY",
    "client_secret": "267a55dc05912009bb6ee13aabe1ea4e00c303e94d",
    "refresh_token": "1000.9d9d2a78dd2bab8c51eb351f9f6d979f.904b8b7a8543ec3281d18749911184fd"
}
_zoho_access_token = None


# ==================== LLM CHAT ====================

# Credentials
# Removed set_api_key in favor of set_config, leaving stub if needed
def set_api_key(api_key: str) -> str:
    """Legacy: Set Sarvam API key."""
    return set_config(json.dumps({"sarvam_api_key": api_key}))


def execute_web_search(query: str) -> str:
    """Execute unified web search using DuckDuckGo."""
    return execute_search_tool(tool_name="web_search", query=query)

def execute_search_tool(tool_name: str, query: str = "") -> str:
    """Execute search tools using DuckDuckGo Search via HTTP."""
    if not query:
        return json.dumps({"success": False, "message": "Query cannot be empty"})
    
    # Strip emojis and special characters from query
    import re as regex_module
    clean_query = regex_module.sub(r'[^\w\s\-.,]', '', query).strip()
    if not clean_query:
        clean_query = query  # Fallback to original if stripping removed everything
    
    # Map tool names to search categories
    category_map = {
        "search_shopping": "shopping",
        "search_amazon": "shopping",
        "search_flipkart": "shopping",
        "search_myntra": "fashion",
        "search_stocks": "stocks",
        "search_real_estate": "real_estate",
        "search_hotels": "hotels",
        "search_maps": "local",
        "search_news": "news",
        "web_search": "general",
    }
    
    category = category_map.get(tool_name, "general")
    refined_query = _refine_search_query(clean_query, category, tool_name)
    
    print(f"[WebSearch] Searching: {refined_query} (category: {category})")
    
    # Use DuckDuckGo JSON API via HTTP
    results = _duckduckgo_search(refined_query, category)
    
    if not results:
        # Try with simpler query
        print("[WebSearch] Retrying with simple query...")
        results = _duckduckgo_search(clean_query, category)
    
    if not results:
        return json.dumps({
            "success": True,
            "action": tool_name,
            "category": category,
            "results": [],
            "message": f"No results found for '{clean_query}'. Try a different search term.",
            "can_add_to_goal": False
        })
    
    # Format response message
    message = _format_search_results_message(results, clean_query, category)
    
    return json.dumps({
        "success": True,
        "action": tool_name,
        "category": category,
        "results": results[:5],
        "message": message,
        "can_add_to_goal": category in ["shopping", "fashion", "stocks"]
    })


def _duckduckgo_search(query: str, category: str = "general") -> list:
    """Search using DuckDuckGo via HTTP requests."""
    try:
        import re as regex_mod
        
        # Use requests if available (faster), otherwise urllib
        try:
            import requests
            use_requests = True
        except ImportError:
            use_requests = False
        
        encoded_query = urllib.parse.quote(query)
        
        # DuckDuckGo HTML endpoint
        url = f"https://html.duckduckgo.com/html/?q={encoded_query}"
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'identity',  # Avoid gzip for easier debugging
            'DNT': '1',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
        
        if use_requests:
            response = requests.get(url, headers=headers, timeout=15)
            html = response.text
        else:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as response:
                html = response.read().decode('utf-8', errors='ignore')
        
        print(f"[WebSearch] Got {len(html)} bytes of HTML")
        
        # Check if we got a real results page or something else
        if 'result__a' not in html and 'web-result' not in html:
            print("[WebSearch] Page does not contain expected result markers")
            # Try to get first 500 chars for debugging
            print(f"[WebSearch] HTML preview: {html[:500]}")
        
        # Parse results from HTML using multiple patterns
        results = []
        
        # Multiple patterns to handle different DDG HTML structures
        patterns = [
            # Pattern 1: Standard result link
            (
                r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>([^<]+)</a>',
                r'<a[^>]+class="result__snippet"[^>]*>(.+?)</a>'
            ),
            # Pattern 2: Alternative with rel=nofollow first
            (
                r'<a[^>]+rel="nofollow"[^>]*href="([^"]+)"[^>]*class="result__a"[^>]*>([^<]+)</a>',
                r'class="result__snippet"[^>]*>(.+?)</a>'
            ),
            # Pattern 3: Web result links (newer DDG format)
            (
                r'<a[^>]+href="(https?://[^"]+)"[^>]*>(.{10,100}?)</a>',
                r'<div[^>]+class="[^"]*snippet[^"]*"[^>]*>(.+?)</div>'
            ),
        ]
        
        for link_pattern, snippet_pattern in patterns:
            matches = regex_mod.findall(link_pattern, html, regex_mod.IGNORECASE)
            if matches:
                print(f"[WebSearch] Pattern matched: found {len(matches)} links")
                snippets_found = regex_mod.findall(snippet_pattern, html, regex_mod.IGNORECASE | regex_mod.DOTALL)
                
                for i, (link, title) in enumerate(matches[:10]):
                    # Clean up the link (remove redirect)
                    if '//duckduckgo.com/' in link:
                        link_match = regex_mod.search(r'uddg=([^&"]+)', link)
                        if link_match:
                            link = urllib.parse.unquote(link_match.group(1))
                    
                    # Skip if link is not valid URL
                    if not link.startswith('http'):
                        continue
                    
                    # Skip DDG internal links
                    if 'duckduckgo.com' in link:
                        continue
                    
                    snippet = ""
                    if i < len(snippets_found):
                        # Clean HTML tags from snippet
                        snippet = regex_mod.sub(r'<[^>]+>', '', snippets_found[i])
                        snippet = snippet.strip()[:300]
                    
                    result = {
                        "title": regex_mod.sub(r'<[^>]+>', '', title).strip(),
                        "link": link,
                        "snippet": snippet,
                        "category": category
                    }
                    
                    # Extract price if shopping category
                    if category in ["shopping", "fashion"]:
                        price = _extract_price_from_text(snippet + " " + title)
                        if price:
                            result["price"] = price
                            result["price_display"] = f"₹{price:,.0f}"
                        
                        # Determine source from link
                        link_lower = link.lower()
                        if "amazon" in link_lower:
                            result["source"] = "Amazon"
                        elif "flipkart" in link_lower:
                            result["source"] = "Flipkart"
                        elif "myntra" in link_lower:
                            result["source"] = "Myntra"
                        elif "ajio" in link_lower:
                            result["source"] = "AJIO"
                        else:
                            result["source"] = "Web"
                    
                    # Extract date for news
                    if category == "news":
                        result["date"] = _extract_date_from_text(snippet)
                    
                    results.append(result)
                
                if results:
                    break
        
        # If HTML parsing failed, try DuckDuckGo Instant Answer API
        if not results:
            print("[WebSearch] HTML parsing failed, trying Instant Answer API")
            api_url = f"https://api.duckduckgo.com/?q={encoded_query}&format=json&no_html=1&skip_disambig=1"
            
            try:
                if use_requests:
                    response = requests.get(api_url, headers=headers, timeout=10)
                    data = response.json()
                else:
                    req = urllib.request.Request(api_url, headers=headers)
                    with urllib.request.urlopen(req, timeout=10) as response:
                        data = json.loads(response.read().decode('utf-8'))
                
                # Extract related topics
                if 'RelatedTopics' in data:
                    for topic in data['RelatedTopics'][:10]:
                        if 'FirstURL' in topic and 'Text' in topic:
                            results.append({
                                "title": topic.get('Text', '')[:100],
                                "link": topic['FirstURL'],
                                "snippet": topic.get('Text', ''),
                                "category": category
                            })
                
                # Extract abstract if available
                if data.get('AbstractText') and data.get('AbstractURL'):
                    results.insert(0, {
                        "title": data.get('Heading', query),
                        "link": data['AbstractURL'],
                        "snippet": data['AbstractText'],
                        "category": category
                    })
                    
            except Exception as api_error:
                print(f"[WebSearch] Instant Answer API error: {api_error}")
        
        print(f"[WebSearch] Final result count: {len(results)}")
        return results
        
    except Exception as e:
        print(f"[WebSearch] Error: {e}")
        import traceback
        traceback.print_exc()
        return []


def _refine_search_query(query: str, category: str, tool_name: str) -> str:
    """Refine search query based on category for better results."""
    if category == "shopping":
        if tool_name == "search_amazon":
            return f"{query} price site:amazon.in"
        elif tool_name == "search_flipkart":
            return f"{query} price site:flipkart.com"
        return f"{query} price best deal India site:amazon.in OR site:flipkart.com"
    
    elif category == "fashion":
        return f"{query} price site:myntra.com OR site:ajio.com OR site:amazon.in"
    
    elif category == "stocks":
        return f"{query} share price NSE BSE live today"
    
    elif category == "real_estate":
        return f"{query} property price trends site:magicbricks.com OR site:99acres.com OR site:housing.com"
    
    elif category == "hotels":
        return f"{query} hotel booking price site:makemytrip.com OR site:booking.com OR site:goibibo.com"
    
    elif category == "local":
        return f"{query} near me address contact"
    
    elif category == "news":
        return f"{query} India news today latest"
    
    # General/finance
    return f"{query} India"


def _extract_price_from_text(text: str) -> Optional[float]:
    """Extract price from text using patterns."""
    patterns = [
        r'₹\s*([\d,]+(?:\.\d{2})?)',
        r'Rs\.?\s*([\d,]+(?:\.\d{2})?)',
        r'INR\s*([\d,]+(?:\.\d{2})?)',
        r'(?:price|cost|at)\s*[:\-]?\s*₹?\s*([\d,]+(?:\.\d{2})?)',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                return float(match.group(1).replace(',', ''))
            except ValueError:
                continue
    return None


def _extract_date_from_text(text: str) -> Optional[str]:
    """Extract date from text."""
    patterns = [
        r'(\d{1,2}\s+\w{3,9}\s+\d{4})',
        r'(\d{4}-\d{2}-\d{2})',
        r'(\d{1,2}/\d{1,2}/\d{4})',
        r'(today|yesterday|\d+\s+hours?\s+ago|\d+\s+days?\s+ago)',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)
    return None


def _format_search_results_message(results: List[Dict], query: str, category: str) -> str:
    """Format search results into a professional, user-friendly message."""
    if not results:
        return f"No results found for '{query}'."
    
    # Clean query of emojis for display
    import re as regex_mod
    clean_query = regex_mod.sub(r'[^\w\s\-.,]', '', query).strip()
    
    if category in ["shopping", "fashion"]:
        msg = f"**Shopping Results for '{clean_query}'**\n\n"
        for i, r in enumerate(results[:5], 1):
            title = r.get("title", "Product")[:50]
            price = r.get("price_display", "Price N/A")
            source = r.get("source", "Web")
            msg += f"{i}. **{title}**\n"
            msg += f"   Price: {price} • {source}\n"
        msg += "\nTap **+** to add to your savings goal."
        return msg
    
    elif category == "stocks":
        msg = f"**Stock Information: '{clean_query}'**\n\n"
        for i, r in enumerate(results[:3], 1):
            title = r.get("title", "")[:60]
            snippet = r.get("snippet", "")[:100]
            msg += f"{i}. {title}\n   {snippet}\n\n"
        return msg
    
    elif category == "hotels":
        msg = f"**Hotel Results: '{clean_query}'**\n\n"
        for i, r in enumerate(results[:5], 1):
            title = r.get("title", "")[:50]
            snippet = r.get("snippet", "")[:80]
            msg += f"{i}. **{title}**\n   {snippet}\n"
        return msg
    
    elif category == "news":
        msg = f"**Latest News: '{clean_query}'**\n\n"
        for i, r in enumerate(results[:5], 1):
            title = r.get("title", "")[:60]
            date = r.get("date", "")
            msg += f"{i}. {title}"
            if date:
                msg += f" ({date})"
            msg += "\n"
        return msg
    
    else:
        msg = f"**Search Results for '{clean_query}'**\n\n"
        for i, r in enumerate(results[:5], 1):
            title = r.get("title", "")[:50]
            snippet = r.get("snippet", "")[:80]
            msg += f"{i}. **{title}**\n   {snippet}\n\n"
        return msg



def _detect_intent_and_auto_execute(query: str) -> Optional[Dict[str, Any]]:
    """
    Pre-LLM intent detection for automatic tool execution.
    Returns tool result if a clear intent is detected, None otherwise.
    
    NOTE: Shopping, hotels, news, etc. are now handled by the ReAct loop
    for multi-step reasoning. Only simple calculations use fast path.
    """
    lower_query = query.lower().strip()
    
    # === CALCULATION INTENT (Pattern-based) - These are fast path ===
    # SIP calculation
    sip_match = re.search(r'sip.*?(\d+[,\d]*)\s*(?:per\s*month|monthly)?.*?(\d+)\s*(?:year|yr)', lower_query, re.IGNORECASE)
    if sip_match:
        monthly = float(sip_match.group(1).replace(',', ''))
        years = int(sip_match.group(2))
        result = calculate_sip_maturity(monthly, 12.0, years)
        data = json.loads(result)
        return {
            'tool_name': 'calculate_sip',
            'data': data,
            'query': query,
            'message': _format_sip_result(data)
        }
    
    # EMI calculation
    emi_match = re.search(r'emi.*?(\d+[,\d]*)\s*(?:lakh|lac|L)?\s*(?:loan)?', lower_query, re.IGNORECASE)
    if emi_match and 'emi' in lower_query:
        amount_str = emi_match.group(1).replace(',', '')
        amount = float(amount_str)
        if 'lakh' in lower_query or 'lac' in lower_query:
            amount *= 100000
        elif 'crore' in lower_query:
            amount *= 10000000
        result = calculate_emi(amount, 9.0, 240)  # Default: 9% for 20 years
        data = json.loads(result)
        return {
            'tool_name': 'calculate_emi',
            'data': data,
            'query': query,
            'message': _format_emi_result(data)
        }
    
    return None


def _format_shopping_results(amazon_data: dict, flipkart_data: dict, query: str) -> str:
    """Format shopping results into a clean, interactive message."""
    msg = f"🛒 **Shopping Results for '{query}'**\n\n"
    
    amazon_items = amazon_data.get('data', [])[:3]
    flipkart_items = flipkart_data.get('data', [])[:3]
    
    if amazon_items:
        msg += "**🅰️ Amazon:**\n"
        for i, item in enumerate(amazon_items, 1):
            name = item.get('title', item.get('name', 'Product'))[:50]
            price = item.get('price', item.get('extracted_price', 'N/A'))
            if isinstance(price, (int, float)):
                price = f"₹{price:,.0f}"
            rating = item.get('rating', '')
            msg += f"{i}. {name}\n   💰 {price}"
            if rating:
                msg += f" ⭐ {rating}"
            msg += "\n"
        msg += "\n"
    
    if flipkart_items:
        msg += "**🔵 Flipkart:**\n"
        for i, item in enumerate(flipkart_items, 1):
            name = item.get('title', item.get('name', 'Product'))[:50]
            price = item.get('price', item.get('extracted_price', 'N/A'))
            if isinstance(price, (int, float)):
                price = f"₹{price:,.0f}"
            rating = item.get('rating', '')
            msg += f"{i}. {name}\n   💰 {price}"
            if rating:
                msg += f" ⭐ {rating}"
            msg += "\n"
    
    if not amazon_items and not flipkart_items:
        msg += "No products found. Try a different search term."
    else:
        msg += "\n💡 _Tap to view details or compare prices!_"
    
    return msg


def _format_fashion_results(data: dict, query: str) -> str:
    """Format Myntra fashion results."""
    items = data.get('data', [])[:5]
    msg = f"👗 **Fashion Results for '{query}'**\n\n"
    
    for i, item in enumerate(items, 1):
        name = item.get('title', item.get('name', 'Item'))[:40]
        price = item.get('price', 'N/A')
        brand = item.get('brand', '')
        msg += f"{i}. {brand} {name}\n   💰 {price}\n"
    
    return msg if items else f"No fashion items found for '{query}'."


def _format_hotel_results(data: dict, query: str) -> str:
    """Format hotel search results."""
    hotels = data.get('data', {}).get('hotels', data.get('data', []))
    if isinstance(hotels, dict):
        hotels = [hotels]
    hotels = hotels[:5] if isinstance(hotels, list) else []
    
    msg = f"🏨 **Hotels for '{query}'**\n\n"
    for i, hotel in enumerate(hotels, 1):
        name = hotel.get('name', 'Hotel')
        price = hotel.get('price', hotel.get('rate', 'N/A'))
        rating = hotel.get('rating', '')
        msg += f"{i}. {name}\n   💰 {price}"
        if rating:
            msg += f" ⭐ {rating}"
        msg += "\n"
    
    return msg if hotels else "No hotels found. Try specifying a location."


def _format_maps_results(data: dict, query: str) -> str:
    """Format local search results."""
    places = data.get('data', {}).get('places', data.get('data', []))
    if isinstance(places, dict):
        places = [places]
    places = places[:5] if isinstance(places, list) else []
    
    msg = f"📍 **Nearby: '{query}'**\n\n"
    for i, place in enumerate(places, 1):
        name = place.get('name', 'Place')
        address = place.get('address', '')[:30]
        rating = place.get('rating', '')
        msg += f"{i}. {name}"
        if rating:
            msg += f" ⭐ {rating}"
        if address:
            msg += f"\n   📍 {address}"
        msg += "\n"
    
    return msg if places else "No places found nearby."


def _format_news_results(data: dict, query: str) -> str:
    """Format news results."""
    articles = data.get('data', {}).get('news', data.get('data', []))
    if isinstance(articles, dict):
        articles = [articles]
    articles = articles[:5] if isinstance(articles, list) else []
    
    msg = f"📰 **Latest News: '{query}'**\n\n"
    for i, article in enumerate(articles, 1):
        title = article.get('title', 'News')[:60]
        source = article.get('source', '')
        msg += f"{i}. {title}"
        if source:
            msg += f"\n   _- {source}_"
        msg += "\n"
    
    return msg if articles else "No news found for this topic."


def _format_sip_result(data: dict) -> str:
    """Format SIP calculation result."""
    if not data.get('success'):
        return "Could not calculate SIP. Please check your inputs."
    
    monthly = data.get('monthly_investment', 0)
    maturity = data.get('maturity_value', 0)
    invested = data.get('total_investment', 0)
    returns = data.get('total_returns', 0)
    years = data.get('years', 0)
    
    return f"""📈 **SIP Calculation**

💰 **Monthly:** ₹{monthly:,.0f}
⏱️ **Duration:** {years} years
📊 **Rate:** 12% p.a.

**Results:**
• Total Invested: ₹{invested:,.0f}
• Maturity Value: **₹{maturity:,.0f}**
• Wealth Gained: ₹{returns:,.0f}

_Start your SIP journey today!_ 🚀"""


def _format_emi_result(data: dict) -> str:
    """Format EMI calculation result."""
    if not data.get('success'):
        return "Could not calculate EMI. Please check your inputs."
    
    emi = data.get('emi', 0)
    principal = data.get('principal', 0)
    interest = data.get('total_interest', 0)
    
    return f"""🏦 **EMI Calculation**

💰 **Loan:** ₹{principal:,.0f}
📊 **Rate:** {data.get('annual_rate', 9)}% p.a.

**Your EMI:** ₹{emi:,.0f}/month
**Total Interest:** ₹{interest:,.0f}

_Consider prepayment to save on interest!_"""


def chat_with_llm(
    query: str,
    conversation_history: List[Dict[str, str]] = None,
    user_context: Dict[str, Any] = None,
    api_key: str = None
) -> str:
    """
    Enhanced AGENTIC chat with ReAct loop.
    The agent can:
    1. Think about what tools to use
    2. Execute tools (search, calculations)
    3. Observe results
    4. Reason and decide next steps
    5. Provide final answer after gathering enough information
    
    NOTE: All queries go through ReAct - no fast path intent detection.
    """
    key = api_key or _sarvam_api_key
    
    if not key:
        return json.dumps({
            "success": False,
            "error": "No API key configured.",
            "response": "I need an API key to respond. Please configure your Sarvam API key."
        })
    
    # === ReAct Loop for ALL Queries ===
    try:
        system_prompt = _build_react_system_prompt(user_context)
        
        # Initialize conversation for ReAct
        messages = [{"role": "user", "content": f"{system_prompt}\n\nUSER QUERY: {query}"}]
        
        # ReAct loop - max 3 iterations (reduced to prevent long waits)
        MAX_ITERATIONS = 3
        all_tool_results = []
        final_response = None
        last_action_data = None
        
        for iteration in range(MAX_ITERATIONS):
            print(f"[ReAct] Iteration {iteration + 1}/{MAX_ITERATIONS}")
            
            try:
                # Call LLM
                llm_response = _call_sarvam_llm(messages, key)
                
                if not llm_response:
                    print(f"[ReAct] No LLM response, breaking loop")
                    break
                    
                response_text = llm_response.get('content', '')
                
                if not response_text:
                    print(f"[ReAct] Empty response text, breaking loop")
                    break
                
                # Check for tool calls in response (only JSON format)
                tool_call = _parse_json_tool_call(response_text)
                
                if tool_call:
                    tool_name = tool_call.get('name', '')
                    tool_args = tool_call.get('arguments', {})
                    
                    # Validate tool call
                    if not tool_name or not isinstance(tool_args, dict):
                        print(f"[ReAct] Invalid tool call format, treating as final answer")
                        final_response = _clean_llm_response(response_text)
                        break
                    
                    # Validate query arg for search tools
                    if tool_name in ["web_search"] and "query" in tool_args:
                        query_arg = tool_args.get("query", "")
                        # Skip if LLM included its thinking in the query
                        if "THINK" in query_arg or "**" in query_arg or len(query_arg) > 200:
                            print(f"[ReAct] Invalid query in tool args, treating as final answer")
                            final_response = _clean_llm_response(response_text)
                            break
                    
                    print(f"[ReAct] Executing tool: {tool_name} with args: {tool_args}")
                    
                    # Execute the tool with error handling
                    try:
                        tool_result = execute_tool(tool_name, tool_args)
                        tool_data = json.loads(tool_result)
                    except Exception as tool_err:
                        print(f"[ReAct] Tool execution error: {tool_err}")
                        tool_data = {"success": False, "error": str(tool_err)}
                    
                    # Store result
                    all_tool_results.append({
                        'tool': tool_name,
                        'args': tool_args,
                        'result': tool_data
                    })
                    last_action_data = tool_data
                    
                    # Add tool execution to conversation (truncate to avoid token limits)
                    tool_result_str = json.dumps(tool_data, indent=2)[:1000]
                    messages.append({"role": "assistant", "content": response_text})
                    messages.append({
                        "role": "user", 
                        "content": f"TOOL RESULT:\n{tool_result_str}\n\nRespond naturally to the user with these results. Include specific details like prices, links, or recommendations. Be helpful and conversational - don't start with 'Final Answer' or similar."
                    })

                else:
                    # No tool call - this is the final answer
                    final_response = _clean_llm_response(response_text)
                    break
                    
            except Exception as iter_error:
                print(f"[ReAct] Iteration error: {iter_error}")
                # Try to recover gracefully
                if all_tool_results:
                    break
                else:
                    final_response = f"I encountered an error while processing. Please try again."
                    break
        
        # If we exhausted iterations without a final response, create one from results
        if not final_response and all_tool_results:
            # Use the last tool result to create a response
            last_result = all_tool_results[-1].get('result', {})
            if last_result.get('message'):
                final_response = last_result.get('message')
            elif last_result.get('results'):
                # Format search results
                results = last_result.get('results', [])[:5]
                final_response = f"Here's what I found:\n\n"
                for i, r in enumerate(results, 1):
                    title = r.get('title', 'Unknown')[:50]
                    snippet = r.get('snippet', '')[:100]
                    final_response += f"{i}. **{title}**\n   {snippet}\n\n"
            else:
                final_response = "I found some information but couldn't format it properly. Please try a more specific query."
        
        if not final_response:
            final_response = "I couldn't process your request. Please try again with a different query."
        
        # Determine if action was taken
        action_taken = len(all_tool_results) > 0
        action_type = all_tool_results[-1]['tool'] if all_tool_results else None
        
        return json.dumps({
            "success": True,
            "response": final_response,
            "action_taken": action_taken,
            "action_type": action_type,
            "action_data": last_action_data or {},
            "needs_confirmation": last_action_data.get('requires_confirmation', False) if last_action_data else False,
            "tools_used": [r['tool'] for r in all_tool_results]
        })
        
    except urllib.error.HTTPError as e:
        print(f"[ReAct] HTTP Error: {e.code}")
        return json.dumps({
            "success": False,
            "error": f"HTTP Error {e.code}",
            "response": "AI service temporarily unavailable. Please try again."
        })
    except Exception as e:
        print(f"[ReAct] General Error: {e}")
        return json.dumps({
            "success": False,
            "error": str(e),
            "response": f"Something went wrong. Please try again."
        })


def _parse_json_tool_call(response_text: str) -> Optional[Dict[str, Any]]:
    """Parse ONLY JSON-formatted tool calls. No pattern matching."""
    if not response_text:
        return None
        
    try:
        # Look for ```json blocks
        if '```json' in response_text:
            start = response_text.find('```json') + 7
            end = response_text.find('```', start)
            if end > start:
                json_str = response_text[start:end].strip()
                data = json.loads(json_str)
                if 'tool_call' in data:
                    return data['tool_call']
        
        # Look for raw JSON with tool_call
        if '{' in response_text and 'tool_call' in response_text:
            start = response_text.find('{')
            end = response_text.rfind('}') + 1
            if start >= 0 and end > start:
                json_str = response_text[start:end]
                data = json.loads(json_str)
                if 'tool_call' in data:
                    return data['tool_call']
    except json.JSONDecodeError:
        pass
    except Exception:
        pass
    
    return None




def _clean_llm_response(text: str) -> str:
    """Clean up LLM response to remove noise and make it concise."""
    if not text:
        return text
    
    # Remove markdown code blocks containing tool calls
    text = re.sub(r'```json\s*\{.*?\}\s*```', '', text, flags=re.DOTALL)
    text = re.sub(r'```\s*\{.*?\}\s*```', '', text, flags=re.DOTALL)
    
    # Remove "Final Answer:" and similar prefixes (case-insensitive)
    text = re.sub(r'^(?:Final Answer[:\s]*|Answer[:\s]*|Response[:\s]*)+', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\n(?:Final Answer[:\s]*|Answer[:\s]*)+', '\n', text, flags=re.IGNORECASE)
    
    # Remove "Here is the/my answer" patterns
    text = re.sub(r'^Here (?:is|are) (?:the|your|my) (?:response|answer|information)[:\.]?\s*', '', text, flags=re.IGNORECASE)
    
    # Remove thinking/reasoning prefixes
    text = re.sub(r'^(?:Based on (?:the|my) (?:search|analysis|research)[,\s]*)?', '', text, flags=re.IGNORECASE)
    
    # Remove excessive newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    # Remove leading/trailing whitespace
    text = text.strip()
    
    return text






# ==================== SARVAM VISION OCR ====================

def extract_receipt_from_path(file_path: str) -> str:
    """Extract receipt data from a local image file using Sarvam Vision API."""
    global _sarvam_api_key
    
    if not _sarvam_api_key:
        return json.dumps({"success": False, "error": "Sarvam API key not configured"})
    
    try:
        # Try using Sarvam SDK first
        if _HAS_SARVAM_SDK:
            try:
                client = SarvamAI(api_subscription_key=_sarvam_api_key)
                
                with open(file_path, 'rb') as f:
                    response = client.vision.analyze(
                        file=f,
                        prompt_type="default_ocr"
                    )
                
                ocr_text = response.content if hasattr(response, 'content') else str(response)
                print(f"[Sarvam Vision] OCR result: {ocr_text[:200]}...")
                
                # Parse the OCR text to extract receipt data
                return _parse_receipt_from_ocr(ocr_text, file_path)
                
            except Exception as sdk_e:
                print(f"[Sarvam Vision] SDK error: {sdk_e}, falling back to urllib")
        
        # Fallback: Use urllib with Sarvam Vision API
        with open(file_path, 'rb') as f:
            image_data = f.read()
        
        # Determine content type from file extension
        ext = file_path.lower().split('.')[-1]
        content_types = {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'webp': 'image/webp'
        }
        content_type = content_types.get(ext, 'image/jpeg')
        
        # Use Sarvam Vision API via multipart form
        boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW'
        
        body = []
        body.append(f'--{boundary}'.encode())
        body.append(b'Content-Disposition: form-data; name="prompt_type"')
        body.append(b'')
        body.append(b'default_ocr')
        body.append(f'--{boundary}'.encode())
        body.append(f'Content-Disposition: form-data; name="file"; filename="{os.path.basename(file_path)}"'.encode())
        body.append(f'Content-Type: {content_type}'.encode())
        body.append(b'')
        body.append(image_data)
        body.append(f'--{boundary}--'.encode())
        
        body_data = b'\r\n'.join(body)
        
        req = urllib.request.Request(
            "https://api.sarvam.ai/v1/vision/analyze",
            data=body_data,
            headers={
                'Content-Type': f'multipart/form-data; boundary={boundary}',
                'api-subscription-key': _sarvam_api_key
            },
            method='POST'
        )
        
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        with urllib.request.urlopen(req, timeout=30, context=context) as response:
            res = json.loads(response.read().decode('utf-8'))
            ocr_text = res.get('content', res.get('text', str(res)))
            
            print(f"[Sarvam Vision] OCR result: {ocr_text[:200]}...")
            return _parse_receipt_from_ocr(ocr_text, file_path)
            
    except urllib.error.HTTPError as e:
        error_body = ""
        try:
            error_body = e.read().decode('utf-8')
        except:
            pass
        return json.dumps({"success": False, "error": f"Sarvam Vision API error {e.code}: {error_body}"})
    except Exception as e:
        return json.dumps({"success": False, "error": f"Image analysis error: {str(e)}"})


def _parse_receipt_from_ocr(ocr_text: str, file_path: str) -> str:
    """Parse OCR text from receipt to extract structured transaction data."""
    try:
        # Try to extract JSON if the OCR text contains JSON
        json_match = re.search(r'\{[^{}]*\}', ocr_text, re.DOTALL)
        if json_match:
            try:
                data = json.loads(json_match.group())
                data["success"] = True
                return json.dumps(data)
            except json.JSONDecodeError:
                pass
        
        # Manual extraction using patterns
        result = {
            "success": True,
            "merchant_name": None,
            "date": None,
            "total_amount": None,
            "currency": "INR",
            "category": "Other",
            "raw_text": ocr_text
        }
        
        # Extract amount patterns (₹ or Rs. followed by numbers)
        amount_patterns = [
            r'(?:total|grand\s*total|amount|payable)[\s:]*[₹Rs.]*\s*([\d,]+\.?\d*)',
            r'[₹Rs.]\s*([\d,]+\.?\d*)',
            r'(?:INR|Rs\.?)\s*([\d,]+\.?\d*)',
        ]
        
        for pattern in amount_patterns:
            match = re.search(pattern, ocr_text, re.IGNORECASE)
            if match:
                amount_str = match.group(1).replace(',', '')
                try:
                    result["total_amount"] = float(amount_str)
                    break
                except ValueError:
                    continue
        
        # Extract date patterns
        date_patterns = [
            r'(\d{2}[/-]\d{2}[/-]\d{4})',  # DD/MM/YYYY or DD-MM-YYYY
            r'(\d{4}[/-]\d{2}[/-]\d{2})',  # YYYY-MM-DD
            r'(\d{1,2}\s+\w{3,9}\s+\d{4})',  # 12 Jan 2024
        ]
        
        for pattern in date_patterns:
            match = re.search(pattern, ocr_text, re.IGNORECASE)
            if match:
                result["date"] = match.group(1)
                break
        
        # Try to detect merchant/store name (usually at the top)
        lines = ocr_text.strip().split('\n')
        for line in lines[:5]:  # Check first 5 lines
            line = line.strip()
            if len(line) > 3 and line[0].isupper():
                # Skip lines that look like addresses or amounts
                if not re.search(r'^\d+|street|road|address|ph|tel|gstin|invoice', line.lower()):
                    result["merchant_name"] = line[:50]  # Limit length
                    break
        
        # Detect category from common keywords
        category_keywords = {
            'Food & Dining': ['restaurant', 'cafe', 'food', 'swiggy', 'zomato', 'pizza', 'burger', 'kitchen'],
            'Shopping': ['store', 'mart', 'shop', 'retail', 'amazon', 'flipkart'],
            'Transport': ['uber', 'ola', 'fuel', 'petrol', 'diesel', 'parking'],
            'Utilities': ['electricity', 'water', 'gas', 'mobile', 'recharge'],
            'Healthcare': ['pharmacy', 'medical', 'hospital', 'doctor', 'medicine'],
            'Entertainment': ['movie', 'cinema', 'pvr', 'inox', 'netflix'],
        }
        
        ocr_lower = ocr_text.lower()
        for category, keywords in category_keywords.items():
            if any(kw in ocr_lower for kw in keywords):
                result["category"] = category
                break
        
        return json.dumps(result)
        
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"Receipt parsing error: {str(e)}",
            "raw_text": ocr_text[:500] if ocr_text else ""
        })



def _call_sarvam_llm(messages: List[Dict[str, str]], api_key: str) -> Optional[Dict[str, Any]]:
    """Call Sarvam LLM and return message content."""
    try:
        # Try SDK first
        if _HAS_SARVAM_SDK:
            try:
                client = SarvamAI(api_subscription_key=api_key)
                res = client.chat.completions(
                    model="sarvam-m",
                    messages=messages
                )
                return {"content": res.choices[0].message.content}
            except Exception as sdk_e:
                print(f"[ReAct] SDK error: {sdk_e}, trying urllib")
        
        # urllib fallback
        api_url = "https://api.sarvam.ai/v1/chat/completions"
        request_body = {
            "model": "sarvam-m",
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 4096,
        }
        
        data = json.dumps(request_body).encode('utf-8')
        req = urllib.request.Request(
            api_url,
            data=data,
            headers={
                'Content-Type': 'application/json',
                'api-subscription-key': api_key,
                'Authorization': f'Bearer {api_key}'
            },
            method='POST'
        )
        
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        with urllib.request.urlopen(req, timeout=45, context=context) as response:
            resp_body = response.read().decode('utf-8')
            response_data = json.loads(resp_body)
        
        if 'choices' in response_data and len(response_data['choices']) > 0:
            return {"content": response_data['choices'][0]['message'].get('content', '')}
        
        return None
    except Exception as e:
        print(f"[ReAct] LLM call error: {e}")
        return None


def _build_react_system_prompt(user_context: Dict[str, Any] = None) -> str:
    """Build system prompt for ReAct (Reasoning + Acting) loop."""
    
    # Only include essential tools for ReAct
    essential_tools = [
        {"name": "web_search", "description": "Search the internet. Use for prices, reviews, news, etc. Add context like 'Amazon' or 'Flipkart' to your query for specific sites."},
        {"name": "calculate_sip", "description": "Calculate SIP returns (monthly_investment, annual_rate, years)"},
        {"name": "calculate_emi", "description": "Calculate loan EMI (principal, annual_rate, tenure_months)"},
        {"name": "create_budget", "description": "Create budget (category, amount, period)"},
        {"name": "create_savings_goal", "description": "Create savings goal (name, target_amount, deadline)"},
        {"name": "add_transaction", "description": "Add expense/income (amount, description, category, type)"},
    ]
    
    tool_list = "\n".join([f"- **{t['name']}**: {t['description']}" for t in essential_tools])
    
    # Extract financial advice from context if available
    financial_profile = ""
    if user_context and 'financial_profile' in str(user_context):
        financial_profile = str(user_context.get('financial_profile', ''))
    
    prompt = f"""You are WealthIn AI, a personalized financial advisor for Indian users.

## YOUR TOOLS
{tool_list}

## HOW TO CALL A TOOL
Output ONLY this JSON when you need to search or calculate:
```json
{{"tool_call": {{"name": "web_search", "arguments": {{"query": "your search query here"}}}}}}
```

## EXAMPLES
User: "Best phone under 20000"
Response: ```json
{{"tool_call": {{"name": "web_search", "arguments": {{"query": "best smartphone under 20000 India 2024"}}}}}}
```

User: "Calculate SIP of 5000 for 10 years"
Response: ```json
{{"tool_call": {{"name": "calculate_sip", "arguments": {{"monthly_investment": 5000, "annual_rate": 12, "years": 10}}}}}}
```

## PERSONALIZED ADVICE RULES
You have access to the user's COMPLETE FINANCIAL PROFILE. Use this to give personalized advice:

1. **Purchase Decisions**: When user asks about buying something:
   - Check their savings rate and disposable income
   - If savings rate < 10%: Strongly recommend EMI or delaying purchase
   - If savings rate 10-20%: Suggest EMI for purchases > ₹10,000
   - If savings rate 20-30%: Cash OK for < ₹20,000, EMI for larger
   - If savings rate > 30%: Cash purchase is fine for most items
   
2. **EMI Calculations**: Always calculate EMI when suggesting it:
   - Use calculate_emi tool with typical rates (12-18% for personal loans)
   - Show monthly EMI amount vs monthly savings capacity
   
3. **Budget Impact**: Explain how a purchase affects their budget:
   - Compare purchase price to their monthly savings
   - Suggest how many months it would take to save for it
   
4. **Goal Alignment**: Check if purchase aligns with their savings goals:
   - If they have active goals, mention the trade-off
   - Suggest adding the item as a new savings goal if appropriate

## CRITICAL RULES
1. The "query" parameter must be a SIMPLE search string
2. Keep queries short and specific
3. After tool results, provide PERSONALIZED advice based on user's financial situation
4. Always mention specific numbers (their income, savings, how purchase affects them)
5. Use ₹ for Indian Rupees

"""
    
    # Add user's financial context if available
    if user_context:
        prompt += "\n## USER'S FINANCIAL PROFILE\n"
        prompt += "Use this data to give personalized advice:\n\n"
        for key, value in user_context.items():
            if key == 'financial_profile' or 'context' in key.lower():
                prompt += f"{value}\n"
            else:
                prompt += f"- {key}: {value}\n"
        prompt += "\n"
    
    return prompt


def _build_system_prompt(user_context: Dict[str, Any] = None) -> str:
    """Build the system prompt for the fully agentic financial advisor."""
    
    # Get list of tools for injection into prompt
    tool_list = "\n".join([f"- **{t['name']}**: {t['description']}" for t in AVAILABLE_TOOLS])
    
    base_prompt = f"""You are WealthIn AI, a fully agentic financial advisor for Indian users.

## 🚀 AGENTIC MODE - AUTO TOOL EXECUTION
You MUST automatically use tools when they match the user's intent. DO NOT ask for confirmation to use tools - just use them!

## Available Tools
{tool_list}

## 🛒 SHOPPING DETECTION - CRITICAL
When user mentions buying, shopping, prices, or products, AUTOMATICALLY search:
- "buy phone" / "best phone under 20000" → Call `search_amazon` AND `search_flipkart`
- "clothes", "fashion", "dress" → Call `search_myntra`  
- "hotel in goa" / "booking" → Call `search_hotels`
- "atm near me" / "restaurant" → Call `search_maps`
- "gold rate" / "fd rates" / "news" → Call `web_search` or `search_news`

## 🧮 AUTO CALCULATIONS
- "SIP of 5000 for 10 years" → Call `calculate_sip` with monthly=5000, rate=12, years=10
- "EMI for 10 lakh loan" → Call `calculate_emi` with principal=1000000, rate=9, tenure=240
- "compound interest on 1 lakh" → Call `calculate_compound_interest`

## 💰 AUTO ACTIONS  
- "create budget of 5000 for food" → Call `create_budget`
- "I spent 500 on groceries" → Call `add_transaction`
- "save 10000 for vacation" → Call `create_savings_goal`

## 📤 TOOL CALL FORMAT
When you need to call a tool, output ONLY this JSON (no other text):
```json
{{"tool_call": {{"name": "tool_name", "arguments": {{"param1": "value1"}}}}}}
```

## 💬 RESPONSE STYLE (when not calling tools)
- Keep responses SHORT (2-3 sentences max)
- Use bullet points for lists
- Emojis are good but don't overuse
- Always use ₹ for Indian Rupees
- Be conversational, not robotic
- NO lengthy explanations unless asked

## User Context
"""

    if user_context:
        for key, value in user_context.items():
            if isinstance(value, dict):
                base_prompt += f"\n### {key.replace('_', ' ').title()}\n"
                for k, v in value.items():
                    base_prompt += f"- {k}: {v}\n"
            else:
                base_prompt += f"- {key}: {value}\n"
    
    return base_prompt



def _parse_tool_call_from_response(response_text: str) -> Optional[Dict[str, Any]]:
    """
    Parse if the LLM response contains a tool call request.
    Enhanced to detect both JSON tool calls and natural language patterns.
    """
    if not response_text:
        return None
        
    # 1. Check for JSON tool call format (preferred)
    try:
        # Look for ```json blocks
        if '```json' in response_text:
            start = response_text.find('```json') + 7
            end = response_text.find('```', start)
            if end > start:
                json_str = response_text[start:end].strip()
                data = json.loads(json_str)
                if 'tool_call' in data:
                    return data['tool_call']
        
        # Look for raw JSON with tool_call
        if '{' in response_text and 'tool_call' in response_text:
            # Find the JSON object
            start = response_text.find('{')
            end = response_text.rfind('}') + 1
            if start >= 0 and end > start:
                json_str = response_text[start:end]
                data = json.loads(json_str)
                if 'tool_call' in data:
                    return data['tool_call']
    except json.JSONDecodeError:
        pass
    except Exception:
        pass
    
    # 2. Pattern-based tool detection (fallback for natural language)
    lower_text = response_text.lower()
    
    # Shopping detection patterns
    shopping_keywords = ['buy', 'purchase', 'price of', 'best', 'cheap', 'under', 'budget']
    product_keywords = ['phone', 'laptop', 'mobile', 'tv', 'refrigerator', 'ac', 'washing machine', 
                       'headphones', 'earbuds', 'watch', 'tablet', 'camera']
    fashion_keywords = ['dress', 'shirt', 'jeans', 'shoes', 'kurta', 'saree', 'clothes', 'fashion']
    
    # Check for product shopping intent
    if any(kw in lower_text for kw in shopping_keywords):
        for product in product_keywords:
            if product in lower_text:
                # Extract a reasonable search query
                query = _extract_search_query(response_text, product)
                return {'name': 'search_amazon', 'arguments': {'query': query}}
        
        for fashion in fashion_keywords:
            if fashion in lower_text:
                query = _extract_search_query(response_text, fashion)
                return {'name': 'search_myntra', 'arguments': {'query': query}}
    
    # Hotel/travel detection
    if any(kw in lower_text for kw in ['hotel', 'stay', 'booking', 'accommodation']):
        # Extract location
        query = _extract_location_query(response_text)
        if query:
            return {'name': 'search_hotels', 'arguments': {'query': query}}
    
    # News detection
    if any(kw in lower_text for kw in ['news', 'latest', 'market', 'sensex', 'nifty']):
        return {'name': 'search_news', 'arguments': {'query': response_text[:50]}}
    
    return None


def _extract_search_query(text: str, keyword: str) -> str:
    """Extract a reasonable search query from text containing a keyword."""
    # Simple extraction: get words around the keyword
    words = text.split()
    result = []
    found = False
    for word in words:
        clean = word.lower().strip('.,!?')
        if keyword in clean:
            found = True
        if found and len(result) < 5:
            result.append(word.strip('.,!?'))
        elif not found and len(result) < 3:
            result.append(word.strip('.,!?'))
    
    return ' '.join(result[-5:]) if result else keyword


def _extract_location_query(text: str) -> Optional[str]:
    """Extract location for hotel search."""
    patterns = [
        r'hotel(?:s)?\s+(?:in|at|near)\s+(\w+(?:\s+\w+)?)',
        r'stay\s+(?:in|at)\s+(\w+(?:\s+\w+)?)',
        r'(\w+)\s+hotel'
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return f"hotels in {match.group(1)}"
    return None




# ==================== FINANCIAL CALCULATORS ====================


def calculate_sip_maturity(
    monthly_investment: float,
    annual_rate: float,
    years: int
) -> str:
    """Calculate SIP maturity value with step-up option."""
    try:
        monthly_rate = annual_rate / 100 / 12
        months = years * 12
        
        if monthly_rate == 0:
            maturity_value = monthly_investment * months
        else:
            maturity_value = monthly_investment * (
                ((1 + monthly_rate) ** months - 1) / monthly_rate
            ) * (1 + monthly_rate)
        
        total_investment = monthly_investment * months
        returns = maturity_value - total_investment
        absolute_return = (returns / total_investment) * 100 if total_investment > 0 else 0
        
        # Calculate year-wise breakdown
        yearly_breakdown = []
        for y in range(1, years + 1):
            m = y * 12
            if monthly_rate == 0:
                val = monthly_investment * m
            else:
                val = monthly_investment * (
                    ((1 + monthly_rate) ** m - 1) / monthly_rate
                ) * (1 + monthly_rate)
            yearly_breakdown.append({
                "year": y,
                "value": round(val, 2),
                "invested": monthly_investment * m
            })
        
        return json.dumps({
            "success": True,
            "maturity_value": round(maturity_value, 2),
            "total_investment": round(total_investment, 2),
            "total_returns": round(returns, 2),
            "absolute_return_percent": round(absolute_return, 2),
            "monthly_investment": monthly_investment,
            "annual_rate": annual_rate,
            "years": years,
            "yearly_breakdown": yearly_breakdown
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def calculate_emi(
    principal: float,
    annual_rate: float,
    tenure_months: int
) -> str:
    """Calculate EMI for loans with amortization schedule."""
    try:
        monthly_rate = annual_rate / 100 / 12
        
        if monthly_rate == 0:
            emi = principal / tenure_months
        else:
            emi = principal * monthly_rate * (
                (1 + monthly_rate) ** tenure_months
            ) / (((1 + monthly_rate) ** tenure_months) - 1)
        
        total_payment = emi * tenure_months
        total_interest = total_payment - principal
        
        # Generate amortization schedule (first 12 months)
        amortization = []
        balance = principal
        for month in range(1, min(13, tenure_months + 1)):
            interest_payment = balance * monthly_rate
            principal_payment = emi - interest_payment
            balance -= principal_payment
            amortization.append({
                "month": month,
                "emi": round(emi, 2),
                "principal": round(principal_payment, 2),
                "interest": round(interest_payment, 2),
                "balance": round(max(0, balance), 2)
            })
        
        return json.dumps({
            "success": True,
            "emi": round(emi, 2),
            "total_payment": round(total_payment, 2),
            "total_interest": round(total_interest, 2),
            "principal": round(principal, 2),
            "annual_rate": annual_rate,
            "tenure_months": tenure_months,
            "interest_percentage": round((total_interest / principal) * 100, 2),
            "amortization_schedule": amortization
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def calculate_compound_interest(
    principal: float,
    annual_rate: float,
    years: float,
    compounds_per_year: int = 12
) -> str:
    """Calculate compound interest with detailed breakdown."""
    try:
        rate = annual_rate / 100
        n = compounds_per_year
        t = years
        
        future_value = principal * ((1 + rate/n) ** (n*t))
        total_interest = future_value - principal
        
        # Year-wise growth
        yearly_values = []
        for y in range(1, int(years) + 1):
            val = principal * ((1 + rate/n) ** (n*y))
            yearly_values.append({
                "year": y,
                "value": round(val, 2),
                "interest_earned": round(val - principal, 2)
            })
        
        return json.dumps({
            "success": True,
            "future_value": round(future_value, 2),
            "principal": round(principal, 2),
            "total_interest": round(total_interest, 2),
            "annual_rate": annual_rate,
            "years": years,
            "compounds_per_year": n,
            "effective_annual_rate": round(((1 + rate/n)**n - 1) * 100, 2),
            "yearly_values": yearly_values
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def calculate_fire_number(
    annual_expenses: float,
    withdrawal_rate: float = 4.0
) -> str:
    """Calculate FIRE number and related metrics."""
    try:
        if withdrawal_rate <= 0:
            withdrawal_rate = 4.0
        
        fire_number = (annual_expenses / withdrawal_rate) * 100
        monthly_expenses = annual_expenses / 12
        
        # Calculate how long different portfolios would last
        portfolio_scenarios = []
        for multiplier in [15, 20, 25, 30, 35]:
            portfolio = monthly_expenses * multiplier * 12
            years_lasts = portfolio / annual_expenses  # Simplified
            portfolio_scenarios.append({
                "portfolio": round(portfolio, 2),
                "multiplier": multiplier,
                "years_coverage": round(years_lasts, 1)
            })
        
        return json.dumps({
            "success": True,
            "fire_number": round(fire_number, 2),
            "annual_expenses": round(annual_expenses, 2),
            "monthly_expenses": round(monthly_expenses, 2),
            "withdrawal_rate": withdrawal_rate,
            "monthly_passive_income_needed": round(annual_expenses / 12, 2),
            "portfolio_scenarios": portfolio_scenarios,
            "advice": f"You need ₹{round(fire_number/100000, 2)} lakhs to achieve FIRE with {withdrawal_rate}% withdrawal rate."
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def calculate_emergency_fund(
    monthly_expenses: float,
    current_savings: float,
    target_months: int = 6
) -> str:
    """Analyze emergency fund adequacy."""
    try:
        if monthly_expenses <= 0:
            months_covered = -1
            gap = 0
            is_adequate = True
        else:
            months_covered = current_savings / monthly_expenses
            target_amount = monthly_expenses * target_months
            gap = max(0, target_amount - current_savings)
            is_adequate = months_covered >= target_months
        
        # Savings plan to reach goal
        savings_plans = []
        for monthly_savings in [5000, 10000, 15000, 20000]:
            if gap > 0:
                months_to_goal = math.ceil(gap / monthly_savings)
                savings_plans.append({
                    "monthly_savings": monthly_savings,
                    "months_to_goal": months_to_goal,
                    "completion_date": (datetime.now() + timedelta(days=months_to_goal * 30)).strftime("%B %Y")
                })
        
        return json.dumps({
            "success": True,
            "months_covered": round(months_covered, 1) if months_covered != -1 else -1,
            "target_months": target_months,
            "target_amount": round(monthly_expenses * target_months, 2),
            "current_savings": round(current_savings, 2),
            "gap": round(gap, 2),
            "is_adequate": is_adequate,
            "status": "Adequate" if is_adequate else "Below Target",
            "savings_plans": savings_plans if not is_adequate else [],
            "advice": f"{'Great! Your emergency fund covers {:.1f} months.' if is_adequate else 'You need ₹{:,.0f} more to reach {} months coverage.'}"
                .format(months_covered if is_adequate else gap, target_months)
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def calculate_savings_rate(income: float, expenses: float) -> str:
    """Calculate savings rate and health indicators."""
    try:
        if income <= 0:
            rate = 0.0
            savings = 0.0
        else:
            savings = income - expenses
            rate = (savings / income) * 100
        
        # Determine health status
        if rate >= 30:
            status = "Excellent"
            emoji = "🌟"
            advice = "Outstanding! You're on track for early retirement."
        elif rate >= 20:
            status = "Good"
            emoji = "✅"
            advice = "Great savings rate! Consider increasing investments."
        elif rate >= 10:
            status = "Fair"
            emoji = "⚠️"
            advice = "Room for improvement. Try to cut discretionary spending."
        else:
            status = "Needs Attention"
            emoji = "🚨"
            advice = "Your savings rate is low. Review your expenses urgently."
        
        return json.dumps({
            "success": True,
            "savings_rate": round(rate, 2),
            "monthly_savings": round(savings, 2),
            "annual_savings": round(savings * 12, 2),
            "income": round(income, 2),
            "expenses": round(expenses, 2),
            "status": status,
            "emoji": emoji,
            "advice": advice,
            "benchmark": "Aim for 20-30% savings rate"
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


# ==================== TRANSACTION CATEGORIZATION ====================

# Enhanced merchant database for better recognition
KNOWN_MERCHANTS = {
    # Food & Dining
    'swiggy': {'category': 'Food & Dining', 'display_name': 'Swiggy'},
    'zomato': {'category': 'Food & Dining', 'display_name': 'Zomato'},
    'dominos': {'category': 'Food & Dining', 'display_name': "Domino's Pizza"},
    'mcdonalds': {'category': 'Food & Dining', 'display_name': "McDonald's"},
    'mcd': {'category': 'Food & Dining', 'display_name': "McDonald's"},
    'kfc': {'category': 'Food & Dining', 'display_name': 'KFC'},
    'pizzahut': {'category': 'Food & Dining', 'display_name': 'Pizza Hut'},
    'burger king': {'category': 'Food & Dining', 'display_name': 'Burger King'},
    'starbucks': {'category': 'Food & Dining', 'display_name': 'Starbucks'},
    'cafe coffee day': {'category': 'Food & Dining', 'display_name': 'Cafe Coffee Day'},
    'ccd': {'category': 'Food & Dining', 'display_name': 'Cafe Coffee Day'},
    'subway': {'category': 'Food & Dining', 'display_name': 'Subway'},
    'haldiram': {'category': 'Food & Dining', 'display_name': 'Haldiram'},
    'bikanervala': {'category': 'Food & Dining', 'display_name': 'Bikanervala'},
    'chaayos': {'category': 'Food & Dining', 'display_name': 'Chaayos'},
    'wow momo': {'category': 'Food & Dining', 'display_name': 'Wow Momo'},
    'faasos': {'category': 'Food & Dining', 'display_name': 'Faasos'},
    'box8': {'category': 'Food & Dining', 'display_name': 'Box8'},
    'behrouz': {'category': 'Food & Dining', 'display_name': 'Behrouz Biryani'},
    'eatclub': {'category': 'Food & Dining', 'display_name': 'EatClub'},
    
    # Groceries
    'dmart': {'category': 'Groceries', 'display_name': 'DMart'},
    'bigbasket': {'category': 'Groceries', 'display_name': 'BigBasket'},
    'blinkit': {'category': 'Groceries', 'display_name': 'Blinkit'},
    'zepto': {'category': 'Groceries', 'display_name': 'Zepto'},
    'instamart': {'category': 'Groceries', 'display_name': 'Swiggy Instamart'},
    'jiomart': {'category': 'Groceries', 'display_name': 'JioMart'},
    'reliance fresh': {'category': 'Groceries', 'display_name': 'Reliance Fresh'},
    'more megastore': {'category': 'Groceries', 'display_name': 'More Megastore'},
    'spencers': {'category': 'Groceries', 'display_name': "Spencer's"},
    'nature basket': {'category': 'Groceries', 'display_name': "Nature's Basket"},
    'dunzo': {'category': 'Groceries', 'display_name': 'Dunzo'},
    
    # Transport
    'uber': {'category': 'Transport', 'display_name': 'Uber'},
    'ola': {'category': 'Transport', 'display_name': 'Ola'},
    'rapido': {'category': 'Transport', 'display_name': 'Rapido'},
    'irctc': {'category': 'Transport', 'display_name': 'IRCTC'},
    'redbus': {'category': 'Transport', 'display_name': 'RedBus'},
    'makemytrip': {'category': 'Transport', 'display_name': 'MakeMyTrip'},
    'goibibo': {'category': 'Transport', 'display_name': 'Goibibo'},
    'yatra': {'category': 'Transport', 'display_name': 'Yatra'},
    'ixigo': {'category': 'Transport', 'display_name': 'ixigo'},
    'uber india': {'category': 'Transport', 'display_name': 'Uber India'},
    'indian oil': {'category': 'Transport', 'display_name': 'Indian Oil'},
    'hindustan petroleum': {'category': 'Transport', 'display_name': 'HPCL'},
    'bharat petroleum': {'category': 'Transport', 'display_name': 'BPCL'},
    'fastag': {'category': 'Transport', 'display_name': 'FASTag Toll'},
    
    # Shopping
    'amazon': {'category': 'Shopping', 'display_name': 'Amazon'},
    'flipkart': {'category': 'Shopping', 'display_name': 'Flipkart'},
    'myntra': {'category': 'Shopping', 'display_name': 'Myntra'},
    'ajio': {'category': 'Shopping', 'display_name': 'AJIO'},
    'nykaa': {'category': 'Shopping', 'display_name': 'Nykaa'},
    'meesho': {'category': 'Shopping', 'display_name': 'Meesho'},
    'tatacliq': {'category': 'Shopping', 'display_name': 'TataCliq'},
    'croma': {'category': 'Shopping', 'display_name': 'Croma'},
    'reliance digital': {'category': 'Shopping', 'display_name': 'Reliance Digital'},
    'vijay sales': {'category': 'Shopping', 'display_name': 'Vijay Sales'},
    'shoppers stop': {'category': 'Shopping', 'display_name': 'Shoppers Stop'},
    'lifestyle': {'category': 'Shopping', 'display_name': 'Lifestyle'},
    'westside': {'category': 'Shopping', 'display_name': 'Westside'},
    'h&m': {'category': 'Shopping', 'display_name': 'H&M'},
    'zara': {'category': 'Shopping', 'display_name': 'Zara'},
    'decathlon': {'category': 'Shopping', 'display_name': 'Decathlon'},
    
    # Utilities
    'airtel': {'category': 'Utilities', 'display_name': 'Airtel'},
    'jio': {'category': 'Utilities', 'display_name': 'Jio'},
    'vi india': {'category': 'Utilities', 'display_name': 'Vi (Vodafone Idea)'},
    'vodafone': {'category': 'Utilities', 'display_name': 'Vodafone'},
    'bsnl': {'category': 'Utilities', 'display_name': 'BSNL'},
    'tata power': {'category': 'Utilities', 'display_name': 'Tata Power'},
    'adani electricity': {'category': 'Utilities', 'display_name': 'Adani Electricity'},
    'bescom': {'category': 'Utilities', 'display_name': 'BESCOM'},
    'mahanagar gas': {'category': 'Utilities', 'display_name': 'Mahanagar Gas'},
    'indane': {'category': 'Utilities', 'display_name': 'Indane Gas'},
    'tata sky': {'category': 'Utilities', 'display_name': 'Tata Sky'},
    'd2h': {'category': 'Utilities', 'display_name': 'D2H'},
    'dish tv': {'category': 'Utilities', 'display_name': 'Dish TV'},
    
    # Entertainment
    'netflix': {'category': 'Entertainment', 'display_name': 'Netflix'},
    'spotify': {'category': 'Entertainment', 'display_name': 'Spotify'},
    'amazon prime': {'category': 'Entertainment', 'display_name': 'Amazon Prime'},
    'hotstar': {'category': 'Entertainment', 'display_name': 'Disney+ Hotstar'},
    'jiocinema': {'category': 'Entertainment', 'display_name': 'JioCinema'},
    'zee5': {'category': 'Entertainment', 'display_name': 'ZEE5'},
    'sonyliv': {'category': 'Entertainment', 'display_name': 'SonyLIV'},
    'youtube premium': {'category': 'Entertainment', 'display_name': 'YouTube Premium'},
    'bookmyshow': {'category': 'Entertainment', 'display_name': 'BookMyShow'},
    'pvr': {'category': 'Entertainment', 'display_name': 'PVR Cinemas'},
    'inox': {'category': 'Entertainment', 'display_name': 'INOX'},
    
    # Healthcare
    'apollo': {'category': 'Healthcare', 'display_name': 'Apollo'},
    'pharmeasy': {'category': 'Healthcare', 'display_name': 'PharmEasy'},
    'netmeds': {'category': 'Healthcare', 'display_name': 'Netmeds'},
    '1mg': {'category': 'Healthcare', 'display_name': '1mg'},
    'tata 1mg': {'category': 'Healthcare', 'display_name': 'Tata 1mg'},
    'practo': {'category': 'Healthcare', 'display_name': 'Practo'},
    'medibuddy': {'category': 'Healthcare', 'display_name': 'MediBuddy'},
    'max hospital': {'category': 'Healthcare', 'display_name': 'Max Hospital'},
    'fortis': {'category': 'Healthcare', 'display_name': 'Fortis Hospital'},
    
    # Investment
    'zerodha': {'category': 'Investment', 'display_name': 'Zerodha'},
    'groww': {'category': 'Investment', 'display_name': 'Groww'},
    'upstox': {'category': 'Investment', 'display_name': 'Upstox'},
    'angelone': {'category': 'Investment', 'display_name': 'Angel One'},
    'kuvera': {'category': 'Investment', 'display_name': 'Kuvera'},
    'coin zerodha': {'category': 'Investment', 'display_name': 'Zerodha Coin'},
    'smallcase': {'category': 'Investment', 'display_name': 'Smallcase'},
    'etmoney': {'category': 'Investment', 'display_name': 'ET Money'},
    'paytm money': {'category': 'Investment', 'display_name': 'Paytm Money'},
    
    # Insurance
    'lic': {'category': 'Insurance', 'display_name': 'LIC'},
    'hdfc life': {'category': 'Insurance', 'display_name': 'HDFC Life'},
    'icici pru': {'category': 'Insurance', 'display_name': 'ICICI Prudential'},
    'sbi life': {'category': 'Insurance', 'display_name': 'SBI Life'},
    'max life': {'category': 'Insurance', 'display_name': 'Max Life'},
    'star health': {'category': 'Insurance', 'display_name': 'Star Health'},
    'digit': {'category': 'Insurance', 'display_name': 'Digit Insurance'},
    'acko': {'category': 'Insurance', 'display_name': 'Acko'},
    
    # Education
    'udemy': {'category': 'Education', 'display_name': 'Udemy'},
    'coursera': {'category': 'Education', 'display_name': 'Coursera'},
    'unacademy': {'category': 'Education', 'display_name': 'Unacademy'},
    'byjus': {'category': 'Education', 'display_name': "BYJU'S"},
    'upgrad': {'category': 'Education', 'display_name': 'upGrad'},
    'simplilearn': {'category': 'Education', 'display_name': 'Simplilearn'},
    'vedantu': {'category': 'Education', 'display_name': 'Vedantu'},
    
    # Fitness
    'cult.fit': {'category': 'Subscriptions', 'display_name': 'cult.fit'},
    'gold gym': {'category': 'Subscriptions', 'display_name': 'Gold Gym'},
    'fitness first': {'category': 'Subscriptions', 'display_name': 'Fitness First'},
}

# ==================== ENHANCED CATEGORY KEYWORDS ====================
# Massively expanded for Indian context with 200+ keywords per category
CATEGORY_KEYWORDS = {
    'Food & Dining': [
        # Food Delivery Apps
        'swiggy', 'zomato', 'uber eats', 'foodpanda', 'dunzo', 'box8', 'fasoos', 'faasos',
        'behrouz biryani', 'ovenstory', 'licious', 'freshmenu', 'eatfit', 'rebel foods',
        # Restaurants & Cafes
        'restaurant', 'cafe', 'dhaba', 'hotel', 'biryani', 'pizza', 'burger', 'dine', 'dining',
        'mcdonalds', 'mcd', 'kfc', 'dominos', 'pizza hut', 'subway', 'starbucks', 'ccd',
        'barista', 'haldirams', 'bikanervala', 'saravana bhavan', 'litti chokha', 'pind balluchi',
        'paradise biryani', 'behrouz', 'chai point', 'chaayos', 'social', 'hard rock cafe',
        'burger king', 'wendy', 'taco bell', 'dunkin', 'krispy kreme', 'baskin robbins', 'keventers',
        # Generic food terms
        'food', 'meal', 'lunch', 'dinner', 'breakfast', 'snack', 'brunch', 'canteen', 'mess',
        'bakery', 'sweet shop', 'mithai', 'ice cream', 'gelato', 'juice', 'smoothie', 'tea', 'coffee',
        'tiffin', 'thali', 'buffet', 'takeaway', 'delivery', 'eat', 'dosa', 'idli', 'paratha',
        'pav bhaji', 'vada pav', 'samosa', 'chaat', 'momos', 'noodles', 'chinese', 'italian',
        'thai', 'japanese', 'sushi', 'tandoori', 'mughlai', 'punjabi', 'south indian', 'north indian',
        'food court', 'eatery', 'bistro', 'kitchen'
    ],
    'Groceries': [
        # Online Grocery
        'bigbasket', 'grofers', 'blinkit', 'zepto', 'instamart', 'jiomart', 'amazon fresh',
        'swiggy instamart', 'dunzo daily', 'milkbasket', 'supr daily', 'licious', 'freshtohome',
        'country delight', 'doodhwala',
        # Retail Chains
        'dmart', 'd mart', 'reliance fresh', 'reliance smart', 'more', 'star bazaar', 'spencer',
        'heritage', 'ratnadeep', 'vishal mega mart', 'easy day', 'big bazaar', 'spar', 'hypercity',
        'nature basket', 'foodhall', 'godrej nature basket',
        # Generic terms
        'grocery', 'groceries', 'supermarket', 'hypermarket', 'kirana', 'provision', 'ration',
        'vegetables', 'fruits', 'sabzi', 'mandi', 'dairy', 'milk', 'curd', 'paneer', 'eggs',
        'bread', 'atta', 'rice', 'dal', 'oil', 'masala', 'spices', 'staples', 'essentials',
        'household', 'detergent', 'cleaning', 'toiletries', 'personal care'
    ],
    'Transport': [
        # Ride Sharing
        'uber', 'ola', 'rapido', 'meru', 'mega cabs', 'indrive', 'blu smart', 'jugnoo',
        # Fuel
        'petrol', 'diesel', 'fuel', 'indian oil', 'bharat petroleum', 'hp petrol', 'ioc', 'bpcl', 'hpcl',
        'cng', 'ev charging', 'ather', 'tata power charging', 'reliance bp',
        # Public Transport
        'irctc', 'indian railways', 'metro', 'delhi metro', 'mumbai metro', 'bangalore metro',
        'hyderabad metro', 'chennai metro', 'kolkata metro', 'uber metro', 'bus', 'redbus',
        'abhibus', 'paytm bus', 'apsrtc', 'ksrtc', 'msrtc', 'upsrtc', 'tsrtc', 'gsrtc',
        # Bikes & Autos
        'auto', 'rickshaw', 'bike taxi', 'bounce', 'vogo', 'yulu',
        # Toll & Parking
        'fastag', 'toll', 'parking', 'nhai', 'paytm fastag', 'airtel fastag',
        # Air & Rail
        'flight', 'airline', 'indigo', 'spicejet', 'air india', 'vistara', 'goair', 'akasa',
        'makemytrip', 'cleartrip', 'ixigo', 'goibibo', 'easemytrip', 'yatra', 'via',
        'cab', 'taxi', 'travel', 'trip', 'commute', 'ride'
    ],
    'Shopping': [
        # E-commerce
        'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'snapdeal', 'shopclues',
        'tatacliq', 'reliance digital', 'croma', 'vijay sales', 'poorvika', 'sangeetha',
        # Fashion
        'zara', 'h&m', 'uniqlo', 'westside', 'shoppers stop', 'lifestyle', 'pantaloons',
        'max fashion', 'fbb', 'central', 'reliance trends', 'v mart', 'brand factory',
        # Electronics
        'apple store', 'samsung store', 'mi home', 'oneplus', 'realme', 'oppo store', 'vivo',
        # Jewelry & Accessories
        'tanishq', 'kalyan jewellers', 'malabar gold', 'joyalukkas', 'pc jeweller', 'titan',
        'caratlane', 'bluestone', 'melorra',
        # Generic
        'shop', 'shopping', 'mall', 'retail', 'purchase', 'buy', 'store', 'outlet', 'clothes',
        'electronics', 'fashion', 'apparel', 'footwear', 'shoes', 'watch', 'jewel', 'jewelry',
        'accessory', 'accessories', 'bag', 'bags', 'cosmetic', 'makeup', 'beauty', 'grooming',
        'decathlon', 'sports', 'furniture', 'ikea', 'pepperfry', 'urban ladder', 'home centre'
    ],
    'Utilities': [
        # Telecom
        'airtel', 'jio', 'bsnl', 'vi', 'vodafone', 'idea', 'mtnl',
        # DTH
        'tata sky', 'dish tv', 'airtel dth', 'sun direct', 'videocon', 'd2h',
        # Electricity
        'electricity', 'electric bill', 'bescom', 'msedcl', 'tata power', 'adani power',
        'bses', 'reliance energy', 'torrent power',
        # Gas
        'indane', 'hp gas', 'bharat gas', 'mahanagar gas', 'adani gas', 'igl', 'gail',
        'piped gas', 'cylinder', 'lpg',
        # Water
        'water', 'water bill', 'jal board', 'municipal',
        # Internet
        'broadband', 'wifi', 'internet', 'fiber', 'act fibernet', 'hathway', 'tikona',
        'excitel', 'spectra', 'airtel xstream', 'jio fiber',
        # Generic
        'utility', 'bill', 'recharge', 'prepaid', 'postpaid', 'landline', 'connection',
        'renewal', 'plan', 'pack'
    ],
    'Entertainment': [
        # OTT Platforms
        'netflix', 'amazon prime', 'prime video', 'hotstar', 'disney plus', 'disney+',
        'zee5', 'sonyliv', 'voot', 'altbalaji', 'mx player', 'jiocinema', 'aha', 'hoichoi',
        'discovery plus', 'lionsgate', 'erosnow', 'shemaroo', 'hungama', 'mubi',
        # Music
        'spotify', 'apple music', 'gaana', 'jio saavn', 'amazon music', 'wynk', 'youtube music',
        # Gaming
        'steam', 'playstation', 'xbox', 'nintendo', 'epic games', 'google play games',
        'pubg', 'free fire', 'cod', 'valorant', 'dream11', 'mpl', 'winzo', 'paytm first games',
        # Theatre & Events
        'bookmyshow', 'paytm movies', 'inox', 'pvr', 'cinepolis', 'carnival', 'movie ticket',
        'concert', 'event', 'show', 'theatre', 'cinema',
        # Generic
        'entertainment', 'movie', 'film', 'game', 'gaming', 'stream', 'streaming', 'ott',
        'subscription', 'premium', 'music', 'video'
    ],
    'Healthcare': [
        # Hospital Chains
        'apollo', 'fortis', 'max healthcare', 'manipal hospital', 'narayana health',
        'medanta', 'aiims', 'aster', 'columbia asia', 'sakra', 'cloudnine',
        # Pharmacy
        'apollo pharmacy', 'medplus', 'netmeds', 'pharmeasy', '1mg', 'truemeds',
        'wellness forever', 'frank ross', 'guardian pharmacy',
        # Diagnostic
        'dr lal path', 'srl diagnostics', 'metropolis', 'thyrocare', 'redcliffe',
        'healthians', 'orange health',
        # Insurance & Wellness
        'practo', 'docprime', 'mfine', 'cult.fit', 'healthify', 'stepsetgo',
        # Generic
        'hospital', 'clinic', 'doctor', 'medical', 'healthcare', 'health', 'medicine',
        'pharmacy', 'chemist', 'diagnostic', 'lab', 'pathology', 'xray', 'scan', 'mri', 'ct scan',
        'dental', 'dentist', 'eye', 'optical', 'therapy', 'physiotherapy', 'consultation',
        'specialist', 'treatment', 'surgery', 'checkup', 'test', 'report', 'prescription'
    ],
    'Income': [
        'salary', 'income', 'wages', 'pay', 'compensation', 'payment received',
        'credit', 'credited', 'deposit', 'received', 'inward',
        'interest credited', 'interest earned', 'dividend', 'bonus', 'incentive',
        'refund', 'cashback', 'reward', 'rewards', 'commission',
        'freelance', 'consulting', 'contract payment', 'invoice payment',
        'rent received', 'rental income', 'royalty', 'settlement',
        'reimbursement', 'expense claim', 'maturity', 'redemption',
        'from upi', 'received from', 'credit by', 'cr'
    ],
    'Transfer': [
        'transfer', 'upi', 'neft', 'imps', 'rtgs', 'fund transfer',
        'paytm', 'phonepe', 'gpay', 'google pay', 'bhim', 'bhim upi',
        'self transfer', 'to self', 'own account', 'internal', 'self',
        'between accounts', 'savings to', 'to savings', 'current to',
        'wallet', 'load wallet', 'add money', 'bank transfer'
    ],
    'Investment': [
        # Platforms
        'zerodha', 'groww', 'upstox', 'angel one', 'angel broking', 'icicidirect',
        'hdfc securities', 'kotak securities', 'sharekhan', '5paisa', 'paytm money',
        'kuvera', 'etmoney', 'coin', 'vested', 'indiabulls',
        # Instruments
        'mutual fund', 'mf', 'sip', 'lumpsum', 'stock', 'share', 'equity', 'nifty', 'sensex',
        'ipo', 'nfo', 'etf', 'bond', 'debenture', 'ncd', 'sgb', 'sovereign gold',
        'fd', 'fixed deposit', 'rd', 'recurring deposit', 'ppf', 'nps', 'epf', 'vpf',
        'nsc', 'kvp', 'post office', 'gold', 'silver', 'digital gold',
        # Generic
        'investment', 'invest', 'trading', 'portfolio', 'demat', 'folio', 'nav', 'units',
        'dividend', 'capital gain', 'exit load', 'redemption'
    ],
    'Insurance': [
        # Companies
        'lic', 'hdfc life', 'icici prudential', 'sbi life', 'max life', 'bajaj allianz',
        'tata aia', 'kotak life', 'birla sunlife', 'aegon life', 'pnb metlife',
        'star health', 'care health', 'niva bupa', 'aditya birla health', 'manipal cigna',
        'acko', 'digit', 'go digit', 'policy bazaar',
        # Generic
        'insurance', 'policy', 'premium', 'term plan', 'term life', 'endowment', 'ulip',
        'health insurance', 'mediclaim', 'life insurance', 'motor insurance', 'car insurance',
        'two wheeler insurance', 'travel insurance', 'home insurance', 'cover', 'claim',
        'renewal', 'nominee', 'sum assured'
    ],
    'Education': [
        # Online Learning
        'udemy', 'coursera', 'edx', 'linkedin learning', 'skillshare', 'pluralsight',
        'upgrad', 'simplilearn', 'great learning', 'byju', 'unacademy', 'vedantu',
        'toppr', 'meritnation', 'embibe', 'doubtnut', 'khan academy', 'whitehat jr', 'cuemath',
        # Institutions
        'school', 'college', 'university', 'institute', 'iit', 'iim', 'nit', 'bits', 'vit',
        'amity', 'manipal', 'srm', 'christ',
        # Generic
        'education', 'tuition', 'coaching', 'training', 'course', 'certification', 'diploma',
        'degree', 'books', 'stationery', 'fees', 'admission', 'exam', 'examination',
        'tutorial', 'learning', 'workshop', 'seminar', 'webinar', 'masterclass'
    ],
    'Rent': [
        'rent', 'rental', 'house rent', 'flat rent', 'office rent', 'room rent',
        'housing', 'landlord', 'tenant', 'lease', 'pg', 'paying guest', 'hostel',
        'maintenance', 'society maintenance', 'association', 'apartment', 'flat',
        'accommodation', 'stay', 'deposit', 'security deposit', 'brokerage',
        'nobroker', 'magicbricks', 'housing.com', '99acres', 'nestaway'
    ],
    'Subscriptions': [
        'subscription', 'membership', 'annual', 'monthly', 'yearly', 'renewal',
        'premium', 'pro', 'plus', 'gold', 'silver', 'platinum', 'vip',
        # Gym & Fitness
        'gym', 'fitness', 'cult fit', 'cult.fit', 'gold gym', 'anytime fitness',
        'fitness first', 'talwalkars', 'golds gym', 'snap fitness',
        # Cloud & Software
        'icloud', 'google one', 'dropbox', 'microsoft 365', 'office 365', 'adobe',
        'notion', 'canva', 'grammarly', 'zoom',
        # General
        'club', 'association', 'fee', 'dues', 'auto renewal', 'recurring'
    ],
    'Travel': [
        # OTAs
        'makemytrip', 'goibibo', 'cleartrip', 'yatra', 'ixigo', 'easemytrip', 'via',
        # Hotels
        'oyo', 'treebo', 'fabhotels', 'zostel', 'goibibo hotels', 'booking.com', 'agoda',
        'airbnb', 'marriott', 'taj', 'oberoi', 'itc hotels', 'radisson', 'hyatt', 'hilton',
        'lemon tree', 'ginger', 'ibis', 'novotel',
        # Generic
        'hotel', 'resort', 'homestay', 'vacation', 'holiday', 'trip', 'tour', 'travel',
        'booking', 'reservation', 'check-in', 'checkout', 'room', 'stay', 'accommodation',
        'passport', 'visa', 'currency exchange', 'forex', 'travel insurance'
    ],
    'Loan & EMI': [
        'emi', 'loan', 'personal loan', 'home loan', 'car loan', 'bike loan', 'gold loan',
        'education loan', 'business loan', 'credit card emi', 'no cost emi', 'bajaj finserv',
        'hdfc credila', 'sbi loan', 'icici loan', 'axis loan', 'kotak loan', 'tata capital',
        'fullerton', 'indiabulls', 'muthoot', 'manappuram', 'iifl', 'credit', 'lending',
        'borrowing', 'interest', 'principal', 'tenure', 'instalment', 'repayment'
    ]
}


def extract_merchant_name(description: str) -> tuple:
    """
    Extract merchant name from transaction description.
    Returns (merchant_name, category, confidence)
    Improved with timestamp filtering and junk character removal.
    """
    if not description:
        return (None, None, 0.0)
    
    desc_lower = description.lower().strip()
    
    # First, clean the description - remove timestamps and junk
    clean_desc = description
    # Remove common timestamp patterns
    clean_desc = re.sub(r'\d{1,2}[:/]\d{2}([:/]\d{2})?\s*(am|pm|AM|PM)?', '', clean_desc)
    clean_desc = re.sub(r'\d{4}[-/]\d{2}[-/]\d{2}', '', clean_desc)
    clean_desc = re.sub(r'\d{2}[-/]\d{2}[-/]\d{4}', '', clean_desc)
    clean_desc = re.sub(r'\d{2}[-/]\d{2}[-/]\d{2}', '', clean_desc)
    # Remove reference numbers (12+ digits)
    clean_desc = re.sub(r'\b\d{12,}\b', '', clean_desc)
    # Remove transaction IDs (alphanumeric 10+ chars)
    clean_desc = re.sub(r'\b[A-Z0-9]{10,}\b', '', clean_desc)
    # Remove mobile numbers
    clean_desc = re.sub(r'\b\d{10}\b', '', clean_desc)
    # Remove UPI IDs
    clean_desc = re.sub(r'[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+', '', clean_desc)
    # Clean up extra spaces
    clean_desc = ' '.join(clean_desc.split())
    
    # Check against known merchants database first
    for merchant_key, merchant_info in KNOWN_MERCHANTS.items():
        if merchant_key in desc_lower:
            return (merchant_info['display_name'], merchant_info['category'], 0.95)
    
    # Try to extract from UPI patterns
    upi_patterns = [
        r'(?:paid to|payment to|sent to|transfer to|to)\s+([A-Za-z][A-Za-z\s]{2,30})(?:\s+(?:via|using|on|from|ref|upi)|$)',
        r'(?:received from|from)\s+([A-Za-z][A-Za-z\s]{2,30})(?:\s+(?:via|using|on|ref)|$)',
        r'(?:upi|imps|neft)[-/]([A-Za-z][A-Za-z\s]+?)[-/]',
        r'^([A-Za-z][A-Za-z\s]{2,25})\s+(?:upi|payment|transfer)',
    ]
    
    for pattern in upi_patterns:
        match = re.search(pattern, clean_desc, re.IGNORECASE)
        if match:
            merchant = match.group(1).strip()
            # Clean up the merchant name - only alphabets and spaces
            merchant = re.sub(r'[^a-zA-Z\s]', '', merchant).strip()
            # Remove very short words at start/end
            words = merchant.split()
            words = [w for w in words if len(w) >= 2]
            if words:
                merchant = ' '.join(words)
                if 3 <= len(merchant) <= 50:
                    # Capitalize properly
                    merchant = ' '.join(word.capitalize() for word in merchant.split())
                    return (merchant, None, 0.75)
    
    # If no pattern matched, try to extract first meaningful words
    words = re.findall(r'\b[A-Za-z]{3,}\b', clean_desc)
    if words:
        # Expanded noise words list
        noise_words = {
            'upi', 'imps', 'neft', 'rtgs', 'ref', 'txn', 'payment', 'transfer',
            'to', 'from', 'via', 'paid', 'received', 'for', 'and', 'the',
            'credit', 'debit', 'transaction', 'account', 'bank', 'mobile',
            'number', 'xyz', 'abc', 'jan', 'feb', 'mar', 'apr', 'may', 'jun',
            'jul', 'aug', 'sep', 'oct', 'nov', 'dec', 'inr', 'rupees', 'rs'
        }
        clean_words = [w for w in words if w.lower() not in noise_words]
        if clean_words:
            merchant = ' '.join(clean_words[:3]).title()
            if 3 <= len(merchant) <= 50:
                return (merchant, None, 0.5)
    
    return (None, None, 0.0)


def categorize_transaction(description: str, amount: float = 0) -> str:
    """Categorize a transaction based on description with enhanced merchant recognition."""
    try:
        desc_lower = description.lower()
        
        # First try to extract merchant and get category from known merchants
        merchant_name, merchant_category, merchant_confidence = extract_merchant_name(description)
        
        if merchant_category:
            return json.dumps({
                "success": True,
                "category": merchant_category,
                "confidence": merchant_confidence,
                "transaction_type": 'income' if merchant_category == 'Income' else 'expense',
                "description": description,
                "merchant": merchant_name,
                "amount": amount
            })
        
        # Fallback to keyword matching
        category = 'Other'
        confidence = 0.5
        
        for cat, keywords in CATEGORY_KEYWORDS.items():
            for keyword in keywords:
                if keyword in desc_lower:
                    category = cat
                    confidence = 0.85
                    break
            if category != 'Other':
                break
        
        # Determine if income or expense based on category
        transaction_type = 'income' if category == 'Income' else 'expense'
        
        return json.dumps({
            "success": True,
            "category": category,
            "confidence": confidence,
            "transaction_type": transaction_type,
            "description": description,
            "merchant": merchant_name,
            "amount": amount
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def categorize_transactions_batch(transactions_json: str) -> str:
    """Categorize multiple transactions."""
    try:
        transactions = json.loads(transactions_json) if isinstance(transactions_json, str) else transactions_json
        
        results = []
        for tx in transactions:
            desc = tx.get('description', '')
            amount = tx.get('amount', 0)
            cat_result = json.loads(categorize_transaction(desc, amount))
            tx['category'] = cat_result.get('category', 'Other')
            tx['confidence'] = cat_result.get('confidence', 0.5)
            results.append(tx)
        
        return json.dumps({"success": True, "transactions": results})
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


# ==================== ANALYTICS ====================

def analyze_spending_trends(transactions: list) -> str:
    """Comprehensive spending analysis."""
    try:
        if isinstance(transactions, str):
            transactions = json.loads(transactions)
        
        total_income = 0
        total_expenses = 0
        categories = {}
        monthly_data = {}
        
        for tx in transactions:
            amount = abs(tx.get('amount', 0))
            category = tx.get('category', 'Other')
            date_str = tx.get('date', '')
            tx_type = tx.get('type', 'expense').lower()
            
            is_income = tx_type in ['income', 'credit', 'deposit']
            
            if is_income:
                total_income += amount
            else:
                total_expenses += amount
                categories[category] = categories.get(category, 0) + amount
            
            # Monthly aggregation
            if date_str:
                try:
                    month_key = date_str[:7]  # YYYY-MM
                    if month_key not in monthly_data:
                        monthly_data[month_key] = {'income': 0, 'expenses': 0}
                    if is_income:
                        monthly_data[month_key]['income'] += amount
                    else:
                        monthly_data[month_key]['expenses'] += amount
                except:
                    pass
        
        # Sort categories by amount
        sorted_categories = sorted(categories.items(), key=lambda x: x[1], reverse=True)
        
        # Calculate percentages
        category_breakdown = []
        for cat, amt in sorted_categories:
            pct = (amt / total_expenses * 100) if total_expenses > 0 else 0
            category_breakdown.append({
                "category": cat,
                "amount": round(amt, 2),
                "percentage": round(pct, 1)
            })
        
        savings_rate = ((total_income - total_expenses) / total_income * 100) if total_income > 0 else 0
        
        # Generate insights
        insights = []
        if len(category_breakdown) > 0:
            top_category = category_breakdown[0]
            insights.append(f"Your highest spending category is {top_category['category']} at {top_category['percentage']}% of total expenses.")
        
        if savings_rate < 10:
            insights.append("⚠️ Your savings rate is below 10%. Consider reducing discretionary spending.")
        elif savings_rate >= 30:
            insights.append("🌟 Excellent savings rate! You're saving over 30% of your income.")
        
        return json.dumps({
            "success": True,
            "analysis": {
                "total_income": round(total_income, 2),
                "total_expenses": round(total_expenses, 2),
                "net_savings": round(total_income - total_expenses, 2),
                "savings_rate": round(savings_rate, 2),
                "transaction_count": len(transactions),
                "category_breakdown": category_breakdown,
                "top_category": category_breakdown[0] if category_breakdown else None,
                "monthly_trend": monthly_data,
                "insights": insights
            }
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})

# Alias for Dart compatibility
analyze_spending = analyze_spending_trends


def get_financial_advice(
    income: float,
    expenses: float,
    savings: float,
    debt: float = 0,
    goals: list = None
) -> str:
    """Generate personalized financial advice."""
    try:
        savings_rate = ((income - expenses) / income * 100) if income > 0 else 0
        debt_to_income = (debt / (income * 12) * 100) if income > 0 else 0
        emergency_months = (savings / expenses) if expenses > 0 else 0
        
        advice = []
        priority_actions = []
        
        # Emergency fund check
        if emergency_months < 3:
            advice.append({
                "area": "Emergency Fund",
                "status": "Critical",
                "icon": "🚨",
                "message": f"You only have {emergency_months:.1f} months of emergency coverage. Priority: Build to 3-6 months."
            })
            priority_actions.append("Build emergency fund to 3 months of expenses")
        elif emergency_months < 6:
            advice.append({
                "area": "Emergency Fund",
                "status": "Warning",
                "icon": "⚠️",
                "message": f"You have {emergency_months:.1f} months coverage. Aim for 6 months."
            })
        else:
            advice.append({
                "area": "Emergency Fund",
                "status": "Good",
                "icon": "✅",
                "message": f"Great! You have {emergency_months:.1f} months of emergency coverage."
            })
        
        # Debt check
        if debt > 0:
            if debt_to_income > 40:
                advice.append({
                    "area": "Debt",
                    "status": "Critical",
                    "icon": "🚨",
                    "message": f"Debt-to-income ratio is {debt_to_income:.1f}%. This is too high. Focus on debt reduction."
                })
                priority_actions.append("Reduce debt aggressively")
            elif debt_to_income > 20:
                advice.append({
                    "area": "Debt",
                    "status": "Warning",
                    "icon": "⚠️",
                    "message": f"Debt-to-income ratio is {debt_to_income:.1f}%. Work on reducing this."
                })
        
        # Savings rate check
        if savings_rate < 10:
            advice.append({
                "area": "Savings",
                "status": "Critical",
                "icon": "🚨",
                "message": f"Savings rate is only {savings_rate:.1f}%. Cut expenses and increase savings."
            })
            priority_actions.append("Reduce expenses by 10-15%")
        elif savings_rate < 20:
            advice.append({
                "area": "Savings",
                "status": "Warning",
                "icon": "⚠️",
                "message": f"Savings rate is {savings_rate:.1f}%. Try to reach 20-30%."
            })
        else:
            advice.append({
                "area": "Savings",
                "status": "Good",
                "icon": "✅",
                "message": f"Excellent savings rate of {savings_rate:.1f}%!"
            })
        
        # Investment suggestion based on surplus
        monthly_surplus = income - expenses
        if monthly_surplus > 0:
            advice.append({
                "area": "Investment",
                "status": "Opportunity",
                "icon": "💰",
                "message": f"You have ₹{monthly_surplus:,.0f} monthly surplus. Consider SIP investments."
            })
        
        return json.dumps({
            "success": True,
            "financial_health": {
                "income": income,
                "expenses": expenses,
                "savings": savings,
                "debt": debt,
                "savings_rate": round(savings_rate, 1),
                "debt_to_income": round(debt_to_income, 1),
                "emergency_months": round(emergency_months, 1)
            },
            "advice": advice,
            "priority_actions": priority_actions,
            "overall_score": _calculate_financial_score(savings_rate, debt_to_income, emergency_months)
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def _calculate_financial_score(savings_rate, debt_to_income, emergency_months):
    """Calculate overall financial health score (0-100)."""
    score = 50  # Base score
    
    # Savings rate contribution (max 25 points)
    if savings_rate >= 30:
        score += 25
    elif savings_rate >= 20:
        score += 20
    elif savings_rate >= 10:
        score += 10
    
    # Debt contribution (max 25 points)
    if debt_to_income == 0:
        score += 25
    elif debt_to_income < 20:
        score += 20
    elif debt_to_income < 40:
        score += 10
    
    # Emergency fund contribution (max 20 points)
    if emergency_months >= 6:
        score += 20
    elif emergency_months >= 3:
        score += 10
    
    return min(100, max(0, score))


def calculate_debt_payoff(debts: list, extra_payment: float = 0) -> str:
    """Calculate debt payoff strategy (avalanche and snowball methods)."""
    try:
        if isinstance(debts, str):
            debts = json.loads(debts)
        
        # Sort for avalanche (highest rate first) and snowball (lowest balance first)
        avalanche_order = sorted(debts, key=lambda x: x.get('rate', 0), reverse=True)
        snowball_order = sorted(debts, key=lambda x: x.get('balance', 0))
        
        total_debt = sum(d.get('balance', 0) for d in debts)
        total_min_payment = sum(d.get('min_payment', 0) for d in debts)
        total_monthly = total_min_payment + extra_payment
        
        # Calculate months to payoff (simplified)
        avg_rate = sum(d.get('rate', 0) for d in debts) / len(debts) if debts else 0
        if total_monthly > 0:
            months_to_payoff = math.ceil(total_debt / total_monthly) if avg_rate == 0 else \
                math.ceil(math.log(total_monthly / (total_monthly - total_debt * avg_rate/1200)) / math.log(1 + avg_rate/1200))
        else:
            months_to_payoff = float('inf')
        
        return json.dumps({
            "success": True,
            "total_debt": round(total_debt, 2),
            "total_monthly_payment": round(total_monthly, 2),
            "estimated_months_to_payoff": months_to_payoff if months_to_payoff != float('inf') else -1,
            "avalanche_order": [d.get('name', 'Unknown') for d in avalanche_order],
            "snowball_order": [d.get('name', 'Unknown') for d in snowball_order],
            "recommendation": "Avalanche method saves more on interest, Snowball gives faster wins.",
            "debts": debts
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def project_net_worth(
    current_net_worth: float,
    monthly_savings: float,
    investment_return: float,
    years: int
) -> str:
    """Project future net worth."""
    try:
        monthly_rate = investment_return / 100 / 12
        projections = []
        
        for y in range(1, years + 1):
            months = y * 12
            # Future value of current net worth
            fv_current = current_net_worth * ((1 + monthly_rate) ** months)
            # Future value of monthly savings (annuity)
            if monthly_rate > 0:
                fv_savings = monthly_savings * (((1 + monthly_rate) ** months - 1) / monthly_rate)
            else:
                fv_savings = monthly_savings * months
            
            total = fv_current + fv_savings
            projections.append({
                "year": y,
                "net_worth": round(total, 2),
                "from_current": round(fv_current, 2),
                "from_savings": round(fv_savings, 2)
            })
        
        final_value = projections[-1]['net_worth'] if projections else current_net_worth
        
        return json.dumps({
            "success": True,
            "current_net_worth": round(current_net_worth, 2),
            "monthly_savings": round(monthly_savings, 2),
            "assumed_return": investment_return,
            "projected_net_worth": round(final_value, 2),
            "total_contributions": round(monthly_savings * years * 12, 2),
            "total_growth": round(final_value - current_net_worth - (monthly_savings * years * 12), 2),
            "projections": projections
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def calculate_tax_savings(
    income: float,
    investments_80c: float = 0,
    health_insurance_80d: float = 0,
    home_loan_interest: float = 0
) -> str:
    """Calculate tax savings under Indian tax law."""
    try:
        # 80C limit
        deduction_80c = min(investments_80c, 150000)
        # 80D limit (self)
        deduction_80d = min(health_insurance_80d, 25000)
        # Section 24 limit
        deduction_24 = min(home_loan_interest, 200000)
        
        total_deductions = deduction_80c + deduction_80d + deduction_24
        taxable_income = max(0, income - total_deductions - 50000)  # Standard deduction
        
        # Old regime tax calculation
        old_regime_tax = _calculate_old_regime_tax(taxable_income)
        
        # New regime tax calculation
        new_regime_tax = _calculate_new_regime_tax(income)
        
        better_regime = "Old Regime" if old_regime_tax < new_regime_tax else "New Regime"
        savings = abs(old_regime_tax - new_regime_tax)
        
        return json.dumps({
            "success": True,
            "gross_income": round(income, 2),
            "deductions": {
                "section_80c": round(deduction_80c, 2),
                "section_80d": round(deduction_80d, 2),
                "section_24": round(deduction_24, 2),
                "standard": 50000,
                "total": round(total_deductions + 50000, 2)
            },
            "taxable_income_old_regime": round(taxable_income, 2),
            "old_regime_tax": round(old_regime_tax, 2),
            "new_regime_tax": round(new_regime_tax, 2),
            "recommended_regime": better_regime,
            "potential_savings": round(savings, 2),
            "effective_tax_rate": round((min(old_regime_tax, new_regime_tax) / income * 100), 2) if income > 0 else 0
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


# ==================== BANK STATEMENT PARSING ====================

def parse_bank_statement(image_b64: str) -> str:
    """
    Extract transactions from a bank statement image using Zoho Vision.
    
    Args:
        image_b64: Base64-encoded image data (PNG/JPEG)
        
    Returns:
        JSON string with success status and transactions
    """
    token = _get_zoho_token()
    if not token:
        return json.dumps({"success": False, "error": "Zoho authentication failed"})
    
    try:
        url = f"https://api.catalyst.zoho.in/quickml/v1/project/{_zoho_creds['project_id']}/vlm/chat"
        
        # Prompt for bank statement extraction
        prompt = """Extract all transactions from this bank statement.
Return a JSON array of objects:
[
  {"date": "YYYY-MM-DD", "description": "...", "amount": 0.0, "type": "debit/credit"}
]
Return ONLY the JSON array."""

        body = {
            "prompt": prompt,
            "model": "VL-Qwen2.5-7B",
            "images": [image_b64],
            "system_prompt": "You are a bank statement OCR expert. Return only JSON.",
            "max_tokens": 4096
        }
        
        req = urllib.request.Request(
            url,
            data=json.dumps(body).encode(),
            headers={
                "Authorization": f"Bearer {token}",
                "CATALYST-ORG": _zoho_creds["org_id"],
                "Content-Type": "application/json"
            },
            method='POST'
        )
        
        with urllib.request.urlopen(req, timeout=60) as response:
            res = json.loads(response.read().decode())
            text = res.get("response", "")
            
            # Extract JSON array from response
            match = re.search(r'\[.*\]', text, re.DOTALL)
            if match:
                txs = json.loads(match.group())
                return json.dumps({
                    "success": True,
                    "bank_detected": "Detected",
                    "transactions": txs,
                    "imported_count": len(txs)
                })
            
            return json.dumps({"success": False, "error": "Could not parse bank statement", "raw": text})
            
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def _calculate_old_regime_tax(taxable_income: float) -> float:
    """Calculate tax under old regime."""
    if taxable_income <= 250000:
        return 0
    elif taxable_income <= 500000:
        return (taxable_income - 250000) * 0.05
    elif taxable_income <= 1000000:
        return 12500 + (taxable_income - 500000) * 0.2
    else:
        return 112500 + (taxable_income - 1000000) * 0.3


def _calculate_new_regime_tax(income: float) -> float:
    """Calculate tax under new regime (FY 2023-24)."""
    if income <= 300000:
        return 0
    elif income <= 600000:
        return (income - 300000) * 0.05
    elif income <= 900000:
        return 15000 + (income - 600000) * 0.1
    elif income <= 1200000:
        return 45000 + (income - 900000) * 0.15
    elif income <= 1500000:
        return 90000 + (income - 1200000) * 0.2
    else:
        return 150000 + (income - 1500000) * 0.3


# ==================== PYTHON PDF TEXT PARSER ====================

def parse_bank_statement_text(text: str) -> str:
    """
    Parse bank statement from OCR text.
    Handles PhonePe, HDFC, SBI, ICICI, Axis, Kotak, and generic formats.
    Input: OCR text from all pages concatenated
    Output: JSON with transactions
    """
    try:
        transactions = []
        
        # Detect bank/source
        text_lower = text.lower()
        bank_detected = "UNKNOWN"
        for bank, keywords in [
            ("PHONEPE", ["phonepe", "phone pe", "transaction statement for"]),
            ("HDFC", ["hdfc", "hdfcbank"]),
            ("SBI", ["sbi", "state bank of india"]),
            ("ICICI", ["icici"]),
            ("AXIS", ["axis"]),
            ("KOTAK", ["kotak"]),
            ("PAYTM", ["paytm"]),
            ("GPAY", ["google pay", "gpay"]),
        ]:
            if any(kw in text_lower for kw in keywords):
                bank_detected = bank
                break
        
        # Date patterns - comprehensive
        date_patterns = [
            # MMM DD, YYYY (PhonePe style)
            r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+(\d{1,2})[,.]?\s*(\d{4})',
            # DD MMM YYYY
            r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[,.]?\s*(\d{4})',
            # DD/MM/YYYY, DD-MM-YYYY
            r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})',
            # DD/MM/YY
            r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2})\b',
        ]
        
        # Amount patterns
        amount_patterns = [
            r'₹\s*([\d,]+(?:\.\d{2})?)',  # ₹1,234.56
            r'Rs\.?\s*([\d,]+(?:\.\d{2})?)',  # Rs. 1234
            r'INR\s*([\d,]+(?:\.\d{2})?)',  # INR 1234
            r'\+\s*₹?\s*([\d,]+(?:\.\d{2})?)',  # + ₹1234 (credit)
            r'\-\s*₹?\s*([\d,]+(?:\.\d{2})?)',  # - ₹1234 (debit)
            r'([\d,]+(?:\.\d{2})?)\s*(Cr|Dr|CR|DR)\b',  # 1234.56 Cr/Dr
        ]
        
        # Month name to number
        month_map = {
            'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
            'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
            'sep': '09', 'sept': '09', 'oct': '10', 'nov': '11', 'dec': '12'
        }
        
        # Merchant categorization
        categories = {
            'swiggy': 'Food', 'zomato': 'Food', 'dominos': 'Food',
            'amazon': 'Shopping', 'flipkart': 'Shopping', 'myntra': 'Shopping',
            'bigbasket': 'Groceries', 'zepto': 'Groceries', 'blinkit': 'Groceries',
            'uber': 'Transport', 'ola': 'Transport', 'irctc': 'Transport',
            'netflix': 'Entertainment', 'spotify': 'Entertainment', 'hotstar': 'Entertainment',
            'airtel': 'Bills', 'jio': 'Bills', 'bsnl': 'Bills',
            'apollo': 'Healthcare', 'pharmeasy': 'Healthcare',
            'makemytrip': 'Travel', 'goibibo': 'Travel', 'oyo': 'Travel',
            'zerodha': 'Investments', 'groww': 'Investments',
            'lic': 'Insurance', 'icici prudential': 'Insurance',
        }
        
        lines = text.split('\n')
        last_date = None
        
        # Strategy 1: PhonePe-specific "Paid to" / "Received from" parsing
        if bank_detected == "PHONEPE":
            # Find all amounts in text
            all_amounts = []
            for pattern in amount_patterns:
                for match in re.finditer(pattern, text, re.IGNORECASE):
                    try:
                        amt_str = match.group(1).replace(',', '')
                        amt = float(amt_str)
                        if 10 <= amt < 10000000:  # ₹10 to ₹1 crore
                            all_amounts.append(amt)
                    except:
                        pass
            
            amount_idx = 0
            for i, line in enumerate(lines):
                # Extract date
                for pattern in date_patterns:
                    match = re.search(pattern, line, re.IGNORECASE)
                    if match:
                        try:
                            groups = match.groups()
                            if groups[0].isalpha():  # MMM DD, YYYY
                                month = month_map.get(groups[0].lower()[:3], '01')
                                day = groups[1].zfill(2)
                                year = groups[2]
                            elif len(groups) >= 3 and groups[1].isalpha():  # DD MMM YYYY
                                day = groups[0].zfill(2)
                                month = month_map.get(groups[1].lower()[:3], '01')
                                year = groups[2]
                            else:  # DD/MM/YYYY
                                day = groups[0].zfill(2)
                                month = groups[1].zfill(2)
                                year = groups[2] if len(groups[2]) == 4 else f"20{groups[2]}"
                            last_date = f"{year}-{month}-{day}"
                        except:
                            pass
                        break
                
                # Check for "Paid to" pattern
                paid_match = re.search(r'(?:Paid to|Payment to)\s+(.+)', line, re.IGNORECASE)
                if paid_match:
                    merchant = paid_match.group(1).strip()[:50]
                    
                    # Try to get amount from nearby lines
                    tx_amount = None
                    for j in range(i, min(i + 5, len(lines))):
                        for pattern in amount_patterns:
                            amt_match = re.search(pattern, lines[j], re.IGNORECASE)
                            if amt_match:
                                try:
                                    tx_amount = float(amt_match.group(1).replace(',', ''))
                                    break
                                except:
                                    pass
                        if tx_amount:
                            break
                    
                    # Use from all_amounts if not found
                    if not tx_amount and amount_idx < len(all_amounts):
                        tx_amount = all_amounts[amount_idx]
                        amount_idx += 1
                    
                    # Use the centralized categorization logic to confirm/refine
                    cat_result = json.loads(categorize_transaction(merchant, tx_amount or 0.0))
                    
                    transactions.append({
                        'date': last_date or datetime.now().strftime('%Y-%m-%d'),
                        'description': merchant,
                        'amount': tx_amount or 0.0,
                        'type': 'expense',
                        'category': cat_result.get('category', 'Other'),
                        'merchant': cat_result.get('merchant', merchant)
                    })
                
                # Check for "Received from" pattern
                received_match = re.search(r'Received from\s+(.+)', line, re.IGNORECASE)
                if received_match:
                    sender = received_match.group(1).strip()[:50]
                    
                    tx_amount = None
                    for j in range(i, min(i + 5, len(lines))):
                        for pattern in amount_patterns:
                            amt_match = re.search(pattern, lines[j], re.IGNORECASE)
                            if amt_match:
                                try:
                                    tx_amount = float(amt_match.group(1).replace(',', ''))
                                    break
                                except:
                                    pass
                        if tx_amount:
                            break
                    
                    if not tx_amount and amount_idx < len(all_amounts):
                        tx_amount = all_amounts[amount_idx]
                        amount_idx += 1
                    
                    # Use the centralized categorization logic
                    cat_result = json.loads(categorize_transaction(f"Received from {sender}", tx_amount or 0.0))
                    
                    transactions.append({
                        'date': last_date or datetime.now().strftime('%Y-%m-%d'),
                        'description': f'Received from {sender}',
                        'amount': tx_amount or 0.0,
                        'type': 'income',
                        'category': cat_result.get('category', 'Income'),
                        'merchant': cat_result.get('merchant', sender)
                    })
        
        # Strategy 2: Generic line-by-line parsing for other banks
        if not transactions:
            for i, line in enumerate(lines):
                # Update date
                for pattern in date_patterns:
                    match = re.search(pattern, line, re.IGNORECASE)
                    if match:
                        try:
                            groups = match.groups()
                            if groups[0].isalpha():
                                month = month_map.get(groups[0].lower()[:3], '01')
                                day = groups[1].zfill(2)
                                year = groups[2]
                            elif len(groups) >= 3 and str(groups[1]).isalpha():
                                day = groups[0].zfill(2)
                                month = month_map.get(str(groups[1]).lower()[:3], '01')
                                year = groups[2]
                            else:
                                day = groups[0].zfill(2)
                                month = groups[1].zfill(2)
                                year = groups[2] if len(groups[2]) == 4 else f"20{groups[2]}"
                            last_date = f"{year}-{month}-{day}"
                        except:
                            pass
                        break
                
                # Look for amount in line
                for pattern in amount_patterns:
                    amt_match = re.search(pattern, line, re.IGNORECASE)
                    if amt_match:
                        try:
                            amount = float(amt_match.group(1).replace(',', ''))
                            if amount < 10 or amount > 10000000:
                                continue
                            
                            # Determine type
                            tx_type = 'expense'
                            if '+' in line or 'cr' in line.lower() or 'credit' in line.lower():
                                tx_type = 'income'
                            
                            # Clean description
                            desc = re.sub(r'[₹Rs\.INR\d,]+', '', line).strip()[:60]
                            if not desc or len(desc) < 3:
                                desc = 'Transaction'
                            
                            # Use the centralized categorization logic
                            cat_result = json.loads(categorize_transaction(desc, amount))
                            
                            transactions.append({
                                'date': last_date or datetime.now().strftime('%Y-%m-%d'),
                                'description': desc,
                                'amount': amount,
                                'type': tx_type,
                                'category': cat_result.get('category', 'Other'),
                                'merchant': cat_result.get('merchant', 'Unknown')
                            })
                            break
                        except:
                            pass
        
        # Deduplicate
        seen = set()
        unique_txs = []
        for tx in transactions:
            key = f"{tx['date']}_{tx['amount']}_{tx['description'][:15]}"
            if key not in seen:
                seen.add(key)
                unique_txs.append(tx)
        
        # Filter out zero-amount transactions
        unique_txs = [tx for tx in unique_txs if tx['amount'] > 0]
        
        if not unique_txs:
            return json.dumps({
                "success": False,
                "error": "No transactions found. The statement format may not be supported.",
                "bank_detected": bank_detected,
                "text_preview": text[:300]
            })
        
        return json.dumps({
            "success": True,
            "bank_detected": bank_detected,
            "transactions": unique_txs,
            "imported_count": len(unique_txs)
        })
        
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


# ==================== HEALTH CHECK ====================

def health_check() -> str:
    """Check if Python backend is functioning."""
    return json.dumps({
        "success": True,
        "status": "healthy",
        "version": "2.0.0",
        "python_version": "3.8",
        "capabilities": [
            "financial_calculations",
            "transaction_categorization",
            "spending_analytics",
            "tax_calculations",
            "debt_analysis",
            "financial_advice"
        ],
        "tools_available": len(AVAILABLE_TOOLS)
    })


def init_python_backend() -> str:
    """Initialize the Python backend."""
    try:
        return json.dumps({
            "success": True,
            "message": "Python backend initialized - Full embedded mode",
            "version": "2.0.0",
            "mode": "embedded",
            "tools_count": len(AVAILABLE_TOOLS),
            "capabilities": [
                "SIP/EMI/Compound Interest calculations",
                "FIRE number calculation",
                "Emergency fund analysis",
                "Transaction categorization (14 categories)",
                "Spending analytics",
                "Debt payoff strategies",
                "Tax savings calculation (Indian)",
                "Net worth projection",
                "Personalized financial advice",
                "Bank statement parsing (Python)"
            ]
        })
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})

