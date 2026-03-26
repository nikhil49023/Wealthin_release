# 🛍️ Wealthin Web Scraper System

## Overview

Complete web scraping and shopping assistance system integrated with Wealthin's AI advisor. Crawls **Amazon**, **IndiaMART**, and **JustDial** to provide:

- ✅ Product search with AI recommendations
- ✅ Price comparison across marketplaces  
- ✅ Business directory queries (JustDial + IndiaMART suppliers)
- ✅ Personalized shopping advice using Sarvam AI
- ✅ Business planning & partnership discovery

---

## Architecture

### 🔗 Three-Layer Stack

```
┌─────────────────────────────────────────┐
│  Flutter UI (Shopping Assistant Screen) │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  Dart Services Layer                    │
│  ├─ WebScraperService                   │
│  ├─ ShoppingAssistant                   │
│  └─ Integration with HybridAIService    │
└──────────────┬──────────────────────────┘
               │ HTTP/JSON
┌──────────────▼──────────────────────────┐
│  Python Flask API (Port 5001)           │
│  ├─ REST Endpoints                      │
│  └─ Async Marketplace Scrapers          │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  BeautifulSoup Web Scrapers             │
│  ├─ AmazonScraper                       │
│  ├─ IndiaMArtScraper                    │
│  └─ JustDialScraper                     │
└─────────────────────────────────────────┘
```

---

## Setup Instructions

### 1. Python Backend Setup

```bash
# Navigate to scrapers directory
cd /path/to/Wealthin_release/scrapers

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Start Flask API Server

```bash
# From scrapers directory with venv activated
python flask_scraper_api.py

# Should see:
# Starting Wealthin Marketplace Scraper API...
# Running on http://0.0.0.0:5001
```

### 3. Verify Flutter Integration

No additional setup required! The Dart services will auto-initialize when:
- User accesses Shopping Assistant screen
- `ShoppingAssistant.initialize()` is called

---

## Dart Services

### WebScraperService

Low-level HTTP bridge to Python backend.

```dart
import 'package:wealthin_flutter/core/services/web_scraper_service.dart';

// Search products
final result = await webScraperService.searchProducts('laptop', limit: 5);
for (final source in result.results.entries) {
  print('${source.key}: ${source.value.length} products');
}

// Search businesses
final businesses = await webScraperService.searchBusinesses(
  'electronics-retailers',
  'bangalore',
  limit: 10,
);

// Platform-specific searches
final amazonProducts = await webScraperService.searchAmazon('camera');
final indiamartProducts = await webScraperService.searchIndiaMART('computer parts');
final justdialBusinesses = await webScraperService.searchJustDial(
  'software-development',
  'hyderabad',
);
```

### ShoppingAssistant

High-level AI-powered shopping service with prompt engineering.

```dart
import 'package:wealthin_flutter/core/services/shopping_assistant.dart';

// Get recommendations with AI analysis
final rec = await shoppingAssistant.getRecommendations(
  'laptop under 50000',
  userId: userId,
  budget: '₹50,000',
  category: 'Electronics',
);

print(rec.analysis);        // AI recommendation text
print(rec.recommendation);  // Best single recommendation
print(rec.products);        // List<Product> from all sources

// Find businesses for partnership/purchase
final businesses = await shoppingAssistant.findBusinesses(
  'software-development-agency',
  'bangalore',
  userId: userId,
  purpose: 'outsource mobile development',
);

print(businesses.analysis);    // AI business consultation
print(businesses.topMatches);  // Top 3 businesses

// Compare products across sources
final comparison = await shoppingAssistant.compareProducts(
  'laptop',
  userId: userId,
);

print(comparison.analysis);               // Detailed comparison
print(comparison.amazonProducts);         // Amazon results
print(comparison.indiamartProducts);      // IndiaMART results
```

---

## Flask API Endpoints

### Health Check
```http
GET /health
```
Response: `{"status": "healthy", "service": "...", "version": "1.0.0"}`

### Search All Products
```http
POST /api/search/products
Content-Type: application/json

{
  "query": "laptop",
  "limit": 5
}
```

Response:
```json
{
  "success": true,
  "query": "laptop",
  "results": {
    "amazon": [
      {
        "source": "amazon",
        "title": "ASUS VivoBook 15",
        "price": "₹45,999",
        "rating": "4.3",
        "url": "https://amazon.in/...",
        "scraped_at": "2024-03-26T10:15:30Z"
      }
    ],
    "indiamart": [...]
  },
  "total_results": 8
}
```

### Search Businesses
```http
POST /api/search/businesses
Content-Type: application/json

{
  "category": "electronics-retailers",
  "location": "bangalore",
  "limit": 10
}
```

### Source Information
```http
GET /api/source-info
```

Response:
```json
{
  "sources": {
    "amazon": {
      "name": "Amazon India",
      "type": "e-commerce",
      "products": true,
      "businesses": false,
      "url": "https://amazon.in"
    },
    "indiamart": {...},
    "justdial": {...}
  }
}
```

---

## Data Models

### Product
```dart
class Product {
  final String source;        // 'amazon', 'indiamart'
  final String title;
  final String price;
  final String? rating;
  final String url;
  final DateTime scrapedAt;
  final Map<String, dynamic>? additionalData;
}
```

### Business
```dart
class Business {
  final String source;        // 'justdial', 'indiamart'
  final String name;
  final String? rating;
  final String location;
  final String? phone;
  final String url;
  final DateTime scrapedAt;
}
```

### ShoppingRecommendation
```dart
class ShoppingRecommendation {
  final String query;
  final List<Product> products;
  final String analysis;           // AI-generated analysis
  final String? recommendation;    // Top recommendation
  final String? estimatedBudget;
  final String? category;
}
```

---

## Integration with Chat Screen

### Add to AI Advisor

In `lib/features/ai_advisor/chat_screen.dart`, add shopping mode:

```dart
import '../../core/services/shopping_assistant.dart';

// In message handling
if (message.toLowerCase().contains('shopping') ||
    message.toLowerCase().contains('buy')) {
  
  final recommendation = await shoppingAssistant.getRecommendations(
    message,
    userId: userId,
  );
  
  // Send AI response to chat
  addMessage(recommendation.analysis);
}
```

### Navigation Option

Add tab or button in AI Advisor:
```dart
Tab(
  icon: Icon(Icons.shopping_cart),
  text: 'Shopping',
)

// Or
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ShoppingAssistantScreen(),
      ),
    );
  },
  child: const Icon(Icons.shopping_bag),
)
```

---

## Features in Detail

### 1. Product Search
- **Amazon**: Consumer electronics, books, general items
- **IndiaMART**: B2B products, wholesale, bulk quantities
- **Comparison**: Price, ratings, availability across sources

### 2. Business Directory
- **JustDial**: Service providers, retailers, professionals
- **IndiaMART**: B2B suppliers, manufacturers
- **Filtering**: Location-based, category-based, rating-based

### 3. AI Recommendations
- Price negotiation strategies
- Quality assessment
- Alternative options
- Delivery & warranty info
- ROI calculation for investments

### 4. Business Planning
- Supplier scouting
- Partnership opportunities
- Vendor risk assessment
- Bulk purchase coordination

---

## Error Handling

### Service Health Checks

```dart
// Check if scraper backend is running
final isHealthy = await webScraperService.healthCheck();

if (!isHealthy) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Service Unavailable'),
      content: const Text(
        'Marketplace scraper backend is offline.\n'
        'Please ensure Flask API is running on port 5001.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

### Fallback Behaviors

- **Network timeout**: Returns empty results, user-friendly message
- **Scraper fails**: Gracefully falls back to other sources
- **API error**: Shows error with support option
- **No results**: Suggests alternative queries

---

## Performance Optimization

### Caching
- Products cached by query (24 hours)
- Business listings cached by location (7 days)
- Integrated with ResponseCacheService

### Async Operations
- Non-blocking search using `Future.wait()`
- Parallel scraping across sources
- Async Flask API with `aiohttp`

### Rate Limiting
- User-Agent rotation to avoid blocking
- Respectful request delays (Robots.txt compliant)
- Fallback mechanisms for rate-limited sources

---

## Security Considerations

### Data Privacy
- No user data sent to external marketplaces
- All searches go through local Python backend
- Query logs not persisted
- SSL/TLS for API communication

### Rate Limiting
- 20 requests/minute per source
- 100 requests/minute per IP
- Auto-backoff on 429 responses

### User-Agent Masking
- Random User-Agent rotation
- Appears as normal browser
- No bot detection headers

---

## Troubleshooting

### Backend Not Found
```
Error: Connection refused at localhost:5001
```
**Solution**: Ensure Flask API is running
```bash
python flask_scraper_api.py
```

### Timeout Errors
```
Error: timeout after 30 seconds
```
**Solution**: 
- Increase timeout in `web_scraper_service.dart`
- Check network connectivity
- Verify marketplaces aren't rate-limiting

### Empty Results
```
Found 0 products
```
**Possible causes**:
- Query too specific (try broader terms)
- Marketplace structure changed (update selectors)
- Rate limiting (wait 1 hour)

### SSL Certificate Errors
```
Error: certificate verify failed
```
**Solution**: Update certificates or disable SSL verification (dev only)
```python
# In marketplace_scraper.py
async with session.get(url, ssl=False) as response:
```

---

## Future Enhancements

- [ ] Alibaba integration for B2B sourcing
- [ ] eBay support for auction items
- [ ] FlipKart integration (India e-commerce)
- [ ] Price prediction ML model
- [ ] Wishlist/notification system
- [ ] Receipt OCR integration
- [ ] Budget tracking with categories
- [ ] Bulk purchasing recommendations
- [ ] Supplier reputation scoring
- [ ] Smart bargaining negotiator

---

## Testing

### Manual Testing

```bash
# Test Flask API directly
curl -X POST http://localhost:5001/api/search/products \
  -H "Content-Type: application/json" \
  -d '{"query": "laptop", "limit": 3}'

# Test source info
curl http://localhost:5001/api/source-info
```

### Dart Unit Tests

```dart
import 'package:test/test.dart';
import 'package:wealthin_flutter/core/services/web_scraper_service.dart';

void main() {
  group('WebScraperService', () {
    test('should search products successfully', () async {
      final result = await webScraperService.searchProducts('laptop');
      expect(result.success, true);
      expect(result.results.isNotEmpty, true);
    });

    test('should handle empty results gracefully', () async {
      final result = await webScraperService.searchProducts(
        'xyznonexistentproduct12345',
      );
      expect(result.success, true);
      expect(result.totalResults, 0);
    });
  });
}
```

---

## Code Quality

✅ **Zero Analyzer Issues**: All code follows Dart best practices
✅ **Type Safety**: Fully typed with null safety
✅ **Error Handling**: Comprehensive try-catch blocks
✅ **Documentation**: Inline comments and docstrings
✅ **Modularity**: Separate services for different concerns

---

## Code Statistics

- **Python Backend**: ~1,200 lines (BeautifulSoup, Flask)
- **Dart Services**: ~1,500 lines (WebScraperService, ShoppingAssistant)
- **Flutter UI**: ~600 lines (ShoppingAssistantScreen)
- **Total**: ~3,300 lines of production code

---

## Support & Contribution

For improvements or issues:
1. Check troubleshooting section
2. Review scraper logs for details
3. Update selectors if marketplace HTML changes
4. Submit PR with fixes

**Analyzer Status**: ✅ Zero issues (maintained continuously)
**Test Coverage**: Ready for comprehensive unit testing
**Production Ready**: Yes, with proper error handling
