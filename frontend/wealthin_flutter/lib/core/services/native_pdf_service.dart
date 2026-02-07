import 'package:flutter/foundation.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Universal PDF Transaction Parser
/// Single powerful approach for all PDF types: Bank Statements, UPI History, PhonePe, GPay, etc.
/// Uses read_pdf_text for native text extraction (PDFBox on Android, PDFKit on iOS)
class NativePdfService {
  static final NativePdfService _instance = NativePdfService._internal();
  factory NativePdfService() => _instance;
  NativePdfService._internal();

  /// Parse any PDF and extract transactions
  Future<List<TransactionModel>> parsePdf(String path) async {
    try {
      debugPrint('[NativePdfService] Parsing PDF: $path');
      String text = await ReadPdfText.getPDFtext(path);
      
      if (text.isEmpty) {
        debugPrint('[NativePdfService] PDF text is empty');
        return [];
      }
      
      debugPrint('[NativePdfService] Extracted ${text.length} characters');
      // Log first 500 chars for debugging
      debugPrint('[NativePdfService] Sample text: ${text.substring(0, text.length > 500 ? 500 : text.length)}');
      return _parseText(text);
    } catch (e) {
      debugPrint('[NativePdfService] Error parsing PDF: $e');
      return [];
    }
  }

  List<TransactionModel> _parseText(String text) {
    List<TransactionModel> transactions = [];
    
    // Try all parsers in sequence
    // 1. PhonePe/GPay UPI format (most specific)
    transactions = _parseUpiFormat(text);
    debugPrint('[NativePdfService] UPI format found: ${transactions.length} transactions');
    
    // 2. Bank statement format (columnar with dates)
    if (transactions.isEmpty) {
      transactions = _parseBankStatement(text);
      debugPrint('[NativePdfService] Bank format found: ${transactions.length} transactions');
    }
    
    // 3. Generic line-by-line extraction
    if (transactions.isEmpty) {
      transactions = _parseGenericFormat(text);
      debugPrint('[NativePdfService] Generic format found: ${transactions.length} transactions');
    }
    
    // Deduplicate
    transactions = _deduplicateTransactions(transactions);
    
    debugPrint('[NativePdfService] Final count after dedup: ${transactions.length} transactions');
    return transactions;
  }


  /// Parse UPI apps: PhonePe, GPay, Paytm
  /// Handles multi-line formats where date, description, and amount are on separate lines
  List<TransactionModel> _parseUpiFormat(String text) {
    List<TransactionModel> transactions = [];
    
    // Normalize text
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    debugPrint('[NativePdfService] Processing ${lines.length} lines for UPI format');
    
    // PhonePe often has:
    // Line 1: Date (Jan 15, 2025 or 15 Jan 2025)
    // Line 2: Description (Paid to Zomato / Received from X)
    // Line 3: Amount (₹250.00 or 250.00)
    // Line 4+: Payment details
    
    DateTime? currentDate;
    String? currentDescription;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Try to detect date
      final dateResult = _tryParseDate(line);
      if (dateResult != null) {
        currentDate = dateResult;
        continue;
      }
      
      // Try to detect description (Paid to / Received from / UPI Payment / etc)
      if (_isDescriptionLine(line)) {
        currentDescription = line;
        continue;
      }
      
      // Try to detect amount
      final amountResult = _extractAmountFromLine(line);
      if (amountResult != null && amountResult > 0 && currentDescription != null) {
        final type = _determineType(currentDescription, null);
        final category = _categorize(currentDescription);
        final merchant = _extractMerchant(currentDescription);
        
        transactions.add(TransactionModel(
          amount: amountResult,
          description: currentDescription,
          date: currentDate ?? DateTime.now(),
          type: type,
          category: category,
          merchant: merchant,
          paymentMethod: 'UPI',
        ));
        
        // Reset for next transaction
        currentDescription = null;
      }
    }
    
    // Also try single-line patterns for other formats
    if (transactions.isEmpty) {
      transactions = _parseSingleLineUpi(normalized);
    }
    
    return transactions;
  }

  /// Check if line looks like a date
  DateTime? _tryParseDate(String line) {
    final patterns = [
      RegExp(r'^([A-Z][a-z]{2}\s+\d{1,2},?\s*\d{4})$', caseSensitive: false), // Jan 15, 2025
      RegExp(r'^(\d{1,2}\s+[A-Z][a-z]{2,8}\s+\d{4})$', caseSensitive: false), // 15 Jan 2025
      RegExp(r'^(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})$'), // 15/01/2025
      RegExp(r'^(\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2})$'), // 2025-01-15
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        return _parseDate(match.group(1)!);
      }
    }
    return null;
  }

  /// Check if line looks like a transaction description
  bool _isDescriptionLine(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('paid to') ||
           lower.startsWith('received from') ||
           lower.startsWith('payment to') ||
           lower.startsWith('transfer to') ||
           lower.startsWith('transfer from') ||
           lower.contains('upi payment') ||
           lower.contains('upi transfer') ||
           lower.contains('debit') ||
           lower.contains('credit') ||
           (line.length > 5 && line.length < 100 && !line.contains('₹') && 
            !RegExp(r'^\d+[/\-.]').hasMatch(line));
  }

  /// Extract amount from a line
  double? _extractAmountFromLine(String line) {
    final patterns = [
      RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'INR\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'^([\d,]+(?:\.\d{1,2})?)$'), // Just a number
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0 && amount < 10000000) {
            return amount;
          }
        }
      }
    }
    return null;
  }

  /// Parse single-line UPI format
  List<TransactionModel> _parseSingleLineUpi(String text) {
    List<TransactionModel> transactions = [];
    
    final patterns = [
      // "Nov 19, 2025  Description  DEBIT/CREDIT  ₹Amount"
      RegExp(
        r'([A-Z][a-z]{2}\s+\d{1,2},?\s*\d{4})\s+(.+?)\s+(CREDIT|DEBIT)\s+₹?([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      // "19/11/2025  Description  ₹Amount"
      RegExp(
        r'(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})\s+(.{5,80}?)\s+₹?([\d,]+(?:\.\d{1,2})?)',
      ),
    ];
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        try {
          final dateStr = match.group(1)!;
          final description = match.group(2)!.trim();
          final amountStr = pattern.pattern.contains('CREDIT|DEBIT') 
              ? match.group(4)! 
              : match.group(3)!;
          final typeHint = pattern.pattern.contains('CREDIT|DEBIT') 
              ? match.group(3) 
              : null;
          
          final date = _parseDate(dateStr);
          final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
          
          if (amount < 1 || amount > 10000000) continue;
          if (description.length < 3) continue;
          
          transactions.add(TransactionModel(
            amount: amount,
            description: description,
            date: date,
            type: _determineType(description, typeHint),
            category: _categorize(description),
            merchant: _extractMerchant(description),
            paymentMethod: 'UPI',
          ));
        } catch (e) {
          continue;
        }
      }
      if (transactions.isNotEmpty) break;
    }
    
    return transactions;
  }


  /// Parse traditional bank statements (columnar format)
  List<TransactionModel> _parseBankStatement(String text) {
    List<TransactionModel> transactions = [];
    final lines = text.split('\n');
    
    DateTime? lastDate;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.length < 10) continue;
      
      // Look for date at start of line
      final dateMatch = RegExp(
        r'^(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
      ).firstMatch(line);
      
      if (dateMatch != null) {
        lastDate = _parseDate(dateMatch.group(1)!);
        line = line.substring(dateMatch.end).trim();
      }
      
      // Look for amount with Dr/Cr indicator
      final amountMatch = RegExp(
        r'([\d,]+(?:\.\d{1,2})?)\s*(Dr|Cr|DR|CR)?',
        caseSensitive: false,
      ).allMatches(line);
      
      if (amountMatch.isNotEmpty && lastDate != null) {
        // Try to find the actual transaction amount (usually last or second to last)
        final matches = amountMatch.toList();
        if (matches.length >= 2) {
          // Second to last is usually transaction, last is balance
          final txMatch = matches[matches.length - 2];
          final amount = double.tryParse(txMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
          
          if (amount > 0 && amount < 10000000) {
            // Extract description
            String desc = line;
            for (var m in matches) {
              desc = desc.replaceFirst(m.group(0)!, '');
            }
            desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
            
            if (desc.length > 3) {
              final type = _determineType(desc, txMatch.group(2));
              
              transactions.add(TransactionModel(
                amount: amount,
                description: desc,
                date: lastDate,
                type: type,
                category: _categorize(desc),
                merchant: _extractMerchant(desc),
              ));
            }
          }
        }
      }
    }
    
    return transactions;
  }

  /// Generic format - extract any recognizable transactions
  List<TransactionModel> _parseGenericFormat(String text) {
    List<TransactionModel> transactions = [];
    final lines = text.split('\n');
    
    DateTime? lastDate;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Try to extract date
      final date = _extractDateFromLine(line);
      if (date != null) {
        lastDate = date;
      }
      
      // Try to extract amount
      final amountMatch = RegExp(
        r'₹\s*([\d,]+(?:\.\d{1,2})?)|Rs\.?\s*([\d,]+(?:\.\d{1,2})?)|INR\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ).firstMatch(line);
      
      if (amountMatch != null) {
        final amountStr = amountMatch.group(1) ?? amountMatch.group(2) ?? amountMatch.group(3);
        if (amountStr != null) {
          final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
          
          if (amount > 0 && amount < 10000000) {
            // Clean description
            String desc = line
                .replaceAll(RegExp(r'₹[\d,\.]+'), '')
                .replaceAll(RegExp(r'Rs\.?\s*[\d,\.]+'), '')
                .replaceAll(RegExp(r'INR\s*[\d,\.]+'), '')
                .replaceAll(RegExp(r'\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            
            if (desc.length > 3) {
              transactions.add(TransactionModel(
                amount: amount,
                description: desc,
                date: lastDate ?? DateTime.now(),
                type: _determineType(desc, null),
                category: _categorize(desc),
                merchant: _extractMerchant(desc),
                paymentMethod: 'Unknown',
              ));
            }
          }
        }
      }
    }
    
    return transactions;
  }

  /// Parse date from various formats
  DateTime _parseDate(String dateStr) {
    dateStr = dateStr.trim();
    
    // Try common date formats
    final formats = [
      // Month name formats
      DateFormat('MMM d, yyyy'),     // Nov 19, 2025
      DateFormat('MMM d yyyy'),      // Nov 19 2025
      DateFormat('d MMM yyyy'),      // 19 Nov 2025
      DateFormat('d MMM, yyyy'),     // 19 Nov, 2025
      DateFormat('MMMM d, yyyy'),    // November 19, 2025
      DateFormat('d MMMM yyyy'),     // 19 November 2025
      // Numeric formats
      DateFormat('dd/MM/yyyy'),      // 19/11/2025
      DateFormat('d/M/yyyy'),        // 9/1/2025
      DateFormat('dd-MM-yyyy'),      // 19-11-2025
      DateFormat('d-M-yyyy'),        // 9-1-2025
      DateFormat('dd.MM.yyyy'),      // 19.11.2025
      DateFormat('yyyy-MM-dd'),      // 2025-11-19
      DateFormat('dd/MM/yy'),        // 19/11/25
      DateFormat('d/M/yy'),          // 9/1/25
      DateFormat('MM/dd/yyyy'),      // 11/19/2025 (US format)
    ];
    
    for (var format in formats) {
      try {
        return format.parse(dateStr);
      } catch (_) {
        continue;
      }
    }
    
    // Manual parsing for edge cases
    final numericMatch = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(dateStr);
    if (numericMatch != null) {
      int day = int.parse(numericMatch.group(1)!);
      int month = int.parse(numericMatch.group(2)!);
      int year = int.parse(numericMatch.group(3)!);
      if (year < 100) year += 2000;
      // Swap if month > 12 (likely DD/MM vs MM/DD confusion)
      if (month > 12 && day <= 12) {
        final temp = day;
        day = month;
        month = temp;
      }
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    
    return DateTime.now();
  }

  /// Extract date from anywhere in the line
  DateTime? _extractDateFromLine(String line) {
    // Try various date patterns
    final patterns = [
      RegExp(r'([A-Z][a-z]{2}\s+\d{1,2},?\s*\d{4})', caseSensitive: false),
      RegExp(r'(\d{1,2}\s+[A-Z][a-z]{2,8}\s+\d{4})', caseSensitive: false),
      RegExp(r'(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})'),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        return _parseDate(match.group(1)!);
      }
    }
    return null;
  }

  /// Determine transaction type
  String _determineType(String description, String? typeHint) {
    final descLower = description.toLowerCase();
    final hint = typeHint?.toLowerCase();
    
    // Explicit indicators
    if (hint == 'cr' || hint == 'credit') return 'income';
    if (hint == 'dr' || hint == 'debit') return 'expense';
    
    // Keywords
    const creditKeywords = [
      'credit', 'credited', 'received', 'salary', 'refund', 'cashback',
      'reward', 'dividend', 'interest', 'bonus', 'transfer from',
    ];
    const debitKeywords = [
      'debit', 'debited', 'paid', 'payment', 'purchase', 'spent',
      'withdrawal', 'charge', 'fee', 'transfer to', 'emi',
    ];
    
    for (var kw in creditKeywords) {
      if (descLower.contains(kw)) return 'income';
    }
    for (var kw in debitKeywords) {
      if (descLower.contains(kw)) return 'expense';
    }
    
    // Default to expense
    return 'expense';
  }

  /// Categorize transaction based on description - Production ready
  String _categorize(String description) {
    final desc = description.toLowerCase();
    
    // Food & Dining - comprehensive
    if (_matchesAny(desc, [
      'swiggy', 'zomato', 'food', 'restaurant', 'cafe', 'pizza', 'burger', 'kfc', 
      'mcdonald', 'dominos', 'starbucks', 'dunkin', 'subway', 'dining', 'biryani',
      'faasos', 'box8', 'behrouz', 'eatsure', 'haldiram', 'wow momo', 'chaayos',
      'chai', 'coffee', 'tea', 'snacks', 'bakery', 'lunch', 'dinner', 'breakfast',
      'hotel bill', 'canteen', 'mess', 'dhaba', 'tiffin', 'thali', 'dosa', 'idli',
      'pav bhaji', 'chaat', 'rolls', 'momos', 'noodles', 'chinese', 'mughlai',
    ])) {
      return 'Food & Dining';
    }
    
    // Groceries
    if (_matchesAny(desc, [
      'bigbasket', 'zepto', 'blinkit', 'grocery', 'supermarket', 'dmart', 'more',
      'reliance fresh', 'spencers', 'grofers', 'jiomart', 'nature basket',
      'vegetables', 'fruits', 'milk', 'dairy', 'bread', 'eggs', 'meat', 'fish',
      'ration', 'kirana', 'provisions', 'daily needs', 'amazon fresh', 'instamart',
      'dunzo', 'aahar', 'provision store', 'general store',
    ])) {
      return 'Groceries';
    }
    
    // Transportation
    if (_matchesAny(desc, [
      'uber', 'ola', 'rapido', 'petrol', 'fuel', 'diesel', 'indian oil', 'hp ',
      'bharat petroleum', 'bpcl', 'shell', 'metro', 'irctc', 'railway', 'train',
      'bus', 'auto', 'cab', 'taxi', 'parking', 'toll', 'fastag', 'indriver',
      'blu smart', 'yulu', 'bounce', 'mswipe', 'public transport', 'local train',
      'redbus', 'ticket', 'commute',
    ])) {
      return 'Transportation';
    }
    
    // Travel
    if (_matchesAny(desc, [
      'makemytrip', 'goibibo', 'cleartrip', 'hotel', 'oyo', 'airbnb', 'trivago',
      'flight', 'booking', 'indigo', 'spicejet', 'air india', 'vistara', 'ixigo',
      'yatra', 'agoda', 'expedia', 'holiday', 'vacation', 'tour', 'resort',
      'airways', 'airlines', 'airport', 'luggage', 'visa', 'passport',
    ])) {
      return 'Travel';
    }
    
    // Shopping
    if (_matchesAny(desc, [
      'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa', 'tata cliq',
      'snapdeal', 'shopclues', 'shopping', 'mall', 'croma', 'reliance digital',
      'vijay sales', 'lenskart', 'zara', 'h&m', 'uniqlo', 'decathlon', 'nike',
      'adidas', 'puma', 'lifestyle', 'westside', 'pantaloons', 'max fashion',
      'zudio', 'trends', 'central', 'shopper stop', 'purplle', 'sugar', 'boat',
      'samsung', 'apple store', 'oneplus', 'xiaomi', 'realme', 'electronics',
    ])) {
      return 'Shopping';
    }
    
    // Entertainment
    if (_matchesAny(desc, [
      'netflix', 'spotify', 'hotstar', 'prime video', 'zee5', 'sony liv',
      'jiocinema', 'youtube', 'gaana', 'jiosaavn', 'apple music', 'audible',
      'bookmyshow', 'pvr', 'inox', 'cinepolis', 'movie', 'cinema', 'theatre',
      'gaming', 'steam', 'playstation', 'xbox', 'nintendo', 'pubg', 'dream11',
      'fantasy', 'concert', 'show', 'event', 'amusement', 'theme park', 'zoo',
      'museum', 'subscription', 'ott', 'streaming',
    ])) {
      return 'Entertainment';
    }
    
    // Bills & Utilities
    if (_matchesAny(desc, [
      'airtel', 'jio', 'vi ', 'vodafone', 'idea', 'bsnl', 'electricity', 'power',
      'water', 'gas', 'piped gas', 'png', 'broadband', 'wifi', 'internet', 'dth',
      'dish tv', 'tata sky', 'tata play', 'hathway', 'act fibernet', 'bill',
      'recharge', 'postpaid', 'prepaid', 'phone bill', 'mobile bill',
      'cylinder', 'lpg', 'connection', 'utility', 'bescom', 'msedcl', 'bses',
    ])) {
      return 'Bills & Utilities';
    }
    
    // Healthcare
    if (_matchesAny(desc, [
      'hospital', 'clinic', 'doctor', 'pharmacy', 'pharma', 'medicine', 'apollo',
      'medplus', 'netmeds', '1mg', 'pharmeasy', 'diagnostic', 'lab', 'pathology',
      'health', 'medical', 'dental', 'dentist', 'eye', 'optical', 'practo',
      'consultation', 'treatment', 'surgery', 'checkup', 'test', 'vaccine',
      'corona', 'covid', 'prescription', 'vitamin', 'supplement', 'fitness',
      'cult.fit', 'gym', 'yoga', 'wellness', 'healthifyme',
    ])) {
      return 'Healthcare';
    }
    
    // Education
    if (_matchesAny(desc, [
      'school', 'college', 'university', 'tuition', 'coaching', 'course', 'class',
      'udemy', 'coursera', 'unacademy', 'byju', 'vedantu', 'whitehat', 'skills',
      'books', 'stationery', 'pencil', 'notebook', 'exam', 'admission', 'fees',
      'library', 'kindle', 'skillshare', 'upgrad', 'internship', 'training',
      'certification', 'degree', 'diploma', 'syllabus', 'learning', 'education',
    ])) {
      return 'Education';
    }
    
    // Investment
    if (_matchesAny(desc, [
      'mutual fund', 'sip', 'zerodha', 'groww', 'upstox', 'angel', 'stocks',
      'shares', 'trading', 'demat', 'nse', 'bse', 'investment', 'nifty', 'sensex',
      'fd', 'fixed deposit', 'ppf', 'nps', 'bonds', 'gold', 'sovereign', 'etf',
      'smallcase', 'kuvera', 'indmoney', 'paytm money', 'coin', 'scripbox',
      'dividend', 'capital gain', 'folio', 'ipo', 'reit',
    ])) {
      return 'Investment';
    }
    
    // Insurance
    if (_matchesAny(desc, [
      'insurance', 'lic', 'hdfc life', 'icici pru', 'max life', 'term plan',
      'health insurance', 'motor insurance', 'car insurance', 'bike insurance',
      'policy', 'premium', 'policybazaar', 'digit', 'acko', 'navi', 'star health',
      'claim', 'cover', 'rider', 'nominee', 'maturity', 'surrender',
    ])) {
      return 'Insurance';
    }
    
    // EMI & Loans
    if (_matchesAny(desc, [
      'emi', 'loan', 'installment', 'credit card', 'bajaj finance', 'home loan',
      'car loan', 'personal loan', 'education loan', 'bnpl', 'simpl', 'lazypay',
      'principal', 'interest', 'outstanding', 'repayment', 'tenure', 'sanction',
      'disbursement', 'foreclosure', 'prepayment', 'overdue',
    ])) {
      return 'EMI & Loans';
    }
    
    // Rent & Housing
    if (_matchesAny(desc, [
      'rent', 'house rent', 'pg', 'hostel', 'accommodation', 'maintenance',
      'society', 'apartment', 'flat', 'deposit', 'caution', 'nobroker',
      'housing', 'tenant', 'landlord', 'lease', 'agreement', 'brokerage',
      'property', 'real estate', 'construction', 'renovation', 'paint',
    ])) {
      return 'Rent & Housing';
    }
    
    // Personal Care
    if (_matchesAny(desc, [
      'salon', 'spa', 'parlour', 'haircut', 'beauty', 'cosmetics', 'skincare',
      'grooming', 'urban company', 'looks', 'javed habib', 'naturals', 'enrich',
      'manicure', 'pedicure', 'facial', 'waxing', 'threading', 'massage',
      'makeover', 'hairstyle', 'barber', 'unisex',
    ])) {
      return 'Personal Care';
    }
    
    // Transfer (internal)
    if (_matchesAny(desc, [
      'transfer', 'neft', 'imps', 'rtgs', 'self transfer', 'fund transfer',
      'account transfer', 'internal', 'between accounts', 'upi transfer',
    ])) {
      return 'Transfer';
    }
    
    // Salary/Income
    if (_matchesAny(desc, [
      'salary', 'wages', 'payroll', 'bonus', 'incentive', 'stipend', 'commission',
      'freelance', 'consulting', 'received from', 'credited', 'refund', 'cashback',
      'interest credit', 'dividend', 'reward', 'earnings',
    ])) {
      return 'Income';
    }
    
    return 'Other';
  }
  
  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }


  /// Extract merchant name from description - Production ready
  String? _extractMerchant(String description) {
    final desc = description.toLowerCase();
    
    // First, clean description of amount prefixes for PhonePe format
    // E.g., "DEBIT ₹353Mobile recharged 9100036537" -> extract merchant
    String cleanDesc = description
        .replaceAll(RegExp(r'^(DEBIT|CREDIT)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'₹[\d,\.]+'), '')
        .replaceAll(RegExp(r'Rs\.?\s*[\d,\.]+'), '')
        .trim();
    
    // Known merchants - Comprehensive list
    final merchants = {
      // Food & Dining
      'swiggy': 'Swiggy', 'zomato': 'Zomato', 'dominos': "Domino's", 'pizza hut': 'Pizza Hut',
      'kfc': 'KFC', 'mcdonald': "McDonald's", 'burger king': 'Burger King', 'starbucks': 'Starbucks',
      'cafe coffee day': 'Cafe Coffee Day', 'ccd': 'Cafe Coffee Day', 'subway': 'Subway',
      'faasos': 'Faasos', 'box8': 'Box8', 'eatsure': 'EatSure', 'behrouz': 'Behrouz Biryani',
      'wow! momo': 'WOW! Momo', 'haldiram': "Haldiram's", 'barbecue nation': 'Barbeque Nation',
      'baskin robbins': 'Baskin Robbins', 'dunkin': "Dunkin'", 'chaipoint': 'Chai Point',
      'chaayos': 'Chaayos', 'third wave': 'Third Wave Coffee', 'blue tokai': 'Blue Tokai',
      
      // Groceries
      'bigbasket': 'BigBasket', 'zepto': 'Zepto', 'blinkit': 'Blinkit', 'grofers': 'Blinkit',
      'jiomart': 'JioMart', 'dmart': 'DMart', 'more supermarket': 'More Supermarket',
      'reliance fresh': 'Reliance Fresh', 'spencers': "Spencer's", 'nature basket': "Nature's Basket",
      'amazon fresh': 'Amazon Fresh', 'swiggy instamart': 'Swiggy Instamart', 'dunzo': 'Dunzo',
      
      // Shopping - E-commerce
      'amazon': 'Amazon', 'flipkart': 'Flipkart', 'myntra': 'Myntra', 'ajio': 'AJIO',
      'meesho': 'Meesho', 'nykaa': 'Nykaa', 'tata cliq': 'Tata CLiQ', 'lenskart': 'Lenskart',
      'snapdeal': 'Snapdeal', 'shopsy': 'Shopsy', 'purplle': 'Purplle', 'sugar cosmetics': 'SUGAR',
      'boat': 'boAt', 'croma': 'Croma', 'reliance digital': 'Reliance Digital',
      
      // Shopping - Fashion
      'zara': 'Zara', 'h&m': 'H&M', 'uniqlo': 'Uniqlo', 'decathlon': 'Decathlon',
      'nike': 'Nike', 'adidas': 'Adidas', 'puma': 'Puma', 'reebok': 'Reebok',
      'lifestyle': 'Lifestyle', 'westside': 'Westside', 'pantaloons': 'Pantaloons',
      'max fashion': 'Max Fashion', 'zudio': 'Zudio', 'trends': 'Trends',
      
      // Transport & Travel
      'uber': 'Uber', 'ola': 'Ola', 'rapido': 'Rapido', 'indriver': 'inDrive',
      'blu smart': 'BluSmart', 'metro': 'Metro', 'irctc': 'IRCTC', 'redbus': 'RedBus',
      'makemytrip': 'MakeMyTrip', 'goibibo': 'Goibibo', 'cleartrip': 'ClearTrip', 'ixigo': 'ixigo',
      'yatra': 'Yatra', 'oyo': 'OYO', 'airbnb': 'Airbnb', 'booking.com': 'Booking.com',
      'indigo': 'IndiGo', 'spicejet': 'SpiceJet', 'air india': 'Air India', 'vistara': 'Vistara',
      
      // Fuel
      'indian oil': 'Indian Oil', 'iocl': 'Indian Oil', 'hp': 'HP', 'hindustan petroleum': 'HP',
      'bharat petroleum': 'BPCL', 'bpcl': 'BPCL', 'shell': 'Shell', 'reliance petrol': 'Reliance Petrol',
      
      // Entertainment
      'netflix': 'Netflix', 'spotify': 'Spotify', 'amazon prime': 'Amazon Prime',
      'hotstar': 'Hotstar', 'disney+': 'Disney+ Hotstar', 'zee5': 'ZEE5', 'sonyliv': 'SonyLIV',
      'jiocinema': 'JioCinema', 'mxplayer': 'MX Player', 'youtube premium': 'YouTube Premium',
      'apple music': 'Apple Music', 'gaana': 'Gaana', 'jiosaavn': 'JioSaavn',
      'bookmyshow': 'BookMyShow', 'pvr': 'PVR', 'inox': 'INOX', 'cinepolis': 'Cinepolis',
      
      // Telecom & Utilities
      'airtel': 'Airtel', 'jio': 'Jio', 'vi': 'Vi', 'vodafone': 'Vi', 'idea': 'Vi',
      'bsnl': 'BSNL', 'act fibernet': 'ACT Fibernet', 'tata sky': 'Tata Play', 
      'dish tv': 'Dish TV', 'hathway': 'Hathway',
      
      // Payments
      'phonepe': 'PhonePe', 'paytm': 'Paytm', 'google pay': 'Google Pay', 'gpay': 'Google Pay',
      'cred': 'CRED', 'mobikwik': 'MobiKwik', 'freecharge': 'FreeCharge', 'bhim': 'BHIM',
      'simpl': 'Simpl', 'lazypay': 'LazyPay', 'amazon pay': 'Amazon Pay',
      
      // Healthcare
      'apollo': 'Apollo', '1mg': 'Tata 1mg', 'pharmeasy': 'PharmEasy', 'netmeds': 'Netmeds',
      'medplus': 'MedPlus', 'practo': 'Practo', 'cult.fit': 'Cult.fit', 'healthifyme': 'HealthifyMe',
      
      // Investment
      'zerodha': 'Zerodha', 'groww': 'Groww', 'upstox': 'Upstox', 'angel one': 'Angel One',
      'coin by zerodha': 'Coin', 'mf utility': 'MF Utility', 'kuvera': 'Kuvera',
      'smallcase': 'smallcase', 'paytm money': 'Paytm Money',
      
      // Insurance
      'policy bazaar': 'PolicyBazaar', 'policybazaar': 'PolicyBazaar', 'digit': 'Digit Insurance',
      'acko': 'ACKO', 'lic': 'LIC', 'hdfc life': 'HDFC Life', 'icici prudential': 'ICICI Prudential',
      
      // Education
      'byju': "BYJU'S", 'unacademy': 'Unacademy', 'vedantu': 'Vedantu', 'whitehat jr': 'WhiteHat Jr',
      'upgrad': 'upGrad', 'coursera': 'Coursera', 'udemy': 'Udemy', 'skillshare': 'Skillshare',
      
      // Telecom services
      'mobile recharge': 'Mobile Recharge', 'recharged': 'Mobile Recharge',
    };
    
    for (var entry in merchants.entries) {
      if (desc.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Try to extract from "Paid to X" patterns
    final paidToPatterns = [
      RegExp(r'paid to\s+([a-zA-Z][a-zA-Z0-9\s\.]+?)(?:\s+(?:via|upi|for|\@)|$)', caseSensitive: false),
      RegExp(r'payment to\s+([a-zA-Z][a-zA-Z0-9\s\.]+?)(?:\s+(?:via|upi|for|\@)|$)', caseSensitive: false),
      RegExp(r'transfer to\s+([a-zA-Z][a-zA-Z0-9\s\.]+?)(?:\s+(?:via|upi|for|\@)|$)', caseSensitive: false),
    ];
    
    for (var pattern in paidToPatterns) {
      final match = pattern.firstMatch(description);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (name.length >= 2 && name.length <= 50) {
          return _capitalize(name);
        }
      }
    }
    
    // Try to extract from "Received from X" patterns
    final receivedFromPatterns = [
      RegExp(r'received from\s+([a-zA-Z][a-zA-Z0-9\s\.]+?)(?:\s+(?:via|upi|\@)|$)', caseSensitive: false),
      RegExp(r'credit from\s+([a-zA-Z][a-zA-Z0-9\s\.]+?)(?:\s+(?:via|upi|\@)|$)', caseSensitive: false),
    ];
    
    for (var pattern in receivedFromPatterns) {
      final match = pattern.firstMatch(description);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (name.length >= 2 && name.length <= 50) {
          return _capitalize(name);
        }
      }
    }
    
    // Try to extract UPI merchant ID
    final upiMatch = RegExp(r'@([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(desc);
    if (upiMatch != null) {
      final upiId = upiMatch.group(1)!.toLowerCase();
      // Map common UPI handles to merchant names
      final upiHandles = {
        'ybl': 'PhonePe', 'ibl': 'PhonePe', 'axl': 'PhonePe',
        'okaxis': 'Google Pay', 'okhdfcbank': 'Google Pay', 'okicici': 'Google Pay', 'oksbi': 'Google Pay',
        'paytm': 'Paytm', 'ptyes': 'Paytm', 'pthdfc': 'Paytm', 'ptsbi': 'Paytm',
        'apl': 'Amazon Pay', 'amazonpay': 'Amazon Pay',
      };
      if (upiHandles.containsKey(upiId)) {
        return upiHandles[upiId];
      }
    }
    
    // For PhonePe format, try to extract name after common prefixes
    // E.g. "Mobile recharged 9100036537" -> Returns "Mobile Recharge"  
    // E.g. "Paid to VEGI RAVI TEJA" -> Extract name
    final phonepePatterns = [
      RegExp(r'Mobile recharged\s+(\d+)', caseSensitive: false),
      RegExp(r'Electricity bill\s+(.+)', caseSensitive: false),
      RegExp(r'DTH recharge\s+(.+)', caseSensitive: false),
    ];
    
    for (var pattern in phonepePatterns) {
      final match = pattern.firstMatch(cleanDesc);
      if (match != null) {
        // Return a meaningful merchant category
        if (cleanDesc.toLowerCase().contains('mobile') || cleanDesc.toLowerCase().contains('recharged')) {
          return 'Mobile Recharge';
        }
        if (cleanDesc.toLowerCase().contains('electricity')) {
          return 'Electricity Bill';
        }
        if (cleanDesc.toLowerCase().contains('dth')) {
          return 'DTH Recharge';
        }
      }
    }
    
    return null;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }


  /// Remove duplicates
  List<TransactionModel> _deduplicateTransactions(List<TransactionModel> transactions) {
    final seen = <String>{};
    final result = <TransactionModel>[];
    
    for (final tx in transactions) {
      final key = '${tx.date.toIso8601String().substring(0, 10)}_${tx.amount}_${tx.description.substring(0, tx.description.length > 15 ? 15 : tx.description.length)}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(tx);
      }
    }
    
    return result;
  }
}
