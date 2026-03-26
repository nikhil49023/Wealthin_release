import 'package:flutter/foundation.dart';
import 'python_bridge_service.dart';
import '../config/secrets.dart';
import 'sarvam_key_manager.dart';

/// AI Agent Service - Hybrid Implementation
/// Uses Python Backend ("The Brain") for LLM & Tools
/// Uses Native Dart for UI & Credits
///
/// **SARVAM AI ONLY with Multi-Key Support**
/// - Uses multiple API keys for higher throughput
/// - Automatic round-robin key rotation
/// - Smart fallback on rate limits
class AIAgentService {
  // Singleton pattern
  static final AIAgentService _instance = AIAgentService._internal();
  factory AIAgentService() => _instance;
  AIAgentService._internal();

  bool _initialized = false;
  bool _keysInjected = false;
  final SarvamAIKeyManager keyManager = SarvamAIKeyManager();

  /// Initialize the AI Agent Service
  Future<void> initialize({
    InferenceMode? preferredMode,
    bool? allowFallback,
  }) async {
    if (_initialized) return;
    _initialized = true;

    // Inject Secrets into Python Brain (Android Only)
    await _injectApiKeys();

    debugPrint('[AIAgentService] Initialized with Multi-Key Sarvam AI (Hybrid Mode)');
  }

  /// Inject API keys into the Python bridge.
  /// Supports multiple keys for distributed rate limiting.
  /// Uses ASYNC getters to ensure keys are loaded from secure storage.
  /// Can be called multiple times — will only inject if not already done.
  ///
  /// **SARVAM AI ONLY** - All AI features now use Sarvam
  Future<void> _injectApiKeys({bool force = false}) async {
    if (_keysInjected && !force) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      // Get all available Sarvam API keys (could be multiple)
      final sarvamKeys = await AppSecrets.getSarvamApiKeysAsync();

      debugPrint('[AIAgentService] Found ${sarvamKeys.length} Sarvam AI key(s)');

      if (sarvamKeys.isEmpty) {
        debugPrint('[AIAgentService] ⚠ Sarvam AI keys not configured!');
        return; // Don't mark as injected so we retry next time
      }

      // Initialize key manager with all available keys
      await keyManager.initialize(sarvamKeys);

      // Inject primary key to Python bridge (key manager will handle rotation)
      final primaryKey = keyManager.getNextKey();
      await pythonBridge.setConfig({
        'sarvam_api_key': primaryKey,
        'sarvam_chat_model': AppSecrets.sarvamChatModel,
        'sarvam_vision_model': AppSecrets.sarvamVisionModel,
        'sarvam_api_keys': sarvamKeys.join(','), // Pass all keys for Python fallback
      });

      _keysInjected = true;
      pythonBridge.markConfigured();

      final totalCapacity = sarvamKeys.length * 60;
      debugPrint(
        '[AIAgentService] ✓ Sarvam API keys configured '
        '(${sarvamKeys.length} keys × 60 RPM = $totalCapacity RPM total)',
      );
    } catch (e) {
      debugPrint('[AIAgentService] ⚠ Key injection failed: $e');
      // Don't mark as injected so we retry next time
    }
  }

  /// Force re-inject API keys (call after user updates keys in Settings)
  Future<void> reinjectKeys() async {
    _keysInjected = false;
    await _injectApiKeys(force: true);
  }

  /// Get next available Sarvam API key with automatic fallback
  String getNextAvailableKey() {
    try {
      return keyManager.getNextKey();
    } catch (e) {
      debugPrint('[AIAgentService] ⚠ Error getting next key: $e');
      // Fallback to single key if manager fails
      return AppSecrets.sarvamApiKey;
    }
  }

  /// Record successful API request
  void recordApiRequest(String key) {
    keyManager.recordRequest(key);
  }

  /// Record rate limit error (enables fallback)
  void recordRateLimit(String key) {
    keyManager.recordRateLimit(key);
  }

  /// Get current key manager status (for debugging/monitoring)
  Map<String, dynamic> getKeyManagerStatus() {
    return keyManager.getStatus();
  }

  /// Main chat method - routes to Python Bridge
  Future<AgentResponse> chat(
    String message, {
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userContext,
    required String userId,
  }) async {
    if (!_initialized) await initialize();
    // Ensure keys are injected (handles race conditions during startup)
    if (!_keysInjected) await _injectApiKeys();

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
        sources: result['sources'],
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
  final List<dynamic>? sources;  // Web search sources with URLs

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

/// Global instance
final aiAgentService = AIAgentService();

// Inference Mode Enum (kept for compatibility)
enum InferenceMode { cloud, local, hybrid }
