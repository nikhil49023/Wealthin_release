import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/zoho_config.dart';

class ZohoService {
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Singleton pattern
  static final ZohoService _instance = ZohoService._internal();
  factory ZohoService() => _instance;
  ZohoService._internal();

  /// Refreshes and returns a valid access token.
  Future<String> getValidAccessToken() async {
    if (!ZohoConfig.isValid) {
      throw Exception('Zoho Catalyst configuration is missing. Check environment variables.');
    }

    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    const tokenUrl = 'https://accounts.zoho.in/oauth/v2/token';
    final response = await http.post(
      Uri.parse(tokenUrl),
      body: {
        'refresh_token': ZohoConfig.refreshToken,
        'client_id': ZohoConfig.clientId,
        'client_secret': ZohoConfig.clientSecret,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
       throw Exception('Failed to refresh Zoho token: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (data['error'] != null) {
       throw Exception('Zoho token error: ${data['error']}');
    }

    _accessToken = data['access_token'];
    // Expires in seconds, subtract buffer time
    int expiresIn = data['expires_in'] ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300));
    
    return _accessToken!;
  }

  /// Helper to call Zoho LLM Chat Endpoint
  Future<String> chat(String systemPrompt, String userMessage) async {
    try {
      final token = await getValidAccessToken();
      final url = 'https://api.catalyst.zoho.in/quickml/v2/project/${ZohoConfig.projectId}/llm/chat';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'CATALYST-ORG': ZohoConfig.orgId,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'prompt': userMessage,
          'model': 'crm-di-qwen_text_14b-fp8-it', 
          'system_prompt': systemPrompt,
          'top_p': 0.9,
          'top_k': 50,
          'best_of': 1,
          'temperature': 0.7,
          'max_tokens': 2048,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Zoho LLM API failed: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['response'] ?? '';
    } catch (e) {
      print('Error calling Zoho LLM: $e');
      rethrow;
    }
  }

  /// Call Zoho RAG Endpoint
  Future<String> ragAnswer(String query) async {
    try {
      final token = await getValidAccessToken();
      const url = 'https://console.catalyst.zoho.in/quickml/v1/project/24392000000011167/rag/answer';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'CATALYST-ORG': ZohoConfig.orgId,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
          'top_k': 5,
        }),
      );

      if (response.statusCode != 200) {
        // Fallback to LLM chat if RAG endpoint fails (e.g. 500 or 404)
        print('Zoho RAG failed (${response.statusCode}), falling back to LLM Serve...');
        return await chat('You are a helpful assistant. Provide a comprehensive answer to the user request.', query);
      }

      final data = jsonDecode(response.body);
      final answer = data['answer'] as String?;
      
      if (answer == null || answer.isEmpty || answer.contains('No answer found')) {
         print('Zoho RAG returned no answer, falling back to LLM Serve...');
         return await chat('You are a helpful assistant. Provide a comprehensive answer to the user request.', query);
      }
      
      return answer;
    } catch (e) {
      print('Error calling Zoho RAG: $e. Falling back to LLM Serve.');
      return await chat('You are a helpful assistant. Provide a comprehensive answer to the user request.', query);
    }
  }

  /// Call Zoho Vision (VLM) Endpoint
  Future<String> visionChat(String prompt, List<String> base64Images) async {
    try {
      final token = await getValidAccessToken();
      final url = 'https://api.catalyst.zoho.in/quickml/v1/project/${ZohoConfig.projectId}/vlm/chat';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'CATALYST-ORG': ZohoConfig.orgId,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'prompt': prompt,
          'model': 'VL-Qwen2.5-7B',
          'images': base64Images,
          'top_k': 50,
          'top_p': 0.9,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Zoho Vision API failed: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['response'] ?? '';
    } catch (e) {
      print('Error calling Zoho Vision: $e');
      rethrow;
    }
  }
}
