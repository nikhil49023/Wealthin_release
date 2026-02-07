import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, TargetPlatform, ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:read_pdf_text/read_pdf_text.dart';
import 'sarvam_service.dart';
import 'backend_config.dart';
import 'database_helper.dart';
import 'python_bridge_service.dart';
import 'native_pdf_service.dart';
import 'financial_calculator.dart';
import '../models/models.dart';

// Typedefs to bridge previous naming mismatch if needed, or just use Models
typedef TransactionData = TransactionModel;
typedef BudgetData = BudgetModel;
typedef GoalData = GoalModel;

/// Data Service - Handles all CRUD operations and analytics
/// On Android: Uses embedded Python + local SQLite (no HTTP backend)
/// On Desktop: Uses HTTP backend + local SQLite fallback
class DataService {
  // Singleton pattern
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // Use BackendConfig for dynamic port management (desktop only)
  String get _baseUrl => backendConfig.baseUrl;
  
  // Platform detection - skip HTTP on Android
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  // Platform detection - skip HTTP on Android

  // ==================== CREDIT SYSTEM (NATIVE) ====================
  final ValueNotifier<int> userCredits = ValueNotifier<int>(100);

  /// Initialize credits from storage
  Future<void> initCredits() async {
    final prefs = await SharedPreferences.getInstance();
    // Default 100 credits if not set
    if (!prefs.containsKey('user_credits')) {
      await prefs.setInt('user_credits', 100);
    }
    userCredits.value = prefs.getInt('user_credits') ?? 100;
  }

  /// Deduct credits and return success
  Future<bool> deductCredits(int amount) async {
    if (userCredits.value < amount) return false;
    
    final prefs = await SharedPreferences.getInstance();
    int newBalance = userCredits.value - amount;
    
    await prefs.setInt('user_credits', newBalance);
    userCredits.value = newBalance;
    return true;
  }

  // ==================== DAILY STREAK SYSTEM ====================
  final ValueNotifier<int> currentStreak = ValueNotifier<int>(0);
  final ValueNotifier<int> longestStreak = ValueNotifier<int>(0);

  /// Initialize and update streak
  Future<Map<String, dynamic>> initStreak() async {
    try {
      final streakData = await databaseHelper.updateStreak();
      currentStreak.value = streakData['current_streak'] as int? ?? 0;
      longestStreak.value = streakData['longest_streak'] as int? ?? 0;
      return streakData;
    } catch (e) {
      debugPrint('Error initializing streak: $e');
      return {'current_streak': 0, 'longest_streak': 0};
    }
  }

  /// Get current streak data without updating
  Future<Map<String, dynamic>?> getStreak() async {
    try {
      return await databaseHelper.getStreak();
    } catch (e) {
      debugPrint('Error getting streak: $e');
      return null;
    }
  }

  // ==================== BUDGET OPERATIONS ====================

  /// Create a new budget
  Future<BudgetData?> createBudget({
    required String userId,
    required String name, // Used as category in DB
    required double amount,
    required String category,
    String icon = 'wallet',
    String period = 'monthly',
  }) async {
    try {
      final row = {
        'category': category,
        'limit_amount': amount,
        'spent_amount': 0.0,
        'period': period,
      };
      
      await databaseHelper.createBudget(row);
      
      // Return a budget object constructed from input
      return BudgetData(
        id: 0, // No ID for category-based PK
        name: name,
        category: category,
        amount: amount,
        spent: 0,
        icon: icon,
      );
    } catch (e) {
      debugPrint('Error creating budget: $e');
    }
    return null;
  }

  /// Get all budgets for a user
  Future<List<BudgetData>> getBudgets(String userId) async {
    try {
      final rows = await databaseHelper.getBudgets();
      return rows.map((row) => BudgetData.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error getting budgets: $e');
    }
    return [];
  }

  // TODO: Update Budget logic requires more complex DB logic/sync if needed
  // For now skipping full update implementation as it relies on category PK

  /// Delete a budget
  Future<bool> deleteBudget(String userId, int budgetId) async {
    // Requires category string, but signature has int ID. 
    // This signature mismatch suggests we need to fetch or adjust calling code.
    // For now returning false to indicate not implemented/safe.
    return false; 
  }

  /// Update a budget
  Future<BudgetData?> updateBudget({
    required String userId,
    required String category,
    double? limitAmount,
    double? spentAmount,
    String? period,
  }) async {
    try {
      final row = <String, dynamic>{
        'category': category,
        if (limitAmount != null) 'limit_amount': limitAmount,
        if (spentAmount != null) 'spent_amount': spentAmount,
        if (period != null) 'period': period,
      };
      
      await databaseHelper.updateBudget(row);
      
      // Fetch and return updated budget
      final budgets = await databaseHelper.getBudgets();
      final updatedBudget = budgets.firstWhere((b) => b['category'] == category, orElse: () => {});
      if (updatedBudget.isNotEmpty) {
        return BudgetData.fromJson(updatedBudget);
      }
    } catch (e) {
      debugPrint('Error updating budget: $e');
    }
    return null;
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
      final row = {
        'name': name,
        'target_amount': targetAmount,
        'saved_amount': 0.0,
        'deadline': deadline,
        // 'color_hex': ...
      };
      
      final id = await databaseHelper.createGoal(row);
      
      return GoalData(
        id: id,
        name: name,
        targetAmount: targetAmount,
        currentAmount: 0,
      );
    } catch (e) {
      debugPrint('Error creating goal: $e');
    }
    return null;
  }

  /// Get all goals for a user
  Future<List<GoalData>> getGoals(String userId) async {
    try {
      final rows = await databaseHelper.getGoals();
      return rows.map((row) => GoalData.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error getting goals: $e');
    }
    return [];
  }

  /// Update an existing goal
  Future<GoalData?> updateGoal({
    required String userId,
    required int goalId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? deadline,
    String? status,
    String? icon,
    String? notes,
  }) async {
    try {
      final row = <String, dynamic>{
        'id': goalId,
        if (name != null) 'name': name,
        if (targetAmount != null) 'target_amount': targetAmount,
        if (currentAmount != null) 'saved_amount': currentAmount,
        if (deadline != null) 'deadline': deadline,
      };
      
      await databaseHelper.updateGoal(row);
      
      // Fetch and return updated goal
      final goals = await databaseHelper.getGoals();
      final updatedGoal = goals.firstWhere((g) => g['id'] == goalId, orElse: () => {});
      if (updatedGoal.isNotEmpty) {
        return GoalData.fromJson(updatedGoal);
      }
    } catch (e) {
      debugPrint('Error updating goal: $e');
    }
    return null;
  }

  /// Add funds to a goal (increment saved amount)
  Future<GoalData?> addFundsToGoal({
    required String userId,
    required int goalId,
    required double amount,
  }) async {
    try {
      // Get current goal
      final goals = await databaseHelper.getGoals();
      final currentGoal = goals.firstWhere((g) => g['id'] == goalId, orElse: () => {});
      
      if (currentGoal.isEmpty) return null;
      
      final currentAmount = (currentGoal['saved_amount'] as num?)?.toDouble() ?? 0.0;
      final newAmount = currentAmount + amount;
      
      final row = {
        'id': goalId,
        'saved_amount': newAmount,
      };
      
      await databaseHelper.updateGoal(row);
      
      // Fetch and return updated goal
      final updatedGoals = await databaseHelper.getGoals();
      final updatedGoal = updatedGoals.firstWhere((g) => g['id'] == goalId, orElse: () => {});
      if (updatedGoal.isNotEmpty) {
        return GoalData.fromJson(updatedGoal);
      }
    } catch (e) {
      debugPrint('Error adding funds to goal: $e');
    }
    return null;
  }

  /// Delete a goal
  Future<bool> deleteGoal(String userId, int goalId) async {
    try {
      final count = await databaseHelper.deleteGoal(goalId);
      return count > 0;
    } catch (e) {
      debugPrint('Error deleting goal: $e');
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
      final row = {
        'amount': amount,
        'description': description,
        'category': category,
        'type': type,
        'date': date ?? DateTime.now().toIso8601String(),
        'paymentMethod': paymentMethod,
        'merchant': notes, // Mapping notes to merchant for now if simple
      };

      final id = await databaseHelper.insertTransaction(row);

      return TransactionData(
        id: id,
        amount: amount,
        description: description,
        date: DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now(),
        type: type,
        category: category,
        paymentMethod: paymentMethod,
      );
    } catch (e) {
      debugPrint('Error creating transaction: $e');
    }
    return null;
  }

  /// Get transactions with filtering
  Future<List<TransactionData>> getTransactions(
    String userId, {
    int limit = 50,
    int offset = 0,
    String? category,
    String? type, // Not fully supported in DB Helper yet
    String? startDate,
    String? endDate,
  }) async {
    try {
      final rows = await databaseHelper.getTransactions(limit: limit, offset: offset);
      return rows.map((row) => TransactionData.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
    }
    return [];
  }

  /// Delete a transaction
  Future<bool> deleteTransaction(String userId, int transactionId) async {
    try {
      final count = await databaseHelper.deleteTransaction(transactionId);
      return count > 0;
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
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
    // On Android, scheduled payments are not yet stored locally
    // Return empty list to avoid HTTP errors
    if (_isAndroid) {
      // TODO: Implement local scheduled payments storage
      return [];
    }
    
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
      debugPrint('Error getting scheduled payments: $e');
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

  // ==================== DASHBOARD & TRENDS ====================

  Future<DashboardData?> getDashboard(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final sDate = startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : null;
      final eDate = endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : null;
      
      // 1. Transaction Summary
      final summary = await databaseHelper.getTransactionSummary(startDate: sDate, endDate: eDate);
      // Fallback manual calc if summary is null or we need filtering (DatabaseHelper summary doesn't support filter yet)
      // Since we want accuracy, let's allow filtering or accept total lifetime stats for dashboard if dates null
      
      double income = (summary?['total_income'] as num?)?.toDouble() ?? 0.0;
      double expenses = (summary?['total_expenses'] as num?)?.toDouble() ?? 0.0;

      // 2. Category Breakdown
      final breakdown = await databaseHelper.getCategoryBreakdown(startDate: sDate, endDate: eDate);
      
      // 3. Recent Transactions
      final recentRows = await databaseHelper.getTransactions(limit: 5);
      final recent = recentRows.map((r) => TransactionModel.fromJson(r)).toList();
      
      // 4. Cashflow
      final cashflowRows = await databaseHelper.getDailyCashflow(startDate: sDate, endDate: eDate);
      // Process cashflow rows into CashflowPoint
      Map<String, double> incomeMap = {};
      Map<String, double> expenseMap = {};
      Set<String> dates = {};
      
      for (var row in cashflowRows) {
        String date = row['date']?.toString() ?? '';
        final lowerType = row['type']?.toString().toLowerCase() ?? 'expense';
        double amt = (row['total'] as num?)?.toDouble() ?? 0.0;
        if (date.isEmpty) continue;
        
        dates.add(date);
        bool isInc = ['income', 'credit', 'deposit'].contains(lowerType);
        if (isInc) {
          incomeMap[date] = (incomeMap[date] ?? 0) + amt;
        } else {
          expenseMap[date] = (expenseMap[date] ?? 0) + amt;
        }
      }
      
      List<String> sortedDates = dates.toList()..sort();
      List<CashflowPoint> cashflow = [];
      double runningBal = 0; // Or fetch initial balance
      
      for (var d in sortedDates) {
        double inc = incomeMap[d] ?? 0;
        double exp = expenseMap[d] ?? 0;
        runningBal += (inc - exp);
        cashflow.add(CashflowPoint(
          date: d,
          income: inc,
          expense: exp,
          balance: runningBal,
        ));
      }

      // Top Expense
      String? topCat;
      double? topAmt;
      if (breakdown.isNotEmpty) {
        var sorted = breakdown.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
        topCat = sorted.first.key;
        topAmt = sorted.first.value;
      }

      return DashboardData(
        totalIncome: income,
        totalExpense: expenses,
        balance: income - expenses,
        savingsRate: income > 0 ? ((income - expenses) / income) * 100 : 0,
        topExpenseCategory: topCat,
        topExpenseAmount: topAmt,
        categoryBreakdown: breakdown,
        cashflowData: cashflow,
        recentTransactions: recent,
      );

    } catch (e) {
      debugPrint('Error getting dashboard: $e');
    }
    return null;
  }

  /// Get trends and spending insights
  Future<TrendsData?> getTrends(
    String userId, {
    String period = 'monthly',
  }) async {
    try {
      // Calculate start/end based on period
      DateTime now = DateTime.now();
      String? startDate;
      if (period == 'monthly') {
        startDate = DateFormat('yyyy-MM-01').format(now);
      } else if (period == 'yearly') {
        startDate = DateFormat('yyyy-01-01').format(now);
      }
      
      // Reuse aggregations
      final breakdown = await databaseHelper.getCategoryBreakdown(startDate: startDate);
      
      // Calc totals from transactions in range
      final transactions = await databaseHelper.getTransactions(limit: 10000, startDate: startDate);
      double income = 0;
      double expense = 0;
      double minExp = double.maxFinite;
      double maxExp = 0;
      Set<String> activeDays = {};
      
      for (var t in transactions) {
        // t is Map
        double amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
        String type = t['type']?.toString() ?? 'expense';
        if (type == 'income' || type == 'credit') {
          income += amt;
        } else {
          expense += amt;
          if (amt < minExp) minExp = amt;
          if (amt > maxExp) maxExp = amt;
          final dateStr = t['date']?.toString() ?? '';
          if (dateStr.isNotEmpty) {
            activeDays.add(dateStr.split('T')[0]); // simplified date part
          }
        }
      }
      if (minExp == double.maxFinite) minExp = 0;

      double avgDaily = activeDays.isNotEmpty ? expense / activeDays.length : 0;
      
       // Top Expense
      String? topCat;
      double? topAmt;
      if (breakdown.isNotEmpty) {
        var sorted = breakdown.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
        topCat = sorted.first.key;
        topAmt = sorted.first.value;
      }

      return TrendsData(
        totalIncome: income,
        totalExpense: expense,
        savingsRate: income > 0 ? ((income - expense) / income) * 100 : 0,
        avgDailyExpense: avgDaily,
        minExpense: minExp,
        maxExpense: maxExp,
        topCategory: topCat,
        topCategoryAmount: topAmt,
        categoryTotals: breakdown,
        insights: [], // TODO: Generate basic insights locally
      );
    } catch (e) {
      debugPrint('Error getting trends: $e');
    }
    return null;
  }

  /// Force recalculate trends (No-op for local DB or re-fetch)
  Future<TrendsData?> analyzeTrends(
    String userId, {
    String period = 'monthly',
  }) async {
    return getTrends(userId, period: period);
  }

  /// Get daily insight
  Future<DailyInsight?> getDailyInsight(String userId) async {
    // On Android, generate insight from local data
    if (_isAndroid) {
      return await _generateLocalInsight(userId);
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/insights/daily/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DailyInsight.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error getting daily insight: $e');
    }
    
    // Fallback to local generation
    return await _generateLocalInsight(userId);
  }
  
  /// Generate insight from local data using Python bridge
  Future<DailyInsight?> _generateLocalInsight(String userId) async {
    try {
      // Get transactions from local DB
      final transactions = await databaseHelper.getTransactions(limit: 100);
      
      if (transactions.isEmpty) {
        return DailyInsight(
          headline: 'Welcome to WealthIn!',
          insightText: 'Start tracking your expenses to get personalized insights.',
          recommendation: 'Add your first transaction to get started.',
          trendIndicator: 'stable',
        );
      }
      
      // Use Python bridge for analysis
      final txList = transactions.map((t) => {
        'description': t['description'] ?? '',
        'amount': t['amount'] ?? 0,
        'category': t['category'] ?? 'Other',
        'date': t['date'] ?? '',
        'type': t['type'] ?? 'expense',
      }).toList();
      
      final analysis = await pythonBridge.analyzeSpending(txList);
      
      if (analysis['success'] == true) {
        final analyticsData = analysis['analysis'] as Map<String, dynamic>?;
        final savingsRate = analyticsData?['savings_rate'] as num? ?? 0;
        final topCategory = analyticsData?['top_category'] as Map<String, dynamic>?;
        
        if (savingsRate >= 20) {
          return DailyInsight(
            headline: 'Great Savings! 🌟',
            insightText: 'You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income. Keep it up!',
            recommendation: 'Consider investing your surplus in mutual funds.',
            trendIndicator: 'up',
          );
        } else if (topCategory != null) {
          return DailyInsight(
            headline: 'Top Spending 💡',
            insightText: '${topCategory['category']} is your highest expense at ${topCategory['percentage']?.toStringAsFixed(1)}%.',
            recommendation: 'Review this category for potential savings.',
            trendIndicator: 'stable',
            categoryHighlight: topCategory['category'] as String?,
          );
        }
      }
      
      return DailyInsight(
        headline: 'Track Your Progress 📊',
        insightText: 'Keep adding transactions to get better insights.',
        recommendation: 'Regular tracking helps you understand spending patterns.',
        trendIndicator: 'stable',
      );
    } catch (e) {
      debugPrint('Error generating local insight: $e');
      return null;
    }
  }


  /// Get comprehensive AI context with user's complete financial picture
  /// This enables AI to provide personalized advice (EMI vs cash, budgeting tips, etc.)
  Future<String> getAiContext(String userId) async {
    // On Android, generate comprehensive context locally
    if (_isAndroid) {
      try {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
        
        // === CURRENT MONTH DATA ===
        final incomeExpense = await databaseHelper.getTransactionSummary(
          startDate: startOfMonth.toIso8601String()
        );
        final breakdown = await databaseHelper.getCategoryBreakdown(
          startDate: startOfMonth.toIso8601String()
        );
        
        double currentIncome = (incomeExpense?['total_income'] as num?)?.toDouble() ?? 0;
        double currentExpense = (incomeExpense?['total_expenses'] as num?)?.toDouble() ?? 0;
        double currentSavings = currentIncome - currentExpense;
        double savingsRate = currentIncome > 0 ? (currentSavings / currentIncome * 100) : 0;
        
        // === LAST 3 MONTHS AVERAGE ===
        final threeMonthData = await databaseHelper.getTransactionSummary(
          startDate: threeMonthsAgo.toIso8601String()
        );
        double avgMonthlyIncome = ((threeMonthData?['total_income'] as num?)?.toDouble() ?? 0) / 3;
        double avgMonthlyExpense = ((threeMonthData?['total_expenses'] as num?)?.toDouble() ?? 0) / 3;
        double avgMonthlySavings = avgMonthlyIncome - avgMonthlyExpense;
        
        // === BUDGETS ===
        final budgets = await databaseHelper.getBudgets();
        String budgetInfo = '';
        double totalBudgeted = 0;
        if (budgets.isNotEmpty) {
          for (var b in budgets.take(5)) {
            String name = b['name']?.toString() ?? b['category']?.toString() ?? 'Unknown';
            double amount = (b['amount'] as num?)?.toDouble() ?? 0;
            double spent = (b['spent'] as num?)?.toDouble() ?? 0;
            totalBudgeted += amount;
            double pct = amount > 0 ? (spent / amount * 100) : 0;
            budgetInfo += '  - $name: ₹${spent.toStringAsFixed(0)} / ₹${amount.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}% used)\n';
          }
        }
        
        // === SAVINGS GOALS ===
        final goals = await databaseHelper.getGoals();
        String goalInfo = '';
        double totalGoalTarget = 0;
        double totalGoalSaved = 0;
        if (goals.isNotEmpty) {
          for (var g in goals.take(5)) {
            String name = g['name']?.toString() ?? 'Unknown';
            double target = (g['target_amount'] as num?)?.toDouble() ?? 0;
            double saved = (g['current_amount'] as num?)?.toDouble() ?? 0;
            totalGoalTarget += target;
            totalGoalSaved += saved;
            double progress = target > 0 ? (saved / target * 100) : 0;
            goalInfo += '  - $name: ₹${saved.toStringAsFixed(0)} / ₹${target.toStringAsFixed(0)} (${progress.toStringAsFixed(0)}%)\n';
          }
        }

        
        // === TOP SPENDING CATEGORIES ===
        var sortedCats = breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        String topCats = sortedCats.take(5).map((e) => "  - ${e.key}: ₹${e.value.toStringAsFixed(0)}").join('\n');
        
        // === FINANCIAL HEALTH INDICATORS ===
        String financialHealth = 'Needs Attention';
        String emiRecommendation = 'Consider EMI for expensive purchases to preserve cash flow';
        
        if (savingsRate >= 30) {
          financialHealth = 'Excellent';
          emiRecommendation = 'You can afford full cash purchase for most items';
        } else if (savingsRate >= 20) {
          financialHealth = 'Good';
          emiRecommendation = 'Full cash for items under ₹20,000; EMI for larger purchases';
        } else if (savingsRate >= 10) {
          financialHealth = 'Moderate';
          emiRecommendation = 'EMI recommended for purchases over ₹10,000';
        } else if (savingsRate >= 0) {
          financialHealth = 'Tight Budget';
          emiRecommendation = 'EMI strongly recommended; avoid large purchases if possible';
        } else {
          financialHealth = 'Deficit (Spending > Income)';
          emiRecommendation = 'Avoid new purchases until budget is balanced';
        }
        
        // Calculate disposable income (after essential expenses)
        double essentialExpenses = (breakdown['Utilities'] ?? 0) + 
                                   (breakdown['Bills'] ?? 0) + 
                                   (breakdown['Food & Dining'] ?? 0) +
                                   (breakdown['Transportation'] ?? 0);
        double disposableIncome = currentIncome - essentialExpenses;
        
        // === BUILD COMPREHENSIVE CONTEXT ===
        final context = '''
=== USER FINANCIAL PROFILE ===

**Monthly Summary (Current Month):**
- Income: ₹${currentIncome.toStringAsFixed(0)}
- Expenses: ₹${currentExpense.toStringAsFixed(0)}
- Savings: ₹${currentSavings.toStringAsFixed(0)}
- Savings Rate: ${savingsRate.toStringAsFixed(1)}%
- Disposable Income: ₹${disposableIncome.toStringAsFixed(0)}
- Financial Health: $financialHealth

**3-Month Averages:**
- Avg Monthly Income: ₹${avgMonthlyIncome.toStringAsFixed(0)}
- Avg Monthly Expense: ₹${avgMonthlyExpense.toStringAsFixed(0)}
- Avg Monthly Savings: ₹${avgMonthlySavings.toStringAsFixed(0)}

**Active Budgets (Total: ₹${totalBudgeted.toStringAsFixed(0)}):**
${budgetInfo.isEmpty ? '  - No budgets set' : budgetInfo}
**Savings Goals (₹${totalGoalSaved.toStringAsFixed(0)} saved of ₹${totalGoalTarget.toStringAsFixed(0)}):**
${goalInfo.isEmpty ? '  - No active goals' : goalInfo}
**Top Spending Categories:**
${topCats.isEmpty ? '  - No data' : topCats}

**AI Purchase Advice:**
$emiRecommendation

=== END PROFILE ===
''';
        
        return context;
      } catch (e) {
        debugPrint('Error building AI context: $e');
        return 'Unable to load financial data. Provide general advice.';
      }
    }
    
    // Fallback for non-Android (HTTP call to backend)
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/trends/$userId/ai-context'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ai_context'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Error getting AI context: $e');
    }
    return '';
  }


  /// Import transactions from PDF
  Future<ImportResult?> importFromPdf(String userId, String filePath) async {
    if (_isAndroid) {
      try {
        // Native PDF extraction
        final text = await ReadPdfText.getPDFtext(filePath);
        if (text.isEmpty) {
           return ImportResult(success: false, transactions: [], importedCount: 0, message: 'Could not read text from PDF');
        }

        // AI Extraction via HTTP
        final result = await SarvamService().extractTransactionsFromText(text);
        
        if (result['success'] == true) {
          final txs = result['transactions'] as List;
          int imported = 0;
          List<TransactionModel> models = [];
          
          for (var t in txs) {
            String type = (t['type']?.toString().toLowerCase() ?? 'debit');
            // Normalize type
            if (type.contains('credit') || type.contains('cr')) type = 'income';
            else type = 'expense';

            final row = {
              'amount': (t['amount'] as num?)?.toDouble() ?? 0.0,
              'description': t['description']?.toString() ?? 'Imported PDF',
              'category': 'Other', // Auto-categorization can be added later
              'date': t['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'type': type,
            };
            final model = TransactionModel.fromJson(row);
            models.add(model);
            
            final id = await databaseHelper.insertTransaction(row);
            if (id > 0) imported++;
          }
          
          return ImportResult(
            success: true,
            transactions: models,
            importedCount: imported,
            bankDetected: result['bank_detected'],
            message: 'Imported $imported transactions from PDF',
          );
        }
        return ImportResult(success: false, transactions: [], importedCount: 0, message: result['error'] ?? 'Unknown error');
      } catch (e) {
        debugPrint('Error importing PDF (Native): $e');
        return ImportResult(success: false, transactions: [], importedCount: 0, message: e.toString());
      }
    }

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
    if (_isAndroid) {
      try {
        final result = await pythonBridge.extractReceiptFromPath(filePath);
        if (result['success'] == true) {
          final row = {
            'amount': (result['total_amount'] as num?)?.toDouble() ?? 0,
            'description': result['merchant_name'] ?? 'Imported Receipt',
            'category': result['category'] ?? 'Other',
            'type': 'expense',
            'date': result['date'] ?? DateTime.now().toIso8601String(),
            'merchant': result['merchant_name'],
          };
          await databaseHelper.insertTransaction(row);
          final model = TransactionModel.fromJson(row);
          
          return ImportResult(
            success: true,
            transactions: [model],
            importedCount: 1,
            message: 'Imported receipt successfully',
          );
        }
        return ImportResult(success: false, transactions: [], importedCount: 0, message: result['error'] ?? 'Unknown error');
      } catch (e) {
        debugPrint('Error importing Image (Android): $e');
        return ImportResult(success: false, transactions: [], importedCount: 0, message: e.toString());
      }
    }

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
    // On Android, analytics are computed locally - no refresh needed
    if (_isAndroid) {
      return true;
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/refresh/$userId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error refreshing analytics: $e');
    }
    return false;
  }

  /// Get monthly trends
  Future<Map<String, dynamic>> getMonthlyTrends(String userId) async {
    // On Android, compute trends locally using Python bridge
    if (_isAndroid) {
      try {
        final transactions = await databaseHelper.getTransactions(limit: 200);
        
        if (transactions.isEmpty) {
          return {'months': [], 'trends': []};
        }
        
        final txList = transactions.map((t) => {
          'description': t['description'] ?? '',
          'amount': t['amount'] ?? 0,
          'category': t['category'] ?? 'Other',
          'date': t['date'] ?? '',
        }).toList();
        
        final analysis = await pythonBridge.analyzeSpending(txList);
        
        if (analysis['success'] == true) {
          return analysis['analysis'] as Map<String, dynamic>? ?? {};
        }
      } catch (e) {
        debugPrint('Error getting local monthly trends: $e');
      }
      return {};
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/monthly/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting monthly trends: $e');
    }
    return {};
  }


  /// Calculate Savings Rate
  Future<double> calculateSavingsRate(double income, double expenses) async {
    return FinancialCalculator.calculateSavingsRate(income, expenses);
  }

  /// Calculate Compound Interest
  Future<Map<String, dynamic>> calculateCompoundInterest({
    required double principal,
    required double rate,
    required int years,
    double monthlyContribution = 0,
  }) async {
    return FinancialCalculator.calculateCompoundInterest(
      principal: principal,
      rate: rate,
      years: years,
      monthlyContribution: monthlyContribution,
    );
  }

  /// Calculate Per Capita Income
  Future<double> calculatePerCapitaIncome(
      double totalIncome, int familySize) async {
    return FinancialCalculator.calculatePerCapitaIncome(totalIncome, familySize);
  }

  /// Calculate Emergency Fund Status
  Future<Map<String, dynamic>> calculateEmergencyFundStatus({
    required double currentSavings,
    required double monthlyExpenses,
    int targetMonths = 6,
  }) async {
    return FinancialCalculator.calculateEmergencyFundStatus(
      currentSavings: currentSavings,
      monthlyExpenses: monthlyExpenses,
      targetMonths: targetMonths,
    );
  }

  // ==================== AI BRAINSTORMING ====================

  /// Analyze a business idea with AI-powered market research
  Future<Map<String, dynamic>?> brainstormBusinessIdea({
    required String idea,
    required String userId,
    String? location,
    String? budgetRange,
  }) async {
    // First try HTTP backend (for desktop)
    if (!_isAndroid) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/agent/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'query': 'Analyze this business idea and provide comprehensive market research: $idea',
            'context': {
              'location': location ?? 'India',
              'budget_range': budgetRange ?? '5-10 Lakhs',
              'force_tool': 'brainstorm_business_idea',
            },
          }),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Extract from action_data if available
          if (data['action_data'] != null) {
            return data['action_data'] as Map<String, dynamic>;
          }
          return {
            'score': 70,
            'message': data['response'] ?? 'Analysis complete.',
            'research': {},
          };
        }
      } catch (e) {
        debugPrint('Brainstorm HTTP failed: $e');
      }
    }
    
    // Fallback to Python bridge (Android)
    if (_isAndroid) {
      try {
        final result = await pythonBridge.chatWithLLM(
          query: 'Analyze this business idea: $idea',
        );
        
        if (result['success'] == true) {
          final data = result['action_data'] as Map<String, dynamic>?;
          return data ?? {
            'score': 70,
            'message': result['response'] ?? 'Analysis complete.',
            'research': {},
          };
        }
      } catch (e) {
        debugPrint('Brainstorm Python bridge failed: $e');
      }
    }
    
    return null;
  }

  // ==================== DOCUMENT SCANNING ====================

  /// Scan a receipt image using Sarvam AI Vision
  Future<ReceiptData?> scanReceipt(String filePath) async {
    // First try Sarvam AI directly (works on all platforms)
    try {
      final result = await SarvamService().analyzeReceipt(filePath);
      if (result['success'] == true) {
        return ReceiptData.fromJson(result);
      }
    } catch (e) {
      debugPrint('Sarvam Vision failed: $e');
    }
    
    // Fallback to Android Python bridge if available
    if (_isAndroid) {
      try {
        final result = await pythonBridge.extractReceiptFromPath(filePath);
        if (result['success'] == true) {
          return ReceiptData.fromJson(result);
        }
      } catch (e) {
        debugPrint('Error scanning receipt (Android fallback): $e');
      }
    }
    
    // Last fallback to backend API (for desktop)
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
      print('Error scanning receipt (backend fallback): $e');
    }
    return null;
  }

  /// Scan a PDF bank statement - returns parsed transactions WITHOUT saving
  /// Use saveTransactions() to persist them after user confirmation
  Future<List<TransactionModel>> scanBankStatement(String filePath) async {
    // Start with Native Parsing (Safe & Fast)
    try {
      debugPrint('Parsing PDF natively: $filePath');
      final transactions = await NativePdfService().parsePdf(filePath);
      
      if (transactions.isNotEmpty) {
        debugPrint('Native parsing successful: ${transactions.length} transactions found.');
        
        // Optional: Enhance with AI Categorization from Backend (if online)
        // We can implement this optimization later if needed.
        // For now, the native regex-based categorization is robust enough for basic usage.
        
        return transactions;
      }
    } catch (e) {
      debugPrint('Native parsing failed: $e');
    }
    
    // Fallback? No, user requested to move away from backend PDF parsing to avoid crashes.
    return [];
  }

  /// Batch save multiple transactions to local database
  /// Used after user confirms transactions from confirmation screen
  Future<int> saveTransactions(List<TransactionModel> transactions, String userId) async {
    int savedCount = 0;
    
    for (final tx in transactions) {
      try {
        final result = await createTransaction(
          userId: userId,
          amount: tx.amount,
          description: tx.description,
          category: tx.category,
          type: tx.type,
          date: DateFormat('yyyy-MM-dd').format(tx.date),
          paymentMethod: tx.paymentMethod,
          notes: tx.notes,
        );
        if (result != null) {
          savedCount++;
        }
      } catch (e) {
        debugPrint('Error saving transaction: ${tx.description} - $e');
      }
    }
    
    debugPrint('Saved $savedCount of ${transactions.length} transactions');
    return savedCount;
  }
}

// ==================== DATA MODELS ====================


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
              (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
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
  final List<TransactionModel> recentTransactions;

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
    List<TransactionModel> recent = [];
    if (json['recent_transactions'] != null) {
      recent = (json['recent_transactions'] as List)
          .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    // Parse category breakdown
    Map<String, double> categories = {};
    // Check both top-level and inside summary (for backend compatibility)
    final breakdownSource = json['category_breakdown'] ?? summary?['by_category'];
    
    if (breakdownSource != null) {
      categories = Map<String, double>.from(
        (breakdownSource as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
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
          (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
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
  final List<TransactionModel> transactions;
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
    List<TransactionModel> txns = [];
    if (json['transactions'] != null) {
      txns = (json['transactions'] as List).map((t) {
        if (t is Map<String, dynamic>) {
          return TransactionModel(
            id: t['id'],
            amount: (t['amount'] as num?)?.toDouble() ?? 0,
            description: t['description'] ?? '',
            category: t['category'] ?? 'Other',
            type: t['type'] ?? 'expense',
            date: t['date'] != null ? DateTime.parse(t['date']) : DateTime.now(),
            paymentMethod: t['payment_method'],
            notes: t['notes'],
            receiptUrl: null,
            isRecurring: false,
            createdAt: t['created_at'] != null ? DateTime.parse(t['created_at']) : DateTime.now(),
          );
        }
        return TransactionModel(
          id: null,
          amount: 0,
          description: '',
          category: 'Other',
          type: 'expense',
          date: DateTime.now(),
          paymentMethod: null,
          notes: null,
          receiptUrl: null,
          isRecurring: false,
          createdAt: DateTime.now(),
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
