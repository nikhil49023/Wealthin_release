import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'data_service.dart';
import 'python_bridge_service.dart';
import '../config/secrets.dart';

/// AI Agent Service - Hybrid Implementation
/// Uses Python Backend ("The Brain") for LLM & Tools
/// Uses Native Dart for UI & Credits
class AIAgentService {
  // Singleton pattern
  static final AIAgentService _instance = AIAgentService._internal();
  factory AIAgentService() => _instance;
  AIAgentService._internal();

  bool _initialized = false;

  /// Initialize the AI Agent Service
  Future<void> initialize({
    InferenceMode? preferredMode,
    bool? allowFallback,
  }) async {
    if (_initialized) return;
    _initialized = true;
    
    // Inject Secrets into Python Brain (Android Only)
    if (defaultTargetPlatform == TargetPlatform.android) {
       await pythonBridge.setConfig({
         'sarvam_api_key': AppSecrets.sarvamApiKey,
         'scrapingdog_api_key': AppSecrets.scrapingDogApiKey,
       });
    }
    
    debugPrint('[AIAgentService] Initialized (Hybrid Mode)');
  }

  /// Main chat method - routes to Python Bridge
  Future<AgentResponse> chat(
    String message, {
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userContext,
    required String userId,
  }) async {
    if (!_initialized) await initialize();

    try {
      // route to Python Brain
      // Map Dart history/context to what Python expects (List<Map<String, String>>)
      // Actually PythonBridge accepts List<Map<String, String>> for history
      
      final historyStrings = conversationHistory?.map((e) => 
        e.map((k, v) => MapEntry(k, v.toString()))
      ).toList();

      final result = await pythonBridge.chatWithLLM(
        query: message,
        conversationHistory: historyStrings,
        userContext: userContext,
      );

      // Parse response
      final response = AgentResponse(
        response: result['response'] ?? 'Sorry, I could not process that.',
        actionTaken: result['action_taken'] ?? false,
        actionType: result['action_type'],
        actionData: result['action_data'],
        needsConfirmation: result['needs_confirmation'] ?? false,
        error: result['error'],
      );

      // --- Credit System Integration ---
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

  /// Handle credit deduction for search tools
  /// NOTE: Credits are NOT deducted for web search - it's free!
  void _handleCreditDeduction(String toolName) {
    // Web search is free - no credit deduction
    // Only premium tools (if any) would deduct credits
    debugPrint('[AIAgentService] Tool $toolName used (free)');
  }


  /// Confirm and execute an action
  Future<bool> confirmAction(String actionType, Map<String, dynamic> parameters) async {
    // Placeholder for action confirmation
    // TODO: Implement actual execution logic (tool calls or DB operations)
    return true;
  }
}

/// Response from the AI agent
class AgentResponse {
  final String response;
  final bool actionTaken;
  final String? actionType;
  final Map<String, dynamic>? actionData;
  final bool needsConfirmation;
  final String? error;
  final String? inferenceMode;
  final int tokensUsed;

  AgentResponse({
    required this.response,
    required this.actionTaken,
    this.actionType,
    this.actionData,
    this.needsConfirmation = false,
    this.error,
    this.inferenceMode,
    this.tokensUsed = 0,
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
  };
}

/// Global instance
final aiAgentService = AIAgentService();

// Inference Mode Enum (kept for compatibility)
enum InferenceMode { cloud, local, hybrid }
