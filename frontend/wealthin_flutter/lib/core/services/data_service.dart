import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'python_bridge_service.dart';
import 'financial_calculator.dart';
import 'native_pdf_parser.dart';
import '../models/models.dart';

// Typedefs to bridge previous naming mismatch if needed, or just use Models
typedef TransactionData = TransactionModel;
typedef BudgetData = BudgetModel;
typedef GoalData = GoalModel;

/// Data Service - Handles all CRUD operations and analytics
/// Android-only runtime with embedded Python + local SQLite.
class DataService {
  // Singleton pattern
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // Retained for optional cloud API calls where available.
  static const String _baseUrl = 'http://127.0.0.1:8000';
  static const Duration _aiHttpTimeout = Duration(seconds: 8);
  static const Duration _aiBackendCooldown = Duration(seconds: 25);
  static const int _aiBackendFailureThreshold = 2;

  // Android-only app runtime.
  bool get _isAndroid => true;

  int _aiBackendFailureCount = 0;
  DateTime? _aiBackendBlockedUntil;

  static const String _merchantRulesKey = 'merchant_rules_local_v1';
  static const String _savedIdeasKeyPrefix = 'saved_ideas_';
  static const String _savedDprsKeyPrefix = 'saved_dprs_';

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

  Future<List<Map<String, dynamic>>> _readJsonList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error reading local json list for $key: $e');
    }
    return [];
  }

  Future<void> _writeJsonList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  bool _canTryAiBackend() {
    if (!_isAndroid) return true;
    final blockedUntil = _aiBackendBlockedUntil;
    if (blockedUntil == null) return true;
    if (DateTime.now().isAfter(blockedUntil)) {
      _aiBackendBlockedUntil = null;
      _aiBackendFailureCount = 0;
      return true;
    }
    return false;
  }

  void _recordAiBackendSuccess() {
    _aiBackendFailureCount = 0;
    _aiBackendBlockedUntil = null;
  }

  void _recordAiBackendFailure(String operation, Object error) {
    if (!_isAndroid) return;
    _aiBackendFailureCount++;
    debugPrint(
      '[AI Backend][$operation] failure #$_aiBackendFailureCount: $error',
    );
    if (_aiBackendFailureCount >= _aiBackendFailureThreshold) {
      _aiBackendBlockedUntil = DateTime.now().add(_aiBackendCooldown);
      debugPrint(
        '[AI Backend] Entering cooldown for ${_aiBackendCooldown.inSeconds}s',
      );
    }
  }

  Future<http.Response?> _postAiJson(
    String operation,
    String url,
    Map<String, dynamic> payload,
  ) async {
    if (!_canTryAiBackend()) {
      final blockedUntil = _aiBackendBlockedUntil;
      final remainingSeconds = blockedUntil == null
          ? 0
          : blockedUntil.difference(DateTime.now()).inSeconds;
      debugPrint(
        '[AI Backend][$operation] Skipped due cooldown (${remainingSeconds}s remaining)',
      );
      return null;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_aiHttpTimeout);
      debugPrint(
        '[AI Backend][$operation] HTTP ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms',
      );
      if (response.statusCode == 200) {
        _recordAiBackendSuccess();
      } else {
        _recordAiBackendFailure(operation, 'HTTP ${response.statusCode}');
      }
      return response;
    } on TimeoutException catch (e) {
      _recordAiBackendFailure(operation, e);
      return null;
    } catch (e) {
      _recordAiBackendFailure(operation, e);
      return null;
    }
  }

  Future<http.Response?> _getAi(String operation, String url) async {
    if (!_canTryAiBackend()) {
      final blockedUntil = _aiBackendBlockedUntil;
      final remainingSeconds = blockedUntil == null
          ? 0
          : blockedUntil.difference(DateTime.now()).inSeconds;
      debugPrint(
        '[AI Backend][$operation] Skipped due cooldown (${remainingSeconds}s remaining)',
      );
      return null;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(Uri.parse(url)).timeout(_aiHttpTimeout);
      debugPrint(
        '[AI Backend][$operation] HTTP ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms',
      );
      if (response.statusCode == 200) {
        _recordAiBackendSuccess();
      } else {
        _recordAiBackendFailure(operation, 'HTTP ${response.statusCode}');
      }
      return response;
    } on TimeoutException catch (e) {
      _recordAiBackendFailure(operation, e);
      return null;
    } catch (e) {
      _recordAiBackendFailure(operation, e);
      return null;
    }
  }

  Map<String, dynamic>? _extractJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final snippet = raw.substring(start, end + 1);
      try {
        final decoded = jsonDecode(snippet);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  List<Map<String, dynamic>> _extractJsonListOfMaps(
    String raw, {
    String listKey = 'ideas',
  }) {
    List<Map<String, dynamic>> toMapList(dynamic value) {
      if (value is! List) return [];
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return toMapList(decoded);
      }
      if (decoded is Map && decoded[listKey] is List) {
        return toMapList(decoded[listKey]);
      }
    } catch (_) {}

    final blockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
    ).firstMatch(raw);
    if (blockMatch != null) {
      final inner = blockMatch.group(1) ?? '';
      try {
        final decoded = jsonDecode(inner);
        if (decoded is List) return toMapList(decoded);
        if (decoded is Map && decoded[listKey] is List) {
          return toMapList(decoded[listKey]);
        }
      } catch (_) {}
    }

    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start >= 0 && end > start) {
      final snippet = raw.substring(start, end + 1);
      try {
        final decoded = jsonDecode(snippet);
        if (decoded is List) return toMapList(decoded);
      } catch (_) {}
    }

    final map = _extractJsonMap(raw);
    if (map != null && map[listKey] is List) {
      return toMapList(map[listKey]);
    }

    return [];
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

  /// Delete a budget by category
  Future<bool> deleteBudget(String userId, String category) async {
    try {
      final count = await databaseHelper.deleteBudget(category);
      return count > 0;
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      return false;
    }
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
      final updatedBudget = budgets.firstWhere(
        (b) => b['category'] == category,
        orElse: () => {},
      );
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
      final updatedGoal = goals.firstWhere(
        (g) => g['id'] == goalId,
        orElse: () => {},
      );
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
      final currentGoal = goals.firstWhere(
        (g) => g['id'] == goalId,
        orElse: () => {},
      );

      if (currentGoal.isEmpty) return null;

      final currentAmount =
          (currentGoal['saved_amount'] as num?)?.toDouble() ?? 0.0;
      final newAmount = currentAmount + amount;

      final row = {
        'id': goalId,
        'saved_amount': newAmount,
      };

      await databaseHelper.updateGoal(row);

      // Fetch and return updated goal
      final updatedGoals = await databaseHelper.getGoals();
      final updatedGoal = updatedGoals.firstWhere(
        (g) => g['id'] == goalId,
        orElse: () => {},
      );
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
        date:
            DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now(),
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
      final rows = await databaseHelper.getTransactions(
        limit: limit,
        offset: offset,
      );
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

  /// Update transaction category (for manual recategorization)
  Future<bool> updateTransactionCategory(
    int transactionId,
    String newCategory,
  ) async {
    try {
      return await databaseHelper.updateTransactionCategory(
        transactionId,
        newCategory,
      );
    } catch (e) {
      debugPrint('Error updating transaction category: $e');
      return false;
    }
  }

  /// Get spending summary
  Future<SpendingSummary?> getSpendingSummary(
    String userId,
    String startDate,
    String endDate,
  ) async {
    if (_isAndroid) {
      try {
        final summary = await databaseHelper.getTransactionSummary(
          startDate: startDate,
          endDate: endDate,
        );
        final byCategory = await databaseHelper.getCategoryBreakdown(
          startDate: startDate,
          endDate: endDate,
        );
        final income = (summary?['total_income'] as num?)?.toDouble() ?? 0.0;
        final expenses =
            (summary?['total_expenses'] as num?)?.toDouble() ?? 0.0;
        final net = income - expenses;
        return SpendingSummary(
          totalIncome: income,
          totalExpenses: expenses,
          net: net,
          savingsRate: income > 0 ? (net / income) * 100 : 0,
          byCategory: byCategory,
        );
      } catch (e) {
        debugPrint('Error getting local summary: $e');
      }
      return null;
    }

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
    if (_isAndroid) {
      final row = {
        'name': name,
        'amount': amount,
        'category': category,
        'due_date': dueDate,
        'frequency': frequency,
        'is_autopay': isAutopay ? 1 : 0,
        'reminder_days': reminderDays,
        'notes': notes,
        'is_active': 1,
      };

      final id = await databaseHelper.createScheduledPayment(row);
      if (id > 0) {
        return ScheduledPaymentData(
          id: id,
          name: name,
          amount: amount,
          category: category,
          dueDate: dueDate,
          frequency: frequency,
          isAutopay: isAutopay,
          status: 'active',
          reminderDays: reminderDays,
          notes: notes,
        );
      }
      return null;
    }

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
      debugPrint('Error creating scheduled payment: $e');
    }
    return null;
  }

  /// Get all scheduled payments
  Future<List<ScheduledPaymentData>> getScheduledPayments(
    String userId, {
    String? status,
  }) async {
    // On Android, use local database
    if (_isAndroid) {
      final rows = await databaseHelper.getScheduledPayments();
      // TODO: Filter by status if needed (e.g. check is_active)
      return rows.map((row) => ScheduledPaymentData.fromJson(row)).toList();
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
    if (_isAndroid) {
      final updates = <String, dynamic>{'id': paymentId};
      if (name != null) updates['name'] = name;
      if (amount != null) updates['amount'] = amount;
      if (category != null) updates['category'] = category;
      if (frequency != null) updates['frequency'] = frequency;
      if (isAutopay != null) updates['is_autopay'] = isAutopay ? 1 : 0;
      if (reminderDays != null) updates['reminder_days'] = reminderDays;
      if (status != null) updates['is_active'] = status == 'active' ? 1 : 0;
      if (notes != null) updates['notes'] = notes;

      await databaseHelper.updateScheduledPayment(updates);

      // Fetch and return the updated payment to ensure UI refreshes
      final payments = await databaseHelper.getScheduledPayments();
      final payment = payments.firstWhere(
        (p) => p['id'] == paymentId,
        orElse: () => {},
      );
      if (payment.isNotEmpty) {
        return ScheduledPaymentData.fromJson(payment);
      }
      return null;
    }

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
    if (_isAndroid) {
      // Simplified local implementation: Advance due date by 1 month
      // TODO: Implement proper frequency handling and transaction creation
      final payments = await databaseHelper.getScheduledPayments();
      final paymentMap = payments.firstWhere(
        (p) => p['id'] == paymentId,
        orElse: () => {},
      );

      if (paymentMap.isNotEmpty) {
        final currentDue = DateTime.parse(paymentMap['due_date']);
        // Calculate next due date based on frequency
        DateTime nextDue;
        final frequency = (paymentMap['frequency'] as String? ?? 'monthly')
            .toLowerCase();

        switch (frequency) {
          case 'weekly':
            nextDue = currentDue.add(const Duration(days: 7));
            break;
          case 'biweekly':
            nextDue = currentDue.add(const Duration(days: 14));
            break;
          case 'quarterly':
            nextDue = DateTime(
              currentDue.year,
              currentDue.month + 3,
              currentDue.day,
            );
            break;
          case 'yearly':
            nextDue = DateTime(
              currentDue.year + 1,
              currentDue.month,
              currentDue.day,
            );
            break;
          case 'monthly':
          default:
            nextDue = DateTime(
              currentDue.year,
              currentDue.month + 1,
              currentDue.day,
            );
            break;
        }

        final nextDueStr = DateFormat('yyyy-MM-dd').format(nextDue);

        await databaseHelper.updateScheduledPayment({
          'id': paymentId,
          'due_date': nextDueStr,
        });

        // Return updated map as object
        final updatedMap = Map<String, dynamic>.from(paymentMap);
        updatedMap['due_date'] = nextDueStr;
        return ScheduledPaymentData.fromJson(updatedMap);
      }
      return null;
    }

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
    if (_isAndroid) {
      final count = await databaseHelper.deleteScheduledPayment(paymentId);
      return count > 0;
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/scheduled-payments/$userId/$paymentId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting scheduled payment: $e');
      return false;
    }
  }

  /// Get upcoming payments
  Future<List<ScheduledPaymentData>> getUpcomingPayments(
    String userId, {
    int days = 7,
  }) async {
    if (_isAndroid) {
      try {
        final payments = await databaseHelper.getScheduledPayments();
        final now = DateTime.now();
        final maxDate = now.add(Duration(days: days));
        final upcoming = payments.where((p) {
          final dueDateStr = p['due_date']?.toString();
          if (dueDateStr == null || dueDateStr.isEmpty) return false;
          final dueDate = DateTime.tryParse(dueDateStr);
          if (dueDate == null) return false;
          return !dueDate.isBefore(now) && !dueDate.isAfter(maxDate);
        }).toList();
        return upcoming.map((p) => ScheduledPaymentData.fromJson(p)).toList();
      } catch (e) {
        debugPrint('Error getting upcoming payments (Android local): $e');
        return [];
      }
    }

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

  // ==================== MERCHANT RULES (One-Click Flagging) ====================

  /// Get all merchant-category rules
  Future<List<MerchantRule>> getMerchantRules() async {
    if (_isAndroid) {
      final rows = await _readJsonList(_merchantRulesKey);
      return rows.map((r) => MerchantRule.fromJson(r)).toList();
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/merchant-rules'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['rules'] as List)
            .map((r) => MerchantRule.fromJson(r))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting merchant rules: $e');
    }
    return [];
  }

  /// Add a new merchant-category rule
  Future<MerchantRule?> addMerchantRule({
    required String keyword,
    required String category,
    bool isAuto = true,
  }) async {
    if (_isAndroid) {
      final normalizedKeyword = keyword.trim();
      final normalizedCategory = category.trim();
      if (normalizedKeyword.isEmpty || normalizedCategory.isEmpty) return null;

      final existing = await _readJsonList(_merchantRulesKey);
      final lowerKeyword = normalizedKeyword.toLowerCase();

      final index = existing.indexWhere(
        (r) => (r['keyword']?.toString().toLowerCase() ?? '') == lowerKeyword,
      );

      final newRule = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'keyword': normalizedKeyword,
        'category': normalizedCategory,
        'is_auto': isAuto,
      };

      if (index >= 0) {
        existing[index] = {...existing[index], ...newRule};
      } else {
        existing.add(newRule);
      }

      await _writeJsonList(_merchantRulesKey, existing);
      return MerchantRule.fromJson(newRule);
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/merchant-rules'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'keyword': keyword,
          'category': category,
          'is_auto': isAuto,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return MerchantRule.fromJson(data['rule']);
        }
      }
    } catch (e) {
      debugPrint('Error adding merchant rule: $e');
    }
    return null;
  }

  /// Delete a merchant rule
  Future<bool> deleteMerchantRule(int ruleId) async {
    if (_isAndroid) {
      final existing = await _readJsonList(_merchantRulesKey);
      final filtered = existing.where((r) => r['id'] != ruleId).toList();
      await _writeJsonList(_merchantRulesKey, filtered);
      return filtered.length != existing.length;
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/merchant-rules/$ruleId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('Error deleting merchant rule: $e');
    }
    return false;
  }

  /// Seed default merchant rules (for demo)
  Future<bool> seedMerchantRules() async {
    if (_isAndroid) {
      final existing = await _readJsonList(_merchantRulesKey);
      if (existing.isNotEmpty) return true;

      final defaults = <Map<String, dynamic>>[
        {
          'id': DateTime.now().millisecondsSinceEpoch + 1,
          'keyword': 'swiggy',
          'category': 'Food',
          'is_auto': true,
        },
        {
          'id': DateTime.now().millisecondsSinceEpoch + 2,
          'keyword': 'uber',
          'category': 'Transport',
          'is_auto': true,
        },
        {
          'id': DateTime.now().millisecondsSinceEpoch + 3,
          'keyword': 'amazon',
          'category': 'Shopping',
          'is_auto': true,
        },
      ];
      await _writeJsonList(_merchantRulesKey, defaults);
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/merchant-rules/seed'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('Error seeding merchant rules: $e');
    }
    return false;
  }

  // ==================== NCM (National Contribution Milestone) ====================

  /// Get user's NCM score (Viksit Bharat themed)
  Future<NCMScore?> getNCMScore(String userId) async {
    if (_isAndroid) {
      try {
        final dashboard = await getDashboard(userId);
        if (dashboard == null) return null;

        final income = dashboard.totalIncome;
        final expense = dashboard.totalExpense;
        final savingsRate = dashboard.savingsRate.clamp(0, 100).toDouble();
        final spendRatio = income > 0 ? (expense / income).clamp(0, 2) : 1.0;

        final consumptionPoints = ((1.2 - spendRatio) * 25)
            .clamp(0, 25)
            .toDouble();
        final savingsPoints = (savingsRate * 0.45).clamp(0, 45).toDouble();
        final txCount = (await databaseHelper.getTransactions(
          limit: 500,
        )).length;
        final taxPoints = txCount >= 20 ? 15.0 : (txCount / 20) * 15.0;

        final score = (consumptionPoints + savingsPoints + taxPoints)
            .clamp(0, 100)
            .toDouble();

        String milestone = 'Citizen';
        String nextMilestone = 'Contributor';
        if (score >= 80) {
          milestone = 'Nation Builder';
          nextMilestone = 'Legacy Creator';
        } else if (score >= 60) {
          milestone = 'Contributor';
          nextMilestone = 'Nation Builder';
        }

        final progress = score >= 80
            ? ((score - 80) / 20 * 100).clamp(0, 100).toDouble()
            : score >= 60
            ? ((score - 60) / 20 * 100).clamp(0, 100).toDouble()
            : (score / 60 * 100).clamp(0, 100).toDouble();

        return NCMScore(
          score: score,
          milestone: milestone,
          nextMilestone: nextMilestone,
          progress: progress,
          consumptionPoints: consumptionPoints,
          savingsPoints: savingsPoints,
          taxPoints: taxPoints,
        );
      } catch (e) {
        debugPrint('Error getting local NCM score: $e');
        return null;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ncm/score/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NCMScore.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error getting NCM score: $e');
    }
    return null;
  }

  /// Get NCM insight with contextual message
  Future<Map<String, dynamic>?> getNCMInsight(String userId) async {
    if (_isAndroid) {
      final score = await getNCMScore(userId);
      if (score == null) return null;

      String message = 'You are progressing steadily. Keep tracking expenses.';
      if (score.score >= 80) {
        message =
            'Excellent financial discipline. You are in top contributor band.';
      } else if (score.score >= 60) {
        message =
            'Good momentum. Improve savings consistency to reach next milestone.';
      }

      return {
        'score': score.score,
        'milestone': score.milestone,
        'next_milestone': score.nextMilestone,
        'progress': score.progress,
        'message': message,
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ncm/insight/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting NCM insight: $e');
    }
    return null;
  }

  // ==================== INVESTMENT NUDGES (RBI Compliant) ====================

  /// Get personalized investment nudges with Insight Chips
  Future<List<InvestmentNudge>> getInvestmentNudges(String userId) async {
    if (_isAndroid) {
      final surplus = await getSurplusAnalysis(userId);
      final monthlySurplus =
          (surplus?['monthly_surplus'] as num?)?.toDouble() ?? 0.0;
      if (monthlySurplus <= 0) return [];

      final nudgeAmount = (monthlySurplus * 0.3).clamp(500.0, 20000.0);
      final nudgeJson = <Map<String, dynamic>>[
        {
          'id': 'rd_1',
          'title': 'Start a Recurring Deposit',
          'subtitle': 'Low-risk monthly savings habit',
          'amount': nudgeAmount,
          'instrument': 'rd',
          'expected_yield': 6.5,
          'action_text': 'Open bank app',
          'insight_chips': [
            {
              'type': 'surplus',
              'icon': 'savings',
              'label': 'Monthly surplus',
              'value': '₹${monthlySurplus.toStringAsFixed(0)}',
            },
            {
              'type': 'safety',
              'icon': 'shield',
              'label': 'Risk level',
              'value': 'Low',
            },
          ],
        },
      ];
      return nudgeJson.map((n) => InvestmentNudge.fromJson(n)).toList();
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/nudges/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['nudges'] as List<dynamic>?)
                ?.map(
                  (n) => InvestmentNudge.fromJson(n as Map<String, dynamic>),
                )
                .toList() ??
            [];
      }
    } catch (e) {
      debugPrint('Error getting investment nudges: $e');
    }
    return [];
  }

  /// Get surplus analysis for investment planning
  Future<Map<String, dynamic>?> getSurplusAnalysis(String userId) async {
    if (_isAndroid) {
      final dashboard = await getDashboard(userId);
      if (dashboard == null) return null;

      final monthlySurplus = dashboard.totalIncome - dashboard.totalExpense;
      return {
        'monthly_income': dashboard.totalIncome,
        'monthly_expense': dashboard.totalExpense,
        'monthly_surplus': monthlySurplus,
        'surplus_ratio': dashboard.totalIncome > 0
            ? (monthlySurplus / dashboard.totalIncome)
            : 0.0,
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/nudges/surplus/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting surplus analysis: $e');
    }
    return null;
  }

  // ==================== FINANCIAL HEALTH (4-Pillar Score) ====================

  /// Get comprehensive financial health score (0-100) with detailed breakdown
  Future<HealthScore?> getHealthScore(String userId) async {
    if (_isAndroid) {
      try {
        final dashboard = await getDashboard(userId);
        if (dashboard == null) return null;

        final income = dashboard.totalIncome;
        final expense = dashboard.totalExpense;
        final savingsRate = dashboard.savingsRate.clamp(0, 100).toDouble();

        final payments = await getScheduledPayments(userId);
        final monthlyDebt = payments.fold<double>(
          0.0,
          (sum, p) => sum + p.amount,
        );
        final debtRatio = income > 0 ? (monthlyDebt / income) : 1.0;

        final goals = await getGoals(userId);
        double goalTarget = 0;
        double goalSaved = 0;
        for (final g in goals) {
          goalTarget += g.targetAmount;
          goalSaved += g.currentAmount;
        }

        final savingsScore = (savingsRate / 100 * 30).clamp(0, 30).toDouble();
        final debtScore = ((1 - debtRatio).clamp(0, 1) * 25).toDouble();
        final emergencyMonths = expense > 0
            ? (goalSaved / expense).clamp(0, 12)
            : 0.0;
        final liquidityScore = (emergencyMonths / 6 * 25)
            .clamp(0, 25)
            .toDouble();
        final investmentRatio = goalTarget > 0
            ? (goalSaved / goalTarget).clamp(0, 1)
            : 0.0;
        final investmentScore = (investmentRatio * 20).clamp(0, 20).toDouble();

        final total =
            (savingsScore + debtScore + liquidityScore + investmentScore)
                .clamp(0, 100)
                .toDouble();

        String grade = 'Poor';
        if (total >= 80) {
          grade = 'Excellent';
        } else if (total >= 65) {
          grade = 'Good';
        } else if (total >= 45) {
          grade = 'Fair';
        }

        final insights = <String>[];
        if (savingsRate < 20) {
          insights.add(
            'Savings rate is below 20%. Reduce discretionary spending.',
          );
        }
        if (debtRatio > 0.35) {
          insights.add(
            'Debt obligations are high. Prioritize high-interest payments.',
          );
        }
        if (emergencyMonths < 3) {
          insights.add(
            'Build an emergency buffer of at least 3 months expenses.',
          );
        }
        if (insights.isEmpty) {
          insights.add(
            'Financial profile is stable. Maintain current discipline.',
          );
        }

        // Build the base health score
        var healthScore = HealthScore(
          totalScore: total,
          grade: grade,
          breakdown: {
            'savings': savingsScore,
            'debt': debtScore,
            'liquidity': liquidityScore,
            'investment': investmentScore,
          },
          insights: insights,
        );

        // Enrich with AI analysis from Groq (async, non-blocking)
        try {
          // Build category breakdown string
          final budgets = await databaseHelper.getBudgets();
          final goalsData = await databaseHelper.getGoals();
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          final breakdown = await databaseHelper.getCategoryBreakdown(
            startDate: startOfMonth.toIso8601String(),
          );

          String catBreak = breakdown.entries
              .map((e) => '  - ${e.key}: ₹${e.value.toStringAsFixed(0)}')
              .join('\n');

          String budgetStr = budgets.take(5).map((b) {
            String name = b['name']?.toString() ?? b['category']?.toString() ?? 'Unknown';
            double amt = (b['amount'] as num?)?.toDouble() ?? 0;
            double spent = (b['spent'] as num?)?.toDouble() ?? 0;
            return '  - $name: ₹${spent.toStringAsFixed(0)} / ₹${amt.toStringAsFixed(0)}';
          }).join('\n');

          String goalStr = goalsData.take(5).map((g) {
            String name = g['name']?.toString() ?? 'Unknown';
            double target = (g['target_amount'] as num?)?.toDouble() ?? 0;
            double saved = (g['current_amount'] as num?)?.toDouble() ?? 0;
            return '  - $name: ₹${saved.toStringAsFixed(0)} / ₹${target.toStringAsFixed(0)}';
          }).join('\n');

          final aiResult = await pythonBridge.generateAiAnalysis(
            income: income,
            expenses: expense,
            savings: income - expense,
            savingsRate: savingsRate,
            healthScore: total,
            categoryBreakdown: catBreak.isEmpty ? 'No spending data' : catBreak,
            budgetInfo: budgetStr.isEmpty ? 'No budgets set' : budgetStr,
            goalInfo: goalStr.isEmpty ? 'No goals set' : goalStr,
          );

          if (aiResult['success'] == true && aiResult['analysis'] != null) {
            healthScore = healthScore.withAiAnalysis(aiResult['analysis'] as String);
            debugPrint('[HealthScore] AI analysis enriched via ${aiResult['model']}');
          }
        } catch (e) {
          debugPrint('[HealthScore] AI analysis skipped: $e');
          // Non-fatal: score is still valid without AI analysis
        }

        return healthScore;
      } catch (e) {
        debugPrint('Error getting local health score: $e');
        return null;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/health-score/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HealthScore.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error getting health score: $e');
    }
    return null;
  }

  // ==================== DASHBOARD & TRENDS ====================

  /// Get optimized dashboard data from backend with caching
  /// Falls back to local data if backend unavailable
  Future<Map<String, dynamic>?> getDashboardOptimized(String userId) async {
    if (_isAndroid) {
      // Android: use local data only
      debugPrint('Android: Using local dashboard data');
      return null; // Fall through to getDashboard()
    }

    try {
      debugPrint('Fetching optimized dashboard from backend for user $userId');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/dashboard/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('Dashboard fetch successful (cached: ${result['cached']})');
        return result['data'] as Map<String, dynamic>;
      } else {
        debugPrint('Dashboard fetch failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching optimized dashboard: $e');
      return null; // Fall back to local
    }
  }

  Future<DashboardData?> getDashboard(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final sDate = startDate != null
          ? DateFormat('yyyy-MM-dd').format(startDate)
          : null;
      final eDate = endDate != null
          ? DateFormat('yyyy-MM-dd').format(endDate)
          : null;

      // 1. Transaction Summary
      final summary = await databaseHelper.getTransactionSummary(
        startDate: sDate,
        endDate: eDate,
      );
      // Fallback manual calc if summary is null or we need filtering (DatabaseHelper summary doesn't support filter yet)
      // Since we want accuracy, let's allow filtering or accept total lifetime stats for dashboard if dates null

      double income = (summary?['total_income'] as num?)?.toDouble() ?? 0.0;
      double expenses = (summary?['total_expenses'] as num?)?.toDouble() ?? 0.0;

      // 2. Category Breakdown
      final breakdown = await databaseHelper.getCategoryBreakdown(
        startDate: sDate,
        endDate: eDate,
      );

      // 3. Recent Transactions
      final recentRows = await databaseHelper.getTransactions(limit: 5);
      final recent = recentRows
          .map((r) => TransactionModel.fromJson(r))
          .toList();

      // 4. Cashflow
      final cashflowRows = await databaseHelper.getDailyCashflow(
        startDate: sDate,
        endDate: eDate,
      );
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
        cashflow.add(
          CashflowPoint(
            date: d,
            income: inc,
            expense: exp,
            balance: runningBal,
          ),
        );
      }

      // Top Expense
      String? topCat;
      double? topAmt;
      if (breakdown.isNotEmpty) {
        var sorted = breakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
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
      final breakdown = await databaseHelper.getCategoryBreakdown(
        startDate: startDate,
      );

      // Calc totals from transactions in range
      final transactions = await databaseHelper.getTransactions(
        limit: 10000,
        startDate: startDate,
      );
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
        var sorted = breakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
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
          insightText:
              'Start tracking your expenses to get personalized insights.',
          recommendation: 'Add your first transaction to get started.',
          trendIndicator: 'stable',
        );
      }

      // Use Python bridge for analysis
      final txList = transactions
          .map(
            (t) => {
              'description': t['description'] ?? '',
              'amount': t['amount'] ?? 0,
              'category': t['category'] ?? 'Other',
              'date': t['date'] ?? '',
              'type': t['type'] ?? 'expense',
            },
          )
          .toList();

      final analysis = await pythonBridge.analyzeSpending(txList);

      if (analysis['success'] == true) {
        final analyticsData = analysis['analysis'] as Map<String, dynamic>?;
        final savingsRate = analyticsData?['savings_rate'] as num? ?? 0;
        final topCategory =
            analyticsData?['top_category'] as Map<String, dynamic>?;

        if (savingsRate >= 20) {
          return DailyInsight(
            headline: 'Great Savings! 🌟',
            insightText:
                'You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income. Keep it up!',
            recommendation: 'Consider investing your surplus in mutual funds.',
            trendIndicator: 'up',
          );
        } else if (topCategory != null) {
          return DailyInsight(
            headline: 'Top Spending 💡',
            insightText:
                '${topCategory['category']} is your highest expense at ${topCategory['percentage']?.toStringAsFixed(1)}%.',
            recommendation: 'Review this category for potential savings.',
            trendIndicator: 'stable',
            categoryHighlight: topCategory['category'] as String?,
          );
        }
      }

      return DailyInsight(
        headline: 'Track Your Progress 📊',
        insightText: 'Keep adding transactions to get better insights.',
        recommendation:
            'Regular tracking helps you understand spending patterns.',
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
        final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

        // === CURRENT MONTH DATA ===
        final incomeExpense = await databaseHelper.getTransactionSummary(
          startDate: startOfMonth.toIso8601String(),
        );
        final breakdown = await databaseHelper.getCategoryBreakdown(
          startDate: startOfMonth.toIso8601String(),
        );

        double currentIncome =
            (incomeExpense?['total_income'] as num?)?.toDouble() ?? 0;
        double currentExpense =
            (incomeExpense?['total_expenses'] as num?)?.toDouble() ?? 0;
        double currentSavings = currentIncome - currentExpense;
        double savingsRate = currentIncome > 0
            ? (currentSavings / currentIncome * 100)
            : 0;

        // === LAST 3 MONTHS AVERAGE ===
        final threeMonthData = await databaseHelper.getTransactionSummary(
          startDate: threeMonthsAgo.toIso8601String(),
        );
        double avgMonthlyIncome =
            ((threeMonthData?['total_income'] as num?)?.toDouble() ?? 0) / 3;
        double avgMonthlyExpense =
            ((threeMonthData?['total_expenses'] as num?)?.toDouble() ?? 0) / 3;
        double avgMonthlySavings = avgMonthlyIncome - avgMonthlyExpense;

        // === BUDGETS ===
        final budgets = await databaseHelper.getBudgets();
        String budgetInfo = '';
        double totalBudgeted = 0;
        if (budgets.isNotEmpty) {
          for (var b in budgets.take(5)) {
            String name =
                b['name']?.toString() ?? b['category']?.toString() ?? 'Unknown';
            double amount = (b['amount'] as num?)?.toDouble() ?? 0;
            double spent = (b['spent'] as num?)?.toDouble() ?? 0;
            totalBudgeted += amount;
            double pct = amount > 0 ? (spent / amount * 100) : 0;
            budgetInfo +=
                '  - $name: ₹${spent.toStringAsFixed(0)} / ₹${amount.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}% used)\n';
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
            goalInfo +=
                '  - $name: ₹${saved.toStringAsFixed(0)} / ₹${target.toStringAsFixed(0)} (${progress.toStringAsFixed(0)}%)\n';
          }
        }

        // === TOP SPENDING CATEGORIES ===
        var sortedCats = breakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        String topCats = sortedCats
            .take(5)
            .map((e) => "  - ${e.key}: ₹${e.value.toStringAsFixed(0)}")
            .join('\n');

        // === FINANCIAL HEALTH INDICATORS ===
        String financialHealth = 'Needs Attention';
        String emiRecommendation =
            'Consider EMI for expensive purchases to preserve cash flow';

        if (savingsRate >= 30) {
          financialHealth = 'Excellent';
          emiRecommendation =
              'You can afford full cash purchase for most items';
        } else if (savingsRate >= 20) {
          financialHealth = 'Good';
          emiRecommendation =
              'Full cash for items under ₹20,000; EMI for larger purchases';
        } else if (savingsRate >= 10) {
          financialHealth = 'Moderate';
          emiRecommendation = 'EMI recommended for purchases over ₹10,000';
        } else if (savingsRate >= 0) {
          financialHealth = 'Tight Budget';
          emiRecommendation =
              'EMI strongly recommended; avoid large purchases if possible';
        } else {
          financialHealth = 'Deficit (Spending > Income)';
          emiRecommendation = 'Avoid new purchases until budget is balanced';
        }

        // Calculate disposable income (after essential expenses)
        double essentialExpenses =
            (breakdown['Utilities'] ?? 0) +
            (breakdown['Bills'] ?? 0) +
            (breakdown['Food & Dining'] ?? 0) +
            (breakdown['Transportation'] ?? 0);
        double disposableIncome = currentIncome - essentialExpenses;

        // === BUILD COMPREHENSIVE CONTEXT ===
        final context =
            '''
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
        // Use Python bridge to parse PDF and extract transactions
        final result = await pythonBridge.executeTool(
          'parse_bank_statement',
          {'file_path': filePath},
        );

        if (result['success'] == true && result['transactions'] != null) {
          final txs = result['transactions'] as List;
          int imported = 0;
          List<TransactionModel> models = [];

          for (var t in txs) {
            String type = (t['type']?.toString().toLowerCase() ?? 'debit');
            // Normalize type
            if (type.contains('credit') || type.contains('cr'))
              type = 'income';
            else
              type = 'expense';

            final row = {
              'amount': (t['amount'] as num?)?.toDouble() ?? 0.0,
              'description': t['description']?.toString() ?? 'Imported PDF',
              'category': t['category']?.toString() ?? 'Other',
              'date':
                  t['date']?.toString() ??
                  DateFormat('yyyy-MM-dd').format(DateTime.now()),
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
            bankDetected: result['bank_detected']?.toString(),
            message: 'Imported $imported transactions from PDF',
          );
        }
        return ImportResult(
          success: false,
          transactions: [],
          importedCount: 0,
          message: result['error']?.toString() ?? 'Unknown error',
        );
      } catch (e) {
        debugPrint('Error importing PDF (Native): $e');
        return ImportResult(
          success: false,
          transactions: [],
          importedCount: 0,
          message: e.toString(),
        );
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
        return ImportResult(
          success: false,
          transactions: [],
          importedCount: 0,
          message: result['error'] ?? 'Unknown error',
        );
      } catch (e) {
        debugPrint('Error importing Image (Android): $e');
        return ImportResult(
          success: false,
          transactions: [],
          importedCount: 0,
          message: e.toString(),
        );
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

  // ==================== FAMILY GROUPS OPERATIONS ====================

  /// Create a new family group
  Future<Map<String, dynamic>?> createFamilyGroup({
    required String userId,
    required String name,
    String? description,
  }) async {
    if (_isAndroid) {
      // Android: create locally first, then sync later
      try {
        final groupId = await databaseHelper.createGroup(
          name,
          userId,
          description: description,
        );
        return {'id': groupId, 'name': name, 'description': description};
      } catch (e) {
        debugPrint('Error creating local group: $e');
        return null;
      }
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/groups/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'name': name,
              'user_id': userId,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Sync to local SQLite
        await databaseHelper.createGroup(
          name,
          userId,
          description: description,
        );
        return data;
      }
    } catch (e) {
      debugPrint('Error creating family group: $e');
    }
    return null;
  }

  /// Get all family groups for a user
  Future<List<Map<String, dynamic>>> getFamilyGroups(String userId) async {
    if (_isAndroid) {
      // Android: read from local SQLite
      try {
        return await databaseHelper.getUserGroups(userId);
      } catch (e) {
        debugPrint('Error getting local groups: $e');
        return [];
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/groups/list/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final groups =
            (data['groups'] as List?)
                ?.map((g) => g as Map<String, dynamic>)
                .toList() ??
            [];

        // Sync to local SQLite for offline access
        for (var group in groups) {
          try {
            await databaseHelper.createGroup(
              group['name'] as String? ?? '',
              userId,
            );
          } catch (e) {
            // Ignore if already exists
          }
        }

        return groups;
      }
    } catch (e) {
      debugPrint('Error fetching family groups: $e');
      // Fallback to local data
      try {
        return await databaseHelper.getUserGroups(userId);
      } catch (e2) {
        debugPrint('Error getting local groups fallback: $e2');
      }
    }
    return [];
  }

  /// Get members of a specific group
  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    if (_isAndroid) {
      try {
        return await databaseHelper.getGroupMembers(groupId);
      } catch (e) {
        debugPrint('Error getting local group members: $e');
        return [];
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/groups/$groupId/members'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['members'] as List?)
                ?.map((m) => m as Map<String, dynamic>)
                .toList() ??
            [];
      }
    } catch (e) {
      debugPrint('Error fetching group members: $e');
    }
    return [];
  }

  /// Add a member to a group
  Future<bool> addGroupMember({
    required int groupId,
    required String email,
    String role = 'member',
  }) async {
    if (_isAndroid) {
      // Android: persist locally for offline-first behaviour
      return await databaseHelper.addGroupMember(groupId, email, role: role);
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/groups/add-member'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'group_id': groupId,
              'user_id': email,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Keep local copy in sync for offline reads.
        await databaseHelper.addGroupMember(groupId, email, role: role);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding group member: $e');
      return false;
    }
  }

  /// Get group dashboard data (aggregated transactions, budgets, etc.)
  Future<Map<String, dynamic>?> getGroupDashboard({
    required int groupId,
    required String userId,
  }) async {
    if (_isAndroid) {
      debugPrint('Android: Group dashboard not yet implemented locally');
      return null;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/groups/$groupId/dashboard?user_id=$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching group dashboard: $e');
    }
    return null;
  }

  /// Generate an invite link for a group
  Future<String?> generateInviteLink(int groupId) async {
    if (_isAndroid) {
      // Android: use local mock link
      return 'wealthin://join-group/$groupId';
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/groups/$groupId/invite/generate'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['invite_link'] as String?;
      }
    } catch (e) {
      debugPrint('Error generating invite link: $e');
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

        final txList = transactions
            .map(
              (t) => {
                'description': t['description'] ?? '',
                'amount': t['amount'] ?? 0,
                'category': t['category'] ?? 'Other',
                'date': t['date'] ?? '',
              },
            )
            .toList();

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
    double totalIncome,
    int familySize,
  ) async {
    return FinancialCalculator.calculatePerCapitaIncome(
      totalIncome,
      familySize,
    );
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

  // ==================== CASHFLOW FORECASTING ====================

  /// Get cashflow forecast for next N days (30/60/90)
  Future<List<Map<String, dynamic>>> getCashflowForecast(
    String userId, {
    int daysAhead = 90,
  }) async {
    if (_isAndroid) {
      try {
        final txRows = await databaseHelper.getTransactions(limit: 1000);
        final now = DateTime.now();
        final lookbackStart = now.subtract(const Duration(days: 60));

        double totalIncome = 0.0;
        double totalExpense = 0.0;
        for (final row in txRows) {
          final date = DateTime.tryParse(row['date']?.toString() ?? '');
          if (date == null || date.isBefore(lookbackStart)) continue;
          final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
          final type = row['type']?.toString().toLowerCase() ?? 'expense';
          if (type == 'income' || type == 'credit' || type == 'deposit') {
            totalIncome += amount;
          } else {
            totalExpense += amount;
          }
        }

        final dailyNet = (totalIncome - totalExpense) / 60.0;
        final dashboard = await getDashboard(userId);
        double runningBalance = dashboard?.balance ?? 0.0;

        final scheduled = await getScheduledPayments(userId);
        final dueMap = <String, double>{};
        for (final p in scheduled) {
          final due = DateTime.tryParse(p.dueDate);
          if (due == null) continue;
          final key = DateFormat('yyyy-MM-dd').format(
            DateTime(now.year, now.month, due.day),
          );
          dueMap[key] = (dueMap[key] ?? 0.0) + p.amount;
        }

        final projections = <Map<String, dynamic>>[];
        for (int i = 1; i <= daysAhead; i++) {
          final day = now.add(Duration(days: i));
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final scheduledOutflow = dueMap[dateKey] ?? 0.0;

          runningBalance += dailyNet;
          runningBalance -= scheduledOutflow;

          projections.add({
            'date': dateKey,
            'projected_income': dailyNet > 0 ? dailyNet : 0.0,
            'projected_expense': dailyNet < 0 ? dailyNet.abs() : 0.0,
            'scheduled_outflow': scheduledOutflow,
            'balance': runningBalance,
          });
        }
        return projections;
      } catch (e) {
        debugPrint('Error generating local cashflow forecast: $e');
        return [];
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/cashflow/forecast/$userId?days_ahead=$daysAhead',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['projections'] as List?)
                ?.map((p) => p as Map<String, dynamic>)
                .toList() ??
            [];
      }
    } catch (e) {
      debugPrint('Error fetching cashflow forecast: $e');
    }
    return [];
  }

  /// Get business runway (months until cash runs out)
  Future<Map<String, dynamic>?> getRunway(String userId) async {
    if (_isAndroid) {
      try {
        final dashboard = await getDashboard(userId);
        if (dashboard == null) return null;

        final monthlyBurn = dashboard.totalExpense - dashboard.totalIncome;
        if (monthlyBurn <= 0) {
          return {
            'runway_months': 999.0,
            'runway_days': 999 * 30,
            'status': 'safe',
            'recommendation':
                'Cashflow is positive. Continue current discipline.',
            'zero_date': null,
          };
        }

        final goals = await getGoals(userId);
        final availableCash = goals.fold<double>(
          0.0,
          (sum, g) => sum + g.currentAmount,
        );
        final runwayMonths = (availableCash / monthlyBurn).clamp(0, 120);
        final zeroDate = DateTime.now().add(
          Duration(days: (runwayMonths * 30).round()),
        );

        return {
          'runway_months': runwayMonths,
          'runway_days': (runwayMonths * 30).round(),
          'status': runwayMonths >= 6 ? 'stable' : 'risk',
          'recommendation': runwayMonths >= 6
              ? 'Runway is healthy.'
              : 'Reduce burn or increase income to extend runway.',
          'zero_date': zeroDate.toIso8601String(),
        };
      } catch (e) {
        debugPrint('Error calculating local runway: $e');
        return null;
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/cashflow/runway/$userId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'runway_months': data['runway_months'] as double?,
          'runway_days': data['runway_days'] as int?,
          'status': data['status'] as String?,
          'recommendation': data['recommendation'] as String?,
          'zero_date': data['zero_date'] as String?,
        };
      }
    } catch (e) {
      debugPrint('Error fetching runway: $e');
    }
    return null;
  }

  /// Get cash crunch warnings (upcoming low balance dates)
  Future<List<Map<String, dynamic>>> getCashCrunchWarnings(
    String userId, {
    int daysAhead = 90,
  }) async {
    if (_isAndroid) {
      final warnings = <Map<String, dynamic>>[];
      final forecast = await getCashflowForecast(userId, daysAhead: daysAhead);
      for (final row in forecast) {
        final balance = (row['balance'] as num?)?.toDouble() ?? 0.0;
        if (balance < 0) {
          warnings.add({
            'date': row['date'],
            'projected_balance': balance,
            'severity': balance < -10000 ? 'high' : 'medium',
            'message': 'Projected negative balance',
          });
        }
      }
      return warnings;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/cashflow/cash-crunch/$userId?days_ahead=$daysAhead',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['warnings'] as List?)
                ?.map((w) => w as Map<String, dynamic>)
                .toList() ??
            [];
      }
    } catch (e) {
      debugPrint('Error fetching cash crunch warnings: $e');
    }
    return [];
  }

  // ==================== AI BRAINSTORMING ====================

  /// Analyze a business idea with AI-powered market research
  Future<Map<String, dynamic>?> brainstormBusinessIdea({
    required String idea,
    required String userId,
    String? location,
    String? budgetRange,
  }) async {
    // Keep HTTP path only as optional fallback.
    if (!_isAndroid) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/agent/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'query':
                'Analyze this business idea and provide comprehensive market research: $idea',
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
          return data ??
              {
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

  /// OpenAI-powered brainstorming with web search augmentation
  /// Returns response with clickable markdown links
  Future<Map<String, dynamic>?> openAIBrainstorm({
    required String message,
    required String userId,
    List<Map<String, dynamic>> conversationHistory = const [],
    bool enableWebSearch = true,
    String searchCategory = 'general',
  }) async {
    if (_isAndroid) {
      try {
        final result = await pythonBridge.chatWithLLM(
          query: message,
          conversationHistory: conversationHistory
              .map((m) => m.map((k, v) => MapEntry(k, v.toString())))
              .toList(),
          userId: userId,
          userContext: {
            'enable_web_search': enableWebSearch,
            'search_category': searchCategory,
          },
        );
        return {
          'success':
              result['success'] == true || result.containsKey('response'),
          'response': result['response']?.toString() ?? '',
          ...result,
        };
      } catch (e) {
        debugPrint('Android brainstorm failed: $e');
        return null;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/brainstorm/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'message': message,
          'conversation_history': conversationHistory,
          'enable_web_search': enableWebSearch,
          'search_category': searchCategory,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('OpenAI Brainstorm failed: $e');
    }
    return null;
  }

  /// Check if OpenAI brainstorming is available
  Future<bool> isBrainstormAvailable() async {
    if (_isAndroid) {
      return true;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/brainstorm/status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] == true;
      }
    } catch (e) {
      debugPrint('Brainstorm status check failed: $e');
    }
    return false;
  }

  /// Get AI-generated financial news summary (Fin-Bite) from Sarvam
  Future<DailyInsight?> getFinBites({
    String query = 'Indian financial market news today',
  }) async {
    if (_isAndroid) {
      try {
        final result = await pythonBridge.chatWithLLM(
          query:
              'Give one short finance update in JSON with keys: headline, insight, recommendation, trend. Query: $query',
        );
        final response = result['response']?.toString();
        if (response != null && response.isNotEmpty) {
          final parsed = _extractJsonMap(response);
          if (parsed != null) {
            return DailyInsight(
              headline: parsed['headline']?.toString() ?? 'Market Update',
              insightText: parsed['insight']?.toString() ?? '',
              recommendation: parsed['recommendation']?.toString() ?? '',
              trendIndicator: parsed['trend']?.toString() ?? 'stable',
            );
          }

          return DailyInsight(
            headline: 'Market Update',
            insightText: response,
            recommendation: 'Track major expenses and stay diversified.',
            trendIndicator: 'stable',
          );
        }
      } catch (e) {
        debugPrint('Local Fin-Bites generation failed: $e');
      }
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/fin-bites?query=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return DailyInsight(
            headline: data['headline'] ?? 'Market Update',
            insightText: data['insight'] ?? '',
            recommendation: data['recommendation'] ?? '',
            trendIndicator: data['trend'] ?? 'stable',
          );
        }
      }
    } catch (e) {
      debugPrint('Fin-Bites fetch failed: $e');
    }
    return null;
  }

  // ==================== DOCUMENT SCANNING ====================

  /// Scan a receipt image using Python backend
  Future<ReceiptData?> scanReceipt(String filePath) async {
    // On Android: Use Python bridge
    if (_isAndroid) {
      try {
        final result = await pythonBridge.extractReceiptFromPath(filePath);
        if (result['success'] == true) {
          final tx = result['transaction'] as Map<String, dynamic>?;
          if (tx != null) {
            final amount =
                (tx['amount'] as num?)?.toDouble() ??
                double.tryParse(tx['amount']?.toString() ?? '');
            final confidenceRaw = result['confidence'] ?? tx['confidence'];
            final confidence = confidenceRaw is num
                ? (confidenceRaw <= 1 ? confidenceRaw * 100 : confidenceRaw)
                      .toDouble()
                : double.tryParse(confidenceRaw?.toString() ?? '');

            return ReceiptData(
              merchantName:
                  tx['merchant']?.toString() ?? tx['description']?.toString(),
              date: tx['date']?.toString(),
              totalAmount: amount,
              category: tx['category']?.toString(),
              paymentMethod: tx['payment_method']?.toString(),
              confidence: confidence,
            );
          }
          return ReceiptData.fromJson(result);
        }
      } catch (e) {
        debugPrint('Error scanning receipt (Python bridge): $e');
      }
    }

    // Optional HTTP fallback path.
    if (!_isAndroid) {
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
        debugPrint('Error scanning receipt (HTTP backend): $e');
      }
    }

    return null;
  }

  /// Scan a PDF bank statement - returns parsed transactions WITHOUT saving
  /// Use saveTransactions() to persist them after user confirmation
  /// Uses native Dart PDF parser (Syncfusion) - works on all platforms
  Future<List<TransactionModel>> scanBankStatement(String filePath) async {
    debugPrint('Parsing PDF with native Dart parser: $filePath');

    try {
      // Use native Dart PDF parser (works on all platforms)
      final txList = await NativePdfParser.parseStatement(filePath);

      if (txList.isNotEmpty) {
        debugPrint('Native PDF parsed ${txList.length} transactions.');

        return txList
            .map(
              (tx) => TransactionModel(
                id: null,
                date: DateTime.tryParse(tx['date'] ?? '') ?? DateTime.now(),
                description: tx['description'] ?? 'Transaction',
                amount: (tx['amount'] as num?)?.toDouble() ?? 0.0,
                category: tx['category'] ?? 'Other',
                type: tx['type'] ?? 'expense',
                merchant: tx['merchant'],
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Native PDF parsing failed: $e');
    }

    return [];
  }

  /// Batch save multiple transactions to local database
  /// Used after user confirms transactions from confirmation screen
  Future<int> saveTransactions(
    List<TransactionModel> transactions,
    String userId,
  ) async {
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

  // ==================== SOCRATIC DPR TOOLS ====================

  /// Start a Socratic brainstorming session for DPR preparation
  Future<Map<String, dynamic>?> startSocraticSession({
    required String businessIdea,
    String section = 'market_analysis',
  }) async {
    if (_isAndroid) {
      try {
        final result = await pythonBridge.executeTool(
          'start_brainstorming',
          {'business_idea': businessIdea, 'section': section},
        );
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        debugPrint('Socratic session error: $e');
      }
    }
    // Fallback
    return {
      'success': true,
      'session_started': true,
      'business_idea': businessIdea,
      'initial_question': {
        'question':
            'What specific problem does your business solve for customers?',
        'question_type': 'clarification',
        'section': section,
      },
    };
  }

  /// Process a response in the Socratic session
  Future<Map<String, dynamic>?> processSocraticResponse({
    required String response,
    required Map<String, dynamic> questionContext,
  }) async {
    if (_isAndroid) {
      try {
        final result = await pythonBridge.executeTool(
          'process_brainstorm_response',
          {'response': response, 'question_context': questionContext},
        );
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        debugPrint('Socratic response error: $e');
      }
    }
    // Fallback with next question
    return {
      'success': true,
      'answer_quality': 'good',
      'next_question': {
        'question': 'How would you measure success in the first year?',
        'question_type': 'implications',
      },
    };
  }

  /// Generate a DPR from collected data
  Future<Map<String, dynamic>?> generateDPR({
    required Map<String, dynamic> projectData,
  }) async {
    final mode = _normalizeIdeasMode(
      projectData['mode']?.toString() ?? 'msme_copilot',
    );
    final businessIdea =
        projectData['business_idea']?.toString() ??
        projectData['project_name']?.toString() ??
        'Business idea';
    final userData = projectData['user_data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(projectData['user_data'])
        : projectData;
    final canvasItems = projectData['canvas_items'] is List
        ? (projectData['canvas_items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    // On Android, skip HTTP backend — go straight to embedded Python.
    if (!_isAndroid) {
      final backendResponse = await _postAiJson(
        'generate_dpr',
        '$_baseUrl/brainstorm/generate-dpr',
        {
          'business_idea': businessIdea,
          'user_data': userData,
          'canvas_items': canvasItems,
          'mode': mode,
        },
      );
      if (backendResponse != null && backendResponse.statusCode == 200) {
        try {
          return jsonDecode(backendResponse.body) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('[DPR Generation] Invalid backend JSON, falling back: $e');
        }
      }
    }

    if (_isAndroid) {
      try {
        final result = await pythonBridge.executeTool(
          'generate_dpr',
          {'project_data': projectData},
        );
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        debugPrint('DPR generation error: $e');
      }
    }
    // Fallback
    return {
      'success': true,
      'dpr': {
        'metadata': {
          'completeness_pct': 45.0,
          'status': 'Draft - Requires More Data',
        },
        'sections': [],
      },
    };
  }

  Future<Map<String, dynamic>> generateDprFromCanvas({
    required String userId,
    required List<Map<String, dynamic>> canvasItems,
    Map<String, dynamic>? userData,
    String mode = 'msme_copilot',
    String? businessIdea,
  }) async {
    final normalizedMode = _normalizeIdeasMode(mode);
    final payload = {
      'user_id': userId,
      'canvas_items': canvasItems,
      'user_data': userData ?? {},
      'mode': normalizedMode,
      if (businessIdea != null && businessIdea.trim().isNotEmpty)
        'business_idea': businessIdea.trim(),
    };

    // On Android, skip HTTP backend — go straight to embedded Python.
    if (!_isAndroid) {
      final response = await _postAiJson(
        'generate_dpr_canvas',
        '$_baseUrl/brainstorm/generate-dpr-from-canvas',
        payload,
      );
      if (response != null && response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (e) {
          debugPrint(
            '[Canvas DPR] Invalid backend JSON, using local fallback: $e',
          );
        }
      }
    }

    final fallback = await generateDPR(
      projectData: {
        'business_idea':
            businessIdea ??
            (canvasItems.isNotEmpty
                ? canvasItems.first['title']?.toString() ?? 'Business idea'
                : 'Business idea'),
        'user_data': userData ?? {},
        'canvas_items': canvasItems,
        'mode': normalizedMode,
      },
    );
    if (fallback != null) return fallback;
    return {
      'success': false,
      'error': 'DPR generation unavailable',
    };
  }

  /// Get empty DPR template
  Future<Map<String, dynamic>?> getDPRTemplate() async {
    if (_isAndroid) {
      try {
        final result = await pythonBridge.executeTool(
          'get_dpr_template',
          {},
        );
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        debugPrint('DPR template error: $e');
      }
    }
    return null;
  }

  /// Run What-If scenario analysis
  Future<Map<String, dynamic>?> runWhatIfAnalysis({
    required double baseRevenue,
    required double operatingCosts,
    required double debtService,
  }) async {
    if (_isAndroid) {
      try {
        final result = await pythonBridge.executeTool(
          'run_scenario_comparison',
          {
            'base_case': {
              'revenue': baseRevenue,
              'operating_costs': operatingCosts,
              'debt_service': debtService,
            },
          },
        );
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        debugPrint('What-If analysis error: $e');
      }
    }
    // Fallback
    return {
      'success': true,
      'scenarios': {
        'base': {'revenue': baseRevenue, 'dscr': 1.8},
        'optimistic': {'revenue': baseRevenue * 1.2, 'dscr': 2.5},
        'conservative': {'revenue': baseRevenue * 0.85, 'dscr': 1.2},
      },
    };
  }

  // ==================== GAMIFICATION & MILESTONES ====================

  /// Save analysis snapshot and check for milestone achievements
  Future<Map<String, dynamic>> saveAnalysisSnapshot({
    required String userId,
    required double totalIncome,
    required double totalExpense,
    required double savingsRate,
    required double healthScore,
    required Map<String, double> categoryBreakdown,
    List<String> insights = const [],
    int transactionCount = 0,
    int budgetCount = 0,
    int goalsCompleted = 0,
    int currentStreak = 0,
    int underBudgetMonths = 0,
  }) async {
    if (_isAndroid) {
      debugPrint("[Analysis] Android: snapshot saved locally");
      return {
        "success": true,
        "snapshot_id": "local_${DateTime.now().millisecondsSinceEpoch}",
        "newly_achieved_milestones": <Map<String, dynamic>>[],
        "user_level": 1,
        "total_xp": 0,
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analysis/save-snapshot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'total_income': totalIncome,
          'total_expense': totalExpense,
          'savings_rate': savingsRate,
          'health_score': healthScore,
          'category_breakdown': categoryBreakdown,
          'insights': insights,
          'transaction_count': transactionCount,
          'budget_count': budgetCount,
          'goals_completed': goalsCompleted,
          'current_streak': currentStreak,
          'under_budget_months': underBudgetMonths,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[Analysis] Save snapshot error: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Analysis] Save snapshot exception: $e');
    }
    return {
      "success": false,
      "newly_achieved_milestones": <Map<String, dynamic>>[],
    };
  }

  /// Get GPT-OSS powered AI insights for the Analysis tab
  Future<Map<String, dynamic>> getAiAnalysisInsights(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/ai-insights/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[Analysis] AI insights error: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Analysis] AI insights exception: $e');
    }
    return {'success': false, 'insights': ''};
  }

  /// Get milestones and XP progress for a user
  Future<Map<String, dynamic>> getMilestones(String userId) async {
    final fallback = {
      "success": true,
      "milestones": <Map<String, dynamic>>[],
      "level": 1,
      "total_xp": 0,
      "xp_to_next_level": 100,
      "milestones_achieved": 0,
      "total_milestones": 14,
    };

    if (_isAndroid) return fallback;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analysis/milestones/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Milestones] Error: $e');
    }
    return fallback;
  }

  /// Get historical analysis snapshots
  Future<List<Map<String, dynamic>>> getAnalysisHistory(
    String userId, {
    int months = 6,
  }) async {
    if (_isAndroid) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analysis/history/$userId?months=$months'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
    } catch (e) {
      debugPrint('[Analysis History] Error: $e');
    }
    return [];
  }

  /// Get monthly financial metrics history
  Future<List<Map<String, dynamic>>> getMetricsHistory(
    String userId, {
    int months = 12,
  }) async {
    if (_isAndroid) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/metrics/history/$userId?months=$months'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['metrics'] ?? []);
      }
    } catch (e) {
      debugPrint('[Metrics History] Error: $e');
    }
    return [];
  }

  // ==================== IDEA EVALUATION (OPENAI) ====================

  /// Evaluate a business idea using OpenAI backend
  Future<Map<String, dynamic>?> evaluateIdea({
    required String userId,
    required String idea,
    String location = "India",
    String budgetRange = "5-10 Lakhs",
    Map<String, dynamic>? userContext,
  }) async {
    if (_isAndroid) {
      try {
        final prompt =
            'Evaluate this business idea for India and respond in strict JSON with keys: '
            'score (0-100), viability (Low|Medium|High), summary, '
            'market_analysis {market_size, target_audience}, '
            'financial_projection {initial_investment, break_even_timeline}, '
            'swot {strengths[], weaknesses[]}, recommendations[], revenue_models[]. '
            'Idea: $idea. Location: $location. Budget: $budgetRange.';

        final ai = await pythonBridge.chatWithLLM(
          query: prompt,
          userId: userId,
          userContext: userContext ?? {},
        );

        final responseText = ai['response']?.toString() ?? '';
        final parsed = _extractJsonMap(responseText);

        Map<String, dynamic> evaluation =
            parsed ??
            {
              'score': 70,
              'summary': responseText.isNotEmpty
                  ? responseText
                  : 'Idea captured. Run deeper analysis for more precision.',
              'viability': 'Medium',
              'market_analysis': {
                'market_size': 'Moderate and growing segment',
                'target_audience': 'Indian consumers and SMBs',
              },
              'financial_projection': {
                'initial_investment': budgetRange,
                'break_even_timeline': '12-18 months',
              },
              'swot': {
                'strengths': <String>['Solves a real user problem'],
                'weaknesses': <String>['Execution complexity depends on team'],
              },
              'recommendations': <String>[
                'Validate with 10-20 potential users',
                'Start with an MVP and measurable milestones',
                'Track CAC, retention, and conversion from day one',
              ],
              'revenue_models': <String>['Subscription', 'Transaction fee'],
            };

        final score = (evaluation['score'] as num?)?.toInt() ?? 70;
        final viability = score >= 80
            ? 'High'
            : score >= 60
            ? 'Medium'
            : 'Low';
        evaluation['viability'] = evaluation['viability'] ?? viability;

        final key = '$_savedIdeasKeyPrefix$userId';
        final saved = await _readJsonList(key);
        saved.insert(0, {
          'id': 'idea_${DateTime.now().millisecondsSinceEpoch}',
          'idea_text': idea,
          'score': score,
          'viability': evaluation['viability'],
          'summary': evaluation['summary']?.toString() ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'evaluation': evaluation,
        });
        if (saved.length > 100) {
          saved.removeRange(100, saved.length);
        }
        await _writeJsonList(key, saved);

        return evaluation;
      } catch (e) {
        debugPrint('[Idea Evaluation] Android error: $e');
        return null;
      }
    }

    final response = await _postAiJson(
      'evaluate_idea',
      '$_baseUrl/ideas/evaluate',
      {
        'user_id': userId,
        'idea': idea,
        'location': location,
        'budget_range': budgetRange,
        'user_context': userContext ?? {},
      },
    );

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['evaluation'] as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('[Idea Evaluation] Invalid backend JSON: $e');
      }
    }
    return null;
  }

  /// Get saved idea evaluations for a user
  Future<List<Map<String, dynamic>>> getSavedIdeas(
    String userId, {
    int limit = 10,
  }) async {
    if (_isAndroid) {
      final key = '$_savedIdeasKeyPrefix$userId';
      final saved = await _readJsonList(key);
      return saved.take(limit).toList();
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ideas/$userId?limit=$limit'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['ideas'] ?? []);
      }
    } catch (e) {
      debugPrint('[Saved Ideas] Error: $e');
    }
    return [];
  }

  // ==================== ENHANCED BRAINSTORMING CANVAS ====================

  String _brainstormPersonaPrompt(String persona) {
    switch (persona) {
      case 'cynical_vc':
        return 'You are a skeptical VC. Prioritize unit economics, moat, execution risks, and brutal realism.';
      case 'enthusiastic_entrepreneur':
        return 'You are a creative entrepreneur. Generate bold, practical opportunities and growth loops.';
      case 'risk_manager':
        return 'You are a risk manager. Emphasize legal, compliance, downside control, and contingency plans.';
      case 'customer_advocate':
        return 'You are a customer advocate. Focus on user pain, adoption friction, and clear value delivery.';
      case 'financial_analyst':
        return 'You are a financial analyst. Quantify assumptions, cashflow impact, and break-even sensitivity.';
      case 'systems_thinker':
        return 'You are a systems thinker. Highlight second-order effects, dependencies, and ecosystem dynamics.';
      default:
        return 'You are a neutral strategy consultant. Be concise, practical, and outcome-focused.';
    }
  }

  String _brainstormWorkflowPrompt(String workflowMode) {
    switch (workflowMode) {
      case 'refinery':
        return 'Workflow: REFINERY. Critique ideas, find weak links, challenge assumptions, and propose stronger alternatives.';
      case 'anchor':
        return 'Workflow: ANCHOR. Extract only high-signal, actionable ideas that should be pinned to a canvas.';
      default:
        return 'Workflow: INPUT. Expand, clarify, and structure raw ideas into actionable directions.';
    }
  }

  String _normalizeIdeasMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    if (normalized == 'msme_copilot' ||
        normalized == 'strategic_planner' ||
        normalized == 'financial_architect' ||
        normalized == 'execution_coach' ||
        normalized == 'market_research' ||
        normalized == 'financial_planner' ||
        normalized == 'career_advisor' ||
        normalized == 'investment_analyst' ||
        normalized == 'life_planning') {
      return 'msme_copilot';
    }
    return 'msme_copilot';
  }

  String _brainstormAnalysisModePrompt(String mode) {
    _normalizeIdeasMode(mode);
    return 'Analysis Mode: MSME Copilot. Combine market validation, financial viability, execution roadmap, and legal/compliance readiness in one clear answer.';
  }

  List<Map<String, dynamic>> _fallbackBrainstormModes() {
    return const [
      {
        'id': 'msme_copilot',
        'label': 'MSME Copilot',
        'description': 'Unified strategy, finance, execution, and compliance guidance.',
      },
    ];
  }

  String _formatConversationSnippet(
    List<Map<String, dynamic>>? conversationHistory, {
    int maxTurns = 12,
  }) {
    final history = conversationHistory ?? const <Map<String, dynamic>>[];
    if (history.isEmpty) return 'No prior conversation.';
    final start = history.length > maxTurns ? history.length - maxTurns : 0;
    return history
        .sublist(start)
        .map((m) {
          final role = m['role']?.toString() ?? 'user';
          final content = m['content']?.toString().trim() ?? '';
          if (content.isEmpty) return '';
          return '$role: $content';
        })
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  List<Map<String, String>> _toStringHistory(
    List<Map<String, dynamic>>? conversationHistory,
  ) {
    return (conversationHistory ?? const <Map<String, dynamic>>[])
        .map(
          (m) => <String, String>{
            'role': m['role']?.toString() ?? 'user',
            'content': m['content']?.toString() ?? '',
          },
        )
        .where((m) => (m['content'] ?? '').trim().isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getBrainstormModes() async {
    // On Android, skip HTTP — no backend server running, use fallback modes.
    if (!_isAndroid) {
      try {
        final response = await _getAi(
          'brainstorm_modes',
          '$_baseUrl/brainstorm/modes',
        );
        if (response != null && response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['modes'] is List) {
            final parsed = <Map<String, dynamic>>[];
            for (final raw in (data['modes'] as List)) {
              if (raw is! Map) continue;
              final item = Map<String, dynamic>.from(raw);
              final key = item['id']?.toString() ?? item['key']?.toString() ?? '';
              if (key.isEmpty) continue;
              parsed.add({
                'id': key,
                'label': item['label']?.toString() ?? key,
                'description':
                    item['description']?.toString() ??
                    item['focus']?.toString() ??
                    '',
                'category': item['category']?.toString() ?? 'general',
              });
            }
            if (parsed.isNotEmpty) return parsed;
          }
        }
      } catch (e) {
        debugPrint('[Brainstorm Modes] Using fallback modes: $e');
      }
    }
    return _fallbackBrainstormModes();
  }

  Future<Map<String, dynamic>> brainstormChat({
    required String userId,
    required String message,
    List<Map<String, dynamic>>? conversationHistory,
    Map<String, dynamic>? userProfile,
    String persona = 'neutral',
    String mode = 'msme_copilot',
    String workflowMode = 'input',
    bool enableWebSearch = true,
    String? userLocation,
  }) async {
    final normalizedMode = _normalizeIdeasMode(mode);
    final normalizedWorkflow = workflowMode.trim().toLowerCase();

    // On Android, skip HTTP backend — go straight to embedded Python.
    if (!_isAndroid) {
      final backendResponse = await _postAiJson(
        'brainstorm_chat',
        '$_baseUrl/brainstorm/chat',
        {
          'user_id': userId,
          'message': message,
          'conversation_history': conversationHistory ?? [],
          'persona': persona,
          'mode': normalizedMode,
          'workflow_mode': normalizedWorkflow,
          'enable_web_search': enableWebSearch,
          'user_profile': userProfile ?? {},
          if (userLocation != null) 'user_location': userLocation,
        },
      );
      if (backendResponse != null && backendResponse.statusCode == 200) {
        try {
          return jsonDecode(backendResponse.body);
        } catch (e) {
          debugPrint('[Brainstorm Chat] Invalid backend JSON, falling back: $e');
        }
      }
    }

    // Android: Use embedded Python via MethodChannel
    if (_isAndroid) {
      try {
        // Build financial context from user profile if available
        final financialCtx = StringBuffer();
        if (userProfile != null) {
          if (userProfile.containsKey('monthly_income')) {
            financialCtx.writeln('User monthly income: ₹${userProfile['monthly_income']}');
          }
          if (userProfile.containsKey('monthly_expenses')) {
            financialCtx.writeln('User monthly expenses: ₹${userProfile['monthly_expenses']}');
          }
          if (userProfile.containsKey('savings_rate')) {
            financialCtx.writeln('Savings rate: ${userProfile['savings_rate']}');
          }
          if (userProfile.containsKey('top_spending') && userProfile['top_spending'] is List) {
            financialCtx.writeln('Top spending: ${(userProfile['top_spending'] as List).join(', ')}');
          }
          if (userProfile.containsKey('location')) {
            financialCtx.writeln('User Location/State: ${userProfile['location']}');
          }
          if (userProfile.containsKey('business_sector')) {
            financialCtx.writeln('Business Sector: ${userProfile['business_sector']}');
          }
          if (userProfile.containsKey('business_stage')) {
            financialCtx.writeln('Business Stage: ${userProfile['business_stage']}');
          }
          if (userProfile.containsKey('location_type')) {
            financialCtx.writeln('Location Type: ${userProfile['location_type']}');
          }
        }

        // Build location context
        final locationCtx = StringBuffer();
        final effectiveLocation = userLocation ?? userProfile?['location']?.toString() ?? '';
        if (effectiveLocation.isNotEmpty) {
          locationCtx.writeln('\n📍 USER LOCATION: $effectiveLocation');
          locationCtx.writeln('Use this to provide state-wise government MSME data, local supplier recommendations, and competition analysis.');
          locationCtx.writeln('Search across the ENTIRE state for the best options, not just nearby.');
        }

        // Determine language preference
        final preferredLang = userProfile?['preferred_language']?.toString() ?? 'English';
        final langInstruction = preferredLang != 'English'
            ? '\n\n🗣️ LANGUAGE: Respond in **$preferredLang**. Use $preferredLang script naturally. For technical/financial terms, write the $preferredLang word first, then the English term in brackets. Example: "मुद्रा योजना (MUDRA Scheme)".'
            : '';

        final prompt =
            '''You are WealthIn MSME Copilot — a friendly, patient, and deeply knowledgeable business mentor for Indian founders, especially first-time entrepreneurs.

## YOUR PERSONALITY
- Think of yourself as a supportive elder brother/sister who has built businesses in India
- You explain things simply — assume the user may be a first-time founder who doesn't know business jargon
- When you use a technical term, ALWAYS explain it in simple words in parentheses. Example: "DPR (Detailed Project Report — a document banks need to give you a loan)"
- Be warm, encouraging, and practical. Many users may feel intimidated by business planning — make them feel confident.
$langInstruction

## YOUR EXPERTISE
- **Scheme-Savvy**: PMMY/MUDRA (government gives loans up to ₹10L without guarantee), PMEGP (government pays 15-35% of your project cost!), CGTMSE (no property needed for loans up to ₹5Cr), PM Vishwakarma, NULM, NRLM, MSE-GIFT, GST Sahay
- **Supply Chain Thinker**: For ANY business idea, walk through: Where to buy raw materials → How to make the product → How to package it → How to deliver it → How to find customers
- **State-Wise**: Know what works best in each Indian state
- **Honest but Encouraging**: Share risks clearly, but always end with what the user CAN do right now

${_brainstormWorkflowPrompt(normalizedWorkflow)}
${_brainstormPersonaPrompt(persona)}

${enableWebSearch ? 'IMPORTANT: Use web_search tool to find real market data, competitor info, government scheme details, or industry statistics relevant to the user\'s idea.' : ''}

${financialCtx.isNotEmpty ? 'User Financial Context:\n$financialCtx' : ''}
${locationCtx.isNotEmpty ? '$locationCtx' : 'NOTE: User has not set their location. Ask for their state naturally — it helps you provide real government MSME data.'}

Conversation context:
${_formatConversationSnippet(conversationHistory, maxTurns: 10)}

User message:
$message

## RESPONSE FORMATTING RULES (VERY IMPORTANT):

### ❌ NEVER USE MARKDOWN TABLES
Tables are unreadable on mobile phones. NEVER use | header | header | format.

### ✅ USE VISUAL ROADMAPS FOR STEPS
When showing a process, plan, or timeline, use this visual roadmap format:

**🗺️ Your Roadmap**

🔵 **Step 1: [Title]**
[1-2 line explanation in simple language]

⬇️

🟢 **Step 2: [Title]**
[1-2 line explanation]

⬇️

🟡 **Step 3: [Title]**
[1-2 line explanation]

⬇️

🎯 **Final Goal: [What you achieve]**

### ✅ USE COMPARISON CARDS (NOT TABLES) FOR COMPARING OPTIONS
When comparing schemes, loans, or options, use this card format:

> **💰 Option 1: MUDRA Loan**
> • How much: Up to ₹10 lakh
> • Who can apply: Any Indian citizen, 18+ years
> • Best for: Small shops, food business, services
> • Time to get: 2-4 weeks

> **🏭 Option 2: PMEGP**
> • How much: Up to ₹50 lakh (₹1 Cr for manufacturing)
> • Government pays: 15-35% of total cost!
> • Who can apply: 8th pass, 18+ years
> • Best for: Manufacturing, food processing

### ✅ USE SIMPLE BULLET LISTS FOR INFORMATION
- Use bullet points with emojis for quick scanning
- Bold the key numbers and names
- Keep sentences short (max 15 words per point)

### TONE
- Write like a mentor talking to a founder over chai ☕
- Use **bold** for key points
- Explain ALL jargon in simple words using parentheses
- End with **🎯 Next Steps** — 2-3 specific things to do TODAY
- Be warm, practical, and encouraging
''';

        final result = await pythonBridge.chatWithLLM(
          query: prompt,
          userId: userId,
          conversationHistory: _toStringHistory(conversationHistory),
          userContext: {
            'mode': normalizedMode,
            'workflow_mode': normalizedWorkflow,
            'persona': persona,
            'enable_web_search': enableWebSearch,
            if (userLocation != null) 'user_location': userLocation,
          },
        );
        if (result['success'] == true || result.containsKey('response')) {
          return {
            'success': true,
            'content': result['response'] ?? result['content'] ?? '',
            'persona': persona,
            'mode': normalizedMode,
            'workflow_mode': normalizedWorkflow,
            'visualization': {
              'mode': normalizedMode,
              'workflow_mode': normalizedWorkflow,
            },
            ...result,
          };
        }
        return {'success': false, 'error': result['error'] ?? 'No AI response'};
      } catch (e) {
        debugPrint('[Brainstorm Chat] Android error: $e');
        return {'success': false, 'error': e.toString()};
      }
    }

    return {'success': false, 'error': 'Brainstorm chat unavailable'};
  }

  Future<Map<String, dynamic>> reverseBrainstorm({
    required List<String> ideas,
    List<Map<String, dynamic>>? conversationHistory,
    String mode = 'msme_copilot',
  }) async {
    final normalizedMode = _normalizeIdeasMode(mode);

    // On Android, skip HTTP backend — go straight to embedded Python.
    if (!_isAndroid) {
      final backendResponse = await _postAiJson(
        'reverse_brainstorm',
        '$_baseUrl/brainstorm/critique',
        {
          'ideas': ideas,
          'conversation_history': conversationHistory ?? [],
          'mode': normalizedMode,
          'workflow_mode': 'refinery',
        },
      );
      if (backendResponse != null && backendResponse.statusCode == 200) {
        try {
          return jsonDecode(backendResponse.body);
        } catch (e) {
          debugPrint(
            '[Reverse Brainstorm] Invalid backend JSON, falling back: $e',
          );
        }
      }
    }

    // Android: Use embedded Python chat with critique prompt
    if (_isAndroid) {
      try {
        final critiquePrompt =
            '''
${_brainstormWorkflowPrompt('refinery')}
${_brainstormAnalysisModePrompt(normalizedMode)}
${_brainstormPersonaPrompt('cynical_vc')}

Ideas to critique:
${ideas.map((i) => '- $i').join('\n')}

Recent context:
${_formatConversationSnippet(conversationHistory, maxTurns: 12)}

Return concise markdown with sections:
- Fatal flaws
- Weak assumptions
- Risk score (1-10) with reason
- Salvage plan (3 concrete fixes)
''';

        final result = await pythonBridge.chatWithLLM(
          query: critiquePrompt,
          conversationHistory: _toStringHistory(conversationHistory),
          userContext: {
            'mode': normalizedMode,
            'workflow_mode': 'refinery',
            'persona': 'cynical_vc',
          },
        );
        if (result['success'] == true || result.containsKey('response')) {
          return {
            'success': true,
            'critique': result['response'] ?? '',
            'mode': normalizedMode,
            'workflow_mode': 'refinery',
            ...result,
          };
        }
        return {
          'success': false,
          'error': result['error'] ?? 'No critique response',
        };
      } catch (e) {
        debugPrint('[Reverse Brainstorm] Android error: $e');
        return {'success': false, 'error': e.toString()};
      }
    }

    return {'success': false, 'error': 'Critique unavailable'};
  }

  Future<Map<String, dynamic>> extractCanvasItems({
    required List<Map<String, dynamic>> conversationHistory,
    String mode = 'msme_copilot',
  }) async {
    final normalizedMode = _normalizeIdeasMode(mode);

    // On Android, skip HTTP backend — go straight to embedded Python.
    if (!_isAndroid) {
      final backendResponse = await _postAiJson(
        'extract_canvas',
        '$_baseUrl/brainstorm/extract-canvas',
        {
          'conversation_history': conversationHistory,
          'mode': normalizedMode,
          'workflow_mode': 'anchor',
        },
      );
      if (backendResponse != null && backendResponse.statusCode == 200) {
        try {
          return jsonDecode(backendResponse.body);
        } catch (e) {
          debugPrint('[Extract Canvas] Invalid backend JSON, falling back: $e');
        }
      }
    }

    // Android: Use embedded Python chat to extract ideas
    if (_isAndroid) {
      try {
        final extractPrompt =
            '''
${_brainstormWorkflowPrompt('anchor')}
${_brainstormAnalysisModePrompt(normalizedMode)}
Extract the most important surviving ideas and action items from this conversation.
Return STRICT JSON only in this shape:
{
  "ideas": [
    {"title": "short title", "content": "what to do", "category": "feature|risk|opportunity|insight"}
  ]
}

Conversation:
${_formatConversationSnippet(conversationHistory, maxTurns: 18)}
''';

        final result = await pythonBridge.chatWithLLM(
          query: extractPrompt,
          conversationHistory: _toStringHistory(conversationHistory),
          userContext: {
            'mode': normalizedMode,
            'workflow_mode': 'anchor',
            'persona': 'neutral',
          },
        );
        if (result['success'] == true || result.containsKey('response')) {
          final responseText = result['response']?.toString() ?? '';
          final parsedIdeas = _extractJsonListOfMaps(
            responseText,
            listKey: 'ideas',
          );
          final allowed = {'feature', 'risk', 'opportunity', 'insight'};

          final ideas = parsedIdeas
              .map((idea) {
                final title = idea['title']?.toString().trim() ?? '';
                final content = idea['content']?.toString().trim() ?? '';
                final rawCategory =
                    idea['category']?.toString().toLowerCase().trim() ??
                    'insight';
                final category = allowed.contains(rawCategory)
                    ? rawCategory
                    : 'insight';
                return {
                  'title': title,
                  'content': content,
                  'category': category,
                };
              })
              .where((idea) => (idea['title'] ?? '').isNotEmpty)
              .toList();

          if (ideas.isEmpty && responseText.isNotEmpty) {
            final fallbackLines = responseText
                .split('\n')
                .map((line) => line.trim())
                .where(
                  (line) =>
                      line.isNotEmpty &&
                      !line.startsWith('```') &&
                      !line.startsWith('{') &&
                      !line.startsWith('['),
                )
                .take(5);
            for (final line in fallbackLines) {
              final clean = line.replaceFirst(
                RegExp(r'^[-*•\d\.\)\s]+'),
                '',
              );
              if (clean.length < 12) continue;
              ideas.add({
                'title': clean.length > 56
                    ? '${clean.substring(0, 56)}...'
                    : clean,
                'content': clean,
                'category': 'insight',
              });
            }
          }

          return {
            'success': true,
            'ideas': ideas,
            'response': responseText,
            'mode': normalizedMode,
            'workflow_mode': 'anchor',
            ...result,
          };
        }
        return {
          'success': false,
          'error': result['error'] ?? 'No extraction result',
          'ideas': [],
        };
      } catch (e) {
        debugPrint('[Extract Canvas] Android error: $e');
        return {'success': false, 'error': e.toString(), 'ideas': []};
      }
    }

    return {
      'success': false,
      'error': 'Canvas extraction unavailable',
      'ideas': [],
    };
  }

  // ==================== DPR MANAGEMENT ====================

  /// Save a DPR document
  Future<String?> saveDPR({
    required String userId,
    required String businessIdea,
    required Map<String, dynamic> sections,
    double completeness = 0.0,
    Map<String, dynamic>? researchData,
    Map<String, dynamic>? financialProjections,
  }) async {
    if (_isAndroid) {
      try {
        final key = '$_savedDprsKeyPrefix$userId';
        final saved = await _readJsonList(key);
        final id = 'dpr_${DateTime.now().millisecondsSinceEpoch}';
        saved.insert(0, {
          'id': id,
          'user_id': userId,
          'business_idea': businessIdea,
          'sections': sections,
          'completeness': completeness,
          'research_data': researchData ?? {},
          'financial_projections': financialProjections ?? {},
          'created_at': DateTime.now().toIso8601String(),
        });
        if (saved.length > 100) {
          saved.removeRange(100, saved.length);
        }
        await _writeJsonList(key, saved);
        return id;
      } catch (e) {
        debugPrint('[DPR Save] Android error: $e');
        return null;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/dpr/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'business_idea': businessIdea,
          'sections': sections,
          'completeness': completeness,
          'research_data': researchData ?? {},
          'financial_projections': financialProjections ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['dpr_id'] as String?;
      }
    } catch (e) {
      debugPrint('[DPR Save] Error: $e');
    }
    return null;
  }

  /// Get saved DPR documents
  Future<List<Map<String, dynamic>>> getSavedDPRs(
    String userId, {
    int limit = 10,
  }) async {
    if (_isAndroid) {
      final key = '$_savedDprsKeyPrefix$userId';
      final saved = await _readJsonList(key);
      return saved.take(limit).toList();
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/dpr/$userId?limit=$limit'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['dprs'] ?? []);
      }
    } catch (e) {
      debugPrint('[Saved DPRs] Error: $e');
    }
    return [];
  }

  // ==================== BUDGET AUTO-SYNC ON IMPORT ====================

  /// After importing transactions, auto-create budgets for new categories
  /// and recalculate spending for existing budgets
  Future<Map<String, dynamic>> autoCategorizeAndSyncBudgets({
    required String userId,
    required List<TransactionData> transactions,
  }) async {
    try {
      // Collect expense categories from imported transactions
      final categories = <String>{};
      for (final tx in transactions) {
        final type = tx.type.toLowerCase();
        if (type == 'expense' || type == 'debit') {
          categories.add(tx.category);
        }
      }

      // Load existing budgets
      final existingBudgets = await getBudgets(userId);
      final existingCategories = {
        for (final b in existingBudgets) b.category.toLowerCase(),
      };

      int newBudgetsCreated = 0;
      // Create missing budgets automatically
      for (final category in categories) {
        if (!existingCategories.contains(category.toLowerCase())) {
          // Estimate budget based on imported spending in this category
          double categorySpending = 0;
          for (final tx in transactions) {
            if (tx.category.toLowerCase() == category.toLowerCase() &&
                (tx.type.toLowerCase() == 'expense' ||
                    tx.type.toLowerCase() == 'debit')) {
              categorySpending += tx.amount;
            }
          }
          // Set budget at 130% of observed spending (20% buffer + 10% for variance)
          final budgetAmount = (categorySpending * 1.3).clamp(1000.0, 500000.0);

          await createBudget(
            userId: userId,
            name: category,
            amount: budgetAmount,
            category: category,
          );
          newBudgetsCreated++;
        }
      }

      // Recalculate all budget spending from transactions
      await databaseHelper.recalculateBudgetSpending();

      return {
        "success": true,
        "categories_synced": categories.length,
        "new_budgets_created": newBudgetsCreated,
      };
    } catch (e) {
      debugPrint('[AutoSync] Error: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  // ==================== MUDRA DPR ====================

  /// Calculate full Mudra DPR from user inputs
  Future<Map<String, dynamic>?> calculateMudraDPR({
    required Map<String, dynamic> inputs,
  }) async {
    try {
      if (_isAndroid) {
        return await pythonBridge.calculateMudraDPR(inputs);
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/mudra-dpr/calculate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(inputs),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Mudra DPR Calculate] Error: $e');
    }
    return null;
  }

  /// Run what-if simulation with overrides
  Future<Map<String, dynamic>?> whatIfSimulate({
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> overrides,
  }) async {
    try {
      if (_isAndroid) {
        return await pythonBridge.whatIfSimulate(inputs, overrides);
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/mudra-dpr/whatif'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'inputs': inputs, 'overrides': overrides}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Mudra DPR What-If] Error: $e');
    }
    return null;
  }

  /// Get cluster suggestions
  Future<List<Map<String, dynamic>>> getClusterSuggestions({
    required String city,
    required String state,
    String businessType = '',
  }) async {
    try {
      if (_isAndroid) {
        return await pythonBridge.getClusterSuggestions(
          city: city,
          state: state,
          businessType: businessType,
        );
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/mudra-dpr/clusters'),
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
    } catch (e) {
      debugPrint('[Cluster Suggestions] Error: $e');
    }
    return [];
  }

  /// Save Mudra DPR to backend
  Future<String?> saveMudraDPR({
    required String userId,
    required Map<String, dynamic> dprData,
  }) async {
    try {
      if (_isAndroid) {
        return await pythonBridge.saveMudraDPR(
          userId: userId,
          dprData: dprData,
        );
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/mudra-dpr/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, ...dprData}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] as String?;
      }
    } catch (e) {
      debugPrint('[Mudra DPR Save] Error: $e');
    }
    return null;
  }

  /// Get saved Mudra DPRs
  Future<List<Map<String, dynamic>>> getMudraDPRs(String userId) async {
    try {
      if (_isAndroid) {
        return await pythonBridge.getMudraDPRs(userId);
      }
      final response = await http.get(
        Uri.parse('$_baseUrl/mudra-dpr/$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['dprs'] ?? []);
      }
    } catch (e) {
      debugPrint('[Mudra DPRs] Error: $e');
    }
    return [];
  }

  /// Get recurring transactions analysis
  Future<Map<String, dynamic>> getRecurringTransactions(String userId) async {
    if (_isAndroid) {
      try {
        final txRows = await databaseHelper.getTransactions(limit: 300);
        final txList = txRows
            .map(
              (t) => {
                'description': t['description'] ?? '',
                'amount': t['amount'] ?? 0,
                'date': t['date'] ?? '',
                'category': t['category'] ?? 'Other',
                'merchant': t['merchant'] ?? t['description'] ?? '',
              },
            )
            .toList();

        final result = await pythonBridge.detectSubscriptions(txList);
        if (result['success'] == true) {
          final items = <Map<String, dynamic>>[
            ...List<Map<String, dynamic>>.from(result['subscriptions'] ?? []),
            ...List<Map<String, dynamic>>.from(
              result['recurring_habits'] ?? [],
            ),
          ];
          return {
            'status': 'success',
            'recurring_count': items.length,
            'estimated_monthly_bills':
                (result['total_monthly_cost'] as num?)?.toDouble() ?? 0.0,
            'items': items,
          };
        }
      } catch (e) {
        debugPrint('Error getting recurring transactions (Android): $e');
      }
      return {
        'status': 'success',
        'recurring_count': 0,
        'estimated_monthly_bills': 0.0,
        'items': [],
      };
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/recurring/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting recurring transactions: $e');
    }

    return {};
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
    this.userId = '', // Optional - not stored in local DB
    required this.name,
    required this.amount,
    required this.category,
    this.frequency = 'monthly',
    required this.dueDate,
    String? nextDueDate, // Optional - derived from dueDate if not provided
    this.isAutopay = false,
    this.status = 'active', // Default active
    this.reminderDays = 3,
    this.lastPaidDate,
    this.notes,
    String? createdAt, // Optional - default to now
    String? updatedAt, // Optional - default to now
  }) : nextDueDate = nextDueDate ?? dueDate,
       createdAt = createdAt ?? DateTime.now().toIso8601String(),
       updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  factory ScheduledPaymentData.fromJson(Map<String, dynamic> json) {
    // Handle local DB format (is_active as int) vs API format (status as string)
    String status = 'active';
    if (json['status'] != null) {
      status = json['status'].toString();
    } else if (json['is_active'] != null) {
      status = (json['is_active'] == 1 || json['is_active'] == true)
          ? 'active'
          : 'paused';
    }

    // Handle is_autopay as int or bool
    bool isAutopay = false;
    if (json['is_autopay'] != null) {
      isAutopay = json['is_autopay'] == 1 || json['is_autopay'] == true;
    }

    return ScheduledPaymentData(
      id: json['id'],
      userId: json['user_id']?.toString() ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] ?? '',
      frequency: json['frequency'] ?? 'monthly',
      dueDate: json['due_date'] ?? '',
      nextDueDate: json['next_due_date'] ?? json['due_date'] ?? '',
      isAutopay: isAutopay,
      status: status,
      reminderDays: json['reminder_days'] ?? 3,
      lastPaidDate: json['last_paid_date'],
      notes: json['notes'],
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] ?? DateTime.now().toIso8601String(),
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
    final breakdownSource =
        json['category_breakdown'] ?? summary?['by_category'];

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
      var sortedEntries = categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sortedEntries.isNotEmpty) {
        topCat = sortedEntries.first.key;
        topAmt = sortedEntries.first.value;
      }
    }

    return DashboardData(
      totalIncome:
          (json['total_income'] ?? summary?['total_income'] as num?)
              ?.toDouble() ??
          0,
      totalExpense:
          (json['total_expense'] ?? summary?['total_expenses'] as num?)
              ?.toDouble() ??
          0,
      balance: (json['balance'] ?? summary?['net'] as num?)?.toDouble() ?? 0,
      savingsRate:
          (json['savings_rate'] ?? summary?['savings_rate'] as num?)
              ?.toDouble() ??
          0,
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
      trendIndicator:
          json['trendIndicator'] ?? json['trend_indicator'] ?? 'stable',
      categoryHighlight:
          json['categoryHighlight'] ?? json['category_highlight'],
      amountHighlight:
          (json['amountHighlight'] ?? json['amount_highlight'] as num?)
              ?.toDouble(),
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
            date: t['date'] != null
                ? DateTime.parse(t['date'])
                : DateTime.now(),
            paymentMethod: t['payment_method'],
            notes: t['notes'],
            receiptUrl: null,
            isRecurring: false,
            createdAt: t['created_at'] != null
                ? DateTime.parse(t['created_at'])
                : DateTime.now(),
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
