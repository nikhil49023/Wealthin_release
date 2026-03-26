#!/usr/bin/env python3
"""
Flask API for Wealthin Marketplace Scraper
Provides REST endpoints for Flutter app to query marketplace data
"""

import asyncio
import json
import logging
from datetime import datetime
from functools import wraps
from typing import Any, Dict

from flask import Flask, jsonify, request
from flask_cors import CORS

from marketplace_scraper import MarketplaceScraperManager
from semantic_ecommerce_search import (
    MultiPlatformSearchManager,
    SemanticSearchEngine,
)
from financial_news_scraper import (
    FinancialAggregator,
    InflationCalculator,
)
from smart_recommendation_engine import SmartRecommendationEngine

app = Flask(__name__)
CORS(app)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global service managers
scraper_manager = MarketplaceScraperManager()
semantic_search_manager = MultiPlatformSearchManager()
recommendation_engine = SmartRecommendationEngine()
financial_agg = FinancialAggregator()
inflation_calc = InflationCalculator()


def async_route(f):
    """Decorator to handle async route functions"""
    @wraps(f)
    def wrapped(*args, **kwargs):
        return asyncio.run(f(*args, **kwargs))

    return wrapped


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'Wealthin Marketplace Scraper API',
        'version': '1.0.0',
    }), 200


@app.route('/api/search/products', methods=['POST'])
@async_route
async def search_products():
    """
    Search products across all marketplaces
    
    Request body:
    {
        "query": "laptop",
        "limit": 5
    }
    """
    try:
        data = request.get_json() or {}
        query = data.get('query', '')
        limit = min(data.get('limit', 5), 20)

        if not query:
            return jsonify({'error': 'Query parameter required'}), 400

        logger.info(f"Searching products: {query} (limit: {limit})")
        results = await scraper_manager.search_all_products(query, limit)

        return jsonify({
            'success': True,
            'query': query,
            'results': results,
            'total_results': sum(
                len(v) for v in results.values() if isinstance(v, list)
            ),
        }), 200

    except Exception as e:
        logger.error(f"Product search error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/search/businesses', methods=['POST'])
@async_route
async def search_businesses():
    """
    Search businesses across all directories
    
    Request body:
    {
        "category": "electronics-retailers",
        "location": "bangalore",
        "limit": 10
    }
    """
    try:
        data = request.get_json() or {}
        category = data.get('category', '')
        location = data.get('location', '')
        limit = min(data.get('limit', 10), 30)

        if not category or not location:
            return jsonify({
                'error': 'Category and location parameters required'
            }), 400

        logger.info(
            f"Searching businesses: {category} in {location} (limit: {limit})"
        )
        results = await scraper_manager.search_all_businesses(
            category, location, limit
        )

        return jsonify({
            'success': True,
            'category': category,
            'location': location,
            'results': results,
            'total_results': sum(
                len(v) for v in results.values() if isinstance(v, list)
            ),
        }), 200

    except Exception as e:
        logger.error(f"Business search error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/search/amazon/products', methods=['POST'])
@async_route
async def search_amazon_products():
    """Search only Amazon"""
    try:
        data = request.get_json() or {}
        query = data.get('query', '')
        limit = min(data.get('limit', 10), 20)

        if not query:
            return jsonify({'error': 'Query required'}), 400

        logger.info(f"Searching Amazon: {query}")
        products = await scraper_manager.amazon.search_products(query, limit)

        return jsonify({
            'success': True,
            'source': 'amazon',
            'query': query,
            'products': products,
            'count': len(products),
        }), 200

    except Exception as e:
        logger.error(f"Amazon search error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/search/indiamart/products', methods=['POST'])
@async_route
async def search_indiamart_products():
    """Search only IndiaMART"""
    try:
        data = request.get_json() or {}
        query = data.get('query', '')
        limit = min(data.get('limit', 10), 20)

        if not query:
            return jsonify({'error': 'Query required'}), 400

        logger.info(f"Searching IndiaMART: {query}")
        products = await scraper_manager.indiamart.search_products(query, limit)

        return jsonify({
            'success': True,
            'source': 'indiamart',
            'query': query,
            'products': products,
            'count': len(products),
        }), 200

    except Exception as e:
        logger.error(f"IndiaMART search error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/search/justdial/businesses', methods=['POST'])
@async_route
async def search_justdial_businesses():
    """Search only JustDial"""
    try:
        data = request.get_json() or {}
        category = data.get('category', '')
        location = data.get('location', '')
        limit = min(data.get('limit', 15), 30)

        if not category or not location:
            return jsonify({
                'error': 'Category and location required'
            }), 400

        logger.info(f"Searching JustDial: {category} in {location}")
        businesses = await scraper_manager.justdial.search_businesses(
            category, location
        )

        return jsonify({
            'success': True,
            'source': 'justdial',
            'category': category,
            'location': location,
            'businesses': businesses,
            'count': len(businesses),
        }), 200

    except Exception as e:
        logger.error(f"JustDial search error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/source-info', methods=['GET'])
def source_info():
    """Information about all data sources"""
    return jsonify({
        'traditional_sources': {
            'amazon': {
                'name': 'Amazon India',
                'type': 'e-commerce',
                'products': True,
                'url': 'https://amazon.in',
            },
            'indiamart': {
                'name': 'IndiaMART',
                'type': 'B2B marketplace',
                'products': True,
                'url': 'https://indiamart.com',
            },
            'justdial': {
                'name': 'JustDial',
                'type': 'Business directory',
                'url': 'https://justdial.com',
            },
        },
        'expanded_sources': {
            'flipkart': {
                'name': 'Flipkart',
                'type': 'e-commerce',
            },
            'ebay': {
                'name': 'eBay India',
                'type': 'e-commerce',
            },
            'olx': {
                'name': 'OLX',
                'type': 'Classifieds',
            },
            'aliexpress': {
                'name': 'AliExpress',
                'type': 'International',
            },
        },
    }), 200


@app.route('/api/semantic-search', methods=['POST'])
@async_route
async def semantic_search():
    """
    Semantic search across multiple e-commerce platforms
    Deduplicates and ranks results by relevance
    
    Request body:
    {
        "query": "laptop",
        "limit": 20
    }
    """
    try:
        data = request.get_json() or {}
        query = data.get('query', '')
        limit = min(data.get('limit', 20), 50)

        if not query:
            return jsonify({'error': 'Query required'}), 400

        logger.info(f"Semantic search: {query}")
        result = await semantic_search_manager.semantic_search(
            query, limit
        )

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Semantic search error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/financial-dashboard', methods=['GET'])
@async_route
async def financial_dashboard():
    """
    Get comprehensive financial dashboard
    Includes: news, government tenders, economic indicators
    """
    try:
        logger.info("Fetching financial dashboard")
        dashboard = await financial_agg.get_financial_dashboard()
        return jsonify(dashboard), 200

    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/inflation-calculator', methods=['POST'])
def inflation_calculator():
    """
    Calculate inflation impact on prices and savings
    
    Request body:
    {
        "type": "future_price",  # or "real_value", "savings_impact"
        "amount": 50000,
        "years": 1
    }
    """
    try:
        data = request.get_json() or {}
        calc_type = data.get('type', 'future_price')
        amount = float(data.get('amount', 0))
        years = int(data.get('years', 1))

        if not amount:
            return jsonify({'error': 'Amount required'}), 400

        logger.info(f"Inflation calculation: {calc_type}")

        result = {
            'calculation_type': calc_type,
            'timestamp': datetime.now().isoformat(),
        }

        if calc_type == 'future_price':
            result['data'] = inflation_calc.estimate_future_price(
                amount, years
            )
        elif calc_type == 'real_value':
            result['data'] = inflation_calc.calculate_real_value(
                amount, years
            )
        elif calc_type == 'savings_impact':
            result['data'] = inflation_calc.calculate_savings_real_value(
                amount, years
            )
        else:
            return jsonify({'error': 'Invalid calculation type'}), 400

        result['current_inflation'] = (
            inflation_calc.CURRENT_INFLATION_RATE
        )
        result['economic_indicators'] = (
            inflation_calc.get_economic_indicators()
        )

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Inflation calculation error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/smart-recommendations', methods=['POST'])
@async_route
async def smart_recommendations():
    """
    Get smart recommendations combining all data sources
    Considers: products, pricing, inflation, economic conditions
    
    Request body:
    {
        "query": "laptop",
        "budget": 50000,
        "preferences": {}
    }
    """
    try:
        data = request.get_json() or {}
        query = data.get('query', '')
        budget = float(data.get('budget', 100000))
        preferences = data.get('preferences', {})

        if not query:
            return jsonify({'error': 'Query required'}), 400

        logger.info(f"Smart recommendation: {query}")
        result = await recommendation_engine.get_smart_recommendations(
            query, budget, preferences
        )

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Recommendation error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/business-insights', methods=['POST'])
@async_route
async def business_insights():
    """
    Get business planning insights
    Includes: government tenders, ROI analysis, market trends
    
    Request body:
    {
        "business_type": "software-development",
        "location": "bangalore",
        "investment": 1000000
    }
    """
    try:
        data = request.get_json() or {}
        business_type = data.get('business_type', '')
        location = data.get('location', '')
        investment = float(data.get('investment', 0))

        if not business_type or not location:
            return jsonify({
                'error': 'business_type and location required'
            }), 400

        logger.info(f"Business insights: {business_type}")
        result = await recommendation_engine.get_business_planning_insights(
            business_type, location, investment
        )

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Business insights error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/economic-indicators', methods=['GET'])
def economic_indicators():
    """Get current economic indicators"""
    try:
        indicators = inflation_calc.get_economic_indicators()
        return jsonify({
            'success': True,
            'indicators': indicators,
            'timestamp': datetime.now().isoformat(),
        }), 200

    except Exception as e:
        logger.error(f"Indicators error: {e}")
        return jsonify({'error': str(e)}), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    logger.info("Starting Wealthin Marketplace Scraper API...")
    app.run(host='0.0.0.0', port=5001, debug=False)
