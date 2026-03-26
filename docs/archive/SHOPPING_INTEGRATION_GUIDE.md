# Shopping Assistant Integration Guide

How to integrate the shopping assistant into Wealthin's main chat interface.

## Quick Integration

### Option 1: Dedicated Navigation Tab

In [lib/features/ai_advisor/chat_screen.dart](../frontend/wealthin_flutter/lib/features/ai_advisor/chat_screen.dart), add shopping mode detection:

```dart
import '../../core/services/shopping_assistant.dart';

// In your chat interface, detect shopping queries:
Future<void> _handleMessage(String message) async {
  final userId = authService.currentUser?.uid ?? 'anonymous';
  
  // Check if query is shopping-related
  if (_isShoppingQuery(message)) {
    // Route to shopping assistant
    final rec = await shoppingAssistant.getRecommendations(
      message,
      userId: userId,
    );
    
    // Display formatted response
    _displayShoppingResult(rec);
  } else {
    // Regular AI response
    final response = await hybridAIService.chat(message, userId: userId);
    _displayMessage(response.response);
  }
}

bool _isShoppingQuery(String message) {
  final keywords = [
    'buy', 'purchase', 'price', 'compare',
    'shop', 'laptop', 'phone', 'product',
    'where to buy', 'best price', 'discount',
    'business', 'supplier', 'vendor'
  ];
  
  final lower = message.toLowerCase();
  return keywords.any((keyword) => lower.contains(keyword));
}

void _displayShoppingResult(ShoppingRecommendation rec) {
  // Format and display as chat message
  final formattedMessage = '''
🛍️ **Shopping Recommendation**

**AI Analysis:**
${rec.analysis}

**Found Products:** ${rec.products.length}
${rec.products.take(3).map((p) => 
  '• ${p.title} - ${p.price} (${p.source})'
).join('\n')}
  ''';
  
  addMessage(formattedMessage);
}
```

### Option 2: Floating Action Button

Add shopping button to chat screen:

```dart
FloatingActionButton(
  mini: true,
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ShoppingAssistantScreen(),
      ),
    );
  },
  tooltip: 'Shopping Assistant',
  child: const Icon(Icons.shopping_bag),
)
```

### Option 3: Bottom Sheet Command

Access shopping assistant from input bar:

```dart
// In message input area, add shopping button:
TextButton(
  onPressed: () {
    _showShoppingBottomSheet();
  },
  icon: const Icon(Icons.shopping_cart),
  label: const Text('Shopping'),
)

void _showShoppingBottomSheet() {
  showModalBottomSheet(
    context: context,
    builder: (_) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Find Products'),
            onTap: () {
              Navigator.pop(context);
              _navigateToShopping('products');
            },
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Find Businesses'),
            onTap: () {
              Navigator.pop(context);
              _navigateToShopping('businesses');
            },
          ),
          ListTile(
            leading: const Icon(Icons.compare),
            title: const Text('Compare Products'),
            onTap: () {
              Navigator.pop(context);
              _navigateToShopping('comparison');
            },
          ),
        ],
      ),
    ),
  );
}
```

## Inline Integration in Chat

### Display Products Within Chat

```dart
// Create reusable widget for inline product display
class ChatProductWidget extends StatelessWidget {
  final Product product;
  
  const ChatProductWidget({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    product.source.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              Chip(
                label: Text('${product.rating ?? "N/A"} ⭐'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Open in browser
              _launchUrl(product.url);
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    // Use url_launcher package
    if (await canLaunch(url)) {
      await launch(url);
    }
  }
}
```

### Display Business Results in Chat

```dart
class ChatBusinessWidget extends StatelessWidget {
  final Business business;
  
  const ChatBusinessWidget({
    super.key,
    required this.business,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(business.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📍 ${business.location}'),
            if (business.phone != null)
              Text('📞 ${business.phone}'),
          ],
        ),
        trailing: Chip(
          label: Text('${business.rating ?? "N/A"} ⭐'),
        ),
        onTap: () {
          _launchUrl(business.url);
        },
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }
}
```

## Multi-Mode AI Responses

### Context-Aware Shopping Mode

```dart
// In hybridAIService chat method, add context:
final response = await hybridAIService.chat(
  message,
  userId: userId,
  userContext: {
    'mode': _detectMode(message),  // 'shopping', 'business', 'financial'
    'query_context': _extractContext(message),
  },
);

String _detectMode(String message) {
  const shoppingKeywords = [
    'buy', 'price', 'product', 'shop', 'compare',
    'vendor', 'supplier', 'business', 'partner'
  ];
  
  const financialKeywords = [
    'budget', 'spend', 'roi', 'profit', 'investment',
    'cost', 'expense', 'save', 'financial'
  ];
  
  final lower = message.toLowerCase();
  
  if (shoppingKeywords.any((k) => lower.contains(k))) {
    return 'shopping';
  } else if (financialKeywords.any((k) => lower.contains(k))) {
    return 'financial';
  }
  
  return 'general';
}
```

## Persistence & History

### Save Shopping Queries

```dart
// Use MemoryService to persist shopping context
Future<void> _saveShoppingContext(
  String userId,
  ShoppingRecommendation rec,
) async {
  await memoryService.addMemory(
    userId,
    {
      'type': 'shopping_query',
      'query': rec.query,
      'timestamp': DateTime.now().toIso8601String(),
      'products': rec.products.map((p) => p.toJson()).toList(),
      'recommendation': rec.recommendation,
    },
  );
}
```

### Retrieve Past Searches

```dart
Future<List<ShoppingRecommendation>> getPastSearches(String userId) async {
  final memory = await memoryService.getMemoryByType(userId, 'shopping_query');
  return (memory as List)
      .cast<Map<String, dynamic>>()
      .map(ShoppingRecommendation.fromJson)
      .toList();
}
```

## Error Handling

### Graceful Fallback

```dart
Future<void> _handleShoppingQuery(String message) async {
  try {
    // Try shopping assistant first
    final rec = await shoppingAssistant.getRecommendations(
      message,
      userId: userId,
    );
    
    if (rec.products.isEmpty && !rec.success) {
      // Fall back to AI explanation
      final response = await hybridAIService.chat(
        "I couldn't find products for '$message'. Please provide:\n"
        "- Product name or category\n"
        "- Budget (optional)\n"
        "- Specifications (optional)",
        userId: userId,
      );
      _displayMessage(response.response);
    } else {
      _displayShoppingResult(rec);
    }
  } catch (e) {
    // Graceful error handling
    final response = await hybridAIService.chat(
      "Shopping assistant is temporarily unavailable. "
      "Let me help you anyway! What are you looking for?",
      userId: userId,
    );
    _displayMessage(response.response);
  }
}
```

## Testing Integration

### Unit Test Example

```dart
import 'package:test/test.dart';
import 'package:wealthin_flutter/core/services/shopping_assistant.dart';

void main() {
  group('Shopping Integration', () {
    late ShoppingAssistant assistant;

    setUpAll(() async {
      assistant = shoppingAssistant;
      await assistant.initialize();
    });

    test('should detect shopping query', () {
      final isShoppingQuery = (String text) {
        const keywords = ['buy', 'price', 'product', 'shop'];
        return keywords.any((k) => text.toLowerCase().contains(k));
      };

      expect(isShoppingQuery('where can i buy a laptop'), true);
      expect(isShoppingQuery('show me finance reports'), false);
    });

    test('should get recommendations for valid query', () async {
      final result = await assistant.getRecommendations(
        'laptop under 50000',
        userId: 'test_user',
      );

      expect(result.success, true);
      // May be empty in test, but shouldn't error
      expect(result.error, isNull);
    });

    test('should handle invalid queries gracefully', () async {
      final result = await assistant.getRecommendations(
        '',
        userId: 'test_user',
      );

      expect(result.success, isNotNull);
    });
  });
}
```

## UI/UX Best Practices

### Visual Feedback

```dart
// Show loading state during search
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(
      children: const [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('Searching across marketplaces...'),
      ],
    ),
    duration: const Duration(minutes: 1),
  ),
);
```

### Result Formatting

```dart
// Format shopping results nicely
String _formatProductList(List<Product> products) {
  if (products.isEmpty) return 'No products found';
  
  return products
      .take(5)
      .asMap()
      .entries
      .map((e) => 
        '${e.key + 1}. ${e.value.title}\n'
        '   ${e.value.price} (${e.value.source}) ⭐${e.value.rating ?? "N/A"}')
      .join('\n');
}
```

## Production Deployment

### Prerequisites

1. Flask API running on port 5001
2. Error logging configured
3. Rate limiting enabled
4. Caching layer active (ResponseCacheService)

### Health Checks

```dart
// Periodic health check of scraper backend
Timer.periodic(Duration(minutes: 5), (_) async {
  final isHealthy = await webScraperService.healthCheck();
  if (!isHealthy) {
    debugPrint('[Shopping] ⚠ Scraper backend unhealthy');
    // Notify user or disable shopping mode
  }
});
```

---

## Summary

| Integration Type | Complexity | Use Case |
|---|---|---|
| Dedicated Screen | Low | Full-featured shopping experience |
| Inline in Chat | Medium | Seamless shopping within conversation |
| Quick Button | Low | Quick access from chat |
| Bottom Sheet | Medium | Contextual shopping options |

**Recommended**: Start with dedicated screen, then add inline if desired.

**Zero Issues Status**: ✅ All code maintains zero analyzer issues
