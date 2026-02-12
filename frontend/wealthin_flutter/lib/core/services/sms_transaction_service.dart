import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';

/// SMS Transaction Service - Reads SMS and extracts financial transactions
class SmsTransactionService {
  static final SmsTransactionService _instance = SmsTransactionService._internal();
  factory SmsTransactionService() => _instance;
  SmsTransactionService._internal();

  final SmsQuery _smsQuery = SmsQuery();
  bool _isScanning = false;
  
  // Bank sender IDs to filter
  final List<String> _bankSenders = [
    'SBI', 'SBIINB', 'SBIACCOUNT',
    'HDFCBK', 'HDFCBANK',
    'ICICIB', 'ICICIBANK',
    'AXISBK', 'AXISBANK',
    'KOTAKBK', 'KOTAK',
    'PNBSMS', 'BOBCARD', 'CANBNK',
    'UNIONBK', 'IDBIBK', 'YESBANK',
    'AUBANK', 'INDBNK', 'SCBANK',
    'PAYTM', 'PHONEPE', 'GPAY',
  ];

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
      
      // Get all SMS messages
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
        count: 5000, // Scan last 5000 SMS
      );

      debugPrint('[SmsTransactionService] Found ${messages.length} SMS messages');

      final db = await DatabaseHelper().database;
      int processed = 0;

      for (final sms in messages) {
        processed++;
        
        // Report progress
        if (onProgress != null && processed % 100 == 0) {
          onProgress(processed, messages.length);
        }

        // Check if it's from a bank
        final sender = sms.address ?? '';
        if (!_isBankSms(sender)) {
          continue;
        }

        final body = sms.body ?? '';
        final timestamp = sms.date ?? DateTime.now();

        // Parse the SMS
        final transaction = _parseSms(sender, body, timestamp);
        
        if (transaction != null) {
          // Check if we already have this transaction (avoid duplicates)
          final existing = await db.query(
            'transactions',
            where: 'description = ? AND amount = ? AND date = ?',
            whereArgs: [
              transaction['description'],
              transaction['amount'],
              transaction['date'],
            ],
            limit: 1,
          );

          if (existing.isEmpty) {
            // Insert new transaction
            await db.insert('transactions', {
              'amount': transaction['amount'],
              'description': transaction['description'],
              'category': transaction['category'],
              'date': transaction['date'],
              'type': transaction['type'],
              'paymentMethod': transaction['paymentMethod'] ?? 'Bank Transfer',
              'merchant': transaction['merchant'] ?? transaction['description'],
              'is_synced': 0,
            });
            
            transactionsFound++;
            debugPrint('[SmsTransactionService] Added: ${transaction['description']} - ₹${transaction['amount']}');
          }
        }
      }

      debugPrint('[SmsTransactionService] Scan complete! Found $transactionsFound new transactions');
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

  /// Parse SMS to extract transaction details
  Map<String, dynamic>? _parseSms(String sender, String message, DateTime timestamp) {
    try {
      // Determine transaction type
      final type = _determineType(message);
      if (type == null) return null;

      // Extract amount
      final amount = _extractAmount(message);
      if (amount == null || amount <= 0) return null;

      // Extract description/merchant
      final description = _extractDescription(message);

      // Categorize
      final category = _categorizeTransaction(description, message);

      // Format date
      final dateStr = timestamp.toIso8601String().split('T')[0];

      return {
        'amount': amount,
        'type': type,
        'description': description,
        'category': category,
        'date': dateStr,
        'merchant': description,
        'paymentMethod': 'Bank Transfer',
        'source': 'sms',
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
      'debited', 'debit', 'paid', 'withdrawn', 'spent',
      'purchase', 'dr', 'sent', 'transferred to'
    ];

    final creditKeywords = [
      'credited', 'credit', 'received', 'deposited',
      'cr', 'salary', 'refund', 'cashback'
    ];

    // Check for amount pattern
    if (!RegExp(r'(?:rs\.?|inr|₹)\s*[\d,]+(?:\.\d{2})?', caseSensitive: false).hasMatch(textLower)) {
      return null;
    }

    // Check credit first (more specific)
    if (creditKeywords.any((kw) => textLower.contains(kw))) {
      return 'income';
    }

    // Check debit
    if (debitKeywords.any((kw) => textLower.contains(kw))) {
      return 'expense';
    }

    return null;
  }

  /// Extract amount from SMS
  double? _extractAmount(String text) {
    // Enhanced patterns for better amount detection
    final patterns = [
      // Most common: Rs.1,234.56 or Rs 1234.56
      RegExp(r'(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // Amount followed by currency: 1234.56 Rs
      RegExp(r'([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)\s*(?:inr|rs\.?|rupees?)', caseSensitive: false),
      // Amount in text: Amount Rs.1234
      RegExp(r'(?:amount|amt|sum|total|value)\s*(?:of\s*)?(?:rs\.?\s*|inr\s*|₹\s*)?([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)', caseSensitive: false),
      // Debited/Credited patterns: Debited Rs.500
      RegExp(r'(?:debited|credited|paid|received|withdrawn|deposited)\s*(?:by\s*)?(?:rs\.?\s*|inr\s*|₹\s*)([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '').replaceAll(' ', '');
          final amount = double.parse(amountStr);
          
          // Validate amount (reasonable transaction range)
          if (amount >= 1 && amount <= 10000000) {  // ₹1 to ₹1 Crore
            return amount;
          }
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  /// Extract merchant/description from SMS
  String _extractDescription(String text) {
    // Enhanced merchant extraction patterns
    final patterns = [
      // UPI patterns: UPI/merchant@bank or UPI-merchant
      RegExp(r'UPI[/-]([a-zA-Z0-9\s@\-\.]+?)(?:[/@\s]|$)', caseSensitive: false),
      // VPA pattern: merchant@bank
      RegExp(r'VPA[:\s-]+([a-zA-Z0-9@\.]+)', caseSensitive: false),
      // At/To/From patterns: at MERCHANT NAME
      RegExp(r'(?:at|to|from)\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI|Card|dated)|\.|\s*$)', caseSensitive: false),
      // Paid to pattern
      RegExp(r'paid to\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI)|\.|\s*$)', caseSensitive: false),
      // Received from pattern
      RegExp(r'received from\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|A/C|Ref|UPI)|\.|\s*$)', caseSensitive: false),
      // For purchases: for merchant
      RegExp(r'for\s+([A-Z][A-Z0-9\s&\-\.\*]+?)(?:\s+(?:on|at|A/C)|\.|\s*$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var desc = match.group(1)!.trim();
        
        // Clean up description
        desc = desc.replaceAll(RegExp(r'\s+'), ' ')  // Normalize spaces
                   .replaceAll(RegExp(r'\*+'), '')  // Remove asterisks
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
  String _categorizeTransaction(String description, String fullText) {
    final descLower = description.toLowerCase();
    final textLower = fullText.toLowerCase();

    // Enhanced category mapping with more keywords
    final categories = {
      'Food & Dining': [
        'zomato', 'swiggy', 'dominos', 'pizza', 'mcdonald', 'kfc', 'burger',
        'restaurant', 'cafe', 'coffee', 'food', 'dining', 'eat', 'lunch',
        'dinner', 'breakfast', 'biryani', 'starbucks', 'subway'
      ],
      'Shopping': [
        'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'shop', 'store',
        'mall', 'mart', 'buy', 'purchase', 'ecommerce', 'meesho', 'jiomart'
      ],
      'Transportation': [
        'uber', 'ola', 'rapido', 'petrol', 'fuel', 'metro', 'parking',
        'bus', 'train', 'taxi', 'cab', 'auto', 'rickshaw', 'travel',
        'fastag', 'toll'
      ],
      'Utilities': [
        'electricity', 'water', 'gas', 'broadband', 'mobile', 'recharge',
        'bill', 'payment', 'airtel', 'jio', 'vodafone', 'bsnl', 'internet',
        'wifi', 'dth', 'tata sky'
      ],
      'Entertainment': [
        'netflix', 'prime', 'spotify', 'hotstar', 'youtube', 'movie',
        'ticket', 'show', 'concert', 'game', 'steam', 'playstation',
        'zee5', 'sony liv'
      ],
      'Groceries': [
        'bigbasket', 'dmart', 'grofers', 'blinkit', 'grocery', 'supermarket',
        'vegetables', 'fruits', 'zepto', 'dunzo', 'instamart', 'fresh'
      ],
      'Healthcare': [
        'pharmacy', 'hospital', 'clinic', 'doctor', 'medicine', 'apollo',
        'medplus', 'netmeds', '1mg', 'pharmeasy', 'health', 'medical'
      ],
      'Education': [
        'school', 'college', 'university', 'course', 'tuition', 'fees',
        'exam', 'book', 'udemy', 'coursera', 'upgrad', 'byjus'
      ],
      'Rent & Housing': [
        'rent', 'maintenance', 'society', 'housing', 'lease', 'accommodation'
      ],
      'Insurance': [
        'insurance', 'policy', 'premium', 'lic', 'health insurance',
        'car insurance', 'life insurance'
      ],
      'Investments': [
        'mutual fund', 'sip', 'stock', 'equity', 'zerodha', 'groww',
        'upstox', 'investment', 'fd', 'rd', 'ppf', 'nps', 'elss'
      ],
      'Salary': [
        'salary', 'sal cr', 'sal credit', 'monthly salary', 'payroll', 'wages'
      ],
      'Transfer': [
        'upi', 'imps', 'neft', 'rtgs', 'transfer', 'sent to', 'p2p'
      ],
    };

    // Check each category
    for (final entry in categories.entries) {
      if (entry.value.any((kw) => descLower.contains(kw) || textLower.contains(kw))) {
        return entry.key;
      }
    }

    // Special checks for transaction types
    if (textLower.contains('atm') || textLower.contains('cash withdrawal')) {
      return 'Cash Withdrawal';
    }

    return 'Others';
  }

  /// Get last SMS scan statistics
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
      debugPrint('[SmsTransactionService] Error getting stats: $e');
    }

    return {'total': 0, 'last_date': null};
  }
}
