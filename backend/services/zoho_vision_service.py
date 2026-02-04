"""
Zoho Catalyst QuickML Service - LLM Chat & Vision OCR
Uses Zoho Catalyst QuickML API for:
- LLM Chat (crm-di-qwen_text_14b-fp8-it model)
- VLM Vision (VL-Qwen2.5-7B model) for receipt/document OCR
Part of the "Perception Layer" in the Sense-Plan-Act architecture
"""

import os
import json
import base64
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
import httpx
from dotenv import load_dotenv

load_dotenv()


@dataclass
class ExtractedReceipt:
    """Structured receipt data extracted from image."""
    merchant_name: str
    date: Optional[str]
    total_amount: float
    currency: str
    items: List[Dict[str, Any]]
    category: Optional[str]
    payment_method: Optional[str]
    raw_text: str
    confidence: float


class ZohoVisionService:
    """
    Zoho Catalyst QuickML integration for LLM chat and vision/OCR tasks.
    - LLM Chat: https://api.catalyst.zoho.in/quickml/v2/project/{project_id}/llm/chat
    - VLM Vision: https://api.catalyst.zoho.in/quickml/v1/project/{project_id}/vlm/chat
    """
    
    def __init__(self):
        self.client_id = os.getenv("ZOHO_CLIENT_ID")
        self.client_secret = os.getenv("ZOHO_CLIENT_SECRET")
        self.refresh_token = os.getenv("ZOHO_REFRESH_TOKEN")
        self.project_id = os.getenv("ZOHO_PROJECT_ID", "24392000000011167")
        self.org_id = os.getenv("ZOHO_CATALYST_ORG_ID", "60056122667")
        self._access_token = None
        
        # API URLs
        self.llm_url = f"https://api.catalyst.zoho.in/quickml/v2/project/{self.project_id}/llm/chat"
        self.vlm_url = f"https://api.catalyst.zoho.in/quickml/v1/project/{self.project_id}/vlm/chat"
        
        if not all([self.client_id, self.client_secret, self.refresh_token]):
            print("Warning: Zoho credentials not complete. Vision/LLM features disabled.")
        else:
            print("✅ Zoho Catalyst QuickML configured")
    
    @property
    def is_configured(self) -> bool:
        return bool(self.client_id and self.client_secret and self.refresh_token)
    
    async def _get_access_token(self) -> str:
        """Get or refresh Zoho access token."""
        if self._access_token:
            return self._access_token
        
        if not self.refresh_token:
            raise Exception("Zoho refresh token not configured")
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://accounts.zoho.in/oauth/v2/token",
                data={
                    "refresh_token": self.refresh_token,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "grant_type": "refresh_token",
                },
            )
            
            if response.status_code != 200:
                raise Exception(f"Zoho auth error: {response.text}")
            
            data = response.json()
            self._access_token = data.get("access_token")
            print("✅ Zoho access token obtained")
            return self._access_token
    
    async def llm_chat(
        self,
        prompt: str,
        system_prompt: str = "You are a helpful financial advisor for Indian entrepreneurs. Be concise and practical. Use ₹ for amounts.",
        model: str = "crm-di-qwen_text_14b-fp8-it",
        temperature: float = 0.7,
        max_tokens: int = 512
    ) -> str:
        """
        Chat completion using Zoho Catalyst QuickML LLM.
        Uses the Qwen 14B model for text generation.
        """
        if not self.is_configured:
            raise Exception("Zoho Catalyst not configured")
        
        token = await self._get_access_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.llm_url,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {token}",
                    "CATALYST-ORG": self.org_id
                },
                json={
                    "prompt": prompt,
                    "model": model,
                    "system_prompt": system_prompt,
                    "top_p": 0.9,
                    "top_k": 50,
                    "best_of": 1,
                    "temperature": temperature,
                    "max_tokens": max_tokens
                },
                timeout=60.0
            )
            
            if response.status_code != 200:
                # Token might have expired, clear and retry
                self._access_token = None
                raise Exception(f"Zoho LLM error: {response.status_code} - {response.text}")
            
            data = response.json()
            # Extract response text - adjust based on actual API response format
            if isinstance(data, dict):
                return data.get("response", data.get("text", data.get("output", str(data))))
            return str(data)
    
    async def vlm_chat(
        self,
        prompt: str,
        images: List[str],  # List of base64-encoded images
        system_prompt: str = "Be concise and factual.",
        model: str = "VL-Qwen2.5-7B",
        temperature: float = 0.7,
        max_tokens: int = 500
    ) -> str:
        """
        Vision chat using Zoho Catalyst QuickML VLM.
        Uses the VL-Qwen2.5-7B model for image understanding.
        """
        if not self.is_configured:
            raise Exception("Zoho Catalyst not configured")
        
        token = await self._get_access_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.vlm_url,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {token}",
                    "CATALYST-ORG": self.org_id
                },
                json={
                    "prompt": prompt,
                    "model": model,
                    "images": images,
                    "system_prompt": system_prompt,
                    "top_k": 50,
                    "top_p": 0.9,
                    "temperature": temperature,
                    "max_tokens": max_tokens
                },
                timeout=60.0
            )
            
            if response.status_code != 200:
                self._access_token = None
                raise Exception(f"Zoho VLM error: {response.status_code} - {response.text}")
            
            data = response.json()
            if isinstance(data, dict):
                return data.get("response", data.get("text", data.get("output", str(data))))
            return str(data)

    async def extract_receipt(
        self,
        image_bytes: bytes,
        filename: str = "receipt.jpg"
    ) -> ExtractedReceipt:
        """
        Extract structured data from a receipt image.
        Uses Zoho's VLM (VL-Qwen2.5-7B) for OCR.
        """
        if not self.is_configured:
            raise Exception("Zoho Vision not configured")
        
        # Encode image to base64
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')
        
        prompt = """Extract all information from this receipt image and return a JSON object with:
{
  "merchant_name": "store/vendor name",
  "date": "YYYY-MM-DD format if visible",
  "total_amount": numeric value,
  "currency": "INR" or detected currency,
  "items": [{"name": "item name", "quantity": 1, "price": 0.0}],
  "category": "Food/Transport/Shopping/Bills/Entertainment/Other",
  "payment_method": "Cash/UPI/Card/Other if visible",
  "raw_text": "all text found in image"
}
Return ONLY the JSON object, no other text."""

        try:
            response_text = await self.vlm_chat(
                prompt=prompt,
                images=[image_b64],
                system_prompt="You are an OCR expert. Extract information from receipts accurately. Return only valid JSON.",
                max_tokens=1024
            )
            
            # Parse the JSON response
            try:
                # Extract JSON from response (handle markdown code blocks)
                json_match = response_text
                if "```json" in response_text:
                    json_match = response_text.split("```json")[1].split("```")[0]
                elif "```" in response_text:
                    json_match = response_text.split("```")[1].split("```")[0]
                
                parsed = json.loads(json_match.strip())
            except json.JSONDecodeError:
                parsed = {
                    "merchant_name": "Unknown",
                    "total_amount": 0.0,
                    "raw_text": response_text
                }
            
            return ExtractedReceipt(
                merchant_name=parsed.get("merchant_name", "Unknown"),
                date=parsed.get("date"),
                total_amount=float(parsed.get("total_amount", 0)),
                currency=parsed.get("currency", "INR"),
                items=parsed.get("items", []),
                category=parsed.get("category"),
                payment_method=parsed.get("payment_method"),
                raw_text=parsed.get("raw_text", ""),
                confidence=0.85
            )
        except Exception as e:
            raise Exception(f"Receipt extraction failed: {str(e)}")
    
    async def extract_bank_statement_page(
        self,
        image_bytes: bytes
    ) -> List[Dict[str, Any]]:
        """
        Extract transactions from a bank statement image/scan.
        Returns list of transaction dictionaries.
        """
        if not self.is_configured:
            raise Exception("Zoho Vision not configured")
        
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')
        
        prompt = """Extract all transactions from this bank statement image.
Return a JSON array of transactions:
[
  {
    "date": "YYYY-MM-DD",
    "description": "transaction description",
    "amount": numeric value (positive for credit, negative for debit),
    "type": "credit" or "debit",
    "balance": running balance if visible
  }
]
Return ONLY the JSON array."""

        try:
            response_text = await self.vlm_chat(
                prompt=prompt,
                images=[image_b64],
                system_prompt="You are a bank statement OCR expert. Extract transaction data accurately. Return only valid JSON array.",
                max_tokens=2048
            )
            
            try:
                if "```json" in response_text:
                    response_text = response_text.split("```json")[1].split("```")[0]
                elif "```" in response_text:
                    response_text = response_text.split("```")[1].split("```")[0]
                return json.loads(response_text.strip())
            except json.JSONDecodeError:
                return []
        except Exception as e:
            raise Exception(f"Bank statement extraction failed: {str(e)}")


# Singleton instance
zoho_vision_service = ZohoVisionService()
