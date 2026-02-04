import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

/// SarvamConfig: Configuration for Sarvam AI
class SarvamConfig {
  static String get apiKey => Platform.environment['SARVAM_API_KEY'] ?? '';
  static bool get isValid => apiKey.isNotEmpty;
}

/// SarvamService: Integration with Sarvam AI for Indic language support
/// Provides culturally and linguistically relevant responses for Indian users
class SarvamService {
  static const String _baseUrl = 'https://api.sarvam.ai/v1';
  
  // Singleton pattern
  static final SarvamService _instance = SarvamService._internal();
  factory SarvamService() => _instance;
  SarvamService._internal();

  /// Check if query contains Indic language text
  bool isIndicQuery(String query) {
    // Check for Devanagari (Hindi, Marathi, Sanskrit)
    final devanagari = RegExp(r'[\u0900-\u097F]');
    // Check for Telugu
    final telugu = RegExp(r'[\u0C00-\u0C7F]');
    // Check for Tamil
    final tamil = RegExp(r'[\u0B80-\u0BFF]');
    // Check for Kannada
    final kannada = RegExp(r'[\u0C80-\u0CFF]');
    // Check for Malayalam
    final malayalam = RegExp(r'[\u0D00-\u0D7F]');
    // Check for Bengali
    final bengali = RegExp(r'[\u0980-\u09FF]');
    // Check for Gujarati
    final gujarati = RegExp(r'[\u0A80-\u0AFF]');
    
    return devanagari.hasMatch(query) ||
        telugu.hasMatch(query) ||
        tamil.hasMatch(query) ||
        kannada.hasMatch(query) ||
        malayalam.hasMatch(query) ||
        bengali.hasMatch(query) ||
        gujarati.hasMatch(query);
  }

  /// Detect the language of the query
  String detectLanguage(String query) {
    if (RegExp(r'[\u0900-\u097F]').hasMatch(query)) return 'hindi';
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(query)) return 'telugu';
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(query)) return 'tamil';
    if (RegExp(r'[\u0C80-\u0CFF]').hasMatch(query)) return 'kannada';
    if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(query)) return 'malayalam';
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(query)) return 'bengali';
    if (RegExp(r'[\u0A80-\u0AFF]').hasMatch(query)) return 'gujarati';
    return 'english';
  }

  /// Chat completion using Sarvam AI
  Future<String> chat(List<Map<String, String>> messages) async {
    if (!SarvamConfig.isValid) {
      throw Exception('Sarvam API key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SarvamConfig.apiKey}',
        },
        body: jsonEncode({
          'messages': messages,
          'model': 'sarvam-2b', // Sarvam's Indic language model
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Sarvam API error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content'] ?? '';
    } catch (e) {
      print('Error calling Sarvam AI: $e');
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

  /// Translate text using Sarvam AI
  Future<String> translate(String text, String sourceLanguage, String targetLanguage) async {
    if (!SarvamConfig.isValid) {
      throw Exception('Sarvam API key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/translate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SarvamConfig.apiKey}',
        },
        body: jsonEncode({
          'text': text,
          'source_language': sourceLanguage,
          'target_language': targetLanguage,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Sarvam Translation error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      return data['translated_text'] ?? text;
    } catch (e) {
      print('Error translating with Sarvam: $e');
      return text; // Return original text on error
    }
  }

  /// Transliterate text (convert script)
  Future<String> transliterate(String text, String targetScript) async {
    if (!SarvamConfig.isValid) {
      throw Exception('Sarvam API key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transliterate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SarvamConfig.apiKey}',
        },
        body: jsonEncode({
          'text': text,
          'target_script': targetScript,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Sarvam Transliteration error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return data['transliterated_text'] ?? text;
    } catch (e) {
      print('Error transliterating with Sarvam: $e');
      return text;
    }
  }
}
