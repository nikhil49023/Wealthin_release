import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'transaction_categorizer.dart';

/// Database Helper for local SQLite management
/// Handles offline data storage for Transactions, Budgets, and Goals
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wealthin.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from v$oldVersion to v$newVersion');
    
    if (oldVersion < 2) {
      // Add user_streak table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_streak(
          id INTEGER PRIMARY KEY DEFAULT 1,
          current_streak INTEGER DEFAULT 0,
          longest_streak INTEGER DEFAULT 0,
          last_activity_date TEXT,
          total_days_active INTEGER DEFAULT 0
        )
      ''');
      
      // Insert default row if not exists
      final existing = await db.query('user_streak', where: 'id = ?', whereArgs: [1]);
      if (existing.isEmpty) {
        await db.insert('user_streak', {
          'id': 1,
          'current_streak': 0,
          'longest_streak': 0,
          'last_activity_date': null,
          'total_days_active': 0,
        });
      }
      debugPrint('user_streak table created/verified');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS scheduled_payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          due_date TEXT NOT NULL,
          frequency TEXT DEFAULT 'monthly',
          is_autopay INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          reminder_days INTEGER DEFAULT 3,
          notes TEXT
        )
      ''');
    }
  }


  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating Database tables...');
    
    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        paymentMethod TEXT,
        merchant TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Budgets Table (Category based)
    await db.execute('''
      CREATE TABLE budgets(
        category TEXT PRIMARY KEY,
        limit_amount REAL NOT NULL,
        spent_amount REAL DEFAULT 0.0,
        period TEXT DEFAULT 'monthly'
      )
    ''');

    // Goals Table
    await db.execute('''
      CREATE TABLE goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL DEFAULT 0.0,
        deadline TEXT,
        color_hex INTEGER
      )
    ''');

    // Scheduled Payments Table
    await db.execute('''
      CREATE TABLE scheduled_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        due_date TEXT NOT NULL,
        frequency TEXT DEFAULT 'monthly',
        is_autopay INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        reminder_days INTEGER DEFAULT 3,
        notes TEXT
      )
    ''');
    
    // User Streak Table for Daily Engagement
    await db.execute('''
      CREATE TABLE user_streak(
        id INTEGER PRIMARY KEY DEFAULT 1,
        current_streak INTEGER DEFAULT 0,
        longest_streak INTEGER DEFAULT 0,
        last_activity_date TEXT,
        total_days_active INTEGER DEFAULT 0
      )
    ''');
    
    // Insert default streak row
    await db.insert('user_streak', {
      'id': 1,
      'current_streak': 0,
      'longest_streak': 0,
      'last_activity_date': null,
      'total_days_active': 0,
    });
    
    debugPrint('Database tables created successfully');
  }

  // --- Transactions CRUD ---

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await database;
    try {
      // Auto-categorize if category is missing or 'Other'
      var category = row['category'] as String?;
      final description = row['description'] as String;
      final type = (row['type'] as String?)?.toLowerCase() ?? 'expense';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      
      if (category == null || category == 'Other' || category.isEmpty) {
        category = TransactionCategorizer.categorize(description);
      }
      
      final rowToInsert = Map<String, dynamic>.from(row);
      rowToInsert['category'] = category;

      final id = await db.insert('transactions', rowToInsert);
      _updateBudgetSpending(category, amount, type);
      
      // Auto-add savings/investment income to goals
      if (_isSavingsTransaction(type, category, description)) {
        await _autoAddToSavingsGoal(amount);
      }
      
      // Check budget threshold for expense transactions
      if (type == 'expense' || type == 'debit') {
        final alert = await checkBudgetThreshold(category, amount);
        if (alert != null && alert['shouldNotify'] == true) {
          // Store latest alert for UI to display
          _lastBudgetAlert = alert;
          debugPrint('Budget alert: ${alert['message']}');
        }
      }
      
      return id;
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      return -1;
    }
  }
  
  // Stores the last budget alert for UI consumption
  Map<String, dynamic>? _lastBudgetAlert;
  
  /// Get and clear the last budget alert
  Map<String, dynamic>? consumeBudgetAlert() {
    final alert = _lastBudgetAlert;
    _lastBudgetAlert = null;
    return alert;
  }
  
  /// Check if transaction should be auto-added to savings goal
  bool _isSavingsTransaction(String type, String category, String description) {
    final lowerType = type.toLowerCase();
    final lowerCategory = category.toLowerCase();
    final lowerDesc = description.toLowerCase();
    
    // Only income/credit transactions can be savings
    if (lowerType != 'income' && lowerType != 'credit' && lowerType != 'deposit') {
      return false;
    }
    
    // Check category or description for savings keywords
    final savingsKeywords = [
      'saving', 'savings', 'investment', 'invest', 'fd', 'fixed deposit',
      'rd', 'recurring deposit', 'mutual fund', 'mf', 'sip', 'ppf', 'nps',
      'elss', 'deposit', 'interest earned'
    ];
    
    for (final keyword in savingsKeywords) {
      if (lowerCategory.contains(keyword) || lowerDesc.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Auto-add amount to first savings goal or create "General Savings" goal
  Future<void> _autoAddToSavingsGoal(double amount) async {
    final db = await database;
    
    try {
      // Find existing goals
      final goals = await db.query('goals', orderBy: 'id ASC', limit: 1);
      
      if (goals.isNotEmpty) {
        // Add to first goal
        final goalId = goals.first['id'] as int;
        final currentSaved = (goals.first['saved_amount'] as num?)?.toDouble() ?? 0.0;
        
        await db.update(
          'goals',
          {'saved_amount': currentSaved + amount},
          where: 'id = ?',
          whereArgs: [goalId],
        );
        
        debugPrint('Auto-added ₹$amount to goal ID $goalId');
      } else {
        // Create "General Savings" goal with this amount
        await db.insert('goals', {
          'name': 'General Savings',
          'target_amount': 100000.0, // 1 Lakh default target
          'saved_amount': amount,
          'deadline': null,
          'color_hex': 0xFF4CAF50, // Green
        });
        
        debugPrint('Created General Savings goal with ₹$amount');
      }
    } catch (e) {
      debugPrint('Error auto-adding to savings goal: $e');
    }
  }

  // ==================== INCOME VS EXPENSE CATEGORIES ====================
  
  /// Categories for income transactions
  static const List<String> incomeCategories = [
    'Salary',
    'Business',
    'Freelance',
    'Investment',
    'Rental',
    'Dividend',
    'Interest',
    'Gift',
    'Refund',
    'Other Income',
  ];
  
  /// Categories for expense transactions
  static const List<String> expenseCategories = [
    'Food & Dining',
    'Groceries',
    'Shopping',
    'Transport',
    'Entertainment',
    'Bills & Utilities',
    'Health',
    'Education',
    'Rent/Housing',
    'Travel',
    'Subscriptions',
    'Personal Care',
    'Insurance',
    'Transfer',
    'Other',
  ];
  
  /// Get categories by transaction type
  List<String> getCategoriesForType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'income' || lowerType == 'credit' || lowerType == 'deposit') {
      return incomeCategories;
    }
    return expenseCategories;
  }

  // ==================== BUDGET THRESHOLD ALERTS ====================
  
  /// Check if transaction puts budget over 75% threshold
  /// Returns alert info if threshold crossed, null otherwise
  Future<Map<String, dynamic>?> checkBudgetThreshold(String category, double amount) async {
    final db = await database;
    
    try {
      final now = DateTime.now();
      final firstDayOfMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      
      // Get budget for this category
      final budgetRows = await db.query(
        'budgets',
        where: 'LOWER(category) = ?',
        whereArgs: [category.toLowerCase()],
      );
      
      if (budgetRows.isEmpty) return null; // No budget set for this category
      
      final budget = budgetRows.first;
      final limitAmount = (budget['limit_amount'] as num?)?.toDouble() ?? 0;
      
      if (limitAmount <= 0) return null;
      
      // Calculate total spent this month including this transaction
      final spentResult = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total_spent
        FROM transactions
        WHERE LOWER(category) = ? 
          AND LOWER(type) IN ('expense', 'debit')
          AND date >= ?
      ''', [category.toLowerCase(), firstDayOfMonth]);
      
      final previouslySpent = (spentResult.first['total_spent'] as num?)?.toDouble() ?? 0;
      final totalSpent = previouslySpent + amount;
      final percentage = (totalSpent / limitAmount) * 100;
      
      // Check thresholds: 75%, 90%, 100%
      if (percentage >= 75) {
        String alertLevel;
        String message;
        
        if (percentage >= 100) {
          alertLevel = 'critical';
          message = '🔴 Budget exceeded! ₹${totalSpent.toStringAsFixed(0)} of ₹${limitAmount.toStringAsFixed(0)} spent on $category';
        } else if (percentage >= 90) {
          alertLevel = 'warning';
          message = '🟠 Almost out! ${percentage.toStringAsFixed(0)}% of $category budget used';
        } else {
          alertLevel = 'caution';
          message = '🟡 ${percentage.toStringAsFixed(0)}% of $category budget used';
        }
        
        return {
          'category': category,
          'limit': limitAmount,
          'spent': totalSpent,
          'percentage': percentage,
          'alertLevel': alertLevel,
          'message': message,
          'shouldNotify': percentage >= 75, // Trigger notification at 75%+
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('Error checking budget threshold: $e');
      return null;
    }
  }


  Future<List<Map<String, dynamic>>> getTransactions({
    int limit = 50,
    int offset = 0,
    String? category,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (category != null) {
      conditions.add('category = ?');
      whereArgs.add(category);
    }
    if (type != null) {
      conditions.add('type = ?');
      whereArgs.add(type);
    }
    if (startDate != null) {
      conditions.add('date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      conditions.add('date <= ?');
      whereArgs.add(endDate);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }

    return await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    // Logic to reduce budget spending could be added here if needed, 
    // but calculating from scratch is safer for consistency.
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTransaction(Map<String, dynamic> row) async {
    final db = await database;
    try {
      final id = row['id'];
      // TODO: Handle budget adjustment if amount/category changes
      return await db.update('transactions', row, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      return 0;
    }
  }
  
  /// Quick method to update just the category of a transaction
  /// Perfect for manual recategorization of "Other" transactions
  Future<bool> updateTransactionCategory(int id, String newCategory) async {
    final db = await database;
    try {
      final result = await db.update(
        'transactions',
        {'category': newCategory},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (result > 0) {
        debugPrint('Updated transaction $id to category: $newCategory');
        // Trigger budget recalculation
        await recalculateBudgetSpending();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating transaction category: $e');
      return false;
    }
  }

  Future<Map<String, double>> getCategoryBreakdown({String? startDate, String? endDate}) async {
    final db = await database;
    String whereClause = "LOWER(type) IN ('expense', 'debit')";
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause += " AND date >= ?";
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClause += " AND date <= ?";
      whereArgs.add(endDate);
    }

    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM transactions 
      WHERE type IN ('expense', 'debit')
      AND $whereClause
      GROUP BY category
    ''', whereArgs);

    return {
      for (var row in result) 
        row['category'] as String: (row['total'] as num).toDouble()
    };
  }

  Future<List<Map<String, dynamic>>> getDailyCashflow({String? startDate, String? endDate}) async {
    final db = await database;
    String whereClause = "1=1";
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause += " AND date >= ?";
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClause += " AND date <= ?";
      whereArgs.add(endDate);
    }

    return await db.rawQuery('''
      SELECT date, type, SUM(amount) as total
      FROM transactions
      WHERE $whereClause
      GROUP BY date, type
      ORDER BY date
    ''', whereArgs);
  }

  Future<Map<String, dynamic>?> getTransactionSummary({String? startDate, String? endDate}) async {
    final db = await database;
    String whereClause = "1=1";
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause += " AND date >= ?";
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClause += " AND date <= ?";
      whereArgs.add(endDate);
    }

    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN LOWER(type) IN ('income', 'credit', 'deposit') THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN LOWER(type) IN ('expense', 'debit') THEN amount ELSE 0 END) as total_expenses
      FROM transactions
      WHERE $whereClause
    ''', whereArgs);
    
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // --- Budgets ---

  Future<void> _updateBudgetSpending(String category, double amount, String type) async {
    final lowerType = type.toLowerCase();
    if (lowerType != 'expense' && lowerType != 'debit') return; // Only expenses affect budget
    
    final db = await database;
    await db.rawUpdate('''
      UPDATE budgets 
      SET spent_amount = spent_amount + ? 
      WHERE category = ?
    ''', [amount, category]);
  }


  Future<int> createBudget(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('budgets', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateBudget(Map<String, dynamic> row) async {
    final db = await database;
    final category = row['category'];
    return await db.update('budgets', row, where: 'category = ?', whereArgs: [category]);
  }

  Future<int> deleteBudget(String category) async {
    final db = await database;
    return await db.delete('budgets', where: 'category = ?', whereArgs: [category]);
  }
  
  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;
    final now = DateTime.now();
    // Format YYYY-MM-DD for first day of month (e.g., "2026-02-01")
    final firstDayOfMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    // Query budgets and join with current month's transactions
    // We use COALESCE(SUM(amount), 0) to handle categories with no transactions
    // Using LOWER() for case-insensitive category matching
    final result = await db.rawQuery('''
      SELECT 
        b.*, 
        COALESCE(t.spent, 0) as spent_amount
      FROM budgets b
      LEFT JOIN (
        SELECT category, SUM(amount) as spent 
        FROM transactions 
        WHERE LOWER(type) IN ('expense', 'debit') AND date >= ? 
        GROUP BY category
      ) t ON LOWER(b.category) = LOWER(t.category)
    ''', [firstDayOfMonth]);
    
    return result;
  }
  
  /// Generate automated budgets based on historical spending
  /// Analyzes last 3 months of transactions and creates budgets with 20% buffer
  Future<Map<String, dynamic>> generateAutoBudgets({double? monthlyIncome}) async {
    final db = await database;
    
    try {
      // Get spending by category for last 3 months
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final threeMonthsAgoStr = '${threeMonthsAgo.year}-${threeMonthsAgo.month.toString().padLeft(2, '0')}-01';
      
      final spendingByCategory = await db.rawQuery('''
        SELECT 
          category,
          AVG(monthly_total) as avg_monthly_spend,
          COUNT(DISTINCT strftime('%Y-%m', date)) as months_active
        FROM (
          SELECT 
            category,
            strftime('%Y-%m', date) as month,
            SUM(amount) as monthly_total
          FROM transactions
          WHERE LOWER(type) IN ('expense', 'debit') AND date >= ?
          GROUP BY category, strftime('%Y-%m', date)
        )
        GROUP BY category
        HAVING avg_monthly_spend > 0
        ORDER BY avg_monthly_spend DESC
      ''', [threeMonthsAgoStr]);
      
      if (spendingByCategory.isEmpty) {
        return {
          'success': false,
          'message': 'No spending history found. Add some transactions first.',
          'budgets_created': 0,
        };
      }
      
      // Calculate total average monthly spending
      double totalMonthlySpend = 0;
      for (final row in spendingByCategory) {
        totalMonthlySpend += (row['avg_monthly_spend'] as num?)?.toDouble() ?? 0;
      }
      
      // If income is provided, ensure budgets respect 50-30-20 rule
      double budgetMultiplier = 1.2; // 20% buffer by default
      if (monthlyIncome != null && monthlyIncome > 0) {
        final maxSpend = monthlyIncome * 0.8; // 80% for needs + wants (20% savings)
        if (totalMonthlySpend * budgetMultiplier > maxSpend) {
          // Scale down budgets to fit within 80% of income
          budgetMultiplier = maxSpend / totalMonthlySpend;
        }
      }
      
      int budgetsCreated = 0;
      final createdBudgets = <Map<String, dynamic>>[];
      
      for (final row in spendingByCategory) {
        final category = row['category'] as String;
        final avgSpend = (row['avg_monthly_spend'] as num?)?.toDouble() ?? 0;
        
        // Calculate budget limit with buffer
        final budgetLimit = (avgSpend * budgetMultiplier).roundToDouble();
        
        // Skip categories with very small spending
        if (budgetLimit < 100) continue;
        
        // Insert or replace budget
        await db.insert('budgets', {
          'category': category,
          'limit_amount': budgetLimit,
          'spent_amount': 0.0,
          'period': 'monthly',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        
        budgetsCreated++;
        createdBudgets.add({
          'category': category,
          'limit': budgetLimit,
          'avg_spend': avgSpend,
        });
      }
      
      debugPrint('Auto-generated $budgetsCreated budgets');
      
      return {
        'success': true,
        'message': 'Created $budgetsCreated budgets based on your spending history.',
        'budgets_created': budgetsCreated,
        'budgets': createdBudgets,
        'total_monthly_budget': totalMonthlySpend * budgetMultiplier,
      };
    } catch (e) {
      debugPrint('Error generating auto-budgets: $e');
      return {
        'success': false,
        'message': 'Failed to generate budgets: $e',
        'budgets_created': 0,
      };
    }
  }

  // --- Goals ---

  Future<int> createGoal(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('goals', row);
  }

  Future<int> updateGoal(Map<String, dynamic> row) async {
    final db = await database;
    final id = row['id'];
    return await db.update('goals', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getGoals() async {
    final db = await database;
    return await db.query('goals');
  }

  // --- Scheduled Payments ---

  Future<int> createScheduledPayment(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('scheduled_payments', row);
  }

  Future<List<Map<String, dynamic>>> getScheduledPayments() async {
    final db = await database;
    return await db.query('scheduled_payments', orderBy: 'due_date ASC');
  }

  Future<int> updateScheduledPayment(Map<String, dynamic> row) async {
    final db = await database;
    final id = row['id'];
    return await db.update('scheduled_payments', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteScheduledPayment(int id) async {
    final db = await database;
    return await db.delete('scheduled_payments', where: 'id = ?', whereArgs: [id]);
  }

  /// Get current streak data
  Future<Map<String, dynamic>?> getStreak() async {
    final db = await database;
    final result = await db.query('user_streak', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  /// Update streak - call this when user opens app or performs action
  Future<Map<String, dynamic>> updateStreak() async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    // Get current streak data
    final current = await getStreak();
    
    if (current == null) {
      // Initialize if not exists
      await db.insert('user_streak', {
        'id': 1,
        'current_streak': 1,
        'longest_streak': 1,
        'last_activity_date': todayStr,
        'total_days_active': 1,
      });
      return {'current_streak': 1, 'longest_streak': 1, 'total_days_active': 1};
    }
    
    final lastActivityStr = current['last_activity_date'] as String?;
    
    // If already logged today, return current data
    if (lastActivityStr == todayStr) {
      return current;
    }
    
    int currentStreak = current['current_streak'] as int? ?? 0;
    int longestStreak = current['longest_streak'] as int? ?? 0;
    int totalDays = current['total_days_active'] as int? ?? 0;
    
    if (lastActivityStr != null) {
      final lastDate = DateTime.tryParse(lastActivityStr);
      if (lastDate != null) {
        final difference = now.difference(lastDate).inDays;
        
        if (difference == 1) {
          // Consecutive day - increment streak
          currentStreak++;
        } else if (difference > 1) {
          // Streak broken - reset
          currentStreak = 1;
        }
      }
    } else {
      currentStreak = 1;
    }
    
    // Update longest streak if needed
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }
    
    totalDays++;
    
    await db.update('user_streak', {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date': todayStr,
      'total_days_active': totalDays,
    }, where: 'id = ?', whereArgs: [1]);
    
    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_days_active': totalDays,
    };
  }

  /// Recalculate budgets spending from transactions
  Future<void> recalculateBudgetSpending() async {
    final db = await database;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    // Get all categories with their monthly spending
    final spending = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE LOWER(type) IN ('expense', 'debit') AND date >= ?
      GROUP BY category
    ''', [firstDayOfMonth]);
    
    // Update each budget
    for (var row in spending) {
      final category = row['category'] as String?;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (category != null) {
        await db.rawUpdate('''
          UPDATE budgets SET spent_amount = ? WHERE category = ?
        ''', [total, category]);
      }
    }
    
    debugPrint('Budget spending recalculated for ${spending.length} categories');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

/// Global instance
final databaseHelper = DatabaseHelper();
