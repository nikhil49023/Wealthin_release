import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_config.dart';
import 'llm_inference_router.dart';
import 'nemotron_inference_service.dart';

/// AI Agent Service - Connects Flutter to the Python AI backend
/// Provides agentic chat with tool execution capabilities
/// Now with LLM inference routing (local → cloud → OpenAI fallback)
class AIAgentService {
  // Singleton pattern
  static final AIAgentService _instance = AIAgentService._internal();
  factory AIAgentService() => _instance;
  AIAgentService._internal();

  // Use BackendConfig for dynamic port management
  String get _baseUrl => backendConfig.baseUrl;

  // LLM inference router for flexible model selection
  late LLMInferenceRouter _inferenceRouter;
  bool _initialized = false;

  /// Initialize with inference configuration
  Future<void> initialize({
    InferenceMode preferredMode = InferenceMode.local,
    String? openaiApiKey,
    bool allowFallback = true,
  }) async {
    if (_initialized) return;

    _inferenceRouter = LLMInferenceRouter();
    await _inferenceRouter.initialize(
      preferredMode: preferredMode,
      cloudEndpoint: _baseUrl,
      openaiApiKey: openaiApiKey,
      allowFallback: allowFallback,
    );

    _initialized = true;
    print('[AIAgentService] Initialized with mode: $preferredMode');
  }

  /// Send an agentic chat message with tool capabilities
  /// Returns structured response with action data
  /// Uses LLM inference routing (local → cloud → OpenAI)
  Future<AgentResponse> chat(
    String query, {
    Map<String, dynamic>? userContext,
    List<Map<String, dynamic>>? conversationHistory,
    String? userId,
    bool useDirectEndpoint = false,
  }) async {
    try {
      // Ensure initialization
      if (!_initialized) {
        await initialize();
      }

      // If explicitly requested or using direct backend
      if (useDirectEndpoint) {
        return await _chatViaDirectEndpoint(
          query,
          userContext: userContext,
          conversationHistory: conversationHistory,
          userId: userId,
        );
      }

      // Use LLM inference router for flexible model selection
      print('[AIAgentService] Routing chat query through LLM inference router');

      // Get available tools
      final tools = await getAvailableTools();

      // Build prompt with context
      final prompt = _buildPromptWithContext(
        query,
        userContext: userContext,
        conversationHistory: conversationHistory,
      );

      // Route through inference system
      final result = await _inferenceRouter.infer(
        prompt,
        tools: tools,
        maxTokens: 2048,
        temperature: 0.7,
      );

      if (!result.success) {
        // Fallback to direct endpoint if all inference modes fail
        print(
          '[AIAgentService] Inference failed, falling back to direct endpoint',
        );
        return await _chatViaDirectEndpoint(
          query,
          userContext: userContext,
          conversationHistory: conversationHistory,
          userId: userId,
        );
      }

      // Parse response and extract tool calls
      ToolCall? toolCall = result.toolCall;

      return AgentResponse(
        response: result.response ?? 'No response',
        actionTaken: toolCall != null,
        actionType: toolCall?.name,
        actionData: toolCall?.arguments,
        needsConfirmation: toolCall != null,
        inferenceMode: result.mode?.toString(),
        tokensUsed: result.tokensUsed,
      );
    } catch (e) {
      print('[AIAgentService] Chat error: $e');
      return AgentResponse(
        response:
            "I'm having trouble processing your request. Please try again.\n\nError: $e",
        actionTaken: false,
        error: e.toString(),
      );
    }
  }

  /// Chat via direct backend endpoint (fallback)
  Future<AgentResponse> _chatViaDirectEndpoint(
    String query, {
    Map<String, dynamic>? userContext,
    List<Map<String, dynamic>>? conversationHistory,
    String? userId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/agent/agentic-chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'user_context': userContext,
        'conversation_history': conversationHistory,
        'user_id': userId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI service error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return AgentResponse.fromJson(data);
  }

  /// Build prompt with financial context
  String _buildPromptWithContext(
    String query, {
    Map<String, dynamic>? userContext,
    List<Map<String, dynamic>>? conversationHistory,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are WealthIn, a personal financial advisor AI.');
    buffer.writeln('Help users manage their finances with practical advice.');
    buffer.writeln('');

    if (userContext != null && userContext.isNotEmpty) {
      buffer.writeln('User Context:');
      userContext.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
      buffer.writeln('');
    }

    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      buffer.writeln('Previous messages:');
      for (final msg in conversationHistory.take(5)) {
        buffer.writeln('${msg['role']}: ${msg['content']}');
      }
      buffer.writeln('');
    }

    buffer.writeln('User: $query');

    return buffer.toString();
  }

  /// Simple chat without tool execution (uses Gemini)
  Future<String> simpleChat(
    String query, {
    Map<String, dynamic>? context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/agent/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'context': context ?? {},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('AI service error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return data['response'] ?? 'No response from AI';
    } catch (e) {
      return "I'm having trouble connecting. Please try again later.\n\nError: $e";
    }
  }

  /// Confirm and execute an AI-suggested action
  Future<bool> confirmAction(
    String actionType,
    Map<String, dynamic> actionData, {
    String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/agent/confirm-action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action_type': actionType,
          'action_data': actionData,
          'user_id': userId,
        }),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get available AI tools
  Future<List<Map<String, dynamic>>> getAvailableTools() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/agent/tools'));

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['tools'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Calculate SIP returns
  Future<Map<String, dynamic>?> calculateSIP({
    required double monthlyInvestment,
    required double expectedRate,
    required int durationMonths,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/calculator/sip'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'monthly_investment': monthlyInvestment,
          'expected_rate': expectedRate,
          'duration_months': durationMonths,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  /// Calculate EMI
  Future<Map<String, dynamic>?> calculateEMI({
    required double principal,
    required double rate,
    required int tenureMonths,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/calculator/emi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'principal': principal,
          'rate': rate,
          'tenure_months': tenureMonths,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  /// Check if backend is reachable
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(
            const Duration(seconds: 5),
          );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get inference router status
  Map<String, dynamic> getInferenceStatus() {
    if (!_initialized) {
      return {
        'initialized': false,
        'status': 'AIAgentService not initialized',
      };
    }

    return {
      'initialized': true,
      'inferenceRouter': _inferenceRouter.getStatus(),
    };
  }

  /// Switch inference mode
  void setInferenceMode(InferenceMode mode) {
    if (!_initialized) return;
    _inferenceRouter.setPreferredMode(mode);
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
