"""
WealthIn Idea Evaluator Service
Uses OpenAI to deeply evaluate business ideas with structured scoring.
"""

import os
import json
import logging
from typing import Dict, Any, Optional
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

try:
    from openai import OpenAI
    HAS_OPENAI = True
except ImportError:
    HAS_OPENAI = False


class IdeaEvaluatorService:
    """Evaluate business ideas using OpenAI with structured analysis."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        self._client = None
        self._model = "gpt-4o"

    @property
    def is_available(self) -> bool:
        return HAS_OPENAI and bool(os.getenv("OPENAI_API_KEY"))

    def _get_client(self):
        if self._client is None and self.is_available:
            self._client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        return self._client

    async def evaluate_idea(
        self,
        idea: str,
        user_context: Optional[Dict[str, Any]] = None,
        location: str = "India",
        budget_range: str = "5-10 Lakhs",
    ) -> Dict[str, Any]:
        """
        Evaluate a business idea with deep OpenAI analysis.
        Returns structured evaluation with scores, market analysis, etc.
        """
        client = self._get_client()
        if not client:
            return self._fallback_evaluation(idea)

        context_str = ""
        if user_context:
            context_str = f"""
User Financial Context:
- Monthly Income: ₹{user_context.get('income', 'Unknown')}
- Monthly Savings: ₹{user_context.get('savings', 'Unknown')}
- Current Savings Rate: {user_context.get('savings_rate', 'Unknown')}%
- Location: {user_context.get('location', location)}
"""

        prompt = f"""You are an expert business consultant and venture analyst specializing in the Indian market.

Evaluate this business idea comprehensively:

**Business Idea:** {idea}
**Location:** {location}
**Estimated Budget:** {budget_range}
{context_str}

Provide a detailed evaluation in the following JSON format:
{{
    "score": <integer 0-100>,
    "viability": "<one of: Highly Viable, Viable, Moderately Viable, Needs Work, Not Recommended>",
    "executive_summary": "<2-3 sentence summary>",
    "market_analysis": {{
        "market_size": "<estimated in crores>",
        "growth_rate": "<annual growth %>",
        "target_audience": "<description>",
        "demand_signals": ["<signal1>", "<signal2>", "<signal3>"]
    }},
    "financial_projection": {{
        "estimated_investment": "<range in INR>",
        "monthly_operating_cost": "<range in INR>",
        "break_even_months": <integer>,
        "expected_monthly_revenue": "<range in INR after stabilization>",
        "roi_first_year": "<percentage>"
    }},
    "strengths": ["<strength1>", "<strength2>", "<strength3>", "<strength4>"],
    "weaknesses": ["<weakness1>", "<weakness2>", "<weakness3>"],
    "opportunities": ["<opportunity1>", "<opportunity2>", "<opportunity3>"],
    "threats": ["<threat1>", "<threat2>", "<threat3>"],
    "competitive_landscape": "<analysis of existing competitors>",
    "risk_assessment": "<key risks and mitigation strategies>",
    "recommendations": ["<actionable step 1>", "<actionable step 2>", "<actionable step 3>", "<actionable step 4>", "<actionable step 5>"],
    "revenue_model_suggestions": ["<model1>", "<model2>", "<model3>"],
    "regulatory_considerations": "<relevant Indian regulations>"
}}

Be specific to the Indian market context. Use real market data where possible.
Return ONLY valid JSON, no markdown.
"""

        try:
            response = client.chat.completions.create(
                model=self._model,
                messages=[
                    {"role": "system", "content": "You are a business evaluation expert. Return only valid JSON."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.7,
                max_tokens=3000,
            )

            content = response.choices[0].message.content.strip()
            # Clean markdown code fences if present
            if content.startswith("```"):
                content = content.split("\n", 1)[1]
            if content.endswith("```"):
                content = content.rsplit("```", 1)[0]
            if content.startswith("json"):
                content = content[4:]

            evaluation = json.loads(content.strip())
            evaluation["idea"] = idea
            evaluation["model_used"] = self._model
            return evaluation

        except json.JSONDecodeError as e:
            logger.error(f"JSON parse error in idea evaluation: {e}")
            return self._fallback_evaluation(idea)
        except Exception as e:
            logger.error(f"OpenAI idea evaluation error: {e}")
            return self._fallback_evaluation(idea)

    def _fallback_evaluation(self, idea: str) -> Dict[str, Any]:
        """Fallback evaluation when OpenAI is not available"""
        return {
            "idea": idea,
            "score": 65,
            "viability": "Moderately Viable",
            "executive_summary": f"'{idea}' shows potential in the Indian market. Detailed AI evaluation requires OpenAI configuration.",
            "market_analysis": {
                "market_size": "Requires research",
                "growth_rate": "Requires research",
                "target_audience": "Urban professionals, 25-45 age group",
                "demand_signals": ["Growing digital adoption", "Rising disposable income"],
            },
            "financial_projection": {
                "estimated_investment": "₹5-15 Lakhs",
                "monthly_operating_cost": "₹50,000-1,50,000",
                "break_even_months": 12,
                "expected_monthly_revenue": "₹1-3 Lakhs",
                "roi_first_year": "15-25%",
            },
            "strengths": ["Growing market demand", "Digital-first approach possible"],
            "weaknesses": ["Competition from established players", "Capital requirements"],
            "opportunities": ["Government startup initiatives", "Digital India push"],
            "threats": ["Market saturation risk", "Regulatory changes"],
            "competitive_landscape": "Requires detailed market research",
            "risk_assessment": "Medium risk - Standard startup challenges apply",
            "recommendations": [
                "Conduct detailed market research",
                "Build a minimum viable product (MVP)",
                "Start with a small pilot in your locality",
                "Network with potential early adopters",
                "Apply for Startup India recognition",
            ],
            "revenue_model_suggestions": ["Subscription-based", "Freemium", "Commission-based"],
            "regulatory_considerations": "Check DPIIT, MSME, and sector-specific regulations",
            "model_used": "fallback",
        }


# Singleton
idea_evaluator = IdeaEvaluatorService()
