# 🚀 Quick API Examples - Semantic Search & Financial Intelligence

**All examples use `http://localhost:5001` | Flask API running**

---

## 1️⃣ Semantic Search Across 7 Platforms

### Request
```bash
curl -X POST http://localhost:5001/api/semantic-search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "gaming laptop",
    "limit": 5
  }'
```

### Response
```json
{
  "query": "gaming laptop",
  "platforms_searched": 7,
  "total_results": 45,
  "unique_products": 12,
  "deduplication_rate": "73.3%",
  "results": [
    {
      "title": "ASUS TUF Gaming F15 RTX 3060",
      "price": "₹89,999",
      "source": "flipkart",
      "also_available_on": ["amazon", "ebay"],
      "rating": 4.6,
      "relevance_score": 96.5,
      "relevance_reason": "Exact match: gaming + laptop"
    },
    {
      "title": "Dell G15 with RTX 3050",
      "price": "₹72,500",
      "source": "amazon",
      "also_available_on": ["ebay_india", "flipkart"],
      "rating": 4.4,
      "relevance_score": 95.2
    }
  ]
}
```

**What's Different from Google Search:**
- ✅ Searches 7 platforms in parallel (5-9 seconds)
- ✅ Intelligently deduplicates same product across sites
- ✅ Shows price differences (ASUS: ₹89,999 vs ₹91,000)
- ✅ Relevance ranked (gaming laptop is 96+ vs random laptop 40)

---

## 2️⃣ Smart Shopping Recommendations

### Request
```bash
curl -X POST http://localhost:5001/api/smart-recommendations \
  -H "Content-Type: application/json" \
  -d '{
    "query": "laptop",
    "budget": 50000,
    "preferences": {
      "brand": "ASUS OR Dell",
      "screen_size": "15.6"
    }
  }'
```

### Response
```json
{
  "recommended_products": [
    {
      "rank": 1,
      "title": "ASUS VivoBook 15",
      "price": "₹45,999",
      "source": "ebay",
      "rating": 4.5,
      "relevance_score": 94.2,
      "relevance_breakdown": {
        "title_match": 95,
        "rating_bonus": 45,
        "inflation_urgency": 85,
        "final_score": 94.2
      },
      "buy_recommendation": "BUY_NOW",
      "urgency_level": "HIGH"
    }
  ],
  "economic_context": {
    "inflation_rate": 5.4,
    "inflation_trend": "RISING ⬆️",
    "rbi_trend": "Tight money policy"
  },
  "financial_news": [
    {
      "source": "Economic Times",
      "headline": "Laptop prices likely to rise due to semiconductor shortage",
      "date": "2024-01-15",
      "relevance": "CRITICAL"
    }
  ],
  "summary": "✅ ASUS VivoBook 15 (₹45,999) strongly recommended. HIGH URGENCY - Inflation rising at 5.4%. Laptop prices likely to increase 3-5% in next 6 months (₹1,380-₹2,300 more). Buy now to save money.",
  "inflation_impact": {
    "today": "₹45,999",
    "after_6_months": "₹47,499 (estimated)",
    "savings_by_buying_now": "₹1,500"
  }
}
```

**Why This Matters:**
- Smart ranking combines relevance (is it actually what you want?) + ratings (is it good?) + inflation (should you buy now?)
- Example: High relevance (95) + inflation urgency (85) + rating (4.5) = BUY_NOW
- Explains in human language: "Buy now to save ₹1,500 before prices rise"

---

## 3️⃣ Inflation Calculator

### Request A: Real Value of Savings
```bash
curl -X POST http://localhost:5001/api/inflation-calculator \
  -H "Content-Type: application/json" \
  -d '{
    "type": "real_value",
    "amount": 100000,
    "years": 1,
    "inflation_rate": 5.4
  }'
```

### Response A
```json
{
  "calculation": "real_value",
  "input": {
    "amount": 100000,
    "years": 1,
    "inflation_rate": 5.4
  },
  "output": {
    "nominal_amount": "₹100,000",
    "real_value": "₹94,888",
    "loss_of_purchasing_power": "₹5,112",
    "percentage_loss": 5.11
  },
  "interpretation": "Your ₹100,000 in savings will have the purchasing power of ₹94,888 after 1 year due to 5.4% inflation. You lose ₹5,112 in buying power."
}
```

### Request B: Future Price Estimation
```bash
curl -X POST http://localhost:5001/api/inflation-calculator \
  -H "Content-Type: application/json" \
  -d '{
    "type": "future_price",
    "amount": 50000,  # Today's price
    "years": 1,
    "inflation_rate": 5.4
  }'
```

### Response B
```json
{
  "calculation": "future_price",
  "output": {
    "today_price": "₹50,000",
    "future_price": "₹52,700",
    "price_increase": "₹2,700",
    "percentage_increase": 5.4
  },
  "interpretation": "The laptop costing ₹50,000 today will cost ₹52,700 in 1 year due to 5.4% inflation."
}
```

### Request C: Savings Impact
```bash
curl -X POST http://localhost:5001/api/inflation-calculator \
  -H "Content-Type: application/json" \
  -d '{
    "type": "savings_impact",
    "amount": 500000,
    "interest_rate": 6.5,  # Bank savings account
    "inflation_rate": 5.4,
    "years": 1
  }'
```

### Response C
```json
{
  "calculation": "savings_impact",
  "output": {
    "principal": "₹500,000",
    "interest_earned": "₹32,500",
    "inflation_loss": "₹27,000",
    "net_gain": "₹5,500",
    "real_return": 1.1
  },
  "interpretation": "Your bank account earning 6.5% interest will gain ₹5,500 in real purchasing power after accounting for 5.4% inflation (net gain: 1.1%)."
}
```

**Use Cases:**
- **Student**: "Will my laptop still be affordable in 6 months?" → Uses future_price
- **Investor**: "Is 6.5% savings rate enough?" → Uses savings_impact  
- **Saver**: "How much purchasing power will I lose?" → Uses real_value

---

## 4️⃣ Financial Dashboard

### Request
```bash
curl http://localhost:5001/api/financial-dashboard
```

### Response (Abbreviated)
```json
{
  "current_time": "2024-01-15T10:30:00",
  "economic_indicators": {
    "rbi_repo_rate": 6.5,
    "reverse_repo_rate": 6.25,
    "inflation_rate": 5.4,
    "inflation_trend": "RISING ⬆️",
    "cpi_forecast_next_quarter": "5.6%"
  },
  "financial_news": [
    {
      "source": "Economic Times",
      "headline": "RBI holds rates steady amid inflation concerns",
      "date": "2024-01-15",
      "impact": "Prices likely to remain high"
    },
    {
      "source": "CNBC-TV18",
      "headline": "Tech stocks surge on AI optimism",
      "date": "2024-01-15"
    }
  ],
  "government_tenders": {
    "active_tenders": 156,
    "total_value": "₹45,000 Crore",
    "recent_tenders": [
      {
        "title": "Ministry of IT: Digital Transformation Project",
        "value": "₹200 Crore",
        "deadline": "2024-04-15",
        "category": "Software Development"
      }
    ]
  },
  "ministry_orders": [
    {
      "ministry": "Ministry of Finance",
      "order": "GST rate changes on essential items",
      "date": "2024-01-10",
      "impact": "Prices likely to decrease 5-8%"
    }
  ]
}
```

---

## 5️⃣ Economic Indicators

### Request
```bash
curl http://localhost:5001/api/economic-indicators
```

### Response
```json
{
  "rbi_rates": {
    "repo_rate": 6.5,
    "reverse_repo_rate": 6.25,
    "slr": 18.0,
    "crr": 4.5,
    "last_updated": "2024-01-10"
  },
  "inflation": {
    "current_cpi": 5.4,
    "previous_quarter": 5.2,
    "trend": "RISING ⬆️",
    "forecast_next_quarter": 5.6,
    "forecast_confidence": 0.87
  },
  "currency": {
    "usd_to_inr": 83.15,
    "change_today": -0.05,
    "trend": "STABLE"
  },
  "forecast": {
    "inflation_outlook": "RISING",
    "rate_outlook": "HOLD",
    "economic_growth": 7.2,
    "unemployment": 3.4
  }
}
```

---

## 6️⃣ Business Planning Insights

### Request
```bash
curl -X POST http://localhost:5001/api/business-insights \
  -H "Content-Type: application/json" \
  -d '{
    "business_type": "software-development",
    "location": "bangalore",
    "investment": 1000000
  }'
```

### Response
```json
{
  "business_opportunity_analysis": {
    "current_opportunity": "EXCELLENT",
    "market_demand": "High",
    "investment_ready": true
  },
  "government_tenders": {
    "matching_opportunities": [
      {
        "tender_id": "GoIT-2024-001",
        "title": "Digital Transformation - Ministry of IT",
        "value": "₹2 Crore",
        "your_chance": 0.70,
        "deadline": "2024-04-15",
        "min_turnover_required": "₹50 Lakh",
        "match_score": "85/100"
      },
      {
        "tender_id": "MinFin-2024-045",
        "title": "Financial Software Platform - Finance Ministry",
        "value": "₹50 Lakh",
        "your_chance": 0.60,
        "deadline": "2024-03-30"
      }
    ]
  },
  "roi_analysis": {
    "investment": "₹10,00,000",
    "scenarios": [
      {
        "year": 1,
        "revenue": "₹20,00,000",
        "profit": "₹6,00,000",
        "roi_percent": 60,
        "roi_with_inflation": "54.6%",
        "assessment": "EXCELLENT"
      }
    ]
  },
  "economic_outlook": {
    "inflation_impact": "₹60,000 salary inflation expected in year 1",
    "interest_rate_impact": "Higher borrowing costs (repo at 6.5%)",
    "overall_outlook": "FAVORABLE for software services"
  },
  "recommendation": "✅ PROCEED - ₹10 Lakh investment has strong ROI (54.6% real return). 3 matching government tenders worth ₹2.5+ Crore. Timing good despite inflation."
}
```

**What This Tells You:**
- ✅ Government tender matches (worth ₹2.5 Crore!)
- ✅ 60% ROI in year 1 (even after inflation: 54.6%)
- ✅ Inflation will add ₹60K salary costs, but margins strong
- ✅ Market demand high, lending rates reasonable
- **Decision: Invest now**

---

## 7️⃣ Source Info

### Request
```bash
curl http://localhost:5001/api/source-info
```

### Response
```json
{
  "ecommerce_platforms": [
    {
      "name": "Amazon India",
      "url": "amazon.in",
      "categories": ["electronics", "home", "beauty"],
      "avg_products_per_category": 10000,
      "scrape_frequency": "real-time"
    },
    {
      "name": "Flipkart",
      "url": "flipkart.com",
      "categories": ["electronics", "fashion", "home"]
    },
    {
      "name": "eBay India",
      "url": "ebay.in",
      "categories": ["electronics", "collectibles", "arts"]
    },
    {
      "name": "OLX",
      "url": "olx.in",
      "categories": ["classifieds", "used-items", "local-deals"]
    },
    {
      "name": "AliExpress",
      "url": "aliexpress.com",
      "categories": ["wholesale", "international", "bulk"]
    },
    {
      "name": "IndiaMART",
      "url": "indiamart.com",
      "categories": ["b2b", "wholesale", "suppliers"]
    },
    {
      "name": "JustDial",
      "url": "justdial.com",
      "categories": ["services", "local-businesses", "phone"]
    }
  ],
  "financial_sources": [
    {
      "name": "Economic Times",
      "type": "Business News",
      "update_frequency": "Hourly"
    },
    {
      "name": "CNBC-TV18",
      "type": "Market News",
      "update_frequency": "Continuous"
    },
    {
      "name": "RBI Official",
      "type": "Central Bank Data",
      "update_frequency": "Daily"
    }
  ],
  "government_sources": [
    {
      "name": "GeM",
      "type": "Government e-Marketplace",
      "tenders_updated": "Real-time"
    },
    {
      "name": "Ministry of Commerce",
      "type": "Government Orders",
      "update_frequency": "Daily"
    },
    {
      "name": "Ministry of Finance",
      "type": "Economic Policies",
      "update_frequency": "Daily"
    },
    {
      "name": "Ministry of Labor",
      "type": "Employment Policies",
      "update_frequency": "Weekly"
    }
  ]
}
```

---

## 🔗 API Endpoint Summary

| Endpoint | Method | Purpose | Speed |
|----------|--------|---------|-------|
| `/api/semantic-search` | POST | Search 7 platforms | 5-9s |
| `/api/smart-recommendations` | POST | Get best products + advice | 10-17s |
| `/api/inflation-calculator` | POST | Calculate inflation impact | <1s |
| `/api/financial-dashboard` | GET | News + tenders + indicators | 5-8s |
| `/api/economic-indicators` | GET | RBI rates, inflation, forecasts | <1s |
| `/api/business-insights` | POST | Tender matching + ROI | 8-15s |
| `/api/source-info` | GET | Available data sources | <0.5s |

---

## 💻 Python Integration

### Using in Django/Flask Backend
```python
import httpx
import asyncio

async def get_smart_recommendations(query, budget):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "http://localhost:5001/api/smart-recommendations",
            json={"query": query, "budget": budget}
        )
        return response.json()

# Usage
result = asyncio.run(get_smart_recommendations("laptop", 50000))
print(result['summary'])  # Human-readable recommendation
```

### Using in Dart/Flutter
```dart
void getSmartRecommendations() async {
  final response = await http.post(
    Uri.parse('http://localhost:5001/api/smart-recommendations'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'query': 'laptop',
      'budget': 50000,
    }),
  );
  
  final data = jsonDecode(response.body);
  print(data['summary']);  // "ASUS VivoBook 15 recommended..."
}
```

---

## 🎯 Real-World Patterns

### Pattern 1: "Should I buy this now?"
```bash
# Step 1: Check inflation calculator
curl -X POST http://localhost:5001/api/inflation-calculator \
  -d '{"type": "future_price", "amount": 50000, "years": 0.5}'

# Step 2: If price going up significantly, use smart-recommendations
curl -X POST http://localhost:5001/api/smart-recommendations \
  -d '{"query": "laptop 15.6", "budget": 50000}'

# Read summary for: "Buy now - save ₹X before prices rise"
```

### Pattern 2: "What business should I start?"
```bash
# Get economic outlook
curl http://localhost:5001/api/financial-dashboard

# Get business-specific insights
curl -X POST http://localhost:5001/api/business-insights \
  -d '{"business_type": "software-dev", "investment": 1000000}'

# Review government opportunities (GeM tenders worth ₹2+ Crore)
```

### Pattern 3: "Is this investment good?"
```bash
# Check economic indicators
curl http://localhost:5001/api/economic-indicators

# If inflation <6%, use real_value calculator
curl -X POST http://localhost:5001/api/inflation-calculator \
  -d '{"type": "savings_impact", "amount": 500000, "interest_rate": 6.5}'

# Decision: If real return >2%, invest
```

---

## 🚨 Error Handling

### 400 Bad Request
```json
{
  "error": "missing_required_field",
  "message": "query parameter is required for semantic-search",
  "fix": "Add 'query' field to request body"
}
```

### 503 Scraper Unavailable
```json
{
  "error": "scraper_error",
  "message": "Flipkart temporarily unavailable",
  "fallback": "Returning results from 6 other platforms",
  "results_count": 23
}
```

### Timeout (>30 seconds)
```json
{
  "partial_results": true,
  "error": "timeout",
  "platforms_returned": [
    "amazon", "flipkart", "ebay"
  ],
  "platforms_timeout": [
    "olx", "indiamart"
  ],
  "results_count": 18
}
```

---

## 📊 Response Time Guidelines

```
Fast (<2s):
  - /api/economic-indicators ✅
  - /api/source-info ✅

Medium (2-5s):
  - /api/inflation-calculator ✅
  - /api/financial-dashboard (if cached) ✅

Slow (5-10s):
  - /api/semantic-search (7 platforms) ⏳
  - /api/financial-dashboard (fresh) ⏳

Very Slow (10-20s):
  - /api/smart-recommendations ⏳⏳
  - /api/business-insights ⏳⏳

Tips:
  - Cache economic indicators (update 1x/hour)
  - Run semantic search in background
  - Use partial results if timeout
```

---

**Ready to build? Start with:**
1. Smart recommendations for shopping
2. Inflation calculator for decisions  
3. Business insights for planning

**All running at `http://localhost:5001` 🚀**
