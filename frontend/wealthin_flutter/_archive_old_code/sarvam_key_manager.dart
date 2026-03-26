import 'package:flutter/foundation.dart';
import 'dart:collection';
import 'package:intl/intl.dart';

/// Manages multiple Sarvam AI API keys with round-robin distribution
/// Each key gets 60 RPM, so 3 keys = 180 RPM, 5 keys = 300 RPM, etc.
///
/// Features:
/// - Rotate through multiple keys
/// - Track rate limit status per key
/// - Auto-fallback when key hits limit
/// - Request queuing with backoff
class SarvamAIKeyManager {
  static final SarvamAIKeyManager _instance = SarvamAIKeyManager._internal();
  factory SarvamAIKeyManager() => _instance;
  SarvamAIKeyManager._internal();

  // Key pool management
  final List<String> _apiKeys = [];
  int _currentKeyIndex = 0;

  // Rate limiting
  final Map<String, RateLimitStatus> _keyStatus = {};
  static const int RPM_LIMIT = 60;
  static const Duration RESET_WINDOW = Duration(minutes: 1);

  // Request queue
  final Queue<PendingRequest> _requestQueue = Queue();
  bool _isProcessing = false;

  /// Initialize with multiple API keys
  /// Pass multiple keys separated by comma or as a list
  /// Example: "key1,key2,key3" or ["key1", "key2", "key3"]
  Future<void> initialize(dynamic sarvamKeys) async {
    _apiKeys.clear();
    _keyStatus.clear();
    _currentKeyIndex = 0;

    if (sarvamKeys is String) {
      // Parse comma-separated keys
      _apiKeys.addAll(
        sarvamKeys
            .split(',')
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty)
            .toList(),
      );
    } else if (sarvamKeys is List<String>) {
      _apiKeys.addAll(sarvamKeys.where((k) => k.isNotEmpty));
    }

    // Initialize status for each key
    for (final key in _apiKeys) {
      _keyStatus[key] = RateLimitStatus(key: key);
    }

    debugPrint(
      '[SarvamKeyManager] Initialized with ${_apiKeys.length} keys '
      '(Total capacity: ${_apiKeys.length * RPM_LIMIT} RPM)',
    );
  }

  /// Get the next available API key (round-robin with fallback)
  String getNextKey() {
    if (_apiKeys.isEmpty) {
      throw Exception('[SarvamKeyManager] No API keys configured');
    }

    // Try current key
    String selectedKey = _apiKeys[_currentKeyIndex];
    final status = _keyStatus[selectedKey]!;

    if (!status.isRateLimited) {
      _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
      debugPrint(
        '[SarvamKeyManager] Using key $_currentKeyIndex: '
        '${status.requestsThisMinute}/${status.rpmLimit} RPM',
      );
      return selectedKey;
    }

    // Current key is rate-limited, find next available
    debugPrint('[SarvamKeyManager] Key rate-limited, finding fallback...');
    for (int i = 0; i < _apiKeys.length; i++) {
      final nextIndex = (_currentKeyIndex + i + 1) % _apiKeys.length;
      final nextKey = _apiKeys[nextIndex];
      final nextStatus = _keyStatus[nextKey]!;

      if (!nextStatus.isRateLimited) {
        _currentKeyIndex = nextIndex;
        debugPrint(
          '[SarvamKeyManager] Fallback to key $nextIndex: '
          '${nextStatus.requestsThisMinute}/${nextStatus.rpmLimit} RPM',
        );
        return nextKey;
      }
    }

    // All keys rate-limited - queue request
    debugPrint(
      '[SarvamKeyManager] ⚠ All keys rate-limited! Queueing request...',
    );
    throw RateLimitedException('All Sarvam AI keys are rate-limited');
  }

  /// Record a successful API request (increments counter)
  void recordRequest(String key) {
    final status = _keyStatus[key];
    if (status != null) {
      status.recordRequest();
    }
  }

  /// Record a rate limit error and mark key as limited
  void recordRateLimit(String key) {
    final status = _keyStatus[key];
    if (status != null) {
      status.hitRateLimit();
      debugPrint(
        '[SarvamKeyManager] ⚠ Rate limit hit for key: '
        'Next available at ${status.retryAfter}',
      );
    }
  }

  /// Get current status of all keys
  Map<String, dynamic> getStatus() {
    final totalRequests = _keyStatus.values.fold<int>(
      0,
      (sum, status) => sum + status.requestsThisMinute,
    );
    final availableKeys = _keyStatus.values
        .where((s) => !s.isRateLimited)
        .length;

    return {
      'total_keys': _apiKeys.length,
      'available_keys': availableKeys,
      'total_rpm_used': totalRequests,
      'total_rpm_capacity': _apiKeys.length * RPM_LIMIT,
      'current_key_index': _currentKeyIndex,
      'keys_status': {
        for (final key in _apiKeys)
          key: {
            'rpm_used': _keyStatus[key]!.requestsThisMinute,
            'rpm_limit': _keyStatus[key]!.rpmLimit,
            'is_rate_limited': _keyStatus[key]!.isRateLimited,
            'retry_after': _keyStatus[key]!.retryAfter,
          },
      },
    };
  }

  /// Add request to queue (for when all keys are rate-limited)
  void queueRequest(Future<dynamic> Function(String key) request) {
    _requestQueue.add(PendingRequest(request: request));
    _processQueue();
  }

  /// Process queued requests with backoff
  Future<void> _processQueue() async {
    if (_isProcessing || _requestQueue.isEmpty) return;

    _isProcessing = true;
    while (_requestQueue.isNotEmpty) {
      try {
        final pending = _requestQueue.removeFirst();
        final key = getNextKey();
        await pending.request(key);
        recordRequest(key);
      } catch (e) {
        debugPrint('[SarvamKeyManager] Queue processing error: $e');
        // Wait before retrying
        await Future.delayed(Duration(seconds: 5));
      }
    }
    _isProcessing = false;
  }

  /// Reset rate limit for all keys (for testing/debugging)
  void resetAllLimits() {
    for (final status in _keyStatus.values) {
      status.reset();
    }
    debugPrint('[SarvamKeyManager] All rate limits reset');
  }
}

/// Rate limit tracking per key
class RateLimitStatus {
  final String key;
  int requestsThisMinute = 0;
  int rpmLimit = 60; // Sarvam AI limit per key
  DateTime? windowStart;
  DateTime? rateLimitedUntil;

  RateLimitStatus({required this.key});

  void recordRequest() {
    final now = DateTime.now();

    // Reset counter if window has passed
    if (windowStart == null ||
        now.difference(windowStart!) > Duration(minutes: 1)) {
      windowStart = now;
      requestsThisMinute = 0;
    }

    requestsThisMinute++;
  }

  void hitRateLimit() {
    // Key is rate-limited for next 60 seconds
    rateLimitedUntil = DateTime.now().add(Duration(seconds: 60));
  }

  bool get isRateLimited {
    if (rateLimitedUntil == null) return false;
    if (DateTime.now().isAfter(rateLimitedUntil!)) {
      rateLimitedUntil = null;
      requestsThisMinute = 0;
      windowStart = DateTime.now();
      return false;
    }
    return true;
  }

  String get retryAfter {
    if (rateLimitedUntil == null) return 'Now';
    final formatter = DateFormat('HH:mm:ss');
    return formatter.format(rateLimitedUntil!);
  }

  void reset() {
    requestsThisMinute = 0;
    windowStart = null;
    rateLimitedUntil = null;
  }
}

/// Pending API request in queue
class PendingRequest {
  final Future<dynamic> Function(String key) request;

  PendingRequest({required this.request});
}

/// Exception for rate limit scenarios
class RateLimitedException implements Exception {
  final String message;
  RateLimitedException(this.message);

  @override
  String toString() => message;
}
