import 'package:flutter/foundation.dart';
import 'python_bridge_service.dart';
import '../config/secrets.dart';

/// AI Agent Service - Hybrid Implementation
/// Uses Python Backend ("The Brain") for LLM & Tools
/// Uses Native Dart for UI & Credits
///
/// **SARVAM AI ONLY (Single Reliable Key)**
class AIAgentService {
  // Singleton pattern
  static final AIAgentService _instance = AIAgentService._internal();
  factory AIAgentService() => _instance;
  AIAgentService._internal();

  bool _initialized = false;
  bool _keysInjected = false;

  /// Initialize the AI Agent Service
  Future<void> initialize({
    InferenceMode? preferredMode,
    bool? allowFallback,
  }) async {
    if (_initialized) return;
    _initialized = true;

    // Inject Secrets into Python Brain (Android Only)
    await _injectApiKey();

    debugPrint('[AIAgentService] Initialized with Target Sarvam Key');
  }

  /// Inject API key into the Python bridge.
  Future<void> _injectApiKey({bool force = false}) async {
    if (_keysInjected && !force) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final key = await AppSecrets.getSarvamApiKeyAsync();

      if (key.isEmpty) {
        debugPrint(
          '[AIAgentService] ⚠ Sarvam AI key not configured (single-key mode).',
        );
        return;
      }

      await pythonBridge.setConfig({
        'sarvam_api_key': key,
        'sarvam_chat_model': AppSecrets.sarvamChatModel,
        'sarvam_vision_model': AppSecrets.sarvamVisionModel,
      });

      _keysInjected = true;
      pythonBridge.markConfigured();

      debugPrint('[AIAgentService] ✓ Sarvam API key configured successfully.');
    } catch (e) {
      debugPrint('[AIAgentService] ⚠ Key injection failed: $e');
    }
  }

  Future<void> reinjectKeys() async {
    _keysInjected = false;
    await _injectApiKey(force: true);
  }

  /// Main chat method - routes to Python Bridge
  Future<AgentResponse> chat(
    String message, {
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userContext,
    required String userId,
  }) async {
    if (!_initialized) await initialize();
    if (!_keysInjected) await _injectApiKey();

    try {
      final historyStrings = conversationHistory
          ?.map((e) => e.map((k, v) => MapEntry(k, v.toString())))
          .toList();

      final result = await pythonBridge.chatWithLLM(
        query: message,
        conversationHistory: historyStrings,
        userContext: userContext,
      );

      final response = AgentResponse(
        response: result['response'] ?? 'Sorry, I could not process that.',
        actionTaken: result['action_taken'] ?? false,
        actionType: result['action_type'],
        actionData: result['action_data'],
        needsConfirmation: result['needs_confirmation'] ?? false,
        error: result['error'],
        sources: result['sources'],
      );

      if (response.actionTaken && response.actionType != null) {
        _handleCreditDeduction(response.actionType!);
      }

      return response;
    } catch (e) {
      debugPrint('[AIAgentService] Error: $e');
      return AgentResponse(
        response: 'I encountered an error connecting to my brain.',
        actionTaken: false,
        error: e.toString(),
      );
    }
  }

  void _handleCreditDeduction(String toolName) {
    debugPrint('[AIAgentService] Tool $toolName used (free)');
  }

  Future<bool> confirmAction(
    String actionType,
    Map<String, dynamic> parameters,
  ) async {
    return true;
  }
}

class AgentResponse {
  final String response;
  final bool actionTaken;
  final String? actionType;
  final Map<String, dynamic>? actionData;
  final bool needsConfirmation;
  final String? error;
  final String? inferenceMode;
  final int tokensUsed;
  final List<dynamic>? sources;

  AgentResponse({
    required this.response,
    required this.actionTaken,
    this.actionType,
    this.actionData,
    this.needsConfirmation = false,
    this.error,
    this.inferenceMode,
    this.tokensUsed = 0,
    this.sources,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    return AgentResponse(
      response: json['response'] ?? '',
      actionTaken: json['action_taken'] ?? false,
      actionType: json['action_type'],
      actionData: json['action_data'],
      needsConfirmation: json['needs_confirmation'] ?? false,
      error: json['error'],
      inferenceMode: json['inference_mode'],
      tokensUsed: json['tokens_used'] ?? 0,
      sources: json['sources'],
    );
  }

  Map<String, dynamic> toJson() => {
    'response': response,
    'action_taken': actionTaken,
    'action_type': actionType,
    'action_data': actionData,
    'needs_confirmation': needsConfirmation,
    'error': error,
    'inference_mode': inferenceMode,
    'tokens_used': tokensUsed,
    'sources': sources,
  };
}

final aiAgentService = AIAgentService();

enum InferenceMode { cloud, local, hybrid }
