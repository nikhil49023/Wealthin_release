import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'backend_config.dart';

/// Data Service - Connects Flutter to the Python backend for CRUD operations
/// Handles budgets, goals, transactions, and scheduled payments
class DataService {
  // Singleton pattern
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // Use BackendConfig for dynamic port management
  String get _baseUrl => backendConfig.baseUrl;

  // ==================== BUDGET OPERATIONS ====================

  /// Create a new budget
  Future<BudgetData?> createBudget({
    required String userId,
    required String name,
    required double amount,
    required String category,
    String icon = 'wallet',
    String period = 'monthly',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/budgets'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'amount': amount,
          'category': category,
          'icon': icon,
          'period': period,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BudgetData.fromJson(data['budget']);
      }
    } catch (e) {
      print('Error creating budget: $e');
    }
    return null;
  }

  /// Get all budgets for a user
  Future<List<BudgetData>> getBudgets(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/budgets/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['budgets'] as List)
            .map((b) => BudgetData.fromJson(b))
            .toList();
      }
    } catch (e) {
      print('Error getting budgets: $e');
    }
    return [];
  }

  /// Update a budget
  Future<BudgetData?> updateBudget({
    required String userId,
    required int budgetId,
    String? name,
    double? amount,
    double? spent,
    String? icon,
    String? category,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (amount != null) updates['amount'] = amount;
      if (spent != null) updates['spent'] = spent;
      if (icon != null) updates['icon'] = icon;
      if (category != null) updates['category'] = category;

      final response = await http.put(
        Uri.parse('$_baseUrl/budgets/$userId/$budgetId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BudgetData.fromJson(data['budget']);
      }
    } catch (e) {
      print('Error updating budget: $e');
    }
    return null;
  }

  /// Delete a budget
  Future<bool> deleteBudget(String userId, int budgetId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/budgets/$userId/$budgetId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting budget: $e');
    }
    return false;
  }

  // ==================== GOAL OPERATIONS ====================

  /// Create a new savings goal
  Future<GoalData?> createGoal({
    required String userId,
    required String name,
    required double targetAmount,
    String? deadline,
    String icon = 'flag',
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/goals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'target_amount': targetAmount,
          'deadline': deadline,
          'icon': icon,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GoalData.fromJson(data['goal']);
      }
    } catch (e) {
      print('Error creating goal: $e');
    }
    return null;
  }

  /// Get all goals for a user
  Future<List<GoalData>> getGoals(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/goals/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['goals'] as List)
            .map((g) => GoalData.fromJson(g))
            .toList();
      }
    } catch (e) {
      print('Error getting goals: $e');
    }
    return [];
  }

  /// Update a goal
  Future<GoalData?> updateGoal({
    required String userId,
    required int goalId,
    String? name,
    double? targetAmount,
    String? deadline,
    String? status,
    String? icon,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (targetAmount != null) updates['target_amount'] = targetAmount;
      if (deadline != null) updates['deadline'] = deadline;
      if (status != null) updates['status'] = status;
      if (icon != null) updates['icon'] = icon;
      if (notes != null) updates['notes'] = notes;

      final response = await http.put(
        Uri.parse('$_baseUrl/goals/$userId/$goalId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GoalData.fromJson(data['goal']);
      }
    } catch (e) {
      print('Error updating goal: $e');
    }
    return null;
  }

  /// Add funds to a goal
  Future<GoalData?> addFundsToGoal({
    required String userId,
    required int goalId,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/goals/$userId/$goalId/add-funds'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GoalData.fromJson(data['goal']);
      }
    } catch (e) {
      print('Error adding funds: $e');
    }
    return null;
  }

  /// Delete a goal
  Future<bool> deleteGoal(String userId, int goalId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/goals/$userId/$goalId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting goal: $e');
    }
    return false;
  }

  // ==================== TRANSACTION OPERATIONS ====================

  /// Create a new transaction
  Future<TransactionData?> createTransaction({
    required String userId,
    required double amount,
    required String description,
    required String category,
    required String type, // 'income' or 'expense'
    String? date,
    String? paymentMethod,
    String? notes,
    String? receiptUrl,
    bool isRecurring = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'amount': amount,
          'description': description,
          'category': category,
          'type': type,
          'date': date,
          'payment_method': paymentMethod,
          'notes': notes,
          'receipt_url': receiptUrl,
          'is_recurring': isRecurring,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TransactionData.fromJson(data['transaction']);
      }
    } catch (e) {
      print('Error creating transaction: $e');
    }
    return null;
  }

  /// Get transactions with filtering
  Future<List<TransactionData>> getTransactions(
    String userId, {
    int limit = 50,
    int offset = 0,
    String? category,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl/transactions/$userId').replace(
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
          if (category != null) 'category': category,
          if (type != null) 'type': type,
          if (startDate != null) 'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['transactions'] as List)
            .map((t) => TransactionData.fromJson(t))
            .toList();
      }
    } catch (e) {
      print('Error getting transactions: $e');
    }
    return [];
  }

  /// Update a transaction
  Future<TransactionData?> updateTransaction({
    required String userId,
    required int transactionId,
    double? amount,
    String? description,
    String? category,
    String? type,
    String? date,
    String? paymentMethod,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (amount != null) updates['amount'] = amount;
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;
      if (type != null) updates['type'] = type;
      if (date != null) updates['date'] = date;
      if (paymentMethod != null) updates['payment_method'] = paymentMethod;
      if (notes != null) updates['notes'] = notes;

      final response = await http.put(
        Uri.parse('$_baseUrl/transactions/$userId/$transactionId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TransactionData.fromJson(data['transaction']);
      }
    } catch (e) {
      print('Error updating transaction: $e');
    }
    return null;
  }

  /// Delete a transaction
  Future<bool> deleteTransaction(String userId, int transactionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/transactions/$userId/$transactionId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting transaction: $e');
    }
    return false;
  }

  /// Get spending summary
  Future<SpendingSummary?> getSpendingSummary(
    String userId,
    String startDate,
    String endDate,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/transactions/$userId/summary?start_date=$startDate&end_date=$endDate',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SpendingSummary.fromJson(data['summary']);
      }
    } catch (e) {
      print('Error getting summary: $e');
    }
    return null;
  }

  // ==================== SCHEDULED PAYMENT OPERATIONS ====================

  /// Create a scheduled payment
  Future<ScheduledPaymentData?> createScheduledPayment({
    required String userId,
    required String name,
    required double amount,
    required String category,
    required String dueDate,
    String frequency = 'monthly',
    bool isAutopay = false,
    int reminderDays = 3,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scheduled-payments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'amount': amount,
          'category': category,
          'due_date': dueDate,
          'frequency': frequency,
          'is_autopay': isAutopay,
          'reminder_days': reminderDays,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScheduledPaymentData.fromJson(data['payment']);
      }
    } catch (e) {
      print('Error creating scheduled payment: $e');
    }
    return null;
  }

  /// Get all scheduled payments
  Future<List<ScheduledPaymentData>> getScheduledPayments(
    String userId, {
    String? status,
  }) async {
    try {
      var url = '$_baseUrl/scheduled-payments/$userId';
      if (status != null) url += '?status=$status';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['payments'] as List)
            .map((p) => ScheduledPaymentData.fromJson(p))
            .toList();
      }
    } catch (e) {
      print('Error getting scheduled payments: $e');
    }
    return [];
  }

  /// Update a scheduled payment
  Future<ScheduledPaymentData?> updateScheduledPayment({
    required String userId,
    required int paymentId,
    String? name,
    double? amount,
    String? category,
    String? frequency,
    bool? isAutopay,
    int? reminderDays,
    String? status,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (amount != null) updates['amount'] = amount;
      if (category != null) updates['category'] = category;
      if (frequency != null) updates['frequency'] = frequency;
      if (isAutopay != null) updates['is_autopay'] = isAutopay;
      if (reminderDays != null) updates['reminder_days'] = reminderDays;
      if (status != null) updates['status'] = status;
      if (notes != null) updates['notes'] = notes;

      final response = await http.put(
        Uri.parse('$_baseUrl/scheduled-payments/$userId/$paymentId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScheduledPaymentData.fromJson(data['payment']);
      }
    } catch (e) {
      print('Error updating scheduled payment: $e');
    }
    return null;
  }

  /// Mark a payment as paid
  Future<ScheduledPaymentData?> markPaymentPaid(
    String userId,
    int paymentId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scheduled-payments/$userId/$paymentId/mark-paid'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScheduledPaymentData.fromJson(data['payment']);
      }
    } catch (e) {
      print('Error marking payment paid: $e');
    }
    return null;
  }

  /// Delete a scheduled payment
  Future<bool> deleteScheduledPayment(String userId, int paymentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/scheduled-payments/$userId/$paymentId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting scheduled payment: $e');
    }
    return false;
  }

  /// Get upcoming payments
  Future<List<ScheduledPaymentData>> getUpcomingPayments(
    String userId, {
    int days = 7,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/scheduled-payments/$userId/upcoming?days=$days'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['payments'] as List)
            .map((p) => ScheduledPaymentData.fromJson(p))
            .toList();
      }
    } catch (e) {
      print('Error getting upcoming payments: $e');
    }
    return [];
  }

  // ==================== DASHBOARD ====================

  Future<DashboardData?> getDashboard(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String url = '$_baseUrl/dashboard/$userId';
      if (startDate != null && endDate != null) {
        final start = DateFormat('yyyy-MM-dd').format(startDate);
        final end = DateFormat('yyyy-MM-dd').format(endDate);
        url += '?start_date=$start&end_date=$end';
      }
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle direct response (which is what backend sends)
        if (data is Map<String, dynamic> && data.containsKey('total_income')) {
          return DashboardData.fromJson(data);
        }
        
        // Fallback for wrapped responses
        if (data['success'] == true && data['data'] != null) {
          return DashboardData.fromJson(data['data']);
        }
        
        return DashboardData.fromJson(data['dashboard'] ?? data['data'] ?? {});
      }
    } catch (e) {
      print('Error getting dashboard: $e');
    }
    return null;
  }

  /// Get trends and spending insights
  Future<TrendsData?> getTrends(
    String userId, {
    String period = 'monthly',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/trends/$userId?period=$period'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['trends'] != null) {
          return TrendsData.fromJson(data['trends']);
        }
      }
    } catch (e) {
      print('Error getting trends: $e');
    }
    return null;
  }

  /// Force recalculate trends
  Future<TrendsData?> analyzeTrends(
    String userId, {
    String period = 'monthly',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/trends/$userId/analyze?period=$period'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['trends'] != null) {
          return TrendsData.fromJson(data['trends']);
        }
      }
    } catch (e) {
      print('Error analyzing trends: $e');
    }
    return null;
  }

  /// Get daily insight
  Future<DailyInsight?> getDailyInsight(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/insights/daily/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DailyInsight.fromJson(data);
      }
    } catch (e) {
      print('Error getting daily insight: $e');
    }
    
    // Fallback if API fails (offline mode)
    // We can simulate insight from local data if needed, but for now returning null
    // allows the UI to show a default state.
    return null;
  }

  /// Get AI context string from trends service
  Future<String> getAiContext(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/trends/$userId/ai-context'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ai_context'] as String? ?? '';
      }
    } catch (e) {
      print('Error getting AI context: $e');
    }
    return '';
  }

  /// Import transactions from PDF
  Future<ImportResult?> importFromPdf(String userId, String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transactions/import/pdf?user_id=$userId'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ImportResult.fromJson(data);
      }
    } catch (e) {
      print('Error importing from PDF: $e');
    }
    return null;
  }

  /// Import transaction from image
  Future<ImportResult?> importFromImage(String userId, String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transactions/import/image?user_id=$userId'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ImportResult.fromJson(data);
      }
    } catch (e) {
      print('Error importing from image: $e');
    }
    return null;
  }

  // ==================== ANALYTICS & CALCULATOR OPERATIONS ====================

  /// Refresh daily trends
  Future<bool> refreshAnalytics(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/refresh/$userId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error refreshing analytics: $e');
    }
    return false;
  }

  /// Get monthly trends
  Future<Map<String, dynamic>> getMonthlyTrends(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/monthly/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getting monthly trends: $e');
    }
    return {};
  }

  /// Calculate Savings Rate
  Future<double> calculateSavingsRate(double income, double expenses) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/calculator/savings-rate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'income': income, 'expenses': expenses}),
      );
      if (response.statusCode == 200) {
        return (jsonDecode(response.body)['savings_rate_percentage'] as num)
            .toDouble();
      }
    } catch (e) {
      print('Error calculating savings rate: $e');
    }
    return 0.0;
  }

  /// Calculate Compound Interest
  Future<Map<String, dynamic>> calculateCompoundInterest({
    required double principal,
    required double rate,
    required int years,
    double monthlyContribution = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/calculator/compound-interest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'principal': principal,
          'rate': rate,
          'years': years,
          'monthly_contribution': monthlyContribution,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error calculating compound interest: $e');
    }
    return {};
  }

  /// Calculate Per Capita Income
  Future<double> calculatePerCapitaIncome(
      double totalIncome, int familySize) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/calculator/per-capita'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'total_income': totalIncome,
          'family_size': familySize,
        }),
      );
      if (response.statusCode == 200) {
        return (jsonDecode(response.body)['per_capita_income'] as num)
            .toDouble();
      }
    } catch (e) {
      print('Error calculating per capita: $e');
    }
    return 0.0;
  }

  /// Calculate Emergency Fund Status
  Future<Map<String, dynamic>> calculateEmergencyFundStatus({
    required double currentSavings,
    required double monthlyExpenses,
    int targetMonths = 6,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/calculator/emergency-fund'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'current_savings': currentSavings,
          'monthly_expenses': monthlyExpenses,
          'target_months': targetMonths,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error calculating emergency fund: $e');
    }
    return {};
  }

  // ==================== DOCUMENT SCANNING ====================

  /// Scan a receipt image
  Future<ReceiptData?> scanReceipt(String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/agent/scan-receipt'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return ReceiptData.fromJson(data['data']);
        }
      }
    } catch (e) {
      print('Error scanning receipt: $e');
    }
    return null;
  }

  /// Scan a PDF bank statement
  Future<List<TransactionData>> scanBankStatement(String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/agent/scan-document'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['transactions'] as List)
            .map(
              (t) => TransactionData(
                id: null,
                userId: '',
                amount: (t['amount'] as num).toDouble(),
                description: t['description'] ?? '',
                category: t['category'] ?? 'Uncategorized',
                type: t['type'] ?? 'expense',
                date: t['date'] ?? DateTime.now().toIso8601String(),
                time: t['time'],
                merchant: t['merchant'],
                paymentMethod: null,
                notes: null,
                receiptUrl: null,
                isRecurring: false,
                createdAt: DateTime.now().toIso8601String(),
              ),
            )
            .toList();
      }
    } catch (e) {
      print('Error scanning document: $e');
    }
    return [];
  }
}

// ==================== DATA MODELS ====================

class BudgetData {
  final int? id;
  final String userId;
  final String name;
  final double amount;
  final double spent;
  final String icon;
  final String category;
  final String period;
  final String startDate;
  final String? endDate;
  final String createdAt;
  final String updatedAt;

  BudgetData({
    this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.spent,
    required this.icon,
    required this.category,
    required this.period,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BudgetData.fromJson(Map<String, dynamic> json) {
    return BudgetData(
      id: json['id'],
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
      icon: json['icon'] ?? 'wallet',
      category: json['category'] ?? '',
      period: json['period'] ?? 'monthly',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  double get progress => amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
  double get remaining => amount - spent;
  bool get isOverBudget => spent > amount;
}

class GoalData {
  final int? id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? deadline;
  final String status;
  final String icon;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  GoalData({
    this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.status,
    required this.icon,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoalData.fromJson(Map<String, dynamic> json) {
    return GoalData(
      id: json['id'],
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0,
      deadline: json['deadline'],
      status: json['status'] ?? 'active',
      icon: json['icon'] ?? 'flag',
      notes: json['notes'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remaining => targetAmount - currentAmount;
  bool get isCompleted => currentAmount >= targetAmount;
}

class TransactionData {
  final int? id;
  final String userId;
  final double amount;
  final String description;
  final String category;
  final String type;
  final String date;
  final String? time;
  final String? merchant;
  final String? paymentMethod;
  final String? notes;
  final String? receiptUrl;
  final bool isRecurring;
  final String createdAt;

  TransactionData({
    this.id,
    required this.userId,
    required this.amount,
    required this.description,
    required this.category,
    required this.type,
    required this.date,
    this.time,
    this.merchant,
    this.paymentMethod,
    this.notes,
    this.receiptUrl,
    required this.isRecurring,
    required this.createdAt,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      id: json['id'],
      userId: json['user_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      type: json['type'] ?? 'expense',
      date: json['date'] ?? '',
      time: json['time'],
      merchant: json['merchant'],
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      receiptUrl: json['receipt_url'],
      isRecurring: json['is_recurring'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
}

class ScheduledPaymentData {
  final int? id;
  final String userId;
  final String name;
  final double amount;
  final String category;
  final String frequency;
  final String dueDate;
  final String nextDueDate;
  final bool isAutopay;
  final String status;
  final int reminderDays;
  final String? lastPaidDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  ScheduledPaymentData({
    this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.dueDate,
    required this.nextDueDate,
    required this.isAutopay,
    required this.status,
    required this.reminderDays,
    this.lastPaidDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScheduledPaymentData.fromJson(Map<String, dynamic> json) {
    return ScheduledPaymentData(
      id: json['id'],
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] ?? '',
      frequency: json['frequency'] ?? 'monthly',
      dueDate: json['due_date'] ?? '',
      nextDueDate: json['next_due_date'] ?? '',
      isAutopay: json['is_autopay'] ?? false,
      status: json['status'] ?? 'active',
      reminderDays: json['reminder_days'] ?? 3,
      lastPaidDate: json['last_paid_date'],
      notes: json['notes'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
}

class SpendingSummary {
  final double totalIncome;
  final double totalExpenses;
  final double net;
  final double savingsRate;
  final Map<String, double> byCategory;

  SpendingSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.net,
    required this.savingsRate,
    required this.byCategory,
  });

  factory SpendingSummary.fromJson(Map<String, dynamic> json) {
    return SpendingSummary(
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      savingsRate: (json['savings_rate'] as num?)?.toDouble() ?? 0,
      byCategory: Map<String, double>.from(
        (json['by_category'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
    );
  }
}

class DashboardData {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final double savingsRate;
  final String? topExpenseCategory;
  final double? topExpenseAmount;
  final Map<String, double> categoryBreakdown;
  final List<CashflowPoint> cashflowData;
  final List<TransactionData> recentTransactions;

  DashboardData({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.savingsRate,
    this.topExpenseCategory,
    this.topExpenseAmount,
    required this.categoryBreakdown,
    required this.cashflowData,
    required this.recentTransactions,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    // Handle nested summary structure from Python backend
    final summary = json['summary'] as Map<String, dynamic>?;

    // Parse cashflow data
    List<CashflowPoint> cashflow = [];
    if (json['cashflow_data'] != null) {
      cashflow = (json['cashflow_data'] as List)
          .map((c) => CashflowPoint.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    // Parse recent transactions
    List<TransactionData> recent = [];
    if (json['recent_transactions'] != null) {
      recent = (json['recent_transactions'] as List)
          .map((t) => TransactionData.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    // Parse category breakdown
    Map<String, double> categories = {};
    // Check both top-level and inside summary (for backend compatibility)
    final breakdownSource = json['category_breakdown'] ?? summary?['by_category'];
    
    if (breakdownSource != null) {
      categories = Map<String, double>.from(
        (breakdownSource as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      );
    }
    
    // Derive top expense category if not explicitly provided
    String? topCat = json['top_expense_category'];
    double? topAmt = (json['top_expense_amount'] as num?)?.toDouble();
    
    if (topCat == null && categories.isNotEmpty) {
       // Find max value in categories
       var sortedEntries = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
       if (sortedEntries.isNotEmpty) {
         topCat = sortedEntries.first.key;
         topAmt = sortedEntries.first.value;
       }
    }

    return DashboardData(
      totalIncome: (json['total_income'] ?? summary?['total_income'] as num?)?.toDouble() ?? 0,
      totalExpense: (json['total_expense'] ?? summary?['total_expenses'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] ?? summary?['net'] as num?)?.toDouble() ?? 0,
      savingsRate: (json['savings_rate'] ?? summary?['savings_rate'] as num?)?.toDouble() ?? 0,
      topExpenseCategory: topCat,
      topExpenseAmount: topAmt,
      categoryBreakdown: categories,
      cashflowData: cashflow,
      recentTransactions: recent,
    );
  }
}

class CashflowPoint {
  final String date;
  final double income;
  final double expense;
  final double balance;

  CashflowPoint({
    required this.date,
    required this.income,
    required this.expense,
    required this.balance,
  });

  factory CashflowPoint.fromJson(Map<String, dynamic> json) {
    return CashflowPoint(
      date: json['date'] ?? '',
      income: (json['income'] as num?)?.toDouble() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TrendsData {
  final double totalIncome;
  final double totalExpense;
  final double savingsRate;
  final double avgDailyExpense;
  final double minExpense;
  final double maxExpense;
  final String? topCategory;
  final double? topCategoryAmount;
  final Map<String, double> categoryTotals;
  final List<String> insights;

  TrendsData({
    required this.totalIncome,
    required this.totalExpense,
    required this.savingsRate,
    required this.avgDailyExpense,
    required this.minExpense,
    required this.maxExpense,
    this.topCategory,
    this.topCategoryAmount,
    required this.categoryTotals,
    required this.insights,
  });

  factory TrendsData.fromJson(Map<String, dynamic> json) {
    Map<String, double> categories = {};
    if (json['category_totals'] != null) {
      categories = Map<String, double>.from(
        (json['category_totals'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      );
    }

    List<String> insightsList = [];
    if (json['insights'] != null) {
      insightsList = List<String>.from(json['insights']);
    }

    return TrendsData(
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0,
      savingsRate: (json['savings_rate'] as num?)?.toDouble() ?? 0,
      avgDailyExpense: (json['avg_daily_expense'] as num?)?.toDouble() ?? 0,
      minExpense: (json['min_expense'] as num?)?.toDouble() ?? 0,
      maxExpense: (json['max_expense'] as num?)?.toDouble() ?? 0,
      topCategory: json['top_expense_category'],
      topCategoryAmount: (json['top_expense_amount'] as num?)?.toDouble(),
      categoryTotals: categories,
      insights: insightsList,
    );
  }
}

class DailyInsight {
  final String headline;
  final String insightText;
  final String recommendation;
  final String trendIndicator;
  final String? categoryHighlight;
  final double? amountHighlight;

  DailyInsight({
    required this.headline,
    required this.insightText,
    required this.recommendation,
    required this.trendIndicator,
    this.categoryHighlight,
    this.amountHighlight,
  });

  factory DailyInsight.fromJson(Map<String, dynamic> json) {
    return DailyInsight(
      headline: json['headline'] ?? '',
      insightText: json['insightText'] ?? json['insight_text'] ?? '',
      recommendation: json['recommendation'] ?? '',
      trendIndicator: json['trendIndicator'] ?? json['trend_indicator'] ?? 'stable',
      categoryHighlight: json['categoryHighlight'] ?? json['category_highlight'],
      amountHighlight: (json['amountHighlight'] ?? json['amount_highlight'] as num?)?.toDouble(),
    );
  }
}

class ImportResult {
  final bool success;
  final String? bankDetected;
  final List<TransactionData> transactions;
  final int importedCount;
  final String? message;
  final double? confidence;

  ImportResult({
    required this.success,
    this.bankDetected,
    required this.transactions,
    required this.importedCount,
    this.message,
    this.confidence,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    List<TransactionData> txns = [];
    if (json['transactions'] != null) {
      txns = (json['transactions'] as List).map((t) {
        if (t is Map<String, dynamic>) {
          return TransactionData(
            id: t['id'],
            userId: t['user_id'] ?? '',
            amount: (t['amount'] as num?)?.toDouble() ?? 0,
            description: t['description'] ?? '',
            category: t['category'] ?? 'Other',
            type: t['type'] ?? 'expense',
            date: t['date'] ?? DateTime.now().toIso8601String(),
            paymentMethod: t['payment_method'],
            notes: t['notes'],
            receiptUrl: null,
            isRecurring: false,
            createdAt: t['created_at'] ?? DateTime.now().toIso8601String(),
          );
        }
        return TransactionData(
          id: null,
          userId: '',
          amount: 0,
          description: '',
          category: 'Other',
          type: 'expense',
          date: DateTime.now().toIso8601String(),
          paymentMethod: null,
          notes: null,
          receiptUrl: null,
          isRecurring: false,
          createdAt: DateTime.now().toIso8601String(),
        );
      }).toList();
    }

    return ImportResult(
      success: json['success'] ?? false,
      bankDetected: json['bank_detected'],
      transactions: txns,
      importedCount: json['imported_count'] ?? 0,
      message: json['message'],
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

class ReceiptData {
  final String? merchantName;
  final String? date;
  final double? totalAmount;
  final String? currency;
  final List<Map<String, dynamic>>? items;
  final String? category;
  final String? paymentMethod;
  final double? confidence;

  ReceiptData({
    this.merchantName,
    this.date,
    this.totalAmount,
    this.currency,
    this.items,
    this.category,
    this.paymentMethod,
    this.confidence,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      merchantName: json['merchant_name'],
      date: json['date'],
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      currency: json['currency'],
      items: json['items'] != null
          ? List<Map<String, dynamic>>.from(json['items'])
          : null,
      category: json['category'],
      paymentMethod: json['payment_method'],
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

/// Global singleton instance
final dataService = DataService();
