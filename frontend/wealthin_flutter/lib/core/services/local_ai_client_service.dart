import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Local AI Client Service
///
/// Supports both Ollama and llama-server backends:
/// - Ollama: http://localhost:11434 (default)
/// - llama-server: http://localhost:8000
///
/// Provides OpenAI-compatible chat completions API
class LocalAIClientService {
  static final LocalAIClientService _instance = LocalAIClientService._internal();
  factory LocalAIClientService() => _instance;
  LocalAIClientService._internal();

  // Backend configuration
  String _baseUrl = 'http://localhost:11434'; // Default: Ollama
  String _modelName = 'tinyllama'; // Default model
  AIBackend _backend = AIBackend.ollama;
  bool _isAvailable = false;
  DateTime? _lastHealthCheck;
  static const _healthCheckInterval = Duration(minutes: 2);

  // Stats
  int _totalQueries = 0;
  int _successfulQueries = 0;
  int _failedQueries = 0;
  Duration _totalLatency = Duration.zero;

  /// Initialize and detect backend
  Future<bool> initialize() async {
    debugPrint('[LocalAI] Initializing...');

    // Try Ollama first (port 11434)
    if (await _detectOllama()) {
      _backend = AIBackend.ollama;
      _baseUrl = 'http://localhost:11434';
      _isAvailable = true;
      debugPrint('[LocalAI] ✓ Ollama detected at $_baseUrl');
      return true;
    }

    // Fallback to llama-server (port 8000)
    if (await _detectLlamaServer()) {
      _backend = AIBackend.llamaServer;
      _baseUrl = 'http://localhost:8000';
      _isAvailable = true;
      debugPrint('[LocalAI] ✓ llama-server detected at $_baseUrl');
      return true;
    }

    _isAvailable = false;
    debugPrint('[LocalAI] ✗ No local AI backend available');
    return false;
  }

  /// Check if local AI is available
  Future<bool> isAvailable() async {
    // Use cached status if recent
    if (_lastHealthCheck != null &&
        DateTime.now().difference(_lastHealthCheck!) < _healthCheckInterval) {
      return _isAvailable;
    }

    // Perform health check
    _lastHealthCheck = DateTime.now();

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      _isAvailable = response.statusCode == 200;
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  /// Generate chat completion
  Future<String> generateCompletion(
    String prompt, {
    List<Map<String, dynamic>>? conversationHistory,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async {
    if (!_isAvailable) {
      throw Exception('Local AI backend not available');
    }

    _totalQueries++;
    final startTime = DateTime.now();

    try {
      final response = _backend == AIBackend.ollama
          ? await _generateOllama(prompt, conversationHistory, temperature, maxTokens)
          : await _generateLlamaServer(prompt, conversationHistory, temperature, maxTokens);

      final latency = DateTime.now().difference(startTime);
      _totalLatency += latency;
      _successfulQueries++;

      debugPrint('[LocalAI] ✓ Completed in ${latency.inMilliseconds}ms (${_backend.name})');
      return response;
    } catch (e) {
      _failedQueries++;
      final latency = DateTime.now().difference(startTime);
      debugPrint('[LocalAI] ✗ Failed after ${latency.inMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Generate with Ollama backend
  Future<String> _generateOllama(
    String prompt,
    List<Map<String, dynamic>>? history,
    double temperature,
    int maxTokens,
  ) async {
    // Build messages array
    final messages = <Map<String, dynamic>>[];

    // Add system prompt for financial context
    messages.add({
      'role': 'system',
      'content': 'You are Artha, a helpful financial assistant for the Wealthin app. '
          'Provide clear, accurate financial advice in simple terms. '
          'Focus on Indian financial context when relevant.'
    });

    // Add conversation history
    if (history != null && history.isNotEmpty) {
      messages.addAll(history);
    }

    // Add current prompt
    messages.add({'role': 'user', 'content': prompt});

    // Ollama API request
    final request = {
      'model': _modelName,
      'messages': messages,
      'stream': false,
      'options': {
        'temperature': temperature,
        'num_predict': maxTokens,
      }
    };

    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Ollama API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['message']?['content'] as String?;

    if (content == null || content.isEmpty) {
      throw Exception('Empty response from Ollama');
    }

    return content;
  }

  /// Generate with llama-server backend (OpenAI-compatible)
  Future<String> _generateLlamaServer(
    String prompt,
    List<Map<String, dynamic>>? history,
    double temperature,
    int maxTokens,
  ) async {
    // Build messages array
    final messages = <Map<String, dynamic>>[];

    // Add system prompt
    messages.add({
      'role': 'system',
      'content': 'You are Artha, a helpful financial assistant for the Wealthin app. '
          'Provide clear, accurate financial advice in simple terms.'
    });

    // Add conversation history
    if (history != null && history.isNotEmpty) {
      messages.addAll(history);
    }

    // Add current prompt
    messages.add({'role': 'user', 'content': prompt});

    // OpenAI-compatible API request
    final request = {
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    final response = await http
        .post(
          Uri.parse('$_baseUrl/v1/chat/completions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('llama-server API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices']?[0]?['message']?['content'] as String?;

    if (content == null || content.isEmpty) {
      throw Exception('Empty response from llama-server');
    }

    return content;
  }

  /// Detect Ollama backend
  Future<bool> _detectOllama() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:11434/api/tags'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List?;

        if (models != null && models.isNotEmpty) {
          // Find best available model
          final modelNames = models.map((m) => m['name'] as String).toList();

          if (modelNames.any((m) => m.contains('tinyllama'))) {
            _modelName = modelNames.firstWhere((m) => m.contains('tinyllama'));
          } else if (modelNames.any((m) => m.contains('llama'))) {
            _modelName = modelNames.firstWhere((m) => m.contains('llama'));
          } else {
            _modelName = modelNames.first;
          }

          debugPrint('[LocalAI] Ollama models available: ${modelNames.join(", ")}');
          debugPrint('[LocalAI] Using model: $_modelName');
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Detect llama-server backend
  Future<bool> _detectLlamaServer() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8000/health'))
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Configure custom backend URL
  void setBackendUrl(String url, AIBackend backend) {
    _baseUrl = url;
    _backend = backend;
    _isAvailable = false; // Force re-check
    _lastHealthCheck = null;
    debugPrint('[LocalAI] Backend changed to ${backend.name} at $url');
  }

  /// Set model name (for Ollama)
  void setModel(String modelName) {
    _modelName = modelName;
    debugPrint('[LocalAI] Model changed to $_modelName');
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    final avgLatency = _successfulQueries > 0
        ? _totalLatency.inMilliseconds / _successfulQueries
        : 0.0;

    return {
      'backend': _backend.name,
      'base_url': _baseUrl,
      'model': _modelName,
      'is_available': _isAvailable,
      'total_queries': _totalQueries,
      'successful_queries': _successfulQueries,
      'failed_queries': _failedQueries,
      'success_rate': _totalQueries > 0 ? _successfulQueries / _totalQueries : 0.0,
      'avg_latency_ms': avgLatency.round(),
    };
  }

  /// Reset statistics
  void resetStats() {
    _totalQueries = 0;
    _successfulQueries = 0;
    _failedQueries = 0;
    _totalLatency = Duration.zero;
  }
}

enum AIBackend {
  ollama,
  llamaServer,
}

// Singleton instances
final localAIClient = LocalAIClientService();
