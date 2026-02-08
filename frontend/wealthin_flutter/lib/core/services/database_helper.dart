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
      
      if (category == null || category == 'Other' || category.isEmpty) {
        category = TransactionCategorizer.categorize(description);
      }
      
      final rowToInsert = Map<String, dynamic>.from(row);
      rowToInsert['category'] = category;

      final id = await db.insert('transactions', rowToInsert);
      _updateBudgetSpending(category, row['amount'], row['type']);
      return id;
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      return -1;
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
