#!/usr/bin/env python3
"""
Enhanced E-Commerce Semantic Search Across Multiple Platforms
Integrates: Flipkart, eBay, OLX, Alibaba, Amazon, IndiaMART
"""

import asyncio
import json
import logging
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import quote, urljoin

import aiohttp
import requests
from bs4 import BeautifulSoup
from fake_useragent import UserAgent

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
#  SEMANTIC SEARCH ENGINE
# ─────────────────────────────────────────────────────────────────────────────

class SemanticSearchEngine:
    """Semantic search across e-commerce platforms"""

    def __init__(self):
        self.ua = UserAgent()

    def calculate_relevance_score(
        self, product: Dict[str, Any], query: str
    ) -> float:
        """
        Calculate semantic relevance using TF-based scoring
        Higher score = more relevant to user query
        """
        score = 0.0
        query_words = set(query.lower().split())
        title_lower = product.get('title', '').lower()

        # Exact match bonus
        if query.lower() in title_lower:
            score += 100

        # Word match scoring
        for word in query_words:
            if word in title_lower:
                score += 20

        # Price relevance (if budget provided)
        if 'price_score' in product:
            score += product['price_score'] * 10

        # Rating bonus
        if 'rating' in product:
            try:
                rating = float(str(product['rating']).split()[0])
                score += rating * 5
            except (ValueError, IndexError):
                pass

        return score

    def rank_results(
        self, results: List[Dict[str, Any]], query: str
    ) -> List[Tuple[Dict, float]]:
        """Rank products by relevance score"""
        scored = [
            (product, self.calculate_relevance_score(product, query))
            for product in results
        ]
        scored.sort(key=lambda x: x[1], reverse=True)
        return scored

    def deduplicate_results(
        self, results: List[Dict[str, Any]], query: str
    ) -> List[Dict[str, Any]]:
        """Remove duplicate products across sources"""
        seen_titles = {}
        unique_results = []

        for result in results:
            title_normalized = (
                result.get('title', '').lower().strip()
            )

            if title_normalized not in seen_titles:
                seen_titles[title_normalized] = result
                unique_results.append(result)
            else:
                # Keep the one with better rating/price
                existing = seen_titles[title_normalized]
                try:
                    new_rating = float(
                        str(result.get('rating', '0')).split()[0]
                    )
                    old_rating = float(
                        str(existing.get('rating', '0')).split()[0]
                    )
                    if new_rating > old_rating:
                        unique_results.remove(existing)
                        unique_results.append(result)
                        seen_titles[title_normalized] = result
                except (ValueError, IndexError):
                    pass

        return unique_results


class FlipkartScraper:
    """Flipkart e-commerce scraper"""

    BASE_URL = "https://www.flipkart.com"

    def __init__(self):
        self.ua = UserAgent()

    async def search_products(
        self, query: str, limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Search Flipkart products"""
        try:
            search_url = f"{self.BASE_URL}/search?q={quote(query)}"
            headers = {'User-Agent': self.ua.random}

            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    search_url, timeout=aiohttp.ClientTimeout(total=10), ssl=False
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        products = self._parse_flipkart_products(soup, limit)
                        logger.info(
                            f"Found {len(products)} Flipkart products for '{query}'"
                        )
                        return products
            return []
        except Exception as e:
            logger.error(f"Flipkart search error: {e}")
            return []

    def _parse_flipkart_products(
        self, soup: BeautifulSoup, limit: int
    ) -> List[Dict]:
        """Parse Flipkart search results"""
        products = []
        for item in soup.select('div._1AtVbE')[:limit]:
            try:
                title = item.select_one('.KzDlHZ')
                price = item.select_one('._30jeq3')
                rating = item.select_one('.gUuXX_')

                if title and price:
                    products.append({
                        'source': 'flipkart',
                        'title': title.text.strip(),
                        'price': price.text.strip(),
                        'rating': rating.text if rating else 'N/A',
                        'url': urljoin(
                            self.BASE_URL, item.select_one('a')['href']
                        ) if item.select_one('a') else '',
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing Flipkart product: {e}")
                continue

        return products


class EBayIndianScraper:
    """eBay India scraper"""

    BASE_URL = "https://www.ebay.in"

    def __init__(self):
        self.ua = UserAgent()

    async def search_products(
        self, query: str, limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Search eBay India products"""
        try:
            search_url = f"{self.BASE_URL}/sch/i.html?_nkw={quote(query)}"
            headers = {'User-Agent': self.ua.random}

            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    search_url, timeout=aiohttp.ClientTimeout(total=10), ssl=False
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        products = self._parse_ebay_products(soup, limit)
                        logger.info(
                            f"Found {len(products)} eBay products for '{query}'"
                        )
                        return products
            return []
        except Exception as e:
            logger.error(f"eBay search error: {e}")
            return []

    def _parse_ebay_products(
        self, soup: BeautifulSoup, limit: int
    ) -> List[Dict]:
        """Parse eBay search results"""
        products = []
        for item in soup.select('div.s-item')[:limit]:
            try:
                title = item.select_one('.s-item__title')
                price = item.select_one('.s-item__price')

                if title and price:
                    products.append({
                        'source': 'ebay',
                        'title': title.text.strip(),
                        'price': price.text.strip(),
                        'rating': 'N/A',
                        'url': item.select_one('a')['href'] if item.select_one('a') else '',
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing eBay product: {e}")
                continue

        return products


class OLXScraper:
    """OLX India classifieds scraper"""

    BASE_URL = "https://www.olx.in"

    def __init__(self):
        self.ua = UserAgent()

    async def search_products(
        self, query: str, limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Search OLX listings"""
        try:
            search_url = f"{self.BASE_URL}/search?q={quote(query)}"
            headers = {'User-Agent': self.ua.random}

            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    search_url, timeout=aiohttp.ClientTimeout(total=10), ssl=False
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        products = self._parse_olx_listings(soup, limit)
                        logger.info(
                            f"Found {len(products)} OLX listings for '{query}'"
                        )
                        return products
            return []
        except Exception as e:
            logger.error(f"OLX search error: {e}")
            return []

    def _parse_olx_listings(
        self, soup: BeautifulSoup, limit: int
    ) -> List[Dict]:
        """Parse OLX search results"""
        products = []
        for item in soup.select('a[data-testid="listing"]')[:limit]:
            try:
                title = item.select_one('span')
                price_elem = item.select_one('[data-testid="price"]')

                if title and price_elem:
                    products.append({
                        'source': 'olx',
                        'title': title.text.strip(),
                        'price': price_elem.text.strip(),
                        'rating': 'N/A',
                        'is_secondhand': True,
                        'url': item.get('href', ''),
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing OLX listing: {e}")
                continue

        return products


class AlibabaExpressScraper:
    """Alibaba Express (AliExpress) scraper"""

    BASE_URL = "https://www.aliexpress.com"

    def __init__(self):
        self.ua = UserAgent()

    async def search_products(
        self, query: str, limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Search AliExpress products"""
        try:
            search_url = (
                f"{self.BASE_URL}/wholesale?SearchText={quote(query)}"
            )
            headers = {'User-Agent': self.ua.random}

            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    search_url, timeout=aiohttp.ClientTimeout(total=10), ssl=False
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        products = self._parse_aliexpress_products(soup, limit)
                        logger.info(
                            f"Found {len(products)} AliExpress products for '{query}'"
                        )
                        return products
            return []
        except Exception as e:
            logger.error(f"AliExpress search error: {e}")
            return []

    def _parse_aliexpress_products(
        self, soup: BeautifulSoup, limit: int
    ) -> List[Dict]:
        """Parse AliExpress search results"""
        products = []
        for item in soup.select('div.organic-item')[:limit]:
            try:
                title = item.select_one('.organic-title')
                price = item.select_one('.organic-price')

                if title and price:
                    products.append({
                        'source': 'aliexpress',
                        'title': title.text.strip(),
                        'price': price.text.strip(),
                        'rating': 'N/A',
                        'shipping': 'International',
                        'url': item.select_one('a')['href'] if item.select_one('a') else '',
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing AliExpress product: {e}")
                continue

        return products


class MultiPlatformSearchManager:
    """Manages semantic search across all platforms"""

    def __init__(self):
        self.flipkart = FlipkartScraper()
        self.ebay = EBayIndianScraper()
        self.olx = OLXScraper()
        self.aliexpress = AlibabaExpressScraper()
        self.semantic_engine = SemanticSearchEngine()

    async def semantic_search(
        self, query: str, limit: int = 20
    ) -> Dict[str, Any]:
        """
        Unified semantic search across all platforms
        Returns ranked, deduplicated results
        """
        try:
            logger.info(f"Starting semantic search for: {query}")

            # Parallel search across all platforms
            results = await asyncio.gather(
                self.flipkart.search_products(query, limit),
                self.ebay.search_products(query, limit),
                self.olx.search_products(query, limit),
                self.aliexpress.search_products(query, limit),
            )

            # Flatten results
            all_products = []
            for platform_results in results:
                all_products.extend(platform_results)

            # Deduplicate similar products
            unique_products = self.semantic_engine.deduplicate_results(
                all_products, query
            )

            # Rank by relevance
            ranked = self.semantic_engine.rank_results(
                unique_products, query
            )

            # Format response
            return {
                'success': True,
                'query': query,
                'results': [
                    {
                        **product,
                        'relevance_score': score,
                    }
                    for product, score in ranked[:limit]
                ],
                'total_results': len(ranked),
                'sources': list(set(p['source'] for p in unique_products)),
                'scraped_at': datetime.now().isoformat(),
            }

        except Exception as e:
            logger.error(f"Semantic search error: {e}")
            return {
                'success': False,
                'error': str(e),
            }


if __name__ == '__main__':
    async def test():
        manager = MultiPlatformSearchManager()
        results = await manager.semantic_search('laptop', limit=10)
        print(json.dumps(results, indent=2))

    asyncio.run(test())
