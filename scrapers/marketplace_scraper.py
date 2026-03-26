#!/usr/bin/env python3
"""
Wealthin Marketplace Web Scraper
Crawls Amazon, IndiaMART, JustDial for shopping & business planning assistance
"""

import asyncio
import json
import logging
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any, Dict, List, Optional
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


class MarketplaceScraperBase(ABC):
    """Base class for marketplace scrapers"""

    def __init__(self):
        self.ua = UserAgent()
        self.session = None
        self.timeout = 10

    async def init_session(self) -> aiohttp.ClientSession:
        """Initialize async HTTP session"""
        if self.session is None:
            headers = {'User-Agent': self.ua.random}
            self.session = aiohttp.ClientSession(headers=headers)
        return self.session

    @abstractmethod
    async def search_products(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Search for products"""
        pass

    @abstractmethod
    async def get_product_details(self, product_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed product information"""
        pass

    @abstractmethod
    async def search_businesses(self, category: str, location: str) -> List[Dict[str, Any]]:
        """Search for businesses"""
        pass

    async def close(self):
        """Close session"""
        if self.session:
            await self.session.close()


class AmazonScraper(MarketplaceScraperBase):
    """Amazon product scraper"""

    BASE_URL = "https://www.amazon.in"

    async def search_products(
        self, query: str, limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Search Amazon products"""
        try:
            session = await self.init_session()
            search_url = f"{self.BASE_URL}/s?k={quote(query)}"

            async with session.get(
                search_url, timeout=self.timeout, ssl=False
            ) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    products = self._parse_amazon_products(soup, limit)
                    logger.info(f"Found {len(products)} Amazon products for '{query}'")
                    return products
                else:
                    logger.warning(
                        f"Amazon search failed: HTTP {response.status}"
                    )
                    return []
        except Exception as e:
            logger.error(f"Amazon search error: {str(e)}")
            return []

    async def get_product_details(
        self, product_id: str
    ) -> Optional[Dict[str, Any]]:
        """Get Amazon product details"""
        try:
            session = await self.init_session()
            url = f"{self.BASE_URL}/dp/{product_id}"

            async with session.get(url, timeout=self.timeout, ssl=False) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    return self._parse_amazon_details(soup)
                return None
        except Exception as e:
            logger.error(f"Amazon details error: {str(e)}")
            return None

    async def search_businesses(
        self, category: str, location: str
    ) -> List[Dict[str, Any]]:
        """Amazon doesn't have business directory (use JustDial instead)"""
        return []

    def _parse_amazon_products(self, soup: BeautifulSoup, limit: int) -> List[Dict]:
        """Parse Amazon search results"""
        products = []
        for item in soup.select('div[data-component-type="s-search-result"]')[:limit]:
            try:
                title_elem = item.select_one('h2 a span')
                price_elem = item.select_one('.a-price-whole')
                rating_elem = item.select_one('.a-icon-star-small span')
                link_elem = item.select_one('h2 a')

                if title_elem and price_elem and link_elem:
                    products.append({
                        'source': 'amazon',
                        'title': title_elem.text.strip(),
                        'price': price_elem.text.strip(),
                        'rating': rating_elem.text.split()[0] if rating_elem else 'N/A',
                        'url': urljoin(
                            self.BASE_URL, link_elem.get('href', '')
                        ),
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing Amazon product: {e}")
                continue

        return products

    def _parse_amazon_details(self, soup: BeautifulSoup) -> Optional[Dict]:
        """Parse Amazon product details page"""
        try:
            title = soup.select_one('#productTitle')
            price = soup.select_one('.a-price-whole')
            description = soup.select_one('#feature-bullets')

            if title and price:
                return {
                    'source': 'amazon',
                    'title': title.text.strip(),
                    'price': price.text.strip(),
                    'description': (
                        description.text.strip()
                        if description
                        else 'N/A'
                    ),
                    'scraped_at': datetime.now().isoformat(),
                }
        except Exception as e:
            logger.error(f"Error parsing Amazon details: {e}")

        return None


class IndiaMArtScraper(MarketplaceScraperBase):
    """IndiaMART B2B supplier scraper"""

    BASE_URL = "https://www.indiamart.com"

    async def search_products(
        self, query: str, limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Search IndiaMART products"""
        try:
            session = await self.init_session()
            search_url = f"{self.BASE_URL}/search.mp?ss={quote(query)}"

            async with session.get(
                search_url, timeout=self.timeout, ssl=False
            ) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    products = self._parse_indiamart_products(soup, limit)
                    logger.info(
                        f"Found {len(products)} IndiaMART products for '{query}'"
                    )
                    return products
                else:
                    logger.warning(
                        f"IndiaMART search failed: HTTP {response.status}"
                    )
                    return []
        except Exception as e:
            logger.error(f"IndiaMART search error: {str(e)}")
            return []

    async def get_product_details(
        self, product_id: str
    ) -> Optional[Dict[str, Any]]:
        """Get IndiaMART product details"""
        try:
            session = await self.init_session()
            url = f"{self.BASE_URL}/proddetail/{product_id}"

            async with session.get(url, timeout=self.timeout, ssl=False) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    return self._parse_indiamart_details(soup)
                return None
        except Exception as e:
            logger.error(f"IndiaMART details error: {str(e)}")
            return None

    async def search_businesses(
        self, category: str, location: str
    ) -> List[Dict[str, Any]]:
        """Search IndiaMART suppliers by category & location"""
        try:
            session = await self.init_session()
            search_url = (
                f"{self.BASE_URL}/sellers/{quote(category)}"
                f"?location={quote(location)}"
            )

            async with session.get(
                search_url, timeout=self.timeout, ssl=False
            ) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    businesses = self._parse_indiamart_suppliers(soup)
                    logger.info(
                        f"Found {len(businesses)} IndiaMART suppliers "
                        f"in {category}, {location}"
                    )
                    return businesses
                return []
        except Exception as e:
            logger.error(f"IndiaMART supplier search error: {str(e)}")
            return []

    def _parse_indiamart_products(
        self, soup: BeautifulSoup, limit: int
    ) -> List[Dict]:
        """Parse IndiaMART search results"""
        products = []
        for item in soup.select('div.plstng')[:limit]:
            try:
                title_elem = item.select_one('.prdNameLink')
                price_elem = item.select_one('.pricerange')
                moq_elem = item.select_one('.moqDiv')
                link_elem = item.select_one('a.prdNameLink')

                if title_elem and price_elem and link_elem:
                    products.append({
                        'source': 'indiamart',
                        'title': title_elem.text.strip(),
                        'price': price_elem.text.strip(),
                        'moq': moq_elem.text.strip() if moq_elem else 'N/A',
                        'url': urljoin(
                            self.BASE_URL, link_elem.get('href', '')
                        ),
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing IndiaMART product: {e}")
                continue

        return products

    def _parse_indiamart_details(self, soup: BeautifulSoup) -> Optional[Dict]:
        """Parse IndiaMART product details"""
        try:
            title = soup.select_one('.productName')
            price = soup.select_one('.pricerange')
            moq = soup.select_one('.moqDiv')
            supplier = soup.select_one('.supName')

            if title and price:
                return {
                    'source': 'indiamart',
                    'title': title.text.strip(),
                    'price': price.text.strip(),
                    'moq': moq.text.strip() if moq else 'N/A',
                    'supplier': supplier.text.strip() if supplier else 'N/A',
                    'scraped_at': datetime.now().isoformat(),
                }
        except Exception as e:
            logger.error(f"Error parsing IndiaMART details: {e}")

        return None

    def _parse_indiamart_suppliers(self, soup: BeautifulSoup) -> List[Dict]:
        """Parse IndiaMART supplier directory"""
        suppliers = []
        for item in soup.select('.supplierItem')[:20]:
            try:
                name_elem = item.select_one('.supName')
                rating_elem = item.select_one('.rating')
                location_elem = item.select_one('.location')
                link_elem = item.select_one('a')

                if name_elem and link_elem:
                    suppliers.append({
                        'source': 'indiamart',
                        'name': name_elem.text.strip(),
                        'rating': rating_elem.text.strip() if rating_elem else 'N/A',
                        'location': (
                            location_elem.text.strip()
                            if location_elem
                            else 'N/A'
                        ),
                        'url': urljoin(
                            self.BASE_URL, link_elem.get('href', '')
                        ),
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing IndiaMART supplier: {e}")
                continue

        return suppliers


class JustDialScraper(MarketplaceScraperBase):
    """JustDial business directory scraper"""

    BASE_URL = "https://www.justdial.com"

    async def search_products(
        self, query: str, limit: int = 10
    ) -> List[Dict[str, Any]]:
        """JustDial is for services, not products"""
        return []

    async def get_product_details(
        self, product_id: str
    ) -> Optional[Dict[str, Any]]:
        """Not applicable for JustDial"""
        return None

    async def search_businesses(
        self, category: str, location: str
    ) -> List[Dict[str, Any]]:
        """Search JustDial business directory"""
        try:
            session = await self.init_session()
            search_url = (
                f"{self.BASE_URL}/{quote(category)}-in-{quote(location)}"
            )

            async with session.get(
                search_url, timeout=self.timeout, ssl=False
            ) as response:
                if response.status == 200:
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    businesses = self._parse_justdial_businesses(soup)
                    logger.info(
                        f"Found {len(businesses)} JustDial businesses "
                        f"in {category}, {location}"
                    )
                    return businesses
                return []
        except Exception as e:
            logger.error(f"JustDial search error: {str(e)}")
            return []

    def _parse_justdial_businesses(self, soup: BeautifulSoup) -> List[Dict]:
        """Parse JustDial business listings"""
        businesses = []
        for item in soup.select('.resInfo')[:20]:
            try:
                name_elem = item.select_one('.biz-name')
                rating_elem = item.select_one('.rating-val')
                phone_elem = item.select_one('.mobilesicon')
                address_elem = item.select_one('.biz-desc')
                link_elem = item.select_one('a.listing-title')

                if name_elem and link_elem:
                    businesses.append({
                        'source': 'justdial',
                        'name': name_elem.text.strip(),
                        'rating': rating_elem.text.strip() if rating_elem else 'N/A',
                        'phone': phone_elem.text.strip() if phone_elem else 'N/A',
                        'address': (
                            address_elem.text.strip()
                            if address_elem
                            else 'N/A'
                        ),
                        'url': urljoin(
                            self.BASE_URL, link_elem.get('href', '')
                        ),
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing JustDial business: {e}")
                continue

        return businesses


class MarketplaceScraperManager:
    """Manages all marketplace scrapers"""

    def __init__(self):
        self.amazon = AmazonScraper()
        self.indiamart = IndiaMArtScraper()
        self.justdial = JustDialScraper()

    async def search_all_products(
        self, query: str, limit: int = 5
    ) -> Dict[str, List[Dict]]:
        """Search all marketplaces for products"""
        results = await asyncio.gather(
            self.amazon.search_products(query, limit),
            self.indiamart.search_products(query, limit),
        )
        return {
            'amazon': results[0],
            'indiamart': results[1],
        }

    async def search_all_businesses(
        self, category: str, location: str, limit: int = 10
    ) -> Dict[str, List[Dict]]:
        """Search all business directories"""
        results = await asyncio.gather(
            self.justdial.search_businesses(category, location),
            self.indiamart.search_businesses(category, location),
        )
        return {
            'justdial': results[0],
            'indiamart_suppliers': results[1],
        }

    async def close_all(self):
        """Close all sessions"""
        await self.amazon.close()
        await self.indiamart.close()
        await self.justdial.close()


async def main():
    """Test scrapers"""
    manager = MarketplaceScraperManager()

    print("\n🛍️  TESTING PRODUCT SEARCH\n")
    products = await manager.search_all_products('laptop', limit=3)
    print(json.dumps(products, indent=2))

    print("\n🏢 TESTING BUSINESS SEARCH\n")
    businesses = await manager.search_all_businesses(
        'electronics-retailers', 'bangalore'
    )
    print(json.dumps(businesses, indent=2))

    await manager.close_all()


if __name__ == '__main__':
    asyncio.run(main())
