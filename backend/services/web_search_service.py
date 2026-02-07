"""
Web Search Service for WealthIn
Provides financial news, tax updates, investment schemes, and market data
Uses DuckDuckGo for privacy-respecting searches with caching
"""

import logging
import re
from typing import List, Dict, Optional, Any
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
import asyncio
import os

try:
    from duckduckgo_search import DDGS
    _HAS_DDGS = True
except ImportError:
    _HAS_DDGS = False
    DDGS = None

logger = logging.getLogger(__name__)


@dataclass
class SearchResult:
    """Represents a search result"""
    title: str
    url: str
    snippet: str
    date: Optional[str] = None
    source: str = "web"
    relevance_score: float = 0.8
    price: Optional[float] = None
    price_display: Optional[str] = None
    category: str = "general"
    can_add_to_goal: bool = False


class WebSearchCache:
    """Simple in-memory cache for search results with TTL"""
    
    def __init__(self, ttl_hours: int = 6):
        self.cache: Dict[str, tuple] = {}
        self.ttl_hours = ttl_hours
    
    def get(self, key: str) -> Optional[List[SearchResult]]:
        """Get cached results if still valid"""
        if key not in self.cache:
            return None
        
        results, timestamp = self.cache[key]
        if datetime.now() - timestamp > timedelta(hours=self.ttl_hours):
            del self.cache[key]
            return None
        
        return results
    
    def set(self, key: str, results: List[SearchResult]):
        """Cache search results with timestamp"""
        self.cache[key] = (results, datetime.now())
    
    def clear(self):
        """Clear all cache"""
        self.cache.clear()


class WealthinSearchEngine:
    """
    DuckDuckGo-powered search engine optimized for WealthIn financial app.
    Supports shopping, stocks, real estate, news, and general searches.
    """
    
    def __init__(self):
        self.ddgs = DDGS() if _HAS_DDGS else None
        self.cache = WebSearchCache(ttl_hours=6)
        self.is_available = _HAS_DDGS
    
    async def search(
        self, 
        query: str, 
        category: str = "general", 
        max_results: int = 5
    ) -> List[SearchResult]:
        """
        Universal search router for Wealthin.
        Categories: 'shopping', 'stocks', 'real_estate', 'news', 'hotels', 'general'
        """
        if not self.is_available:
            logger.warning("DuckDuckGo search not available - package not installed")
            return []
        
        # Check cache first
        cache_key = f"{category}:{query}"
        cached = self.cache.get(cache_key)
        if cached:
            logger.info(f"Returning cached results for: {query}")
            return cached[:max_results]
        
        # Optimize query based on category
        refined_query = self._refine_query(query, category)
        
        try:
            # Run synchronous DDG search in thread pool
            results_raw = await asyncio.to_thread(
                self._do_search,
                refined_query,
                max_results * 2  # Get extra for filtering
            )
            
            # Format and filter results
            results = [self._format_result(r, category, idx) for idx, r in enumerate(results_raw)]
            results = self._filter_relevant(results, query)[:max_results]
            
            # Cache results
            if results:
                self.cache.set(cache_key, results)
            
            logger.info(f"DuckDuckGo returned {len(results)} results for: {query}")
            return results
            
        except Exception as e:
            logger.error(f"DuckDuckGo search error: {e}")
            return []
    
    def _do_search(self, query: str, max_results: int) -> List[Dict]:
        """Perform synchronous DuckDuckGo search."""
        if not self.ddgs:
            return []
        
        return list(self.ddgs.text(
            keywords=query,
            region="in-en",  # Focus on Indian market for Wealthin
            safesearch="moderate",
            max_results=max_results,
            backend="lite"  # Fast backend with lower overhead
        ))

    def _refine_query(self, query: str, category: str) -> str:
        """Add search operators to get better financial data."""
        category_refinements = {
            "shopping": f"{query} price site:amazon.in OR site:flipkart.com",
            "fashion": f"{query} price site:myntra.com OR site:ajio.com OR site:amazon.in",
            "stocks": f"{query} share price NSE BSE live today",
            "real_estate": f"{query} property price trends site:magicbricks.com OR site:99acres.com OR site:housing.com",
            "hotels": f"{query} hotel booking price site:makemytrip.com OR site:booking.com OR site:goibibo.com",
            "news": f"{query} India news today latest",
            "tax": f"{query} income tax India 2025 budget",
            "schemes": f"{query} Pradhan Mantri scheme India government benefit",
            "interest_rates": f"{query} RBI interest rate savings FD rate India",
        }
        return category_refinements.get(category, f"{query} India")

    def _format_result(self, r: Dict, category: str, idx: int) -> SearchResult:
        """Parse raw result into SearchResult with category-specific enhancements."""
        result = SearchResult(
            title=r.get("title", ""),
            url=r.get("href", r.get("url", "")),
            snippet=r.get("body", ""),
            category=category,
            relevance_score=1.0 - (idx * 0.05),
            source="DuckDuckGo"
        )
        
        # Extract price for shopping categories
        if category in ["shopping", "fashion"]:
            result.can_add_to_goal = True
            price = self._extract_price(result.snippet + " " + result.title)
            if price:
                result.price = price
                result.price_display = f"₹{price:,.0f}"
            
            # Determine source from URL
            url_lower = result.url.lower()
            if "amazon" in url_lower:
                result.source = "Amazon"
            elif "flipkart" in url_lower:
                result.source = "Flipkart"
            elif "myntra" in url_lower:
                result.source = "Myntra"
        
        # Extract date for news
        if category == "news":
            result.date = self._extract_date(result.snippet)
        
        return result
    
    def _extract_price(self, text: str) -> Optional[float]:
        """Extract price from text using Indian currency patterns."""
        patterns = [
            r'₹\s*([\d,]+(?:\.\d{2})?)',
            r'Rs\.?\s*([\d,]+(?:\.\d{2})?)',
            r'INR\s*([\d,]+(?:\.\d{2})?)',
            r'(?:price|cost|at)\s*[:\-]?\s*₹?\s*([\d,]+(?:\.\d{2})?)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                try:
                    return float(match.group(1).replace(',', ''))
                except ValueError:
                    continue
        return None
    
    def _extract_date(self, text: str) -> Optional[str]:
        """Extract date from text snippet."""
        patterns = [
            r'(\d{1,2}\s+\w{3,9}\s+\d{4})',
            r'(\d{4}-\d{2}-\d{2})',
            r'(\d{1,2}/\d{1,2}/\d{4})',
            r'(today|yesterday|\d+\s+hours?\s+ago|\d+\s+days?\s+ago)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1)
        return None
    
    def _filter_relevant(self, results: List[SearchResult], query: str) -> List[SearchResult]:
        """Filter results by relevance to query and content quality."""
        filtered = []
        query_terms = query.lower().split()
        
        for result in results:
            content = (result.title + " " + result.snippet).lower()
            matches = sum(1 for term in query_terms if term in content)
            
            if matches > 0 and len(result.snippet) > 30:
                result.relevance_score *= (matches / len(query_terms))
                filtered.append(result)
        
        filtered.sort(key=lambda x: x.relevance_score, reverse=True)
        return filtered


class WebSearchService:
    """
    Financial search service with caching and result quality filtering.
    Uses WealthinSearchEngine (DuckDuckGo) for all searches.
    """
    
    def __init__(self):
        self.engine = WealthinSearchEngine()
    
    @property
    def is_available(self) -> bool:
        return self.engine.is_available
    
    async def search_finance_news(
        self,
        query: str,
        limit: int = 5,
        category: Optional[str] = None,
    ) -> List[SearchResult]:
        """Search for financial news and updates."""
        cat = category or "general"
        return await self.engine.search(query, category=cat, max_results=limit)
    
    async def search_tax_updates(self, query: str = "income tax India 2025", limit: int = 5) -> List[SearchResult]:
        """Search for current tax updates and guidelines."""
        return await self.engine.search(query, category="tax", max_results=limit)
    
    async def search_schemes(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for government schemes and benefits."""
        return await self.engine.search(query, category="schemes", max_results=limit)
    
    async def search_interest_rates(self, query: str = "current interest rates India", limit: int = 5) -> List[SearchResult]:
        """Search for current interest rates and market data."""
        return await self.engine.search(query, category="interest_rates", max_results=limit)
    
    async def search_investment_news(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for investment and market news."""
        return await self.engine.search(query, category="stocks", max_results=limit)
    
    async def search_shopping(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for product prices and shopping deals."""
        return await self.engine.search(query, category="shopping", max_results=limit)
    
    async def search_stocks(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for stock prices and market data."""
        return await self.engine.search(query, category="stocks", max_results=limit)
    
    async def search_real_estate(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for real estate and property data."""
        return await self.engine.search(query, category="real_estate", max_results=limit)
    
    async def search_hotels(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for hotel prices and bookings."""
        return await self.engine.search(query, category="hotels", max_results=limit)
    
    def get_cached_results(self, query: str, category: Optional[str] = None) -> Optional[List[SearchResult]]:
        """Get cached results without performing new search."""
        cache_key = f"{category or 'general'}:{query}"
        return self.engine.cache.get(cache_key)
    
    def clear_cache(self):
        """Clear all cached search results."""
        self.engine.cache.clear()
        logger.info("Web search cache cleared")


# Singleton instance
web_search_service = WebSearchService()
