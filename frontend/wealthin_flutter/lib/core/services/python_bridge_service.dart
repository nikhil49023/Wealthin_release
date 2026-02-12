import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:wealthin_flutter/core/services/backend_config.dart';

/// System Health Status for Python Engine
enum SystemHealthStatus {
  ready,
  initializing,
  unavailable,
  error,
}

/// System Health Result
class SystemHealth {
  final SystemHealthStatus status;
  final String message;
  final Map<String, bool> components;

  SystemHealth({
    required this.status,
    required this.message,
    this.components = const {},
  });
}

/// Python Bridge Service
/// Acts as the bridge between Flutter frontend and Python backend sidecar.
/// Handles API calls for RAG, Financial Calculations, and AI interactions.
class PythonBridgeService {
  PythonBridgeService._internal();
  static final PythonBridgeService _instance = PythonBridgeService._internal();
  factory PythonBridgeService() => _instance;

  // MethodChannel for Android (Chaquopy embedded Python)
  static const _channel = MethodChannel('wealthin/python');
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  // Use BackendConfig to get the dynamic base URL (desktop only)
  String get _baseUrl => backendConfig.baseUrl;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Call Python function via MethodChannel (Android only)
  Future<Map<String, dynamic>> _callPython(String function, Map<String, dynamic> args) async {
    try {
      final result = await _channel.invokeMethod<String>('callPython', {
        'function': function,
        'args': args,
      });
      if (result != null) {
        return jsonDecode(result) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'No result from Python'};
    } catch (e) {
      debugPrint('[PythonBridge] MethodChannel error ($function): $e');
      return {'success': false, 'error': 'Python bridge error: $e'};
    }
  }

  /// Initialize and check backend health
  Future<bool> initialize() async {
    if (_isAndroid) {
      // Android: Use Chaquopy MethodChannel
      try {
        final result = await _callPython('health_check', {});
        _isInitialized = result['success'] == true || result['status'] == 'ready';
        if (_isInitialized) {
          debugPrint('[PythonBridge] ✓ Embedded Python ready (Chaquopy)');
        }
        return _isInitialized;
      } catch (e) {
        debugPrint('[PythonBridge] Chaquopy health check failed: $e');
        _isInitialized = false;
        return false;
      }
    }

    // Desktop: Use HTTP health check
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      
      _isInitialized = response.statusCode == 200;
      if (_isInitialized) {
        debugPrint('[PythonBridge] Backend connected at $_baseUrl');
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('[PythonBridge] Health check failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Check system health - useful for Settings screen
  Future<SystemHealth> checkSystemHealth() async {
    if (_isAndroid) {
      try {
        final result = await _callPython('health_check', {});
        if (result['success'] == true || result['status'] == 'ready') {
          final components = result['components'] as Map<String, dynamic>? ?? {};
          return SystemHealth(
            status: SystemHealthStatus.ready,
            message: 'Embedded AI Engine Ready',
            components: {
              'python': components['python'] == true,
              'sarvam': components['sarvam_configured'] == true,
              'tools': (components['tools_count'] ?? 0) > 0,
            },
          );
        }
      } catch (e) {
        debugPrint('[PythonBridge] Chaquopy health error: $e');
      }
      return SystemHealth(
        status: SystemHealthStatus.unavailable,
        message: 'Embedded Python not available',
        components: {'python': false},
      );
    }

    // Desktop: HTTP health check
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SystemHealth(
          status: SystemHealthStatus.ready,
          message: 'AI Engine Ready',
          components: {
            'rag': data['rag_status'] == 'active',
            'rag_docs': (data['rag_documents'] ?? 0) > 0,
          },
        );
      }
    } catch (e) {
      debugPrint('[PythonBridge] Health check error: $e');
    }
    
    return SystemHealth(
      status: SystemHealthStatus.unavailable,
      message: 'Backend not reachable',
      components: {'rag': false},
    );
  }

  /// Send message to AI agent via the agentic-chat endpoint.
  /// This supports RAG, Tools, and Context.
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userContext,
    String? userId,
  }) async {
    final url = Uri.parse('$_baseUrl/agent/agentic-chat');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': message, 
          'conversation_history': conversationHistory ?? [],
          'user_context': userContext ?? {},
          'user_id': userId,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('[PythonBridge] Chat Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PythonBridge] Exception: $e');
      rethrow;
    }
  }
  
  /// Generate Detailed Project Report (DPR)
  Future<String> generateDPR({
    required String businessIdea,
    required Map<String, dynamic> userData,
    required String userId,
    bool includeMarketResearch = false,
  }) async {
    final url = Uri.parse('$_baseUrl/brainstorm/generate-dpr');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'business_idea': businessIdea,
          'user_data': userData,
          'user_id': userId,
          'include_market_research': includeMarketResearch,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['dpr'] ?? "No DPR generated.";
      } else {
        debugPrint('[PythonBridge] DPR Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate DPR');
      }
    } catch (e) {
      debugPrint('[PythonBridge] Exception: $e');
      rethrow;
    }
  }

  /// Categorize a single transaction
  Future<Map<String, dynamic>> categorizeTransaction(String description, double amount) async {
    final url = Uri.parse('$_baseUrl/categorize');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': description,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Fallback
        return {'category': 'Uncategorized', 'confidence': 0.0};
      }
    } catch (e) {
      return {'category': 'Uncategorized', 'confidence': 0.0};
    }
  }

  /// Categorize multiple transactions
  Future<List<Map<String, dynamic>>> categorizeBatch(List<Map<String, dynamic>> transactions) async {
    final url = Uri.parse('$_baseUrl/categorize/batch');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transactions': transactions,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['transactions']);
      } else {
        return transactions; // Return original if fail
      }
    } catch (e) {
      return transactions;
    }
  }

  /// Calculate SIP returns
  Future<Map<String, dynamic>> calculateSIP({
    required double monthlyInvestment,
    required double expectedRate,
    required int durationMonths,
  }) async {
    final url = Uri.parse('$_baseUrl/calculator/sip');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'monthly_investment': monthlyInvestment,
        'expected_rate': expectedRate,
        'duration_months': durationMonths,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to calculate SIP');
    }
  }

    /// Calculate EMI
  Future<Map<String, dynamic>> calculateEMI({
    required double principal,
    required double annualRate,
    required int tenureMonths,
  }) async {
    final url = Uri.parse('$_baseUrl/calculator/emi');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'principal': principal,
        'rate': annualRate,
        'tenure_months': tenureMonths,
      }),
    );

     if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to calculate EMI');
    }
  }

  /// Calculate Compound Interest
   Future<Map<String, dynamic>> calculateCompoundInterest({
    required double principal,
    required double annualRate,
    required int years,
  }) async {
      // NOTE: The backend endpoint is /calculator/lumpsum or similar, 
      // but for 'compound interest' specifically we might use that logic.
      // Let's use lumpsum endpoint which is essentially compound interest
      final url = Uri.parse('$_baseUrl/calculator/lumpsum');
       final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'principal': principal,
        'rate': annualRate,
        'duration_years': years,
      }),
    );

     if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to calculate Compound Interest');
    }
  }

   /// Calculate Savings Rate
   Future<Map<String, dynamic>> calculateSavingsRate({
    required double income,
    required double expenses,
  }) async {
      final url = Uri.parse('$_baseUrl/calculator/savings-rate');
       final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'income': income,
        'expenses': expenses,
      }),
    );

     if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
       // Fallback logic
       final rate = income > 0 ? ((income - expenses) / income) * 100 : 0.0;
       return {'savings_rate_percentage': rate};
    }
  }

    /// Calculate Emergency Fund
   Future<Map<String, dynamic>> calculateEmergencyFund({
    required double monthlyExpenses,
    required double currentSavings,
    int targetMonths = 6,
  }) async {
      final url = Uri.parse('$_baseUrl/calculator/emergency-fund');
       final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'monthly_expenses': monthlyExpenses,
        'current_savings': currentSavings,
        'target_months': targetMonths,
      }),
    );

     if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to calculate Emergency Fund');
    }
  }

  /// Set config/secrets on the backend (e.g. API keys for Android embedded Python)
  Future<void> setConfig(Map<String, String> config) async {
    if (_isAndroid) {
      try {
        final result = await _callPython('set_config', {
          'config_json': jsonEncode(config),
        });
        debugPrint('[PythonBridge] setConfig result: $result');
      } catch (e) {
        debugPrint('[PythonBridge] setConfig error: $e');
      }
      return;
    }
    // Desktop: Config is managed via environment variables on the backend.
    debugPrint('[PythonBridge] setConfig called (no-op for HTTP bridge)');
  }

  /// Chat with LLM via the agentic-chat endpoint
  Future<Map<String, dynamic>> chatWithLLM({
    required String query,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userContext,
    String? userId,
  }) async {
    if (_isAndroid) {
      // Android: Use Chaquopy MethodChannel → flutter_bridge.chat_with_llm
      try {
        final result = await _callPython('chat_with_llm', {
          'query': query,
        });
        // flutter_bridge.chat_with_llm returns JSON string, _callPython already decodes it
        if (result['success'] == true || result.containsKey('response')) {
          return result;
        }
        return {'success': false, 'response': result['error'] ?? 'No response from AI'};
      } catch (e) {
        debugPrint('[PythonBridge] chatWithLLM (Android) Exception: $e');
        return {'success': false, 'response': 'AI engine error: $e'};
      }
    }

    // Desktop: Use HTTP
    final url = Uri.parse('$_baseUrl/agent/agentic-chat');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'conversation_history': conversationHistory ?? [],
          'user_context': userContext ?? {},
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('[PythonBridge] chatWithLLM Error: ${response.statusCode}');
        return {'success': false, 'response': 'Backend error: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('[PythonBridge] chatWithLLM Exception: $e');
      return {'success': false, 'response': 'Connection error: $e'};
    }
  }

  /// Analyze spending patterns via the backend
  Future<Map<String, dynamic>> analyzeSpending(List<Map<String, dynamic>> transactions) async {
    final url = Uri.parse('$_baseUrl/analyze/spending');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'transactions': transactions}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'analysis': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Backend error: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('[PythonBridge] analyzeSpending Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Execute a named tool on the backend.
  /// Routes to the appropriate backend endpoint based on tool name.
  Future<Map<String, dynamic>> executeTool(
    String toolName,
    Map<String, dynamic> params,
  ) async {
    if (_isAndroid) {
      // Android: Use Chaquopy MethodChannel → flutter_bridge.execute_tool
      try {
        final result = await _callPython('execute_tool', {
          'tool_name': toolName,
          'tool_args': params,
        });
        return result;
      } catch (e) {
        debugPrint('[PythonBridge] executeTool($toolName) Android Exception: $e');
        return {'success': false, 'error': e.toString()};
      }
    }

    // Desktop: Route via HTTP
    try {
      switch (toolName) {
        case 'parse_bank_statement':
          return await _executeDocumentScan(params);
        case 'extract_receipt':
          return await _executeReceiptScan(params);
        case 'start_brainstorming':
        case 'process_brainstorm_response':
          return await _executeBrainstorm(toolName, params);
        case 'generate_dpr':
          return await _executeGenerateDPR(params);
        case 'get_dpr_template':
          return {'success': true, 'template': {}};
        case 'run_scenario_comparison':
          return await _executeViaChat('Run scenario comparison', params);
        default:
          return await _executeViaChat(toolName, params);
      }
    } catch (e) {
      debugPrint('[PythonBridge] executeTool($toolName) Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _executeDocumentScan(Map<String, dynamic> params) async {
    final filePath = params['file_path'] as String?;
    if (filePath == null) return {'success': false, 'error': 'No file path'};

    final url = Uri.parse('$_baseUrl/agent/scan-document');
    final request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': true, 'transactions': data['transactions'] ?? []};
    }
    return {'success': false, 'error': 'Scan failed: ${response.statusCode}'};
  }

  Future<Map<String, dynamic>> _executeReceiptScan(Map<String, dynamic> params) async {
    final filePath = params['file_path'] as String?;
    if (filePath == null) return {'success': false, 'error': 'No file path'};

    final url = Uri.parse('$_baseUrl/agent/scan-receipt');
    final request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {
          'success': true,
          'transaction': data['suggested_transaction'] ?? data['data'],
        };
      }
    }
    return {'success': false, 'error': 'Receipt scan failed'};
  }

  Future<Map<String, dynamic>> _executeBrainstorm(String action, Map<String, dynamic> params) async {
    final url = Uri.parse('$_baseUrl/brainstorm/chat');
    final message = action == 'start_brainstorming'
        ? 'Start brainstorming for: ${params['business_idea']}'
        : params['response'] ?? '';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': 'default',
        'message': message,
        'conversation_history': [],
        'enable_web_search': true,
        'search_category': 'general',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': data['success'] ?? false, 'response': data['content'] ?? ''};
    }
    return {'success': false, 'error': 'Brainstorm failed'};
  }

  Future<Map<String, dynamic>> _executeGenerateDPR(Map<String, dynamic> params) async {
    final projectData = params['project_data'] as Map<String, dynamic>? ?? {};
    final url = Uri.parse('$_baseUrl/brainstorm/generate-dpr');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': 'default',
        'business_idea': projectData['business_idea'] ?? '',
        'user_data': projectData,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': true, 'dpr': data['dpr'] ?? ''};
    }
    return {'success': false, 'error': 'DPR generation failed'};
  }

  Future<Map<String, dynamic>> _executeViaChat(String toolHint, Map<String, dynamic> params) async {
    final result = await chatWithLLM(
      query: '$toolHint: ${jsonEncode(params)}',
    );
    return {'success': true, ...result};
  }

  /// Extract receipt data from an image file path
  Future<Map<String, dynamic>> extractReceiptFromPath(String filePath) async {
    final url = Uri.parse('$_baseUrl/agent/scan-receipt');

    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final suggested = data['suggested_transaction'] as Map<String, dynamic>? ?? {};
          return {
            'success': true,
            'merchant_name': suggested['description'] ?? data['data']?['merchant_name'] ?? 'Unknown',
            'total_amount': suggested['amount'] ?? data['data']?['total_amount'] ?? 0,
            'date': suggested['date'] ?? data['data']?['date'],
            'category': data['data']?['category'] ?? 'Other',
          };
        }
      }
      return {'success': false, 'error': 'Receipt extraction failed'};
    } catch (e) {
      debugPrint('[PythonBridge] extractReceiptFromPath Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Detect recurring subscriptions from transaction history
  Future<Map<String, dynamic>> detectSubscriptions(List<Map<String, dynamic>> transactions) async {
    if (_isAndroid) {
      // Android: Use Chaquopy's detect_subscriptions tool directly
      try {
        final result = await _callPython('execute_tool', {
          'tool_name': 'detect_subscriptions',
          'tool_args': {'transactions': transactions},
        });
        return result;
      } catch (e) {
        debugPrint('[PythonBridge] detectSubscriptions (Android) Exception: $e');
        return {'success': false, 'error': e.toString()};
      }
    }

    // Desktop: Use HTTP analyze/spending endpoint
    try {
      final url = Uri.parse('$_baseUrl/analyze/spending');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'transactions': transactions}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subscriptions = <Map<String, dynamic>>[];
        final recurringHabits = <Map<String, dynamic>>[];
        double totalMonthlyCost = 0;

        if (data is Map<String, dynamic>) {
          final categories = data['category_breakdown'] as Map<String, dynamic>? ?? {};
          for (final entry in categories.entries) {
            final amount = (entry.value as num?)?.toDouble() ?? 0;
            if (amount > 0) {
              totalMonthlyCost += amount;
            }
          }
        }

        return {
          'success': true,
          'subscriptions': subscriptions,
          'recurring_habits': recurringHabits,
          'total_monthly_cost': totalMonthlyCost,
          'annual_projection': totalMonthlyCost * 12,
        };
      }
      return {'success': false, 'error': 'Analysis failed'};
    } catch (e) {
      debugPrint('[PythonBridge] detectSubscriptions Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  // ==================== MUDRA DPR ====================

  /// Calculate full Mudra DPR from user inputs
  Future<Map<String, dynamic>> calculateMudraDPR(
      Map<String, dynamic> inputs) async {
    final url = Uri.parse('$_baseUrl/mudra-dpr/calculate');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(inputs),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Calculate failed: ${response.statusCode}'};
    } catch (e) {
      debugPrint('[PythonBridge] calculateMudraDPR Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Run what-if simulation with overrides
  Future<Map<String, dynamic>> whatIfSimulate(
      Map<String, dynamic> inputs, Map<String, dynamic> overrides) async {
    final url = Uri.parse('$_baseUrl/mudra-dpr/whatif');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'inputs': inputs, 'overrides': overrides}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'What-if failed: ${response.statusCode}'};
    } catch (e) {
      debugPrint('[PythonBridge] whatIfSimulate Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get cluster suggestions by state
  Future<List<Map<String, dynamic>>> getClusterSuggestions({
    required String city,
    required String state,
    String businessType = '',
  }) async {
    final url = Uri.parse('$_baseUrl/mudra-dpr/clusters');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'city': city,
          'state': state,
          'business_type': businessType,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['clusters'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('[PythonBridge] getClusterSuggestions Exception: $e');
      return [];
    }
  }

  /// Save Mudra DPR to backend
  Future<String?> saveMudraDPR({
    required String userId,
    required Map<String, dynamic> dprData,
  }) async {
    final url = Uri.parse('$_baseUrl/mudra-dpr/save');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, ...dprData}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[PythonBridge] saveMudraDPR Exception: $e');
      return null;
    }
  }

  /// Get saved Mudra DPRs for user
  Future<List<Map<String, dynamic>>> getMudraDPRs(String userId) async {
    final url = Uri.parse('$_baseUrl/mudra-dpr/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['dprs'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('[PythonBridge] getMudraDPRs Exception: $e');
      return [];
    }
  }
}

/// Global instance
final pythonBridge = PythonBridgeService();
