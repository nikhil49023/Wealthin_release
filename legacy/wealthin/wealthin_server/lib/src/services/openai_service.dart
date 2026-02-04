import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

/// OpenAI Configuration
class OpenAIConfig {
  static String get apiKey => Platform.environment['OPENAI_API_KEY'] ?? '';
  static bool get isValid => apiKey.isNotEmpty;
}

/// OpenAIService: Integration with OpenAI for orchestration and advanced reasoning
/// Used as the supervisor/orchestrator in the tri-model architecture
class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  
  // Singleton pattern
  static final OpenAIService _instance = OpenAIService._internal();
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  /// Chat completion using OpenAI
  Future<String> chat(
    List<Map<String, String>> messages, {
    String model = 'gpt-4o-mini',
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    if (!OpenAIConfig.isValid) {
      throw Exception('OpenAI API key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenAI API error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content'] ?? '';
    } catch (e) {
      print('Error calling OpenAI: $e');
      rethrow;
    }
  }

  /// Simple chat with user message
  Future<String> simpleChat(String message, {String systemPrompt = ''}) async {
    final messages = <Map<String, String>>[];
    
    if (systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': message});
    
    return await chat(messages);
  }

  /// Function calling for agentic behavior
  Future<Map<String, dynamic>> functionCall(
    String message,
    List<Map<String, dynamic>> functions, {
    String systemPrompt = 'You are a helpful financial assistant.',
  }) async {
    if (!OpenAIConfig.isValid) {
      throw Exception('OpenAI API key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': message},
          ],
          'tools': functions.map((f) => {'type': 'function', 'function': f}).toList(),
          'tool_choice': 'auto',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenAI Function Call error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final choice = data['choices']?[0];
      final toolCalls = choice?['message']?['tool_calls'];
      
      if (toolCalls != null && toolCalls.isNotEmpty) {
        return {
          'type': 'function_call',
          'function': toolCalls[0]['function']['name'],
          'arguments': jsonDecode(toolCalls[0]['function']['arguments'] ?? '{}'),
          'message': choice?['message']?['content'],
        };
      }
      
      return {
        'type': 'message',
        'content': choice?['message']?['content'] ?? '',
      };
    } catch (e) {
      print('Error in OpenAI function call: $e');
      rethrow;
    }
  }

  /// Orchestrate between different AI services
  Future<OrchestrationDecision> orchestrate(String query) async {
    const systemPrompt = '''You are an AI orchestrator for a financial app called WealthIn.
Your job is to decide which AI service should handle a user query:

1. "sarvam" - For queries in Indian regional languages (Hindi, Telugu, Tamil, etc.) or about local Indian business concepts
2. "rag" - For factual questions about taxes, regulations, schemes, investments, or when accuracy is critical
3. "llm" - For conversational queries, greetings, personal advice, tips, or general chat

Respond with ONLY a JSON object: {"service": "sarvam|rag|llm", "reason": "brief explanation"}''';

    try {
      final response = await simpleChat(query, systemPrompt: systemPrompt);
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      
      if (jsonMatch != null) {
        final data = jsonDecode(jsonMatch.group(0)!);
        return OrchestrationDecision(
          service: data['service'] ?? 'llm',
          reason: data['reason'] ?? 'Default routing',
        );
      }
    } catch (e) {
      print('Orchestration error: $e');
    }
    
    return OrchestrationDecision(
      service: 'llm',
      reason: 'Fallback to LLM',
    );
  }
}

/// Orchestration decision from OpenAI
class OrchestrationDecision {
  final String service;
  final String reason;

  OrchestrationDecision({required this.service, required this.reason});
}
