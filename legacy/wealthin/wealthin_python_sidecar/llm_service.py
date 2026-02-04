"""
LLM Service - Sarvam AI Integration
WealthIn Financial Advisor powered by Sarvam AI
"""
import json
import httpx
from typing import Dict, Any, List


class LLMService:
    """Sarvam AI LLM Service for WealthIn"""
    
    # Sarvam AI API Configuration
    SARVAM_API_KEY = "sk_vqh8cfif_MWrqmgK4dyzLoIOqxJn8udIc"
    SARVAM_API_URL = "https://api.sarvam.ai/v1/chat/completions"
    SARVAM_MODEL = "sarvam-m"  # Sarvam's main model
    
    def __init__(self):
        self.provider = 'sarvam'
        print(f"[LLM] Initialized with Sarvam AI")
    
    def get_status(self) -> Dict[str, Any]:
        """Get LLM service status"""
        return {
            'active_provider': 'sarvam',
            'model': self.SARVAM_MODEL,
            'available_providers': {
                'sarvam': True,
            }
        }
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        system_prompt: str = None,
        temperature: float = 0.7,
        max_tokens: int = 2048
    ) -> str:
        """Send chat completion request to Sarvam AI"""
        return await self._sarvam_chat(messages, system_prompt, temperature, max_tokens)
    
    async def _sarvam_chat(
        self,
        messages: List[Dict[str, str]],
        system_prompt: str,
        temperature: float,
        max_tokens: int = 2048
    ) -> str:
        """Chat with Sarvam AI"""
        try:
            # Build messages for Sarvam API
            api_messages = []
            if system_prompt:
                api_messages.append({"role": "system", "content": system_prompt})
            api_messages.extend(messages)
            
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    self.SARVAM_API_URL,
                    headers={
                        "Authorization": f"Bearer {self.SARVAM_API_KEY}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.SARVAM_MODEL,
                        "messages": api_messages,
                        "temperature": temperature,
                        "max_tokens": max_tokens
                    }
                )
                
                if response.status_code == 200:
                    data = response.json()
                    return data['choices'][0]['message']['content']
                else:
                    error_msg = f"Sarvam AI Error: {response.status_code}"
                    try:
                        error_data = response.json()
                        error_msg += f" - {error_data.get('error', {}).get('message', response.text)}"
                    except:
                        error_msg += f" - {response.text}"
                    print(f"[Sarvam] {error_msg}")
                    return f"I'm experiencing a temporary issue. Please try again. ({error_msg})"
                    
        except httpx.TimeoutException:
            print("[Sarvam] Request timeout")
            return "The request took too long. Please try again."
        except httpx.ConnectError:
            print("[Sarvam] Connection error")
            return "Unable to connect to AI service. Please check your internet connection."
        except Exception as e:
            print(f"[Sarvam] Exception: {e}")
            return f"An error occurred: {str(e)}"

    def get_financial_advisor_prompt(self, user_context: Dict[str, Any]) -> str:
        """Generate system prompt for financial advisor with user context"""
        
        context_parts = []
        
        if user_context.get('monthly_income'):
            context_parts.append(f"- Monthly Income: ₹{user_context['monthly_income']:,.0f}")
        
        if user_context.get('monthly_expense'):
            context_parts.append(f"- Monthly Expenses: ₹{user_context['monthly_expense']:,.0f}")
        
        if user_context.get('savings_rate'):
            context_parts.append(f"- Savings Rate: {user_context['savings_rate']:.1f}%")
        
        if user_context.get('top_expense_category'):
            context_parts.append(f"- Top Spending Category: {user_context['top_expense_category']}")
        
        if user_context.get('active_goals'):
            goals = [g['name'] for g in user_context['active_goals'][:3]]
            context_parts.append(f"- Active Goals: {', '.join(goals)}")
        
        if user_context.get('budgets'):
            budgets = [f"{b['category']}: ₹{b['amount']:,.0f}" for b in user_context['budgets'][:3]]
            context_parts.append(f"- Budgets: {', '.join(budgets)}")
        
        context_text = '\n'.join(context_parts) if context_parts else "No financial data available yet."
        
        return f"""You are WealthIn AI, a professional financial advisor for Indian users. Provide personalized, actionable advice.

USER'S FINANCIAL CONTEXT:
{context_text}

GUIDELINES:
1. Be concise and professional
2. Use Indian Rupee (₹) for all amounts
3. Reference actual user data when available
4. Suggest importing bank statements for better insights
5. Help with: budgeting, savings, expense tracking, investments, debt management
6. Support both English and Hindi responses based on user's language

Keep responses helpful, encouraging, and focused on improving financial health."""


# Global instance
llm_service = LLMService()


# ==================== AGENTIC FUNCTIONS ====================

FINANCIAL_TOOLS = [
    {
        "name": "create_budget",
        "description": "Create or update a budget for a spending category",
        "parameters": {
            "category": "string - Category name",
            "amount": "number - Monthly limit in INR",
            "name": "string - Optional budget name"
        }
    },
    {
        "name": "create_savings_goal", 
        "description": "Set a new savings target",
        "parameters": {
            "name": "string - Goal name",
            "target_amount": "number - Target amount in INR",
            "deadline": "string - Optional target date"
        }
    },
    {
        "name": "analyze_spending",
        "description": "Analyze spending patterns in a category",
        "parameters": {
            "category": "string - Category to analyze",
            "period": "string - weekly/monthly/quarterly"
        }
    },
    {
        "name": "calculate_investment",
        "description": "Calculate investment returns",
        "parameters": {
            "type": "string - sip/fd/rd/emi",
            "amount": "number - Investment amount",
            "rate": "number - Expected return rate %",
            "duration": "number - Duration in months"
        }
    }
]


async def process_with_tools(
    query: str,
    user_context: Dict[str, Any],
    user_id: str
) -> Dict[str, Any]:
    """Process a query with potential tool execution"""
    
    tools_text = json.dumps(FINANCIAL_TOOLS, indent=2)
    
    tool_prompt = f"""Analyze the user's query and respond appropriately.

If the user wants to perform an action, respond with JSON:
{{"action": "tool_name", "parameters": {{}}, "confirmation": "message"}}

Otherwise, respond with helpful text.

Tools: {tools_text}
Query: {query}"""
    
    response = await llm_service.chat(
        messages=[{'role': 'user', 'content': tool_prompt}],
        system_prompt=llm_service.get_financial_advisor_prompt(user_context),
        temperature=0.3
    )
    
    try:
        if '{' in response and '}' in response:
            json_start = response.index('{')
            json_end = response.rindex('}') + 1
            parsed = json.loads(response[json_start:json_end])
            
            if 'action' in parsed:
                return {
                    'type': 'tool_call',
                    'action': parsed['action'],
                    'parameters': parsed.get('parameters', {}),
                    'confirmation': parsed.get('confirmation', f"Execute {parsed['action']}?"),
                    'raw_response': response
                }
    except (json.JSONDecodeError, ValueError):
        pass
    
    return {'type': 'text', 'response': response}
