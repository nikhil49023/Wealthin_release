import 'package:flutter/foundation.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Native service for PDF parsing using read_pdf_text (wrapper for PDFBox/iOS Vision)
/// Replaces the Python PDF parsing to reduce app overhead and crashes.
class NativePdfService {
  static final NativePdfService _instance = NativePdfService._internal();

  factory NativePdfService() => _instance;

  NativePdfService._internal();

  /// Parse PDF transaction
  Future<List<TransactionModel>> parsePdf(String path) async {
    try {
      String text = await ReadPdfText.getPDFtext(path);
      if (text.isEmpty) {
        debugPrint('PDF text is empty or could not be read.');
        return [];
      }
      return _parseText(text);
    } catch (e) {
      debugPrint('Error parsing PDF natively: $e');
      return [];
    }
  }

  List<TransactionModel> _parseText(String text) {
    // Detect format
    if (text.toUpperCase().contains('PHONEPE')) {
      return _parsePhonePe(text);
    }
    
    // Fallback to generic bank statement parser
    return _parseGenericBankStatement(text);
  }

  /// Specialized parser for PhonePe statements
  List<TransactionModel> _parsePhonePe(String text) {
    List<TransactionModel> transactions = [];
    final lines = text.split('\n');

    // Regex for PhonePe: "Nov 19, 2025  Paid to Zomato  DEBIT  ₹250"
    // Dart Regex: Group 1=Date, Group 2=Desc, Group 3=Type, Group 4=Amount
    final pattern = RegExp(
      r'([A-Z][a-z]{2} \d{1,2}, \d{4})\s+(.+?)\s+(CREDIT|DEBIT)\s+₹?([\d,]+\.?\d*)', 
      caseSensitive: false
    );

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final match = pattern.firstMatch(line);
      if (match != null) {
        try {
          String dateStr = match.group(1)!;
          String desc = match.group(2)!.trim();
          String typeStr = match.group(3)!.toUpperCase();
          String amountStr = match.group(4)!.replaceAll(',', '');

          // Parse Date: "Nov 19, 2025" -> DateTime
          DateTime date;
          try {
            date = DateFormat('MMM d, yyyy').parse(dateStr);
          } catch (e) {
            date = DateTime.now();
          }

          double amount = double.tryParse(amountStr) ?? 0.0;
          String type = (typeStr == 'CREDIT') ? 'income' : 'expense';
          
          // Enhanced categorization
          String category = _guessCategory(desc);
          String? merchant;
          
          if (desc.startsWith("Paid to ")) {
            merchant = desc.substring(8);
          } else if (desc.startsWith("Received from ")) {
            merchant = desc.substring(14);
          }

          if (amount > 0) {
            transactions.add(TransactionModel(
              amount: amount,
              description: desc,
              date: date,
              type: type,
              category: category,
              merchant: merchant,
              paymentMethod: 'UPI',
            ));
          }
        } catch (e) {
          debugPrint('Error parsing PhonePe line: $e');
        }
      }
    }
    return transactions;
  }

  /// Generic parser for bank statements using common patterns
  List<TransactionModel> _parseGenericBankStatement(String text) {
    List<TransactionModel> transactions = [];
    final lines = text.split('\n');
    
    // Regex for DD/MM/YYYY or DD-MM-YYYY or DD MMM YYYY
    final datePattern = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})');
    
    // Regex for amounts like 1,234.56 or 500.00 (optionally followed by Dr/Cr)
    final amountPattern = RegExp(r'([\d,]+\.\d{2})\s*(Dr|Cr)?', caseSensitive: false);

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch != null) {
        try {
          String dateStr = dateMatch.group(1)!;
          
          // Find all potential amounts in the line
          final matches = amountPattern.allMatches(line);
          if (matches.isEmpty) continue;

          // Strategy: 
          // 1. If multiple amounts, the last one is often Balance, second to last is Tx Amount.
          // 2. If only one amount, it's likely the Tx Amount (unless it's a balance forward line).
          
          double amount = 0.0;
          String type = 'expense'; // Default
          
          if (matches.length >= 2) {
            // Assume 2nd to last is transaction, last is balance
            final txMatch = matches.elementAt(matches.length - 2);
            amount = double.parse(txMatch.group(1)!.replaceAll(',', ''));
            if (txMatch.group(2) != null) {
               type = (txMatch.group(2)!.toLowerCase() == 'cr') ? 'income' : 'expense';
            }
          } else {
            // Only one amount found
            final txMatch = matches.first;
            amount = double.parse(txMatch.group(1)!.replaceAll(',', ''));
            if (txMatch.group(2) != null) {
               type = (txMatch.group(2)!.toLowerCase() == 'cr') ? 'income' : 'expense';
            } else {
               // Heuristic: Check for "Credit" word in line
               if (line.toLowerCase().contains('credit')) type = 'income';
            }
          }

          // Description is everything else
          // Remove Date
          String desc = line.replaceAll(dateStr, '');
          // Remove amounts
          for (var m in matches) {
            desc = desc.replaceAll(line.substring(m.start, m.end), '');
          }
          desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();

          // Date Parsing
          DateTime date;
          try {
             if (dateStr.contains('/')) {
                date = DateFormat('dd/MM/yyyy').parse(dateStr);
             } else if (dateStr.contains('-')) {
                date = DateFormat('dd-MM-yyyy').parse(dateStr);
             } else {
                date = DateTime.now();
             }
          } catch (_) {
             date = DateTime.now();
          }

          if (amount > 0 && desc.length > 3) {
            transactions.add(TransactionModel(
              amount: amount,
              description: desc,
              date: date,
              type: type,
              category: _guessCategory(desc),
              isRecurring: false,
            ));
          }
        } catch (e) {
          // Skip malformed lines
        }
      }
    }
    return transactions;
  }
  
  String _guessCategory(String description) {
    String desc = description.toUpperCase();
    if (desc.contains('SWIGGY') || desc.contains('ZOMATO') || desc.contains('FOOD')) return 'Food';
    if (desc.contains('UBER') || desc.contains('OLA') || desc.contains('PETROL')) return 'Transport';
    if (desc.contains('JIO') || desc.contains('AIRTEL') || desc.contains('BILL')) return 'Utilities';
    if (desc.contains('AMAZON') || desc.contains('FLIPKART')) return 'Shopping';
    if (desc.contains('UPI')) return 'Transfer';
    return 'Uncategorized';
  }
}
