"""
AI Tools Service - Agentic AI with Function Calling
Ported from wealthin_server Dart implementation
Enables the AI advisor to take actions: budgets, payments, goals, transactions

Primary LLM Providers:
1. Sarvam AI - For Indic language support (Hindi, Telugu, Tamil, etc.)
2. Zoho Catalyst QuickML - For general chat (Qwen 14B model)
"""

import json
import re
import logging
from typing import Dict, Any, List, Optional
from dataclasses import dataclass
from datetime import datetime
from pydantic import BaseModel

# Configure logger
logger = logging.getLogger(__name__)

# Import services
from .sarvam_service import sarvam_service
from .zoho_vision_service import zoho_vision_service
from .web_search_service import web_search_service

# Check which services are available
SARVAM_AVAILABLE = sarvam_service.is_configured
ZOHO_AVAILABLE = zoho_vision_service.is_configured
WEB_SEARCH_AVAILABLE = web_search_service.is_available

logger.info("AI Services Status:")
logger.info(f"  - Sarvam AI: {'✅' if SARVAM_AVAILABLE else '❌'}")
logger.info(f"  - Zoho Catalyst: {'✅' if ZOHO_AVAILABLE else '❌'}")


class AgentQueryRequest(BaseModel):
    user_id: str
    query: str
    context: Optional[Dict[str, Any]] = None


@dataclass
class AIToolResponse:
    """Response from AI tool processing"""
    response: str
    action_taken: bool
    action_type: Optional[str] = None
    action_data: Optional[Dict[str, Any]] = None
    needs_confirmation: bool = False
    error: Optional[str] = None


# Available tools/functions the AI can call
FINANCIAL_TOOLS = [
    {
        "name": "create_budget",
        "description": "Create a new budget category for the user. Use when user wants to set a spending limit for a category.",
        "parameters": {
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "description": "Budget category name (e.g., Food, Transport, Entertainment, Shopping, Bills)"
                },
                "amount": {
                    "type": "number",
                    "description": "Monthly budget amount in INR"
                },
                "period": {
                    "type": "string",
                    "enum": ["monthly", "weekly", "yearly"],
                    "description": "Budget period (default: monthly)"
                }
            },
            "required": ["category", "amount"]
        }
    },
    {
        "name": "create_savings_goal",
        "description": "Create a savings goal for the user. Use when user wants to save for something specific.",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Name of the savings goal (e.g., Emergency Fund, Vacation, New Phone)"
                },
                "target_amount": {
                    "type": "number",
                    "description": "Target amount to save in INR"
                },
                "target_date": {
                    "type": "string",
                    "description": "Target date to reach the goal (YYYY-MM-DD format)"
                },
                "current_amount": {
                    "type": "number",
                    "description": "Current saved amount (default: 0)"
                }
            },
            "required": ["name", "target_amount"]
        }
    },
    {
        "name": "schedule_payment",
        "description": "Schedule a recurring payment reminder. Use when user wants to set up bill reminders or track recurring expenses.",
        "parameters": {
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Payment name (e.g., Rent, Netflix, EMI, Electricity Bill)"
                },
                "amount": {
                    "type": "number",
                    "description": "Payment amount in INR"
                },
                "due_day": {
                    "type": "integer",
                    "description": "Day of month when payment is due (1-31)"
                },
                "frequency": {
                    "type": "string",
                    "enum": ["monthly", "weekly", "yearly", "once"],
                    "description": "Payment frequency"
                },
                "category": {
                    "type": "string",
                    "description": "Category of the payment"
                }
            },
            "required": ["name", "amount", "due_day"]
        }
    },
    {
        "name": "add_transaction",
        "description": "Add a new transaction (income or expense). Use when user mentions spending or earning money.",
        "parameters": {
            "type": "object",
            "properties": {
                "description": {
                    "type": "string",
                    "description": "Transaction description"
                },
                "amount": {
                    "type": "number",
                    "description": "Transaction amount in INR (positive number)"
                },
                "type": {
                    "type": "string",
                    "enum": ["income", "expense"],
                    "description": "Transaction type"
                },
                "category": {
                    "type": "string",
                    "description": "Transaction category (e.g., Food, Transport, Salary, Shopping)"
                },
                "date": {
                    "type": "string",
                    "description": "Transaction date (YYYY-MM-DD), defaults to today"
                }
            },
            "required": ["description", "amount", "type"]
        }
    },
    {
        "name": "get_spending_summary",
        "description": "Get spending summary and analysis for a period. Use when user asks about their spending patterns.",
        "parameters": {
            "type": "object",
            "properties": {
                "period": {
                    "type": "string",
                    "enum": ["today", "week", "month", "year"],
                    "description": "Time period for summary"
                },
                "category": {
                    "type": "string",
                    "description": "Optional category filter"
                }
            },
            "required": ["period"]
        }
    },
    {
        "name": "calculate_sip",
        "description": "Calculate SIP (Systematic Investment Plan) returns. Use when user asks about SIP investments or mutual funds.",
        "parameters": {
            "type": "object",
            "properties": {
                "monthly_investment": {
                    "type": "number",
                    "description": "Monthly SIP amount in INR"
                },
                "expected_rate": {
                    "type": "number",
                    "description": "Expected annual return rate in percentage (e.g., 12 for 12%)"
                },
                "duration_months": {
                    "type": "integer",
                    "description": "Investment duration in months"
                }
            },
            "required": ["monthly_investment", "expected_rate", "duration_months"]
        }
    },
    {
        "name": "calculate_emi",
        "description": "Calculate EMI (Equated Monthly Installment) for loans. Use when user asks about loan EMIs.",
        "parameters": {
            "type": "object",
            "properties": {
                "principal": {
                    "type": "number",
                    "description": "Loan principal amount in INR"
                },
                "rate": {
                    "type": "number",
                    "description": "Annual interest rate in percentage"
                },
                "tenure_months": {
                    "type": "integer",
                    "description": "Loan tenure in months"
                }
            },
            "required": ["principal", "rate", "tenure_months"]
        }
    },
    {
        "name": "get_tax_info",
        "description": "Get information about Indian income tax slabs, deductions, or GST. Use for tax-related queries.",
        "parameters": {
            "type": "object",
            "properties": {
                "query_type": {
                    "type": "string",
                    "enum": ["income_tax_slabs", "deductions_80c", "gst_rates", "advance_tax", "tds"],
                    "description": "Type of tax information needed"
                },
                "income": {
                    "type": "number",
                    "description": "Annual income in INR (optional, for tax calculation)"
                },
                "regime": {
                    "type": "string",
                    "enum": ["old", "new"],
                    "description": "Tax regime (old or new)"
                }
            },
            "required": ["query_type"]
        }
    },
    {
        "name": "web_search",
        "description": "Unified web search using DuckDuckGo. Use for any internet lookup: product prices, gold rates, FD rates, stock prices, news, hotel deals, reviews, comparisons, etc. Add context to your query for better results (e.g., 'iPhone 15 price Amazon India' or 'best hotels in Mumbai booking.com').",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query - be specific for better results"
                },
                "category": {
                    "type": "string",
                    "enum": ["general", "shopping", "news", "finance", "travel"],
                    "description": "Optional category hint to refine search results"
                }
            },
            "required": ["query"]
        }
    }
]

# System prompt for the AI advisor - Enhanced for Agentic Behavior
SYSTEM_PROMPT = """You are WealthIn AI, a powerful and intelligent financial advisor for Indian users.

You operate as a FULLY AGENTIC AI - you can think step-by-step, perform multiple searches, compare results, and validate information before responding.

You can help users with:
- Creating and managing budgets
- Setting savings goals
- Scheduling payment reminders
- Recording transactions (income/expenses)
- Getting spending analysis
- Calculating SIP returns and loan EMIs
- Tax information (Income Tax, GST)
- **Market Research & Price Comparison** (NEW - use search tools agentically!)

### AGENTIC SEARCH BEHAVIOR ###
When a user asks about products, prices, or market research:
1. **Multi-Step Search**: First search for the product, then search for reviews, then compare prices.
2. **Price Comparison**: Search on Amazon AND Flipkart, compare and present best deals.
3. **Validation**: Cross-reference information from multiple sources.
4. **Deep Research**: For investment queries, search for news, expert opinions, and historical data.

Example agentic flow for "Find best price for iPhone 15":
- Step 1: Call `web_search` with "iPhone 15 price Amazon India"
- Step 2: Call `web_search` with "iPhone 15 price Flipkart"
- Step 3: Call `web_search` with "iPhone 15 reviews"
- Step 4: Compare results and provide a comprehensive answer with recommendations.

### ACTION GUIDELINES ###
When a user's request requires taking an action (like creating a budget or adding a transaction), 
use the appropriate function. Always confirm important details before executing.

Guidelines:
- Use Indian Rupee (₹) for all amounts
- Be concise and helpful, but thorough for research queries
- For calculations, show the breakdown
- For tax queries, mention that this is general information and they should consult a CA for specific advice
- Be encouraging about good financial habits
- For shopping/product queries, always provide multiple options with prices and links

If the user just wants to chat or has a general question, respond conversationally without calling functions."""


class AIToolsService:
    """
    AI Tools Service - Enables agentic behavior with function calling.
    Uses OpenAI when available, falls back to Gemini with pattern matching.
    """
    
    # Patterns that indicate an action request
    ACTION_PATTERNS = [
        re.compile(r'\b(create|add|set|make|start)\s+(a\s+)?(budget|goal|savings|reminder|payment|transaction)', re.IGNORECASE),
        re.compile(r'\b(budget|save|track|record|schedule)\b.*\b(for|of)\s+\d+', re.IGNORECASE),
        re.compile(r'\b(spent|earned|paid|received)\s+.*₹?\d+', re.IGNORECASE),
        re.compile(r'\b(remind|schedule|setup)\s+(me\s+)?(about|for|to)', re.IGNORECASE),
        re.compile(r'₹\s*\d+.*\b(budget|goal|payment)', re.IGNORECASE),
        re.compile(r'\b(calculate|what.+if|how much)\s+.*(sip|emi|fd|rd|return)', re.IGNORECASE),
    ]
    
    # Patterns for extracting action data from natural language
    BUDGET_PATTERN = re.compile(r'budget.*?(?:of|for)?\s*₹?\s*(\d+[\d,]*)\s*(?:for|on)?\s*([a-zA-Z\s]+)?', re.IGNORECASE)
    GOAL_PATTERN = re.compile(r'(?:save|goal).*?₹?\s*(\d+[\d,]*)\s*(?:for|towards)?\s*([a-zA-Z\s]+)?', re.IGNORECASE)
    TRANSACTION_PATTERN = re.compile(r'(?:spent|paid|earned|received).*?₹?\s*(\d+[\d,]*)\s*(?:on|for|from)?\s*([a-zA-Z\s]+)?', re.IGNORECASE)
    SIP_PATTERN = re.compile(r'sip.*?₹?\s*(\d+[\d,]*)\s*.*?(\d+)\s*%.*?(\d+)\s*(?:years?|months?)?', re.IGNORECASE)
    EMI_PATTERN = re.compile(r'emi.*?₹?\s*(\d+[\d,]*)\s*.*?(\d+\.?\d*)\s*%.*?(\d+)\s*(?:years?|months?)?', re.IGNORECASE)
    
    def is_action_query(self, query: str) -> bool:
        """Check if query is requesting an action."""
        # If query contains math operators, let LLM handle it (don't force fast path)
        if any(op in query for op in ['+', '*', '/']):
            return False 
        return any(pattern.search(query) for pattern in self.ACTION_PATTERNS)
    
    def _extract_action_from_query(self, query: str) -> Optional[Dict[str, Any]]:
        """Extract action and parameters from natural language using regex."""
        query_lower = query.lower()
        
        # Check for budget creation
        if 'budget' in query_lower:
            match = self.BUDGET_PATTERN.search(query)
            if match:
                amount = float(match.group(1).replace(',', ''))
                category = (match.group(2) or 'General').strip()
                return {
                    "function": "create_budget",
                    "arguments": {"category": category, "amount": amount, "period": "monthly"}
                }
        
        # Check for goal creation
        if any(word in query_lower for word in ['save', 'goal', 'target']):
            match = self.GOAL_PATTERN.search(query)
            if match:
                amount = float(match.group(1).replace(',', ''))
                name = (match.group(2) or 'Savings Goal').strip()
                return {
                    "function": "create_savings_goal",
                    "arguments": {"name": name, "target_amount": amount}
                }
        
        # Check for transaction
        if any(word in query_lower for word in ['spent', 'paid', 'earned', 'received']):
            match = self.TRANSACTION_PATTERN.search(query)
            if match:
                amount = float(match.group(1).replace(',', ''))
                description = (match.group(2) or 'Transaction').strip()
                tx_type = 'income' if any(word in query_lower for word in ['earned', 'received']) else 'expense'
                return {
                    "function": "add_transaction",
                    "arguments": {"description": description, "amount": amount, "type": tx_type, "category": "General"}
                }
        
        # Check for SIP calculation
        if 'sip' in query_lower:
            match = self.SIP_PATTERN.search(query)
            if match:
                monthly = float(match.group(1).replace(',', ''))
                rate = float(match.group(2))
                duration = int(match.group(3))
                if 'year' in query_lower:
                    duration *= 12
                return {
                    "function": "calculate_sip",
                    "arguments": {"monthly_investment": monthly, "expected_rate": rate, "duration_months": duration}
                }
        
        # Check for EMI calculation
        if 'emi' in query_lower or 'loan' in query_lower:
            match = self.EMI_PATTERN.search(query)
            if match:
                principal = float(match.group(1).replace(',', ''))
                rate = float(match.group(2))
                tenure = int(match.group(3))
                if 'year' in query_lower:
                    tenure *= 12
                return {
                    "function": "calculate_emi",
                    "arguments": {"principal": principal, "rate": rate, "tenure_months": tenure}
                }
        
        return None
    
    async def _get_llm_response(self, query: str, system_prompt: str = "") -> str:
        """
        Get LLM response using available providers in priority order:
        1. Sarvam AI (for Indic languages or as primary)
        2. Zoho Catalyst QuickML (for general chat)
        """
        default_system_prompt = system_prompt or "You are a helpful financial advisor for Indian entrepreneurs. Be concise and practical. Use ₹ for amounts."
        
        # Check if query contains Indic script - use Sarvam
        if SARVAM_AVAILABLE and sarvam_service.is_indic_query(query):
            try:
                return await sarvam_service.simple_chat(query, default_system_prompt)
            except Exception as e:
                print(f"Sarvam error: {e}, falling back to Zoho")
        
        # Try Zoho Catalyst LLM
        if ZOHO_AVAILABLE:
            try:
                return await zoho_vision_service.llm_chat(
                    prompt=query,
                    system_prompt=default_system_prompt
                )
            except Exception as e:
                print(f"Zoho LLM error: {e}, trying Sarvam")
        
        # Fallback to Sarvam for English queries too
        if SARVAM_AVAILABLE:
            try:
                return await sarvam_service.simple_chat(query, default_system_prompt)
            except Exception as e:
                print(f"Sarvam fallback error: {e}")
        
        raise Exception("No LLM providers available. Please configure Sarvam AI or Zoho Catalyst.")
    
    async def _chat_response(self, query: str, user_context: Optional[Dict[str, Any]] = None) -> AIToolResponse:
        """Generate a chat response using available LLM providers."""
        try:
            # 1. Regex Pattern Matching (Fast Path)
            extracted = self._extract_action_from_query(query)
            if extracted:
                function_name = extracted["function"]
                arguments = extracted["arguments"]
                action_result = await self._execute_function(function_name, arguments)
                return AIToolResponse(
                    response=action_result["message"],
                    action_taken=True,
                    action_type=function_name,
                    action_data=action_result,
                    needs_confirmation=action_result.get("needs_confirmation", False)
                )
            
            # 2. LLM-based Reasoning (Agentic Loop)
            # Get user trends context
            trends_context = ""
            if user_context and user_context.get("user_id"):
                trends_context = await self._get_user_trends_context(user_context["user_id"])
            
            # Prepare tools for Sarvam SDK
            tools = [
                {
                    "type": "function",
                    "function": t
                } for t in FINANCIAL_TOOLS
            ]
            
            # Initialize conversation history
            messages = [
                {"role": "system", "content": SYSTEM_PROMPT + f"\n\n{trends_context}\n\nUser Context: {json.dumps(user_context) if user_context else 'None'}"},
                {"role": "user", "content": query}
            ]
            
            # AGENTIC LOOP (Max 5 iterations)
            final_response = None
            action_result = None
            
            for _ in range(5):
                # Call LLM with tools
                if SARVAM_AVAILABLE:
                    response_obj = sarvam_service.chat_completion(messages, tools=tools)
                else:
                    # Fallback to simple chat if Sarvam not available (should be handled upstream)
                    response_text = await self._get_llm_response(query, SYSTEM_PROMPT)
                    return AIToolResponse(response=response_text, action_taken=False)

                # Handle response
                response_message = None
                tool_calls = []
                
                # Parse response object (adapt based on SDK return type)
                if hasattr(response_obj, 'choices'):
                    choice = response_obj.choices[0]
                    response_message = choice.message
                    if hasattr(response_message, 'tool_calls') and response_message.tool_calls:
                        tool_calls = response_message.tool_calls
                    content = response_message.content
                elif isinstance(response_obj, dict): # Dict fallback
                    choice = response_obj.get("choices", [{}])[0]
                    msg_dict = choice.get("message", {})
                    content = msg_dict.get("content")
                    tool_calls_data = msg_dict.get("tool_calls", [])
                    # Convert dict tool calls to objects if needed or use as is
                    # For simplicity in this block, assuming object or dict access
                    tool_calls = tool_calls_data

                # If we have content, add to history
                # Note: We only add the message once (with tool_calls if present)
                
                # If no tool calls, this is the final answer
                if not tool_calls:
                    if content:
                        messages.append({"role": "assistant", "content": content})
                    final_response = content
                    break
                
                # Process tool calls - add assistant message with tool_calls
                messages.append({
                    "role": "assistant",
                    "content": content or "",
                    "tool_calls": tool_calls
                })
                
                # Execute each tool
                has_financial_action = False
                
                for tool_call in tool_calls:
                    # Handle object vs dict access
                    if isinstance(tool_call, dict):
                        func_name = tool_call.get("function", {}).get("name")
                        args_str = tool_call.get("function", {}).get("arguments")
                        call_id = tool_call.get("id")
                    else:
                        func_name = tool_call.function.name
                        args_str = tool_call.function.arguments
                        call_id = tool_call.id
                        
                    try:
                        func_args = json.loads(args_str)
                    except:
                        func_args = {}
                        
                    logger.info(f"Agent executing tool: {func_name}")
                    
                    # Execute tool
                    result = await self._execute_function(func_name, func_args)
                    
                    # Store result if it's a significant financial action
                    # (Not just search)
                    if not func_name.startswith("search_") and not func_name.startswith("web_"):
                        action_result = result
                        has_financial_action = True
                    
                    # Add tool output to history
                    messages.append({
                        "role": "tool",
                        "tool_call_id": call_id,
                        "name": func_name,
                        "content": json.dumps(result)
                    })
                
                # If we performed a financial action (like create budget), 
                # we might want to stop early or let the LLM confirm
                if has_financial_action and action_result:
                     # Check if we should stop. Usually LLM will summarize next.
                     pass

            return AIToolResponse(
                response=final_response or "I've completed the tasks.",
                action_taken=bool(action_result),
                action_type=action_result["action"] if action_result else None,
                action_data=action_result,
                needs_confirmation=action_result.get("needs_confirmation", False) if action_result else False
            )

        except Exception as e:
            logger.error(f"Chat response error: {e}")
            return AIToolResponse(
                response="I encountered an error while processing your request. Please try again.",
                action_taken=False
            )

    def _parse_tool_call(self, response_text: str) -> Optional[Dict[str, Any]]:
        """Attempt to parse a JSON tool call from LLM response."""
        try:
            # Clean up potential markdown wrappers
            clean_text = response_text.strip()
            if "```json" in clean_text:
                clean_text = clean_text.split("```json")[1].split("```")[0].strip()
            elif "```" in clean_text:
                clean_text = clean_text.split("```")[1].split("```")[0].strip()
            
            # Find JSON object pattern
            if clean_text.startswith('{') and clean_text.endswith('}'):
                data = json.loads(clean_text)
                if "tool" in data and "arguments" in data:
                    return data
            return None
        except Exception:
            return None
    async def _get_user_trends_context(self, user_id: str) -> str:
        """Get user's spending trends context for personalized AI responses."""
        try:
            from .trends_service import trends_service
            from .database_service import database_service
            
            # Fetch recent transactions
            transactions = await database_service.get_transactions(user_id, limit=200, offset=0)
            if not transactions:
                return "User Financial Context: No transaction history yet. Help them get started with tracking!"
            
            # Analyze trends
            tx_dicts = [t.__dict__ for t in transactions]
            trends = await trends_service.analyze_transactions(tx_dicts, user_id, period_days=30)
            
            return f"""User Financial Context:
{trends.ai_context}

Use this information to provide personalized, relevant advice. Reference specific patterns when applicable."""
        except Exception as e:
            print(f"Error getting trends context: {e}")
            return ""
    
    async def process_with_tools(
        self,
        query: str,
        user_context: Optional[Dict[str, Any]] = None
    ) -> AIToolResponse:
        """
        Process a query with tool/function calling capability.
        Uses Sarvam AI for Indic languages, Zoho Catalyst for general chat,
        with pattern-based action extraction for financial tools.
        """
        # Use our unified chat response method
        return await self._chat_response(query, user_context)
    
    async def _execute_function(
        self,
        function_name: str,
        arguments: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Execute a tool function and return the result."""
        
        if function_name == "create_budget":
            return await self._create_budget(arguments)
        elif function_name == "create_savings_goal":
            return await self._create_savings_goal(arguments)
        elif function_name == "schedule_payment":
            return await self._schedule_payment(arguments)
        elif function_name == "add_transaction":
            return await self._add_transaction(arguments)
        elif function_name == "get_spending_summary":
            return await self._get_spending_summary(arguments)
        elif function_name == "calculate_sip":
            return await self._calculate_sip(arguments)
        elif function_name == "calculate_emi":
            return await self._calculate_emi(arguments)
        elif function_name == "get_tax_info":
            return await self._get_tax_info(arguments)
        
        # Unified Web Search Tool
        elif function_name == "web_search":
            return await self._execute_search_tool(function_name, arguments)
            
        else:
            return {"success": False, "message": f"Unknown action: {function_name}"}
    
    # ==================== Tool Implementations ====================
    
    async def _create_budget(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Create a budget - returns data for Flutter to save locally."""
        category = args.get("category", "General")
        amount = args.get("amount", 0)
        period = args.get("period", "monthly")
        
        return {
            "success": True,
            "needs_confirmation": True,
            "action": "create_budget",
            "data": {
                "category": category,
                "amount": amount,
                "period": period,
                "created_at": datetime.now().isoformat()
            },
            "message": f"✅ I'll create a {period} budget of ₹{amount:,.0f} for **{category}**.\n\nWould you like me to proceed?"
        }
    
    async def _create_savings_goal(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Create a savings goal."""
        name = args.get("name", "Savings Goal")
        target_amount = args.get("target_amount", 0)
        target_date = args.get("target_date")
        current_amount = args.get("current_amount", 0)
        
        # Calculate monthly savings needed
        monthly_needed = None
        if target_date:
            from datetime import datetime
            try:
                target = datetime.fromisoformat(target_date)
                months_left = (target.year - datetime.now().year) * 12 + (target.month - datetime.now().month)
                if months_left > 0:
                    monthly_needed = (target_amount - current_amount) / months_left
            except ValueError:
                logger.warning(f"Invalid date format for target_date: {target_date}")
        
        message = f"🎯 I'll create a savings goal: **{name}**\n\n"
        message += f"• Target: ₹{target_amount:,.0f}\n"
        if current_amount > 0:
            message += f"• Current progress: ₹{current_amount:,.0f}\n"
        if target_date:
            message += f"• Target date: {target_date}\n"
        if monthly_needed:
            message += f"• Monthly savings needed: ₹{monthly_needed:,.0f}\n"
        message += "\nShall I create this goal?"
        
        return {
            "success": True,
            "needs_confirmation": True,
            "action": "create_savings_goal",
            "data": {
                "name": name,
                "target_amount": target_amount,
                "target_date": target_date,
                "current_amount": current_amount,
                "monthly_needed": monthly_needed,
                "created_at": datetime.now().isoformat()
            },
            "message": message
        }
    
    async def _schedule_payment(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Schedule a payment reminder."""
        name = args.get("name", "Payment")
        amount = args.get("amount", 0)
        due_day = args.get("due_day", 1)
        frequency = args.get("frequency", "monthly")
        category = args.get("category", "Bills")
        
        return {
            "success": True,
            "needs_confirmation": True,
            "action": "schedule_payment",
            "data": {
                "name": name,
                "amount": amount,
                "due_day": due_day,
                "frequency": frequency,
                "category": category,
                "created_at": datetime.now().isoformat()
            },
            "message": f"📅 I'll set up a {frequency} payment reminder:\n\n• **{name}**: ₹{amount:,.0f}\n• Due on day {due_day} of each month\n• Category: {category}\n\nConfirm to add this reminder?"
        }
    
    async def _add_transaction(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Add a transaction."""
        description = args.get("description", "Transaction")
        amount = args.get("amount", 0)
        tx_type = args.get("type", "expense")
        category = args.get("category", "General")
        date = args.get("date", datetime.now().strftime("%Y-%m-%d"))
        
        emoji = "💸" if tx_type == "expense" else "💰"
        type_label = "Expense" if tx_type == "expense" else "Income"
        
        return {
            "success": True,
            "needs_confirmation": True,
            "action": "add_transaction",
            "data": {
                "description": description,
                "amount": amount,
                "type": tx_type,
                "category": category,
                "date": date,
                "created_at": datetime.now().isoformat()
            },
            "message": f"{emoji} Recording {type_label.lower()}:\n\n• **{description}**\n• Amount: ₹{amount:,.0f}\n• Category: {category}\n• Date: {date}\n\nAdd this transaction?"
        }
    
    async def _get_spending_summary(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Get spending summary - will need Flutter to provide data."""
        period = args.get("period", "month")
        category = args.get("category")
        
        # This returns a request for Flutter to provide the data
        return {
            "success": True,
            "needs_confirmation": False,
            "action": "get_spending_summary",
            "requires_data": True,
            "data": {
                "period": period,
                "category": category
            },
            "message": f"📊 Let me analyze your {period}ly spending{' for ' + category if category else ''}...\n\n*Please ensure your transactions are synced for accurate analysis.*"
        }
    
    async def _calculate_sip(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate SIP returns."""
        monthly = args.get("monthly_investment", 0)
        rate = args.get("expected_rate", 12)
        months = args.get("duration_months", 12)
        
        # SIP Formula: FV = P × ((1+r)^n - 1) / r × (1+r)
        monthly_rate = rate / 12 / 100
        if monthly_rate == 0:
            future_value = monthly * months
        else:
            future_value = monthly * (((1 + monthly_rate) ** months - 1) / monthly_rate) * (1 + monthly_rate)
        
        total_invested = monthly * months
        wealth_gained = future_value - total_invested
        years = months / 12
        
        return {
            "success": True,
            "needs_confirmation": False,
            "action": "calculate_sip",
            "data": {
                "monthly_investment": monthly,
                "expected_rate": rate,
                "duration_months": months,
                "total_invested": round(total_invested, 2),
                "future_value": round(future_value, 2),
                "wealth_gained": round(wealth_gained, 2)
            },
            "message": f"📈 **SIP Calculation**\n\n"
                      f"• Monthly Investment: ₹{monthly:,.0f}\n"
                      f"• Duration: {years:.1f} years ({months} months)\n"
                      f"• Expected Return: {rate}% p.a.\n\n"
                      f"**Results:**\n"
                      f"• Total Invested: ₹{total_invested:,.0f}\n"
                      f"• Future Value: ₹{future_value:,.0f}\n"
                      f"• Wealth Gained: ₹{wealth_gained:,.0f} ({(wealth_gained/total_invested*100):.1f}%)\n\n"
                      f"💡 *Start early to benefit from compounding!*"
        }
    
    async def _calculate_emi(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate loan EMI."""
        principal = args.get("principal", 0)
        rate = args.get("rate", 10)
        months = args.get("tenure_months", 12)
        
        # EMI Formula: EMI = P × r × (1+r)^n / ((1+r)^n - 1)
        monthly_rate = rate / 12 / 100
        if monthly_rate == 0:
            emi = principal / months
        else:
            emi = principal * monthly_rate * ((1 + monthly_rate) ** months) / (((1 + monthly_rate) ** months) - 1)
        
        total_payment = emi * months
        total_interest = total_payment - principal
        
        return {
            "success": True,
            "needs_confirmation": False,
            "action": "calculate_emi",
            "data": {
                "principal": principal,
                "rate": rate,
                "tenure_months": months,
                "emi": round(emi, 2),
                "total_payment": round(total_payment, 2),
                "total_interest": round(total_interest, 2)
            },
            "message": f"🏦 **EMI Calculation**\n\n"
                      f"• Loan Amount: ₹{principal:,.0f}\n"
                      f"• Interest Rate: {rate}% p.a.\n"
                      f"• Tenure: {months} months ({months/12:.1f} years)\n\n"
                      f"**Results:**\n"
                      f"• Monthly EMI: ₹{emi:,.0f}\n"
                      f"• Total Interest: ₹{total_interest:,.0f}\n"
                      f"• Total Payment: ₹{total_payment:,.0f}\n\n"
                      f"💡 *Consider prepayment to reduce interest burden.*"
        }
    
    async def _get_tax_info(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Get tax information."""
        query_type = args.get("query_type", "income_tax_slabs")
        income = args.get("income")
        regime = args.get("regime", "new")
        
        if query_type == "income_tax_slabs":
            if regime == "new":
                message = """📋 **New Tax Regime (FY 2024-25)**

| Income Slab | Tax Rate |
|-------------|----------|
| Up to ₹3,00,000 | Nil |
| ₹3,00,001 - ₹7,00,000 | 5% |
| ₹7,00,001 - ₹10,00,000 | 10% |
| ₹10,00,001 - ₹12,00,000 | 15% |
| ₹12,00,001 - ₹15,00,000 | 20% |
| Above ₹15,00,000 | 30% |

✅ Standard deduction of ₹75,000 available
❌ No other deductions (80C, HRA, etc.)"""
            else:
                message = """📋 **Old Tax Regime (FY 2024-25)**

| Income Slab | Tax Rate |
|-------------|----------|
| Up to ₹2,50,000 | Nil |
| ₹2,50,001 - ₹5,00,000 | 5% |
| ₹5,00,001 - ₹10,00,000 | 20% |
| Above ₹10,00,000 | 30% |

✅ Deductions available: 80C, 80D, HRA, LTA, etc.
✅ Standard deduction of ₹50,000"""
        
        elif query_type == "deductions_80c":
            message = """📋 **Section 80C Deductions (Max ₹1,50,000)**

Popular options:
• **PPF** - 15 year lock-in, tax-free returns
• **ELSS** - 3 year lock-in, equity exposure
• **NSC** - 5 year, fixed returns
• **Tax-saving FD** - 5 year lock-in
• **Life Insurance Premium**
• **Children's Tuition Fees**
• **Home Loan Principal**
• **EPF/VPF** - Employee contribution

💡 *ELSS offers shortest lock-in with market-linked returns*"""
        
        elif query_type == "gst_rates":
            message = """📋 **GST Rate Structure**

| Category | Rate |
|----------|------|
| Essential items (food grains, milk) | 0% |
| Basic necessities | 5% |
| Standard goods | 12% |
| Most goods & services | 18% |
| Luxury items, sin goods | 28% |

🔹 Composition scheme: 1-6% (for small businesses)
🔹 Input tax credit available for registered businesses"""
        
        else:
            message = "Please specify what tax information you need: income_tax_slabs, deductions_80c, gst_rates, advance_tax, or tds."
        
        message += "\n\n⚠️ *This is general information. Please consult a Chartered Accountant for personalized tax advice.*"
        
        return {
            "success": True,
            "needs_confirmation": False,
            "action": "get_tax_info",
            "data": {
                "query_type": query_type,
                "regime": regime
            },
            "message": message
        }
    
    async def _execute_search_tool(self, tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute search-related tools using DuckDuckGo (privacy-respecting, free)."""
        from .web_search_service import web_search_service
        from dataclasses import asdict
        
        query = args.get("query", "")
        if not query:
            return {"success": False, "message": "Query cannot be empty."}
        
        if not web_search_service.is_available:
            return {"success": False, "message": "Web search is not available. Please install duckduckgo-search."}
        
        try:
            # Use the optional category hint from arguments, or default to "general"
            category = arguments.get("category", "general")
            
            # Execute the search using DuckDuckGo
            results = await web_search_service.search_finance_news(
                query, 
                limit=5, 
                category=category
            )
            
            if not results:
                return {
                    "success": True,
                    "needs_confirmation": False,
                    "action": tool_name,
                    "data": [],
                    "message": f"No results found for '{query}'. Try a different search term."
                }
            
            # Format results for the LLM to process
            formatted_results = []
            for r in results:
                item = {
                    "title": r.title,
                    "url": r.url,
                    "snippet": r.snippet,
                    "source": r.source,
                }
                if r.price:
                    item["price"] = r.price
                    item["price_display"] = r.price_display
                if r.date:
                    item["date"] = r.date
                formatted_results.append(item)
            
            # Build a user-friendly message
            message_lines = [f"🔍 **Search Results for '{query}':**\n"]
            for i, r in enumerate(results[:5], 1):
                price_str = f" - {r.price_display}" if r.price_display else ""
                message_lines.append(f"{i}. **{r.title}**{price_str}")
                message_lines.append(f"   {r.snippet[:100]}...")
                message_lines.append(f"   [View]({r.url})\n")
            
            return {
                "success": True,
                "needs_confirmation": False,
                "action": tool_name,
                "data": formatted_results,
                "message": "\n".join(message_lines)
            }
            
        except Exception as e:
            logger.error(f"Search error: {e}")
            return {"success": False, "message": f"Search error: {str(e)}"}

    async def generate_daily_insight(self, user_id: str) -> Dict[str, Any]:
        """
        Generate a daily financial insight for the user.
        Connects to the 'FinBite' card in the Flutter app.
        """
        try:
            from .trends_service import trends_service
            from .database_service import database_service
            
            # Fetch recent transactions to see what's happening
            transactions = await database_service.get_transactions(user_id, limit=50, offset=0)
            
            if not transactions:
                return {
                    "headline": "Welcome to WealthIn! 🚀",
                    "insightText": "Start your financial journey by adding your first transaction.",
                    "recommendation": "Try scanning a receipt or adding an expense manually.",
                    "trendIndicator": "stable"
                }

            # Analyze trends for the last 30 days
            tx_dicts = [t.__dict__ for t in transactions]
            trends = await trends_service.analyze_transactions(tx_dicts, user_id, period_days=30)
            
            # Use LLM to generate a snappy insight based on trends
            prompt = f"""
            Analyze this 30-day financial summary for a user and generate a 'Daily Insight' card content.
            
            Context:
            - Total Spent: ₹{trends.total_spent}
            - Income: ₹{trends.total_income}
            - Savings Rate: {trends.savings_rate}%
            - Top Category: {trends.top_spending_category}
            - Recent Activity: {len(transactions)} transactions
            
            Output strictly as a JSON object with these keys:
            - headline: Short, catchy title (max 5 words)
            - insightText: The main observation (max 2 sentences)
            - recommendation: Actionable advice (max 1 sentence)
            - trendIndicator: "up", "down", or "stable" (based on savings/health)
            
            Example:
            {{
                "headline": "Spending Spike Detected ⚠️",
                "insightText": "Your food expenses are 20% higher this week.",
                "recommendation": "try cooking at home this weekend to save.",
                "trendIndicator": "down"
            }}
            """
            
            # We use the _get_llm_response method which handles Sarvam/Zoho fallback
            response_json = await self._get_llm_response(prompt, "You are a financial data analyst. return only valid JSON.")
            
            # Parse the JSON
            parsed = self._parse_tool_call(response_json) # Reuse parse logic which handles markdown code blocks
            
            if parsed and "headline" in parsed:
                return parsed
                
            # Fallback if specific keys aren't found but JSON was valid
            if parsed:
                 return {
                    "headline": parsed.get("headline", "Financial Update"),
                    "insightText": parsed.get("insightText", "Review your recent transactions to stay on track."),
                    "recommendation": parsed.get("recommendation", "Check your budget status."),
                    "trendIndicator": parsed.get("trendIndicator", "stable")
                }

            # Fallback if parsing failed completely
            return {
                "headline": "Spending Insight",
                "insightText": f"You've spent ₹{trends.total_spent:,.0f} in the last 30 days.",
                "recommendation": f"Your top category is {trends.top_spending_category}. Watch it!",
                "trendIndicator": "stable"
            }
            
        except Exception as e:
            logger.error(f"Error generating insight: {e}")
            return {
                "headline": "Stay on Track",
                "insightText": "Consistency is key to financial freedom.",
                "recommendation": "Check your goals today.",
                "trendIndicator": "stable"
            }


# Singleton instance
ai_tools_service = AIToolsService()
# Alias for compatibility
ai_agent_service = ai_tools_service
