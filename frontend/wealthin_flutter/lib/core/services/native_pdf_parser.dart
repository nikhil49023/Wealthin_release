import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Document type detected from PDF
enum DocumentType {
  bankStatement,
  receipt,
  ticket,
  invoice,
  unknown
}

/// Parsed transaction result
class ParsedTransaction {
  final String date;
  final String description;
  final double amount;
  final String type; // 'expense' or 'income'
  final String category;
  final String? merchant;
  final double? confidence;

  ParsedTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    this.merchant,
    this.confidence,
  });

  Map<String, dynamic> toMap() => {
    'date': date,
    'description': description,
    'amount': amount,
    'type': type,
    'category': category,
    'merchant': merchant ?? description,
    'confidence': confidence ?? 0.8,
  };
}

/// Battle-ready native Dart PDF parser
/// Handles bank statements, receipts, tickets, invoices from any source
class NativePdfParser {
  // ==================== MAIN ENTRY POINT ====================
  
  /// Parse any PDF document and extract financial transactions
  static Future<List<Map<String, dynamic>>> parseStatement(String filePath) async {
    try {
      debugPrint('[NativePDF] ═══════════════════════════════════════');
      debugPrint('[NativePDF] Parsing: $filePath');
      
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[NativePDF] ❌ File not found');
        return [];
      }
      
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      
      final pageCount = document.pages.count;
      debugPrint('[NativePDF] 📄 Found $pageCount page(s)');
      
      if (pageCount > 50) {
        debugPrint('[NativePDF] ⚠️ PDF too large ($pageCount pages)');
        document.dispose();
        return [];
      }
      
      // Extract text from all pages
      final StringBuffer fullText = StringBuffer();
      for (int i = 0; i < pageCount; i++) {
        final text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
        fullText.writeln(text);
        debugPrint('[NativePDF] Page ${i + 1}: ${text.length} chars');
      }
      
      document.dispose();
      
      final text = fullText.toString();
      debugPrint('[NativePDF] 📝 Total extracted: ${text.length} chars');
      
      if (text.trim().isEmpty) {
        debugPrint('[NativePDF] ❌ No text extracted (scanned PDF?)');
        return [];
      }
      
      // Debug dump
      final preview = text.length > 800 ? text.substring(0, 800) : text;
      debugPrint('[NativePDF] TEXT PREVIEW:\n$preview\n...');
      
      // Detect document type
      final docType = _detectDocumentType(text);
      debugPrint('[NativePDF] 📋 Document type: ${docType.name}');
      
      // Parse based on document type
      List<ParsedTransaction> transactions;
      switch (docType) {
        case DocumentType.bankStatement:
          transactions = _parseBankStatement(text);
          break;
        case DocumentType.receipt:
          transactions = _parseReceipt(text);
          break;
        case DocumentType.ticket:
          transactions = _parseTicket(text);
          break;
        case DocumentType.invoice:
          transactions = _parseInvoice(text);
          break;
        case DocumentType.unknown:
          // Try all parsers and pick best result
          transactions = _parseGeneric(text);
          break;
      }
      
      debugPrint('[NativePDF] ✅ Parsed ${transactions.length} transactions');
      debugPrint('[NativePDF] ═══════════════════════════════════════');
      
      return transactions.map((t) => t.toMap()).toList();
      
    } catch (e, stack) {
      debugPrint('[NativePDF] ❌ Error: $e');
      debugPrint('[NativePDF] Stack: $stack');
      return [];
    }
  }
  
  // ==================== DOCUMENT TYPE DETECTION ====================
  
  static DocumentType _detectDocumentType(String text) {
    final lower = text.toLowerCase();
    
    // Bank statement indicators
    final bankKeywords = [
      'statement', 'account summary', 'transaction history', 
      'opening balance', 'closing balance', 'available balance',
      'phonepe', 'paytm', 'gpay', 'google pay', 'hdfc', 'sbi', 
      'icici', 'axis', 'kotak', 'bank', 'debit', 'credit',
      'upi', 'imps', 'neft', 'rtgs'
    ];
    
    // Receipt indicators
    final receiptKeywords = [
      'receipt', 'invoice no', 'bill no', 'order id', 'tax invoice',
      'subtotal', 'grand total', 'cgst', 'sgst', 'igst', 'gst',
      'payment successful', 'thank you for', 'purchase'
    ];
    
    // Ticket indicators
    final ticketKeywords = [
      'ticket', 'booking', 'pnr', 'seat', 'passenger', 'boarding',
      'flight', 'train', 'bus', 'departure', 'arrival', 'journey',
      'irctc', 'makemytrip', 'goibibo', 'redbus', 'ixigo'
    ];
    
    // Invoice indicators
    final invoiceKeywords = [
      'invoice', 'bill to', 'ship to', 'due date', 'payment terms',
      'amount due', 'total due', 'balance due'
    ];
    
    int bankScore = bankKeywords.where((k) => lower.contains(k)).length;
    int receiptScore = receiptKeywords.where((k) => lower.contains(k)).length;
    int ticketScore = ticketKeywords.where((k) => lower.contains(k)).length;
    int invoiceScore = invoiceKeywords.where((k) => lower.contains(k)).length;
    
    debugPrint('[NativePDF] Scores - Bank: $bankScore, Receipt: $receiptScore, Ticket: $ticketScore, Invoice: $invoiceScore');
    
    if (bankScore >= 3 || bankScore > receiptScore && bankScore > ticketScore) {
      return DocumentType.bankStatement;
    } else if (ticketScore >= 2 && ticketScore >= receiptScore) {
      return DocumentType.ticket;
    } else if (invoiceScore >= 2 && invoiceScore > receiptScore) {
      return DocumentType.invoice;
    } else if (receiptScore >= 2) {
      return DocumentType.receipt;
    }
    
    return DocumentType.unknown;
  }
  
  // ==================== BANK STATEMENT PARSER ====================
  
  static List<ParsedTransaction> _parseBankStatement(String text) {
    final lower = text.toLowerCase();
    final transactions = <ParsedTransaction>[];
    
    // Detect specific bank/app
    String source = 'UNKNOWN';
    final sources = {
      'PHONEPE': ['phonepe', 'phone pe'],
      'PAYTM': ['paytm'],
      'GPAY': ['google pay', 'gpay', 'g-pay'],
      'HDFC': ['hdfc bank', 'hdfcbank'],
      'SBI': ['state bank of india', 'sbi '],
      'ICICI': ['icici bank', 'icicibank'],
      'AXIS': ['axis bank', 'axisbank'],
      'KOTAK': ['kotak mahindra', 'kotak bank'],
      'YES': ['yes bank'],
      'BOB': ['bank of baroda'],
      'PNB': ['punjab national bank', 'pnb'],
      'CANARA': ['canara bank'],
      'IDBI': ['idbi bank'],
      'IDFC': ['idfc first', 'idfc bank'],
      'FEDERAL': ['federal bank'],
      'INDUSIND': ['indusind bank'],
      'RBL': ['rbl bank'],
      'CRED': ['cred'],
      'AMAZON_PAY': ['amazon pay'],
      'FREECHARGE': ['freecharge'],
      'MOBIKWIK': ['mobikwik'],
    };
    
    for (final entry in sources.entries) {
      if (entry.value.any((k) => lower.contains(k))) {
        source = entry.key;
        break;
      }
    }
    
    debugPrint('[NativePDF] 🏦 Source detected: $source');
    
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    // Try source-specific parser first
    if (['PHONEPE', 'PAYTM', 'GPAY', 'AMAZON_PAY'].contains(source)) {
      transactions.addAll(_parseUPIStatement(lines, source));
    } else if (['HDFC', 'SBI', 'ICICI', 'AXIS', 'KOTAK', 'YES', 'BOB', 'PNB', 'CANARA', 'IDBI', 'IDFC', 'FEDERAL', 'INDUSIND', 'RBL'].contains(source)) {
      transactions.addAll(_parseTraditionalBankStatement(lines, source));
    }
    
    // Fallback to generic parser if nothing found
    if (transactions.isEmpty) {
      transactions.addAll(_parseGenericStatement(lines));
    }
    
    return _deduplicateTransactions(transactions);
  }
  
  /// Parse UPI app statements (PhonePe, Paytm, GPay, Amazon Pay)
  static List<ParsedTransaction> _parseUPIStatement(List<String> lines, String source) {
    debugPrint('[NativePDF] Using UPI statement parser for $source');
    final transactions = <ParsedTransaction>[];
    
    // Common patterns for UPI statements
    // Format typically: Date -> Time -> Type -> Amount -> Description
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Try to find date patterns
      final dateMatch = _extractDate(line);
      if (dateMatch != null) {
        // Look ahead for transaction details
        String? txType;
        double? amount;
        String? description;
        
        for (int j = i + 1; j < (i + 10).clamp(0, lines.length); j++) {
          final nextLine = lines[j];
          
          // Check for transaction type
          if (txType == null) {
            if (nextLine.toUpperCase() == 'DEBIT' || nextLine.toLowerCase().contains('debited')) {
              txType = 'expense';
            } else if (nextLine.toUpperCase() == 'CREDIT' || nextLine.toLowerCase().contains('credited')) {
              txType = 'income';
            }
          }
          
          // Check for amount
          if (amount == null) {
            final amtMatch = _extractAmount(nextLine);
            if (amtMatch != null && amtMatch > 0) {
              amount = amtMatch;
            }
          }
          
          // Check for description (after finding amount)
          if (description == null && amount != null) {
            final desc = _extractDescription(nextLine);
            if (desc != null) {
              description = desc;
              break; // Found description, stop looking
            }
          }
        }
        
        // Create transaction if we have enough data
        if (amount != null && amount >= 1) {
          txType ??= 'expense'; // Default to expense
          description ??= '$source Transaction';
          
          transactions.add(ParsedTransaction(
            date: dateMatch,
            description: description,
            amount: amount,
            type: txType,
            category: _categorize(description, amount),
            merchant: description,
            confidence: 0.85,
          ));
        }
      }
    }
    
    return transactions;
  }
  
  /// Parse traditional bank statements (HDFC, SBI, ICICI, etc.)
  static List<ParsedTransaction> _parseTraditionalBankStatement(List<String> lines, String source) {
    debugPrint('[NativePDF] Using traditional bank parser for $source');
    final transactions = <ParsedTransaction>[];
    
    String? lastDate;
    
    for (final line in lines) {
      // Try to extract date
      final dateMatch = _extractDate(line);
      if (dateMatch != null) {
        lastDate = dateMatch;
      }
      
      // Try to extract amount from line
      final amounts = _extractAllAmounts(line);
      if (amounts.isNotEmpty && lastDate != null) {
        // Find the most likely transaction amount (usually the largest or last)
        double amount = amounts.last;
        if (amount < 1 || amount > 10000000) continue;
        
        // Determine type from context
        String txType = 'expense';
        final lineLower = line.toLowerCase();
        if (lineLower.contains('cr') || lineLower.contains('credit') || 
            lineLower.contains('deposit') || lineLower.contains('received') ||
            line.contains('+')) {
          txType = 'income';
        }
        
        // Extract description
        String description = _cleanDescription(line);
        if (description.length < 3) description = '$source Transaction';
        
        transactions.add(ParsedTransaction(
          date: lastDate,
          description: description,
          amount: amount,
          type: txType,
          category: _categorize(description, amount),
          merchant: description,
          confidence: 0.75,
        ));
      }
    }
    
    return transactions;
  }
  
  /// Generic statement parser - last resort
  static List<ParsedTransaction> _parseGenericStatement(List<String> lines) {
    debugPrint('[NativePDF] Using generic statement parser');
    final transactions = <ParsedTransaction>[];
    
    String? lastDate;
    
    for (final line in lines) {
      // Skip very short lines
      if (line.length < 5) continue;
      
      // Try to extract date
      final dateMatch = _extractDate(line);
      if (dateMatch != null) {
        lastDate = dateMatch;
      }
      
      // Look for amount in line
      final amount = _extractAmount(line);
      if (amount != null && amount >= 10 && amount <= 10000000) {
        final lineLower = line.toLowerCase();
        final isCredit = lineLower.contains('cr') || lineLower.contains('credit') || 
                        lineLower.contains('+') || lineLower.contains('received');
        
        final description = _cleanDescription(line);
        if (description.length < 3) continue;
        
        transactions.add(ParsedTransaction(
          date: lastDate ?? DateTime.now().toIso8601String().substring(0, 10),
          description: description,
          amount: amount,
          type: isCredit ? 'income' : 'expense',
          category: _categorize(description, amount),
          merchant: description,
          confidence: 0.6,
        ));
      }
    }
    
    return transactions;
  }
  
  // ==================== RECEIPT PARSER ====================
  
  static List<ParsedTransaction> _parseReceipt(String text) {
    debugPrint('[NativePDF] Using receipt parser');
    final transactions = <ParsedTransaction>[];
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    // Find merchant name (usually at top or has specific patterns)
    String? merchantName;
    String? date;
    double? totalAmount;
    
    for (int i = 0; i < lines.length && i < 20; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();
      
      // Extract merchant (look for company-like patterns)
      if (merchantName == null && i < 5) {
        final amt = _extractAmount(line);
        if (line.length > 3 && line.length < 50 && 
            !lineLower.contains('receipt') && !lineLower.contains('invoice') &&
            amt == null) {
          // Could be merchant name
          if (RegExp(r'^[A-Z]').hasMatch(line)) {
            merchantName = line;
          }
        }
      }
      
      // Extract date
      if (date == null) {
        date = _extractDate(line);
      }
      
      // Extract total (look for keywords)
      if (totalAmount == null) {
        if (lineLower.contains('total') || lineLower.contains('grand total') ||
            lineLower.contains('amount') || lineLower.contains('paid')) {
          totalAmount = _extractAmount(line);
        }
      }
    }
    
    // If no total found, look for the largest amount
    if (totalAmount == null) {
      double maxAmount = 0;
      for (final line in lines) {
        final amt = _extractAmount(line);
        if (amt != null && amt > maxAmount && amt < 10000000) {
          maxAmount = amt;
        }
      }
      if (maxAmount > 0) totalAmount = maxAmount;
    }
    
    if (totalAmount != null && totalAmount > 0) {
      transactions.add(ParsedTransaction(
        date: date ?? DateTime.now().toIso8601String().substring(0, 10),
        description: merchantName ?? 'Receipt Purchase',
        amount: totalAmount,
        type: 'expense',
        category: _categorize(merchantName ?? text, totalAmount),
        merchant: merchantName,
        confidence: 0.9,
      ));
    }
    
    return transactions;
  }
  
  // ==================== TICKET PARSER ====================
  
  static List<ParsedTransaction> _parseTicket(String text) {
    debugPrint('[NativePDF] Using ticket parser');
    final transactions = <ParsedTransaction>[];
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final lower = text.toLowerCase();
    
    String? date;
    double? amount;
    String description = 'Ticket Booking';
    String category = 'Travel';
    
    // Detect ticket type
    if (lower.contains('flight') || lower.contains('airline') || lower.contains('boarding')) {
      description = 'Flight Ticket';
      category = 'Travel';
    } else if (lower.contains('train') || lower.contains('irctc') || lower.contains('pnr')) {
      description = 'Train Ticket';
      category = 'Travel';
    } else if (lower.contains('bus') || lower.contains('redbus')) {
      description = 'Bus Ticket';
      category = 'Travel';
    } else if (lower.contains('movie') || lower.contains('cinema') || lower.contains('bookmyshow')) {
      description = 'Movie Ticket';
      category = 'Entertainment';
    } else if (lower.contains('event') || lower.contains('concert') || lower.contains('show')) {
      description = 'Event Ticket';
      category = 'Entertainment';
    }
    
    // Extract details
    for (final line in lines) {
      if (date == null) {
        date = _extractDate(line);
      }
      
      final lineLower = line.toLowerCase();
      if (amount == null && (lineLower.contains('total') || lineLower.contains('fare') || 
          lineLower.contains('amount') || lineLower.contains('price'))) {
        amount = _extractAmount(line);
      }
    }
    
    // Fallback: find largest amount
    if (amount == null) {
      double maxAmount = 0;
      for (final line in lines) {
        final amt = _extractAmount(line);
        if (amt != null && amt > maxAmount && amt < 1000000) {
          maxAmount = amt;
        }
      }
      if (maxAmount > 0) amount = maxAmount;
    }
    
    if (amount != null && amount > 0) {
      transactions.add(ParsedTransaction(
        date: date ?? DateTime.now().toIso8601String().substring(0, 10),
        description: description,
        amount: amount,
        type: 'expense',
        category: category,
        merchant: description,
        confidence: 0.85,
      ));
    }
    
    return transactions;
  }
  
  // ==================== INVOICE PARSER ====================
  
  static List<ParsedTransaction> _parseInvoice(String text) {
    debugPrint('[NativePDF] Using invoice parser');
    // Similar to receipt parser but looks for invoice-specific patterns
    return _parseReceipt(text); // Reuse receipt logic
  }
  
  // ==================== GENERIC PARSER ====================
  
  static List<ParsedTransaction> _parseGeneric(String text) {
    debugPrint('[NativePDF] Using generic fallback parser');
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    // Try all approaches and merge results
    final results = <ParsedTransaction>[];
    
    results.addAll(_parseGenericStatement(lines));
    
    // Also try to find a single total if statement parsing found nothing
    if (results.isEmpty) {
      double? maxAmount;
      String? date;
      
      for (final line in lines) {
        date ??= _extractDate(line);
        final amt = _extractAmount(line);
        if (amt != null && (maxAmount == null || amt > maxAmount) && amt < 10000000) {
          maxAmount = amt;
        }
      }
      
      if (maxAmount != null && maxAmount > 0) {
        results.add(ParsedTransaction(
          date: date ?? DateTime.now().toIso8601String().substring(0, 10),
          description: 'Document Transaction',
          amount: maxAmount,
          type: 'expense',
          category: 'Other',
          merchant: 'Unknown',
          confidence: 0.5,
        ));
      }
    }
    
    return results;
  }
  
  // ==================== UTILITY FUNCTIONS ====================
  
  /// Extract date from text - supports many formats
  static String? _extractDate(String text) {
    final monthMap = {
      'jan': '01', 'january': '01',
      'feb': '02', 'february': '02',
      'mar': '03', 'march': '03',
      'apr': '04', 'april': '04',
      'may': '05',
      'jun': '06', 'june': '06',
      'jul': '07', 'july': '07',
      'aug': '08', 'august': '08',
      'sep': '09', 'sept': '09', 'september': '09',
      'oct': '10', 'october': '10',
      'nov': '11', 'november': '11',
      'dec': '12', 'december': '12',
    };
    
    // Patterns in order of specificity
    final patterns = [
      // MMM DD, YYYY (Jan 29, 2026)
      RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2})[,.]?\s*(\d{4})', caseSensitive: false),
      // DD MMM YYYY (29 Jan 2026)
      RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+(\d{4})', caseSensitive: false),
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})'),
      // YYYY-MM-DD (ISO)
      RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})'),
      // DD/MM/YY
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2})\b'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          String day, month, year;
          final groups = match.groups([1, 2, 3]);
          
          if (groups[0] != null && RegExp(r'^[a-zA-Z]').hasMatch(groups[0]!)) {
            // MMM DD, YYYY format
            final monthKey = groups[0]!.toLowerCase().substring(0, 3);
            month = monthMap[monthKey] ?? '01';
            day = groups[1]!.padLeft(2, '0');
            year = groups[2]!;
          } else if (groups[1] != null && RegExp(r'^[a-zA-Z]').hasMatch(groups[1]!)) {
            // DD MMM YYYY format
            day = groups[0]!.padLeft(2, '0');
            final monthKey = groups[1]!.toLowerCase().substring(0, 3);
            month = monthMap[monthKey] ?? '01';
            year = groups[2]!;
          } else if (groups[0]!.length == 4) {
            // YYYY-MM-DD format
            year = groups[0]!;
            month = groups[1]!.padLeft(2, '0');
            day = groups[2]!.padLeft(2, '0');
          } else {
            // DD/MM/YYYY or DD/MM/YY
            day = groups[0]!.padLeft(2, '0');
            month = groups[1]!.padLeft(2, '0');
            year = groups[2]!.length == 4 ? groups[2]! : '20${groups[2]}';
          }
          
          // Validate
          final d = int.tryParse(day);
          final m = int.tryParse(month);
          final y = int.tryParse(year);
          if (d != null && m != null && y != null && d >= 1 && d <= 31 && m >= 1 && m <= 12 && y >= 2000) {
            return '$year-$month-$day';
          }
        } catch (_) {}
      }
    }
    
    return null;
  }
  
  /// Extract a single amount from text
  static double? _extractAmount(String text) {
    final patterns = [
      // ₹1,234.56 or ₹ 1,234.56
      RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)'),
      // Rs. 1,234.56 or Rs 1234
      RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // INR 1,234.56
      RegExp(r'INR\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      // 1,234.56 Cr/Dr
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:Cr|Dr|CR|DR)\b'),
      // +/- amount
      RegExp(r'[+\-]\s*₹?\s*([\d,]+(?:\.\d{1,2})?)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amtStr = match.group(1)?.replaceAll(',', '');
        if (amtStr != null) {
          final amt = double.tryParse(amtStr);
          if (amt != null && amt > 0) return amt;
        }
      }
    }
    
    return null;
  }
  
  /// Extract all amounts from text
  static List<double> _extractAllAmounts(String text) {
    final amounts = <double>[];
    final pattern = RegExp(r'[\d,]+(?:\.\d{1,2})?');
    
    for (final match in pattern.allMatches(text)) {
      final amtStr = match.group(0)?.replaceAll(',', '');
      if (amtStr != null) {
        final amt = double.tryParse(amtStr);
        if (amt != null && amt >= 1 && amt <= 10000000) {
          amounts.add(amt);
        }
      }
    }
    
    return amounts;
  }
  
  /// Extract description from line
  static String? _extractDescription(String text) {
    // Skip metadata lines
    final skipPatterns = [
      'transaction id', 'utr no', 'reference no', 'ref no',
      'paid by', 'credited to', 'debited from', 'xxxx',
      'page', 'date', 'amount', 'balance', 'upi',
      'support', 'help', 'contact', 'generated',
    ];
    
    final lower = text.toLowerCase();
    if (skipPatterns.any((p) => lower.contains(p))) return null;
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(text)) return null; // Time pattern
    if (text.length < 4) return null;
    
    // Look for description patterns
    final patterns = [
      RegExp(r'Paid to\s+(.+)', caseSensitive: false),
      RegExp(r'Received from\s+(.+)', caseSensitive: false),
      RegExp(r'Transfer to\s+(.+)', caseSensitive: false),
      RegExp(r'Payment to\s+(.+)', caseSensitive: false),
      RegExp(r'Recharge\s+(.+)', caseSensitive: false),
      RegExp(r'Bill Payment\s+(.+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    
    // Return cleaned text as description
    if (text.length > 5 && text.length < 100) {
      return text.length > 60 ? text.substring(0, 60) : text;
    }
    
    return null;
  }
  
  /// Clean a line to get description
  static String _cleanDescription(String text) {
    // Remove amounts, dates, and common noise
    String cleaned = text
      .replaceAll(RegExp(r'₹[\d,\.]+'), '')
      .replaceAll(RegExp(r'Rs\.?\s*[\d,\.]+', caseSensitive: false), '')
      .replaceAll(RegExp(r'INR\s*[\d,\.]+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}'), '')
      .replaceAll(RegExp(r'\d{1,2}:\d{2}(:\d{2})?(\s*[AP]M)?', caseSensitive: false), '')
      .replaceAll(RegExp(r'Cr|Dr|CR|DR'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
    
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }
  
  /// Categorize transaction based on description
  static String _categorize(String desc, double amount) {
    final lower = desc.toLowerCase();
    
    final categories = {
      'Food': ['swiggy', 'zomato', 'dominos', 'pizza', 'restaurant', 'food', 'juice', 'tiffin', 'cafe', 'kitchen', 'biryani', 'burger', 'kfc', 'mcdonalds', 'starbucks', 'dunkin'],
      'Shopping': ['amazon', 'flipkart', 'myntra', 'jiomart', 'market', 'store', 'shop', 'mall', 'fashion', 'apparel', 'cloth'],
      'Groceries': ['bigbasket', 'zepto', 'blinkit', 'vegetable', 'grocery', 'grofers', 'instamart', 'dunzo', 'milk', 'dairy'],
      'Transport': ['uber', 'ola', 'rapido', 'irctc', 'metro', 'petrol', 'fuel', 'parking', 'toll', 'cab', 'auto', 'bike'],
      'Entertainment': ['netflix', 'spotify', 'hotstar', 'prime', 'movie', 'game', 'bookmyshow', 'pvr', 'inox', 'youtube', 'disney'],
      'Bills': ['airtel', 'jio', 'bsnl', 'vodafone', 'electricity', 'water', 'gas', 'bill', 'recharge', 'postpaid', 'prepaid', 'broadband', 'wifi'],
      'Healthcare': ['apollo', 'pharmeasy', 'medplus', 'hospital', 'clinic', 'pharmacy', 'medicine', 'doctor', 'health', 'netmeds', '1mg'],
      'Travel': ['makemytrip', 'goibibo', 'oyo', 'hotel', 'flight', 'booking', 'travel', 'trip', 'airways', 'airlines', 'indigo', 'spicejet'],
      'Investments': ['zerodha', 'groww', 'mutual', 'fund', 'stock', 'share', 'sip', 'investment', 'trading'],
      'Insurance': ['lic', 'icici prudential', 'insurance', 'policy', 'premium'],
      'Education': ['course', 'udemy', 'coursera', 'school', 'college', 'tuition', 'education', 'book', 'stationery'],
      'Rent': ['rent', 'landlord', 'housing', 'maintenance', 'society'],
      'Salary': ['salary', 'payroll', 'income', 'credited'],
      'Transfer': ['transfer', 'sent to', 'paid to', 'upi', 'neft', 'imps', 'rtgs'],
    };
    
    for (final entry in categories.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) {
        return entry.key;
      }
    }
    
    // Size-based categorization
    if (amount > 50000) return 'Large Expense';
    if (amount > 10000) return 'Major Expense';
    
    return 'Other';
  }
  
  /// Remove duplicate transactions
  static List<ParsedTransaction> _deduplicateTransactions(List<ParsedTransaction> transactions) {
    final seen = <String>{};
    final unique = <ParsedTransaction>[];
    
    for (final tx in transactions) {
      final descPrefix = tx.description.length > 15 ? tx.description.substring(0, 15) : tx.description;
      final key = '${tx.date}_${tx.amount}_$descPrefix';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(tx);
      }
    }
    
    // Sort by date descending
    unique.sort((a, b) => b.date.compareTo(a.date));
    
    return unique;
  }
}
