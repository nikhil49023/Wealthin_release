import 'dart:async';
import 'backend_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// LLM Inference Router - Routes between cloud and fallback inference
class LLMInferenceRouter {
  static final LLMInferenceRouter _instance = LLMInferenceRouter._internal();
  factory LLMInferenceRouter() => _instance;
  LLMInferenceRouter._internal();

  String? _cloudEndpoint;
  String? _openaiApiKey;

  // Configuration
  InferenceMode _preferredMode = InferenceMode.cloud;
  bool _allowFallback = true;
  Duration _inferenceTimeout = const Duration(seconds: 30);

  /// Initialize router with configuration
  Future<void> initialize({
    InferenceMode preferredMode = InferenceMode.cloud,
    String? cloudEndpoint,
    String? openaiApiKey,
    bool allowFallback = true,
  }) async {
    _preferredMode = preferredMode;
    _cloudEndpoint = cloudEndpoint ?? backendConfig.baseUrl;
    _openaiApiKey = openaiApiKey;
    _allowFallback = allowFallback;

    print('[LLMRouter] Initializing with mode: $_preferredMode');
  }

  /// Route inference request through preferred mode with fallback
  Future<InferenceResult> infer(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
    Map<String, dynamic>? systemPrompt,
  }) async {
    print('[LLMRouter] Routing inference with preferred mode: $_preferredMode');

    // Try preferred mode
    try {
      if (_preferredMode == InferenceMode.cloud) {
        return await _inferenceWithTimeout(
          () => _inferCloud(
            prompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature,
          ),
        );
      } else {
        return await _inferenceWithTimeout(
          () => _inferOpenAI(
            prompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature,
          ),
        );
      }
    } catch (e) {
      print('[LLMRouter] Preferred mode failed: $e');

      if (!_allowFallback) {
        return InferenceResult(
          success: false,
          error: 'Inference failed: $e',
          mode: _preferredMode,
        );
      }

      // Try fallback
      final fallbackMode = _preferredMode == InferenceMode.cloud
          ? InferenceMode.openai
          : InferenceMode.cloud;
          
      print('[LLMRouter] Attempting fallback with mode: $fallbackMode');

      try {
        if (fallbackMode == InferenceMode.cloud) {
          return await _inferCloud(
            prompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature,
          );
        } else {
          return await _inferOpenAI(
            prompt,
            tools: tools,
            maxTokens: maxTokens,
            temperature: temperature,
          );
        }
      } catch (e) {
        return InferenceResult(
          success: false,
          error: 'All inference modes failed: $e',
          mode: null,
        );
      }
    }
  }

  /// Infer via cloud endpoint
  Future<InferenceResult> _inferCloud(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    try {
      print('[LLMRouter] Using cloud inference');

      if (_cloudEndpoint == null) {
        throw Exception('Cloud endpoint not configured');
      }
      
      // Call backend API
      final response = await http.post(
        Uri.parse('$_cloudEndpoint/agent/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
            'query': prompt,
            'user_id': 'user', // Default
            'context': {
                'tools': tools,
                'max_tokens': maxTokens,
                'temperature': temperature
            }
        }),
      ).timeout(_inferenceTimeout);

      if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return InferenceResult(
            success: true,
            response: data['response'],
            tokensUsed: 0,
            mode: InferenceMode.cloud,
            latency: DateTime.now(),
          );
      }
      
      throw Exception('Backend returned ${response.statusCode}');

    } catch (e) {
      return InferenceResult(
        success: false,
        error: 'Cloud inference failed: $e',
        mode: InferenceMode.cloud,
      );
    }
  }

  /// Infer via OpenAI API (fallback)
  Future<InferenceResult> _inferOpenAI(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    try {
      print('[LLMRouter] Using OpenAI fallback');

      if (_openaiApiKey == null) {
        throw Exception('OpenAI API key not configured');
      }

      final systemMessage =
          'You are a financial advisor AI for the WealthIn app. Provide helpful, accurate financial guidance. ';

      final response = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_openaiApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'gpt-4-turbo',
              'messages': [
                {'role': 'system', 'content': systemMessage},
                {'role': 'user', 'content': prompt},
              ],
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final message = data['choices']?[0]?['message']?['content'] ?? '';
      final tokensUsed = data['usage']?['total_tokens'] ?? 0;

      return InferenceResult(
        success: true,
        response: message,
        tokensUsed: tokensUsed,
        mode: InferenceMode.openai,
        latency: DateTime.now(),
      );
    } catch (e) {
      return InferenceResult(
        success: false,
        error: 'OpenAI inference failed: $e',
        mode: InferenceMode.openai,
      );
    }
  }

  /// Apply timeout to inference
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

  /// Switch preferred mode
  void setPreferredMode(InferenceMode mode) {
    _preferredMode = mode;
    print('[LLMRouter] Preferred mode switched to: $_preferredMode');
  }
}

/// Inference mode enumeration
enum InferenceMode {
  cloud,
  openai,
}

/// Result from inference
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
