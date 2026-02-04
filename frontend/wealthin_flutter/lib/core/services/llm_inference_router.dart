import 'dart:async';
import 'nemotron_inference_service.dart';
import 'backend_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// LLM Inference Router - Routes between local, cloud, and fallback inference
/// Implements failover logic: local → cloud nemotron → openai fallback
class LLMInferenceRouter {
  static final LLMInferenceRouter _instance = LLMInferenceRouter._internal();
  factory LLMInferenceRouter() => _instance;
  LLMInferenceRouter._internal();

  final nemotron = NemotronInferenceService();
  String? _cloudEndpoint;
  String? _openaiApiKey;

  // Configuration
  InferenceMode _preferredMode = InferenceMode.local;
  bool _allowFallback = true;
  Duration _inferenceTimeout = const Duration(seconds: 30);

  /// Initialize router with configuration
  Future<void> initialize({
    InferenceMode preferredMode = InferenceMode.local,
    String? cloudEndpoint,
    String? openaiApiKey,
    bool allowFallback = true,
  }) async {
    _preferredMode = preferredMode;
    _cloudEndpoint = cloudEndpoint ?? backendConfig.baseUrl;
    _openaiApiKey = openaiApiKey;
    _allowFallback = allowFallback;

    print('[LLMRouter] Initializing with mode: $_preferredMode');

    // Initialize nemotron service
    await nemotron.initialize();

    // Try to load optimal model if preferred mode is local
    if (_preferredMode == InferenceMode.local) {
      try {
        await nemotron.loadOptimalModel();
      } catch (e) {
        print('[LLMRouter] Failed to load local model: $e');
        if (_allowFallback) {
          _preferredMode = InferenceMode.cloud;
        }
      }
    }
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
      switch (_preferredMode) {
        case InferenceMode.local:
          return await _inferenceWithTimeout(
            () => _inferLocal(
              prompt,
              tools: tools,
              maxTokens: maxTokens,
              temperature: temperature,
              systemPrompt: systemPrompt,
            ),
          );

        case InferenceMode.cloud:
          return await _inferenceWithTimeout(
            () => _inferCloud(
              prompt,
              tools: tools,
              maxTokens: maxTokens,
              temperature: temperature,
            ),
          );

        case InferenceMode.openai:
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

      // Attempt fallback
      if (!_allowFallback) {
        return InferenceResult(
          success: false,
          error: 'Inference failed: $e',
          mode: _preferredMode,
        );
      }

      // Try next modes in order
      return await _tryFallback(
        prompt,
        tools: tools,
        maxTokens: maxTokens,
        temperature: temperature,
        systemPrompt: systemPrompt,
      );
    }
  }

  /// Infer locally with Nemotron
  Future<InferenceResult> _inferLocal(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
    Map<String, dynamic>? systemPrompt,
  }) async {
    try {
      print('[LLMRouter] Using local inference');

      // Load model if not already loaded
      if (nemotron.isModelLoaded == false) {
        await nemotron.loadOptimalModel();
      }

      // Perform inference
      final response = await nemotron.inferLocal(
        prompt,
        tools: tools,
        maxTokens: maxTokens,
        temperature: temperature,
        systemPrompt: systemPrompt,
      );

      return InferenceResult(
        success: true,
        response: response.text,
        toolCall: response.toolCall,
        tokensUsed: response.tokensUsed,
        mode: InferenceMode.local,
        latency: response.timestamp,
      );
    } catch (e) {
      return InferenceResult(
        success: false,
        error: 'Local inference failed: $e',
        mode: InferenceMode.local,
      );
    }
  }

  /// Infer via cloud Nemotron endpoint
  Future<InferenceResult> _inferCloud(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    try {
      print('[LLMRouter] Using cloud Nemotron inference');

      if (_cloudEndpoint == null) {
        throw Exception('Cloud endpoint not configured');
      }

      final response = await nemotron.inferCloud(
        prompt,
        cloudEndpoint: _cloudEndpoint!,
        tools: tools,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      return InferenceResult(
        success: true,
        response: response.text,
        toolCall: response.toolCall,
        tokensUsed: response.tokensUsed,
        mode: InferenceMode.cloud,
        latency: response.timestamp,
      );
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
          'You are a financial advisor AI for the WealthIn app. Provide helpful, accurate financial guidance. '
          'When suggesting actions, format tool calls as JSON: {"type": "tool_call", "tool_call": {"name": "...", "arguments": {...}}}';

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
              if (tools != null && tools.isNotEmpty)
                'tools': [
                  for (final tool in tools)
                    {
                      'type': 'function',
                      'function': tool,
                    },
                ],
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

      // Try to parse tool call from response
      ToolCall? toolCall;
      if (message.contains('tool_call')) {
        toolCall = NemotronInferenceService.parseToolCall(message);
      }

      return InferenceResult(
        success: true,
        response: message,
        toolCall: toolCall,
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

  /// Try fallback modes
  Future<InferenceResult> _tryFallback(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
    Map<String, dynamic>? systemPrompt,
  }) async {
    final modesInOrder = [
      InferenceMode.local,
      InferenceMode.cloud,
      InferenceMode.openai,
    ];

    for (final mode in modesInOrder) {
      if (mode == _preferredMode) continue; // Skip already-tried mode

      print('[LLMRouter] Attempting fallback with mode: $mode');

      try {
        switch (mode) {
          case InferenceMode.local:
            return await _inferLocal(
              prompt,
              tools: tools,
              maxTokens: maxTokens,
              temperature: temperature,
              systemPrompt: systemPrompt,
            );

          case InferenceMode.cloud:
            return await _inferCloud(
              prompt,
              tools: tools,
              maxTokens: maxTokens,
              temperature: temperature,
            );

          case InferenceMode.openai:
            return await _inferOpenAI(
              prompt,
              tools: tools,
              maxTokens: maxTokens,
              temperature: temperature,
            );
        }
      } catch (e) {
        print('[LLMRouter] Fallback $mode failed: $e');
        continue;
      }
    }

    return InferenceResult(
      success: false,
      error: 'All inference modes failed',
      mode: null,
    );
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

  /// Get current status
  Map<String, dynamic> getStatus() {
    return {
      'preferredMode': _preferredMode.toString(),
      'allowFallback': _allowFallback,
      'nemotronStatus': nemotron.getStatus(),
      'cloudEndpoint': _cloudEndpoint,
      'hasOpenAIKey': _openaiApiKey != null,
    };
  }
}

/// Inference mode enumeration
enum InferenceMode {
  local,
  cloud,
  openai,
}

/// Result from inference
class InferenceResult {
  final bool success;
  final String? response;
  final ToolCall? toolCall;
  final int tokensUsed;
  final InferenceMode? mode;
  final String? error;
  final DateTime? latency;

  InferenceResult({
    required this.success,
    this.response,
    this.toolCall,
    this.tokensUsed = 0,
    this.mode,
    this.error,
    this.latency,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'response': response,
    'tool_call': toolCall?.toJson(),
    'tokens_used': tokensUsed,
    'mode': mode?.toString(),
    'error': error,
  };
}

/// Global instance
final llmRouter = LLMInferenceRouter();
