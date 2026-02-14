import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
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

/// SMS Transaction Service - Reads SMS and extracts financial transactions
class SmsTransactionService {
  static final SmsTransactionService _instance =
      SmsTransactionService._internal();
  factory SmsTransactionService() => _instance;
  SmsTransactionService._internal();

  final SmsQuery _smsQuery = SmsQuery();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isScanning = false;
  final Map<String, String> _phoneToContactName = {};
  final Map<String, String> _normalizedContactNameToDisplayName = {};
  final Map<String, int> _upiUsageCount = {};

  static const Map<String, _UpiBusinessRule> _knownUpiBusinessRules = {
    'amzn': _UpiBusinessRule(displayName: 'Amazon', category: 'Shopping'),
    'amazon': _UpiBusinessRule(displayName: 'Amazon', category: 'Shopping'),
    'flipkart': _UpiBusinessRule(displayName: 'Flipkart', category: 'Shopping'),
    'zomato': _UpiBusinessRule(
      displayName: 'Zomato',
      category: 'Food & Dining',
    ),
    'swiggy': _UpiBusinessRule(
      displayName: 'Swiggy',
      category: 'Food & Dining',
    ),
    'paytm': _UpiBusinessRule(displayName: 'Paytm', category: 'Utilities'),
    'irctc': _UpiBusinessRule(displayName: 'IRCTC', category: 'Transportation'),
    'uber': _UpiBusinessRule(displayName: 'Uber', category: 'Transportation'),
    'ola': _UpiBusinessRule(displayName: 'Ola', category: 'Transportation'),
    'rapido': _UpiBusinessRule(
      displayName: 'Rapido',
      category: 'Transportation',
    ),
    'blinkit': _UpiBusinessRule(displayName: 'Blinkit', category: 'Groceries'),
    'zepto': _UpiBusinessRule(displayName: 'Zepto', category: 'Groceries'),
    'jiomart': _UpiBusinessRule(displayName: 'JioMart', category: 'Groceries'),
    'bigbasket': _UpiBusinessRule(
      displayName: 'BigBasket',
      category: 'Groceries',
    ),
  };

  // Bank sender IDs to filter — comprehensive list for Indian banks
  final List<String> _bankSenders = [
    // State Bank of India
    'SBI', 'SBIINB', 'SBIACCOUNT', 'SBIPSG', 'SBISMS', 'SBINRB',
    // HDFC Bank
    'HDFCBK', 'HDFCBANK', 'HDFCBN', 'HDFC', 'HDFCCC',
    // ICICI Bank
    'ICICIB', 'ICICIBANK', 'ICICIBK', 'ICICI', 'ICICIC',
    // Axis Bank
    'AXISBK', 'AXISBANK', 'AXIS',
    // Kotak Mahindra Bank
    'KOTAKBK', 'KOTAK', 'KOTAKB',
    // Punjab National Bank
    'PNBSMS', 'PNB',
    // Bank of Baroda
    'BOBCARD', 'BOBSMS', 'BOB',
    // Canara Bank
    'CANBNK', 'CANARA',
    // Union Bank of India
    'UNIONBK', 'UNION',
    // IDBI Bank
    'IDBIBK', 'IDBI',
    // Yes Bank
    'YESBANK', 'YESBK',
    // AU Small Finance Bank
    'AUBANK', 'AUSFB',
    // Indian Bank
    'INDBNK', 'INDBANK',
    // Standard Chartered
    'SCBANK', 'STANCHART',
    // Federal Bank
    'FEDERALBK', 'FEDERAL',
    // DBS Bank
    'DBSBNK', 'DBS',
    // IndusInd Bank
    'INDUSIND', 'INDUSBK',
    // Bandhan Bank
    'BANDHAN', 'BANDHANBK',
    // IDFC First Bank
    'IDFCFIRST', 'IDFCBK',
    // RBL Bank
    'RBLBANK', 'RBLBK',
    // Bank of India
    'BOIBNK', 'BOI',
    // Indian Overseas Bank
    'IOB',
    // South Indian Bank
    'SIB', 'SIBSMS',
    // Equitas Small Finance
    'EQUITAS',
    // Ujjivan Small Finance
    'UJJIVAN',
    // Fintech / UPI
    'PAYTM', 'PHONEPE', 'GPAY', 'CRED', 'SLICE', 'FAMPAY',
    // Credit cards / NBFCs
    'BAJFINANCE', 'BAJAJ', 'ILOANBK', 'ABORIG', 'TATACARD', 'HSBC',
    // Post Office / NBFC / Others
    'IPPB', 'AIRTEL', 'JIOBANK',
    // Additional banks
    'CSBBNK', 'CSB', 'KARNATAKA', 'KVB', 'KVBANK',
    'NAINITAL', 'TMBANK', 'DCBBANK', 'DCB',
    'CENTRALBANK', 'MAHABANK', 'CITIBK', 'CITI',
    'DBSBNK', 'BARODA', 'PUNJAB', 'UCO',
    'FREECHARGE', 'MOBIKWIK', 'BHIM',
  ];

  /// Content-based keywords that indicate a banking SMS (fallback for unknown senders)
  static final RegExp _bankContentPattern = RegExp(
    r'(debited|credited|debit|credit|a/c|acct|account\s*\w*\d|avl\.?\s*bal|'
    r'avail(?:able)?\s*bal|txn|transaction|UPI|NEFT|RTGS|IMPS|withdrawn|'
    r'transferred|received|payment\s+of\s+rs|emi\s+(?:of|for)|'
    r'auto.?debit|standing\s+instruction|nach|mandate|'
    r'your\s+a/c|your\s+account|bank\s+account|'
    r'card\s+ending|spent\s+on|purchase\s+of)',
    caseSensitive: false,
  );

  /// Check if SMS permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Request SMS permission
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Scan all SMS messages for transactions
  Future<int> scanAllSms({Function(int, int)? onProgress}) async {
    if (_isScanning) {
      debugPrint('[SmsTransactionService] Already scanning');
      return 0;
    }

    _isScanning = true;
    int transactionsFound = 0;

    try {
      // Check permission
      if (!await hasPermission()) {
        debugPrint('[SmsTransactionService] SMS permission not granted');
        return 0;
      }

      debugPrint('[SmsTransactionService] Starting SMS scan...');

      // Get all SMS messages — scan full history for comprehensive coverage
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
        count: 50000, // Scan full SMS history (50k cap for performance)
      );

      debugPrint(
        '[SmsTransactionService] Found ${messages.length} SMS messages',
      );

      await _loadContactCache();

      final db = await _databaseHelper.database;
      await _warmUpiUsageCache(db);
      int processed = 0;

      for (final sms in messages) {
        processed++;

        // Report progress
        if (onProgress != null && processed % 100 == 0) {
          onProgress(processed, messages.length);
        }

        // Check if it's from a bank (sender-based + content-based fallback)
        final sender = sms.address ?? '';
        final body = sms.body ?? '';
        if (!_isBankSmsEnhanced(sender, body)) {
          continue;
        }

        final timestamp = sms.date ?? DateTime.now();

        // Parse the SMS
        final transaction = await _parseSms(sender, body, timestamp);

        if (transaction != null) {
          // Check if we already have this transaction (avoid duplicates)
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
            // Insert new transaction with balance/account/bank info
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
                (value) => value + 1,
                ifAbsent: () => 1,
              );
            }

            transactionsFound++;
            debugPrint(
              '[SmsTransactionService] Added: ${transaction['description']} - ₹${transaction['amount']} (bal: ${transaction['balance']})',
            );
          }
        }
      }

      debugPrint(
        '[SmsTransactionService] Scan complete! Found $transactionsFound new transactions',
      );
      return transactionsFound;
    } catch (e) {
      debugPrint('[SmsTransactionService] Error scanning SMS: $e');
      return 0;
    } finally {
      _isScanning = false;
    }
  }

  /// Check if SMS is from a bank
  bool _isBankSms(String sender) {
    final senderUpper = sender.toUpperCase();
    return _bankSenders.any((bank) => senderUpper.contains(bank));
  }

  /// Enhanced check: sender-based + content-based fallback
  bool _isBankSmsEnhanced(String sender, String body) {
    // First check sender ID
    if (_isBankSms(sender)) return true;
    // Fallback: check message content for banking keywords
    return _bankContentPattern.hasMatch(body);
  }

  Future<void> _loadContactCache() async {
    _phoneToContactName.clear();
    _normalizedContactNameToDisplayName.clear();

    try {
      final contactsPermission = await Permission.contacts.status;
      if (!contactsPermission.isGranted) {
        debugPrint(
          '[SmsTransactionService] Contacts permission not granted, skipping UPI contact matching',
        );
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      for (final contact in contacts) {
        final name = contact.displayName.trim();
        if (name.isEmpty) continue;

        final normalizedName = _normalizeNameForMatch(name);
        if (normalizedName.isNotEmpty) {
          _normalizedContactNameToDisplayName.putIfAbsent(
            normalizedName,
            () => name,
          );
        }

        for (final phone in contact.phones) {
          final normalizedPhone = _normalizePhoneNumber(phone.number);
          if (normalizedPhone == null) continue;
          _phoneToContactName.putIfAbsent(normalizedPhone, () => name);
        }
      }

      debugPrint(
        '[SmsTransactionService] Loaded contacts for UPI matching: ${_phoneToContactName.length} numbers',
      );
    } catch (e) {
      debugPrint(
        '[SmsTransactionService] Failed to load contacts for UPI matching: $e',
      );
    }
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
    if (digits.isEmpty) return null;
    if (digits.length < 10) return null;
    return digits.substring(digits.length - 10);
  }

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
      final candidate = match
          .group(1)
          ?.trim()
          .replaceAll(RegExp(r'[.,;:]$'), '');
      if (candidate == null || !_isLikelyUpiId(candidate)) continue;
      return candidate.toLowerCase();
    }
    return null;
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

    final storedName = await _databaseHelper.getUpiContactMapping(
      normalizedUpi,
    );
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

  Future<void> saveManualUpiMapping({
    required String upiId,
    required String displayName,
  }) async {
    final normalizedUpi = upiId.trim().toLowerCase();
    final normalizedName = displayName.trim();
    if (!_isLikelyUpiId(normalizedUpi) || normalizedName.isEmpty) return;

    await _databaseHelper.upsertUpiContactMapping(
      upiId: normalizedUpi,
      contactName: normalizedName,
      source: 'manual',
    );
  }

  Future<void> _warmUpiUsageCache(Database db) async {
    _upiUsageCount.clear();

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
      _upiUsageCount.update(
        upiFromNotes,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
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

  _UpiBusinessRule? _resolveBusinessRule(String? upiId) {
    if (upiId == null || upiId.isEmpty) return null;
    final localPart = upiId.split('@').first.toLowerCase();
    final normalizedPrefix = localPart.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalizedPrefix.isEmpty) return null;

    _UpiBusinessRule? bestMatch;
    var bestMatchLength = 0;

    for (final entry in _knownUpiBusinessRules.entries) {
      final key = entry.key;
      if (!(normalizedPrefix.startsWith(key) ||
          normalizedPrefix.contains(key))) {
        continue;
      }

      if (key.length > bestMatchLength) {
        bestMatch = entry.value;
        bestMatchLength = key.length;
      }
    }

    return bestMatch;
  }

  /// Parse SMS to extract transaction details
  Future<Map<String, dynamic>?> _parseSms(
    String sender,
    String message,
    DateTime timestamp,
  ) async {
    try {
      // Determine transaction type
      final type = _determineType(message);
      if (type == null) return null;

      // Extract balance FIRST so we can exclude it from amount extraction
      final balance = _extractBalance(message);

      // Extract amount (context-aware, avoids balance)
      final amount = _extractAmount(message, balance: balance);
      if (amount == null || amount <= 0) return null;

      final upiId = _extractUpiId(message);
      final matchedUpiName = upiId == null
          ? null
          : await _resolveUpiDisplayName(upiId);
      final businessRule = _resolveBusinessRule(upiId);
      final upiFrequencyCount = upiId == null
          ? 0
          : (_upiUsageCount[upiId] ?? 0);

      // Extract description/merchant with UPI humanization fallback
      final extractedDescription = _extractDescription(message);
      final description = matchedUpiName?.trim().isNotEmpty == true
          ? matchedUpiName!.trim()
          : (businessRule?.displayName ??
                (upiId != null ? 'Unknown' : extractedDescription));
      final merchant = matchedUpiName?.trim().isNotEmpty == true
          ? matchedUpiName!.trim()
          : (businessRule?.displayName ?? (upiId ?? extractedDescription));

      // Extract account last 4 digits
      final accountLast4 = _extractAccount(message);

      // Identify bank
      final bank = _identifyBank(sender);

      // Categorize
      final category = _categorizeTransaction(
        description,
        message,
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

      // Format date
      final dateStr = timestamp.toIso8601String().split('T')[0];

      return {
        'amount': amount,
        'type': type,
        'description': description,
        'category': category,
        'date': dateStr,
        'merchant': merchant,
        'paymentMethod': 'Bank Transfer',
        'source': 'sms',
        'notes': notes,
        'balance': balance,
        'account_last4': accountLast4,
        'bank': bank,
        'upi_id': upiId,
      };
    } catch (e) {
      debugPrint('[SmsTransactionService] Error parsing SMS: $e');
      return null;
    }
  }

  /// Determine transaction type from message
  String? _determineType(String text) {
    final textLower = text.toLowerCase();

    final debitKeywords = [
      'debited',
      'debit',
      'paid',
      'withdrawn',
      'spent',
      'purchase',
      'purchased',
      'sent',
      'transferred to',
      'transaction at',
      'txn at',
      'txn of',
      'pos txn',
      'upi txn',
    ];

    final creditKeywords = [
      'credited',
      'received',
      'deposited',
      'salary',
      'sal cr',
      'refund',
      'cashback',
      'interest credited',
      'reward credited',
    ];

    // Exclusion: "credit card" is a DEBIT instrument, not a credit transaction
    final hasCreditCard =
        textLower.contains('credit card') || textLower.contains('creditcard');

    // Check credit keywords first (more specific, e.g. salary / refunds)
    // But skip if the only "credit" match is from "credit card"
    if (!hasCreditCard) {
      if (creditKeywords.any((kw) => textLower.contains(kw))) {
        return 'income';
      }
      // Word-boundary check for standalone "cr" (e.g. "Cr Rs.500")
      if (RegExp(r'\bcr\b').hasMatch(textLower)) {
        return 'income';
      }
    } else {
      // Even with "credit card", check for explicit credited/received etc.
      final specificCredit = [
        'credited',
        'received',
        'deposited',
        'refund',
        'cashback',
        'salary',
      ];
      if (specificCredit.any((kw) => textLower.contains(kw))) {
        return 'income';
      }
    }

    // Then check for debit-style phrases
    if (debitKeywords.any((kw) => textLower.contains(kw))) {
      return 'expense';
    }
    // Word-boundary check for standalone "dr" (e.g. "Dr Rs.1000")
    if (RegExp(r'\bdr\b').hasMatch(textLower)) {
      return 'expense';
    }

    // Fallback: many banks use generic "txn/transaction" wording without explicit debit/credit.
    // If we see a transaction keyword and a valid amount, treat as an expense by default.
    final hasTxnWord = RegExp(r'\b(txn|transaction)\b').hasMatch(textLower);
    if (hasTxnWord && _extractAmount(text) != null) {
      return 'expense';
    }

    return null;
  }

  /// Extract amount from SMS, avoiding confusion with balance
  double? _extractAmount(String text, {double? balance}) {
    final textLower = text.toLowerCase();

    // Strategy 1: Contextual patterns - amount right next to debit/credit keywords
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
          if (amount >= 0.01 && amount <= 10000000) {
            return amount;
          }
        } catch (e) {
          continue;
        }
      }
    }

    // Strategy 2: Generic Rs/INR patterns, but skip amounts that match the balance
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

    // Find the balance region to skip matches inside it
    final balanceRegion = _findBalanceRegion(text);

    for (final pattern in genericPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        // Skip if match is inside balance region
        if (balanceRegion != null &&
            match.start >= balanceRegion.$1 &&
            match.start <= balanceRegion.$2) {
          continue;
        }

        try {
          final amountStr = match
              .group(1)!
              .replaceAll(',', '')
              .replaceAll(' ', '');
          final amount = double.parse(amountStr);

          // Skip if amount equals the balance
          if (balance != null && (amount - balance).abs() < 0.01) {
            continue;
          }

          if (amount >= 1 && amount <= 10000000) {
            return amount;
          }
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  /// Find the character range where balance info appears in the text
  (int, int)? _findBalanceRegion(String text) {
    final balanceMarkers = [
      RegExp(
        r'(?:avl\.?\s*bal|avail(?:able)?\s*bal(?:ance)?|a/c\s*bal|net\s*(?:avl\.?\s*)?bal|closing\s*bal|bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)?[0-9,]+(?:\.[0-9]{1,2})?',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:rs\.?\s*|inr\s*|₹\s*)[0-9,]+(?:\.[0-9]{1,2})?\s*(?:available|avl|avail)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in balanceMarkers) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return (match.start, match.end);
      }
    }
    return null;
  }

  /// Extract available balance from SMS
  double? _extractBalance(String text) {
    // Comprehensive balance patterns for Indian banks
    final patterns = [
      // "Avl Bal Rs.10,000.00" / "Avl. Bal: Rs 10000" / "Avail Bal INR 5000"
      RegExp(
        r'(?:avl\.?\s*bal|avail(?:able)?\s*bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      // "A/c bal: Rs.10000" / "Account balance Rs.5000"
      RegExp(
        r'(?:a/c\s*bal(?:ance)?|account\s*bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      // "Net Avl Bal Rs.10000" / "Net Bal: INR 5000"
      RegExp(
        r'(?:net\s*(?:avl\.?\s*)?bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      // "Closing Bal Rs.10000"
      RegExp(
        r'(?:closing\s*bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      // "Balance Rs.10000" / "Bal Rs 5000" / "Bal: INR 10000" / "Bal:Rs.5000"
      RegExp(
        r'(?:bal(?:ance)?)\s*[:.]?\s*(?:is\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      // Reversed: "Rs.10000 available" / "INR 5000 avl"
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
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  /// Extract last 4 digits of account number
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
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Identify bank from sender ID
  String _identifyBank(String sender) {
    final senderUpper = sender.toUpperCase();

    const bankMap = {
      'SBI': 'State Bank of India',
      'HDFC': 'HDFC Bank',
      'ICICI': 'ICICI Bank',
      'AXIS': 'Axis Bank',
      'KOTAK': 'Kotak Mahindra Bank',
      'PNB': 'Punjab National Bank',
      'BOB': 'Bank of Baroda',
      'CANBNK': 'Canara Bank',
      'UNION': 'Union Bank',
      'IDBI': 'IDBI Bank',
      'YES': 'Yes Bank',
      'AUBANK': 'AU Small Finance Bank',
      'INDBNK': 'IndusInd Bank',
      'SCBANK': 'Standard Chartered',
      'FEDERAL': 'Federal Bank',
      'IDFC': 'IDFC First Bank',
      'RBL': 'RBL Bank',
      'PAYTM': 'Paytm Payments Bank',
      'PHONEPE': 'PhonePe',
      'GPAY': 'Google Pay',
    };

    for (final entry in bankMap.entries) {
      if (senderUpper.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'Unknown Bank';
  }

  /// Extract merchant/description from SMS
  String _extractDescription(String text) {
    // Enhanced merchant extraction patterns
    final patterns = [
      // UPI patterns: UPI/merchant@bank or UPI-merchant
      RegExp(
        r'UPI[/-]([a-zA-Z0-9\s@\-\.]+?)(?:[/@\s]|$)',
        caseSensitive: false,
      ),
      // VPA pattern: merchant@bank
      RegExp(r'VPA[:\s-]+([a-zA-Z0-9@\.]+)', caseSensitive: false),
      // At/To/From patterns: at MERCHANT NAME
      RegExp(
        r'(?:at|to|from)\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI|Card|dated)|\.|\s*$)',
        caseSensitive: false,
      ),
      // Paid to pattern
      RegExp(
        r'paid to\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI)|\.|\s*$)',
        caseSensitive: false,
      ),
      // Received from pattern
      RegExp(
        r'received from\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI)|\.|\s*$)',
        caseSensitive: false,
      ),
      // For purchases: for merchant
      RegExp(
        r'for\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|at|A/C)|\.|\s*$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var desc = match.group(1)!.trim();

        // Clean up description
        desc = desc
            .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
            .replaceAll(RegExp(r'\*+'), '') // Remove asterisks
            .trim();

        // Validate length and content
        if (desc.length >= 3 && desc.length <= 100) {
          // Remove common suffixes that leak into extraction
          desc = desc.replaceAll(RegExp(r'\s+(A/C|Ref|UPI|Card).*$'), '');
          return desc;
        }
      }
    }

    // Fallback: Try to extract any capitalized phrase
    final words = text.split(RegExp(r'\s+'));
    final capitalPhrase = <String>[];

    for (final word in words) {
      if (word.length > 2 && RegExp(r'^[A-Z]').hasMatch(word)) {
        capitalPhrase.add(word);
        if (capitalPhrase.length >= 3) break;
      } else if (capitalPhrase.isNotEmpty) {
        break; // Stop if we hit a non-capitalized word
      }
    }

    if (capitalPhrase.isNotEmpty) {
      final phrase = capitalPhrase.join(' ');
      if (phrase.length >= 3) {
        return phrase;
      }
    }

    return 'Bank Transaction';
  }

  /// Auto-categorize transaction
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
      if (businessRule != null) {
        return businessRule.category;
      }

      final isRecurringUpi = upiFrequencyCount >= 2;
      final isSmallTxn = amount >= 50 && amount <= 500;
      final isLargeTxn = amount >= 1000;

      if (type == 'income' && isLargeTxn) {
        return 'Freelance Income';
      }
      if (isRecurringUpi && isLargeTxn) {
        return 'Rent & Housing';
      }
      if (isRecurringUpi && !isLargeTxn) {
        return 'Subscriptions';
      }
      if (hasContactMatch) {
        if (type == 'expense' && isSmallTxn) {
          return 'Daily Expenses';
        }
        return 'Personal Transfer';
      }
      if (type == 'expense' && isSmallTxn) {
        return 'Daily Expenses';
      }

      return 'Uncategorized';
    }

    // Enhanced category mapping with comprehensive keywords
    final categories = {
      'Food & Dining': [
        'zomato',
        'swiggy',
        'dominos',
        'pizza',
        'mcdonald',
        'kfc',
        'burger',
        'restaurant',
        'cafe',
        'coffee',
        'food',
        'dining',
        'eat',
        'lunch',
        'dinner',
        'breakfast',
        'biryani',
        'starbucks',
        'subway',
        'chai',
        'bakery',
        'haldiram',
        'barbeque',
      ],
      'Shopping': [
        'amazon',
        'flipkart',
        'myntra',
        'ajio',
        'nykaa',
        'shop',
        'store',
        'mall',
        'mart',
        'buy',
        'purchase',
        'ecommerce',
        'meesho',
        'jiomart',
        'snapdeal',
        'tatacliq',
        'croma',
        'reliance digital',
      ],
      'Transportation': [
        'uber',
        'ola',
        'rapido',
        'petrol',
        'fuel',
        'metro',
        'parking',
        'bus',
        'train',
        'taxi',
        'cab',
        'auto',
        'rickshaw',
        'travel',
        'fastag',
        'toll',
      ],
      'Utilities': [
        'electricity',
        'water',
        'gas',
        'broadband',
        'mobile',
        'recharge',
        'bill',
        'payment',
        'airtel',
        'jio',
        'vodafone',
        'bsnl',
        'internet',
        'wifi',
        'dth',
        'tata sky',
      ],
      'Entertainment': [
        'netflix',
        'prime',
        'spotify',
        'hotstar',
        'youtube',
        'movie',
        'ticket',
        'show',
        'concert',
        'game',
        'steam',
        'playstation',
        'zee5',
        'sony liv',
      ],
      'Groceries': [
        'bigbasket',
        'dmart',
        'grofers',
        'blinkit',
        'grocery',
        'supermarket',
        'vegetables',
        'fruits',
        'zepto',
        'dunzo',
        'instamart',
        'fresh',
      ],
      'Healthcare': [
        'pharmacy',
        'hospital',
        'clinic',
        'doctor',
        'medicine',
        'apollo',
        'medplus',
        'netmeds',
        '1mg',
        'pharmeasy',
        'health',
        'medical',
      ],
      'Education': [
        'school',
        'college',
        'university',
        'course',
        'tuition',
        'fees',
        'exam',
        'book',
        'udemy',
        'coursera',
        'upgrad',
        'byjus',
      ],
      'Rent & Housing': [
        'rent',
        'maintenance',
        'society',
        'housing',
        'lease',
        'accommodation',
      ],
      'Insurance': [
        'insurance',
        'policy',
        'premium',
        'lic',
        'health insurance',
        'car insurance',
        'life insurance',
      ],
      'Investments': [
        'mutual fund',
        'sip',
        'stock',
        'equity',
        'zerodha',
        'groww',
        'upstox',
        'investment',
        'fd',
        'rd',
        'ppf',
        'nps',
        'elss',
        'angel one',
        'coin',
        'kuvera',
      ],
      'Salary': [
        'salary',
        'sal cr',
        'sal credit',
        'monthly salary',
        'payroll',
        'wages',
        'stipend',
      ],
      'Loan & EMI': [
        'emi',
        'loan',
        'nach',
        'mandate',
        'auto debit',
        'bajaj finserv',
        'home loan',
        'personal loan',
        'car loan',
      ],
      'Wallet & Prepaid': [
        'wallet',
        'loaded',
        'top-up',
        'topup',
        'freecharge',
        'mobikwik',
        'amazonpay',
        'phonepe wallet',
      ],
      'Transfer': ['upi', 'imps', 'neft', 'rtgs', 'transfer', 'sent to', 'p2p'],
    };

    // Check each category
    for (final entry in categories.entries) {
      if (entry.value.any(
        (kw) => descLower.contains(kw) || textLower.contains(kw),
      )) {
        return entry.key;
      }
    }

    // Special checks for transaction types
    if (textLower.contains('atm') || textLower.contains('cash withdrawal')) {
      return 'Cash Withdrawal';
    }

    return 'Others';
  }

  /// Scan historic SMS within a specific date range
  Future<int> scanHistoricSms({
    required DateTime fromDate,
    DateTime? toDate,
    Function(int, int)? onProgress,
  }) async {
    if (_isScanning) return 0;
    _isScanning = true;
    int transactionsFound = 0;
    final effectiveToDate = toDate ?? DateTime.now();

    try {
      if (!await hasPermission()) return 0;

      debugPrint(
        '[SmsTransactionService] Historic scan: ${fromDate.toIso8601String()} to ${effectiveToDate.toIso8601String()}',
      );

      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 100000, // No practical limit for historic scan
      );

      await _loadContactCache();
      final db = await _databaseHelper.database;
      await _warmUpiUsageCache(db);
      int processed = 0;

      for (final sms in messages) {
        final timestamp = sms.date ?? DateTime.now();

        // Filter to date range
        if (timestamp.isBefore(fromDate) || timestamp.isAfter(effectiveToDate)) {
          continue;
        }

        processed++;
        if (onProgress != null && processed % 100 == 0) {
          onProgress(processed, messages.length);
        }

        final sender = sms.address ?? '';
        final body = sms.body ?? '';
        if (!_isBankSmsEnhanced(sender, body)) continue;

        final transaction = await _parseSms(sender, body, timestamp);
        if (transaction == null) continue;

        final existing = await db.query(
          'transactions',
          where: 'description = ? AND amount = ? AND date = ? AND COALESCE(merchant, "") = ?',
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
          transactionsFound++;
        }
      }

      debugPrint(
        '[SmsTransactionService] Historic scan complete! Found $transactionsFound new transactions',
      );
      return transactionsFound;
    } catch (e) {
      debugPrint('[SmsTransactionService] Error in historic scan: $e');
      return 0;
    } finally {
      _isScanning = false;
    }
  }

  /// Get last SMS scan statistics with bank-wise breakdown
  Future<Map<String, dynamic>> getScanStats() async {
    try {
      final db = await DatabaseHelper().database;

      final result = await db.rawQuery('''
        SELECT COUNT(*) as count, MAX(date) as last_date, MIN(date) as first_date
        FROM transactions
        WHERE paymentMethod = 'Bank Transfer'
      ''');

      final bankWise = await db.rawQuery('''
        SELECT bank, COUNT(*) as count, SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) as total_expense,
               SUM(CASE WHEN type='income' THEN amount ELSE 0 END) as total_income
        FROM transactions
        WHERE paymentMethod = 'Bank Transfer' AND bank IS NOT NULL AND bank != 'Unknown Bank'
        GROUP BY bank ORDER BY count DESC
      ''');

      if (result.isNotEmpty) {
        return {
          'total': result.first['count'] ?? 0,
          'last_date': result.first['last_date'],
          'first_date': result.first['first_date'],
          'banks': bankWise.map((b) => {
            'bank': b['bank'],
            'count': b['count'],
            'total_expense': b['total_expense'],
            'total_income': b['total_income'],
          }).toList(),
        };
      }
    } catch (e) {
      debugPrint('[SmsTransactionService] Error getting stats: $e');
    }

    return {'total': 0, 'last_date': null, 'first_date': null, 'banks': []};
  }
}
