import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'transaction_categorizer.dart';
import '../constants/categories.dart';

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
      version: 8,
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
      final existing = await db.query(
        'user_streak',
        where: 'id = ?',
        whereArgs: [1],
      );
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

    if (oldVersion < 4) {
      // Normalize legacy category names in transactions
      await db.execute(
        "UPDATE transactions SET category = 'Transportation' WHERE LOWER(category) = 'transport'",
      );
      await db.execute(
        "UPDATE transactions SET category = 'Utilities' WHERE LOWER(category) IN ('bills', 'bills & utilities')",
      );
      await db.execute(
        "UPDATE transactions SET category = 'Healthcare' WHERE LOWER(category) IN ('health', 'medical')",
      );
      await db.execute(
        "UPDATE transactions SET category = 'Rent & Housing' WHERE LOWER(category) IN ('rent/housing', 'rent', 'housing')",
      );

      // Normalize legacy category names in budgets
      await db.execute(
        "UPDATE budgets SET category = 'Transportation' WHERE LOWER(category) = 'transport'",
      );
      await db.execute(
        "UPDATE budgets SET category = 'Utilities' WHERE LOWER(category) IN ('bills', 'bills & utilities')",
      );
      await db.execute(
        "UPDATE budgets SET category = 'Healthcare' WHERE LOWER(category) IN ('health', 'medical')",
      );
      await db.execute(
        "UPDATE budgets SET category = 'Rent & Housing' WHERE LOWER(category) IN ('rent/housing', 'rent', 'housing')",
      );

      debugPrint('Migrated legacy category names to canonical names (v4)');
    }

    if (oldVersion < 5) {
      // Add Brainstorming/Ideas canvas tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS brainstorm_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          persona TEXT DEFAULT 'neutral',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_archived INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS brainstorm_messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          persona TEXT,
          is_critique INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (session_id) REFERENCES brainstorm_sessions(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS brainstorm_canvas_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT DEFAULT 'idea',
          position_x REAL DEFAULT 0,
          position_y REAL DEFAULT 0,
          color_hex INTEGER,
          created_at TEXT NOT NULL,
          FOREIGN KEY (session_id) REFERENCES brainstorm_sessions(id) ON DELETE CASCADE
        )
      ''');

      debugPrint('Created brainstorming canvas tables (v5)');
    }

    if (oldVersion < 6) {
      // Local family groups support for offline Android mode
      await db.execute('''
        CREATE TABLE IF NOT EXISTS groups(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          created_by TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_members(
          group_id INTEGER NOT NULL,
          user_id TEXT NOT NULL,
          role TEXT DEFAULT 'member',
          joined_at TEXT NOT NULL,
          PRIMARY KEY (group_id, user_id),
          FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
        )
      ''');

      debugPrint('Created family group tables (v6)');
    }

    if (oldVersion < 7) {
      // Add SMS-parsed fields to transactions for balance tracking
      await db.execute('ALTER TABLE transactions ADD COLUMN balance REAL');
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN account_last4 TEXT',
      );
      await db.execute('ALTER TABLE transactions ADD COLUMN bank TEXT');

      debugPrint(
        'Added balance/account_last4/bank columns to transactions (v7)',
      );
    }

    if (oldVersion < 8) {
      // UPI ID -> Contact name mapping cache for humanized transaction labels
      await db.execute('''
        CREATE TABLE IF NOT EXISTS upi_contact_mappings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          upi_id TEXT NOT NULL,
          upi_key TEXT NOT NULL UNIQUE,
          contact_name TEXT NOT NULL,
          source TEXT DEFAULT 'manual',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      debugPrint('Created upi_contact_mappings table (v8)');
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
        is_synced INTEGER DEFAULT 0,
        balance REAL,
        account_last4 TEXT,
        bank TEXT
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

    // Brainstorming Sessions Table
    await db.execute('''
      CREATE TABLE brainstorm_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        persona TEXT DEFAULT 'neutral',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_archived INTEGER DEFAULT 0
      )
    ''');

    // Brainstorming Messages Table (Chat history)
    await db.execute('''
      CREATE TABLE brainstorm_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        persona TEXT,
        is_critique INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES brainstorm_sessions(id) ON DELETE CASCADE
      )
    ''');

    // Brainstorming Canvas Items (Anchored ideas)
    await db.execute('''
      CREATE TABLE brainstorm_canvas_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT DEFAULT 'idea',
        position_x REAL DEFAULT 0,
        position_y REAL DEFAULT 0,
        color_hex INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES brainstorm_sessions(id) ON DELETE CASCADE
      )
    ''');

    // UPI Contact Mapping Table
    await db.execute('''
      CREATE TABLE upi_contact_mappings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        upi_id TEXT NOT NULL,
        upi_key TEXT NOT NULL UNIQUE,
        contact_name TEXT NOT NULL,
        source TEXT DEFAULT 'manual',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Family Groups Table
    await db.execute('''
      CREATE TABLE groups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Family Group Members Table
    await db.execute('''
      CREATE TABLE group_members(
        group_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT DEFAULT 'member',
        joined_at TEXT NOT NULL,
        PRIMARY KEY (group_id, user_id),
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )
    ''');

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
      category = Categories.normalize(category);

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
    if (lowerType != 'income' &&
        lowerType != 'credit' &&
        lowerType != 'deposit') {
      return false;
    }

    // Check category or description for savings keywords
    final savingsKeywords = [
      'saving',
      'savings',
      'investment',
      'invest',
      'fd',
      'fixed deposit',
      'rd',
      'recurring deposit',
      'mutual fund',
      'mf',
      'sip',
      'ppf',
      'nps',
      'elss',
      'deposit',
      'interest earned',
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
        final currentSaved =
            (goals.first['saved_amount'] as num?)?.toDouble() ?? 0.0;

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

  /// Categories for income transactions (delegates to Categories)
  static List<String> get incomeCategories => Categories.income;

  /// Categories for expense transactions (delegates to Categories)
  static List<String> get expenseCategories => Categories.expense;

  /// Get categories by transaction type
  List<String> getCategoriesForType(String type) {
    return Categories.getForType(type);
  }

  // ==================== BUDGET THRESHOLD ALERTS ====================

  /// Check if transaction puts budget over 75% threshold
  /// Returns alert info if threshold crossed, null otherwise
  Future<Map<String, dynamic>?> checkBudgetThreshold(
    String category,
    double amount,
  ) async {
    final db = await database;

    try {
      final now = DateTime.now();
      final firstDayOfMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

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
      final spentResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) as total_spent
        FROM transactions
        WHERE LOWER(category) = ? 
          AND LOWER(type) IN ('expense', 'debit')
          AND date >= ?
      ''',
        [category.toLowerCase(), firstDayOfMonth],
      );

      final previouslySpent =
          (spentResult.first['total_spent'] as num?)?.toDouble() ?? 0;
      final totalSpent = previouslySpent + amount;
      final percentage = (totalSpent / limitAmount) * 100;

      // Check thresholds: 75%, 90%, 100%
      if (percentage >= 75) {
        String alertLevel;
        String message;

        if (percentage >= 100) {
          alertLevel = 'critical';
          message =
              '🔴 Budget exceeded! ₹${totalSpent.toStringAsFixed(0)} of ₹${limitAmount.toStringAsFixed(0)} spent on $category';
        } else if (percentage >= 90) {
          alertLevel = 'warning';
          message =
              '🟠 Almost out! ${percentage.toStringAsFixed(0)}% of $category budget used';
        } else {
          alertLevel = 'caution';
          message =
              '🟡 ${percentage.toStringAsFixed(0)}% of $category budget used';
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
      return await db.update(
        'transactions',
        row,
        where: 'id = ?',
        whereArgs: [id],
      );
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

  Future<Map<String, double>> getCategoryBreakdown({
    String? startDate,
    String? endDate,
  }) async {
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
        row['category'] as String: (row['total'] as num).toDouble(),
    };
  }

  /// Get transactions for a specific category (for budget details view)
  Future<List<Map<String, dynamic>>> getTransactionsByCategory(
    String category, {
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;
    List<String> conditions = ['LOWER(category) = LOWER(?)'];
    List<dynamic> whereArgs = [category];

    // Default to current month if no dates provided
    if (startDate == null) {
      final now = DateTime.now();
      startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    }
    conditions.add('date >= ?');
    whereArgs.add(startDate);

    if (endDate != null) {
      conditions.add('date <= ?');
      whereArgs.add(endDate);
    }

    final whereClause = conditions.join(' AND ');

    return await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  /// Get savings-related transactions (for goals screen)
  Future<List<Map<String, dynamic>>> getSavingsTransactions({
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    // Keywords that indicate savings/investment transactions
    final savingsKeywords = [
      'saving',
      'savings',
      'investment',
      'invest',
      'fd',
      'fixed deposit',
      'rd',
      'recurring deposit',
      'mutual fund',
      'mf',
      'sip',
      'ppf',
      'nps',
      'elss',
      'deposit',
      'interest earned',
      'dividend',
    ];

    // Build LIKE conditions for each keyword
    final likeConditions = savingsKeywords
        .map(
          (kw) =>
              "(LOWER(description) LIKE '%$kw%' OR LOWER(category) LIKE '%$kw%')",
        )
        .join(' OR ');

    String whereClause =
        "LOWER(type) IN ('income', 'credit', 'deposit') AND ($likeConditions)";
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += " AND date >= ?";
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClause += " AND date <= ?";
      whereArgs.add(endDate);
    }

    return await db.rawQuery(
      '''
      SELECT * FROM transactions
      WHERE $whereClause
      ORDER BY date DESC
      LIMIT ?
    ''',
      [...whereArgs, limit],
    );
  }

  /// Get income transactions (for goals screen income section)
  Future<List<Map<String, dynamic>>> getIncomeTransactions({
    int limit = 10,
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    String whereClause = "LOWER(type) IN ('income', 'credit', 'deposit')";
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += " AND date >= ?";
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      whereClause += " AND date <= ?";
      whereArgs.add(endDate);
    }

    return await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getDailyCashflow({
    String? startDate,
    String? endDate,
  }) async {
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

  Future<Map<String, dynamic>?> getTransactionSummary({
    String? startDate,
    String? endDate,
  }) async {
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

  Future<void> _updateBudgetSpending(
    String category,
    double amount,
    String type,
  ) async {
    final lowerType = type.toLowerCase();
    if (lowerType != 'expense' && lowerType != 'debit') {
      return; // Only expenses affect budget
    }

    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE budgets
      SET spent_amount = spent_amount + ?
      WHERE LOWER(category) = LOWER(?)
    ''',
      [amount, category],
    );
  }

  Future<int> createBudget(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'budgets',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateBudget(Map<String, dynamic> row) async {
    final db = await database;
    final category = row['category'];
    return await db.update(
      'budgets',
      row,
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  Future<int> deleteBudget(String category) async {
    final db = await database;
    return await db.delete(
      'budgets',
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;
    final now = DateTime.now();
    // Format YYYY-MM-DD for first day of month (e.g., "2026-02-01")
    final firstDayOfMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    // Query budgets and join with current month's transactions
    // We use COALESCE(SUM(amount), 0) to handle categories with no transactions
    // Using LOWER() for case-insensitive category matching
    final result = await db.rawQuery(
      '''
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
    ''',
      [firstDayOfMonth],
    );

    return result;
  }

  /// Generate automated budgets based on historical spending
  /// Analyzes last 3 months of transactions and creates budgets with 20% buffer
  Future<Map<String, dynamic>> generateAutoBudgets({
    double? monthlyIncome,
  }) async {
    final db = await database;

    try {
      // Get spending by category for last 3 months
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final threeMonthsAgoStr =
          '${threeMonthsAgo.year}-${threeMonthsAgo.month.toString().padLeft(2, '0')}-01';

      final spendingByCategory = await db.rawQuery(
        '''
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
      ''',
        [threeMonthsAgoStr],
      );

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
        totalMonthlySpend +=
            (row['avg_monthly_spend'] as num?)?.toDouble() ?? 0;
      }

      // If income is provided, ensure budgets respect 50-30-20 rule
      double budgetMultiplier = 1.2; // 20% buffer by default
      if (monthlyIncome != null && monthlyIncome > 0) {
        final maxSpend =
            monthlyIncome * 0.8; // 80% for needs + wants (20% savings)
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
        'message':
            'Created $budgetsCreated budgets based on your spending history.',
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

  // --- Family Groups ---

  Future<int> createGroup(
    String name,
    String userId, {
    String? description,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.transaction<int>((txn) async {
      final groupId = await txn.insert('groups', {
        'name': name,
        'description': description,
        'created_by': userId,
        'created_at': now,
      });

      await txn.insert('group_members', {
        'group_id': groupId,
        'user_id': userId,
        'role': 'admin',
        'joined_at': now,
      });

      return groupId;
    });
  }

  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT
        g.id,
        g.name,
        g.description,
        g.created_by,
        g.created_at,
        gm.role,
        COUNT(gm2.user_id) as member_count
      FROM groups g
      JOIN group_members gm ON g.id = gm.group_id
      LEFT JOIN group_members gm2 ON g.id = gm2.group_id
      WHERE gm.user_id = ?
      GROUP BY g.id, g.name, g.description, g.created_by, g.created_at, gm.role
      ORDER BY g.created_at DESC
    ''',
      [userId],
    );
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    final db = await database;
    return await db.query(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'joined_at ASC',
    );
  }

  Future<bool> addGroupMember(
    int groupId,
    String userId, {
    String role = 'member',
  }) async {
    final db = await database;
    try {
      await db.insert(
        'group_members',
        {
          'group_id': groupId,
          'user_id': userId,
          'role': role,
          'joined_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    } catch (e) {
      debugPrint('Error adding group member: $e');
      return false;
    }
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
    return await db.update(
      'scheduled_payments',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteScheduledPayment(int id) async {
    final db = await database;
    return await db.delete(
      'scheduled_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get current streak data
  Future<Map<String, dynamic>?> getStreak() async {
    final db = await database;
    final result = await db.query(
      'user_streak',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  /// Update streak - call this when user opens app or performs action
  Future<Map<String, dynamic>> updateStreak() async {
    final db = await database;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

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

    await db.update(
      'user_streak',
      {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_activity_date': todayStr,
        'total_days_active': totalDays,
      },
      where: 'id = ?',
      whereArgs: [1],
    );

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
    final spending = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE LOWER(type) IN ('expense', 'debit') AND date >= ?
      GROUP BY category
    ''',
      [firstDayOfMonth],
    );

    // Update each budget
    for (var row in spending) {
      final category = row['category'] as String?;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (category != null) {
        await db.rawUpdate(
          '''
          UPDATE budgets SET spent_amount = ? WHERE LOWER(category) = LOWER(?)
        ''',
          [total, category],
        );
      }
    }

    debugPrint(
      'Budget spending recalculated for ${spending.length} categories',
    );
  }

  // --- Brainstorming Sessions CRUD ---

  Future<int> createBrainstormSession(
    String title, {
    String persona = 'neutral',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('brainstorm_sessions', {
      'title': title,
      'persona': persona,
      'created_at': now,
      'updated_at': now,
      'is_archived': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getBrainstormSessions({
    bool includeArchived = false,
  }) async {
    final db = await database;
    final whereClause = includeArchived ? null : 'is_archived = ?';
    final whereArgs = includeArchived ? null : [0];
    return await db.query(
      'brainstorm_sessions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getBrainstormSession(int sessionId) async {
    final db = await database;
    final results = await db.query(
      'brainstorm_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateBrainstormSession(
    int sessionId, {
    String? title,
    String? persona,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (persona != null) updates['persona'] = persona;

    await db.update(
      'brainstorm_sessions',
      updates,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> archiveBrainstormSession(int sessionId) async {
    final db = await database;
    await db.update(
      'brainstorm_sessions',
      {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteBrainstormSession(int sessionId) async {
    final db = await database;
    // Foreign key constraints will cascade delete messages and canvas items
    await db.delete(
      'brainstorm_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // --- Brainstorming Messages CRUD ---

  Future<int> addBrainstormMessage({
    required int sessionId,
    required String role,
    required String content,
    String? persona,
    bool isCritique = false,
  }) async {
    final db = await database;
    final messageId = await db.insert('brainstorm_messages', {
      'session_id': sessionId,
      'role': role,
      'content': content,
      'persona': persona,
      'is_critique': isCritique ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update session's updated_at timestamp
    await db.update(
      'brainstorm_sessions',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    return messageId;
  }

  Future<List<Map<String, dynamic>>> getBrainstormMessages(
    int sessionId,
  ) async {
    final db = await database;
    return await db.query(
      'brainstorm_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deleteBrainstormMessage(int messageId) async {
    final db = await database;
    await db.delete(
      'brainstorm_messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> clearBrainstormMessages(int sessionId) async {
    final db = await database;
    await db.delete(
      'brainstorm_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // --- Brainstorming Canvas Items CRUD ---

  Future<int> addCanvasItem({
    required int sessionId,
    required String title,
    required String content,
    String category = 'idea',
    double positionX = 0,
    double positionY = 0,
    int? colorHex,
  }) async {
    final db = await database;
    return await db.insert('brainstorm_canvas_items', {
      'session_id': sessionId,
      'title': title,
      'content': content,
      'category': category,
      'position_x': positionX,
      'position_y': positionY,
      'color_hex': colorHex,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getCanvasItems(int sessionId) async {
    final db = await database;
    return await db.query(
      'brainstorm_canvas_items',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> updateCanvasItem(
    int itemId, {
    String? title,
    String? content,
    String? category,
    double? positionX,
    double? positionY,
    int? colorHex,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (category != null) updates['category'] = category;
    if (positionX != null) updates['position_x'] = positionX;
    if (positionY != null) updates['position_y'] = positionY;
    if (colorHex != null) updates['color_hex'] = colorHex;

    if (updates.isNotEmpty) {
      await db.update(
        'brainstorm_canvas_items',
        updates,
        where: 'id = ?',
        whereArgs: [itemId],
      );
    }
  }

  Future<void> deleteCanvasItem(int itemId) async {
    final db = await database;
    await db.delete(
      'brainstorm_canvas_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  // --- UPI Contact Mapping ---

  String _normalizeUpiKey(String upiId) {
    return upiId.trim().toLowerCase();
  }

  Future<void> upsertUpiContactMapping({
    required String upiId,
    required String contactName,
    String source = 'manual',
  }) async {
    final cleanedUpi = upiId.trim();
    final cleanedName = contactName.trim();
    if (cleanedUpi.isEmpty || cleanedName.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final db = await database;
    await db.insert(
      'upi_contact_mappings',
      {
        'upi_id': cleanedUpi,
        'upi_key': _normalizeUpiKey(cleanedUpi),
        'contact_name': cleanedName,
        'source': source,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getUpiContactMapping(String upiId) async {
    final key = _normalizeUpiKey(upiId);
    if (key.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'upi_contact_mappings',
      where: 'upi_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['contact_name']?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

/// Global instance
final databaseHelper = DatabaseHelper();
