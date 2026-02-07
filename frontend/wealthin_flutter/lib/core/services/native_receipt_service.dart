import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Native service for Receipt Scanning using Google ML Kit
/// On-device OCR - fast, lightweight, works offline
class NativeReceiptService {
  static final NativeReceiptService _instance = NativeReceiptService._internal();
  factory NativeReceiptService() => _instance;
  NativeReceiptService._internal();

  // Singleton text recognizer
  TextRecognizer? _textRecognizer;
  
  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Extract receipt data from image using ML Kit
  Future<Map<String, dynamic>> extractReceipt(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return {'success': false, 'error': 'File not found'};
      }
      
      // Use Google ML Kit for on-device OCR
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);
      
      final text = recognizedText.text;
      debugPrint('[NativeReceiptService] Extracted ${text.length} characters');
      
      if (text.isEmpty) {
        return {'success': false, 'error': 'No text found in image'};
      }
      
      // Parse the extracted text
      return parseReceiptText(text);
    } catch (e) {
      debugPrint('[NativeReceiptService] Error extracting receipt: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse receipt from text (for when text is already available)
  Map<String, dynamic> parseReceiptText(String text) {
    if (text.isEmpty) {
      return {'success': false, 'error': 'No text provided'};
    }

    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return {'success': false, 'error': 'Empty receipt'};

    // 1. Merchant (First non-empty line usually)
    String merchant = lines.first;
    if (merchant.length < 3 && lines.length > 1) merchant = lines[1];
    
    // Clean merchant name
    merchant = merchant.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (merchant.length > 50) merchant = merchant.substring(0, 50);

    // 2. Date search
    DateTime? date;
    final datePatterns = [
      RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})'),
      RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'),
      RegExp(r'([A-Za-z]{3})\s+(\d{1,2}),?\s*(\d{4})', caseSensitive: false),
    ];
    
    for (var line in lines) {
      for (var pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          try {
            String dStr = match.group(0)!.replaceAll('.', '/').replaceAll('-', '/');
            // Try different formats
            for (var format in ['dd/MM/yyyy', 'dd/MM/yy', 'yyyy/MM/dd', 'MMM d, yyyy']) {
              try {
                date = DateFormat(format).parse(dStr);
                break;
              } catch (_) {}
            }
            if (date != null) break;
          } catch (_) {}
        }
      }
      if (date != null) break;
    }
    date ??= DateTime.now();

    // 3. Total Amount - look for "Total", "Amount", "Pay", "Grand Total"
    double amount = 0.0;
    final amountKeywords = ['total', 'amount', 'pay', 'grand', 'sum', 'due'];
    final amountRegExp = RegExp(r'[₹Rs\.INR]?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
    
    // First, look for lines with total keywords
    for (var line in lines.reversed) {
      final lineLower = line.toLowerCase();
      for (var keyword in amountKeywords) {
        if (lineLower.contains(keyword)) {
          final matches = amountRegExp.allMatches(line);
          if (matches.isNotEmpty) {
            String? numStr = matches.last.group(1)?.replaceAll(',', '');
            if (numStr != null) {
              double? val = double.tryParse(numStr);
              if (val != null && val > amount && val < 1000000) {
                amount = val;
              }
            }
          }
        }
      }
    }
    
    // If no total found, take the largest reasonable number
    if (amount == 0.0) {
      for (var line in lines) {
        final matches = amountRegExp.allMatches(line);
        for (var m in matches) {
          String? numStr = m.group(1)?.replaceAll(',', '');
          if (numStr != null) {
            double? val = double.tryParse(numStr);
            if (val != null && val > amount && val < 100000) {
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
      paymentMethod: _guessPaymentMethod(text),
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
      'confidence': amount > 0 ? 0.85 : 0.4,
      'needs_review': amount == 0,
    };
  }
  
  String _guessCategory(String merchant, String fullText) {
    String txt = ('$merchant $fullText').toUpperCase();
    
    // Food & Dining
    if (txt.contains('SWIGGY') || txt.contains('ZOMATO') || txt.contains('FOOD') ||
        txt.contains('RESTAURANT') || txt.contains('CAFE') || txt.contains('PIZZA') ||
        txt.contains('BURGER') || txt.contains('KFC') || txt.contains('MCDONALD')) {
      return 'Food & Dining';
    }
    
    // Groceries
    if (txt.contains('MARKET') || txt.contains('GROCERY') || txt.contains('BIGBASKET') ||
        txt.contains('ZEPTO') || txt.contains('BLINKIT') || txt.contains('DMART') ||
        txt.contains('SUPERMARKET') || txt.contains('KIRANA')) {
      return 'Groceries';
    }
    
    // Transportation
    if (txt.contains('FUEL') || txt.contains('PETROL') || txt.contains('DIESEL') ||
        txt.contains('UBER') || txt.contains('OLA') || txt.contains('RAPIDO') ||
        txt.contains('INDIAN OIL') || txt.contains('BHARAT PETROLEUM')) {
      return 'Transportation';
    }
    
    // Healthcare
    if (txt.contains('HOSPITAL') || txt.contains('MEDIC') || txt.contains('PHARMACY') ||
        txt.contains('APOLLO') || txt.contains('1MG') || txt.contains('PHARMEASY') ||
        txt.contains('CLINIC') || txt.contains('DOCTOR')) {
      return 'Healthcare';
    }
    
    // Entertainment
    if (txt.contains('MOVIE') || txt.contains('PVR') || txt.contains('INOX') ||
        txt.contains('NETFLIX') || txt.contains('SPOTIFY') || txt.contains('PRIME')) {
      return 'Entertainment';
    }
    
    // Bills & Utilities
    if (txt.contains('ELECTRICITY') || txt.contains('WATER') || txt.contains('GAS') ||
        txt.contains('AIRTEL') || txt.contains('JIO') || txt.contains('VI ') ||
        txt.contains('BILL') || txt.contains('RECHARGE')) {
      return 'Bills & Utilities';
    }
    
    return 'Shopping';
  }
  
  String _guessPaymentMethod(String text) {
    final txt = text.toUpperCase();
    if (txt.contains('UPI') || txt.contains('GPAY') || txt.contains('PHONEPE') || 
        txt.contains('PAYTM')) return 'UPI';
    if (txt.contains('CARD') || txt.contains('VISA') || txt.contains('MASTERCARD') ||
        txt.contains('RUPAY')) return 'Card';
    if (txt.contains('CASH') || txt.contains('PAID')) return 'Cash';
    if (txt.contains('NET BANKING') || txt.contains('NEFT') || txt.contains('IMPS')) return 'Net Banking';
    return 'Unknown';
  }

  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
