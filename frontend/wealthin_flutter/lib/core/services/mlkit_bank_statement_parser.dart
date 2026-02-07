import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Universal Bank Statement Parser using Python Backend (Sarvam AI)
/// Replaces heavy Google ML Kit dependency
/// Handles: PhonePe, HDFC, SBI, ICICI, Axis, Kotak, and generic formats
class MlKitBankStatementParser {
  
  // ==================== MERCHANT KEYWORDS ====================
  static final Map<String, String> _merchantPatterns = {
    // Food & Dining
    'swiggy': 'Food & Dining', 'zomato': 'Food & Dining', 'dominos': 'Food & Dining',
    'pizza hut': 'Food & Dining', 'mcdonalds': 'Food & Dining', 'kfc': 'Food & Dining',
    'starbucks': 'Food & Dining', 'cafe coffee': 'Food & Dining', 'burger king': 'Food & Dining',
    
    // Shopping
    'amazon': 'Shopping', 'flipkart': 'Shopping', 'myntra': 'Shopping',
    'ajio': 'Shopping', 'meesho': 'Shopping', 'snapdeal': 'Shopping',
    'nykaa': 'Shopping', 'tata cliq': 'Shopping', 'reliance': 'Shopping',
    
    // Groceries
    'bigbasket': 'Groceries', 'zepto': 'Groceries', 'blinkit': 'Groceries',
    'dunzo': 'Groceries', 'dmart': 'Groceries', 'grofers': 'Groceries',
    'jiomart': 'Groceries', 'more': 'Groceries', 'spencers': 'Groceries',
    
    // Transportation
    'uber': 'Transportation', 'ola': 'Transportation', 'rapido': 'Transportation',
    'irctc': 'Transportation', 'redbus': 'Transportation', 'abhibus': 'Transportation',
    'metro': 'Transportation', 'petrol': 'Transportation', 'fuel': 'Transportation',
    'indian oil': 'Transportation', 'hp petrol': 'Transportation', 'bharat petroleum': 'Transportation',
    
    // Entertainment
    'netflix': 'Entertainment', 'spotify': 'Entertainment', 'hotstar': 'Entertainment',
    'amazon prime': 'Entertainment', 'zee5': 'Entertainment', 'sony liv': 'Entertainment',
    'bookmyshow': 'Entertainment', 'pvr': 'Entertainment', 'inox': 'Entertainment',
    
    // Bills & Utilities
    'airtel': 'Bills & Utilities', 'jio': 'Bills & Utilities', 'vi ': 'Bills & Utilities',
    'vodafone': 'Bills & Utilities', 'bsnl': 'Bills & Utilities', 'act fibernet': 'Bills & Utilities',
    'tata power': 'Bills & Utilities', 'bescom': 'Bills & Utilities', 'electricity': 'Bills & Utilities',
    'gas bill': 'Bills & Utilities', 'water bill': 'Bills & Utilities', 'broadband': 'Bills & Utilities',
    
    // Healthcare
    'apollo': 'Healthcare', '1mg': 'Healthcare', 'pharmeasy': 'Healthcare',
    'netmeds': 'Healthcare', 'practo': 'Healthcare', 'hospital': 'Healthcare',
    'clinic': 'Healthcare', 'medical': 'Healthcare', 'pharmacy': 'Healthcare',
    
    // Travel
    'makemytrip': 'Travel', 'goibibo': 'Travel', 'cleartrip': 'Travel',
    'yatra': 'Travel', 'ixigo': 'Travel', 'oyo': 'Travel',
    'airbnb': 'Travel', 'taj': 'Travel', 'hotel': 'Travel',
    
    // Finance
    'mutual fund': 'Investments', 'sip': 'Investments', 'zerodha': 'Investments',
    'groww': 'Investments', 'upstox': 'Investments', 'paytm money': 'Investments',
    'insurance': 'Insurance', 'lic': 'Insurance', 'hdfc life': 'Insurance',
  };

  // ==================== PUBLIC METHODS ====================

  /// Parse bank statement from image file
  /// Uses Python backend with Sarvam AI
  static Future<Map<String, dynamic>> parseFromImageFile(String imagePath) async {
    try {
      debugPrint('[BankStatementParser] Processing file: $imagePath');
      
      // Read image and prepare for Python backend
      final file = File(imagePath);
      if (!await file.exists()) {
        return {'success': false, 'error': 'File not found: $imagePath'};
      }
      
      // Return placeholder - actual parsing done via PythonBridgeService
      // This method is called from the service layer
      return {
        'success': true,
        'needs_python_processing': true,
        'file_path': imagePath,
        'message': 'Ready for Sarvam AI processing',
      };
    } catch (e) {
      debugPrint('[BankStatementParser] Error parsing image: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse bank statement from image bytes
  static Future<Map<String, dynamic>> parseFromImageBytes(Uint8List imageBytes, String tempPath) async {
    try {
      debugPrint('[BankStatementParser] Writing ${imageBytes.length} bytes to temp file');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes);
      
      final result = await parseFromImageFile(tempPath);
      
      return result;
    } catch (e) {
      debugPrint('[BankStatementParser] Error parsing image bytes: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse from already-extracted text (for when text is available)
  static Map<String, dynamic> parseFromText(String text) {
    final transactions = <Map<String, dynamic>>[];
    
    if (text.isEmpty) {
      return {'success': false, 'error': 'No text provided'};
    }
    
    // Detect bank/source
    final bankDetected = _detectBank(text);
    debugPrint('[BankStatementParser] Detected bank: $bankDetected');
    
    // Split into lines and clean
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    // Parse transactions from text
    String? lastDate;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Try to extract date
      final dateResult = _extractDate(line);
      if (dateResult != null) {
        lastDate = dateResult;
      }
      
      // Try to extract amount
      final amountResult = _extractAmount(line);
      if (amountResult != null) {
        final amount = amountResult['amount'] as double;
        if (amount < 1) continue;
        
        final txType = _determineTransactionType(line, amountResult['type'] as String?);
        String description = _extractDescription(line);
        final category = _categorizeTransaction(description);
        final merchant = _extractMerchant(description);
        
        transactions.add({
          'date': lastDate ?? DateTime.now().toIso8601String().substring(0, 10),
          'description': description.isNotEmpty ? description : 'Transaction',
          'amount': amount,
          'type': txType,
          'category': category,
          'merchant': merchant,
        });
      }
    }
    
    // Deduplicate
    final deduped = _deduplicateTransactions(transactions);
    
    if (deduped.isEmpty) {
      return {
        'success': false,
        'error': 'No transactions found in the document',
        'bank_detected': bankDetected,
      };
    }
    
    return {
      'success': true,
      'bank_detected': bankDetected,
      'transactions': deduped,
      'imported_count': deduped.length,
    };
  }

  // ==================== HELPER METHODS ====================

  static final Map<String, List<String>> _bankKeywords = {
    'phonepe': ['phonepe', 'phone pe'],
    'hdfc': ['hdfc', 'hdfcbank'],
    'sbi': ['sbi', 'state bank'],
    'icici': ['icici'],
    'axis': ['axis bank'],
    'kotak': ['kotak'],
    'paytm': ['paytm'],
    'gpay': ['google pay', 'gpay'],
  };

  /// Detect bank from text
  static String _detectBank(String text) {
    final textLower = text.toLowerCase();
    
    for (final entry in _bankKeywords.entries) {
      for (final keyword in entry.value) {
        if (textLower.contains(keyword)) {
          return entry.key.toUpperCase();
        }
      }
    }
    
    return 'UNKNOWN';
  }

  /// Extract date from text
  static String? _extractDate(String text) {
    // Common date patterns
    final patterns = [
      RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b'),
      RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})\b'),
      RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return _normalizeDateMatch(match);
      }
    }
    return null;
  }

  /// Normalize date to YYYY-MM-DD
  static String _normalizeDateMatch(RegExpMatch match) {
    final fullMatch = match.group(0) ?? '';
    
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fullMatch)) {
      return fullMatch;
    }
    
    if (RegExp(r'^\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{4}$').hasMatch(fullMatch)) {
      final parts = fullMatch.split(RegExp(r'[/\-\.]'));
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
    
    if (RegExp(r'^\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2}$').hasMatch(fullMatch)) {
      final parts = fullMatch.split(RegExp(r'[/\-\.]'));
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = '20${parts[2]}';
      return '$year-$month-$day';
    }
    
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  /// Extract amount from text
  static Map<String, dynamic>? _extractAmount(String text) {
    final patterns = [
      RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)\b'),
      RegExp(r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\b', caseSensitive: false),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(Cr|Dr|CR|DR)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        String? amountStr = match.group(1);
        String? typeHint;
        
        if (match.groupCount >= 2) {
          final suffix = match.group(2)?.toLowerCase();
          if (suffix == 'cr') typeHint = 'income';
          if (suffix == 'dr') typeHint = 'expense';
        }
        
        if (amountStr != null) {
          final amount = double.tryParse(amountStr.replaceAll(',', ''));
          if (amount != null && amount > 0) {
            return {'amount': amount, 'type': typeHint};
          }
        }
      }
    }
    return null;
  }

  /// Determine transaction type
  static String _determineTransactionType(String text, String? typeHint) {
    if (typeHint != null) return typeHint;
    
    final textLower = text.toLowerCase();
    
    final creditKeywords = ['credit', 'cr', 'credited', 'received', 'salary', 'refund'];
    final debitKeywords = ['debit', 'dr', 'debited', 'paid', 'payment', 'purchase'];
    
    for (final kw in creditKeywords) {
      if (textLower.contains(kw)) return 'income';
    }
    
    for (final kw in debitKeywords) {
      if (textLower.contains(kw)) return 'expense';
    }
    
    return 'expense';
  }

  /// Extract description from line
  static String _extractDescription(String line) {
    String desc = line
        .replaceAll(RegExp(r'₹[\d,\.]+'), '')
        .replaceAll(RegExp(r'Rs\.?\s*[\d,\.]+'), '')
        .replaceAll(RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    return desc.length > 100 ? desc.substring(0, 100) : desc;
  }

  /// Extract merchant from description
  static String _extractMerchant(String description) {
    final descLower = description.toLowerCase();
    
    for (final merchant in _merchantPatterns.keys) {
      if (descLower.contains(merchant)) {
        return merchant.split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
            .join(' ');
      }
    }
    
    final words = description.split(' ').where((w) => w.length > 2).take(3).join(' ');
    return words.length > 30 ? words.substring(0, 30) : words;
  }

  /// Categorize transaction
  static String _categorizeTransaction(String description) {
    final descLower = description.toLowerCase();
    
    for (final entry in _merchantPatterns.entries) {
      if (descLower.contains(entry.key)) {
        return entry.value;
      }
    }
    
    if (descLower.contains('salary')) return 'Income';
    if (descLower.contains('rent')) return 'Housing';
    if (descLower.contains('emi') || descLower.contains('loan')) return 'Loan';
    if (descLower.contains('atm') || descLower.contains('cash')) return 'Cash';
    if (descLower.contains('transfer') || descLower.contains('upi')) return 'Transfer';
    
    return 'Other';
  }

  /// Deduplicate transactions
  static List<Map<String, dynamic>> _deduplicateTransactions(List<Map<String, dynamic>> transactions) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    
    for (final tx in transactions) {
      final descStr = tx['description']?.toString() ?? '';
      final key = '${tx['date']}_${tx['amount']}_${descStr.length > 20 ? descStr.substring(0, 20) : descStr}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(tx);
      }
    }
    
    return result;
  }

  /// Dispose resources
  static void dispose() {
    // No resources to dispose - using Python backend
  }
}
