import 'package:flutter/foundation.dart';
import 'ai_agent_service.dart';
import 'query_router.dart';
import 'response_cache_service.dart';
import 'memory_service.dart';
import 'rag_service.dart';

/// Hybrid AI Service - Sarvam API Only Mode
/// 
/// PRODUCTION MODE: All queries use Sarvam AI exclusively
/// - No local inference
/// - No on-device fallback
/// - Multi-key Sarvam support with automatic rotation
class HybridAIService {
  static final HybridAIService _instance = HybridAIService._internal();
  factory HybridAIService() => _instance;
  HybridAIService._internal();

  bool _initialized = false;
  int _apiQueries = 0;
  int _cacheHits = 0;

  /// Initialize hybrid service
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════╗');
    debugPrint('║          HYBRID AI SERVICE - SARVAM API ONLY MODE        ║');
    debugPrint('╠══════════════════════════════════════════════════════════╣');
    debugPrint('║                                                          ║');
    debugPrint('║  Local Inference:     DISABLED                           ║');
    debugPrint('║  Sarvam AI Provider:  ENABLED ✓                         ║');
    debugPrint('║  Multi-Key Support:   ENABLED ✓                         ║');
    debugPrint('║  Routing Mode:        API_ONLY                          ║');
    debugPrint('║                                                          ║');
    debugPrint('║  All queries will use Sarvam AI exclusively.            ║');
    debugPrint('║  No local inference or fallbacks.                       ║');
    debugPrint('║                                                          ║');

    // Initialize core components
    await queryRouter.initialize();

    // Sarvam API will initialize on first use (lazy)

    _initialized = true;
    debugPrint('╚══════════════════════════════════════════════════════════╝');
    debugPrint('');
  }

  /// Main chat method — injects RAG + memory context before calling Sarvam AI
  Future<AgentResponse> chat(
    String message, {
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userContext,
    required String userId,
    QueryContext? queryContext,
  }) async {
    if (!_initialized) await initialize();

    try {
      // 1. Check cache first (instant, free)
      final cached = await responseCache.get(message, context: userContext);
      if (cached != null) {
        _cacheHits++;
        debugPrint('[HybridAI] ✓ CACHE HIT (0ms)');
        return AgentResponse(
          response: cached,
          actionTaken: false,
          inferenceMode: 'cache',
          tokensUsed: 0,
        );
      }

      // 2. Build personalised context: memory + RAG
      final memCtx = await memoryService.buildMemoryContext(userId);
      final ragCtx = await ragService.buildRagContext(userId, message);

      final enrichedContext = <String, dynamic>{
        ...?userContext,
        if (memCtx.isNotEmpty) 'memory': memCtx,
        if (ragCtx.isNotEmpty) 'rag_context': ragCtx,
      };

      debugPrint('[HybridAI] ─────────────────────────────────────');
      debugPrint('[HybridAI] Query: "${_truncate(message, 50)}"');
      debugPrint('[HybridAI] Memory: ${memCtx.isNotEmpty ? "✓" : "empty"}');
      debugPrint('[HybridAI] RAG: ${ragCtx.isNotEmpty ? "✓" : "empty"}');
      debugPrint('[HybridAI] Using: Sarvam API (Artha)');

      // 3. Execute via Sarvam API
      final response = await _executeAPI(message, conversationHistory, enrichedContext, userId);
      _apiQueries++;

      // 4. Cache the response
      _cacheResponse(message, response, enrichedContext);
      debugPrint('[HybridAI] ─────────────────────────────────────');
      return response;

    } catch (e) {
      debugPrint('[HybridAI] ✗ Error: $e');
      return AgentResponse(
        response: 'I encountered an error. Please try again.',
        actionTaken: false,
        error: e.toString(),
      );
    }
  }

  /// Execute using Sarvam API (only inference method)
  Future<AgentResponse> _executeAPI(
    String message,
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userContext,
    String userId,
  ) async {
    final startTime = DateTime.now();

    // Use Sarvam API via existing service
    final response = await aiAgentService.chat(
      message,
      conversationHistory: conversationHistory,
      userContext: userContext,
      userId: userId,
    );

    final latency = DateTime.now().difference(startTime);

    debugPrint('[HybridAI] ✓ Sarvam API completed in ${latency.inMilliseconds}ms');

    return AgentResponse(
      response: response.response,
      actionTaken: response.actionTaken,
      actionType: response.actionType,
      actionData: response.actionData,
      needsConfirmation: response.needsConfirmation,
      error: response.error,
      inferenceMode: 'api (Sarvam)',
      tokensUsed: response.tokensUsed,
      sources: response.sources,
    );
  }

  /// Cache response for future queries
  void _cacheResponse(String message, AgentResponse response, Map<String, dynamic>? userContext) {
    final shouldCache = responseCache.isLikelyRepeated(message);
    final isTimeSensitive = responseCache.isTimeSensitive(message);

    if (shouldCache || !isTimeSensitive) {
      responseCache.set(
        message,
        response.response,
        context: userContext,
        isTimeSensitive: isTimeSensitive,
      );
    }
  }

  /// Get usage statistics
  Map<String, dynamic> getStats() {
    return {
      'total_queries': _apiQueries,
      'api_queries': _apiQueries,
      'cache_hits': _cacheHits,
      'cache_stats': responseCache.getStats(),
      'mode': 'Sarvam API Only (Production)',
    };
  }

  /// Reset statistics
  void resetStats() {
    _apiQueries = 0;
    _cacheHits = 0;
    debugPrint('[HybridAI] Stats reset');
  }

  /// Helper: Truncate string
  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}

/// Global instance
final hybridAI = HybridAIService();
