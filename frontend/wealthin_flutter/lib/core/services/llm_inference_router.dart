import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'python_bridge_service.dart';

/// LLM Inference Router - Android embedded inference only.
class LLMInferenceRouter {
  static final LLMInferenceRouter _instance = LLMInferenceRouter._internal();
  factory LLMInferenceRouter() => _instance;
  LLMInferenceRouter._internal();

  // Configuration
  InferenceMode _preferredMode = InferenceMode.embedded;
  bool _allowFallback = true;
  final Duration _inferenceTimeout = const Duration(seconds: 30);

  /// Initialize router with configuration.
  /// Kept compatible with previous API but runs Android embedded mode only.
  Future<void> initialize({
    InferenceMode preferredMode = InferenceMode.embedded,
    String? cloudEndpoint,
    String? openaiApiKey,
    bool allowFallback = true,
  }) async {
    _preferredMode = InferenceMode.embedded;
    _allowFallback = allowFallback;

    debugPrint('[LLMRouter] Initialized in embedded Android mode');
  }

  /// Route inference request through embedded Python mode.
  Future<InferenceResult> infer(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
    Map<String, dynamic>? systemPrompt,
  }) async {
    try {
      return await _inferenceWithTimeout(() async {
        final result = await pythonBridge.chatWithLLM(
          query: prompt,
          userContext: {
            'tools': tools ?? const [],
            'max_tokens': maxTokens,
            'temperature': temperature,
            if (systemPrompt != null) 'system_prompt': systemPrompt,
          },
        );

        if (result['success'] == true || result.containsKey('response')) {
          return InferenceResult(
            success: true,
            response: result['response']?.toString() ?? '',
            tokensUsed: 0,
            mode: InferenceMode.embedded,
            latency: DateTime.now(),
          );
        }

        return InferenceResult(
          success: false,
          error: result['error']?.toString() ?? 'Embedded inference failed',
          mode: InferenceMode.embedded,
        );
      });
    } catch (e) {
      if (!_allowFallback) {
        return InferenceResult(
          success: false,
          error: 'Inference failed: $e',
          mode: _preferredMode,
        );
      }

      return InferenceResult(
        success: false,
        error: 'Inference failed: $e',
        mode: InferenceMode.embedded,
      );
    }
  }

  Future<InferenceResult> _inferenceWithTimeout(
    Future<InferenceResult> Function() inferFn,
  ) async {
    try {
      return await inferFn().timeout(_inferenceTimeout);
    } on TimeoutException {
      return InferenceResult(
        success: false,
        error: 'Inference timeout after $_inferenceTimeout',
        mode: _preferredMode,
      );
    }
  }

  /// Preferred mode is fixed to embedded in Android-only runtime.
  void setPreferredMode(InferenceMode mode) {
    _preferredMode = InferenceMode.embedded;
    debugPrint('[LLMRouter] Embedded mode enforced');
  }
}

/// Inference mode enumeration.
enum InferenceMode {
  embedded,
}

/// Result from inference.
class InferenceResult {
  final bool success;
  final String? response;
  final int tokensUsed;
  final InferenceMode? mode;
  final String? error;
  final DateTime? latency;

  InferenceResult({
    required this.success,
    this.response,
    this.tokensUsed = 0,
    this.mode,
    this.error,
    this.latency,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'response': response,
    'tokens_used': tokensUsed,
    'mode': mode?.toString(),
    'error': error,
  };
}

/// Global instance
final llmRouter = LLMInferenceRouter();
