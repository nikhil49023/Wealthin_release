"""
OpenAI Service with Function Calling
Ported from wealthin_server Dart implementation
Provides agentic AI capabilities for financial management
"""

import os
import json
from typing import List, Dict, Any, Optional
from openai import AsyncOpenAI
from dotenv import load_dotenv

load_dotenv()


class OpenAIService:
    """
    OpenAI Service with function calling for agentic behavior.
    Used as the primary orchestrator for WealthIn AI.
    """
    
    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            print("Warning: OPENAI_API_KEY not found in environment variables.")
            self.client = None
        else:
            self.client = AsyncOpenAI(api_key=api_key)
        
        self.default_model = "gpt-4o-mini"
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 1024
    ) -> str:
        """Simple chat completion."""
        if not self.client:
            raise Exception("OpenAI API key not configured")
        
        response = await self.client.chat.completions.create(
            model=model or self.default_model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
        return response.choices[0].message.content or ""
    
    async def simple_chat(self, message: str, system_prompt: str = "") -> str:
        """Simple chat with just a user message."""
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": message})
        return await self.chat(messages)
    
    async def function_call(
        self,
        message: str,
        tools: List[Dict[str, Any]],
        system_prompt: str = "You are a helpful financial assistant."
    ) -> Dict[str, Any]:
        """
        Function calling for agentic behavior.
        Returns either a function call request or a regular message.
        """
        if not self.client:
            raise Exception("OpenAI API key not configured")
        
        # Format tools for OpenAI API
        formatted_tools = [
            {"type": "function", "function": tool}
            for tool in tools
        ]
        
        response = await self.client.chat.completions.create(
            model=self.default_model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message}
            ],
            tools=formatted_tools,
            tool_choice="auto"
        )
        
        choice = response.choices[0]
        
        # Check if the model wants to call a function
        if choice.message.tool_calls:
            tool_call = choice.message.tool_calls[0]
            return {
                "type": "function_call",
                "function": tool_call.function.name,
                "arguments": json.loads(tool_call.function.arguments or "{}"),
                "message": choice.message.content
            }
        
        return {
            "type": "message",
            "content": choice.message.content or ""
        }
    
    async def orchestrate(self, query: str) -> Dict[str, str]:
        """
        Decide which AI service should handle the query.
        Routes to: sarvam (Indic), zoho_rag (factual), openai (conversation)
        """
        system_prompt = """You are an AI orchestrator for a financial app called WealthIn.
Your job is to decide which AI service should handle a user query:

1. "sarvam" - For queries in Indian regional languages (Hindi, Telugu, Tamil, etc.) or about local Indian business concepts
2. "rag" - For factual questions about taxes, GST, regulations, schemes, investments, or when accuracy is critical
3. "llm" - For conversational queries, greetings, personal advice, tips, or general chat

Respond with ONLY a JSON object: {"service": "sarvam|rag|llm", "reason": "brief explanation"}"""

        try:
            response = await self.simple_chat(query, system_prompt=system_prompt)
            # Extract JSON from response
            import re
            json_match = re.search(r'\{[^}]+\}', response)
            if json_match:
                data = json.loads(json_match.group(0))
                return {
                    "service": data.get("service", "llm"),
                    "reason": data.get("reason", "Default routing")
                }
        except Exception as e:
            print(f"Orchestration error: {e}")
        
        return {"service": "llm", "reason": "Fallback to LLM"}


# Singleton instance
openai_service = OpenAIService()
