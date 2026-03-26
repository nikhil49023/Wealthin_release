import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// RAG Service — Retrieval-Augmented Generation for Artha AI
/// Chunks user's personal + financial data into text snippets,
/// scores each against the query using TF-IDF bag-of-words similarity,
/// and returns the top-k most relevant snippets for prompt injection.
///
/// 100% on-device — no cloud. Pure Dart TF-IDF.
class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  RagService._internal();

  static const int _topK = 3;
  static const int _maxChunkLen = 300;

  // ─────────── Public API ───────────

  /// Build RAG context string for injection into the AI prompt
  Future<String> buildRagContext(String userId, String query) async {
    try {
      final chunks = await _buildChunks(userId);
      if (chunks.isEmpty) return '';

      final ranked = _rankChunks(chunks, query);
      final top = ranked.take(_topK).toList();

      if (top.isEmpty) return '';

      final buf = StringBuffer('<financial_context>\n');
      for (final chunk in top) {
        buf.writeln('  - ${chunk.trim()}');
      }
      buf.write('</financial_context>');
      return buf.toString();
    } catch (e) {
      debugPrint('[RAG] Error building context: $e');
      return '';
    }
  }

  // ─────────── Private ───────────

  /// Build text chunks from user's financial data
  Future<List<String>> _buildChunks(String userId) async {
    final chunks = <String>[];

    try {
      // --- Transactions (recent 50)
      final db = await DatabaseHelper().database;
      final txns = await db.query(
        'transactions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date DESC',
        limit: 50,
      );

      // Group by category
      final byCategory = <String, double>{};
      for (final t in txns) {
        final cat  = t['category'] as String? ?? 'Other';
        final amt  = (t['amount'] as num?)?.toDouble() ?? 0;
        byCategory[cat] = (byCategory[cat] ?? 0) + amt;
      }

      if (byCategory.isNotEmpty) {
        final topSpend = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final spendSummary = topSpend.take(5)
          .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}')
          .join(', ');
        chunks.add('Top spending categories this month: $spendSummary');
      }

      // Total income vs expense
      final txnData = await db.rawQuery(
        '''SELECT 
          SUM(CASE WHEN type="income" THEN amount ELSE 0 END) AS income,
          SUM(CASE WHEN type="expense" THEN amount ELSE 0 END) AS expense,
          COUNT(*) AS count
        FROM transactions WHERE user_id = ?''',
        [userId],
      );
      if (txnData.isNotEmpty) {
        final row = txnData.first;
        final income  = (row['income']  as num?)?.toDouble() ?? 0;
        final expense = (row['expense'] as num?)?.toDouble() ?? 0;
        final count   = row['count'] as int? ?? 0;
        if (count > 0) {
          chunks.add(
            'Financial summary: Monthly income ₹${income.toStringAsFixed(0)}, '
            'expenses ₹${expense.toStringAsFixed(0)}, '
            'net savings ₹${(income - expense).toStringAsFixed(0)}. '
            'Total transactions tracked: $count.'
          );
        }
      }

      // Recent transactions (last 5)
      final recent = txns.take(5).toList();
      if (recent.isNotEmpty) {
        final recentStr = recent.map((t) =>
          '${t['description']} (${t['category']}) ₹${t['amount']}').join('; ');
        chunks.add('Recent transactions: $recentStr');
      }

      // --- Goals
      try {
        final goals = await db.query(
          'goals',
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 5,
        );
        for (final g in goals) {
          chunks.add(
            'Financial goal: "${g['name']}" — target ₹${g['target_amount']}, '
            'saved ₹${g['current_amount']}, deadline ${g['deadline']}'
          );
        }
      } catch (_) {} // Goals table may not exist in all versions

      // --- Budgets
      try {
        final budgets = await db.query(
          'budgets',
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 5,
        );
        for (final b in budgets) {
          chunks.add(
            'Budget: ${b['category']} — ₹${b['amount']} per month'
          );
        }
      } catch (_) {}

    } catch (e) {
      debugPrint('[RAG] Chunk build error: $e');
    }

    return chunks;
  }

  /// TF-IDF keyword similarity ranking
  List<String> _rankChunks(List<String> chunks, String query) {
    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return chunks;

    final scored = chunks.map((chunk) {
      final chunkTokens = _tokenize(chunk);
      // Simple dot-product similarity
      var score = 0.0;
      for (final token in queryTokens) {
        if (chunkTokens.contains(token)) score += 1.0;
        // Partial match bonus
        for (final ct in chunkTokens) {
          if (ct.startsWith(token) || token.startsWith(ct)) score += 0.3;
        }
      }
      return MapEntry(chunk, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored
      .where((e) => e.value > 0)
      .map((e) => e.key.length > _maxChunkLen
          ? '${e.key.substring(0, _maxChunkLen)}...'
          : e.key)
      .toList();
  }

  Set<String> _tokenize(String text) {
    return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9₹ ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !_stopWords.contains(w))
      .toSet();
  }

  static const _stopWords = {
    'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can',
    'had', 'her', 'was', 'one', 'our', 'out', 'day', 'get', 'has',
    'him', 'his', 'how', 'may', 'new', 'now', 'old', 'see',
    'two', 'who', 'boy', 'did', 'let', 'put', 'say', 'she',
    'too', 'use', 'that', 'this', 'with', 'have', 'from', 'they',
    'know', 'want', 'been', 'good', 'much', 'some', 'time', 'very',
    'when', 'come', 'here', 'just', 'like', 'long', 'make', 'many',
    'over', 'such', 'take', 'than', 'them', 'well', 'were',
  };
}

/// Global singleton
final ragService = RagService();
