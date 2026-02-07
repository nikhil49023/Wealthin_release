"""
Sarvam AI Service - Indic Language Expert
Provides culturally and linguistically relevant responses for Indian users
Supports: Hindi, Telugu, Tamil, Kannada, Malayalam, Bengali, Gujarati, Marathi
Uses the official sarvamai SDK for chat completions.
"""

import os
import re
import json
from typing import List, Dict, Optional, Any
from dotenv import load_dotenv
import httpx

load_dotenv()

# Try to import sarvamai SDK
try:
    from sarvamai import SarvamAI
    SARVAM_SDK_AVAILABLE = True
except ImportError:
    SARVAM_SDK_AVAILABLE = False
    print("Warning: sarvamai SDK not installed. Run: pip install sarvamai")


class SarvamService:
    """
    Sarvam AI Service for Indic language support.
    Used for regional language queries and local business context.
    Uses the official sarvamai SDK.
    """
    
    def __init__(self):
        self.api_key = os.getenv("SARVAM_API_KEY")
        self._client = None
        
        if not self.api_key:
            print("Warning: SARVAM_API_KEY not found. Indic language features disabled.")
        elif not SARVAM_SDK_AVAILABLE:
            print("Warning: sarvamai SDK not available. Install with: pip install sarvamai")
        else:
            self._client = SarvamAI(api_subscription_key=self.api_key)
            print("✅ Sarvam AI initialized successfully")
        
    @property
    def is_configured(self) -> bool:
        return bool(self.api_key and SARVAM_SDK_AVAILABLE and self._client)
    
    # Language detection patterns
    INDIC_PATTERNS = {
        'hindi': re.compile(r'[\u0900-\u097F]'),      # Devanagari
        'telugu': re.compile(r'[\u0C00-\u0C7F]'),     # Telugu
        'tamil': re.compile(r'[\u0B80-\u0BFF]'),      # Tamil
        'kannada': re.compile(r'[\u0C80-\u0CFF]'),    # Kannada
        'malayalam': re.compile(r'[\u0D00-\u0D7F]'),  # Malayalam
        'bengali': re.compile(r'[\u0980-\u09FF]'),    # Bengali
        'gujarati': re.compile(r'[\u0A80-\u0AFF]'),   # Gujarati
        'marathi': re.compile(r'[\u0900-\u097F]'),    # Marathi (uses Devanagari)
    }
    
    def is_indic_query(self, text: str) -> bool:
        """Check if text contains any Indic language script."""
        for pattern in self.INDIC_PATTERNS.values():
            if pattern.search(text):
                return True
        return False
    
    def detect_language(self, text: str) -> str:
        """Detect the primary Indic language in text."""
        for lang, pattern in self.INDIC_PATTERNS.items():
            if pattern.search(text):
                return lang
        return 'english'
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        model: str = "sarvam-m"  # Valid models: sarvam-m, gemma-4b, gemma-12b
    ) -> str:
        """
        Chat completion using Sarvam AI SDK.
        Best for Indic language conversations.
        """
        if not self.is_configured:
            raise Exception("Sarvam AI not configured or SDK not available")
        
        try:
            # Use the sarvamai SDK - synchronous call
            # Explicitly pass model to avoid API errors
            response = self._client.chat.completions(
                messages=messages,
                model=model
            )
            
            # Extract the response content
            if hasattr(response, 'choices') and response.choices:
                return response.choices[0].message.content
            elif isinstance(response, dict):
                return response.get("choices", [{}])[0].get("message", {}).get("content", "")
            else:
                return str(response)
                
        except Exception as e:
            # If standard model fails, try fallback (e.g. if API expects specific 'sarvam-m')
            if "sarvam-m" in str(e) and model == "sarvam-2b":
                 try:
                    response = self._client.chat.completions(
                        messages=messages,
                        model="sarvam-m"
                    )
                    if hasattr(response, 'choices') and response.choices:
                        return response.choices[0].message.content
                 except Exception:
                     pass
            raise Exception(f"Sarvam AI error: {str(e)}")

    def chat_completion(
        self,
        messages: List[Dict[str, str]],
        tools: Optional[List[Dict[str, Any]]] = None,
        model: str = "sarvam-2.0-llama-3.1-8b-instruct" # Using a capable model for reasoning
    ) -> Any:
        """
        Raw chat completion with tools support.
        Returns the full response object to handle tool_calls.
        """
        if not self.is_configured:
             raise Exception("Sarvam AI not configured")
        
        try:
            # Prepare arguments
            kwargs = {
                "messages": messages,
                "model": model,
            }
            if tools:
                kwargs["tools"] = tools
                
            # Use the SDK's create method if widely supported, or formatted call
            # Based on user example: client.chat.completions.create
            if hasattr(self._client, 'chat') and hasattr(self._client.chat, 'completions'):
                if hasattr(self._client.chat.completions, 'create'):
                    return self._client.chat.completions.create(**kwargs)
                else:
                    # Fallback to direct call if older SDK structure
                    return self._client.chat.completions(**kwargs)
            else:
                # Direct client call fallback
                return self._client(**kwargs)
                
        except Exception as e:
            raise Exception(f"Sarvam completion error: {e}")
    async def simple_chat(
        self,
        message: str,
        system_prompt: str = ""
    ) -> str:
        """Simple chat with user message."""
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": message})
        return await self.chat(messages)
    
    async def translate(
        self,
        text: str,
        source_lang: str,
        target_lang: str
    ) -> str:
        """Translate text between languages."""
        if not self.is_configured:
            return text  # Return original if not configured
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.BASE_URL}/translate",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {self.api_key}",
                },
                json={
                    "text": text,
                    "source_language": source_lang,
                    "target_language": target_lang,
                },
                timeout=30.0
            )
            
            if response.status_code != 200:
                return text  # Return original on error
            
            data = response.json()
            return data.get("translated_text", text)
    
    async def get_financial_advice_indic(
        self,
        query: str,
        language: Optional[str] = None
    ) -> str:
        """
        Get financial advice in Indian regional language.
        Adds local context like regional tax benefits, schemes, etc.
        """
        detected_lang = language or self.detect_language(query)
        
        system_prompt = f"""You are a helpful financial advisor for Indian entrepreneurs.
Respond in {detected_lang} if the user's query is in that language.
Include relevant local context like:
- State-specific tax benefits
- Regional business schemes (MSME, Mudra loans)
- GST implications for small businesses
- UPI and digital payment guidance
Be concise and practical. Use ₹ for amounts."""

        return await self.simple_chat(query, system_prompt)


# Singleton instance
sarvam_service = SarvamService()
