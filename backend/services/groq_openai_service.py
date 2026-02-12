"""
Groq OpenAI-compatible service restricted to OpenAI GPT-OSS models.
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
    """Groq chat wrapper with strict OpenAI model validation and fallback."""

    def __init__(self) -> None:
        self.client: Optional[AsyncOpenAI] = None
        self._initialized = False
        self.last_model_used: Optional[str] = None

    async def initialize(self) -> None:
        if self._initialized:
            return

        if AsyncOpenAI is None:
            logger.warning("openai package not available for GroqOpenAIService")
            return

        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            logger.warning("GROQ_API_KEY not set")
            return

        self.client = AsyncOpenAI(
            api_key=api_key,
            base_url="https://api.groq.com/openai/v1",
        )
        self._initialized = True
        logger.info("GroqOpenAIService initialized")

    @property
    def is_available(self) -> bool:
        return self._initialized and self.client is not None

    def _candidate_models(self) -> List[str]:
        raw = os.getenv(
            "GROQ_OPENAI_MODELS",
            "openai/gpt-oss-120b,openai/gpt-oss-70b,openai/gpt-oss-20b",
        )
        parsed = [m.strip() for m in raw.split(",") if m.strip()]
        allowed = [m for m in parsed if m.startswith("openai/gpt-oss-")]
        if not allowed:
            allowed = ["openai/gpt-oss-20b"]
        return allowed

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

        raise RuntimeError(f"All OpenAI Groq models failed: {last_error}")

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

