import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Memory Service — Agentic persistent memory for Artha AI
/// Stores user financial facts, preferences, and goals in SQLite.
/// Design inspired by OpenClaw-style memory.md pattern — but persisted on-device.
class MemoryService {
  static final MemoryService _instance = MemoryService._internal();
  factory MemoryService() => _instance;
  MemoryService._internal();

  // ─────────── Fact extraction patterns ───────────
  // These regexes pull structured facts from AI responses / user messages.
  static final _incomeRx    = RegExp(r'(?:income|salary|earn)[^₹\d]*₹?\s*([\d,]+)', caseSensitive: false);
  static final _expenseRx   = RegExp(r'(?:spent|expense)[^₹\d]*₹?\s*([\d,]+)', caseSensitive: false);
  static final _savingsRx   = RegExp(r'(?:saving|save)[^₹\d%]*(?:₹?\s*([\d,]+)|(\d+)%)', caseSensitive: false);
  static final _goalRx      = RegExp(r'(?:goal|want|planning)[^:.\n]{0,30}(?:₹?\s*([\d,]+)|(\d+)\s*(?:lakh|cr|crore))', caseSensitive: false);
  static final _nameRx      = RegExp(r'(?:my name is|i am|call me)\s+([A-Z][a-z]+)', caseSensitive: false);
  static final _riskRx      = RegExp(r'(?:risk[- ]?(?:profile|appetite)|i (?:am|prefer))\s*(aggressive|moderate|conservative)', caseSensitive: false);
  static final _sipRx       = RegExp(r'sip[^₹\d]*₹?\s*([\d,]+)', caseSensitive: false);

  // ─────────── Public API ───────────

  /// Save or update a memory key for a user
  Future<void> saveMemory(String userId, String key, String value) async {
    final db = await DatabaseHelper().database;
    await _ensureTable(db);
    await db.insert(
      'user_memory',
      {'user_id': userId, 'key': key, 'value': value, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('[Memory] Saved: $key = $value');
  }

  /// Load all memory entries for a user
  Future<Map<String, String>> getMemory(String userId) async {
    try {
      final db = await DatabaseHelper().database;
      // Ensure table exists
      await _ensureTable(db);
      final rows = await db.query(
        'user_memory',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'updated_at DESC',
      );
      return {for (final r in rows) r['key'] as String: r['value'] as String};
    } catch (e) {
      debugPrint('[Memory] Error loading memory: $e');
      return {};
    }
  }

  /// Build a formatted context string for prompt injection
  Future<String> buildMemoryContext(String userId) async {
    final memory = await getMemory(userId);
    if (memory.isEmpty) return '';

    final buf = StringBuffer('<memory>\n');
    // Priority ordering for most-useful facts first
    final orderedKeys = [
      'user_name', 'monthly_income', 'monthly_expenses', 'monthly_savings',
      'risk_profile', 'main_goal', 'sip_amount', 'occupation', 'city',
      'preferred_language', 'family_size',
    ];
    for (final key in orderedKeys) {
      if (memory.containsKey(key)) {
        buf.writeln('  ${_keyLabel(key)}: ${memory[key]}');
      }
    }
    // Remaining keys
    for (final entry in memory.entries) {
      if (!orderedKeys.contains(entry.key)) {
        buf.writeln('  ${_keyLabel(entry.key)}: ${entry.value}');
      }
    }
    buf.write('</memory>');
    return buf.toString();
  }

  /// Extract facts from AI response text and save them
  Future<void> extractAndSave(String text, String userId) async {
    try {
      // Name
      final nameMatch = _nameRx.firstMatch(text);
      if (nameMatch != null) await saveMemory(userId, 'user_name', nameMatch.group(1)!);

      // Income
      final incomeMatch = _incomeRx.firstMatch(text);
      if (incomeMatch != null) await saveMemory(userId, 'monthly_income', '₹${incomeMatch.group(1)}');

      // Expenses
      final expMatch = _expenseRx.firstMatch(text);
      if (expMatch != null) await saveMemory(userId, 'monthly_expenses', '₹${expMatch.group(1)}');

      // Savings
      final savMatch = _savingsRx.firstMatch(text);
      if (savMatch != null) {
        final amount = savMatch.group(1) ?? savMatch.group(2);
        if (amount != null) await saveMemory(userId, 'monthly_savings', savMatch.group(1) != null ? '₹$amount' : '$amount%');
      }

      // Goals
      final goalMatch = _goalRx.firstMatch(text);
      if (goalMatch != null) await saveMemory(userId, 'main_goal', goalMatch.group(0)!.trim());

      // Risk profile
      final riskMatch = _riskRx.firstMatch(text);
      if (riskMatch != null) await saveMemory(userId, 'risk_profile', riskMatch.group(1)!.toLowerCase());

      // SIP
      final sipMatch = _sipRx.firstMatch(text);
      if (sipMatch != null) await saveMemory(userId, 'sip_amount', '₹${sipMatch.group(1)}');
    } catch (e) {
      debugPrint('[Memory] Extract error: $e');
    }
  }

  /// Clear all memory for a user (for privacy / reset)
  Future<void> clearMemory(String userId) async {
    final db = await DatabaseHelper().database;
    await _ensureTable(db);
    await db.delete('user_memory', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ─────────── Private helpers ───────────

  Future<void> _ensureTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(user_id, key)
      )
    ''');
  }

  String _keyLabel(String key) {
    const labels = {
      'user_name': 'Name',
      'monthly_income': 'Monthly income',
      'monthly_expenses': 'Monthly expenses',
      'monthly_savings': 'Monthly savings',
      'risk_profile': 'Risk profile',
      'main_goal': 'Main goal',
      'sip_amount': 'SIP amount',
      'occupation': 'Occupation',
      'city': 'City',
      'preferred_language': 'Preferred language',
      'family_size': 'Family size',
    };
    return labels[key] ?? key.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

/// Global singleton
final memoryService = MemoryService();
