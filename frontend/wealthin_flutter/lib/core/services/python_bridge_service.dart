import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

/// Android-only Python Bridge Service.
/// Uses Chaquopy MethodChannel for on-device AI/runtime services.
class PythonBridgeService {
  PythonBridgeService._internal();
  static final PythonBridgeService _instance = PythonBridgeService._internal();
  factory PythonBridgeService() => _instance;

  static const _channel = MethodChannel('wealthin/python');
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Lightweight in-memory fallback for Mudra drafts in Android-only mode.
  final Map<String, List<Map<String, dynamic>>> _mudraCache = {};

  Future<Map<String, dynamic>> _callPython(
    String function,
    Map<String, dynamic> args,
  ) async {
    if (!_isAndroid) {
      return {
        'success': false,
        'error': 'Android-only feature. Current platform is not supported.',
      };
    }

    try {
      final result = await _channel.invokeMethod<String>('callPython', {
        'function': function,
        'args': args,
      });

      if (result == null || result.isEmpty) {
        return {'success': false, 'error': 'No result from Python bridge'};
      }

      final decoded = jsonDecode(result);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'success': true, 'data': decoded};
    } catch (e) {
      debugPrint('[PythonBridge] MethodChannel error ($function): $e');
      return {'success': false, 'error': 'Python bridge error: $e'};
    }
  }

  Future<bool> initialize() async {
    final result = await _callPython('health_check', {});
    _isInitialized = result['success'] == true || result['status'] == 'ready';
    return _isInitialized;
  }

  Future<SystemHealth> checkSystemHealth() async {
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

    return SystemHealth(
      status: SystemHealthStatus.unavailable,
      message: result['error']?.toString() ?? 'Embedded Python unavailable',
      components: const {'python': false},
    );
  }

  Future<void> setConfig(Map<String, String> config) async {
    final result = await _callPython('set_config', {
      'config_json': jsonEncode(config),
    });
    debugPrint('[PythonBridge] setConfig result: $result');
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userContext,
    String? userId,
  }) async {
    return chatWithLLM(
      query: message,
      conversationHistory: conversationHistory
          ?.map((e) => e.map((k, v) => MapEntry(k, v.toString())))
          .toList(),
      userContext: userContext,
      userId: userId,
    );
  }

  Future<String> generateDPR({
    required String businessIdea,
    required Map<String, dynamic> userData,
    required String userId,
    bool includeMarketResearch = false,
  }) async {
    final result = await executeTool('generate_dpr', {
      'project_data': {
        'business_idea': businessIdea,
        'user_id': userId,
        ...userData,
        'include_market_research': includeMarketResearch,
      },
    });

    if (result['success'] == true) {
      final dpr = result['dpr'];
      if (dpr is String) return dpr;
      return jsonEncode(dpr ?? {});
    }
    return 'Failed to generate DPR: ${result['error'] ?? 'Unknown error'}';
  }

  Future<Map<String, dynamic>> categorizeTransaction(
    String description,
    double amount,
  ) async {
    final result = await executeTool('categorize_transaction', {
      'description': description,
      'amount': amount,
    });

    if (result['success'] == true) {
      return result;
    }
    return {'success': false, 'category': 'Other', 'confidence': 0.0};
  }

  Future<List<Map<String, dynamic>>> categorizeBatch(
    List<Map<String, dynamic>> transactions,
  ) async {
    final categorized = <Map<String, dynamic>>[];
    for (final tx in transactions) {
      final result = await categorizeTransaction(
        tx['description']?.toString() ?? '',
        (tx['amount'] as num?)?.toDouble() ?? 0.0,
      );
      categorized.add({
        ...tx,
        'category': result['category'] ?? tx['category'] ?? 'Other',
      });
    }
    return categorized;
  }

  Future<Map<String, dynamic>> calculateSIP({
    required double monthlyInvestment,
    required double expectedRate,
    required int durationMonths,
  }) async {
    return executeTool('calculate_sip', {
      'monthly_investment': monthlyInvestment,
      'annual_rate': expectedRate,
      'years': (durationMonths / 12).ceil(),
    });
  }

  Future<Map<String, dynamic>> calculateEMI({
    required double principal,
    required double annualRate,
    required int tenureMonths,
  }) async {
    return executeTool('calculate_emi', {
      'principal': principal,
      'annual_rate': annualRate,
      'tenure_months': tenureMonths,
    });
  }

  Future<Map<String, dynamic>> calculateCompoundInterest({
    required double principal,
    required double annualRate,
    required int years,
  }) async {
    return executeTool('calculate_compound_interest', {
      'principal': principal,
      'annual_rate': annualRate,
      'years': years,
      'compounds_per_year': 12,
    });
  }

  Future<Map<String, dynamic>> calculateSavingsRate({
    required double income,
    required double expenses,
  }) async {
    return executeTool('calculate_savings_rate', {
      'income': income,
      'expenses': expenses,
    });
  }

  Future<Map<String, dynamic>> calculateEmergencyFund({
    required double monthlyExpenses,
    required double currentSavings,
    int targetMonths = 6,
  }) async {
    return executeTool('calculate_emergency_fund', {
      'monthly_expenses': monthlyExpenses,
      'current_savings': currentSavings,
      'target_months': targetMonths,
    });
  }

  Future<Map<String, dynamic>> chatWithLLM({
    required String query,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userContext,
    String? userId,
  }) async {
    final result = await _callPython('chat_with_llm', {
      'query': query,
      'conversation_history': conversationHistory ?? [],
      'user_context': userContext ?? {},
      'user_id': userId,
    });

    if (result['success'] == true || result.containsKey('response')) {
      return result;
    }

    return {
      'success': false,
      'response': result['error']?.toString() ?? 'AI engine unavailable',
      'error': result['error'],
    };
  }

  Future<Map<String, dynamic>> analyzeSpending(
    List<Map<String, dynamic>> transactions,
  ) async {
    final result = await executeTool('analyze_spending', {
      'transactions': transactions,
    });

    if (result['success'] != true) {
      return {
        'success': false,
        'error': result['error'] ?? 'Spending analysis failed',
      };
    }

    final rawAnalysis = (result['analysis'] as Map<String, dynamic>?) ?? {};
    final normalized = <String, dynamic>{...rawAnalysis};

    final categoryBreakdown = rawAnalysis['category_breakdown'];
    if (categoryBreakdown is List) {
      final map = <String, double>{};
      for (final item in categoryBreakdown) {
        if (item is Map<String, dynamic>) {
          final key = item['category']?.toString();
          final val = (item['amount'] as num?)?.toDouble() ?? 0.0;
          if (key != null && key.isNotEmpty) map[key] = val;
        }
      }
      normalized['category_breakdown'] = map;
    }

    if (normalized['monthly_data'] == null &&
        rawAnalysis['monthly_trend'] != null) {
      normalized['monthly_data'] = rawAnalysis['monthly_trend'];
    }

    return {'success': true, 'analysis': normalized};
  }

  Future<Map<String, dynamic>> executeTool(
    String toolName,
    Map<String, dynamic> params,
  ) async {
    final result = await _callPython('execute_tool', {
      'tool_name': toolName,
      'tool_args': params,
    });
    return result;
  }

  Future<Map<String, dynamic>> extractReceiptFromPath(String filePath) async {
    // Prefer direct path extractor for better OCR parsing.
    final result = await _callPython('extract_receipt_from_path', {
      'file_path': filePath,
    });

    if (result['success'] == true) {
      return result;
    }

    // Fallback through unified tool execution.
    final fallback = await executeTool('extract_receipt', {
      'file_path': filePath,
    });
    return fallback;
  }

  Future<Map<String, dynamic>> detectSubscriptions(
    List<Map<String, dynamic>> transactions,
  ) async {
    return executeTool('detect_subscriptions', {
      'transactions': transactions,
    });
  }

  Future<Map<String, dynamic>> calculateMudraDPR(
    Map<String, dynamic> inputs,
  ) async {
    final result = await executeTool('generate_dpr', {
      'project_data': inputs,
    });

    if (result['success'] == true) {
      return result;
    }
    return {
      'success': false,
      'error': result['error'] ?? 'Failed to generate DPR',
    };
  }

  Future<Map<String, dynamic>> whatIfSimulate(
    Map<String, dynamic> inputs,
    Map<String, dynamic> overrides,
  ) async {
    double toDouble(dynamic value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    final merged = <String, dynamic>{...inputs, ...overrides};
    final result = await executeTool('run_scenario_comparison', {
      'base_revenue':
          toDouble(merged['base_revenue'] ?? merged['monthly_revenue']) *
          ((merged['base_revenue'] == null && merged['monthly_revenue'] != null)
              ? 12
              : 1),
      'base_costs':
          toDouble(merged['base_costs'] ?? merged['monthly_costs']) *
          ((merged['base_costs'] == null && merged['monthly_costs'] != null)
              ? 12
              : 1),
      'loan_amount': toDouble(
        merged['loan_amount'] ?? merged['debt'] ?? merged['principal'],
      ),
      'interest_rate': toDouble(merged['interest_rate'], 12),
      'loan_tenure_years': (toDouble(merged['loan_tenure_years'], 5)).round(),
    });

    return result;
  }

  Future<List<Map<String, dynamic>>> getClusterSuggestions({
    required String city,
    required String state,
    String businessType = '',
  }) async {
    final st = state.trim().toLowerCase();
    final bt = businessType.trim().toLowerCase();

    final generic = <Map<String, dynamic>>[
      {
        'cluster': 'Industrial Estate',
        'city': city,
        'state': state,
        'focus': bt.isEmpty ? 'General MSME' : businessType,
      },
      {
        'cluster': 'District MSME Hub',
        'city': city,
        'state': state,
        'focus': 'Vendor + market linkage',
      },
    ];

    if (st.contains('gujarat')) {
      return [
        {
          'cluster': 'Textile Cluster',
          'city': 'Surat',
          'state': 'Gujarat',
          'focus': 'Textiles',
        },
        {
          'cluster': 'Chemical MSME Cluster',
          'city': 'Vadodara',
          'state': 'Gujarat',
          'focus': 'Chemicals',
        },
        ...generic,
      ];
    }

    if (st.contains('tamil')) {
      return [
        {
          'cluster': 'Textile Cluster',
          'city': 'Coimbatore',
          'state': 'Tamil Nadu',
          'focus': 'Textiles',
        },
        {
          'cluster': 'Auto Components Cluster',
          'city': 'Chennai',
          'state': 'Tamil Nadu',
          'focus': 'Manufacturing',
        },
        ...generic,
      ];
    }

    if (st.contains('maharashtra')) {
      return [
        {
          'cluster': 'IT Services Cluster',
          'city': 'Pune',
          'state': 'Maharashtra',
          'focus': 'IT/Services',
        },
        {
          'cluster': 'Engineering Cluster',
          'city': 'Nashik',
          'state': 'Maharashtra',
          'focus': 'Engineering',
        },
        ...generic,
      ];
    }

    return generic;
  }

  Future<String?> saveMudraDPR({
    required String userId,
    required Map<String, dynamic> dprData,
  }) async {
    final id = 'mudra_${DateTime.now().millisecondsSinceEpoch}';
    final record = {
      'id': id,
      'created_at': DateTime.now().toIso8601String(),
      ...dprData,
    };
    _mudraCache.putIfAbsent(userId, () => <Map<String, dynamic>>[]).add(record);
    return id;
  }

  Future<List<Map<String, dynamic>>> getMudraDPRs(String userId) async {
    return List<Map<String, dynamic>>.from(_mudraCache[userId] ?? const []);
  }
}

/// Global instance
final pythonBridge = PythonBridgeService();
