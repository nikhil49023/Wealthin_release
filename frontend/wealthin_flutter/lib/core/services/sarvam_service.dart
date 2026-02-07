import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/secrets.dart';

class SarvamService {
  static const String _baseUrl = "https://api.sarvam.ai/v1";
  static const String _diBaseUrl = "https://api.sarvam.ai"; // Document Intelligence base
  
  // Use centralized secrets - never hardcode API keys
  static String get _apiKey => AppSecrets.sarvamApiKey;

  // Singleton
  static final SarvamService _instance = SarvamService._internal();
  factory SarvamService() => _instance;
  SarvamService._internal();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'api-subscription-key': _apiKey,
  };

  /// Chat with Sarvam AI
  Future<Map<String, dynamic>> chat(String query, {List<Map<String, String>>? history, String? context}) async {
    try {
      final messages = <Map<String, String>>[];
      
      // Add context as system/first message
      if (context != null && context.isNotEmpty) {
        messages.add({
          "role": "system", 
          "content": "You are WealthIn, an expert AI financial advisor for Indian users. Use ₹ for currency. $context"
        });
      }

      // Add history
      if (history != null) {
        messages.addAll(history);
      }

      // Add current query
      messages.add({"role": "user", "content": query});

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          "model": "sarvam-2b-v2",
          "messages": messages,
          "temperature": 0.3,
          "max_tokens": 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? "I couldn't generate a response.";
        return {
          "success": true,
          "response": content,
        };
      } else {
        return {
          "success": false,
          "error": "HTTP ${response.statusCode}: ${response.body}",
          "response": "I'm having trouble connecting to the server."
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
        "response": "Connection error: $e"
      };
    }
  }

  /// Extract transactions from text using Sarvam AI
  Future<Map<String, dynamic>> extractTransactionsFromText(String text) async {
    try {
      // Truncate text if too long to avoid token limits (Sarvam 2B ~4k-8k context)
      final truncatedText = text.length > 6000 ? text.substring(0, 6000) : text;
      
      final prompt = """
      Extract financial transactions from this bank statement text.
      Return strictly a JSON array of objects with keys: "date" (YYYY-MM-DD), "description", "amount" (number), "type" ("credit" or "debit").
      Ignore headers/footers. If no transactions found, return [].
      
      Text Data:
      $truncatedText
      
      JSON Array:
      """;

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          "model": "sarvam-2b-v2",
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.1, // Low temp for extraction
          "max_tokens": 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices']?[0]?['message']?['content'] ?? "[]";
        
        // Clean markdown
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();
        
        // Create transactions list
        try {
           // Find bracket
           final start = content.indexOf('[');
           final end = content.lastIndexOf(']');
           if (start != -1 && end != -1) {
             final jsonStr = content.substring(start, end + 1);
             final List<dynamic> list = jsonDecode(jsonStr);
             return {
               "success": true,
               "transactions": list,
               "bank_detected": "Universal Text Import"
             };
           }
        } catch (e) {
          debugPrint("JSON Parse Error: $content");
        }
        return {"success": false, "error": "Could not parse JSON from AI response"};
      }
      return {"success": false, "error": "AI Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ==================== DOCUMENT INTELLIGENCE API ====================
  
  /// Create a Document Intelligence Job
  Future<String?> createDocumentJob({String language = "en-IN", String outputFormat = "json"}) async {
    try {
      final response = await http.post(
        Uri.parse('$_diBaseUrl/document-intelligence/create-job'),
        headers: _headers,
        body: jsonEncode({
          "language": language,
          "output_format": outputFormat,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['job_id']?.toString();
      }
      debugPrint("Create Job Error: ${response.body}");
      return null;
    } catch (e) {
      debugPrint("Create Job Exception: $e");
      return null;
    }
  }

  /// Upload a file to a Document Intelligence Job
  Future<bool> uploadDocumentFile(String jobId, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint("File not found: $filePath");
        return false;
      }
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_diBaseUrl/document-intelligence/upload-file'),
      );
      request.headers['api-subscription-key'] = _apiKey;
      request.fields['job_id'] = jobId;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Upload File Exception: $e");
      return false;
    }
  }

  /// Start a Document Intelligence Job
  Future<bool> startDocumentJob(String jobId) async {
    try {
      final response = await http.post(
        Uri.parse('$_diBaseUrl/document-intelligence/start-job'),
        headers: _headers,
        body: jsonEncode({"job_id": jobId}),
      );
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (e) {
      debugPrint("Start Job Exception: $e");
      return false;
    }
  }

  /// Get Document Intelligence Job Status
  Future<Map<String, dynamic>> getDocumentJobStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$_diBaseUrl/document-intelligence/job-status?job_id=$jobId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"status": "error", "error": response.body};
    } catch (e) {
      return {"status": "error", "error": e.toString()};
    }
  }

  /// Download Document Intelligence Job Output
  Future<Map<String, dynamic>> downloadDocumentOutput(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$_diBaseUrl/document-intelligence/download-output?job_id=$jobId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "error": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  /// Full Document Intelligence Flow (Orchestrated)
  /// Processes a PDF file and returns extracted transactions
  Future<Map<String, dynamic>> processDocumentIntelligence(String filePath) async {
    try {
      // Step 1: Create Job
      final jobId = await createDocumentJob(language: "en-IN", outputFormat: "json");
      if (jobId == null) {
        return {"success": false, "error": "Failed to create document job"};
      }
      
      // Step 2: Upload File
      final uploaded = await uploadDocumentFile(jobId, filePath);
      if (!uploaded) {
        return {"success": false, "error": "Failed to upload file"};
      }
      
      // Step 3: Start Job
      final started = await startDocumentJob(jobId);
      if (!started) {
        return {"success": false, "error": "Failed to start job"};
      }
      
      // Step 4: Poll for completion (max 60 seconds)
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 2));
        
        final status = await getDocumentJobStatus(jobId);
        final jobStatus = status['status']?.toString().toLowerCase() ?? '';
        
        if (jobStatus == 'completed' || jobStatus == 'succeeded') {
          // Step 5: Download output
          final output = await downloadDocumentOutput(jobId);
          return {
            "success": true,
            "data": output,
            "job_id": jobId,
          };
        } else if (jobStatus == 'failed' || jobStatus == 'error') {
          return {"success": false, "error": status['error'] ?? "Job failed"};
        }
      }
      
      return {"success": false, "error": "Job timed out"};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ==================== VISION API (Receipt Analysis) ====================
  
  /// Analyze an image (receipt) and extract financial data
  Future<Map<String, dynamic>> analyzeReceipt(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return {"success": false, "error": "Image file not found"};
      }
      
      // Read and encode image to base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Determine mime type
      final ext = imagePath.toLowerCase().split('.').last;
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      
      // Use Sarvam's vision/chat endpoint with image
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          "model": "sarvam-2b-v2",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:$mimeType;base64,$base64Image"
                  }
                },
                {
                  "type": "text",
                  "text": """Analyze this receipt image. Extract:
1. merchant_name: Name of store/business
2. date: Date of purchase (YYYY-MM-DD format)
3. total_amount: Total amount paid (number only)
4. category: Best guess category (Food, Shopping, Transport, Bills, Entertainment, Healthcare, Other)
5. items: List of items if visible

Return as JSON object with these exact keys. If any field is unclear, use null."""
                }
              ]
            }
          ],
          "temperature": 0.1,
          "max_tokens": 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices']?[0]?['message']?['content'] ?? "{}";
        
        // Clean markdown
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();
        
        try {
          final start = content.indexOf('{');
          final end = content.lastIndexOf('}');
          if (start != -1 && end != -1) {
            final jsonStr = content.substring(start, end + 1);
            final parsed = jsonDecode(jsonStr);
            return {
              "success": true,
              "merchant_name": parsed['merchant_name'],
              "date": parsed['date'],
              "total_amount": parsed['total_amount'],
              "category": parsed['category'] ?? 'Other',
              "items": parsed['items'],
            };
          }
        } catch (e) {
          debugPrint("Vision JSON Parse Error: $content");
        }
        
        return {"success": false, "error": "Could not parse receipt data"};
      }
      
      return {"success": false, "error": "Vision API Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }
}

