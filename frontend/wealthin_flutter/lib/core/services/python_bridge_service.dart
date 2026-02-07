import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Python Bridge Service
/// Provides access to embedded Python backend via Chaquopy platform channels
/// This is the ONLY backend for the app - no external HTTP server needed
class PythonBridgeService {
  PythonBridgeService._internal();
  static final PythonBridgeService _instance = PythonBridgeService._internal();
  factory PythonBridgeService() => _instance;

  static const MethodChannel _channel = MethodChannel('wealthin/python');

  bool _isInitialized = false;
  bool _isPythonAvailable = false;
  List<Map<String, dynamic>> _availableTools = [];

  /// Check if Python is available (Android only with Chaquopy)
  bool get isPythonAvailable => _isPythonAvailable;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get available tools for the LLM
  List<Map<String, dynamic>> get availableTools => _availableTools;

  /// Set Configuration (API Keys, etc) in Python backend
  Future<bool> setConfig(Map<String, dynamic> config) async {
    if (!_isPythonAvailable) return false;
    final result = await _callPython('set_config', {'config_json': jsonEncode(config)});
    return result['success'] == true;
  }

  /// Set Gemini API Key in Python backend (Legacy wrapper)
  Future<bool> setApiKey(String apiKey) async {
    return setConfig({'sarvam_api_key': apiKey});
  }

  /// Chat with LLM using embedded Python
  Future<Map<String, dynamic>> chatWithLLM({
    required String query,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? userContext,
    String? apiKey,
  }) async {
    if (!_isPythonAvailable) {
      return {
        'success': false,
        'error': 'Python backend not available',
        'response': 'I apologize, but my intelligence engine is currently unavailable on this platform.'
      };
    }

    final args = <String, dynamic>{
      'query': query,
      if (conversationHistory != null) 'conversation_history': conversationHistory,
      if (userContext != null) 'user_context': userContext,
      if (apiKey != null) 'api_key': apiKey,
    };

    return await _callPython('chat_with_llm', args);
  }

  /// Initialize the Python backend
  Future<bool> initialize() async {
    if (_isInitialized) return _isPythonAvailable;

    try {
      // On non-Android platforms, Python won't be available
      if (defaultTargetPlatform != TargetPlatform.android) {
        debugPrint('[PythonBridge] Not on Android, Python unavailable');
        _isPythonAvailable = false;
        _isInitialized = true;
        return false;
      }

      final result = await _callPython('init_python_backend', {});
      _isPythonAvailable = result['success'] == true;
      _isInitialized = true;

      if (_isPythonAvailable) {
        // Load available tools
        final toolsResult = await _callPython('get_available_tools', {});
        if (toolsResult['success'] == true) {
          _availableTools =
              List<Map<String, dynamic>>.from(toolsResult['tools'] ?? []);
        }
      }

      debugPrint('[PythonBridge] Initialized: $_isPythonAvailable');
      debugPrint('[PythonBridge] Available tools: ${_availableTools.length}');
      return _isPythonAvailable;
    } catch (e) {
      debugPrint('[PythonBridge] Init error: $e');
      _isPythonAvailable = false;
      _isInitialized = true;
      return false;
    }
  }

  /// Call a Python function and parse the JSON result
  Future<Map<String, dynamic>> _callPython(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    try {
      final String resultJson = await _channel.invokeMethod('callPython', {
        'function': functionName,
        'args': args,
      });

      return json.decode(resultJson) as Map<String, dynamic>;
    } on PlatformException catch (e) {
      debugPrint('[PythonBridge] Platform error: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      debugPrint('[PythonBridge] Error calling $functionName: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== TOOL EXECUTION ====================

  /// Execute any tool by name (for LLM tool calls)
  Future<Map<String, dynamic>> executeTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    if (!_isPythonAvailable) {
      // Use Dart fallbacks
      return _executeDartFallback(toolName, args);
    }

    final result = await _callPython('execute_tool', {
      'tool_name': toolName,
      'tool_args': args,
    });

    if (result['success'] != true) {
      // Try Dart fallback
      return _executeDartFallback(toolName, args);
    }

    return result;
  }

  /// Dart fallback for tools when Python is unavailable
  Map<String, dynamic> _executeDartFallback(
    String toolName,
    Map<String, dynamic> args,
  ) {
    switch (toolName) {
      case 'calculate_sip':
        return _calculateSIPFallback(
          args['monthly_investment'] as double? ?? 0,
          args['annual_rate'] as double? ?? 0,
          args['years'] as int? ?? 0,
        );
      case 'calculate_emi':
        return _calculateEMIFallback(
          args['principal'] as double? ?? 0,
          args['annual_rate'] as double? ?? 0,
          args['tenure_months'] as int? ?? 0,
        );
      case 'calculate_savings_rate':
        return _calculateSavingsRateFallback(
          args['income'] as double? ?? 0,
          args['expenses'] as double? ?? 0,
        );
      case 'categorize_transaction':
        return _categorizeTransactionFallback(
          args['description'] as String? ?? '',
        );
      default:
        return {'success': false, 'error': 'Tool not available in fallback mode'};
    }
  }

  // ==================== FINANCIAL CALCULATORS ====================

  /// Calculate SIP maturity
  Future<Map<String, dynamic>> calculateSIP({
    required double monthlyInvestment,
    required double annualRate,
    required int years,
  }) async {
    if (!_isPythonAvailable) {
      return _calculateSIPFallback(monthlyInvestment, annualRate, years);
    }

    return await _callPython('calculate_sip', {
      'monthly_investment': monthlyInvestment,
      'annual_rate': annualRate,
      'years': years,
    });
  }

  Map<String, dynamic> _calculateSIPFallback(
    double monthlyInvestment,
    double annualRate,
    int years,
  ) {
    final monthlyRate = annualRate / 100 / 12;
    final months = years * 12;

    double maturityValue;
    if (monthlyRate == 0) {
      maturityValue = monthlyInvestment * months;
    } else {
      maturityValue = monthlyInvestment *
          (((1 + monthlyRate).pow(months) - 1) / monthlyRate) *
          (1 + monthlyRate);
    }

    final totalInvestment = monthlyInvestment * months;
    final returns = maturityValue - totalInvestment;

    return {
      'success': true,
      'maturity_value': maturityValue.roundToDouble(),
      'total_investment': totalInvestment,
      'total_returns': returns.roundToDouble(),
      'monthly_investment': monthlyInvestment,
      'annual_rate': annualRate,
      'years': years,
    };
  }

  /// Calculate EMI
  Future<Map<String, dynamic>> calculateEMI({
    required double principal,
    required double annualRate,
    required int tenureMonths,
  }) async {
    if (!_isPythonAvailable) {
      return _calculateEMIFallback(principal, annualRate, tenureMonths);
    }

    return await _callPython('calculate_emi', {
      'principal': principal,
      'annual_rate': annualRate,
      'tenure_months': tenureMonths,
    });
  }

  Map<String, dynamic> _calculateEMIFallback(
    double principal,
    double annualRate,
    int tenureMonths,
  ) {
    final monthlyRate = annualRate / 100 / 12;

    double emi;
    if (monthlyRate == 0) {
      emi = principal / tenureMonths;
    } else {
      emi = principal *
          monthlyRate *
          (1 + monthlyRate).pow(tenureMonths) /
          ((1 + monthlyRate).pow(tenureMonths) - 1);
    }

    final totalPayment = emi * tenureMonths;
    final totalInterest = totalPayment - principal;

    return {
      'success': true,
      'emi': emi.roundToDouble(),
      'total_payment': totalPayment.roundToDouble(),
      'total_interest': totalInterest.roundToDouble(),
      'principal': principal,
      'annual_rate': annualRate,
      'tenure_months': tenureMonths,
    };
  }

  /// Calculate compound interest
  Future<Map<String, dynamic>> calculateCompoundInterest({
    required double principal,
    required double annualRate,
    required double years,
    int compoundsPerYear = 12,
  }) async {
    if (!_isPythonAvailable) {
      final rate = annualRate / 100;
      final futureValue =
          principal * (1 + rate / compoundsPerYear).pow(compoundsPerYear * years);
      return {
        'success': true,
        'future_value': futureValue.roundToDouble(),
        'principal': principal,
        'total_interest': (futureValue - principal).roundToDouble(),
      };
    }

    return await _callPython('calculate_compound_interest', {
      'principal': principal,
      'annual_rate': annualRate,
      'years': years,
      'compounds_per_year': compoundsPerYear,
    });
  }

  /// Calculate FIRE number
  Future<Map<String, dynamic>> calculateFIRENumber({
    required double annualExpenses,
    double withdrawalRate = 4.0,
  }) async {
    if (!_isPythonAvailable) {
      final fireNumber = (annualExpenses / withdrawalRate) * 100;
      return {
        'success': true,
        'fire_number': fireNumber.roundToDouble(),
        'annual_expenses': annualExpenses,
        'withdrawal_rate': withdrawalRate,
      };
    }

    return await _callPython('calculate_fire_number', {
      'annual_expenses': annualExpenses,
      'withdrawal_rate': withdrawalRate,
    });
  }

  /// Calculate emergency fund status
  Future<Map<String, dynamic>> calculateEmergencyFund({
    required double monthlyExpenses,
    required double currentSavings,
    int targetMonths = 6,
  }) async {
    if (!_isPythonAvailable) {
      final monthsCovered =
          monthlyExpenses > 0 ? currentSavings / monthlyExpenses : 0.0;
      final gap = (monthlyExpenses * targetMonths) - currentSavings;
      return {
        'success': true,
        'months_covered': monthsCovered,
        'target_months': targetMonths,
        'gap': gap > 0 ? gap : 0,
        'is_adequate': monthsCovered >= targetMonths,
      };
    }

    return await _callPython('calculate_emergency_fund', {
      'monthly_expenses': monthlyExpenses,
      'current_savings': currentSavings,
      'target_months': targetMonths,
    });
  }

  /// Calculate savings rate
  Future<Map<String, dynamic>> calculateSavingsRate({
    required double income,
    required double expenses,
  }) async {
    if (!_isPythonAvailable) {
      return _calculateSavingsRateFallback(income, expenses);
    }

    return await _callPython('calculate_savings_rate', {
      'income': income,
      'expenses': expenses,
    });
  }

  Map<String, dynamic> _calculateSavingsRateFallback(
    double income,
    double expenses,
  ) {
    final rate = income > 0 ? ((income - expenses) / income) * 100 : 0.0;
    return {
      'success': true,
      'savings_rate': rate,
      'monthly_savings': income - expenses,
      'income': income,
      'expenses': expenses,
    };
  }

  // ==================== TRANSACTION CATEGORIZATION ====================

  /// Categorize a single transaction
  Future<Map<String, dynamic>> categorizeTransaction({
    required String description,
    double amount = 0,
  }) async {
    if (!_isPythonAvailable) {
      return _categorizeTransactionFallback(description);
    }

    return await _callPython('categorize_transaction', {
      'description': description,
      'amount': amount,
    });
  }

  Map<String, dynamic> _categorizeTransactionFallback(String description) {
    final descLower = description.toLowerCase();
    String category = 'Other';

    final categoryKeywords = {
      'Food & Dining': ['food', 'restaurant', 'swiggy', 'zomato', 'cafe'],
      'Groceries': ['grocery', 'supermarket', 'dmart', 'bigbasket'],
      'Transport': ['uber', 'ola', 'petrol', 'fuel', 'taxi', 'metro'],
      'Shopping': ['amazon', 'flipkart', 'myntra', 'shop'],
      'Utilities': ['electricity', 'water', 'internet', 'phone', 'bill'],
      'Entertainment': ['netflix', 'spotify', 'movie', 'game'],
      'Healthcare': ['hospital', 'doctor', 'pharmacy', 'medical'],
      'Income': ['salary', 'income', 'payment received'],
    };

    for (final entry in categoryKeywords.entries) {
      if (entry.value.any((keyword) => descLower.contains(keyword))) {
        category = entry.key;
        break;
      }
    }

    return {'success': true, 'category': category, 'confidence': 0.8};
  }

  /// Categorize multiple transactions
  Future<Map<String, dynamic>> categorizeTransactionsBatch(
    List<Map<String, dynamic>> transactions,
  ) async {
    if (!_isPythonAvailable) {
      final results = transactions.map((tx) {
        final result =
            _categorizeTransactionFallback(tx['description'] as String? ?? '');
        return {...tx, 'category': result['category']};
      }).toList();
      return {'success': true, 'transactions': results};
    }

    return await _callPython('categorize_transactions_batch', {
      'transactions_json': json.encode(transactions),
    });
  }

  /// Parse bank statement from base64 image (Zoho Vision OCR)
  Future<Map<String, dynamic>> parseBankStatement(String imageBase64) async {
    if (!_isPythonAvailable) {
      return {'success': false, 'error': 'Python backend not available'};
    }

    return await _callPython('parse_bank_statement', {
      'image_b64': imageBase64,
    });
  }

  /// Parse bank statement from OCR text (Python text parser)
  /// This is better for multi-page PDFs where text from all pages is concatenated
  Future<Map<String, dynamic>> parseBankStatementFromText(String ocrText) async {
    if (!_isPythonAvailable) {
      return {'success': false, 'error': 'Python backend not available'};
    }

    return await _callPython('parse_bank_statement_text', {
      'text': ocrText,
    });
  }

  /// Extract receipt data from path (Zoho Vision)
  Future<Map<String, dynamic>> extractReceiptFromPath(String filePath) async {
    if (!_isPythonAvailable) {
      return {'success': false, 'error': 'Python backend not available'};
    }

    return await _callPython('extract_receipt_from_path', {
      'file_path': filePath,
    });
  }

  // ==================== ANALYTICS ====================

  /// Analyze spending trends
  Future<Map<String, dynamic>> analyzeSpending(
    List<Map<String, dynamic>> transactions,
  ) async {
    if (!_isPythonAvailable) {
      // Basic fallback analysis
      double totalIncome = 0;
      double totalExpenses = 0;
      final categories = <String, double>{};

      for (final tx in transactions) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
        if (amount > 0) {
          totalIncome += amount;
        } else {
          totalExpenses += amount.abs();
          final cat = tx['category'] as String? ?? 'Other';
          categories[cat] = (categories[cat] ?? 0) + amount.abs();
        }
      }

      return {
        'success': true,
        'analysis': {
          'total_income': totalIncome,
          'total_expenses': totalExpenses,
          'net_savings': totalIncome - totalExpenses,
          'savings_rate':
              totalIncome > 0 ? ((totalIncome - totalExpenses) / totalIncome) * 100 : 0,
          'category_breakdown': categories,
        },
      };
    }

    return await _callPython('analyze_spending', {
      'transactions': json.encode(transactions),
    });
  }

  // ==================== FINANCIAL ADVICE ====================

  /// Get personalized financial advice
  Future<Map<String, dynamic>> getFinancialAdvice({
    required double income,
    required double expenses,
    required double savings,
    double debt = 0,
    List<String>? goals,
  }) async {
    if (!_isPythonAvailable) {
      final savingsRate = income > 0 ? ((income - expenses) / income) * 100 : 0;
      final emergencyMonths = expenses > 0 ? savings / expenses : 0;

      return {
        'success': true,
        'financial_health': {
          'savings_rate': savingsRate,
          'emergency_months': emergencyMonths,
        },
        'advice': [
          {
            'area': 'Savings',
            'status': savingsRate >= 20 ? 'Good' : 'Needs Improvement',
            'message': savingsRate >= 20
                ? 'Great savings rate!'
                : 'Try to save at least 20% of your income.',
          },
        ],
      };
    }

    return await _callPython('get_financial_advice', {
      'income': income,
      'expenses': expenses,
      'savings': savings,
      'debt': debt,
      'goals': goals ?? [],
    });
  }

  // ==================== DEBT & NET WORTH ====================

  /// Calculate debt payoff strategy
  Future<Map<String, dynamic>> calculateDebtPayoff(
    List<Map<String, dynamic>> debts, {
    double extraPayment = 0,
  }) async {
    if (!_isPythonAvailable) {
      return {'success': false, 'error': 'Debt payoff calculation requires Python'};
    }

    return await _callPython('calculate_debt_payoff', {
      'debts': json.encode(debts),
      'extra_payment': extraPayment,
    });
  }

  /// Project future net worth
  Future<Map<String, dynamic>> projectNetWorth({
    required double currentNetWorth,
    required double monthlySavings,
    double investmentReturn = 8.0,
    int years = 10,
  }) async {
    if (!_isPythonAvailable) {
      // Simple projection
      final annualSavings = monthlySavings * 12;
      var netWorth = currentNetWorth;
      final projections = <Map<String, dynamic>>[];

      for (var y = 1; y <= years; y++) {
        netWorth = netWorth * (1 + investmentReturn / 100) + annualSavings;
        projections.add({'year': y, 'net_worth': netWorth.roundToDouble()});
      }

      return {
        'success': true,
        'current_net_worth': currentNetWorth,
        'projected_net_worth': netWorth.roundToDouble(),
        'projections': projections,
      };
    }

    return await _callPython('project_net_worth', {
      'current_net_worth': currentNetWorth,
      'monthly_savings': monthlySavings,
      'investment_return': investmentReturn,
      'years': years,
    });
  }

  // ==================== TAX CALCULATIONS ====================

  /// Calculate tax savings (Indian tax law)
  Future<Map<String, dynamic>> calculateTaxSavings({
    required double income,
    double investments80c = 0,
    double healthInsurance80d = 0,
    double homeLoanInterest = 0,
  }) async {
    if (!_isPythonAvailable) {
      return {'success': false, 'error': 'Tax calculation requires Python'};
    }

    return await _callPython('calculate_tax_savings', {
      'income': income,
      'investments_80c': investments80c,
      'health_insurance_80d': healthInsurance80d,
      'home_loan_interest': homeLoanInterest,
    });
  }

  // ==================== HEALTH CHECK ====================

  /// Check Python backend health
  Future<Map<String, dynamic>> healthCheck() async {
    if (!_isPythonAvailable) {
      return {
        'success': true,
        'status': 'dart_fallback',
        'message': 'Using Dart fallback implementations',
      };
    }

    return await _callPython('health_check', {});
  }
}

/// Extension for pow on double
extension DoublePow on double {
  double pow(num exponent) => exponent is int
      ? List.filled(exponent, this).fold(1.0, (a, b) => a * b)
      : throw UnsupportedError('Only integer exponents supported');
}

/// Global Python bridge instance
final pythonBridge = PythonBridgeService();
