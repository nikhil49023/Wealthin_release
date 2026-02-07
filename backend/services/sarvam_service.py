"""
Sarvam AI Service - Indic Language Expert
Provides culturally and linguistically relevant responses for Indian users
Supports: Hindi, Telugu, Tamil, Kannada, Malayalam, Bengali, Gujarati, Marathi

This version uses direct HTTP requests instead of the SDK for better compatibility
with embedded Python environments (Chaquopy on Android).
"""

import os
import re
import json
import logging
from typing import List, Dict, Optional, Any
from dotenv import load_dotenv

# Use requests (lightweight, works on Android via Chaquopy)
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

load_dotenv()

logger = logging.getLogger(__name__)


class SarvamService:
    """
    Sarvam AI Service for Indic language support.
    Uses direct HTTP requests for maximum compatibility.
    """
    
    BASE_URL = "https://api.sarvam.ai"
    
    def __init__(self):
        self.api_key = os.getenv("SARVAM_API_KEY")
        self._initialized = False
        
        if not self.api_key:
            logger.warning("SARVAM_API_KEY not found. Indic language features disabled.")
        elif not REQUESTS_AVAILABLE:
            logger.warning("requests library not available.")
        else:
            self._initialized = True
            logger.info("✅ Sarvam AI initialized successfully")
        
    @property
    def is_configured(self) -> bool:
        return bool(self.api_key and REQUESTS_AVAILABLE and self._initialized)
    
    def _get_headers(self) -> Dict[str, str]:
        """Get standard headers for Sarvam API requests."""
        return {
            "api-subscription-key": self.api_key,
            "Content-Type": "application/json",
        }
    
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
    
    # ==================== DOCUMENT INTELLIGENCE ====================
    
    def parse_document(self, file_path: str, output_format: str = "markdown") -> Dict[str, Any]:
        """
        Parse a PDF document using Sarvam Doc Intelligence.
        
        Args:
            file_path: Path to the PDF file
            output_format: "markdown" or "html"
        
        Returns:
            Dict with parsed content and metadata
        """
        if not self.is_configured:
            return {"success": False, "error": "Sarvam AI not configured"}
        
        try:
            url = f"{self.BASE_URL}/parse/parsepdf"
            
            with open(file_path, "rb") as f:
                files = {"file": (os.path.basename(file_path), f, "application/pdf")}
                headers = {"api-subscription-key": self.api_key}
                
                response = requests.post(
                    url,
                    headers=headers,
                    files=files,
                    timeout=120  # PDF parsing can take time
                )
            
            if response.status_code == 200:
                data = response.json()
                return {
                    "success": True,
                    "content": data.get("parsed_content", ""),
                    "pages": data.get("num_pages", 0),
                    "metadata": data.get("metadata", {}),
                }
            else:
                return {
                    "success": False,
                    "error": f"API error: {response.status_code}",
                    "details": response.text[:500]
                }
                
        except requests.exceptions.Timeout:
            return {"success": False, "error": "Request timed out"}
        except requests.exceptions.ConnectionError:
            return {"success": False, "error": "No internet connection"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def extract_from_image(self, file_path: str) -> Dict[str, Any]:
        """
        Extract text from an image using Sarvam Vision OCR.
        
        Args:
            file_path: Path to the image file (jpg, png, etc.)
        
        Returns:
            Dict with extracted text and confidence
        """
        if not self.is_configured:
            return {"success": False, "error": "Sarvam AI not configured"}
        
        try:
            # Sarvam Vision endpoint for OCR
            url = f"{self.BASE_URL}/vision/ocr"
            
            # Determine content type
            ext = os.path.splitext(file_path)[1].lower()
            content_type = {
                ".jpg": "image/jpeg",
                ".jpeg": "image/jpeg",
                ".png": "image/png",
                ".webp": "image/webp",
            }.get(ext, "application/octet-stream")
            
            with open(file_path, "rb") as f:
                files = {"file": (os.path.basename(file_path), f, content_type)}
                headers = {"api-subscription-key": self.api_key}
                
                response = requests.post(
                    url,
                    headers=headers,
                    files=files,
                    timeout=60
                )
            
            if response.status_code == 200:
                data = response.json()
                return {
                    "success": True,
                    "text": data.get("extracted_text", ""),
                    "confidence": data.get("confidence", 0.0),
                    "language": data.get("detected_language", "unknown"),
                }
            else:
                return {
                    "success": False,
                    "error": f"API error: {response.status_code}",
                    "details": response.text[:500]
                }
                
        except requests.exceptions.Timeout:
            return {"success": False, "error": "Request timed out"}
        except requests.exceptions.ConnectionError:
            return {"success": False, "error": "No internet connection"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    # ==================== CHAT COMPLETIONS ====================
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        model: str = "sarvam-m"
    ) -> str:
        """
        Chat completion using Sarvam AI via HTTP.
        Best for Indic language conversations.
        """
        if not self.is_configured:
            raise Exception("Sarvam AI not configured")
        
        try:
            url = f"{self.BASE_URL}/v1/chat/completions"
            
            payload = {
                "model": model,
                "messages": messages,
            }
            
            response = requests.post(
                url,
                headers=self._get_headers(),
                json=payload,
                timeout=60
            )
            
            if response.status_code == 200:
                data = response.json()
                choices = data.get("choices", [])
                if choices:
                    return choices[0].get("message", {}).get("content", "")
                return ""
            else:
                raise Exception(f"API error: {response.status_code} - {response.text[:200]}")
                
        except Exception as e:
            raise Exception(f"Sarvam AI error: {str(e)}")
    
    def chat_completion_sync(
        self,
        messages: List[Dict[str, str]],
        tools: Optional[List[Dict[str, Any]]] = None,
        model: str = "sarvam-m"
    ) -> Dict[str, Any]:
        """
        Synchronous chat completion with optional tools support.
        Returns the full response object.
        """
        if not self.is_configured:
            return {"error": "Sarvam AI not configured"}
        
        try:
            url = f"{self.BASE_URL}/v1/chat/completions"
            
            payload = {
                "model": model,
                "messages": messages,
            }
            if tools:
                payload["tools"] = tools
            
            response = requests.post(
                url,
                headers=self._get_headers(),
                json=payload,
                timeout=60
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"API error: {response.status_code}"}
                
        except Exception as e:
            return {"error": str(e)}
    
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
    
    # ==================== TRANSLATION ====================
    
    def translate_sync(
        self,
        text: str,
        source_lang: str,
        target_lang: str
    ) -> str:
        """Translate text between languages (synchronous)."""
        if not self.is_configured:
            return text
        
        try:
            url = f"{self.BASE_URL}/translate"
            
            response = requests.post(
                url,
                headers=self._get_headers(),
                json={
                    "text": text,
                    "source_language": source_lang,
                    "target_language": target_lang,
                },
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                return data.get("translated_text", text)
            return text
            
        except Exception:
            return text
    
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
