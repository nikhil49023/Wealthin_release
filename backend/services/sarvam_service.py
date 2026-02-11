"""
Sarvam AI Service - Indic Language Expert
Provides culturally and linguistically relevant responses for Indian users
Supports: Hindi, Telugu, Tamil, Kannada, Malayalam, Bengali, Gujarati, Marathi

This version uses direct HTTP requests instead of the SDK for better compatibility
with embedded Python environments (Chaquopy on Android).

Features:
- Document Intelligence: OCR for bank statements, receipts, invoices
- Indic Language Chat: Hindi, Telugu, Tamil, etc.
- Translation: Between Indic languages and English
- Financial Advice: Culturally relevant financial guidance
"""

import os
import re
import json
import logging
import time
import base64
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

    # ==================== DOCUMENT INTELLIGENCE (NEW SDK-STYLE) ====================

    def extract_transactions_from_image(self, file_path: str) -> Dict[str, Any]:
        """
        Extract financial transactions from an image (receipt, bank statement screenshot, etc.)
        using Sarvam Vision with structured output.

        This uses a two-step process:
        1. OCR to extract text from image
        2. LLM to parse text into structured transaction data

        Returns:
            Dict with transactions list and metadata
        """
        if not self.is_configured:
            return {"success": False, "error": "Sarvam AI not configured", "transactions": []}

        try:
            # Step 1: Extract text from image using OCR
            logger.info(f"[Sarvam] Starting transaction extraction from: {file_path}")

            # Read image and encode as base64
            ext = os.path.splitext(file_path)[1].lower()
            content_type = {
                ".jpg": "image/jpeg",
                ".jpeg": "image/jpeg",
                ".png": "image/png",
                ".webp": "image/webp",
            }.get(ext, "image/jpeg")

            with open(file_path, "rb") as f:
                image_data = f.read()
                image_base64 = base64.b64encode(image_data).decode('utf-8')

            # Try the vision/translate endpoint with image input
            url = f"{self.BASE_URL}/v1/chat/completions"

            # Construct prompt for structured extraction
            extraction_prompt = """You are a financial document parser. Extract ALL transactions from this image.

For each transaction, provide:
- date: In YYYY-MM-DD format (use today's date if not visible)
- description: Merchant name or transaction details
- amount: Numeric value (positive number)
- type: "income" or "expense" (debit/payment = expense, credit = income)
- category: One of: Food & Dining, Groceries, Transportation, Shopping, Entertainment, Utilities, Healthcare, Education, Investment, Insurance, EMI & Loans, Salary & Income, Transfer, Rent & Housing, Personal Care, Other

Return ONLY a valid JSON array of transactions:
[{"date": "2024-01-15", "description": "Swiggy Order", "amount": 450.00, "type": "expense", "category": "Food & Dining"}]

If no transactions found, return empty array: []"""

            payload = {
                "model": "sarvam-m",
                "messages": [
                    {"role": "system", "content": extraction_prompt},
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
                                "text": "Extract all financial transactions from this image. Return ONLY JSON array."
                            }
                        ]
                    }
                ],
                "max_tokens": 2000,
                "temperature": 0.1
            }

            response = requests.post(
                url,
                headers=self._get_headers(),
                json=payload,
                timeout=90
            )

            if response.status_code == 200:
                data = response.json()
                content = data.get("choices", [{}])[0].get("message", {}).get("content", "[]")

                # Parse JSON from response
                try:
                    # Clean response
                    content = content.strip()
                    if content.startswith("```json"):
                        content = content[7:]
                    if content.startswith("```"):
                        content = content[3:]
                    if content.endswith("```"):
                        content = content[:-3]
                    content = content.strip()

                    # Find JSON array
                    start_idx = content.find('[')
                    end_idx = content.rfind(']') + 1
                    if start_idx >= 0 and end_idx > start_idx:
                        json_str = content[start_idx:end_idx]
                        transactions = json.loads(json_str)

                        # Validate and clean transactions
                        valid_transactions = []
                        for tx in transactions:
                            if isinstance(tx, dict) and 'amount' in tx:
                                # Ensure required fields
                                tx['date'] = tx.get('date', time.strftime('%Y-%m-%d'))
                                tx['description'] = tx.get('description', 'Transaction')
                                tx['amount'] = abs(float(tx.get('amount', 0)))
                                tx['type'] = tx.get('type', 'expense').lower()
                                tx['category'] = tx.get('category', 'Other')
                                tx['merchant'] = tx.get('merchant', tx['description'])
                                valid_transactions.append(tx)

                        logger.info(f"[Sarvam] Extracted {len(valid_transactions)} transactions")
                        return {
                            "success": True,
                            "transactions": valid_transactions,
                            "source": "sarvam_vision",
                            "raw_text": content[:500]
                        }
                    else:
                        return {
                            "success": False,
                            "error": "No JSON array found in response",
                            "transactions": [],
                            "raw_response": content[:500]
                        }

                except json.JSONDecodeError as e:
                    logger.error(f"[Sarvam] JSON parse error: {e}")
                    return {
                        "success": False,
                        "error": f"Failed to parse response: {e}",
                        "transactions": [],
                        "raw_response": content[:500]
                    }
            else:
                # Fallback: Try simple OCR + text parsing
                logger.warning(f"[Sarvam] Vision API failed ({response.status_code}), trying OCR fallback")
                return self._fallback_ocr_extraction(file_path)

        except Exception as e:
            logger.error(f"[Sarvam] Transaction extraction error: {e}")
            return self._fallback_ocr_extraction(file_path)

    def _fallback_ocr_extraction(self, file_path: str) -> Dict[str, Any]:
        """
        Fallback method: Use simple OCR + regex patterns to extract transactions.
        """
        try:
            # First try basic OCR
            ocr_result = self.extract_from_image(file_path)

            if not ocr_result.get("success"):
                return {"success": False, "error": "OCR failed", "transactions": []}

            text = ocr_result.get("text", "")
            if not text:
                return {"success": False, "error": "No text extracted", "transactions": []}

            # Use regex patterns to find transactions
            transactions = self._parse_transactions_from_text(text)

            return {
                "success": len(transactions) > 0,
                "transactions": transactions,
                "source": "ocr_fallback",
                "raw_text": text[:500]
            }

        except Exception as e:
            logger.error(f"[Sarvam] Fallback OCR error: {e}")
            return {"success": False, "error": str(e), "transactions": []}

    def _parse_transactions_from_text(self, text: str) -> List[Dict]:
        """
        Parse transactions from OCR text using regex patterns.
        Handles common Indian bank statement and receipt formats.
        """
        transactions = []

        # Common patterns for Indian transactions
        # Pattern: Date + Description + Amount
        patterns = [
            # DD/MM/YYYY or DD-MM-YYYY followed by description and amount
            r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(.+?)\s+([\d,]+\.?\d{0,2})\s*(DR|CR|Cr|Dr)?',
            # Amount with Rs or INR prefix
            r'(Rs\.?|INR|₹)\s*([\d,]+\.?\d{0,2})\s+(.+)',
            # UPI pattern
            r'UPI[/-](.+?)[/-](.+?)\s+([\d,]+\.?\d{0,2})',
        ]

        lines = text.split('\n')
        today = time.strftime('%Y-%m-%d')

        for line in lines:
            line = line.strip()
            if not line or len(line) < 5:
                continue

            for pattern in patterns:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    try:
                        groups = match.groups()

                        # Extract amount (find the numeric group)
                        amount = 0
                        description = ""
                        date = today

                        for g in groups:
                            if g and re.match(r'^[\d,]+\.?\d*$', g.replace(',', '')):
                                amount = float(g.replace(',', ''))
                            elif g and re.match(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', g):
                                # Parse date
                                date = self._parse_date(g)
                            elif g and len(g) > 3 and not g.upper() in ['DR', 'CR']:
                                description = g.strip()

                        if amount > 0:
                            # Determine type
                            tx_type = 'expense'
                            if any(x in line.upper() for x in ['CR', 'CREDIT', 'RECEIVED', 'SALARY']):
                                tx_type = 'income'

                            transactions.append({
                                'date': date,
                                'description': description[:100] or 'Transaction',
                                'amount': amount,
                                'type': tx_type,
                                'category': 'Other',
                                'merchant': description[:50] or 'Unknown'
                            })
                            break

                    except Exception as e:
                        logger.debug(f"Pattern match error: {e}")
                        continue

        return transactions

    def _parse_date(self, date_str: str) -> str:
        """Parse various date formats to YYYY-MM-DD."""
        try:
            import re
            # Try DD/MM/YYYY or DD-MM-YYYY
            match = re.match(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})', date_str)
            if match:
                day, month, year = match.groups()
                if len(year) == 2:
                    year = '20' + year
                return f"{year}-{month.zfill(2)}-{day.zfill(2)}"
        except:
            pass
        return time.strftime('%Y-%m-%d')
    
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


    async def get_financial_news_summary(self, query: str = "Indian financial market news today") -> Dict[str, Any]:
        """
        Get latest financial news summary using Web Search + Sarvam AI.
        Returns a 'FinBite' style summary.
        """
        try:
            # Import here to avoid circular dependencies
            from services.web_search_service import web_search_service
            
            # 1. Search for news
            results = await web_search_service.search_finance_news(query, limit=5)
            if not results:
                return {
                    "headline": "Market Update Unavailable",
                    "insight": "Could not fetch latest news. Please check your internet connection.",
                    "trend": "stable"
                }
                
            # 2. Format for Sarvam
            news_text = "\n".join([f"- {r.title}: {r.snippet}" for r in results])
            
            # 3. Summarize with Sarvam
            system_prompt = """You are a smart financial news assistant.
Summarize the following news into a strict JSON format (no markdown, just raw JSON).
{
  "headline": "Catchy headline (max 8 words)",
  "insight": "Concise summary of market impact (max 2 sentences)",
  "trend": "up" | "down" | "stable",
  "recommendation": "One actionable tip for investors"
}"""
            
            response_text = await self.chat([
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Summarize these updates:\n{news_text}"}
            ])
            
            # Clean and parse JSON
            clean_text = response_text.replace("```json", "").replace("```", "").strip()
            # Handle potential extra text
            if "{" in clean_text:
                clean_text = clean_text[clean_text.find("{"):clean_text.rfind("}")+1]
                
            return json.loads(clean_text)
            
        except Exception as e:
            logger.error(f"Sarvam news summary failed: {e}")
            return {
                "headline": "Market Update",
                "insight": "Stay tuned for the latest financial updates.",
                "trend": "stable",
                "recommendation": "Review your portfolio regularly."
            }



# Singleton instance
sarvam_service = SarvamService()
