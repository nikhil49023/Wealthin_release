import 'dart:convert';
import 'package:serverpod/serverpod.dart' hide Transaction;
import '../services/zoho_service.dart';
import '../generated/protocol.dart';
import 'package:http/http.dart' as http;

/// TransactionImportEndpoint: Handle document-based transaction imports
/// Supports: Vision (handwritten/bills), PDF extraction, Bank statements
class TransactionImportEndpoint extends Endpoint {
  static const String _pythonSidecarUrl = 'http://localhost:8000';

  /// Extract transactions from an image using Vision model (for handwritten/bills)
  Future<Map<String, dynamic>> extractFromImage(
    Session session,
    String imageBase64,
    String mimeType,
    int userId,
  ) async {
    try {
      session.log('Extracting transactions from image using Vision model');

      // Use Zoho Vision model for OCR
      const ocrPrompt =
          '''You are an expert at extracting financial transactions from images.
Analyze this image and extract all transactions you can find.
For each transaction, provide:
- description: What the transaction is for
- date: The date in YYYY-MM-DD format
- type: Either "income" or "expense"
- amount: The numeric amount (no currency symbols)

Return ONLY a valid JSON array of transactions.''';

      final rawText = await ZohoService().visionChat(ocrPrompt, [imageBase64]);

      // Parse the extracted transactions
      final transactions = _parseTransactions(rawText);

      return {
        'success': true,
        'source': 'vision',
        'transactions': transactions,
        'raw_text': rawText,
      };
    } catch (e) {
      session.log('Vision extraction error: $e', level: LogLevel.error);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Extract transactions from a PDF using Python sidecar
  Future<Map<String, dynamic>> extractFromPdf(
    Session session,
    String pdfBase64,
    int userId,
  ) async {
    try {
      session.log('Extracting transactions from PDF');

      // Call Python sidecar to extract text from PDF
      final response = await http.post(
        Uri.parse('$_pythonSidecarUrl/transactions/extract-text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'document_base64': pdfBase64,
          'source': 'pdf',
          'mime_type': 'application/pdf',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Python sidecar error: ${response.body}');
      }

      final promptData = jsonDecode(response.body) as Map<String, dynamic>;

      // Use the LLM to structure the extracted text
      final structuredResponse = await ZohoService().chat(
        promptData['system_prompt'] as String,
        promptData['user_prompt'] as String,
      );

      final transactions = _parseTransactions(structuredResponse);

      return {
        'success': true,
        'source': 'pdf',
        'transactions': transactions,
      };
    } catch (e) {
      session.log('PDF extraction error: $e', level: LogLevel.error);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Import extracted transactions to database
  Future<Map<String, dynamic>> importTransactions(
    Session session,
    List<Map<String, dynamic>> transactionData,
    int userId,
  ) async {
    try {
      int imported = 0;
      int skipped = 0;

      for (final td in transactionData) {
        try {
          // Check for duplicates
          final existing = await Transaction.db.findFirstRow(
            session,
            where: (t) =>
                t.userProfileId.equals(userId) &
                t.amount.equals((td['amount'] as num).toDouble()) &
                t.description.equals(td['description'] as String),
          );

          if (existing != null) {
            skipped++;
            continue;
          }

          // Parse date
          DateTime transactionDate;
          try {
            transactionDate = DateTime.parse(td['date'] as String);
          } catch (e) {
            transactionDate = DateTime.now();
          }

          final transaction = Transaction(
            amount: (td['amount'] as num).toDouble(),
            description: td['description'] as String,
            date: transactionDate,
            type: td['type'] as String,
            category: _inferCategory(td['description'] as String),
            userProfileId: userId,
          );

          await Transaction.db.insertRow(session, transaction);
          imported++;
        } catch (e) {
          session.log(
            'Error importing transaction: $e',
            level: LogLevel.warning,
          );
          skipped++;
        }
      }

      return {
        'success': true,
        'imported': imported,
        'skipped': skipped,
        'total': transactionData.length,
      };
    } catch (e) {
      session.log('Import error: $e', level: LogLevel.error);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Parse transactions from LLM response
  List<Map<String, dynamic>> _parseTransactions(String response) {
    try {
      // Find JSON array in response
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!) as List<dynamic>;
        return parsed.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Failed to parse
    }
    return [];
  }

  /// Infer category from description
  String _inferCategory(String description) {
    final desc = description.toLowerCase();

    // Food & Dining
    if (desc.contains('food') ||
        desc.contains('restaurant') ||
        desc.contains('swiggy') ||
        desc.contains('zomato') ||
        desc.contains('cafe') ||
        desc.contains('pizza') ||
        desc.contains('grocery') ||
        desc.contains('supermarket')) {
      return 'Food & Dining';
    }

    // Transport
    if (desc.contains('uber') ||
        desc.contains('ola') ||
        desc.contains('petrol') ||
        desc.contains('fuel') ||
        desc.contains('metro') ||
        desc.contains('bus') ||
        desc.contains('flight') ||
        desc.contains('train')) {
      return 'Transport';
    }

    // Bills & Utilities
    if (desc.contains('electricity') ||
        desc.contains('water') ||
        desc.contains('gas') ||
        desc.contains('internet') ||
        desc.contains('phone') ||
        desc.contains('mobile') ||
        desc.contains('recharge') ||
        desc.contains('bill')) {
      return 'Bills & Utilities';
    }

    // Shopping
    if (desc.contains('amazon') ||
        desc.contains('flipkart') ||
        desc.contains('myntra') ||
        desc.contains('shopping') ||
        desc.contains('clothes') ||
        desc.contains('electronics')) {
      return 'Shopping';
    }

    // Entertainment
    if (desc.contains('movie') ||
        desc.contains('netflix') ||
        desc.contains('spotify') ||
        desc.contains('game') ||
        desc.contains('subscription')) {
      return 'Entertainment';
    }

    // Healthcare
    if (desc.contains('doctor') ||
        desc.contains('hospital') ||
        desc.contains('medicine') ||
        desc.contains('pharmacy') ||
        desc.contains('medical')) {
      return 'Healthcare';
    }

    // Salary/Income
    if (desc.contains('salary') ||
        desc.contains('income') ||
        desc.contains('payment received') ||
        desc.contains('credit')) {
      return 'Salary';
    }

    return 'Other';
  }

  /// Get import history for a user
  Future<Map<String, dynamic>> getImportStats(
    Session session,
    int userId,
  ) async {
    final transactions = await Transaction.db.find(
      session,
      where: (t) => t.userProfileId.equals(userId),
    );

    final categoryCount = <String, int>{};
    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in transactions) {
      categoryCount[t.category] = (categoryCount[t.category] ?? 0) + 1;
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    return {
      'total_transactions': transactions.length,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'categories': categoryCount,
    };
  }
}
