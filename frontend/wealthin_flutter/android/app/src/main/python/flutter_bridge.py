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
# Keys are injected at runtime via set_config() from Flutter's secure storage
# DO NOT hardcode API keys here — they are managed by Android KeyStore
_sarvam_api_key = ""  # Set via set_config()
_groq_api_key = ""    # Set via set_config()
_gov_msme_api_key = ""  # Set via set_config() - data.gov.in MSME/UDYAM API
_zoho_creds = {
    "project_id": "24392000000011167",
    "org_id": "60056122667",
    "client_id": "",
    "client_secret": "",
    "refresh_token": ""
}

def set_config(config_json: str) -> str:
    """Set API keys and configuration dynamically."""
    global _sarvam_api_key, _groq_api_key, _gov_msme_api_key, _zoho_creds
    try:
        config = json.loads(config_json)
        
        if "sarvam_api_key" in config and config["sarvam_api_key"]:
            _sarvam_api_key = config["sarvam_api_key"]

        if "groq_api_key" in config and config["groq_api_key"]:
            _groq_api_key = config["groq_api_key"]

        if "gov_msme_api_key" in config and config["gov_msme_api_key"]:
            _gov_msme_api_key = config["gov_msme_api_key"]
            
        if "zoho_creds" in config:
            _zoho_creds.update(config["zoho_creds"])
        
        # Diagnostic logging (key lengths only, never values)
        print(f"[set_config] Keys configured:")
        print(f"  Groq: {'✓ ' + str(len(_groq_api_key)) + ' chars' if _groq_api_key else '✗ MISSING'}")
        print(f"  Sarvam: {'✓ ' + str(len(_sarvam_api_key)) + ' chars' if _sarvam_api_key else '✗ MISSING'}")
        print(f"  GovMSME: {'✓ ' + str(len(_gov_msme_api_key)) + ' chars' if _gov_msme_api_key else '✗ MISSING'}")
        
        configured_providers = []
        if _groq_api_key: configured_providers.append("Groq")
        if _sarvam_api_key: configured_providers.append("Sarvam")
        if not configured_providers:
            print(f"[set_config] ⚠ WARNING: No AI providers configured! Chat/Analysis will fail.")
        else:
            print(f"[set_config] Active AI providers: {', '.join(configured_providers)}")
            
        return json.dumps({"success": True, "message": "Configuration updated", "providers": configured_providers})
    except Exception as e:
        print(f"[set_config] ERROR: {e}")
        return json.dumps({"success": False, "error": str(e)})


def health_check() -> str:
    """
    Check the health of the Python environment.
    Returns status of various components for the Flutter Settings screen.
    """
    global _sarvam_api_key, _groq_api_key, _gov_msme_api_key
    
    components = {
        "python": True,  # If we're running this, Python is working
        "sarvam_configured": bool(_sarvam_api_key),
        "groq_configured": bool(_groq_api_key),
        "gov_msme_configured": bool(_gov_msme_api_key),
        "pdf_parser_available": False,
        "tools_count": len(AVAILABLE_TOOLS),
    }
    
    # Check if PDF parser is available
    try:
        from pypdf import PdfReader
        components["pdf_parser_available"] = True
        components["pdf_engine"] = "pypdf"
    except ImportError:
        components["pdf_engine"] = "none"
    
    return json.dumps({
        "success": True,
        "status": "ready",
        "components": components,
        "sarvam_configured": components["sarvam_configured"],
        "groq_configured": components["groq_configured"],
        "pdf_parser_available": components["pdf_parser_available"],
    })


# ==================== AI-POWERED ANALYSIS ====================

def generate_ai_analysis(financial_data_json: str) -> str:
    """
    Generate AI-powered financial analysis using Groq GPT-OSS.
    Takes aggregated transaction data and returns personalized insights.
    Called by Flutter's getHealthScore to enrich the health report with AI analysis.
    """
    global _groq_api_key, _sarvam_api_key
    
    try:
        data = json.loads(financial_data_json) if isinstance(financial_data_json, str) else financial_data_json
        
        # Build the analysis prompt with user's actual financial data
        prompt = f"""Analyze this Indian user's financial data. Be encouraging — focus on what's working AND how to improve.

## Financial Snapshot
- Monthly Income: ₹{data.get('income', 0):,.0f}
- Monthly Expenses: ₹{data.get('expenses', 0):,.0f}
- Net Savings: ₹{data.get('savings', 0):,.0f}
- Savings Rate: {data.get('savings_rate', 0):.1f}%
- Current Health Score: {data.get('health_score', 0):.0f}/100

## Category-wise Spending
{data.get('category_breakdown', 'No data')}

## Active Budgets
{data.get('budget_info', 'No budgets set')}

## Savings Goals
{data.get('goal_info', 'No goals set')}

## Top Merchants / Frequent Transactions
{data.get('top_merchants', 'No merchant data')}

## Month-over-Month Trend
{data.get('monthly_trend', 'No trend data available')}

## Instructions — Follow This Format EXACTLY

### 📊 How You're Doing
Start with encouragement. Mention 1-2 things the user is doing well before any critique.
Then give a clear 3-line assessment: score interpretation, spending discipline, and trajectory.

### 🔍 Where Your Money Goes
Analyze the top 3-4 spending categories:
• Are they proportional to income? Flag any that are unusually high.
• Mention specific merchants if they appear frequently.
• Identify subscriptions or recurring small charges that add up.

### ✅ What's Going Right
List 2-3 positives — things the user should KEEP doing. E.g.:
• "Your savings rate of X% is above the national average of 15%"
• "You have active savings goals — that's a great discipline"
• "Your debt-to-income ratio is healthy"

### ⚠️ What Needs Attention
List 2-3 areas that need improvement, but frame each one POSITIVELY with a fix:
• Instead of: "You spend too much on Food"
• Say: "Food spending is ₹X/month (Y% of income). Reducing by ₹Z/month would boost your savings rate to W%. Consider meal prepping or local tiffin services from MSME vendors."

### 🏭 Save with Local MSMEs
Look at the user's spending categories and suggest where they could save by switching to local MSME/small business alternatives:
• Food/Groceries → Local kirana stores, community buying groups
• Services → Local registered service providers via UDYAM directory
• Shopping → Local artisans, cooperative stores
• Repairs/Maintenance → Registered MSME workshops

For each suggestion, explain the potential savings in ₹ and mention "You can search for registered MSMEs near you using the Udyam directory" — this helps both the user and local enterprises.

### 🗺️ Your Improvement Roadmap

**Month 1 (Quick Wins):**
• [Specific action with ₹ amount] — Expected impact: +N points on health score
• [Second quick action]

**Month 2-3 (Build Habits):**
• [Action like starting SIP, setting up auto-save]
• [Budget adjustments with exact ₹ targets]

**Month 4-6 (Level Up):**
• [Investment actions, emergency fund milestone]
• [Score projection: "By month 6, your score could reach X/100"]

### 🎯 Score Projection
- Current Score: {data.get('health_score', 0):.0f}/100
- 3-Month Target: [realistic number]/100
- 6-Month Target: [realistic number]/100
- Next Tier: [e.g., "Moving from Fair (52) to Good (65+)"]

IMPORTANT: Use ONLY the data provided. Never make up numbers. Be encouraging and specific — use actual ₹ amounts. Use Indian context (UPI, SIP, RD, FD, PPF, ELSS, kirana, tiffin, MSME)."""

        messages = [
            {"role": "system", "content": "You are WealthIn AI, a warm and encouraging financial analyst for Indian users. Your job is to make users feel good about their progress while giving specific, actionable improvements. Format using markdown. Never fabricate data — only use the numbers provided."},
            {"role": "user", "content": prompt}
        ]
        
        # Use Groq first, fallback to Sarvam
        result = None
        if _groq_api_key:
            result = _call_groq_llm(messages, _groq_api_key)
        if not result and _sarvam_api_key:
            result = _call_sarvam_llm(messages, _sarvam_api_key)
        
        if result and result.get('content'):
            return json.dumps({
                "success": True,
                "analysis": result['content'],
                "model": "groq-gpt-oss-20b" if _groq_api_key else "sarvam-m"
            })
        
        return json.dumps({
            "success": False,
            "analysis": "",
            "error": "No response from AI models"
        })
        
    except Exception as e:
        print(f"[AI Analysis] Error: {e}")
        return json.dumps({
            "success": False,
            "analysis": "",
            "error": str(e)
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
    },
    {
        "name": "create_scheduled_payment",
        "description": "Create a new scheduled payment or bill reminder",
        "parameters": {
            "name": "str - Payment name (e.g., Netflix, Rent, Electricity)",
            "amount": "float - Payment amount in INR",
            "category": "str - Payment category",
            "due_date": "str - First due date (YYYY-MM-DD)",
            "frequency": "str - Frequency: 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly' (default: monthly)"
        },
        "requires_confirmation": True
    },
    {
        "name": "detect_subscriptions",
        "description": "Analyze transaction history to find recurring subscriptions and regular payments. Returns a list of detected subscriptions with their frequency, amounts, and next expected dates.",
        "parameters": {
            "transactions": "list - List of transaction objects with fields: description, amount, date, category, merchant (optional)"
        }
    },
    {
        "name": "check_pmegp_eligibility",
        "description": "Check eligibility for the PMEGP (Prime Minister Employment Generation Programme) scheme. Returns subsidy amounts, own contribution required, and bank loan needed.",
        "parameters": {
            "project_cost": "float - Total project cost in INR",
            "sector": "str - 'manufacturing' or 'service'",
            "location": "str - 'urban' or 'rural'",
            "category": "str - 'general' or 'special' (SC/ST/Women/Minority)"
        }
    },
    {
        "name": "check_standup_india_eligibility",
        "description": "Check eligibility for Stand-Up India scheme for SC/ST/Women entrepreneurs. Returns loan terms and eligibility status.",
        "parameters": {
            "loan_amount": "float - Required loan amount in INR",
            "applicant_category": "str - 'sc', 'st', or 'woman'",
            "is_greenfield": "bool - Is this a first-time venture?",
            "sector": "str - 'manufacturing', 'services', or 'agri-allied'"
        }
    },
    {
        "name": "calculate_dscr",
        "description": "Calculate Debt Service Coverage Ratio for bank loan applications. Banks typically require DSCR >= 1.5.",
        "parameters": {
            "net_operating_income": "float - Annual net operating income (EBITDA) in INR",
            "annual_interest": "float - Annual interest payment in INR",
            "annual_principal": "float - Annual principal repayment in INR"
        }
    },
    {
        "name": "calculate_tam_sam_som",
        "description": "Calculate TAM (Total Addressable Market), SAM (Serviceable Addressable Market), and SOM (Serviceable Obtainable Market) for market sizing.",
        "parameters": {
            "total_potential_customers": "int - Total number of potential customers in the market",
            "average_revenue_per_user": "float - Average revenue per customer (INR)",
            "geographic_accessibility_pct": "float - % of market accessible geographically (0-100)",
            "feature_accessibility_pct": "float - % of market your product can serve (0-100)",
            "operational_capacity_pct": "float - Your operational capacity % (0-100)",
            "competitive_edge_pct": "float - Expected market share based on competition (0-100)"
        }
    },
    {
        "name": "generate_socratic_question",
        "description": "Generate a Socratic question to guide MSME brainstorming. Uses 6 question types: clarification, probing_assumptions, probing_evidence, viewpoints, implications, meta.",
        "parameters": {
            "business_idea": "str - The user's business idea or topic",
            "aspect": "str - Specific aspect to focus on",
            "question_type": "str - Type of question: 'clarification', 'probing_assumptions', 'probing_evidence', 'viewpoints', 'implications', 'meta'",
            "current_section": "str - DPR section: 'market_analysis', 'technical_viability', 'financial_projections', 'compliance', 'risk_mitigation'"
        }
    },
    {
        "name": "start_brainstorming",
        "description": "Start a structured Socratic brainstorming session for DPR preparation.",
        "parameters": {
            "business_idea": "str - The MSME business idea to explore",
            "section": "str - Starting DPR section (default: 'market_analysis')"
        }
    },
    {
        "name": "process_brainstorm_response",
        "description": "Process user's response in brainstorming session and get the next Socratic question.",
        "parameters": {
            "user_response": "str - User's answer to the previous question",
            "current_aspect": "str - Current topic/aspect being discussed"
        }
    },
    {
        "name": "run_sensitivity_analysis",
        "description": "Run DSCR sensitivity analysis for bank loan applications. Shows how DSCR changes with revenue/cost/interest variations.",
        "parameters": {
            "base_revenue": "float - Annual revenue in INR",
            "base_costs": "float - Annual operating costs in INR",
            "loan_amount": "float - Total loan amount in INR",
            "interest_rate": "float - Annual interest rate % (default: 12)",
            "loan_tenure_years": "int - Loan repayment period in years (default: 5)",
            "variation_pct": "float - Percentage variation for sensitivity (default: 20)"
        }
    },
    {
        "name": "run_scenario_comparison",
        "description": "Compare optimistic, base, conservative, and worst-case scenarios for MSME projections.",
        "parameters": {
            "base_revenue": "float - Annual revenue in INR",
            "base_costs": "float - Annual operating costs in INR",
            "loan_amount": "float - Total loan amount in INR",
            "interest_rate": "float - Annual interest rate % (default: 12)",
            "loan_tenure_years": "int - Loan repayment period in years (default: 5)"
        }
    },
    {
        "name": "run_cash_runway_analysis",
        "description": "Analyze cash runway under normal and stress scenarios. Shows how long the business can survive.",
        "parameters": {
            "initial_cash": "float - Starting cash balance in INR",
            "monthly_revenue": "float - Expected monthly revenue in INR",
            "monthly_costs": "float - Monthly operating costs in INR",
            "monthly_debt_service": "float - Monthly loan EMI in INR",
            "growth_rate_pct": "float - Expected monthly revenue growth % (default: 5)"
        }
    },
    {
        "name": "generate_dpr",
        "description": "Generate a complete Detailed Project Report (DPR) in standardized banking format for MSME loan applications.",
        "parameters": {
            "project_data": "dict - Project data with sections: executive_summary, promoter_profile, market_analysis, financial_projections, cost_of_project, profitability, compliance"
        }
    },
    {
        "name": "get_dpr_template",
        "description": "Get an empty DPR template with all required fields for bank loan applications.",
        "parameters": {}
    },
    {
        "name": "search_msme_directory",
        "description": "Search the Government of India UDYAM MSME directory for registered enterprises by State and District. Returns enterprise name, address, activities/services, pincode and registration date. Use this when user asks about local businesses, vendors, service providers, or registered MSMEs in a specific area.",
        "parameters": {
            "state": "str - Indian state name in UPPERCASE (e.g., 'MAHARASHTRA', 'KARNATAKA', 'TAMIL NADU')",
            "district": "str - District name in UPPERCASE (e.g., 'PUNE', 'BANGALORE', 'CHENNAI')",
            "limit": "int - Number of results to return (default: 10, max: 10)"
        }
    },
    {
        "name": "search_jobs",
        "description": "Search for job opportunities based on role, location, and skills. Searches across major Indian job platforms like LinkedIn, Naukri, Indeed, Foundit.",
        "parameters": {
            "role": "str - Job role (e.g., 'Python Developer', 'Digital Marketer')",
            "location": "str - Location (e.g., 'Bangalore', 'Remote', 'Mumbai')",
            "skills": "str - Optional key skills to include in search",
            "experience_level": "str - Optional experience level (e.g., 'Freshers', 'Mid-level', 'Senior')"
        }
    },
    {
        "name": "get_career_advice",
        "description": "Get career growth advice, salary insights, or interview preparation tips for a specific role or career transition.",
        "parameters": {
            "current_role": "str - Current job role or 'Student' / 'Fresher'",
            "target_role": "str - Desired next role or job title",
            "industry": "str - Industry (e.g., 'IT', 'Finance', 'Healthcare', 'Marketing')",
            "query_type": "str - Type of advice: 'growth_path', 'salary_insight', or 'interview_prep'"
        }
    }
]

# Agentic Actions Storage (for confirmation flow)
_pending_actions = {}



# ==================== TOOL EXECUTOR ====================

def execute_tool(tool_name: str, args_json: str) -> str:
    """
    Execute a tool by name with given arguments.
    This is the main entry point for the LLM to call tools.
    
    NOTE: args_json is passed as a JSON string from Kotlin, we need to parse it.
    """
    try:
        # Parse the JSON string to a dict
        if isinstance(args_json, str):
            args = json.loads(args_json)
        else:
            args = args_json  # Already a dict
        
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
            "create_scheduled_payment": prepare_create_scheduled_payment,
            # Pattern Analysis Tools
            "detect_subscriptions": detect_subscriptions,
            # MSME Compliance & Financial Tools
            "check_pmegp_eligibility": check_pmegp_eligibility,
            "check_standup_india_eligibility": check_standup_india_eligibility,
            "calculate_dscr": calculate_dscr,
            "calculate_tam_sam_som": calculate_tam_sam_som,
            # Socratic Brainstorming Tools
            "generate_socratic_question": generate_socratic_question,
            "start_brainstorming": start_brainstorming_session,
            "process_brainstorm_response": process_brainstorm_response,
            # What-If Simulator Tools
            "run_sensitivity_analysis": run_sensitivity_analysis,
            "run_scenario_comparison": run_scenario_comparison,
            "run_cash_runway_analysis": run_cash_runway_analysis,
            # DPR Generator Tools
            "generate_dpr": generate_dpr,
            "get_dpr_template": get_dpr_template,
            # Government MSME Directory
            "search_msme_directory": search_msme_directory,
            # Job & Career Tools
            "search_jobs": search_jobs,
            "get_career_advice": get_career_advice,
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
        "confirmation_message": f"💸 Add **{type}**: **₹{amount:,.0f}** for **{description}** ({category})?",
        "buttons": ["✅ Yes, add it", "❌ Cancel"]
    })


def prepare_create_scheduled_payment(name: str, amount: float, category: str, due_date: str, frequency: str = "monthly") -> str:
    """Prepare scheduled payment creation - requires user confirmation."""
    action_id = f"sch_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    _pending_actions[action_id] = {
        "type": "create_scheduled_payment",
        "data": {
            "name": name,
            "amount": amount,
            "category": category,
            "dueDate": due_date,
            "frequency": frequency,
            "isAutopay": False
        },
        "created_at": datetime.now().isoformat()
    }
    return json.dumps({
        "success": True,
        "requires_confirmation": True,
        "action_id": action_id,
        "action_type": "create_scheduled_payment",
        "action_data": {
            "name": name,
            "amount": amount,
            "category": category,
            "due_date": due_date,
            "frequency": frequency
        },
        "confirmation_message": f"📅 Schedule **{frequency}** payment: **₹{amount:,.0f}** for **{name}**?",
        "buttons": ["✅ Yes, schedule it", "❌ Cancel"]
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


# ==================== SUBSCRIPTION/PATTERN DETECTION ====================

def detect_subscriptions(transactions: List[Dict]) -> str:
    """
    Analyze transactions to detect recurring subscriptions and regular payments.
    Uses time delta standard deviation and amount variance to identify patterns.
    
    Args:
        transactions: List of dicts with: description, amount, date, category, merchant (optional)
    
    Returns:
        JSON with detected subscriptions and recurring habits
    """
    import statistics
    from collections import defaultdict
    
    if not transactions or len(transactions) < 2:
        return json.dumps({
            "success": True,
            "subscriptions": [],
            "recurring_habits": [],
            "total_monthly_cost": 0,
            "message": "Not enough transactions to detect patterns."
        })
    
    # Configuration thresholds
    TIME_DELTA_SD_THRESHOLD = 3.0  # Max SD in days for "regular" recurrence
    AMOUNT_CV_THRESHOLD = 0.1  # Max coefficient of variation for "fixed" amount
    MIN_OCCURRENCES = 2
    
    # Group transactions by normalized merchant/description
    grouped = defaultdict(list)
    for tx in transactions:
        merchant = tx.get('merchant') or tx.get('description') or 'Unknown'
        key = _normalize_merchant_for_subscription(merchant)
        grouped[key].append({
            'description': tx.get('description', ''),
            'amount': abs(float(tx.get('amount', 0))),
            'date': tx.get('date', ''),
            'category': tx.get('category', 'Other')
        })
    
    subscriptions = []
    recurring_habits = []
    
    for merchant_key, txs in grouped.items():
        if len(txs) < MIN_OCCURRENCES:
            continue
        
        # Analyze pattern
        pattern = _analyze_subscription_pattern(txs)
        
        if pattern['is_subscription']:
            subscriptions.append({
                'merchant': merchant_key,
                'category': txs[0]['category'],
                'frequency': pattern['frequency'],
                'average_amount': pattern['avg_amount'],
                'last_charge': txs[-1]['date'] if txs else None,
                'next_expected': pattern['next_expected'],
                'occurrences': len(txs),
                'confidence': pattern['confidence']
            })
        elif pattern['is_recurring_habit']:
            recurring_habits.append({
                'merchant': merchant_key,
                'category': txs[0]['category'],
                'frequency': pattern['frequency'],
                'average_amount': pattern['avg_amount'],
                'occurrences': len(txs)
            })
    
    # Sort by monthly impact
    subscriptions.sort(key=lambda x: x['average_amount'], reverse=True)
    recurring_habits.sort(key=lambda x: x['average_amount'] * x['occurrences'], reverse=True)
    
    # Calculate monthly cost
    monthly_cost = sum(
        _normalize_amount_to_monthly(s['average_amount'], s['frequency'])
        for s in subscriptions
    )
    
    return json.dumps({
        "success": True,
        "subscriptions": subscriptions[:20],  # Top 20
        "recurring_habits": recurring_habits[:10],  # Top 10
        "total_monthly_cost": round(monthly_cost, 2),
        "annual_projection": round(monthly_cost * 12, 2),
        "message": f"Found {len(subscriptions)} subscriptions totaling ₹{monthly_cost:,.0f}/month"
    })


# ==================== JOB & CAREER TOOLS ====================

def search_jobs(role: str, location: str, skills: str = "", experience_level: str = "") -> str:
    """
    Search for job opportunities using web search with job-platform-targeted queries.
    Searches across LinkedIn, Naukri, Indeed, and Foundit for the Indian job market.
    """
    query_parts = [f'"{role}"', f'"{location}"']
    if skills:
        query_parts.append(skills)
    if experience_level:
        query_parts.append(f'"{experience_level}"')
    
    base_query = " ".join(query_parts)
    search_query = f"{base_query} jobs (site:linkedin.com/jobs OR site:naukri.com OR site:indeed.co.in OR site:foundit.in)"
    
    return execute_web_search(search_query)


def get_career_advice(current_role: str, target_role: str, industry: str, query_type: str) -> str:
    """
    Get career growth advice, salary insights, or interview preparation tips.
    Routes to targeted web searches based on the query type.
    """
    if query_type == 'salary_insight':
        return execute_web_search(
            f"average salary for {target_role} in {industry} India {datetime.now().year}"
        )
    
    elif query_type == 'interview_prep':
        return execute_web_search(
            f"interview questions for {target_role} {industry} India"
        )
    
    else:  # growth_path or general
        return execute_web_search(
            f"career path from {current_role} to {target_role} in {industry} India"
        )


def _normalize_merchant_for_subscription(name: str) -> str:
    """Clean merchant name for grouping."""
    if not name:
        return "unknown"
    cleaned = re.sub(r'[*#\d]+', '', name.lower())
    cleaned = re.sub(r'[^\w\s]', '', cleaned)
    for suffix in ['.com', 'com', 'inc', 'ltd', 'pvt', 'private', 'limited']:
        cleaned = cleaned.replace(suffix, '')
    return cleaned.strip() or "unknown"


def _analyze_subscription_pattern(transactions: List[Dict]) -> Dict:
    """Analyze transactions to detect subscription patterns."""
    import statistics
    
    amounts = [tx['amount'] for tx in transactions]
    dates = []
    for tx in transactions:
        try:
            date_str = tx['date'][:10]  # Handle ISO format
            dates.append(datetime.strptime(date_str, '%Y-%m-%d'))
        except:
            continue
    
    if len(dates) < 2:
        return {'is_subscription': False, 'is_recurring_habit': False, 'frequency': 'irregular'}
    
    # Sort by date
    sorted_pairs = sorted(zip(dates, amounts), key=lambda x: x[0])
    dates = [p[0] for p in sorted_pairs]
    amounts = [p[1] for p in sorted_pairs]
    
    # Time delta analysis
    deltas = [(dates[i+1] - dates[i]).days for i in range(len(dates)-1)]
    avg_delta = statistics.mean(deltas)
    delta_sd = statistics.stdev(deltas) if len(deltas) > 1 else 0
    
    # Amount analysis
    avg_amount = statistics.mean(amounts)
    amount_sd = statistics.stdev(amounts) if len(amounts) > 1 else 0
    amount_cv = (amount_sd / avg_amount) if avg_amount > 0 else 0
    
    # Determine frequency
    if avg_delta <= 8:
        frequency = 'weekly'
    elif avg_delta <= 16:
        frequency = 'bi-weekly'
    elif avg_delta <= 35:
        frequency = 'monthly'
    elif avg_delta <= 100:
        frequency = 'quarterly'
    else:
        frequency = 'irregular'
    
    # Subscription: regular time + fixed amount
    is_subscription = delta_sd <= 3.0 and amount_cv <= 0.1 and len(transactions) >= 2
    
    # Recurring habit: somewhat regular but variable
    is_recurring_habit = not is_subscription and avg_delta <= 35 and len(transactions) >= 3
    
    # Confidence score
    occ_score = min(len(transactions) / 12, 1.0)
    time_score = max(0, 1 - (delta_sd / 10))
    amount_score = max(0, 1 - (amount_cv / 0.5))
    confidence = occ_score * 0.4 + time_score * 0.3 + amount_score * 0.3
    
    # Next expected date
    next_expected = None
    if frequency != 'irregular' and dates:
        next_expected = (max(dates) + timedelta(days=avg_delta)).strftime('%Y-%m-%d')
    
    return {
        'is_subscription': is_subscription,
        'is_recurring_habit': is_recurring_habit,
        'frequency': frequency,
        'avg_amount': round(avg_amount, 2),
        'next_expected': next_expected,
        'confidence': round(confidence, 2)
    }


def _normalize_amount_to_monthly(amount: float, frequency: str) -> float:
    """Convert amount to monthly equivalent."""
    multipliers = {
        'weekly': 4.33, 'bi-weekly': 2.17, 'monthly': 1.0,
        'quarterly': 0.33, 'irregular': 1.0
    }
    return amount * multipliers.get(frequency, 1.0)


# ==================== MSME COMPLIANCE & FINANCIAL TOOLS ====================

# MSME Classification Limits (2025-26 Budget Update)
MSME_CLASSIFICATION = {
    "micro": {"investment_limit": 2_50_00_000, "turnover_limit": 10_00_00_000},
    "small": {"investment_limit": 25_00_00_000, "turnover_limit": 100_00_00_000},
    "medium": {"investment_limit": 125_00_00_000, "turnover_limit": 500_00_00_000},
}

# PMEGP Scheme Parameters
PMEGP_SCHEME = {
    "max_project_cost_manufacturing": 50_00_000,
    "max_project_cost_service": 20_00_000,
    "subsidy_general_urban": 0.15,
    "subsidy_general_rural": 0.25,
    "subsidy_special_urban": 0.25,
    "subsidy_special_rural": 0.35,
}

def check_pmegp_eligibility(
    project_cost: float,
    sector: str,
    location: str,
    category: str,
    is_existing_unit: bool = False,
) -> str:
    """Check eligibility for PMEGP scheme."""
    issues = []
    
    # Check project cost limit
    max_cost = PMEGP_SCHEME["max_project_cost_manufacturing"] if sector == "manufacturing" else PMEGP_SCHEME["max_project_cost_service"]
    if project_cost > max_cost:
        issues.append(f"Project cost ₹{project_cost/100000:.1f}L exceeds limit ₹{max_cost/100000:.0f}L for {sector}")
    
    if is_existing_unit:
        issues.append("PMEGP is only for new units, not existing businesses")
    
    # Calculate subsidy based on location and category
    if location.lower() == "rural":
        subsidy_rate = PMEGP_SCHEME["subsidy_special_rural"] if category.lower() == "special" else PMEGP_SCHEME["subsidy_general_rural"]
    else:
        subsidy_rate = PMEGP_SCHEME["subsidy_special_urban"] if category.lower() == "special" else PMEGP_SCHEME["subsidy_general_urban"]
    
    subsidy_amount = project_cost * subsidy_rate
    own_contribution = project_cost * (0.05 if category.lower() == "special" else 0.10)
    bank_loan = project_cost - subsidy_amount - own_contribution
    
    return json.dumps({
        "success": True,
        "eligible": len(issues) == 0,
        "issues": issues,
        "subsidy_rate": f"{subsidy_rate*100:.0f}%",
        "subsidy_amount": round(subsidy_amount, 2),
        "own_contribution": round(own_contribution, 2),
        "bank_loan_required": round(bank_loan, 2),
        "breakdown": {
            "project_cost": project_cost,
            "subsidy": subsidy_amount,
            "own_contribution": own_contribution,
            "bank_loan": bank_loan
        },
        "implementing_agency": "KVIC, KVIB, or DIC",
        "notes": [
            "Subsidy is credit-linked and released to bank",
            "Land cost cannot be included in project cost",
            "VIII pass required for projects > ₹10 Lakh",
            "Age: 18-45 years for new units"
        ]
    })


def check_standup_india_eligibility(
    loan_amount: float,
    applicant_category: str,
    is_greenfield: bool,
    sector: str,
) -> str:
    """Check eligibility for Stand-Up India scheme."""
    issues = []
    
    # Category validation
    valid_categories = ["sc", "st", "woman"]
    if applicant_category.lower() not in valid_categories:
        issues.append(f"Stand-Up India is only for SC/ST and Women entrepreneurs (got: {applicant_category})")
    
    if not is_greenfield:
        issues.append("Only greenfield (first-time) ventures are eligible")
    
    # Loan range check
    min_loan, max_loan = 10_00_000, 1_00_00_000
    if loan_amount < min_loan:
        issues.append(f"Minimum loan amount is ₹10 Lakh")
    if loan_amount > max_loan:
        issues.append(f"Maximum loan amount is ₹1 Crore")
    
    # Sector validation
    valid_sectors = ["manufacturing", "services", "agri-allied"]
    if sector.lower() not in valid_sectors:
        issues.append(f"Sector must be Manufacturing, Services, or Agri-allied (got: {sector})")
    
    return json.dumps({
        "success": True,
        "eligible": len(issues) == 0,
        "issues": issues,
        "loan_amount": loan_amount,
        "terms": {
            "repayment_period": "7 years",
            "moratorium": "18 months",
            "composite_loan": "Yes (term loan + working capital)",
            "margin_money": "Up to 25% from CGTMSE/NCGTC subsidy"
        },
        "eligibility_criteria": {
            "target_group": "SC/ST and Women entrepreneurs",
            "project_type": "Greenfield only",
            "sectors": ["Manufacturing", "Services", "Agri-allied"],
            "loan_range": "₹10 Lakh - ₹1 Crore"
        }
    })


def calculate_dscr(
    net_operating_income: float,
    annual_interest: float,
    annual_principal: float,
) -> str:
    """
    Calculate Debt Service Coverage Ratio.
    DSCR = Net Operating Income / (Interest + Principal)
    Banks typically require DSCR >= 1.5
    """
    total_debt_service = annual_interest + annual_principal
    
    if total_debt_service == 0:
        return json.dumps({
            "success": True,
            "dscr": "N/A",
            "status": "No debt obligations",
            "bankable": True,
            "message": "No debt service required"
        })
    
    dscr = net_operating_income / total_debt_service
    
    if dscr >= 2.0:
        status = "Excellent"
        recommendation = "Strong debt repayment capacity. Likely loan approval."
        bankable = True
    elif dscr >= 1.5:
        status = "Good"
        recommendation = "Meets typical bank requirements. Standard processing expected."
        bankable = True
    elif dscr >= 1.25:
        status = "Marginal"
        recommendation = "May require additional collateral or guarantor."
        bankable = True
    elif dscr >= 1.0:
        status = "Weak"
        recommendation = "High risk of rejection. Consider reducing loan amount."
        bankable = False
    else:
        status = "Critical"
        recommendation = "Insufficient cash flow. Loan unlikely to be approved."
        bankable = False
    
    return json.dumps({
        "success": True,
        "dscr": round(dscr, 2),
        "status": status,
        "bankable": bankable,
        "recommendation": recommendation,
        "calculation": {
            "net_operating_income": net_operating_income,
            "annual_interest": annual_interest,
            "annual_principal": annual_principal,
            "total_debt_service": total_debt_service
        },
        "bank_requirements": {
            "minimum_dscr": 1.5,
            "preferred_dscr": 2.0,
            "formula": "DSCR = Net Operating Income / (Interest + Principal)"
        }
    })


def calculate_tam_sam_som(
    total_potential_customers: int,
    average_revenue_per_user: float,
    geographic_accessibility_pct: float,
    feature_accessibility_pct: float,
    operational_capacity_pct: float,
    competitive_edge_pct: float,
) -> str:
    """
    Calculate TAM/SAM/SOM market sizing for DPR preparation.
    
    TAM = Total Addressable Market
    SAM = Serviceable Addressable Market  
    SOM = Serviceable Obtainable Market
    """
    # TAM = Total potential customers × ARPU
    tam = total_potential_customers * average_revenue_per_user
    
    # SAM = TAM × Geographic × Feature accessibility
    sam = tam * (geographic_accessibility_pct / 100) * (feature_accessibility_pct / 100)
    
    # SOM = SAM × Operational capacity × Competitive edge
    som = sam * (operational_capacity_pct / 100) * (competitive_edge_pct / 100)
    
    # Format for display
    def format_inr(value):
        if value >= 1_00_00_000:
            return f"₹{value/1_00_00_000:.2f} Cr"
        elif value >= 1_00_000:
            return f"₹{value/1_00_000:.2f} L"
        else:
            return f"₹{value:,.0f}"
    
    return json.dumps({
        "success": True,
        "market_sizing": {
            "TAM": {
                "value": round(tam, 2),
                "formatted": format_inr(tam),
                "description": "Total revenue if 100% market captured"
            },
            "SAM": {
                "value": round(sam, 2),
                "formatted": format_inr(sam),
                "description": "Segment reachable with current products/geography"
            },
            "SOM": {
                "value": round(som, 2),
                "formatted": format_inr(som),
                "description": "Realistic market share in short term (1-3 years)"
            }
        },
        "inputs": {
            "total_potential_customers": total_potential_customers,
            "average_revenue_per_user": average_revenue_per_user,
            "geographic_accessibility_pct": geographic_accessibility_pct,
            "feature_accessibility_pct": feature_accessibility_pct,
            "operational_capacity_pct": operational_capacity_pct,
            "competitive_edge_pct": competitive_edge_pct
        },
        "methodology": "Bottom-up calculation",
        "notes": [
            "TAM/SAM/SOM is required in Section 3 of bank DPR",
            "Use conservative SOM estimates (5-15% is typical)",
            "Back up with industry data and citations"
        ]
    })


# ==================== SOCRATIC BRAINSTORMING TOOLS ====================

import random as socratic_random

# Socratic Question Templates (6 Types)
SOCRATIC_TEMPLATES = {
    "clarification": [
        "What specific metrics define '{aspect}' in the context of your business?",
        "When you say '{aspect}', what exactly do you mean by that?",
        "Could you clarify what success looks like for '{aspect}'?",
        "How would you measure '{aspect}' in concrete terms?",
    ],
    "probing_assumptions": [
        "What evidence leads you to believe {aspect} will work?",
        "Have you considered what happens if your assumption about {aspect} is wrong?",
        "Why do you assume {aspect}? What's the basis for this?",
        "Is it possible that {aspect} is an industry myth rather than fact?",
    ],
    "probing_evidence": [
        "Why is {aspect} important to your business model?",
        "What's the root cause behind {aspect}?",
        "What data or research supports your claim about {aspect}?",
        "Can you trace {aspect} back to a fundamental customer need?",
    ],
    "viewpoints": [
        "How would a large-scale competitor respond to your approach on {aspect}?",
        "What would a skeptical investor ask about {aspect}?",
        "How might a potential customer view {aspect}?",
        "What would a bank loan officer think about {aspect}?",
    ],
    "implications": [
        "What are the financial ramifications if {aspect} fails?",
        "If {aspect} doesn't work, what's your Plan B?",
        "How would a 30-day disruption in {aspect} affect operations?",
        "What are the long-term implications of investing in {aspect}?",
    ],
    "meta": [
        "Why is it important to define {aspect} at this stage?",
        "Are we asking the right questions about {aspect}?",
        "What question haven't we asked about {aspect} that we should?",
        "How does clarifying {aspect} strengthen your DPR?",
    ],
}

# Session state
_brainstorm_session = {
    "active": False,
    "business_idea": "",
    "current_section": "market_analysis",
    "history": [],
    "covered_types": set(),
}

DPR_SECTIONS = ["market_analysis", "technical_viability", "financial_projections", "compliance", "risk_mitigation"]


def generate_socratic_question(
    business_idea: str,
    aspect: str,
    question_type: str = "clarification",
    current_section: str = "market_analysis",
) -> str:
    """Generate a Socratic question for brainstorming."""
    qtype = question_type.lower() if question_type else "clarification"
    templates = SOCRATIC_TEMPLATES.get(qtype, SOCRATIC_TEMPLATES["clarification"])
    
    template = socratic_random.choice(templates)
    question = template.format(aspect=aspect or business_idea[:50])
    
    # Track session
    _brainstorm_session["covered_types"].add(qtype)
    _brainstorm_session["history"].append({
        "type": qtype,
        "question": question,
        "section": current_section,
    })
    
    hints = {
        "clarification": ["Be specific with numbers and metrics", "Think about how this appears in your DPR"],
        "probing_assumptions": ["Consider if you have data to back this up", "Think about what industry reports say"],
        "probing_evidence": ["Cite sources if you have them", "Consider primary vs secondary research"],
        "viewpoints": ["Think from the bank's perspective", "Consider what competitors would do"],
        "implications": ["Calculate potential financial impact", "Think about contingency plans"],
        "meta": ["Reflect on the overall DPR structure", "Consider what sections need more depth"],
    }
    
    return json.dumps({
        "success": True,
        "question_type": qtype,
        "question": question,
        "hints": hints.get(qtype, []),
        "section": current_section,
    })


def start_brainstorming_session(business_idea: str, section: str = "market_analysis") -> str:
    """Start a structured Socratic brainstorming session."""
    _brainstorm_session["active"] = True
    _brainstorm_session["business_idea"] = business_idea
    _brainstorm_session["current_section"] = section
    _brainstorm_session["history"] = []
    _brainstorm_session["covered_types"] = set()
    
    # Generate initial clarification question
    initial_q = generate_socratic_question(
        business_idea=business_idea,
        aspect="your business idea",
        question_type="clarification",
        current_section=section,
    )
    initial_question = json.loads(initial_q)
    
    return json.dumps({
        "success": True,
        "session_started": True,
        "business_idea": business_idea,
        "current_section": section,
        "sections_to_cover": DPR_SECTIONS,
        "initial_question": initial_question,
        "guidance": "Let's explore your business idea systematically. I'll guide you through Socratic questioning for each DPR section.",
    })


def process_brainstorm_response(user_response: str, current_aspect: str) -> str:
    """Process user response and generate next Socratic question."""
    # Assess response quality
    word_count = len(user_response.split())
    has_numbers = any(char.isdigit() for char in user_response)
    has_reasoning = any(word in user_response.lower() for word in ["because", "since", "therefore", "as a result"])
    
    score = 0
    feedback = []
    
    if word_count < 10:
        feedback.append("Consider adding more detail to strengthen your DPR.")
    else:
        score += 25
    
    if has_numbers:
        score += 30
        feedback.append("Good use of specific data/numbers.")
    else:
        feedback.append("Adding specific metrics would strengthen your case.")
    
    if has_reasoning:
        score += 25
        feedback.append("Strong reasoning provided.")
    
    if word_count > 30:
        score += 20
    
    # Determine next question type
    all_types = set(SOCRATIC_TEMPLATES.keys())
    covered = _brainstorm_session.get("covered_types", set())
    uncovered = all_types - covered
    
    if not has_numbers:
        next_type = "probing_evidence"
    elif uncovered:
        next_type = socratic_random.choice(list(uncovered))
    else:
        next_type = socratic_random.choice(list(all_types))
    
    # Generate next question
    next_q = generate_socratic_question(
        business_idea=_brainstorm_session.get("business_idea", ""),
        aspect=current_aspect,
        question_type=next_type,
        current_section=_brainstorm_session.get("current_section", "market_analysis"),
    )
    
    return json.dumps({
        "success": True,
        "response_quality": {
            "score": min(score, 100),
            "word_count": word_count,
            "has_specifics": has_numbers,
            "feedback": feedback,
        },
        "next_question": json.loads(next_q),
        "covered_types": list(covered),
        "session_progress": len(_brainstorm_session.get("history", [])),
    })


# ==================== WHAT-IF SIMULATOR TOOLS ====================

# DSCR risk thresholds
DSCR_THRESHOLDS = {"LOW": 2.0, "MEDIUM": 1.5, "HIGH": 1.25}


def _calculate_dscr_internal(revenue: float, costs: float, interest: float, principal: float, tax_rate: float = 0.25) -> float:
    """Calculate DSCR from financial inputs."""
    ebitda = revenue - costs
    net_income = ebitda * (1 - tax_rate)
    debt_service = interest + principal
    return net_income / debt_service if debt_service > 0 else float('inf')


def _get_risk_level(dscr: float) -> str:
    """Get risk level based on DSCR."""
    if dscr >= DSCR_THRESHOLDS["LOW"]:
        return "LOW"
    elif dscr >= DSCR_THRESHOLDS["MEDIUM"]:
        return "MEDIUM"
    elif dscr >= DSCR_THRESHOLDS["HIGH"]:
        return "HIGH"
    return "CRITICAL"


def run_sensitivity_analysis(
    base_revenue: float,
    base_costs: float,
    loan_amount: float,
    interest_rate: float = 12.0,
    loan_tenure_years: int = 5,
    variation_pct: float = 20.0,
) -> str:
    """Run DSCR sensitivity analysis."""
    annual_interest = loan_amount * (interest_rate / 100)
    annual_principal = loan_amount / loan_tenure_years
    
    base_dscr = _calculate_dscr_internal(base_revenue, base_costs, annual_interest, annual_principal)
    
    results = {
        "base_case": {
            "dscr": round(base_dscr, 2),
            "risk_level": _get_risk_level(base_dscr),
            "revenue": base_revenue,
            "costs": base_costs,
            "annual_debt_service": annual_interest + annual_principal,
        },
        "sensitivity": {},
    }
    
    # Analyze each variable
    for var in ["revenue", "costs", "interest"]:
        sensitivity_data = []
        for pct in [-variation_pct, -variation_pct/2, 0, variation_pct/2, variation_pct]:
            factor = 1 + (pct / 100)
            
            if var == "revenue":
                test_rev, test_costs, test_int = base_revenue * factor, base_costs, annual_interest
            elif var == "costs":
                test_rev, test_costs, test_int = base_revenue, base_costs * factor, annual_interest
            else:
                test_rev, test_costs, test_int = base_revenue, base_costs, annual_interest * factor
            
            dscr = _calculate_dscr_internal(test_rev, test_costs, test_int, annual_principal)
            sensitivity_data.append({
                "variation_pct": pct,
                "dscr": round(dscr, 2),
                "risk_level": _get_risk_level(dscr),
                "bankable": dscr >= 1.5,
            })
        results["sensitivity"][var] = sensitivity_data
    
    # Break-even calculation
    target_dscr = 1.5
    target_ebitda = target_dscr * (annual_interest + annual_principal) / 0.75
    break_even_revenue = target_ebitda + base_costs
    
    results["break_even"] = {
        "minimum_revenue_for_dscr_1_5": round(break_even_revenue, 2),
        "margin_from_base": round(((base_revenue / break_even_revenue) - 1) * 100, 1) if break_even_revenue > 0 else 0,
    }
    
    return json.dumps({"success": True, **results})


def run_scenario_comparison(
    base_revenue: float,
    base_costs: float,
    loan_amount: float,
    interest_rate: float = 12.0,
    loan_tenure_years: int = 5,
) -> str:
    """Compare optimistic/base/conservative/worst case scenarios."""
    annual_interest = loan_amount * (interest_rate / 100)
    annual_principal = loan_amount / loan_tenure_years
    
    scenarios = {
        "optimistic": {"rev": 1.25, "cost": 0.90, "desc": "25% higher revenue, 10% lower costs"},
        "base": {"rev": 1.0, "cost": 1.0, "desc": "As per DPR projections"},
        "conservative": {"rev": 0.85, "cost": 1.10, "desc": "15% lower revenue, 10% higher costs"},
        "worst_case": {"rev": 0.70, "cost": 1.20, "desc": "30% lower revenue, 20% higher costs"},
    }
    
    results = {}
    for name, params in scenarios.items():
        revenue = base_revenue * params["rev"]
        costs = base_costs * params["cost"]
        dscr = _calculate_dscr_internal(revenue, costs, annual_interest, annual_principal)
        ebitda = revenue - costs
        
        results[name] = {
            "description": params["desc"],
            "revenue": round(revenue, 2),
            "costs": round(costs, 2),
            "ebitda": round(ebitda, 2),
            "net_margin_pct": round((ebitda / revenue) * 100, 1) if revenue > 0 else 0,
            "dscr": round(dscr, 2),
            "risk_level": _get_risk_level(dscr),
            "bankable": dscr >= 1.5,
        }
    
    return json.dumps({"success": True, "scenarios": results})


def run_cash_runway_analysis(
    initial_cash: float,
    monthly_revenue: float,
    monthly_costs: float,
    monthly_debt_service: float,
    growth_rate_pct: float = 5.0,
) -> str:
    """Analyze cash runway under normal and stress scenarios."""
    # Normal scenario
    cash = initial_cash
    normal_runway = 0
    cash_history = [cash]
    
    for month in range(1, 37):
        revenue = monthly_revenue * ((1 + growth_rate_pct/100) ** month)
        cash_flow = revenue - monthly_costs - monthly_debt_service
        cash += cash_flow
        cash_history.append(round(cash, 2))
        if cash > 0:
            normal_runway = month
        else:
            break
    
    # Stress scenario (50% revenue drop for 3 months)
    cash = initial_cash
    stress_runway = 0
    
    for month in range(1, 37):
        if month <= 3:
            revenue = monthly_revenue * 0.5
        else:
            revenue = monthly_revenue * ((1 + growth_rate_pct/100) ** (month - 3))
        cash_flow = revenue - monthly_costs - monthly_debt_service
        cash += cash_flow
        if cash > 0:
            stress_runway = month
        else:
            break
    
    # Recommendation
    if stress_runway >= 12:
        recommendation = "Strong cash position. Business can weather significant stress."
    elif stress_runway >= 6:
        recommendation = "Adequate buffer. Consider building 3 months additional reserves."
    elif stress_runway >= 3:
        recommendation = "Tight margins. Recommend increasing initial working capital."
    else:
        recommendation = "High risk. Working capital is insufficient for debt servicing."
    
    return json.dumps({
        "success": True,
        "normal_scenario": {
            "runway_months": normal_runway,
            "cash_history_first_12": cash_history[:13],
        },
        "stress_scenario": {
            "runway_months": stress_runway,
            "scenario": "50% revenue drop for first 3 months",
        },
        "recommendation": recommendation,
    })


# ==================== DPR GENERATOR TOOLS ====================

# DPR Section Structure (standardized banking format)
DPR_STRUCTURE = [
    "1. Executive Summary",
    "2. Promoter Profile & Background",
    "3. Business Description & Market Analysis",
    "4. Technical Aspects & Production Process",
    "5. Financial Projections",
    "6. Cost of Project & Means of Finance",
    "7. Profitability & Break-Even Analysis",
    "8. Risk Analysis & Mitigation",
    "9. Statutory Compliance & Approvals",
    "10. Annexures",
]


def generate_dpr(project_data: Dict[str, Any]) -> str:
    """Generate a DPR with section-by-section gating.
    Each section is only 'unlocked' when ALL its required fields are provided
    with real, non-empty, non-zero values.
    Returns section-level status so the AI knows which sections to ask about next.
    """
    
    # Each tuple: (data_key, title, required_fields_list)
    # A section is LOCKED if any required field is missing/empty/zero
    section_schema = [
        ("executive_summary", "1. Executive Summary", [
            "business_name", "nature_of_business", "msme_category",
            "project_cost", "loan_required",
        ]),
        ("promoter_profile", "2. Promoter Profile & Background", [
            "promoter_name", "qualification", "experience_years",
            "udyam_number", "pan",
        ]),
        ("market_analysis", "3. Business Description & Market Analysis", [
            "product_description", "target_market",
            "competitive_advantage", "pricing_strategy",
        ]),
        ("technical", "4. Technical Aspects & Production Process", [
            "process_description", "raw_materials",
            "plant_capacity", "manpower_required",
        ]),
        ("financial_projections", "5. Financial Projections", [
            "year_1", "year_2", "year_3",
        ]),
        ("cost_of_project", "6. Cost of Project & Means of Finance", [
            "total_project_cost", "term_loan",
            "promoter_contribution",
        ]),
        ("profitability", "7. Profitability & Break-Even Analysis", [
            "dscr", "break_even_revenue", "payback_period_years",
        ]),
        ("risk_analysis", "8. Risk Analysis & Mitigation", [
            "key_risks", "mitigation_strategies",
        ]),
        ("compliance", "9. Statutory Compliance & Approvals", [
            "udyam_registration", "gst_registration",
        ]),
    ]
    
    def _is_filled(value):
        """Check if a field has real, non-placeholder content."""
        if value is None:
            return False
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped or stripped in ("", "Pending", "N/A", "TBD", "UDYAM-XX-00-0000000", "0"):
                return False
            return True
        if isinstance(value, (int, float)):
            return value > 0
        if isinstance(value, dict):
            # For nested dicts (like year_1: {revenue: X, costs: Y}), 
            # at least one sub-field must have data
            return any(_is_filled(v) for v in value.values())
        if isinstance(value, list):
            return len(value) > 0
        return bool(value)
    
    dpr = {
        "metadata": {
            "generated_on": datetime.now().isoformat(),
            "version": "1.0",
            "format": "Standardized Banking Format (MSME)",
        },
        "unlocked_sections": [],
        "section_status": [],
    }
    
    total_sections = len(section_schema)
    unlocked_count = 0
    next_section_to_ask = None
    
    for key, title, required_fields in section_schema:
        section_content = project_data.get(key, {})
        if not isinstance(section_content, dict):
            section_content = {}
        
        # Check each required field
        filled = []
        missing = []
        for field in required_fields:
            if _is_filled(section_content.get(field)):
                filled.append(field)
            else:
                missing.append(field)
        
        is_unlocked = len(missing) == 0
        completeness = (len(filled) / len(required_fields) * 100) if required_fields else 100
        
        status_entry = {
            "section": title,
            "status": "✅ Unlocked" if is_unlocked else "🔒 Locked",
            "completeness_pct": round(completeness, 1),
            "filled_fields": filled,
            "missing_fields": missing,
        }
        dpr["section_status"].append(status_entry)
        
        if is_unlocked:
            unlocked_count += 1
            dpr["unlocked_sections"].append({
                "title": title,
                "content": section_content,
            })
        elif next_section_to_ask is None:
            # First locked section → this is what the AI should ask about next
            next_section_to_ask = {
                "section": title,
                "missing_fields": missing,
                "hint": f"Ask the user for: {', '.join(f.replace('_', ' ').title() for f in missing)}",
            }
    
    # Overall status
    overall_pct = (unlocked_count / total_sections * 100) if total_sections > 0 else 0
    dpr["metadata"]["overall_completeness_pct"] = round(overall_pct, 1)
    dpr["metadata"]["unlocked_count"] = unlocked_count
    dpr["metadata"]["total_sections"] = total_sections
    dpr["metadata"]["sections_structure"] = DPR_STRUCTURE
    
    if overall_pct >= 100:
        dpr["metadata"]["status"] = "✅ Ready for Submission"
    elif overall_pct >= 60:
        dpr["metadata"]["status"] = "🟡 Partially Complete — More sections needed"
    else:
        dpr["metadata"]["status"] = "🔒 Draft — Keep providing data to unlock sections"
    
    result = {"success": True, "dpr": dpr}
    
    if next_section_to_ask:
        result["next_section"] = next_section_to_ask
    
    return json.dumps(result)


def get_dpr_template() -> str:
    """Get empty DPR template with all required fields per section.
    Fields marked with * are REQUIRED to unlock that section.
    """
    template = {
        "executive_summary": {
            "business_name*": "", "nature_of_business*": "", "msme_category*": "Micro/Small/Medium",
            "project_cost*": 0, "loan_required*": 0,
            "promoter_contribution": 0, "expected_employment": 0,
            "projected_revenue_year1": 0,
        },
        "promoter_profile": {
            "promoter_name*": "", "qualification*": "", "experience_years*": 0,
            "udyam_number*": "", "pan*": "",
            "gst_number": "", "address": "",
        },
        "market_analysis": {
            "product_description*": "", "target_market*": "",
            "competitive_advantage*": "", "pricing_strategy*": "",
            "tam": 0, "sam": 0, "som": 0, "competitors": [],
        },
        "technical": {
            "process_description*": "", "raw_materials*": "",
            "plant_capacity*": "", "manpower_required*": 0,
            "technology_used": "", "quality_standards": "",
        },
        "financial_projections": {
            "year_1*": {"revenue": 0, "operating_costs": 0, "net_profit": 0},
            "year_2*": {"revenue": 0, "operating_costs": 0, "net_profit": 0},
            "year_3*": {"revenue": 0, "operating_costs": 0, "net_profit": 0},
            "year_4": {"revenue": 0, "operating_costs": 0, "net_profit": 0},
            "year_5": {"revenue": 0, "operating_costs": 0, "net_profit": 0},
            "growth_rate": 15,
        },
        "cost_of_project": {
            "total_project_cost*": 0, "term_loan*": 0, "promoter_contribution*": 0,
            "land_building": 0, "plant_machinery": 0, "furniture_fixtures": 0,
            "working_capital_margin": 0, "subsidy": 0,
        },
        "profitability": {
            "dscr*": 0, "break_even_revenue*": 0, "payback_period_years*": 0,
            "current_ratio": 0, "gross_profit_margin": 0, "net_profit_margin": 0,
        },
        "risk_analysis": {
            "key_risks*": [], "mitigation_strategies*": [],
            "insurance_coverage": "",
        },
        "compliance": {
            "udyam_registration*": "", "gst_registration*": "",
            "trade_license": "", "pollution_noc": "",
            "msme_schemes": ["PMEGP", "Stand-Up India", "Mudra", "ZED"],
        },
    }
    
    return json.dumps({
        "success": True,
        "template": template,
        "sections": DPR_STRUCTURE,
        "instructions": (
            "DPR sections are LOCKED by default. "
            "Each section unlocks only when ALL its required fields (* marked) have real data. "
            "Collect data from the user ONE SECTION AT A TIME. "
            "Call generate_dpr() with the collected data — it will show which sections are unlocked and which still need data."
        ),
    })


# ==================== DIRECT PDF PARSING ====================

MAX_PDF_PAGES = 5  # Maximum pages allowed for PDF parsing

def _get_pdf_page_count(file_path: str) -> int:
    """Get the number of pages in a PDF file using pypdf."""
    try:
        from pypdf import PdfReader
        reader = PdfReader(file_path)
        return len(reader.pages)
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
    """
    Parse bank statement from PDF using pypdf (pure Python).
    Simple and reliable - works on Android without native dependencies.
    """
    try:
        print(f"[PDF Parser] Parsing: {file_path}")
        
        # Check if file exists
        if not os.path.exists(file_path):
            return json.dumps({
                "success": False,
                "error": f"File not found: {file_path}"
            })
        
        text = ""
        
        # Use pypdf (pure Python, works on Android via Chaquopy)
        try:
            from pypdf import PdfReader
            print("[PDF Parser] Using pypdf...")
            
            reader = PdfReader(file_path)
            page_count = len(reader.pages)
            print(f"[PDF Parser] Found {page_count} page(s)")
            
            if page_count > 10:
                return json.dumps({
                    "success": False,
                    "error": f"PDF too large ({page_count} pages). Maximum 10 pages supported."
                })
            
            for i, page in enumerate(reader.pages):
                page_text = page.extract_text() or ""
                if page_text:
                    text += page_text + "\n\n"
                print(f"[PDF Parser] Page {i+1}: {len(page_text)} chars")
                
        except ImportError as ie:
            print(f"[PDF Parser] pypdf not available: {ie}")
            return json.dumps({
                "success": False,
                "error": "PDF parser not installed. Please reinstall the app."
            })
        except Exception as pdf_err:
            print(f"[PDF Parser] pypdf error: {pdf_err}")
            return json.dumps({
                "success": False,
                "error": f"Failed to read PDF: {str(pdf_err)}"
            })
        
        if not text.strip():
            return json.dumps({
                "success": False,
                "error": "PDF has no readable text. Try a different statement."
            })
        
        print(f"[PDF Parser] Extracted {len(text)} chars, parsing transactions...")
        # DEBUG DUMP: Print first 500 chars to help debug
        print(f"[PDF Parser] TEXT DUMP (first 500 chars): {text[:500]}")
        
        # Parse the extracted text for transactions
        return parse_bank_statement_text(text)
        
    except Exception as e:
        print(f"[PDF Parser] Error: {e}")
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
# Uses the global _zoho_creds set at top of file via set_config()
_zoho_access_token = None


# ==================== LLM CHAT ====================

# Credentials
# Removed set_api_key in favor of set_config, leaving stub if needed
def set_api_key(api_key: str) -> str:
    """Legacy: Set Sarvam API key."""
    return set_config(json.dumps({"sarvam_api_key": api_key}))



def search_msme_directory(state: str, district: str, limit: int = 10) -> str:
    """
    Search the Government of India UDYAM MSME directory.
    Uses data.gov.in API to find registered enterprises by State and District.
    """
    global _gov_msme_api_key
    
    try:
        api_key = _gov_msme_api_key or "579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b"
        limit = min(int(limit or 10), 10)
        
        # Build API URL with filters
        base_url = "https://api.data.gov.in/resource/8b68ae56-84cf-4728-a0a6-1be11028dea7"
        params = {
            "api-key": api_key,
            "format": "json",
            "limit": str(limit),
            "offset": "0",
            "filters[State]": state.upper().strip(),
            "filters[District]": district.upper().strip(),
        }
        
        query_string = urllib.parse.urlencode(params)
        url = f"{base_url}?{query_string}"
        
        # Make HTTPS request
        ctx = ssl.create_unverified_context()
        req = urllib.request.Request(url, headers={"User-Agent": "WealthIn/2.0"})
        
        with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        
        records = data.get("records", [])
        total = data.get("total", 0)
        
        if not records:
            return json.dumps({
                "success": True,
                "enterprises": [],
                "total": 0,
                "state": state.upper(),
                "district": district.upper(),
                "message": f"No registered MSMEs found in {district}, {state}. Try a different district or check the spelling."
            })
        
        # Parse and format enterprises
        enterprises = []
        for rec in records:
            # Parse activities JSON
            activities_raw = rec.get("Activities", "[]")
            services = []
            nic_codes = []
            try:
                activities = json.loads(activities_raw) if isinstance(activities_raw, str) else activities_raw
                if isinstance(activities, list):
                    for act in activities:
                        desc = act.get("Description", "")
                        nic = act.get("NicCode", act.get("Nic2Digit", ""))
                        if desc:
                            services.append(desc[:120] + ("..." if len(desc) > 120 else ""))
                        if nic:
                            nic_codes.append(str(nic))
            except:
                services = [activities_raw[:120] if activities_raw else "Not specified"]
            
            pincode = str(rec.get("Pincode", "")).replace(".0", "")
            mobile = rec.get("MobileNo", rec.get("Mobile", rec.get("ContactNo", "")))
            email = rec.get("Email", rec.get("EmailId", ""))
            msme_category = rec.get("MSMEDICategory", rec.get("Category", rec.get("EnterpriseType", "")))
            org_type = rec.get("OrganisationType", rec.get("TypeOfOrganisation", ""))
            
            enterprise = {
                "name": rec.get("EnterpriseName", "Unknown"),
                "state": rec.get("State", state.upper()),
                "district": rec.get("District", district.upper()),
                "address": rec.get("CommunicationAddress", "Not available"),
                "pincode": pincode,
                "services": services,
                "nic_codes": nic_codes,
                "registration_date": rec.get("RegistrationDate", ""),
                "contact": str(mobile) if mobile else "Not listed",
                "email": str(email) if email else "Not listed",
                "category": str(msme_category) if msme_category else "MSME",
                "organization_type": str(org_type) if org_type else "",
            }
            
            # Build a clean display text for the AI to format nicely
            svc_text = ", ".join(services[:3]) if services else "Various services"
            display = f"**{enterprise['name']}**\n"
            display += f"• Services: {svc_text}\n"
            display += f"• Address: {enterprise['address']}, {pincode}\n"
            if mobile and str(mobile) != "":
                display += f"• Contact: {mobile}\n"
            if email and str(email) != "":
                display += f"• Email: {email}\n"
            display += f"• Category: {enterprise['category']} | Registered: {enterprise['registration_date']}"
            enterprise["display_text"] = display
            
            enterprises.append(enterprise)
        
        return json.dumps({
            "success": True,
            "enterprises": enterprises,
            "total": total,
            "showing": len(enterprises),
            "state": state.upper(),
            "district": district.upper(),
            "source": "UDYAM Registration Portal, Ministry of MSME, Government of India",
            "message": f"Found {total:,} registered MSMEs in {district}, {state}. Showing top {len(enterprises)}."
        })
        
    except urllib.error.HTTPError as e:
        return json.dumps({
            "success": False,
            "error": f"Government API error: {e.code} - {e.reason}",
            "hint": "Check if the state/district names are correct and in UPPERCASE"
        })
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"MSME directory search failed: {str(e)}"
        })


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
    # === Deserialize JSON strings from Kotlin bridge ===
    # Kotlin passes conversation_history as JSON string (e.g., '[{"role":"user","content":"hi"}]')
    # and user_context as JSON string (e.g., '{"mode":"msme_copilot"}')
    if isinstance(conversation_history, str):
        try:
            conversation_history = json.loads(conversation_history)
            print(f"[chat_with_llm] Parsed conversation_history: {len(conversation_history)} items")
        except (json.JSONDecodeError, TypeError):
            conversation_history = None
    
    if isinstance(user_context, str):
        try:
            user_context = json.loads(user_context)
            print(f"[chat_with_llm] Parsed user_context: {list(user_context.keys()) if user_context else 'empty'}")
        except (json.JSONDecodeError, TypeError):
            user_context = None
    
    # Ensure proper types
    if not isinstance(conversation_history, list):
        conversation_history = None
    if not isinstance(user_context, dict):
        user_context = None
    
    # Use Groq for Ideas/Brainstorm (much faster via Groq LPU)
    groq_key = _groq_api_key
    # Fallback to Sarvam only if Groq key is missing
    sarvam_key = api_key or _sarvam_api_key
    
    if not groq_key and not sarvam_key:
        return json.dumps({
            "success": False,
            "error": "No API key configured.",
            "response": "I need an API key to respond. Please configure your Groq or Sarvam API key."
        })
    
    # Pick the LLM call function: Groq first, Sarvam fallback
    def _call_llm(msgs):
        if groq_key:
            result = _call_groq_llm(msgs, groq_key)
            if result:
                return result
            print("[LLM] Groq failed, trying Sarvam fallback")
        if sarvam_key:
            return _call_sarvam_llm(msgs, sarvam_key)
        return None
    
    # === FAST PATH: Simple conversational messages ===
    # Detect greetings, thanks, and short casual messages that don't need
    # the full ReAct loop / tool infrastructure. Single lightweight LLM call.
    lower_query = query.lower().strip()
    _GREETING_WORDS = {
        'hi', 'hello', 'hey', 'hii', 'hiii', 'yo', 'sup', 'hola',
        'namaste', 'namaskar', 'good morning', 'good afternoon',
        'good evening', 'good night', 'gm', 'gn',
    }
    _CASUAL_WORDS = {
        'thanks', 'thank you', 'thankyou', 'ok', 'okay', 'cool',
        'nice', 'great', 'awesome', 'bye', 'goodbye', 'see you',
        'got it', 'understood', 'sure', 'yes', 'no', 'nope', 'yep',
        'hmm', 'hm', 'ah', 'oh', 'lol', 'haha', 'wow',
    }
    is_casual = (
        lower_query in _GREETING_WORDS
        or lower_query in _CASUAL_WORDS
        or (len(lower_query) <= 12 and any(lower_query.startswith(g) for g in _GREETING_WORDS))
    )
    
    if is_casual:
        try:
            print(f"[FastPath] Casual message detected: '{query}'")
            fast_messages = [
                {
                    "role": "system",
                    "content": (
                        "You are WealthIn AI, a friendly financial advisor for Indian users. "
                        "Keep responses short (1-2 sentences). Be warm and conversational. "
                        "End with a helpful follow-up question about their finances."
                    )
                },
            ]
            # Include conversation history for continuity
            if conversation_history and isinstance(conversation_history, list):
                for msg in conversation_history[-10:]:  # Last 10 messages max
                    role = msg.get('role', 'user')
                    content = msg.get('content', '')[:300]  # Truncate long messages
                    if role in ('user', 'assistant') and content:
                        fast_messages.append({"role": role, "content": content})
            fast_messages.append({"role": "user", "content": query})
            fast_result = _call_llm(fast_messages)
            fast_text = (fast_result or {}).get('content', '')
            if fast_text:
                return json.dumps({
                    "success": True,
                    "response": fast_text.strip(),
                    "action_taken": False,
                    "action_type": None,
                    "action_data": {},
                    "needs_confirmation": False,
                    "tools_used": []
                })
        except Exception as fast_err:
            print(f"[FastPath] Error: {fast_err}, falling back to ReAct")
    
    # === ReAct Loop for ALL Queries ===
    try:
        # Detect if this is a brainstorm/Ideas mode call
        is_brainstorm = False
        if user_context and user_context.get('mode') in (
            'msme_copilot', 'strategic_planner', 'financial_architect',
            'execution_coach', 'market_research', 'financial_planner',
        ):
            is_brainstorm = True
        
        if is_brainstorm:
            # For Ideas/Brainstorm mode: the query already contains the full
            # MSME Copilot system prompt with detailed instructions.
            # Don't override it with the generic short-response ReAct prompt.
            tool_list = "\n".join([f"- **{t['name']}**: {t['description']}" for t in AVAILABLE_TOOLS])
            brainstorm_system = f"""You are WealthIn MSME Copilot — a friendly, patient, and deeply knowledgeable business mentor for Indian founders, especially first-time entrepreneurs.

## YOUR PERSONALITY
- Be a supportive mentor — explain things simply for first-time founders
- When you use a technical term, ALWAYS explain it: "DPR (Detailed Project Report — a document banks need to give you a loan)"
- Be warm, encouraging, and practical

## AVAILABLE TOOLS
{tool_list}

## HOW TO CALL A TOOL
Output ONLY this JSON when you need data:
```json
{{"tool_call": {{"name": "tool_name", "arguments": {{"param1": "value1"}}}}}}
```

## RESPONSE FORMATTING RULES (CRITICAL):

### ❌ NEVER USE MARKDOWN TABLES — they are unreadable on phones

### ✅ USE VISUAL ROADMAPS FOR STEPS:
🔵 **Step 1: [Title]**
[Simple explanation]
⬇️
🟢 **Step 2: [Title]**
[Simple explanation]
⬇️
🎯 **Final Goal: [Result]**

### ✅ USE COMPARISON CARDS (NOT TABLES):
> **💰 Option 1: Name**
> • Detail: Value
> • Detail: Value

### ✅ USE BULLET LISTS WITH EMOJIS
- Bold key numbers and names
- Keep sentences short (max 15 words)

### TONE
- Like a mentor over chai ☕
- Explain ALL jargon in parentheses
- End with **🎯 Next Steps** — 2-3 actions
- Use ₹ for Indian Rupees
"""
            messages = [{"role": "system", "content": brainstorm_system}]
            # Include conversation history for brainstorm continuity
            if conversation_history and isinstance(conversation_history, list):
                for msg in conversation_history[-10:]:
                    role = msg.get('role', 'user')
                    content = msg.get('content', '')[:500]
                    if role in ('user', 'assistant') and content:
                        messages.append({"role": role, "content": content})
            messages.append({"role": "user", "content": query})
            print(f"[ReAct] Brainstorm mode — {len(messages)} messages (incl. {len(conversation_history or [])} history)")
        else:
            system_prompt = _build_react_system_prompt(user_context)
            # Initialize conversation with system prompt
            messages = [{"role": "system", "content": system_prompt}]
            # Include conversation history so the AI has context of prior messages
            if conversation_history and isinstance(conversation_history, list):
                for msg in conversation_history[-10:]:  # Last 10 turns to stay within token limits
                    role = msg.get('role', 'user')
                    content = msg.get('content', '')[:300]  # Truncate long messages
                    if role in ('user', 'assistant') and content:
                        messages.append({"role": role, "content": content})
            messages.append({"role": "user", "content": query})
            print(f"[ReAct] Advisor mode — {len(messages)} messages (incl. {len(conversation_history or [])} history)")
        
        # ReAct loop - max 3 iterations (reduced to prevent long waits)
        MAX_ITERATIONS = 3
        all_tool_results = []
        final_response = None
        last_action_data = None
        
        for iteration in range(MAX_ITERATIONS):
            print(f"[ReAct] Iteration {iteration + 1}/{MAX_ITERATIONS}")
            
            try:
                # Call LLM (Groq primary, Sarvam fallback)
                llm_response = _call_llm(messages)
                
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
            # Fallback: If we have tool results but no formatted answer, usage that
            if all_tool_results:
                try:
                    last_res = all_tool_results[-1]['result']
                    final_response = json.dumps(last_res, indent=2)
                except:
                    final_response = "I completed the action but couldn't summarize it."
            else:
                final_response = "I couldn't process your request. Please try again with a different query."
        
        # Determine if action was taken
        action_taken = len(all_tool_results) > 0
        action_type = all_tool_results[-1]['tool'] if all_tool_results else None
        
        # For action tools (create_budget, etc.), extract the inner action_data
        # The tool result has: {action_type, action_data: {category, amount, ...}, requires_confirmation, ...}
        # We need to pass the INNER action_data to Flutter, not the full tool result
        resolved_action_data = last_action_data or {}
        resolved_action_type = action_type
        needs_confirmation = False
        
        if last_action_data and isinstance(last_action_data, dict):
            # If the tool explicitly returned action_type and action_data, use those
            if 'action_type' in last_action_data:
                resolved_action_type = last_action_data['action_type']
            if 'action_data' in last_action_data:
                resolved_action_data = last_action_data['action_data']
            needs_confirmation = last_action_data.get('requires_confirmation', False)
            
            # If there's a confirmation_message, use it as the response
            if needs_confirmation and last_action_data.get('confirmation_message'):
                final_response = last_action_data['confirmation_message']
        
        # Extract sources from search tool results for the Flutter Sources sheet
        sources = []
        for tr in all_tool_results:
            result_data = tr.get('result', {})
            if isinstance(result_data, dict) and 'results' in result_data:
                for item in result_data['results']:
                    if isinstance(item, dict) and (item.get('url') or item.get('link')):
                        sources.append({
                            'title': item.get('title', ''),
                            'url': item.get('url') or item.get('link', ''),
                            'snippet': item.get('snippet', item.get('description', '')),
                        })
        
        return json.dumps({
            "success": True,
            "response": final_response,
            "action_taken": action_taken,
            "action_type": resolved_action_type,
            "action_data": resolved_action_data,
            "needs_confirmation": needs_confirmation,
            "tools_used": [r['tool'] for r in all_tool_results],
            "sources": sources if sources else None,
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
        
        # Fallback: Use urllib with Sarvam multimodal chat API (FIXED - no /vision/analyze endpoint)
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
        
        # Encode image as base64 for multimodal chat
        image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        # Use Sarvam chat/completions with image_url (OpenAI-compatible multimodal)
        request_body = {
            "model": "sarvam-m",
            "messages": [
                {
                    "role": "system",
                    "content": """You are an expert receipt/document parser. Extract ALL financial details from this image.
Return a JSON object with these fields:
{
  "merchant_name": "store or merchant name",
  "date": "YYYY-MM-DD",
  "total_amount": 0.00,
  "currency": "INR",
  "category": "Food & Dining|Shopping|Transport|Utilities|Healthcare|Entertainment|Other",
  "items": [{"name": "item", "amount": 0.00}]
}
Return ONLY the JSON. No explanation."""
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{content_type};base64,{image_base64}"
                            }
                        },
                        {
                            "type": "text",
                            "text": "Extract receipt details from this image. Return ONLY JSON."
                        }
                    ]
                }
            ],
            "max_tokens": 2000,
            "temperature": 0.1
        }
        
        data = json.dumps(request_body).encode('utf-8')
        req = urllib.request.Request(
            "https://api.sarvam.ai/v1/chat/completions",
            data=data,
            headers={
                'Content-Type': 'application/json',
                'api-subscription-key': _sarvam_api_key,
                'User-Agent': 'WealthIn/1.0 (Android; Chaquopy)'
            },
            method='POST'
        )
        
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        with urllib.request.urlopen(req, timeout=60, context=context) as response:
            res = json.loads(response.read().decode('utf-8'))
            content = res.get('choices', [{}])[0].get('message', {}).get('content', '')
            
            print(f"[Sarvam Vision] Chat response: {content[:200]}...")
            
            # Try to parse as JSON first
            try:
                clean = content.strip()
                if clean.startswith("```json"):
                    clean = clean[7:]
                if clean.startswith("```"):
                    clean = clean[3:]
                if clean.endswith("```"):
                    clean = clean[:-3]
                clean = clean.strip()
                
                # Find JSON object
                start = clean.find('{')
                end = clean.rfind('}') + 1
                if start >= 0 and end > start:
                    parsed = json.loads(clean[start:end])
                    parsed["success"] = True
                    return json.dumps(parsed)
            except json.JSONDecodeError:
                pass
            
            # Fallback to text parsing
            return _parse_receipt_from_ocr(content, file_path)
            
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



def _call_groq_llm(messages: List[Dict[str, str]], api_key: str) -> Optional[Dict[str, Any]]:
    """Call Groq LLM (OpenAI-compatible) with model fallback chain.
    Tries multiple models in order: openai/gpt-oss-20b → llama-3.3-70b-versatile
    → llama-3.1-8b-instant → mixtral-8x7b-32768
    """
    import time
    
    # Model fallback chain — if primary fails (rate limit, unavailable), try next
    MODELS = [
        "openai/gpt-oss-20b",
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "mixtral-8x7b-32768",
    ]
    
    api_url = "https://api.groq.com/openai/v1/chat/completions"
    last_error = None
    
    for model in MODELS:
        try:
            print(f"[Groq] Trying model: {model}")
            request_body = {
                "model": model,
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
                    'Authorization': f'Bearer {api_key}',
                    'User-Agent': 'WealthIn/1.0 (Android; Chaquopy)'
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
                content = response_data['choices'][0]['message'].get('content', '')
                print(f"[Groq] Response received from {model} ({len(content)} chars)")
                return {"content": content, "model": model}
            
            print(f"[Groq] No choices from {model}: {json.dumps(response_data)[:200]}")
            continue  # Try next model
            
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8', errors='replace')[:500]
            print(f"[Groq] HTTP Error {e.code} for {model}: {error_body}")
            last_error = f"HTTP {e.code}: {error_body[:100]}"
            
            # Handle tool_use_failed: the model tried native tool calling
            # Extract the tool call from the error's failed_generation field
            if e.code == 400 and 'tool_use_failed' in error_body:
                try:
                    error_data = json.loads(error_body)
                    failed_gen = error_data.get('error', {}).get('failed_generation', '')
                    if failed_gen:
                        print(f"[Groq] Recovered tool call from failed_generation: {failed_gen[:200]}")
                        try:
                            tool_data = json.loads(failed_gen)
                            tool_call_json = json.dumps({"tool_call": tool_data})
                            return {"content": f"```json\n{tool_call_json}\n```", "model": model}
                        except json.JSONDecodeError:
                            return {"content": failed_gen, "model": model}
                except Exception as parse_err:
                    print(f"[Groq] Failed to parse error body: {parse_err}")
            
            # Rate limit (429) or server error (5xx) → wait briefly, try next model
            if e.code == 429:
                print(f"[Groq] Rate limited on {model}, waiting 2s before trying next model")
                time.sleep(2)
                continue
            elif e.code >= 500:
                print(f"[Groq] Server error on {model}, trying next model")
                continue
            elif e.code == 400:
                # Bad request but not tool_use — could be model-specific issue, try next
                print(f"[Groq] Bad request on {model}, trying next model")
                continue
            else:
                # 401 (auth), 403 (forbidden) etc — don't retry, key issue
                print(f"[Groq] Auth/permission error {e.code}, stopping retries")
                return None
                
        except Exception as e:
            print(f"[Groq] Error with {model}: {e}")
            last_error = str(e)
            continue  # Try next model
    
    print(f"[Groq] All models failed. Last error: {last_error}")
    return None


def _call_sarvam_llm(messages: List[Dict[str, str]], api_key: str) -> Optional[Dict[str, Any]]:
    """Call Sarvam LLM and return message content. (Fallback / non-Ideas usage)"""
    try:
        # Try SDK first
        if _HAS_SARVAM_SDK:
            try:
                client = SarvamAI(api_subscription_key=api_key)
                res = client.chat.completions(
                    model="sarvam-m",
                    messages=messages
                )
                print(f"[Sarvam] SDK response received")
                return {"content": res.choices[0].message.content, "model": "sarvam-m"}
            except Exception as sdk_e:
                print(f"[Sarvam] SDK error: {sdk_e}, trying urllib")
        
        # urllib fallback
        print(f"[Sarvam] Calling via urllib (key length: {len(api_key)})")
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
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'WealthIn/1.0 (Android; Chaquopy)'
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
            content = response_data['choices'][0]['message'].get('content', '')
            print(f"[Sarvam] Response received ({len(content)} chars)")
            return {"content": content, "model": "sarvam-m"}
        
        print(f"[Sarvam] No choices in response: {json.dumps(response_data)[:200]}")
        return None
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='replace')[:500]
        print(f"[Sarvam] HTTP Error {e.code}: {error_body}")
        return None
    except Exception as e:
        print(f"[Sarvam] LLM call error: {type(e).__name__}: {e}")
        return None


def _build_react_system_prompt(user_context: Dict[str, Any] = None) -> str:
    """Build system prompt for ReAct (Reasoning + Acting) loop.
    Exposes ALL available tools for maximum agent capability.
    """
    
    # Expose ALL tools for ReAct (not just the essentials)
    tool_list = "\n".join([f"- **{t['name']}**: {t['description']}" for t in AVAILABLE_TOOLS])
    
    # Extract financial advice from context if available
    financial_profile = ""
    if user_context and 'financial_profile' in str(user_context):
        financial_profile = str(user_context.get('financial_profile', ''))
    
    prompt = f"""You are WealthIn Business Planner — a strict, focused business financial planning assistant for Indian MSMEs and entrepreneurs.

## YOUR SCOPE (STRICTLY BUSINESS ONLY)
You ONLY help with:
✅ DPR (Detailed Project Report) drafting — section by section
✅ MSME/MUDRA/PMEGP/Stand-Up India scheme eligibility & applications
✅ Business loan calculations (EMI, DSCR, working capital)
✅ GST rates, compliance, invoicing queries
✅ Business cashflow planning & projections
✅ Break-even analysis & profitability calculations
✅ Business budgeting & cost optimization
✅ MSME directory search (finding registered enterprises)
✅ Business risk assessment & mitigation
✅ Market analysis & competitive positioning

## WHAT YOU DO NOT DO (POLITELY REDIRECT)
❌ Personal investment advice (SIP, mutual funds, stocks) → Say: "I'm your business planner! For personal investments, check the Analysis tab."
❌ Shopping or purchase advice → Say: "I focus on business planning. For purchase decisions, try the Analysis section."
❌ Career guidance or job search → Say: "I specialize in business planning. For career advice, try external job portals."
❌ General knowledge or trivia → Say: "I'm built for business planning — ask me about DPR, MSME schemes, or business financials!"
❌ Personal budgeting → Say: "I help with business budgets. For personal budgets, check the Budget section in the app."

If ANY message is outside your scope, respond with a SHORT one-liner redirect and suggest a relevant business topic instead.

## YOUR PERSONALITY
- Professional but approachable. Like a trusted CA/business consultant.
- ASK QUESTIONS before giving advice. Never assume the business type, scale, or financial details.
- Use Indian business context: MSME categories, Udyam registration, GST, TDS, DSCR, etc.

## ANTI-HALLUCINATION RULES (CRITICAL)
1. **NEVER make up numbers, interest rates, scheme criteria, or GST rates.** Use `web_search` to verify.
2. **For DPR drafts**: NEVER fill in fields with made-up data. Ask the user for every value.
3. **For govt schemes**: ALWAYS verify eligibility criteria using `web_search` — schemes change frequently.
4. **Always caveat**: "Verify this with your CA/chartered accountant before filing."

## YOUR TOOLS
{tool_list}

## HOW TO CALL A TOOL
Output ONLY this JSON when you need to search, calculate, or take action:
```json
{{"tool_call": {{"name": "tool_name", "arguments": {{"param1": "value1"}}}}}}
```

## DPR DRAFTING FLOW (SECTION-BY-SECTION UNLOCK)
When user wants to create a DPR:
1. FIRST ask: "Let's build your DPR step by step. Each section unlocks only when ALL its required fields are filled."
2. Start with **Section 1: Executive Summary** — ask for: business name, nature of business, MSME category, project cost, loan required.
3. When one section is complete, move to the NEXT locked section. Use the `next_section` hint from `generate_dpr` results.
4. **NEVER generate a DPR with empty/placeholder/made-up data.** Each section stays 🔒 LOCKED until the user provides real values.
5. After each user response, call `generate_dpr` with all data collected so far — it returns section-by-section status (✅ Unlocked / 🔒 Locked).
6. Show the user progress: "3/9 sections unlocked ✅ — next: Market Analysis"
7. For complex sections (Financial Projections, Profitability), help calculate values from raw numbers the user provides.

## BUSINESS ANALYSIS
You have access to the user's FINANCIAL PROFILE including spending trends. Use this to:

1. **Business expense patterns**: Identify business-related spending from transaction data
2. **Cashflow advice**: If the user runs a business, analyze their income vs expenses for cash runway
3. **Loan readiness**: Based on DSCR, savings rate, and debt ratio — advise on loan eligibility
4. **MSME scheme matching**: Proactively suggest relevant govt schemes based on business type and size
5. **Trend-Aware Advice**: Use the Notable Trends section:
   - **Recurring payments**: Identify business subscriptions (SaaS, rent, EMIs)
   - **Expense hikes**: Flag business cost increases and suggest optimization
   - **Top merchants**: Identify vendor concentration risk

## RESPONSE STYLE
1. **Keep responses SHORT**: 3-5 sentences max. Use • bullets for lists.
2. **Use ₹ for amounts**: Always in Indian Rupees.
3. **ALWAYS end with a business-relevant follow-up question**:
   - "What's your projected monthly revenue?"
   - "Do you have your Udyam registration number?"
   - "Shall I check your PMEGP/Mudra eligibility?"
4. **NEVER give responses longer than 5 lines without bullet points**

## CRITICAL RULES
1. **BUSINESS ONLY** — reject personal/non-business queries with a polite one-liner
2. **ASK before you ASSUME** — always clarify business details first
3. **Never hallucinate** — when in doubt, use `web_search`
4. Tool "query" parameter must be a SIMPLE search string
5. After tool results, give a BRIEF summary with key business insights

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
        
        print(f"[Parser] Detected bank: {bank_detected}")
        
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
        
        # Strategy 1: PhonePe multi-line block parsing
        # Format: Date -> Time -> DEBIT/CREDIT -> ₹Amount -> Description
        if bank_detected == "PHONEPE":
            print("[Parser] Using PhonePe multi-line block parser")
            i = 0
            while i < len(lines):
                line = lines[i].strip()
                
                # Look for date pattern to start a transaction block
                date_match = re.search(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s*(\d{4})', line, re.IGNORECASE)
                if date_match:
                    # Parse date
                    month = month_map.get(date_match.group(1).lower()[:3], '01')
                    day = date_match.group(2).zfill(2)
                    year = date_match.group(3)
                    tx_date = f"{year}-{month}-{day}"
                    
                    # Look ahead for DEBIT/CREDIT, amount, and description within next 6 lines
                    tx_type = None
                    tx_amount = None
                    tx_desc = None
                    
                    for j in range(i + 1, min(i + 7, len(lines))):
                        next_line = lines[j].strip()
                        
                        # Check for DEBIT/CREDIT
                        if next_line.upper() == 'DEBIT':
                            tx_type = 'expense'
                        elif next_line.upper() == 'CREDIT':
                            tx_type = 'income'
                        
                        # Check for amount (₹ followed by number)
                        if tx_amount is None:
                            amt_match = re.search(r'₹\s*([0-9,]+(?:\.\d{0,2})?)', next_line)
                            if amt_match:
                                try:
                                    tx_amount = float(amt_match.group(1).replace(',', ''))
                                except:
                                    pass
                        
                        # Check for description patterns (only after finding amount)
                        if tx_desc is None and tx_amount is not None:
                            # Get description from lines after amount
                            desc_patterns = [
                                (r'Paid to\s+(.+)', True),
                                (r'Received from\s+(.+)', True),
                                (r'Mobile recharged\s+(.+)', True),
                                (r'Bill Payment\s+(.+)', True),
                                (r'Added to wallet', False),
                                (r'DTH Recharge', False),
                                (r'Electricity bill', False),
                            ]
                            for dp, has_group in desc_patterns:
                                dm = re.search(dp, next_line, re.IGNORECASE)
                                if dm:
                                    tx_desc = dm.group(1).strip() if has_group and dm.lastindex else dm.group(0).strip()
                                    break
                            # If no pattern matched but line has meaningful text
                            if tx_desc is None and len(next_line) > 5:
                                skip_patterns = ['Transaction ID', 'UTR No', 'Paid by', 'Credited to', 
                                               'Reference', 'XXXX', 'Page', 'Date', 'Amount', 'Type',
                                               'support.phonepe', 'system generated']
                                if not any(sp.lower() in next_line.lower() for sp in skip_patterns):
                                    # Check if it's not just a time
                                    if not re.match(r'^\d{1,2}[f:]\d{2}\s*(am|pm)?$', next_line, re.IGNORECASE):
                                        tx_desc = next_line[:60]
                    
                    # Create transaction if we have enough info
                    if tx_type and tx_amount and tx_amount >= 1:
                        if tx_desc is None:
                            tx_desc = 'PhonePe Transaction'
                        
                        # Clean description
                        tx_desc = tx_desc.strip()[:60]
                        
                        # Get category
                        cat_result = json.loads(categorize_transaction(tx_desc, tx_amount))
                        
                        transactions.append({
                            'date': tx_date,
                            'description': tx_desc,
                            'amount': tx_amount,
                            'type': tx_type,
                            'category': cat_result.get('category', 'Other'),
                            'merchant': cat_result.get('merchant', tx_desc)
                        })
                
                i += 1
        
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

