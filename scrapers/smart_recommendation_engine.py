#!/usr/bin/env python3
"""
Smart Recommendation Engine
Combines all data sources (e-commerce, financial, government, inflation) 
to provide personalized product & investment suggestions
"""

import asyncio
import json
import logging
from datetime import datetime
from typing import Any, Dict, List

from financial_news_scraper import FinancialAggregator, InflationCalculator
from semantic_ecommerce_search import MultiPlatformSearchManager

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SmartRecommendationEngine:
    """
    AI-powered recommendation engine combining:
    - Product data from 6+ e-commerce platforms
    - Financial news & economic indicators
    - Government procurements
    - Inflation calculations
    - User preferences & history
    """

    def __init__(self):
        self.ecommerce_manager = MultiPlatformSearchManager()
        self.financial_agg = FinancialAggregator()
        self.inflation_calc = InflationCalculator()

    async def get_smart_recommendations(
        self,
        user_query: str,
        user_budget: float,
        user_preferences: Dict[str, Any] | None = None,
    ) -> Dict[str, Any]:
        """
        Get smart recommendations considering:
        1. Product availability & pricing
        2. Current inflation trends
        3. Economic conditions
        4. Recent financial news
        5. User preferences
        """
        try:
            logger.info(
                f"Generating smart recommendations for: {user_query}"
            )

            # Parallel data collection
            products_task = (
                self.ecommerce_manager.semantic_search(user_query, limit=15)
            )
            financial_task = self.financial_agg.get_financial_dashboard()

            products_data, financial_data = await asyncio.gather(
                products_task, financial_task
            )

            if not products_data.get('success'):
                return {
                    'success': False,
                    'error': 'Failed to fetch products',
                }

            # Filter by budget
            affordable_products = [
                p for p in products_data['results']
                if self._extract_price(p.get('price', '0')) <= user_budget
            ]

            # Apply inflation adjustment
            inflation_recommendations = (
                self.inflation_calc.generate_product_recommendations(
                    user_budget,
                )
            )

            # Score products based on multiple factors
            scored_products = [
                {
                    **product,
                    'buy_recommendation': self._calculate_buy_score(
                        product, inflation_recommendations
                    ),
                    'urgency': self._calculate_urgency(
                        product, inflation_recommendations
                    ),
                }
                for product in affordable_products[:10]
            ]

            # Sort by recommendation score
            scored_products.sort(
                key=lambda x: x['buy_recommendation'],
                reverse=True,
            )

            # Generate comprehensive recommendation
            recommendation_summary = (
                self._generate_recommendation_summary(
                    scored_products,
                    financial_data,
                    inflation_recommendations,
                )
            )

            return {
                'success': True,
                'user_query': user_query,
                'user_budget': user_budget,
                'timestamp': datetime.now().isoformat(),
                'recommended_products': scored_products[:5],
                'economic_context': {
                    'inflation_rate': (
                        self.inflation_calc.CURRENT_INFLATION_RATE
                    ),
                    'inflation_trend': (
                        self.inflation_calc._calculate_trend()
                    ),
                    'recommendation': (
                        inflation_recommendations['recommendations'][0]
                        if inflation_recommendations['recommendations']
                        else {}
                    ),
                },
                'financial_news': financial_data.get('financial_news', [])[:3],
                'relevant_government_opportunities': (
                    financial_data.get('government_tenders', [])[:2]
                ),
                'summary': recommendation_summary,
            }

        except Exception as e:
            logger.error(f"Recommendation generation error: {e}")
            return {'success': False, 'error': str(e)}

    async def get_business_planning_insights(
        self,
        business_type: str,
        location: str,
        investment_amount: float,
    ) -> Dict[str, Any]:
        """
        Get business planning insights:
        - Market opportunities
        - Government schemes & tenders
        - Investment recommendations
        - Economic outlook
        """
        try:
            logger.info(
                f"Generating business insights for: {business_type}"
            )

            # Fetch financial & government data
            financial_data = (
                await self.financial_agg.get_financial_dashboard()
            )

            # Filter relevant government tenders for the business type
            relevant_tenders = [
                t for t in financial_data.get('government_tenders', [])
                if business_type.lower() in t.get('title', '').lower()
            ]

            # Calculate ROI considering inflation
            roi_analysis = self._analyze_roi_with_inflation(
                investment_amount
            )

            # Get economic indicators
            indicators = self.inflation_calc.get_economic_indicators()

            return {
                'success': True,
                'business_type': business_type,
                'location': location,
                'investment_amount': investment_amount,
                'economic_context': {
                    'repo_rate': indicators['rbi_repo_rate'],
                    'inflation': indicators['current_inflation'],
                    'inflation_trend': indicators['inflation_trend'],
                },
                'government_opportunities': {
                    'available_tenders': len(relevant_tenders),
                    'top_tenders': relevant_tenders[:3],
                    'total_tender_value': sum(
                        self._extract_price(
                            t.get('tender_value', '0')
                        )
                        for t in relevant_tenders
                    ),
                },
                'roi_analysis': roi_analysis,
                'market_news': (
                    financial_data.get('financial_news', [])[:3]
                ),
                'timestamp': datetime.now().isoformat(),
            }

        except Exception as e:
            logger.error(f"Business insights error: {e}")
            return {'success': False, 'error': str(e)}

    def _extract_price(self, price_str: str) -> float:
        """Extract numeric price from string"""
        import re
        price_match = re.search(r'[\d,]+\.?\d*', price_str.replace(',', ''))
        return float(price_match.group()) if price_match else 0

    def _calculate_buy_score(
        self,
        product: Dict[str, Any],
        inflation_rec: Dict[str, Any],
    ) -> float:
        """Calculate recommendation score for a product"""
        score = 0.0

        # Relevance score (from semantic search)
        score += product.get('relevance_score', 0) * 0.3

        # Rating bonus
        try:
            rating = float(
                str(product.get('rating', '0')).split()[0]
            )
            score += (rating / 5) * 100 * 0.3
        except (ValueError, IndexError):
            pass

        # Inflation urgency bonus
        if (
            any(
                'NOW' in str(r.get('action', ''))
                for r in inflation_rec.get('recommendations', [])
            )
            and product.get('source') != 'olx'
        ):
            score += 20

        return score

    def _calculate_urgency(
        self,
        product: Dict[str, Any],
        inflation_rec: Dict[str, Any],
    ) -> str:
        """Determine purchase urgency"""
        inflation_urgency = [
            r.get('urgency', 'MEDIUM')
            for r in inflation_rec.get('recommendations', [])
        ]

        if 'HIGH' in inflation_urgency:
            return 'BUY_NOW'
        elif 'MEDIUM' in inflation_urgency:
            return 'CONSIDER'
        else:
            return 'CAN_WAIT'

    def _generate_recommendation_summary(
        self,
        products: List[Dict[str, Any]],
        financial_data: Dict[str, Any],
        inflation_rec: Dict[str, Any],
    ) -> str:
        """Generate human-readable recommendation summary"""
        if not products:
            return 'No products found within your budget.'

        top_product = products[0]
        inflation_action = (
            inflation_rec.get('recommendations', [{}])[0]
            .get('action', 'CONSULT EXPERT')
        )

        summary = f"""
**Top Recommendation:** {top_product.get('title', 'N/A')}
**Price:** {top_product.get('price', 'N/A')}
**Source:** {top_product.get('source', 'N/A').upper()}
**Rating:** {top_product.get('rating', 'N/A')}
**Relevance Score:** {top_product.get('relevance_score', 0):.1f}/100

**Economic Analysis:**
- Current Inflation: {self.inflation_calc.CURRENT_INFLATION_RATE}%
- Inflation Action: {inflation_action}
- Trend: {self.inflation_calc._calculate_trend()}

**Advice:** {self._get_shopping_advice(products, inflation_rec)}
"""
        return summary.strip()

    def _get_shopping_advice(
        self,
        products: List[Dict[str, Any]],
        inflation_rec: Dict[str, Any],
    ) -> str:
        """Generate shopping advice"""
        if inflation_rec.get('loss_percentage', 0) > 5:
            return (
                'High inflation detected. Consider buying essential items now '
                'to lock in current prices. Defer non-essential purchases.'
            )
        elif (
            any(
                p.get('source') == 'olx'
                for p in products
            )
        ):
            return (
                'Secondhand options available on OLX. Compare with new items '
                'for better value.'
            )
        else:
            return (
                'Multiple marketplace options available. Best price is typically '
                'on the listed platform. Check for warranty & return policies.'
            )

    def _analyze_roi_with_inflation(
        self,
        investment: float,
    ) -> Dict[str, Any]:
        """Analyze ROI considering inflation"""
        inflation_rate = self.inflation_calc.CURRENT_INFLATION_RATE / 100

        scenarios = {
            '5_percent_return': {
                'return_rate': 0.05,
                'real_return': 0.05 - inflation_rate,
                'real_roi': investment * (0.05 - inflation_rate),
            },
            '10_percent_return': {
                'return_rate': 0.10,
                'real_return': 0.10 - inflation_rate,
                'real_roi': investment * (0.10 - inflation_rate),
            },
            '15_percent_return': {
                'return_rate': 0.15,
                'real_return': 0.15 - inflation_rate,
                'real_roi': investment * (0.15 - inflation_rate),
            },
        }

        best_scenario = max(
            scenarios.items(),
            key=lambda x: x[1]['real_roi'],
        )

        return {
            'investment_amount': investment,
            'current_inflation': (
                self.inflation_calc.CURRENT_INFLATION_RATE
            ),
            'scenarios': scenarios,
            'recommendation': (
                f"Target {best_scenario[0].replace('_', ' ')
                .replace(' percent', '%')} return to beat inflation"
            ),
        }


if __name__ == '__main__':
    async def test():
        engine = SmartRecommendationEngine()

        print('--- Smart Shopping Recommendation ---')
        rec = await engine.get_smart_recommendations(
            'laptop',
            budget=50000,
        )
        print(json.dumps(rec, indent=2))

        print('\n--- Business Planning Insights ---')
        insights = await engine.get_business_planning_insights(
            'software-development',
            'bangalore',
            investment_amount=1000000,
        )
        print(json.dumps(insights, indent=2))

    asyncio.run(test())
