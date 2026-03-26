import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class Product {
  final String source;
  final String title;
  final String price;
  final String? rating;
  final String url;
  final DateTime scrapedAt;
  final Map<String, dynamic>? additionalData;

  Product({
    required this.source,
    required this.title,
    required this.price,
    this.rating,
    required this.url,
    required this.scrapedAt,
    this.additionalData,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      source: json['source'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      price: json['price'] as String? ?? 'N/A',
      rating: json['rating'] as String?,
      url: json['url'] as String? ?? '',
      scrapedAt: json['scraped_at'] != null
          ? DateTime.parse(json['scraped_at'] as String)
          : DateTime.now(),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'title': title,
    'price': price,
    'rating': rating,
    'url': url,
    'scraped_at': scrapedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'Product($source: $title - $price - ${rating ?? "N/A"} stars)';
}

class Business {
  final String source;
  final String name;
  final String? rating;
  final String location;
  final String? phone;
  final String url;
  final DateTime scrapedAt;
  final Map<String, dynamic>? additionalData;

  Business({
    required this.source,
    required this.name,
    this.rating,
    required this.location,
    this.phone,
    required this.url,
    required this.scrapedAt,
    this.additionalData,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      source: json['source'] as String? ?? 'unknown',
      name: json['name'] as String? ?? '',
      rating: json['rating'] as String?,
      location: json['location'] as String? ?? '',
      phone: json['phone'] as String?,
      url: json['url'] as String? ?? '',
      scrapedAt: json['scraped_at'] != null
          ? DateTime.parse(json['scraped_at'] as String)
          : DateTime.now(),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'name': name,
    'rating': rating,
    'location': location,
    'phone': phone,
    'url': url,
    'scraped_at': scrapedAt.toIso8601String(),
  };

  @override
  String toString() => 'Business($name - $location - ${rating ?? "N/A"} stars)';
}

class MarketplaceSource {
  final String id;
  final String name;
  final String type;
  final bool hasProducts;
  final bool hasBusinesses;
  final String url;

  MarketplaceSource({
    required this.id,
    required this.name,
    required this.type,
    required this.hasProducts,
    required this.hasBusinesses,
    required this.url,
  });

  factory MarketplaceSource.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return MarketplaceSource(
      id: id,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      hasProducts: json['products'] as bool? ?? false,
      hasBusinesses: json['businesses'] as bool? ?? false,
      url: json['url'] as String? ?? '',
    );
  }
}

class ProductSearchResult {
  final String query;
  final Map<String, List<Product>> results;
  final int totalResults;
  final bool success;
  final String? error;

  ProductSearchResult({
    required this.query,
    required this.results,
    required this.totalResults,
    required this.success,
    this.error,
  });

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) {
    final results = <String, List<Product>>{};
    if (json['results'] is Map) {
      (json['results'] as Map<String, dynamic>).forEach((key, value) {
        if (value is List) {
          results[key] = (value as List)
              .cast<Map<String, dynamic>>()
              .map(Product.fromJson)
              .toList();
        }
      });
    }

    return ProductSearchResult(
      query: json['query'] as String? ?? '',
      results: results,
      totalResults: json['total_results'] as int? ?? 0,
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

class BusinessSearchResult {
  final String category;
  final String location;
  final Map<String, List<Business>> results;
  final int totalResults;
  final bool success;
  final String? error;

  BusinessSearchResult({
    required this.category,
    required this.location,
    required this.results,
    required this.totalResults,
    required this.success,
    this.error,
  });

  factory BusinessSearchResult.fromJson(Map<String, dynamic> json) {
    final results = <String, List<Business>>{};
    if (json['results'] is Map) {
      (json['results'] as Map<String, dynamic>).forEach((key, value) {
        if (value is List) {
          results[key] = (value as List)
              .cast<Map<String, dynamic>>()
              .map(Business.fromJson)
              .toList();
        }
      });
    }

    return BusinessSearchResult(
      category: json['category'] as String? ?? '',
      location: json['location'] as String? ?? '',
      results: results,
      totalResults: json['total_results'] as int? ?? 0,
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MARKETPLACE SCRAPER SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class WebScraperService {
  static final WebScraperService _instance = WebScraperService._internal();
  factory WebScraperService() => _instance;
  WebScraperService._internal();

  final String _baseUrl = 'http://localhost:5001';
  final Duration _timeout = const Duration(seconds: 30);
  final Map<String, MarketplaceSource> _sources = {};

  bool _initialized = false;

  /// Initialize scraper service and fetch source information
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('[WebScraper] Initializing Marketplace Scraper Service...');
      await _fetchSourceInfo();
      _initialized = true;
      debugPrint(
        '[WebScraper] ✓ Service initialized with ${_sources.length} sources',
      );
    } catch (e) {
      debugPrint('[WebScraper] ⚠ Init warning: $e (will retry on first use)');
      _initialized = true;
    }
  }

  /// Fetch available marketplace sources
  Future<void> _fetchSourceInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/source-info'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['sources'] is Map) {
          (data['sources'] as Map<String, dynamic>).forEach((key, value) {
            _sources[key] = MarketplaceSource.fromJson(
              key,
              value as Map<String, dynamic>,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('[WebScraper] Error fetching sources: $e');
      _initializeDefaultSources();
    }
  }

  /// Initialize default sources if API is unavailable
  void _initializeDefaultSources() {
    _sources['amazon'] = MarketplaceSource(
      id: 'amazon',
      name: 'Amazon India',
      type: 'e-commerce',
      hasProducts: true,
      hasBusinesses: false,
      url: 'https://amazon.in',
    );
    _sources['indiamart'] = MarketplaceSource(
      id: 'indiamart',
      name: 'IndiaMART',
      type: 'B2B marketplace',
      hasProducts: true,
      hasBusinesses: true,
      url: 'https://indiamart.com',
    );
    _sources['justdial'] = MarketplaceSource(
      id: 'justdial',
      name: 'JustDial',
      type: 'Business directory',
      hasProducts: false,
      hasBusinesses: true,
      url: 'https://justdial.com',
    );
  }

  /// Search products across all marketplaces
  Future<ProductSearchResult> searchProducts(
    String query, {
    int limit = 5,
  }) async {
    if (!_initialized) await initialize();

    try {
      debugPrint('[WebScraper] Searching products: "$query" (limit: $limit)');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/search/products'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'limit': limit}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final result = ProductSearchResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        debugPrint('[WebScraper] ✓ Found ${result.totalResults} products');
        return result;
      } else {
        debugPrint('[WebScraper] Error: HTTP ${response.statusCode}');
        return ProductSearchResult(
          query: query,
          results: {},
          totalResults: 0,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[WebScraper] Search error: $e');
      return ProductSearchResult(
        query: query,
        results: {},
        totalResults: 0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Search for businesses in a category and location
  Future<BusinessSearchResult> searchBusinesses(
    String category,
    String location, {
    int limit = 10,
  }) async {
    if (!_initialized) await initialize();

    try {
      debugPrint(
        '[WebScraper] Searching businesses: $category in $location (limit: $limit)',
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/search/businesses'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'category': category,
              'location': location,
              'limit': limit,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final result = BusinessSearchResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        debugPrint('[WebScraper] ✓ Found ${result.totalResults} businesses');
        return result;
      } else {
        debugPrint('[WebScraper] Error: HTTP ${response.statusCode}');
        return BusinessSearchResult(
          category: category,
          location: location,
          results: {},
          totalResults: 0,
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[WebScraper] Search error: $e');
      return BusinessSearchResult(
        category: category,
        location: location,
        results: {},
        totalResults: 0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Search Amazon only
  Future<List<Product>> searchAmazon(
    String query, {
    int limit = 10,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/search/amazon/products'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'limit': limit}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products =
            (data['products'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(Product.fromJson)
                .toList() ??
            [];
        debugPrint('[WebScraper] Amazon: Found ${products.length} products');
        return products;
      }
      return [];
    } catch (e) {
      debugPrint('[WebScraper] Amazon search error: $e');
      return [];
    }
  }

  /// Search IndiaMART only
  Future<List<Product>> searchIndiaMART(
    String query, {
    int limit = 10,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/search/indiamart/products'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'limit': limit}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products =
            (data['products'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(Product.fromJson)
                .toList() ??
            [];
        debugPrint('[WebScraper] IndiaMART: Found ${products.length} products');
        return products;
      }
      return [];
    } catch (e) {
      debugPrint('[WebScraper] IndiaMART search error: $e');
      return [];
    }
  }

  /// Search JustDial businesses only
  Future<List<Business>> searchJustDial(
    String category,
    String location, {
    int limit = 15,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/search/justdial/businesses'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'category': category,
              'location': location,
              'limit': limit,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final businesses =
            (data['businesses'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(Business.fromJson)
                .toList() ??
            [];
        debugPrint(
          '[WebScraper] JustDial: Found ${businesses.length} businesses',
        );
        return businesses;
      }
      return [];
    } catch (e) {
      debugPrint('[WebScraper] JustDial search error: $e');
      return [];
    }
  }

  /// Get all available sources
  List<MarketplaceSource> getSources() => _sources.values.toList();

  /// Get source by ID
  MarketplaceSource? getSource(String id) => _sources[id];

  /// Check if service is healthy
  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[WebScraper] Health check failed: $e');
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SINGLETON INSTANCE
// ─────────────────────────────────────────────────────────────────────────────

final webScraperService = WebScraperService();
