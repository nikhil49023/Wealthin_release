"""
Web Search Service for WealthIn
Provides financial news, tax updates, investment schemes, and market data
Uses DuckDuckGo for privacy-respecting searches with caching
"""

import logging
from typing import List, Dict, Optional, Any
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
import asyncio
import os
from functools import lru_cache
from .api_sethu_service import api_sethu_service

try:
    from duckduckgo_search import DDGS
except ImportError:
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


class ScraperDogService:
    """Service to interact with ScraperDog API"""
    def __init__(self):
        self.api_key = os.getenv("SCRAPERDOG_API_KEY", "")
        self.base_url = "https://api.scraperdog.com/scrape"
        self.is_configured = bool(self.api_key)

    async def search(self, query: str, limit: int = 5) -> List[SearchResult]:
        if not self.is_configured:
            logger.warning("ScraperDog not configured")
            return []
            
        try:
            # Placeholder for ScraperDog Google Search API or generic scrape
            # Example: params = {"api_key": self.api_key, "url": f"https://www.google.com/search?q={query}"}
            # response = requests.get(self.base_url, params=params)
             # ... parse HTML ...
            return []
        except Exception as e:
            logger.error(f"ScraperDog search failed: {e}")
            return []

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



class WebSearchService:
    """
    Financial search service with caching and result quality filtering
    """
    
    def __init__(self):
        self.cache = WebSearchCache(ttl_hours=6)
        self.search_client = DDGS() if DDGS else None
        
        # Finance-specific search keywords
        self.finance_keywords = {
            'tax': ['income tax', 'gst', 'tax return', 'tax slab', 'deduction', 'tax filing'],
            'investment': ['mutual fund', 'stocks', 'bonds', 'sip', 'market news', 'portfolio'],
            'schemes': ['pradhan mantri', 'scheme', 'government', 'subsidy', 'benefit'],
            'interest_rates': ['rbi', 'interest rate', 'savings account', 'fd rate', 'emi'],
            'crypto': ['bitcoin', 'crypto', 'nft', 'blockchain', 'web3'],
            'realestate': ['real estate', 'property', 'home', 'mortgage', 'rental'],
        }
    
    async def search_finance_news(
        self,
        query: str,
        limit: int = 5,
        category: Optional[str] = None,
    ) -> List[SearchResult]:
        """
        Search for financial news and updates
        
        Args:
            query: Search query
            limit: Number of results to return
            category: Optional category filter (tax, investment, schemes, etc.)
        
        Returns:
            List of SearchResult objects
        """
        try:
            # Check cache first
            cache_key = f"finance_news:{query}:{category}"
            cached = self.cache.get(cache_key)
            if cached:
                logger.info(f"Returning cached results for: {query}")
                return cached[:limit]
            
            if not self.search_client:
                logger.warning("DuckDuckGo client not available, returning empty results")
                return []
            
            # Build enhanced query with finance context
            enhanced_query = f"{query} India finance news"
            if category:
                enhanced_query = f"{query} {category}"
            
            # Perform search
            results = []
            try:
                ddg_results = await asyncio.to_thread(
                    self.search_client.text,
                    enhanced_query,
                    max_results=limit * 2,  # Get extra to filter
                )
                
                for idx, result in enumerate(ddg_results[:limit * 2]):
                    search_result = SearchResult(
                        title=result.get('title', ''),
                        url=result.get('link', ''),
                        snippet=result.get('body', ''),
                        date=self._extract_date(result.get('body', '')),
                        source='DuckDuckGo',
                        relevance_score=1.0 - (idx * 0.05),  # Decay by position
                    )
                    results.append(search_result)
                
                # Filter and sort by relevance
                results = self._filter_relevant_results(results, query)
                results = results[:limit]
                
                # Cache results
                self.cache.set(cache_key, results)
                
                logger.info(f"Found {len(results)} results for: {query}")
                return results
            
            except Exception as e:
                logger.error(f"DuckDuckGo search failed: {e}")
                return []
        
        except Exception as e:
            logger.error(f"Search finance news error: {e}")
            return []
    
    async def search_tax_updates(self, query: str = "income tax India 2025", limit: int = 5) -> List[SearchResult]:
        """Search for current tax updates and guidelines"""
        enhanced_query = f"{query} budget income tax slab deduction"
        return await self.search_finance_news(enhanced_query, limit=limit, category="tax")
    
    async def search_schemes(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for government schemes and benefits"""
        enhanced_query = f"{query} Pradhan Mantri scheme India government"
        return await self.search_finance_news(enhanced_query, limit=limit, category="schemes")
    
    async def search_interest_rates(self, query: str = "current interest rates India", limit: int = 5) -> List[SearchResult]:
        """Search for current interest rates and market data"""
        enhanced_query = f"{query} RBI savings account FD rate SIP"
        return await self.search_finance_news(enhanced_query, limit=limit, category="interest_rates")
    
    async def search_investment_news(self, query: str, limit: int = 5) -> List[SearchResult]:
        """Search for investment and market news"""
        enhanced_query = f"{query} stock market mutual fund portfolio"
        return await self.search_finance_news(enhanced_query, limit=limit, category="investment")
    
    def _extract_date(self, text: str) -> Optional[str]:
        """Try to extract date from text snippet"""
        # Simple date extraction - can be enhanced with regex
        import re
        
        patterns = [
            r'\d{1,2}\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}',
            r'\d{4}-\d{2}-\d{2}',
            r'\d{1,2}/\d{1,2}/\d{4}',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text)
            if match:
                return match.group(0)
        
        return None
    
    def _filter_relevant_results(self, results: List[SearchResult], query: str) -> List[SearchResult]:
        """Filter results by relevance to query and content quality"""
        filtered = []
        query_terms = query.lower().split()
        
        for result in results:
            # Check if title/snippet contains query terms
            content = (result.title + " " + result.snippet).lower()
            matches = sum(1 for term in query_terms if term in content)
            
            if matches > 0 and len(result.snippet) > 50:  # Must have snippet
                result.relevance_score *= (matches / len(query_terms))
                filtered.append(result)
        
        # Sort by relevance
        filtered.sort(key=lambda x: x.relevance_score, reverse=True)
        return filtered
    
    def get_cached_results(self, query: str, category: Optional[str] = None) -> Optional[List[SearchResult]]:
        """Get cached results without performing new search"""
        cache_key = f"finance_news:{query}:{category}"
        return self.cache.get(cache_key)
    
    def clear_cache(self):
        """Clear all cached search results"""
        self.cache.clear()
        logger.info("Web search cache cleared")


# Singleton instance
web_search_service = WebSearchService()
