"""
Multi-Provider AI Service
Supports: Groq, OpenAI, Gemini, Ollama
Preserves OpenAI quota for hackathon finals
"""

import os
import httpx
import json
from typing import Optional, Dict, Any

# Make tiktoken optional
try:
    import tiktoken
    TIKTOKEN_AVAILABLE = True
except ImportError:
    TIKTOKEN_AVAILABLE = False


class AIProviderService:
    """Unified AI service supporting multiple providers"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        self.provider = os.getenv('AI_PROVIDER', 'groq').lower()
        self.max_tokens_per_request = int(os.getenv('MAX_TOKENS_PER_REQUEST', '800'))
        
        # Token counter for OpenAI-compatible models (optional)
        if TIKTOKEN_AVAILABLE:
            try:
                self.tokenizer = tiktoken.get_encoding("cl100k_base")
            except:
                self.tokenizer = None
        else:
            self.tokenizer = None
    
    def count_tokens(self, text: str) -> int:
        """Count tokens in text (for budget management)"""
        if self.tokenizer:
            return len(self.tokenizer.encode(text))
        else:
            # Rough estimate: 1 token ≈ 4 characters
            return len(text) // 4
    
    async def get_completion(
        self,
        prompt: str,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        system_prompt: Optional[str] = None
    ) -> str:
        """
        Get AI completion from configured provider
        
        Args:
            prompt: User query
            max_tokens: Max response tokens (defaults to env setting)
            temperature: Response creativity (0-1)
            system_prompt: System instructions
        
        Returns:
            AI response text
        """
        max_tokens = max_tokens or self.max_tokens_per_request
        
        # Check token budget
        prompt_tokens = self.count_tokens(prompt)
        if system_prompt:
            prompt_tokens += self.count_tokens(system_prompt)
        
        # Ensure we stay within limits (reserve tokens for response)
        if prompt_tokens > 700:
            print(f"⚠️ Warning: Prompt is {prompt_tokens} tokens. Truncating...")
            # Truncate prompt if too long
            prompt = prompt[:2800]  # ~700 tokens
        
        # Route to provider
        if self.provider == 'groq':
            return await self._groq_completion(prompt, max_tokens, temperature, system_prompt)
        elif self.provider == 'openai':
            return await self._openai_completion(prompt, max_tokens, temperature, system_prompt)
        elif self.provider == 'gemini':
            return await self._gemini_completion(prompt, max_tokens, temperature, system_prompt)
        elif self.provider == 'ollama':
            return await self._ollama_completion(prompt, max_tokens, temperature, system_prompt)
        elif self.provider == 'mock':
            return self._mock_completion(prompt)
        else:
            raise ValueError(f"Unknown AI provider: {self.provider}")
    
    # ==================== GROQ (Recommended for Testing) ====================
    
    async def _groq_completion(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        system_prompt: Optional[str]
    ) -> str:
        """Groq API with OpenAI Reasoning Model - Fast & Advanced"""
        api_key = os.getenv('GROQ_API_KEY')
        if not api_key:
            raise ValueError("GROQ_API_KEY not set in environment")
        
        url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})
        
        data = {
            "model": "openai/gpt-oss-20b",  # OpenAI reasoning model
            "messages": messages,
            "max_completion_tokens": min(max_tokens, 8192),
            "temperature": temperature,
            "top_p": 1,
            "reasoning_effort": "medium",  # Options: low, medium, high
            "stream": False  # Set to True for streaming if needed
        }
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(url, headers=headers, json=data)
            response.raise_for_status()
            
            result = response.json()
            return result['choices'][0]['message']['content'].strip()
    
    async def _groq_completion_stream(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        system_prompt: Optional[str]
    ):
        """Groq API with streaming - for real-time responses"""
        api_key = os.getenv('GROQ_API_KEY')
        if not api_key:
            raise ValueError("GROQ_API_KEY not set in environment")
        
        url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})
        
        data = {
            "model": "openai/gpt-oss-20b",
            "messages": messages,
            "max_completion_tokens": min(max_tokens, 8192),
            "temperature": temperature,
            "top_p": 1,
            "reasoning_effort": "medium",
            "stream": True
        }
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream("POST", url, headers=headers, json=data) as response:
                response.raise_for_status()
                
                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data_str = line[6:]  # Remove "data: " prefix
                        if data_str.strip() == "[DONE]":
                            break
                        
                        try:
                            chunk = json.loads(data_str)
                            if 'choices' in chunk and len(chunk['choices']) > 0:
                                delta = chunk['choices'][0].get('delta', {})
                                if 'content' in delta:
                                    yield delta['content']
                        except json.JSONDecodeError:
                            continue
    
    # ==================== OPENAI (Save for Finals!) ====================
    
    async def _openai_completion(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        system_prompt: Optional[str]
    ) -> str:
        """OpenAI API - USE ONLY FOR HACKATHON PRESENTATION"""
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key:
            raise ValueError("OPENAI_API_KEY not set. Use GROQ for testing!")
        
        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})
        
        data = {
            "model": "gpt-4o-mini",  # Efficient model
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature
        }
        
        print(f"⚠️ Using OpenAI! Tokens: ~{self.count_tokens(prompt + (system_prompt or ''))}")
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, headers=headers, json=data)
            response.raise_for_status()
            
            result = response.json()
            
            # Log token usage
            usage = result.get('usage', {})
            print(f"📊 Tokens used: {usage.get('total_tokens', 'unknown')}")
            
            return result['choices'][0]['message']['content'].strip()
    
    # ==================== GOOGLE GEMINI ====================
    
    async def _gemini_completion(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        system_prompt: Optional[str]
    ) -> str:
        """Google Gemini API"""
        try:
            import google.generativeai as genai
        except ImportError:
            raise ImportError("Install: pip install google-generativeai")
        
        api_key = os.getenv('GOOGLE_API_KEY')
        if not api_key:
            raise ValueError("GOOGLE_API_KEY not set in environment")
        
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        # Combine system and user prompt
        full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
        
        response = await model.generate_content_async(
            full_prompt,
            generation_config={
                'max_output_tokens': max_tokens,
                'temperature': temperature
            }
        )
        
        return response.text.strip()
    
    # ==================== OLLAMA (Local) ====================
    
    async def _ollama_completion(
        self,
        prompt: str,
        max_tokens: int,
        temperature: float,
        system_prompt: Optional[str]
    ) -> str:
        """Ollama Local API"""
        url = "http://localhost:11434/api/generate"
        
        # Combine prompts
        full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
        
        data = {
            "model": os.getenv('OLLAMA_MODEL', 'llama3'),
            "prompt": full_prompt,
            "stream": False,
            "options": {
                "num_predict": max_tokens,
                "temperature": temperature
            }
        }
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(url, json=data)
            response.raise_for_status()
            
            result = response.json()
            return result['response'].strip()
    
    # ==================== MOCK (No API) ====================
    
    def _mock_completion(self, prompt: str) -> str:
        """Mock responses for offline testing"""
        
        # Simple rule-based responses
        prompt_lower = prompt.lower()
        
        if 'budget' in prompt_lower or 'spending' in prompt_lower:
            return "Based on your spending patterns, I recommend setting a monthly budget of ₹15,000. You're currently spending ₹12,500/month on average."
        
        elif 'save' in prompt_lower or 'savings' in prompt_lower:
            return "Great question about savings! I suggest the 50-30-20 rule: 50% needs, 30% wants, 20% savings. You could save ₹5,000/month comfortably."
        
        elif 'invoice' in prompt_lower or 'gst' in prompt_lower:
            return "For GST invoicing, make sure to include: Invoice number, GSTIN, HSN codes, and proper tax breakdown (CGST/SGST or IGST)."
        
        elif 'cash flow' in prompt_lower or 'runway' in prompt_lower:
            return "Your current runway is 3.5 months. Consider reducing expenses or increasing revenue to extend your runway to 6+ months for safety."
        
        else:
            return "I'm here to help with your financial questions! I can assist with budgeting, savings, GST invoicing, cash flow management, and more."


# Singleton instance
ai_provider = AIProviderService()
