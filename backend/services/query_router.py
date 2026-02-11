from enum import Enum
from typing import Tuple, Dict

class QueryType(Enum):
    GOV_API = "government_api"      # Real-time verification
    STATIC_KB = "static_knowledge"  # Tax rules, formulas
    TRANSACTION = "transaction"     # User's local data
    HEAVY_REASONING = "heavy"       # DPR, complex analysis
    WEB_SEARCH = "web"              # Latest news
    SIMPLE = "simple"               # Fallback

class QueryRouter:
    """
    Enhanced router: Gov APIs → Static KB → OpenAI
    """
    
    # Government API triggers (real-time data)
    GOV_API_KEYWORDS = [
        "verify pan", "check pan", "validate gstin", "gst number",
        "itr status", "return status", "pf balance", "epfo",
        "nps balance", "aadhaar", "pan card"
    ]
    
    # Static knowledge triggers (offline data)
    STATIC_KB_KEYWORDS = [
        "tax slab", "80c", "80d", "80g", "standard deduction",
        "old regime", "new regime", "gst rate", "itr form",
        "which form", "calculate tax", "deduction limit",
        "income tax", "tax saving"
    ]
    
    # Transaction queries (local DB)
    TRANSACTION_KEYWORDS = [
        "my spending", "my transactions", "my expenses",
        "my budget", "my savings", "show transactions",
        "how much i spent", "my income"
    ]
    
    # Heavy reasoning (OpenAI)
    HEAVY_KEYWORDS = [
        "dpr", "detailed project report", "business plan",
        "market analysis", "feasibility", "investment proposal",
        "strategy"
    ]
    
    WEB_SEARCH_KEYWORDS = [
        "news", "latest", "today", "current price", "stock price",
        "gold rate", "forecast", "trend"
    ]
    
    @staticmethod
    def classify_query(query: str, user_context: dict = None) -> Tuple[QueryType, dict]:
        """
        Enhanced smart routing with weighted scoring for precise classification.
        Uses multi-factor decision making instead of simple keyword matching.
        """
        query_lower = query.lower()

        # Calculate confidence scores for each query type
        scores = {
            QueryType.GOV_API: 0,
            QueryType.STATIC_KB: 0,
            QueryType.TRANSACTION: 0,
            QueryType.WEB_SEARCH: 0,
            QueryType.HEAVY_REASONING: 0,
            QueryType.SIMPLE: 0
        }

        # Score Government API queries (higher weight = stronger match)
        for kw in QueryRouter.GOV_API_KEYWORDS:
            if kw in query_lower:
                scores[QueryType.GOV_API] += 3  # High confidence

        # Score Static Knowledge queries
        for kw in QueryRouter.STATIC_KB_KEYWORDS:
            if kw in query_lower:
                scores[QueryType.STATIC_KB] += 2

        # Score Transaction queries
        for kw in QueryRouter.TRANSACTION_KEYWORDS:
            if kw in query_lower:
                scores[QueryType.TRANSACTION] += 2

        # Score Web Search queries
        for kw in QueryRouter.WEB_SEARCH_KEYWORDS:
            if kw in query_lower:
                scores[QueryType.WEB_SEARCH] += 2

        # Score Heavy Reasoning queries
        for kw in QueryRouter.HEAVY_KEYWORDS:
            if kw in query_lower:
                scores[QueryType.HEAVY_REASONING] += 3

        # Additional context-based scoring
        if user_context:
            # If user has transaction history, boost TRANSACTION score for spending queries
            if user_context.get("has_transactions") and any(w in query_lower for w in ["spend", "expense", "income"]):
                scores[QueryType.TRANSACTION] += 1

        # Question words boost web search for real-time info
        question_words = ["what is", "how much", "when", "where", "latest", "current"]
        if any(qw in query_lower for qw in question_words):
            scores[QueryType.WEB_SEARCH] += 1

        # Find the highest scoring query type
        max_score = max(scores.values())

        if max_score == 0:
            # No clear match - default to SIMPLE
            return QueryType.SIMPLE, {
                "use_govt_api": False,
                "use_static_kb": True,
                "use_openai": True,
                "model": "gpt-4o-mini",
                "confidence": 0.3
            }

        # Get the query type with highest score
        query_type = max(scores, key=scores.get)
        confidence = max_score / 10.0  # Normalize to 0-1 scale

        # Return appropriate config based on classified type
        if query_type == QueryType.GOV_API:
            return QueryType.GOV_API, {
                "use_govt_api": True,
                "use_static_kb": False,
                "use_openai": False,
                "model": "govt_api",
                "confidence": min(confidence, 1.0)
            }

        elif query_type == QueryType.STATIC_KB:
            return QueryType.STATIC_KB, {
                "use_govt_api": False,
                "use_static_kb": True,
                "use_openai": False,
                "model": "static_json",
                "confidence": min(confidence, 1.0)
            }

        elif query_type == QueryType.TRANSACTION:
            return QueryType.TRANSACTION, {
                "use_db": True,
                "use_govt_api": False,
                "use_static_kb": False,
                "use_openai": False,
                "model": "local_db",
                "confidence": min(confidence, 1.0)
            }

        elif query_type == QueryType.WEB_SEARCH:
            return QueryType.WEB_SEARCH, {
                "use_db": False,
                "use_web": True,
                "model": "gpt-4o-mini",
                "confidence": min(confidence, 1.0)
            }

        elif query_type == QueryType.HEAVY_REASONING:
            return QueryType.HEAVY_REASONING, {
                "use_govt_api": False,
                "use_static_kb": True,
                "use_openai": True,
                "model": "gpt-4o",
                "max_tokens": 4000,
                "confidence": min(confidence, 1.0)
            }

        # Fallback to SIMPLE
        return QueryType.SIMPLE, {
            "use_govt_api": False,
            "use_static_kb": True,
            "use_openai": True,
            "model": "gpt-4o-mini",
            "confidence": min(confidence, 1.0)
        }

router = QueryRouter()
