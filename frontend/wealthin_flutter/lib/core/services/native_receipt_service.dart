import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'python_bridge_service.dart';

/// Native service for Receipt Scanning using Sarvam AI (via Python backend)
/// Replaces heavy Google ML Kit dependency
class NativeReceiptService {
  static final NativeReceiptService _instance = NativeReceiptService._internal();
  factory NativeReceiptService() => _instance;
  NativeReceiptService._internal();

  final _pythonBridge = PythonBridgeService();

  /// Extract receipt data from image using Sarvam AI
  Future<Map<String, dynamic>> extractReceipt(String imagePath) async {
    try {
      // Use Python backend with Sarvam AI for receipt parsing
      final result = await _pythonBridge.extractReceiptFromPath(imagePath);
      
      if (result['success'] == true && result['transactions'] != null) {
        final transactions = result['transactions'] as List;
        if (transactions.isNotEmpty) {
          final tx = transactions.first as Map<String, dynamic>;
          return {
            'success': true,
            'transaction': tx,
            'confidence': result['confidence'] ?? 0.85,
          };
        }
      }
      
      // Fallback to basic text extraction if Sarvam fails
      return _fallbackExtraction(imagePath);
    } catch (e) {
      debugPrint('[NativeReceiptService] Error extracting receipt: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Fallback extraction using basic pattern matching
  Future<Map<String, dynamic>> _fallbackExtraction(String imagePath) async {
    // This is a minimal fallback - returns a template for manual entry
    return {
      'success': true,
      'transaction': {
        'amount': 0.0,
        'description': 'Receipt (please review)',
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'type': 'expense',
        'category': 'Shopping',
        'merchant': 'Unknown Merchant',
      },
      'confidence': 0.3,
      'needs_review': true,
    };
  }

  /// Parse receipt from text (for when text is already available)
  Map<String, dynamic> parseReceiptText(String text) {
    if (text.isEmpty) {
      return {'success': false, 'error': 'No text provided'};
    }

    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return {'success': false, 'error': 'Empty receipt'};

    // 1. Merchant (First line usually)
    String merchant = lines.first;
    if (merchant.length < 3 && lines.length > 1) merchant = lines[1];

    // 2. Date search
    DateTime? date;
    final dateRegExp = RegExp(r'(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})');
    
    for (var line in lines) {
      final match = dateRegExp.firstMatch(line);
      if (match != null) {
        try {
          String dStr = match.group(1)!.replaceAll('.', '/').replaceAll('-', '/');
          date = DateFormat('dd/MM/yyyy').parse(dStr);
          break;
        } catch (_) {
          // Keep looking
        }
      }
    }
    date ??= DateTime.now();

    // 3. Total Amount
    double amount = 0.0;
    final amountRegExp = RegExp(r'[0-9]+[,.]?[0-9]*');
    
    for (var line in lines.reversed) {
      if (line.toLowerCase().contains('total') || 
          line.toLowerCase().contains('amount') || 
          line.toLowerCase().contains('pay')) {
        final matches = amountRegExp.allMatches(line);
        if (matches.isNotEmpty) {
           String? numStr = matches.last.group(0)?.replaceAll(',', '');
           if (numStr != null) {
              double? val = double.tryParse(numStr);
              if (val != null && val > amount) amount = val;
           }
        }
      }
    }
    
    // If no total found, take the largest number in the document
    if (amount == 0.0) {
       for (var line in lines) {
          final matches = amountRegExp.allMatches(line);
           for (var m in matches) {
             String? numStr = m.group(0)?.replaceAll(',', '');
              if (numStr != null) {
                double? val = double.tryParse(numStr);
                if (val != null && val > amount && val < 1000000) {
                  amount = val;
                }
              }
           }
       }
    }
    
    // Construct Transaction
    final transaction = TransactionModel(
      amount: amount,
      description: 'Receipt from $merchant',
      date: date,
      type: 'expense',
      category: _guessCategory(merchant, text),
      merchant: merchant,
      paymentMethod: 'Cash',
      isRecurring: false,
    );
    
    return {
      'success': true,
      'transaction': {
        'amount': transaction.amount,
        'description': transaction.description,
        'date': DateFormat('yyyy-MM-dd').format(transaction.date),
        'type': transaction.type,
        'category': transaction.category,
        'merchant': transaction.merchant,
      },
      'confidence': amount > 0 ? 0.8 : 0.4,
    };
  }
  
  String _guessCategory(String merchant, String fullText) {
    String txt = ('$merchant $fullText').toUpperCase();
    if (txt.contains('FOOD') || txt.contains('REST') || txt.contains('CAFE') || txt.contains('ZOMATO')) return 'Food';
    if (txt.contains('MARKET') || txt.contains('GROCERY') || txt.contains('BIGBASKET')) return 'Groceries';
    if (txt.contains('FUEL') || txt.contains('PETROL') || txt.contains('STATION')) return 'Transport';
    if (txt.contains('HOSPITAL') || txt.contains('MEDIC') || txt.contains('PHARMACY')) return 'Healthcare';
    return 'Shopping';
  }

  void dispose() {
    // No resources to dispose - Sarvam is handled by Python backend
  }
}
