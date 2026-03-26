import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Response Cache Service for AI Queries
/// Caches common queries to reduce API costs and improve latency
///
/// Benefits:
/// - 10-20% of queries are repeated
/// - Instant response (0ms vs 2000ms)
/// - Zero API cost for cached responses
///
/// Cache Strategy:
/// - Store last 100 responses in memory
/// - TTL: 1 hour for most queries, 5 min for time-sensitive
/// - Invalidate on user context change
class ResponseCacheService {
  static final ResponseCacheService _instance = ResponseCacheService._internal();
  factory ResponseCacheService() => _instance;
  ResponseCacheService._internal();

  final Map<String, CachedResponse> _cache = {};
  static const int MAX_CACHE_SIZE = 100;
  static const Duration DEFAULT_TTL = Duration(hours: 1);
  static const Duration TIME_SENSITIVE_TTL = Duration(minutes: 5);

  // Stats
  int _hits = 0;
  int _misses = 0;
  int _expirations = 0;

  /// Get cached response if available and not expired
  Future<String?> get(String query, {Map<String, dynamic>? context}) async {
    final key = _generateKey(query, context);
    final cached = _cache[key];

    if (cached == null) {
      _misses++;
      return null;
    }

    if (cached.isExpired) {
      _cache.remove(key);
      _expirations++;
      _misses++;
      return null;
    }

    _hits++;
    debugPrint('[ResponseCache] HIT: ${query.substring(0, query.length < 30 ? query.length : 30)}...');
    return cached.response;
  }

  /// Cache a response
  void set(
    String query,
    String response, {
    Map<String, dynamic>? context,
    Duration? ttl,
    bool isTimeSensitive = false,
  }) {
    final key = _generateKey(query, context);

    // Determine TTL
    final cacheTTL = ttl ?? (isTimeSensitive ? TIME_SENSITIVE_TTL : DEFAULT_TTL);

    // Evict oldest if cache is full
    if (_cache.length >= MAX_CACHE_SIZE) {
      _evictOldest();
    }

    _cache[key] = CachedResponse(
      query: query,
      response: response,
      timestamp: DateTime.now(),
      ttl: cacheTTL,
    );

    debugPrint('[ResponseCache] SET: ${query.substring(0, query.length < 30 ? query.length : 30)}...');
  }

  /// Generate cache key from query and context
  String _generateKey(String query, Map<String, dynamic>? context) {
    // Normalize query
    final normalizedQuery = query.toLowerCase().trim();

    // Include relevant context in key
    final contextStr = context != null ? context.toString() : '';

    // Generate hash
    final bytes = utf8.encode('$normalizedQuery|$contextStr');
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Evict oldest entry from cache
  void _evictOldest() {
    if (_cache.isEmpty) return;

    // Find oldest entry
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestTime = entry.value.timestamp;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
      debugPrint('[ResponseCache] Evicted oldest entry');
    }
  }

  /// Clear all cached responses
  void clear() {
    _cache.clear();
    debugPrint('[ResponseCache] Cache cleared');
  }

  /// Clear expired entries
  void clearExpired() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('[ResponseCache] Cleared ${expiredKeys.length} expired entries');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final total = _hits + _misses;
    final hitRate = total > 0 ? (_hits / total * 100).toStringAsFixed(1) : '0.0';

    return {
      'cache_size': _cache.length,
      'max_size': MAX_CACHE_SIZE,
      'hits': _hits,
      'misses': _misses,
      'expirations': _expirations,
      'hit_rate': '$hitRate%',
      'total_queries': total,
    };
  }

  /// Reset statistics
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _expirations = 0;
  }

  /// Check if query is likely to be repeated (heuristic)
  bool isLikelyRepeated(String query) {
    final lowerQuery = query.toLowerCase();

    // Common financial queries
    final commonPatterns = [
      'what is',
      'how to',
      'explain',
      'difference between',
      'best',
      'should i',
      'can i',
      'when to',
    ];

    return commonPatterns.any((pattern) => lowerQuery.startsWith(pattern));
  }

  /// Check if query is time-sensitive (should expire quickly)
  bool isTimeSensitive(String query) {
    final lowerQuery = query.toLowerCase();

    final timeSensitiveKeywords = [
      'latest',
      'current',
      'today',
      'now',
      'recent',
      'news',
      'price',
      'rate',
      'market',
    ];

    return timeSensitiveKeywords.any((keyword) => lowerQuery.contains(keyword));
  }
}

/// Cached response entry
class CachedResponse {
  final String query;
  final String response;
  final DateTime timestamp;
  final Duration ttl;

  CachedResponse({
    required this.query,
    required this.response,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > ttl;
  }

  int get ageInSeconds {
    return DateTime.now().difference(timestamp).inSeconds;
  }
}

/// Global instance
final responseCache = ResponseCacheService();
