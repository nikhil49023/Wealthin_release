import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Nemotron LLM Inference Service
/// Handles local model loading and inference with Nemotron function calling format
class NemotronInferenceService {
  static final NemotronInferenceService _instance =
      NemotronInferenceService._internal();
  factory NemotronInferenceService() => _instance;
  NemotronInferenceService._internal();

  // Model configuration
  static const String SARVAM_1_1B_MODEL = 'sarvam-1-1b-q4';
  static const String SARVAM_1_3B_MODEL = 'sarvam-1-3b-q4';
  static const String SARVAM_1_FULL_MODEL = 'sarvam-1';

  bool _isInitialized = false;
  bool _isModelLoaded = false;
  String? _loadedModelName;
  final Map<String, dynamic> _modelCache = {};

  /// Initialize inference service (device capability detection)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Detect device capabilities
      final capabilities = await _detectDeviceCapabilities();
      print('[NemotronInference] Device capabilities: $capabilities');

      _isInitialized = true;
    } catch (e) {
      print('[NemotronInference] Initialization error: $e');
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  /// Public getter for model loaded status
  bool get isModelLoaded => _isModelLoaded;

  /// Public getter for loaded model name
  String? get loadedModelName => _loadedModelName;

  /// Detect device RAM and storage for model selection
  Future<Map<String, dynamic>> detectDeviceCapabilities() async {
    return _detectDeviceCapabilities();
  }

  /// Load optimal model automatically
  Future<void> loadOptimalModel() async {
    final capabilities = await detectDeviceCapabilities();
    final optimalModel = selectOptimalModel(capabilities);
    await loadModel(optimalModel);
  }
  Future<Map<String, dynamic>> _detectDeviceCapabilities() async {
    try {
      final ProcessResult result = await Process.run('free', ['-b']);
      final memOutput = result.stdout.toString();
      print('[NemotronInference] Memory info: $memOutput');

      return {
        'platform': Platform.operatingSystem,
        'isAndroid': Platform.isAndroid,
        'isIOS': Platform.isIOS,
        'isLinux': Platform.isLinux,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // Default capabilities if detection fails
      return {
        'platform': Platform.operatingSystem,
        'isAndroid': Platform.isAndroid,
        'isIOS': Platform.isIOS,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Select optimal model based on device capabilities
  String selectOptimalModel(Map<String, dynamic> capabilities) {
    // Mobile devices: use quantized 1B model
    if (capabilities['isAndroid'] == true || capabilities['isIOS'] == true) {
      return SARVAM_1_1B_MODEL;
    }

    // Larger devices: use 3B model
    return SARVAM_1_3B_MODEL;
  }

  /// Load a model (simulation - real implementation would use mlc_llm or similar)
  Future<bool> loadModel(String modelName) async {
    if (_isModelLoaded && _loadedModelName == modelName) {
      return true;
    }

    try {
      print('[NemotronInference] Loading model: $modelName');

      // In production, this would:
      // 1. Check if model file exists locally
      // 2. Download if needed from Hugging Face or similar
      // 3. Load into memory using mlc_llm or similar framework
      // 4. Verify model signature and safety

      _loadedModelName = modelName;
      _isModelLoaded = true;

      print('[NemotronInference] Model loaded successfully: $modelName');
      return true;
    } catch (e) {
      print('[NemotronInference] Failed to load model: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Infer using loaded local model (Nemotron format)
  Future<NemotronResponse> inferLocal(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
    Map<String, dynamic>? systemPrompt,
  }) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      print(
        '[NemotronInference] Inferring locally with model: $_loadedModelName',
      );

      // In production, this would:
      // 1. Prepare prompt with system message and tools
      // 2. Call mlc_llm inference
      // 3. Parse Nemotron function calling format
      // 4. Return structured response

      // For now, return mock response structure
      return NemotronResponse(
        text: 'Mock response - local inference not yet implemented',
        toolCall: null,
        finishReason: 'length',
        tokensUsed: 0,
        isLocal: true,
      );
    } catch (e) {
      print('[NemotronInference] Local inference error: $e');
      rethrow;
    }
  }

  /// Infer using cloud endpoint (Nemotron format)
  Future<NemotronResponse> inferCloud(
    String prompt, {
    String cloudEndpoint = 'http://localhost:8000',
    List<Map<String, dynamic>>? tools,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    try {
      print('[NemotronInference] Inferring via cloud endpoint');

      final response = await http
          .post(
            Uri.parse('$cloudEndpoint/llm/inference'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'prompt': prompt,
              'tools': tools,
              'max_tokens': maxTokens,
              'temperature': temperature,
              'format': 'nemotron', // Specify Nemotron function calling format
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          'Cloud inference failed: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      return NemotronResponse.fromJson(data);
    } catch (e) {
      print('[NemotronInference] Cloud inference error: $e');
      rethrow;
    }
  }

  /// Parse Nemotron function calling format
  /// Expected format: {"type": "tool_call", "tool_call": {"name": "...", "arguments": {...}}}
  static ToolCall? parseToolCall(String response) {
    try {
      // Try to extract JSON from response
      final regex = RegExp(r'\{[\s\S]*\}');
      final match = regex.firstMatch(response);

      if (match == null) {
        return null;
      }

      final jsonStr = match.group(0)!;
      final json = jsonDecode(jsonStr);

      // Check for Nemotron format
      if (json['type'] == 'tool_call' && json['tool_call'] != null) {
        final toolCall = json['tool_call'] as Map<String, dynamic>;
        return ToolCall(
          name: toolCall['name'] as String? ?? '',
          arguments: toolCall['arguments'] as Map<String, dynamic>? ?? {},
        );
      }

      return null;
    } catch (e) {
      print('[NemotronInference] Failed to parse tool call: $e');
      return null;
    }
  }

  /// Get model status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'modelLoaded': _isModelLoaded,
      'loadedModel': _loadedModelName,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Clear cache
  void clearCache() {
    _modelCache.clear();
  }

  /// Unload model (cleanup)
  Future<void> unloadModel() async {
    _isModelLoaded = false;
    _loadedModelName = null;
    _modelCache.clear();
    print('[NemotronInference] Model unloaded');
  }
}

/// Response from Nemotron inference
class NemotronResponse {
  final String text;
  final ToolCall? toolCall;
  final String finishReason;
  final int tokensUsed;
  final bool isLocal;
  final DateTime timestamp;

  NemotronResponse({
    required this.text,
    required this.toolCall,
    required this.finishReason,
    required this.tokensUsed,
    required this.isLocal,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NemotronResponse.fromJson(Map<String, dynamic> json) {
    // Parse tool_call from response
    ToolCall? toolCall;
    if (json['tool_call'] != null) {
      final tc = json['tool_call'] as Map<String, dynamic>;
      toolCall = ToolCall(
        name: tc['name'] as String? ?? '',
        arguments: tc['arguments'] as Map<String, dynamic>? ?? {},
      );
    }

    return NemotronResponse(
      text: json['text'] ?? json['response'] ?? '',
      toolCall: toolCall,
      finishReason: json['finish_reason'] ?? 'stop',
      tokensUsed: json['tokens_used'] ?? 0,
      isLocal: json['is_local'] ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'tool_call': toolCall?.toJson(),
    'finish_reason': finishReason,
    'tokens_used': tokensUsed,
    'is_local': isLocal,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Tool call extracted from model response
class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'arguments': arguments,
  };
}

/// Global instance
final nemotronInference = NemotronInferenceService();
