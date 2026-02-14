"""
Unified OpenAI-Compatible Service
Supports both Groq and OpenAI with same SDK - just swap API key!

Usage:
  For Groq (default):
    export OPENAI_API_KEY=<your-groq-api-key>
    export OPENAI_BASE_URL=https://api.groq.com/openai/v1
    export OPENAI_MODEL=llama-3.3-70b-versatile
  
  For OpenAI (finals):
    export OPENAI_API_KEY=<your-openai-api-key>
    export OPENAI_BASE_URL=https://api.openai.com/v1  # or leave unset
    export OPENAI_MODEL=gpt-4o-mini
"""

import json
import logging
import os
import re
from typing import Any, Dict, List, Optional

try:
    from openai import AsyncOpenAI
except ImportError:
    AsyncOpenAI = None


logger = logging.getLogger(__name__)


class GroqOpenAIService:
    """Unified OpenAI-compatible service. Works with Groq, OpenAI, or any OpenAI-compatible API."""

    def __init__(self) -> None:
        self.client: Optional[AsyncOpenAI] = None
        self._initialized = False
        self.last_model_used: Optional[str] = None
        self.provider_name = "Unknown"

    async def initialize(self) -> None:
        if self._initialized:
            return

        if AsyncOpenAI is None:
            logger.warning("openai package not available for GroqOpenAIService")
            return

        # Check for API key (supports both OPENAI_API_KEY and GROQ_API_KEY)
        api_key = os.getenv("OPENAI_API_KEY") or os.getenv("GROQ_API_KEY")
        if not api_key:
            logger.warning("Neither OPENAI_API_KEY nor GROQ_API_KEY is set")
            return

        # Get base URL (if not set, uses OpenAI default)
        base_url = os.getenv("OPENAI_BASE_URL")
        if not base_url and api_key.startswith("gsk_"):
            base_url = "https://api.groq.com/openai/v1"
            logger.info("Detected Groq-style API key; defaulting OPENAI_BASE_URL to Groq endpoint")
        
        # Determine provider based on base URL
        if base_url and "groq.com" in base_url:
            self.provider_name = "Groq"
        elif base_url and "openai.com" in base_url:
            self.provider_name = "OpenAI"
        elif not base_url:
            self.provider_name = "OpenAI"
        else:
            self.provider_name = "Custom"

        # Initialize client
        if base_url:
            self.client = AsyncOpenAI(
                api_key=api_key,
                base_url=base_url,
            )
        else:
            # No base_url = use OpenAI default
            self.client = AsyncOpenAI(api_key=api_key)
        
        self._initialized = True
        logger.info(f"GroqOpenAIService initialized with provider: {self.provider_name}")

    @property
    def is_available(self) -> bool:
        return self._initialized and self.client is not None

    def _candidate_models(self) -> List[str]:
        """
        Get models from environment variable.
        Supports both single model and comma-separated list.
        
        Examples:
          OPENAI_MODEL=gpt-4o-mini                    # OpenAI
          OPENAI_MODEL=llama-3.3-70b-versatile        # Groq
          OPENAI_MODEL=llama3-70b-8192,mixtral-8x7b   # Groq fallback chain
        """
        model_env = os.getenv("OPENAI_MODEL", "")
        
        if model_env:
            # User specified models
            models = [m.strip() for m in model_env.split(",") if m.strip()]
        else:
            # Auto-detect based on provider
            if self.provider_name == "Groq":
                # GPT-OSS is the primary reasoning model for Ideas & Analysis
                models = [
                    "openai/gpt-oss-20b",
                    "llama-3.3-70b-versatile",
                    "mixtral-8x7b-32768"
                ]
            else:
                # OpenAI or custom
                models = ["gpt-4o-mini", "gpt-3.5-turbo"]
        
        return models

    async def chat(
        self,
        messages: List[Dict[str, str]],
        *,
        temperature: float = 0.4,
        max_tokens: int = 1800,
    ) -> Dict[str, Any]:
        if not self.is_available:
            raise RuntimeError("GroqOpenAIService is not available")

        last_error: Optional[Exception] = None
        for model in self._candidate_models():
            try:
                response = await self.client.chat.completions.create(
                    model=model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                )
                content = response.choices[0].message.content or ""
                self.last_model_used = model
                return {"content": content, "model": model}
            except Exception as exc:
                last_error = exc
                logger.warning(f"Groq model failed ({model}): {exc}")

        raise RuntimeError(f"All {self.provider_name} models failed: {last_error}")

    async def chat_json(
        self,
        messages: List[Dict[str, str]],
        *,
        temperature: float = 0.2,
        max_tokens: int = 2200,
    ) -> Dict[str, Any]:
        strict_messages = list(messages)
        strict_messages.append(
            {
                "role": "user",
                "content": (
                    "Return ONLY valid JSON. Do not include markdown, prose, or code fences."
                ),
            }
        )
        result = await self.chat(
            strict_messages,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        parsed = self._extract_json_object(result["content"])
        if parsed is None:
            raise ValueError("Model response did not contain valid JSON")
        return parsed

    @staticmethod
    def _extract_json_object(text: str) -> Optional[Dict[str, Any]]:
        raw = (text or "").strip()
        if not raw:
            return None

        try:
            data = json.loads(raw)
            if isinstance(data, dict):
                return data
        except Exception:
            pass

        code_match = re.search(r"```(?:json)?\s*(\{[\s\S]*?\})\s*```", raw)
        if code_match:
            try:
                data = json.loads(code_match.group(1))
                if isinstance(data, dict):
                    return data
            except Exception:
                pass

        span_match = re.search(r"(\{[\s\S]*\})", raw)
        if span_match:
            try:
                data = json.loads(span_match.group(1))
                if isinstance(data, dict):
                    return data
            except Exception:
                return None

        return None


groq_openai_service = GroqOpenAIService()
