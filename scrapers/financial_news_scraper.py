#!/usr/bin/env python3
"""
Financial News Scraper & Government Orders Tracker
Tracks economic indicators, news, and government procurement
"""

import asyncio
import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional
from urllib.parse import quote

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
#  FINANCIAL NEWS SCRAPERS
# ─────────────────────────────────────────────────────────────────────────────

class FinancialNewsScraper:
    """Scrapes financial news and economic indicators"""

    def __init__(self):
        self.ua = UserAgent()
        self.sources = {
            'economic_times': {
                'url': 'https://economictimes.indiatimes.com',
                'selectors': {
                    'article': 'div.listing',
                    'title': 'h3',
                    'link': 'a',
                },
            },
            'cnbc_tv18': {
                'url': 'https://www.cnbctv18.com',
                'selectors': {
                    'article': 'div.article-card',
                    'title': 'h2',
                    'link': 'a',
                },
            },
            'rbi_news': {
                'url': 'https://www.rbi.org.in/web/rbi',
                'selectors': {
                    'article': 'div.news-item',
                },
            },
        }

    async def scrape_financial_news(self) -> List[Dict[str, Any]]:
        """Scrape financial news from multiple sources"""
        news_items = []

        tasks = [
            self._scrape_economic_times(),
            self._scrape_cnbc(),
            self._scrape_rbi_updates(),
        ]

        results = await asyncio.gather(*tasks)
        for result in results:
            news_items.extend(result)

        return news_items

    async def _scrape_economic_times(self) -> List[Dict[str, Any]]:
        """Scrape Economic Times"""
        try:
            headers = {'User-Agent': self.ua.random}
            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    'https://economictimes.indiatimes.com/markets',
                        timeout=aiohttp.ClientTimeout(total=10),
                    ssl=False,
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        return self._parse_economic_times(soup)
        except Exception as e:
            logger.error(f"Economic Times scrape error: {e}")
        return []

    async def _scrape_cnbc(self) -> List[Dict[str, Any]]:
        """Scrape CNBC-TV18"""
        try:
            headers = {'User-Agent': self.ua.random}
            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    'https://www.cnbctv18.com/market',
                        timeout=aiohttp.ClientTimeout(total=10),
                    ssl=False,
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        return self._parse_cnbc(soup)
        except Exception as e:
            logger.error(f"CNBC-TV18 scrape error: {e}")
        return []

    async def _scrape_rbi_updates(self) -> List[Dict[str, Any]]:
        """Scrape RBI official updates"""
        try:
            headers = {'User-Agent': self.ua.random}
            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    'https://www.rbi.org.in/web/rbi/press-releases',
                        timeout=aiohttp.ClientTimeout(total=10),
                    ssl=False,
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        return self._parse_rbi_updates(soup)
        except Exception as e:
            logger.error(f"RBI updates scrape error: {e}")
        return []

    def _parse_economic_times(self, soup: BeautifulSoup) -> List[Dict]:
        """Parse Economic Times articles"""
        articles = []
        for item in soup.select('div.listing')[:10]:
            try:
                title = item.select_one('h3')
                link = item.select_one('a')
                date = item.select_one('.date')

                if title and link:
                    articles.append({
                        'source': 'economic_times',
                        'title': title.text.strip(),
                        'url': link.get('href', ''),
                        'published_date': date.text.strip() if date else 'N/A',
                        'category': 'Financial News',
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing ET article: {e}")
        return articles

    def _parse_cnbc(self, soup: BeautifulSoup) -> List[Dict]:
        """Parse CNBC articles"""
        articles = []
        for item in soup.select('div.article-card')[:10]:
            try:
                title = item.select_one('h2')
                link = item.select_one('a')

                if title and link:
                    articles.append({
                        'source': 'cnbc_tv18',
                        'title': title.text.strip(),
                        'url': link.get('href', ''),
                        'category': 'Financial News',
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing CNBC article: {e}")
        return articles

    def _parse_rbi_updates(self, soup: BeautifulSoup) -> List[Dict]:
        """Parse RBI press releases"""
        articles = []
        for item in soup.select('div.pr-item')[:10]:
            try:
                title = item.select_one('a')
                date = item.select_one('.date')

                if title:
                    articles.append({
                        'source': 'rbi_official',
                        'title': title.text.strip(),
                        'url': title.get('href', ''),
                        'published_date': date.text.strip() if date else 'N/A',
                        'category': 'RBI Update',
                        'importance': 'High',
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing RBI update: {e}")
        return articles


# ─────────────────────────────────────────────────────────────────────────────
#  GOVERNMENT ORDERS & TENDERS TRACKER
# ─────────────────────────────────────────────────────────────────────────────

class GovernmentOrdersScraper:
    """Tracks government procurement orders and tenders"""

    def __init__(self):
        self.ua = UserAgent()

    async def scrape_government_tenders(
        self, category: str = 'all'
    ) -> List[Dict[str, Any]]:
        """Scrape government e-marketplace tenders"""
        try:
            headers = {'User-Agent': self.ua.random}
            # GeM (Government e-Marketplace)
            url = 'https://gem.gov.in/browse-tenders'

            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.get(
                    url,
                        timeout=aiohttp.ClientTimeout(total=10),
                    ssl=False,
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        soup = BeautifulSoup(html, 'html.parser')
                        return self._parse_government_tenders(soup)
        except Exception as e:
            logger.error(f"Government tenders scrape error: {e}")
        return []

    async def scrape_ministry_orders(self) -> List[Dict[str, Any]]:
        """Scrape ministry-wise government orders"""
        orders = []

        ministries = {
            'commerce': 'https://www.commerce.gov.in/press-release',
            'finance': 'https://pib.gov.in/PressReleaseDetail.aspx?PRID=',
            'labor': 'https://pib.gov.in/PressReleasePage.aspx?PRID=',
        }

        for ministry, url in ministries.items():
            try:
                headers = {'User-Agent': self.ua.random}
                async with aiohttp.ClientSession(headers=headers) as session:
                    async with session.get(
                        url,
                            timeout=aiohttp.ClientTimeout(total=10),
                        ssl=False,
                    ) as response:
                        if response.status == 200:
                            html = await response.text()
                            soup = BeautifulSoup(html, 'html.parser')
                            ministry_orders = self._parse_ministry_orders(
                                soup, ministry
                            )
                            orders.extend(ministry_orders)
            except Exception as e:
                logger.debug(f"Ministry orders scrape error ({ministry}): {e}")

        return orders

    def _parse_government_tenders(
        self, soup: BeautifulSoup
    ) -> List[Dict]:
        """Parse GeM tenders"""
        tenders = []
        for item in soup.select('div.tender-item')[:20]:
            try:
                title = item.select_one('h3')
                description = item.select_one('p.description')
                deadline = item.select_one('span.deadline')
                amount = item.select_one('span.amount')

                if title:
                    tenders.append({
                        'source': 'nam_gem',
                        'type': 'Government Tender',
                        'title': title.text.strip(),
                        'description': description.text.strip() if description else '',
                        'deadline': deadline.text.strip() if deadline else 'N/A',
                        'tender_value': amount.text.strip() if amount else 'N/A',
                        'category': 'Government Procurement',
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing tender: {e}")

        return tenders

    def _parse_ministry_orders(
        self, soup: BeautifulSoup, ministry: str
    ) -> List[Dict]:
        """Parse ministry orders"""
        orders = []
        for item in soup.select('div.press-release')[:10]:
            try:
                title = item.select_one('h2')
                date = item.select_one('span.date')
                link = item.select_one('a')

                if title:
                    orders.append({
                        'source': f'{ministry}_official',
                        'type': 'Government Order',
                        'title': title.text.strip(),
                        'date': date.text.strip() if date else 'N/A',
                        'url': link.get('href', '') if link else '',
                        'ministry': ministry.capitalize(),
                        'scraped_at': datetime.now().isoformat(),
                    })
            except Exception as e:
                logger.debug(f"Error parsing {ministry} order: {e}")

        return orders


# ─────────────────────────────────────────────────────────────────────────────
#  INFLATION & ECONOMIC INDICATORS CALCULATOR
# ─────────────────────────────────────────────────────────────────────────────

class InflationCalculator:
    """Calculates inflation and economic metrics"""

    # RBI base rates (example data - fetch from RBI API in production)
    RBI_REPO_RATE = 6.5  # Current (as of March 2024)
    RBI_REVERSE_REPO = 6.25
    CURRENT_INFLATION_RATE = 5.4  # CPI inflation

    # Historical inflation indices
    INFLATION_HISTORY = {
        '2024_march': 5.4,
        '2024_february': 5.9,
        '2024_january': 6.5,
        '2023_december': 5.7,
        '2023_november': 4.8,
    }

    def calculate_real_value(
        self, amount: float, years: int = 1
    ) -> Dict[str, float]:
        """
        Calculate real value of money considering inflation
        Real Value = Amount / (1 + inflation_rate)^years
        """
        inflation_rate = self.CURRENT_INFLATION_RATE / 100

        real_value = amount / ((1 + inflation_rate) ** years)
        value_lost = amount - real_value

        return {
            'nominal_amount': amount,
            'real_value_after_years': round(real_value, 2),
            'value_lost_to_inflation': round(value_lost, 2),
            'inflation_rate_percent': self.CURRENT_INFLATION_RATE,
            'time_period_years': years,
        }

    def estimate_future_price(
        self, current_price: float, years: int = 1
    ) -> Dict[str, Any]:
        """Estimate future price considering inflation"""
        inflation_rate = self.CURRENT_INFLATION_RATE / 100

        future_price = current_price * ((1 + inflation_rate) ** years)
        price_increase = future_price - current_price

        return {
            'current_price': current_price,
            'estimated_price': round(future_price, 2),
            'price_increase': round(price_increase, 2),
            'percentage_increase': round((price_increase / current_price) * 100, 2),
            'time_period_years': years,
            'inflation_applied': self.CURRENT_INFLATION_RATE,
        }

    def calculate_savings_real_value(
        self, monthly_savings: float, months: int = 12
    ) -> Dict[str, Any]:
        """
        Calculate real value of savings after inflation
        Shows how much purchasing power is lost
        """
        total_savings = monthly_savings * months
        inflation_rate = self.CURRENT_INFLATION_RATE / 100
        years = months / 12

        real_value = total_savings / ((1 + inflation_rate) ** years)
        purchasing_power_loss = total_savings - real_value

        return {
            'total_savings': total_savings,
            'real_value': round(real_value, 2),
            'purchasing_power_loss': round(purchasing_power_loss, 2),
            'loss_percentage': round(
                (purchasing_power_loss / total_savings) * 100, 2
            ),
            'period_months': months,
            'recommendation': (
                'Consider investing in assets that outpace inflation'
                if purchasing_power_loss > (total_savings * 0.05)
                else 'Savings are reasonable'
            ),
        }

    def get_economic_indicators(self) -> Dict[str, Any]:
        """Get current economic indicators"""
        return {
            'rbi_repo_rate': self.RBI_REPO_RATE,
            'rbi_reverse_repo': self.RBI_REVERSE_REPO,
            'current_inflation': self.CURRENT_INFLATION_RATE,
            'inflation_trend': self._calculate_trend(),
            'cpi_forecast_next_quarter': 5.8,
            'currency_band': 'INR 82-84 to USD',
            'last_updated': datetime.now().isoformat(),
        }

    def _calculate_trend(self) -> str:
        """Calculate inflation trend"""
        recent = self.INFLATION_HISTORY['2024_march']
        previous = self.INFLATION_HISTORY['2024_february']

        if recent > previous:
            return 'RISING ⬆️'
        elif recent < previous:
            return 'FALLING ⬇️'
        else:
            return 'STABLE ➡️'

    def generate_product_recommendations(
        self,
        user_budget: float,
        inflation_risk_tolerance: str = 'medium',
    ) -> Dict[str, Any]:
        """
        Recommend product purchases considering inflation
        Higher inflation = buy now, lower inflation = can wait
        """
        recommendations = []

        if self.CURRENT_INFLATION_RATE > 6.0:
            recommendations.extend([
                {
                    'type': 'Essential Items',
                    'action': 'BUY NOW',
                    'reasoning': (
                        'High inflation - buy essential items now '
                        'before prices rise further'
                    ),
                    'urgency': 'HIGH',
                },
                {
                    'type': 'Non-essential',
                    'action': 'DEFER',
                    'reasoning': 'High inflation - defer luxury purchases',
                    'urgency': 'LOW',
                },
            ])
        elif self.CURRENT_INFLATION_RATE < 4.5:
            recommendations.extend([
                {
                    'type': 'Durable Goods',
                    'action': 'CAN_WAIT',
                    'reasoning': 'Low inflation - prices unlikely to rise much',
                    'urgency': 'LOW',
                },
                {
                    'type': 'Investments',
                    'action': 'CONSIDER',
                    'reasoning': 'Low inflation - good time to invest',
                    'urgency': 'MEDIUM',
                },
            ])
        else:
            recommendations.append({
                'type': 'All Products',
                'action': 'NORMAL_SHOPPING',
                'reasoning': 'Moderate inflation - normal buying patterns',
                'urgency': 'MEDIUM',
            })

        return {
            'current_inflation': self.CURRENT_INFLATION_RATE,
            'user_budget': user_budget,
            'risk_tolerance': inflation_risk_tolerance,
            'recommendations': recommendations,
            'generated_at': datetime.now().isoformat(),
        }


class FinancialAggregator:
    """Aggregates all financial data sources"""

    def __init__(self):
        self.news_scraper = FinancialNewsScraper()
        self.govt_scraper = GovernmentOrdersScraper()
        self.inflation_calc = InflationCalculator()

    async def get_financial_dashboard(self) -> Dict[str, Any]:
        """Get comprehensive financial dashboard"""
        try:
            # Parallel data collection
            news_task = self.news_scraper.scrape_financial_news()
            tenders_task = (
                self.govt_scraper.scrape_government_tenders()
            )
            orders_task = self.govt_scraper.scrape_ministry_orders()

            news, tenders, orders = await asyncio.gather(
                news_task, tenders_task, orders_task
            )

            indicators = self.inflation_calc.get_economic_indicators()

            return {
                'success': True,
                'financial_news': news[:5],
                'government_tenders': tenders[:5],
                'ministry_orders': orders[:5],
                'economic_indicators': indicators,
                'generated_at': datetime.now().isoformat(),
            }
        except Exception as e:
            logger.error(f"Dashboard generation error: {e}")
            return {'success': False, 'error': str(e)}


if __name__ == '__main__':
    async def test():
        agg = FinancialAggregator()
        dashboard = await agg.get_financial_dashboard()
        print(json.dumps(dashboard, indent=2))

        calc = InflationCalculator()
        print('\n--- Price Estimation ---')
        print(json.dumps(calc.estimate_future_price(50000, 1), indent=2))

    asyncio.run(test())
