import 'package:flutter/foundation.dart';

import 'web_scraper_service.dart';
import 'hybrid_ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SHOPPING ASSISTANT - AI-Powered Shopping & Business Planning
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingAssistant {
  static final ShoppingAssistant _instance = ShoppingAssistant._internal();
  factory ShoppingAssistant() => _instance;
  ShoppingAssistant._internal();

  final webScraper = webScraperService;
  final aiService = HybridAIService();

  bool _initialized = false;

  /// Initialize shopping assistant
  Future<void> initialize() async {
    if (_initialized) return;
    await webScraper.initialize();
    await aiService.initialize();
    _initialized = true;
    debugPrint('[ShoppingAssistant] ✓ Initialized');
  }

  /// Get shopping recommendations with AI analysis
  Future<ShoppingRecommendation> getRecommendations(
    String query, {
    required String userId,
    String? budget,
    String? category,
  }) async {
    if (!_initialized) await initialize();

    try {
      debugPrint('[ShoppingAssistant] Getting recommendations for: $query');

      // Search across marketplaces
      final searchResults = await webScraper.searchProducts(query, limit: 5);

      if (!searchResults.success) {
        return ShoppingRecommendation(
          query: query,
          products: [],
          analysis: 'Failed to fetch marketplace data. Please try again.',
          recommendation: null,
          estimatedBudget: budget,
          category: category,
        );
      }

      // Flatten products from all sources
      final allProducts = <Product>[];
      searchResults.results.forEach((source, products) {
        allProducts.addAll(products);
      });

      // Get AI analysis
      final aiPrompt = _buildAnalysisPrompt(
        query,
        allProducts,
        budget: budget,
        category: category,
      );

      final aiResponse = await aiService.chat(
        aiPrompt,
        userId: userId,
        userContext: {
          'mode': 'shopping',
          'query': query,
          'product_count': allProducts.length,
        },
      );

      return ShoppingRecommendation(
        query: query,
        products: allProducts,
        analysis: aiResponse.response,
        recommendation: _extractRecommendation(aiResponse.response),
        estimatedBudget: budget,
        category: category,
      );
    } catch (e) {
      debugPrint('[ShoppingAssistant] Error: $e');
      return ShoppingRecommendation(
        query: query,
        products: [],
        analysis: 'Error: ${e.toString()}',
        recommendation: null,
        estimatedBudget: budget,
        category: category,
      );
    }
  }

  /// Find businesses for purchase/partnership
  Future<BusinessFindingResult> findBusinesses(
    String businessType,
    String location, {
    required String userId,
    String? purpose,
  }) async {
    if (!_initialized) await initialize();

    try {
      debugPrint(
        '[ShoppingAssistant] Finding businesses: $businessType in $location',
      );

      // Search across business directories
      final searchResults = await webScraper.searchBusinesses(
        businessType,
        location,
        limit: 10,
      );

      if (!searchResults.success) {
        return BusinessFindingResult(
          businessType: businessType,
          location: location,
          businesses: [],
          analysis: 'Failed to fetch business data. Please try again.',
          topMatches: [],
          purpose: purpose,
        );
      }

      // Flatten businesses from all sources
      final allBusinesses = <Business>[];
      searchResults.results.forEach((source, businesses) {
        allBusinesses.addAll(businesses);
      });

      // Sort by rating
      allBusinesses.sort((a, b) {
        final ratingA = double.tryParse(a.rating?.split(' ')[0] ?? '0') ?? 0;
        final ratingB = double.tryParse(b.rating?.split(' ')[0] ?? '0') ?? 0;
        return ratingB.compareTo(ratingA);
      });

      // Get AI analysis
      final aiPrompt = _buildBusinessAnalysisPrompt(
        businessType,
        location,
        allBusinesses,
        purpose: purpose,
      );

      final aiResponse = await aiService.chat(
        aiPrompt,
        userId: userId,
        userContext: {
          'mode': 'business_finding',
          'business_type': businessType,
          'location': location,
          'business_count': allBusinesses.length,
        },
      );

      return BusinessFindingResult(
        businessType: businessType,
        location: location,
        businesses: allBusinesses,
        analysis: aiResponse.response,
        topMatches: allBusinesses.take(3).toList(),
        purpose: purpose,
      );
    } catch (e) {
      debugPrint('[ShoppingAssistant] Error: $e');
      return BusinessFindingResult(
        businessType: businessType,
        location: location,
        businesses: [],
        analysis: 'Error: ${e.toString()}',
        topMatches: [],
        purpose: purpose,
      );
    }
  }

  /// Compare products across sources
  Future<ComparisonResult> compareProducts(
    String query, {
    required String userId,
  }) async {
    if (!_initialized) await initialize();

    try {
      debugPrint('[ShoppingAssistant] Comparing products: $query');

      final amazonProducts = await webScraper.searchAmazon(query, limit: 5);
      final indiamartProducts = await webScraper.searchIndiaMART(
        query,
        limit: 5,
      );

      final comparisonPrompt = _buildComparisonPrompt(
        query,
        amazonProducts,
        indiamartProducts,
      );

      final aiResponse = await aiService.chat(
        comparisonPrompt,
        userId: userId,
        userContext: {
          'mode': 'product_comparison',
          'query': query,
        },
      );

      return ComparisonResult(
        query: query,
        amazonProducts: amazonProducts,
        indiamartProducts: indiamartProducts,
        analysis: aiResponse.response,
      );
    } catch (e) {
      debugPrint('[ShoppingAssistant] Comparison error: $e');
      return ComparisonResult(
        query: query,
        amazonProducts: [],
        indiamartProducts: [],
        analysis: 'Error comparing products: ${e.toString()}',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  PROMPT BUILDERS
  // ───────────────────────────────────────────────────────────────────────────

  String _buildAnalysisPrompt(
    String query,
    List<Product> products, {
    String? budget,
    String? category,
  }) {
    final productList = products
        .take(5)
        .map(
          (p) => '- ${p.title} (${p.source}): ${p.price} ⭐${p.rating ?? "N/A"}',
        )
        .join('\n');

    return '''
You are a knowledgeable shopping assistant. Analyze these products for "$query" and provide personalized recommendations.

PRODUCTS FOUND:
$productList

${budget != null ? '\nUSER BUDGET: $budget' : ''}
${category != null ? '\nCATEGORY: $category' : ''}

Please provide:
1. Best value option with reasoning
2. Premium option if available
3. Budget-friendly alternative
4. Key comparison points (quality, warranty, delivery)
5. Estimated total cost of ownership
6. Where to buy and how to negotiate

Keep recommendations concise and actionable.
''';
  }

  String _buildBusinessAnalysisPrompt(
    String businessType,
    String location,
    List<Business> businesses, {
    String? purpose,
  }) {
    final businessList = businesses
        .take(10)
        .map(
          (b) =>
              '- ${b.name} (${b.source}): ${b.location} ⭐${b.rating ?? "N/A"} ${b.phone ?? ""}',
        )
        .join('\n');

    return '''
You are a business consultant. Analyze these "$businessType" businesses in $location for potential partnership or purchase.

BUSINESSES FOUND:
$businessList

${purpose != null ? '\nPURPOSE: $purpose' : ''}

Please provide:
1. Top 3 recommendations with reasoning
2. Quality indicators and red flags
3. Estimated negotiation range (if applicable)
4. Questions to ask before engaging
5. Due diligence checklist
6. Risk assessment

Focus on reliability, scalability, and value.
''';
  }

  String _buildComparisonPrompt(
    String query,
    List<Product> amazonProducts,
    List<Product> indiamartProducts,
  ) {
    final amazonList = amazonProducts.isEmpty
        ? 'No products found'
        : amazonProducts
              .take(3)
              .map((p) => '- ${p.title}: ${p.price}')
              .join('\n');

    final indiamartList = indiamartProducts.isEmpty
        ? 'No products found'
        : indiamartProducts
              .take(3)
              .map((p) => '- ${p.title}: ${p.price}')
              .join('\n');

    return '''
Compare these "$query" products from different marketplaces:

AMAZON:
$amazonList

INDIAMART (B2B/Wholesale):
$indiamartList

Provide:
1. Price comparison and best deal
2. Quantity/MOQ considerations
3. Use case recommendations (retail vs wholesale)
4. Quality indicators
5. Shipping & delivery timeline
6. Return/guarantee policies
''';
  }

  String? _extractRecommendation(String analysis) {
    final lines = analysis.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains('recommend') ||
          line.toLowerCase().contains('best')) {
        return line.trim();
      }
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingRecommendation {
  final String query;
  final List<Product> products;
  final String analysis;
  final String? recommendation;
  final String? estimatedBudget;
  final String? category;

  ShoppingRecommendation({
    required this.query,
    required this.products,
    required this.analysis,
    this.recommendation,
    this.estimatedBudget,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'products': products.map((p) => p.toJson()).toList(),
    'analysis': analysis,
    'recommendation': recommendation,
    'estimated_budget': estimatedBudget,
    'category': category,
  };
}

class BusinessFindingResult {
  final String businessType;
  final String location;
  final List<Business> businesses;
  final String analysis;
  final List<Business> topMatches;
  final String? purpose;

  BusinessFindingResult({
    required this.businessType,
    required this.location,
    required this.businesses,
    required this.analysis,
    required this.topMatches,
    this.purpose,
  });

  Map<String, dynamic> toJson() => {
    'business_type': businessType,
    'location': location,
    'businesses': businesses.map((b) => b.toJson()).toList(),
    'analysis': analysis,
    'top_matches': topMatches.map((b) => b.toJson()).toList(),
    'purpose': purpose,
  };
}

class ComparisonResult {
  final String query;
  final List<Product> amazonProducts;
  final List<Product> indiamartProducts;
  final String analysis;

  ComparisonResult({
    required this.query,
    required this.amazonProducts,
    required this.indiamartProducts,
    required this.analysis,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'amazon_products': amazonProducts.map((p) => p.toJson()).toList(),
    'indiamart_products': indiamartProducts.map((p) => p.toJson()).toList(),
    'analysis': analysis,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  SINGLETON INSTANCE
// ─────────────────────────────────────────────────────────────────────────────

final shoppingAssistant = ShoppingAssistant();
