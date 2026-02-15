import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';


import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class _UpiBusinessRule {
  final String displayName;
  final String category;

  const _UpiBusinessRule({
    required this.displayName,
    required this.category,
  });
}

/// Notification Transaction Service – Listens for banking app notifications
/// and extracts financial transactions using the same parsing pipeline as
/// the previous SMS-based approach, but operating on notification payloads
/// (title, text, package, timestamp) instead of SMS inbox rows.
///
/// Requires: user-granted Notification Listener access (special access via
/// system Settings, NOT a runtime permission).
class NotificationTransactionService {
  static final NotificationTransactionService _instance =
      NotificationTransactionService._internal();
  factory NotificationTransactionService() => _instance;
  NotificationTransactionService._internal();

  // Platform channels
  static const _methodChannel =
      MethodChannel('wealthin/notification_listener');
  static const _eventChannel =
      EventChannel('wealthin/notification_events');

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  bool _isListening = false;
  StreamSubscription<dynamic>? _notificationSubscription;

  // Contact cache (reused from old SMS service)
  final Map<String, String> _phoneToContactName = {};
  final Map<String, String> _normalizedContactNameToDisplayName = {};
  final Map<String, int> _upiUsageCount = {};

  // ────────────────────────────────────────────────────────────────────
  // Known UPI business rules (identical to old SMS service)
  // ────────────────────────────────────────────────────────────────────
  static const Map<String, _UpiBusinessRule> _knownUpiBusinessRules = {
    'amzn': _UpiBusinessRule(displayName: 'Amazon', category: 'Shopping'),
    'amazon': _UpiBusinessRule(displayName: 'Amazon', category: 'Shopping'),
    'flipkart':
        _UpiBusinessRule(displayName: 'Flipkart', category: 'Shopping'),
    'zomato':
        _UpiBusinessRule(displayName: 'Zomato', category: 'Food & Dining'),
    'swiggy':
        _UpiBusinessRule(displayName: 'Swiggy', category: 'Food & Dining'),
    'paytm': _UpiBusinessRule(displayName: 'Paytm', category: 'Utilities'),
    'irctc':
        _UpiBusinessRule(displayName: 'IRCTC', category: 'Transportation'),
    'uber':
        _UpiBusinessRule(displayName: 'Uber', category: 'Transportation'),
    'ola': _UpiBusinessRule(displayName: 'Ola', category: 'Transportation'),
    'rapido':
        _UpiBusinessRule(displayName: 'Rapido', category: 'Transportation'),
    'blinkit':
        _UpiBusinessRule(displayName: 'Blinkit', category: 'Groceries'),
    'zepto': _UpiBusinessRule(displayName: 'Zepto', category: 'Groceries'),
    'jiomart':
        _UpiBusinessRule(displayName: 'JioMart', category: 'Groceries'),
    'bigbasket':
        _UpiBusinessRule(displayName: 'BigBasket', category: 'Groceries'),
  };

  // ────────────────────────────────────────────────────────────────────
  // Bank package-name → human bank name mapping
  // ────────────────────────────────────────────────────────────────────
  static const Map<String, String> _packageToBank = {
    'com.sbi': 'State Bank of India',
    'com.csam.icici': 'ICICI Bank',
    'com.hdfc': 'HDFC Bank',
    'com.snapwork.hdfc': 'HDFC Bank',
    'com.axis.mobile': 'Axis Bank',
    'com.msf.koenig.bank.kotak': 'Kotak Mahindra Bank',
    'net.one97.paytm': 'Paytm Payments Bank',
    'com.phonepe.app': 'PhonePe',
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.dreamplug.androidapp': 'CRED',
  };

  // Banking content pattern (same as old SMS service)
  static final RegExp _bankContentPattern = RegExp(
    r'(debited|credited|debit|credit|a/c|acct|account\s*\w*\d|avl\.?\s*bal|'
    r'avail(?:able)?\s*bal|txn|transaction|UPI|NEFT|RTGS|IMPS|withdrawn|'
    r'transferred|received|payment\s+of\s+rs)',
    caseSensitive: false,
  );

  // ════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════

  /// Check whether the user has enabled notification listener access.
  Future<bool> isListenerEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isListenerEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotifTxn] Error checking listener status: $e');
      return false;
    }
  }

  /// Open the system Notification Listener settings page.
  Future<bool> openListenerSettings() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('openListenerSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('[NotifTxn] Error opening listener settings: $e');
      return false;
    }
  }

  /// Start listening for incoming notifications from the event stream.
  /// Each notification that looks like a banking transaction is parsed
  /// and persisted automatically.
  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    await _loadContactCache();
    final db = await _databaseHelper.database;
    await _warmUpiUsageCache(db);

    _notificationSubscription =
        _eventChannel.receiveBroadcastStream().listen((event) {
      _handleNotificationEvent(event);
    }, onError: (error) {
      debugPrint('[NotifTxn] Event stream error: $error');
    });

    debugPrint('[NotifTxn] Started listening for banking notifications');
  }

  /// Stop the notification event stream.
  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _isListening = false;
    debugPrint('[NotifTxn] Stopped listening');
  }

  /// Process a single notification event from the platform side.
  Future<void> _handleNotificationEvent(dynamic event) async {
    try {
      final Map<String, dynamic> payload =
          jsonDecode(event as String) as Map<String, dynamic>;

      final title = payload['title'] as String? ?? '';
      final text = payload['text'] as String? ?? '';
      final package = payload['package'] as String? ?? '';
      final timestampMs = payload['timestamp'] as int? ?? 0;

      final body = '$title $text';

      // Double-check banking content (native side already filters, but be safe)
      if (!_bankContentPattern.hasMatch(body)) return;

      final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);

      final transaction = await _parseNotification(
        package: package,
        body: body,
        timestamp: timestamp,
      );

      if (transaction == null) return;

      final db = await _databaseHelper.database;

      // Deduplicate
      final existing = await db.query(
        'transactions',
        where:
            'description = ? AND amount = ? AND date = ? AND COALESCE(merchant, "") = ?',
        whereArgs: [
          transaction['description'],
          transaction['amount'],
          transaction['date'],
          transaction['merchant'] ?? '',
        ],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert('transactions', {
          'amount': transaction['amount'],
          'description': transaction['description'],
          'category': transaction['category'],
          'date': transaction['date'],
          'type': transaction['type'],
          'paymentMethod': transaction['paymentMethod'] ?? 'Bank Transfer',
          'merchant': transaction['merchant'] ?? transaction['description'],
          'notes': transaction['notes'],
          'is_synced': 0,
          'balance': transaction['balance'],
          'account_last4': transaction['account_last4'],
          'bank': transaction['bank'],
        });

        final insertedUpiId = transaction['upi_id']?.toString();
        if (insertedUpiId != null && insertedUpiId.isNotEmpty) {
          _upiUsageCount.update(
            insertedUpiId,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }

        debugPrint(
          '[NotifTxn] Added: ${transaction['description']} – ₹${transaction['amount']}',
        );
      }
    } catch (e) {
      debugPrint('[NotifTxn] Error handling notification: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // PARSING PIPELINE (re-used from SmsTransactionService)
  // ════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _parseNotification({
    required String package,
    required String body,
    required DateTime timestamp,
  }) async {
    try {
      final type = _determineType(body);
      if (type == null) return null;

      final balance = _extractBalance(body);
      final amount = _extractAmount(body, balance: balance);
      if (amount == null || amount <= 0) return null;

      final upiId = _extractUpiId(body);
      final matchedUpiName =
          upiId == null ? null : await _resolveUpiDisplayName(upiId);
      final businessRule = _resolveBusinessRule(upiId);
      final upiFrequencyCount =
          upiId == null ? 0 : (_upiUsageCount[upiId] ?? 0);

      final extractedDescription = _extractDescription(body);
      final description = matchedUpiName?.trim().isNotEmpty == true
          ? matchedUpiName!.trim()
          : (businessRule?.displayName ??
              (upiId != null ? 'Unknown' : extractedDescription));
      final merchant = matchedUpiName?.trim().isNotEmpty == true
          ? matchedUpiName!.trim()
          : (businessRule?.displayName ?? (upiId ?? extractedDescription));

      final accountLast4 = _extractAccount(body);
      final bank = _identifyBankFromPackage(package);

      final category = _categorizeTransaction(
        description,
        body,
        upiId: upiId,
        amount: amount,
        type: type,
        hasContactMatch: matchedUpiName?.trim().isNotEmpty == true,
        businessRule: businessRule,
        upiFrequencyCount: upiFrequencyCount,
      );

      String? notes;
      if (upiId != null) {
        final noteParts = <String>['UPI ID: $upiId'];
        if (matchedUpiName?.trim().isNotEmpty == true) {
          noteParts.add('Contact: ${matchedUpiName!.trim()}');
        }
        if (businessRule != null) {
          noteParts.add('Business: ${businessRule.displayName}');
        }
        if (upiFrequencyCount >= 3) {
          noteParts.add('Recurring: ${upiFrequencyCount + 1}');
        }
        if (category == 'Uncategorized') {
          noteParts.add('Review Needed');
        }
        notes = noteParts.join(' | ');
      }

      final dateStr = timestamp.toIso8601String().split('T')[0];

      return {
        'amount': amount,
        'type': type,
        'description': description,
        'category': category,
        'date': dateStr,
        'merchant': merchant,
        'paymentMethod': 'Bank Transfer',
        'source': 'notification',
        'notes': notes,
        'balance': balance,
        'account_last4': accountLast4,
        'bank': bank,
        'upi_id': upiId,
      };
    } catch (e) {
      debugPrint('[NotifTxn] Error parsing notification: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────
  // Determine type (debit / credit)
  // ────────────────────────────────────────────────────────
  String? _determineType(String text) {
    final textLower = text.toLowerCase();

    final debitKeywords = [
      'debited', 'debit', 'paid', 'withdrawn', 'spent', 'purchase',
      'purchased', 'sent', 'transferred to', 'transaction at',
      'txn at', 'txn of', 'pos txn', 'upi txn',
    ];

    final creditKeywords = [
      'credited', 'received', 'deposited', 'salary', 'sal cr',
      'refund', 'cashback', 'interest credited', 'reward credited',
    ];

    final hasCreditCard =
        textLower.contains('credit card') || textLower.contains('creditcard');

    if (!hasCreditCard) {
      if (creditKeywords.any((kw) => textLower.contains(kw))) {
        return 'income';
      }
      if (RegExp(r'\bcr\b').hasMatch(textLower)) return 'income';
    } else {
      final specificCredit = [
        'credited', 'received', 'deposited', 'refund', 'cashback', 'salary',
      ];
      if (specificCredit.any((kw) => textLower.contains(kw))) return 'income';
    }

    if (debitKeywords.any((kw) => textLower.contains(kw))) return 'expense';
    if (RegExp(r'\bdr\b').hasMatch(textLower)) return 'expense';

    final hasTxnWord = RegExp(r'\b(txn|transaction)\b').hasMatch(textLower);
    if (hasTxnWord && _extractAmount(text) != null) return 'expense';

    return null;
  }

  // ────────────────────────────────────────────────────────
  // Amount extraction
  // ────────────────────────────────────────────────────────
  double? _extractAmount(String text, {double? balance}) {
    final textLower = text.toLowerCase();

    final contextualPatterns = [
      RegExp(
        r'(?:debited|debit|paid|withdrawn|spent|purchased|sent)\s*(?:by\s*|for\s*|of\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:credited|received|deposited|refund)\s*(?:by\s*|with\s*|of\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)\s*(?:has been\s*)?(?:debited|credited|paid|withdrawn|received|deposited)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in contextualPatterns) {
      final match = pattern.firstMatch(textLower);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = double.parse(amountStr);
          if (amount >= 0.01 && amount <= 10000000) return amount;
        } catch (_) {
          continue;
        }
      }
    }

    final genericPatterns = [
      RegExp(
        r'(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)\s*(?:inr|rs\.?|rupees?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:amount|amt|sum|total|value)\s*(?:of\s*)?(?:rs\.?\s*|inr\s*|₹\s*)?([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
    ];

    final balanceRegion = _findBalanceRegion(text);

    for (final pattern in genericPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        if (balanceRegion != null &&
            match.start >= balanceRegion.$1 &&
            match.start <= balanceRegion.$2) {
          continue;
        }
        try {
          final amountStr =
              match.group(1)!.replaceAll(',', '').replaceAll(' ', '');
          final amount = double.parse(amountStr);
          if (balance != null && (amount - balance).abs() < 0.01) continue;
          if (amount >= 1 && amount <= 10000000) return amount;
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  (int, int)? _findBalanceRegion(String text) {
    final balanceMarkers = [
      RegExp(
        r'(?:avl\.?\s*bal|avail(?:able)?\s*bal(?:ance)?|a/c\s*bal|net\s*(?:avl\.?\s*)?bal|closing\s*bal|bal(?:ance)?)\s*[:.]\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)?[0-9,]+(?:\.[0-9]{1,2})?',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:rs\.?\s*|inr\s*|₹\s*)[0-9,]+(?:\.[0-9]{1,2})?\s*(?:available|avl|avail)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in balanceMarkers) {
      final match = pattern.firstMatch(text);
      if (match != null) return (match.start, match.end);
    }
    return null;
  }

  // ────────────────────────────────────────────────────────
  // Balance extraction
  // ────────────────────────────────────────────────────────
  double? _extractBalance(String text) {
    final patterns = [
      RegExp(
        r'(?:avl\.?\s*bal|avail(?:able)?\s*bal(?:ance)?)\s*[:.]\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:a/c\s*bal(?:ance)?|account\s*bal(?:ance)?)\s*[:.]\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:net\s*(?:avl\.?\s*)?bal(?:ance)?)\s*[:.]\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:closing\s*bal(?:ance)?)\s*[:.]\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:bal(?:ance)?)\s*[:.]\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)\s*(?:available|avl|avail)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          return double.parse(match.group(1)!.replaceAll(',', ''));
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────────────
  // Account last-4 & bank identification
  // ────────────────────────────────────────────────────────
  String? _extractAccount(String text) {
    final patterns = [
      RegExp(
        r'(?:a/c|acct?|account|card)\s*(?:no\.?\s*)?(?:\*{2,}|[xX]{2,})?(\d{4})',
        caseSensitive: false,
      ),
      RegExp(r'(?:\*{2,}|[xX]{2,})(\d{4})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String _identifyBankFromPackage(String packageName) {
    final lower = packageName.toLowerCase();
    for (final entry in _packageToBank.entries) {
      if (lower.startsWith(entry.key)) return entry.value;
    }

    // Fallback: try to identify from notification text via sender-style keywords
    // (kept for edge-cases where package is generic)
    return 'Unknown Bank';
  }

  // ────────────────────────────────────────────────────────
  // UPI helpers
  // ────────────────────────────────────────────────────────
  bool _isLikelyUpiId(String value) {
    final candidate = value.trim().toLowerCase();
    if (!candidate.contains('@')) return false;
    final parts = candidate.split('@');
    if (parts.length != 2) return false;
    if (parts[0].length < 2 || parts[1].length < 2) return false;
    return RegExp(r'^[a-z0-9._-]+@[a-z0-9._-]+$').hasMatch(candidate);
  }

  String? _extractUpiId(String text) {
    final patterns = [
      RegExp(
        r'vpa[:\s-]+([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'upi(?:[/\s:-])+([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
        caseSensitive: false,
      ),
      RegExp(r'([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final candidate =
          match.group(1)?.trim().replaceAll(RegExp(r'[.,;:]$'), '');
      if (candidate == null || !_isLikelyUpiId(candidate)) continue;
      return candidate.toLowerCase();
    }
    return null;
  }

  _UpiBusinessRule? _resolveBusinessRule(String? upiId) {
    if (upiId == null || upiId.isEmpty) return null;
    final localPart = upiId.split('@').first.toLowerCase();
    final normalizedPrefix = localPart.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalizedPrefix.isEmpty) return null;

    _UpiBusinessRule? bestMatch;
    var bestMatchLength = 0;
    for (final entry in _knownUpiBusinessRules.entries) {
      if (!(normalizedPrefix.startsWith(entry.key) ||
          normalizedPrefix.contains(entry.key))) {
        continue;
      }
      if (entry.key.length > bestMatchLength) {
        bestMatch = entry.value;
        bestMatchLength = entry.key.length;
      }
    }
    return bestMatch;
  }

  // ────────────────────────────────────────────────────────
  // Contact / UPI name resolution
  // ────────────────────────────────────────────────────────
  Future<void> _loadContactCache() async {
    // Contact loading disabled — flutter_contacts requires READ_CONTACTS
    // permission which we have removed. UPI name resolution still works
    // via the database-cached UPI-to-name mapping.
    debugPrint('[NotifTxn] Contact loading skipped (no contacts permission)');
  }

  String _normalizeNameForMatch(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _normalizePhoneNumber(String rawValue) {
    final digits = rawValue.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }

  String? _findFuzzyNameMatch(String upiLocalPart) {
    if (_normalizedContactNameToDisplayName.isEmpty) return null;
    final upiNameToken = _normalizeNameForMatch(
      upiLocalPart.replaceAll(RegExp(r'[._-]+'), ' '),
    );
    if (upiNameToken.length < 3) return null;

    final exactMatch = _normalizedContactNameToDisplayName[upiNameToken];
    if (exactMatch != null) return exactMatch;

    for (final entry in _normalizedContactNameToDisplayName.entries) {
      if (entry.key.length < 3) continue;
      if (entry.key.contains(upiNameToken) ||
          upiNameToken.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<String?> _resolveUpiDisplayName(String upiId) async {
    final normalizedUpi = upiId.trim().toLowerCase();
    if (normalizedUpi.isEmpty) return null;

    final storedName =
        await _databaseHelper.getUpiContactMapping(normalizedUpi);
    if (storedName != null) return storedName;

    final localPart = normalizedUpi.split('@').first;
    final normalizedPhone = _normalizePhoneNumber(localPart);
    if (normalizedPhone != null) {
      final phoneMatch = _phoneToContactName[normalizedPhone];
      if (phoneMatch != null && phoneMatch.trim().isNotEmpty) {
        await _databaseHelper.upsertUpiContactMapping(
          upiId: normalizedUpi,
          contactName: phoneMatch.trim(),
          source: 'contacts_phone',
        );
        return phoneMatch.trim();
      }
    }

    final fuzzyMatch = _findFuzzyNameMatch(localPart);
    if (fuzzyMatch != null && fuzzyMatch.trim().isNotEmpty) {
      await _databaseHelper.upsertUpiContactMapping(
        upiId: normalizedUpi,
        contactName: fuzzyMatch.trim(),
        source: 'contacts_fuzzy',
      );
      return fuzzyMatch.trim();
    }
    return null;
  }

  Future<void> _warmUpiUsageCache(Database db) async {
    _upiUsageCount.clear();
    try {
      final cutoffDate = DateTime.now()
          .subtract(const Duration(days: 90))
          .toIso8601String()
          .split('T')
          .first;

      final rows = await db.query(
        'transactions',
        columns: ['notes'],
        where: 'paymentMethod = ? AND date >= ? AND notes LIKE ?',
        whereArgs: ['Bank Transfer', cutoffDate, 'UPI ID:%'],
      );

      for (final row in rows) {
        final upiFromNotes = _extractUpiFromNotes(row['notes']?.toString());
        if (upiFromNotes == null) continue;
        _upiUsageCount.update(upiFromNotes, (v) => v + 1,
            ifAbsent: () => 1);
      }
    } catch (e) {
      debugPrint('[NotifTxn] UPI cache warm-up skipped: $e');
    }
  }

  String? _extractUpiFromNotes(String? notes) {
    if (notes == null || notes.isEmpty) return null;
    final match = RegExp(
      r'UPI ID:\s*([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+)',
      caseSensitive: false,
    ).firstMatch(notes);
    final candidate = match?.group(1)?.trim().toLowerCase();
    if (candidate == null || !_isLikelyUpiId(candidate)) return null;
    return candidate;
  }

  // ────────────────────────────────────────────────────────
  // Description extraction
  // ────────────────────────────────────────────────────────
  String _extractDescription(String text) {
    final patterns = [
      RegExp(
        r'UPI[/-]([a-zA-Z0-9\s@\-\.]+?)(?:[/@\s]|$)',
        caseSensitive: false,
      ),
      RegExp(r'VPA[:\s-]+([a-zA-Z0-9@\.]+)', caseSensitive: false),
      RegExp(
        r'(?:at|to|from)\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI|Card|dated)|\.|\s*$)',
        caseSensitive: false,
      ),
      RegExp(
        r'paid to\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI)|\.|\s*$)',
        caseSensitive: false,
      ),
      RegExp(
        r'received from\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI)|\.|\s*$)',
        caseSensitive: false,
      ),
      RegExp(
        r'for\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|at|A/C)|\.|\s*$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var desc = match
            .group(1)!
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'\*+'), '')
            .trim();
        if (desc.length >= 3 && desc.length <= 100) {
          desc = desc.replaceAll(RegExp(r'\s+(A/C|Ref|UPI|Card).*$'), '');
          return desc;
        }
      }
    }

    final words = text.split(RegExp(r'\s+'));
    final capitalPhrase = <String>[];
    for (final word in words) {
      if (word.length > 2 && RegExp(r'^[A-Z]').hasMatch(word)) {
        capitalPhrase.add(word);
        if (capitalPhrase.length >= 3) break;
      } else if (capitalPhrase.isNotEmpty) {
        break;
      }
    }
    if (capitalPhrase.isNotEmpty) {
      final phrase = capitalPhrase.join(' ');
      if (phrase.length >= 3) return phrase;
    }
    return 'Bank Transaction';
  }

  // ────────────────────────────────────────────────────────
  // Categorization (identical to old service)
  // ────────────────────────────────────────────────────────
  String _categorizeTransaction(
    String description,
    String fullText, {
    String? upiId,
    required double amount,
    required String type,
    required bool hasContactMatch,
    _UpiBusinessRule? businessRule,
    int upiFrequencyCount = 0,
  }) {
    final descLower = description.toLowerCase();
    final textLower = fullText.toLowerCase();

    if (upiId != null) {
      if (businessRule != null) return businessRule.category;
      final isRecurringUpi = upiFrequencyCount >= 2;
      final isSmallTxn = amount >= 50 && amount <= 500;
      final isLargeTxn = amount >= 1000;

      if (type == 'income' && isLargeTxn) return 'Freelance Income';
      if (isRecurringUpi && isLargeTxn) return 'Rent & Housing';
      if (isRecurringUpi && !isLargeTxn) return 'Subscriptions';
      if (hasContactMatch) {
        if (type == 'expense' && isSmallTxn) return 'Daily Expenses';
        return 'Personal Transfer';
      }
      if (type == 'expense' && isSmallTxn) return 'Daily Expenses';
      return 'Uncategorized';
    }

    final categories = {
      'Food & Dining': [
        'zomato', 'swiggy', 'dominos', 'pizza', 'mcdonald', 'kfc', 'burger',
        'restaurant', 'cafe', 'coffee', 'food', 'dining', 'eat', 'lunch',
        'dinner', 'breakfast', 'biryani', 'starbucks', 'subway',
      ],
      'Shopping': [
        'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'shop', 'store',
        'mall', 'mart', 'buy', 'purchase', 'ecommerce', 'meesho', 'jiomart',
      ],
      'Transportation': [
        'uber', 'ola', 'rapido', 'petrol', 'fuel', 'metro', 'parking', 'bus',
        'train', 'taxi', 'cab', 'auto', 'rickshaw', 'travel', 'fastag', 'toll',
      ],
      'Utilities': [
        'electricity', 'water', 'gas', 'broadband', 'mobile', 'recharge',
        'bill', 'payment', 'airtel', 'jio', 'vodafone', 'bsnl', 'internet',
        'wifi', 'dth', 'tata sky',
      ],
      'Entertainment': [
        'netflix', 'prime', 'spotify', 'hotstar', 'youtube', 'movie', 'ticket',
        'show', 'concert', 'game', 'steam', 'playstation', 'zee5', 'sony liv',
      ],
      'Groceries': [
        'bigbasket', 'dmart', 'grofers', 'blinkit', 'grocery', 'supermarket',
        'vegetables', 'fruits', 'zepto', 'dunzo', 'instamart', 'fresh',
      ],
      'Healthcare': [
        'pharmacy', 'hospital', 'clinic', 'doctor', 'medicine', 'apollo',
        'medplus', 'netmeds', '1mg', 'pharmeasy', 'health', 'medical',
      ],
      'Education': [
        'school', 'college', 'university', 'course', 'tuition', 'fees', 'exam',
        'book', 'udemy', 'coursera', 'upgrad', 'byjus',
      ],
      'Rent & Housing': [
        'rent', 'maintenance', 'society', 'housing', 'lease', 'accommodation',
      ],
      'Insurance': [
        'insurance', 'policy', 'premium', 'lic', 'health insurance',
        'car insurance', 'life insurance',
      ],
      'Investments': [
        'mutual fund', 'sip', 'stock', 'equity', 'zerodha', 'groww', 'upstox',
        'investment', 'fd', 'rd', 'ppf', 'nps', 'elss',
      ],
      'Salary': [
        'salary', 'sal cr', 'sal credit', 'monthly salary', 'payroll', 'wages',
      ],
      'Transfer': [
        'upi', 'imps', 'neft', 'rtgs', 'transfer', 'sent to', 'p2p',
      ],
    };

    for (final entry in categories.entries) {
      if (entry.value
          .any((kw) => descLower.contains(kw) || textLower.contains(kw))) {
        return entry.key;
      }
    }

    if (textLower.contains('atm') || textLower.contains('cash withdrawal')) {
      return 'Cash Withdrawal';
    }

    return 'Others';
  }

  // ════════════════════════════════════════════════════════════════════
  // Stats (backward-compatible with DataSourcesScreen)
  // ════════════════════════════════════════════════════════════════════

  /// Get transaction detection statistics (notification + legacy SMS).
  Future<Map<String, dynamic>> getScanStats() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count, MAX(date) as last_date
        FROM transactions
        WHERE paymentMethod = 'Bank Transfer'
      ''');

      if (result.isNotEmpty) {
        return {
          'total': result.first['count'] ?? 0,
          'last_date': result.first['last_date'],
        };
      }
    } catch (e) {
      debugPrint('[NotifTxn] Error getting stats: $e');
    }
    return {'total': 0, 'last_date': null};
  }
}
