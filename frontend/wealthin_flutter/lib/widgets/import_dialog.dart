import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import '../core/services/backend_config.dart';
import '../core/services/data_service.dart';
import '../core/services/python_bridge_service.dart';
import '../core/models/models.dart';

/// Dialog for importing transactions from PDF/Image files
/// - PDF icon: For structured bank statements (HDFC, SBI, ICICI, Axis)
/// - Image icon: For receipts, handwritten notes, scanned documents
class ImportTransactionsDialog extends StatefulWidget {
  final String userId;

  const ImportTransactionsDialog({
    super.key,
    required this.userId,
  });

  @override
  State<ImportTransactionsDialog> createState() =>
      _ImportTransactionsDialogState();
}

class _ImportTransactionsDialogState extends State<ImportTransactionsDialog> {
  bool _isLoading = false;
  String? _fileName;
  Uint8List? _fileBytes;
  String _importType = ''; // 'pdf' or 'image'
  List<Map<String, dynamic>> _extractedTransactions = [];
  String? _error;
  bool _showPreview = false;
  String? _bankDetected;

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _fileName = file.name;
            _fileBytes = file.bytes;
            _importType = 'pdf';
            _error = null;
          });
          await _extractFromPdf();
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick PDF: $e';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _fileName = file.name;
            _fileBytes = file.bytes;
            _importType = 'image';
            _error = null;
          });
          await _extractFromImage();
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _extractFromPdf() async {
    if (_fileBytes == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Save PDF to temp file
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}/statement_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(_fileBytes!);

        debugPrint('[ImportDialog] PDF saved to: $tempPath');

        // Use DataService which calls Python backend (pdfplumber)
        final transactions = await dataService.scanBankStatement(tempPath);

        List<Map<String, dynamic>> transactionMaps = [];
        if (transactions.isNotEmpty) {
          transactionMaps = transactions
              .map(
                (tx) => {
                  'date': tx.date.toIso8601String().substring(0, 10),
                  'description': tx.description,
                  'amount': tx.amount,
                  'type': tx.type,
                  'category': tx.category,
                  'merchant': tx.merchant,
                },
              )
              .toList()
              .cast<Map<String, dynamic>>();
        }

        // Clean up temp file
        try {
          await tempFile.delete();
        } catch (_) {}

        if (transactionMaps.isNotEmpty) {
          setState(() {
            _bankDetected = _detectBank(_fileName);
            _extractedTransactions = transactionMaps;
            _showPreview = true;
            _isLoading = false;
          });
          debugPrint(
            '[ImportDialog] Found ${transactionMaps.length} transactions',
          );
        } else {
          throw Exception(
            'No transactions found. Ensure the PDF has selectable text with dates and amounts.',
          );
        }
      } else {
        // === Desktop: Use HTTP backend ===
        final uri = Uri.parse(
          '${backendConfig.baseUrl}/transactions/import/pdf?user_id=${widget.userId}',
        );
        final request = http.MultipartRequest('POST', uri);

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _fileBytes!,
            filename: _fileName ?? 'statement.pdf',
            contentType: MediaType('application', 'pdf'),
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _bankDetected = data['bank_detected'];
            _extractedTransactions = List<Map<String, dynamic>>.from(
              data['transactions'] ?? [],
            );
            _showPreview = true;
            _isLoading = false;
          });
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(
            errorData['detail'] ?? 'Failed to extract transactions',
          );
        }
      }

      if (_extractedTransactions.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No transactions found in the PDF. Try a different bank statement.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to extract from PDF: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _extractFromImage() async {
    if (_fileBytes == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Use Python bridge for image OCR
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$_fileName');
        await tempFile.writeAsBytes(_fileBytes!);

        // Use Python bridge for receipt extraction
        final result = await pythonBridge.executeTool(
          'extract_receipt',
          {'file_path': tempFile.path},
        );

        setState(() {
          if (result['success'] == true && result['transaction'] != null) {
            _extractedTransactions = [
              result['transaction'] as Map<String, dynamic>,
            ];
          } else {
            _error =
                result['error']?.toString() ?? 'Failed to extract from image';
          }
          _showPreview = true;
          _isLoading = false;
        });
      } else {
        // Original HTTP logic
        final uri = Uri.parse(
          '${backendConfig.baseUrl}/transactions/import/image?user_id=${widget.userId}',
        );
        final request = http.MultipartRequest('POST', uri);

        final extension = _fileName?.split('.').last ?? 'jpg';
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _fileBytes!,
            filename: _fileName ?? 'receipt.$extension',
            contentType: MediaType(
              'image',
              extension == 'jpg' ? 'jpeg' : extension,
            ),
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final transaction = data['transaction'] as Map<String, dynamic>?;

          setState(() {
            if (transaction != null) {
              _extractedTransactions = [transaction];
            }
            _showPreview = true;
            _isLoading = false;
          });

          if (data['confidence'] != null && data['confidence'] < 0.7) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Low confidence extraction. Please verify the details.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(
            errorData['detail'] ?? 'Failed to extract from image',
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to extract from image: $e';
        _isLoading = false;
      });
    }
  }

  void _resetState() {
    setState(() {
      _fileName = null;
      _fileBytes = null;
      _importType = '';
      _extractedTransactions = [];
      _showPreview = false;
      _bankDetected = null;
      _error = null;
    });
  }

  /// Deduplicate transactions based on date + amount + description prefix
  List<Map<String, dynamic>> _deduplicateTransactions(
    List<Map<String, dynamic>> transactions,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final tx in transactions) {
      final desc = tx['description']?.toString() ?? '';
      final key =
          '${tx['date']}_${tx['amount']}_${desc.length > 15 ? desc.substring(0, 15) : desc}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(tx);
      }
    }

    return result;
  }

  /// Detect bank/source from filename
  String _detectBank(String? filename) {
    if (filename == null) return 'Statement';
    final lower = filename.toLowerCase();

    if (lower.contains('phonepe')) return 'PhonePe';
    if (lower.contains('gpay') || lower.contains('googlepay'))
      return 'Google Pay';
    if (lower.contains('paytm')) return 'Paytm';
    if (lower.contains('hdfc')) return 'HDFC Bank';
    if (lower.contains('sbi')) return 'SBI';
    if (lower.contains('icici')) return 'ICICI Bank';
    if (lower.contains('axis')) return 'Axis Bank';
    if (lower.contains('kotak')) return 'Kotak Bank';
    if (lower.contains('upi')) return 'UPI History';

    return 'Statement';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.document_scanner,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Import Transactions',
                      style: theme.textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  if (_showPreview)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _resetState,
                      tooltip: 'Start over',
                    ),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 24),

              // Import options
              if (!_showPreview) ...[
                Text(
                  'Choose import source:',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    // PDF Import Option
                    Expanded(
                      child: _ImportOptionCard(
                        icon: Icons.picture_as_pdf,
                        iconColor: Colors.red,
                        title: 'Bank Statement',
                        subtitle: 'PDF files from HDFC, SBI, ICICI, Axis',
                        isLoading: _isLoading && _importType == 'pdf',
                        isSelected: _importType == 'pdf' && _fileName != null,
                        onTap: _isLoading ? null : _pickPdf,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Image Import Option
                    Expanded(
                      child: _ImportOptionCard(
                        icon: Icons.image,
                        iconColor: Colors.blue,
                        title: 'Receipt / Image',
                        subtitle: 'Photos, scans, handwritten notes',
                        isLoading: _isLoading && _importType == 'image',
                        isSelected: _importType == 'image' && _fileName != null,
                        onTap: _isLoading ? null : _pickImage,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                // 5-page limit note
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.amber[800],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PDF files must not exceed 5 pages',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Selected file indicator
                if (_fileName != null && !_showPreview)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _importType == 'pdf'
                              ? Icons.picture_as_pdf
                              : Icons.image,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fileName!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _isLoading
                                    ? 'Processing...'
                                    : 'Ready to extract',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(),
              ],

              // Preview list
              if (_showPreview && _extractedTransactions.isNotEmpty) ...[
                if (_bankDetected != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      avatar: const Icon(Icons.account_balance, size: 16),
                      label: Text('Bank: ${_bankDetected!.toUpperCase()}'),
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                  ),
                Text(
                  'Found ${_extractedTransactions.length} transaction(s):',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _extractedTransactions.length,
                    itemBuilder: (context, index) {
                      final t = _extractedTransactions[index];
                      final isIncome = t['type'] == 'income';
                      final amount = t['amount'] is num
                          ? (t['amount'] as num).toDouble()
                          : double.tryParse(t['amount'].toString()) ?? 0;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            child: Icon(
                              isIncome
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            t['merchant'] ?? t['description'] ?? 'Transaction',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['date'] ?? 'No date'),
                              if (t['category'] != null)
                                Chip(
                                  label: Text(
                                    t['category'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isIncome ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          isThreeLine: t['category'] != null,
                        ),
                      ).animate().fadeIn(delay: (50 * index).ms);
                    },
                  ),
                ),
              ],

              // Empty state for preview
              if (_showPreview && _extractedTransactions.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different file or format',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error display
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Loading indicator
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  _importType == 'pdf'
                      ? 'Analyzing bank statement...'
                      : 'Processing image with Vision AI...',
                  style: theme.textTheme.bodySmall,
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  if (_showPreview && _extractedTransactions.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              // Actually save transactions to database
                              setState(() => _isLoading = true);

                              List<TransactionModel> savedTransactions = [];
                              int savedCount = 0;
                              for (final tx in _extractedTransactions) {
                                try {
                                  final amount = tx['amount'] is num
                                      ? (tx['amount'] as num).toDouble()
                                      : double.tryParse(
                                              tx['amount'].toString(),
                                            ) ??
                                            0;

                                  if (amount <= 0) continue;

                                  final result = await dataService
                                      .createTransaction(
                                        userId: widget.userId,
                                        amount: amount,
                                        description:
                                            tx['description']?.toString() ??
                                            'Transaction',
                                        category:
                                            tx['category']?.toString() ??
                                            'Other',
                                        type:
                                            tx['type']?.toString() ?? 'expense',
                                        date: tx['date']?.toString(),
                                        notes: tx['merchant']?.toString(),
                                      );

                                  if (result != null) {
                                    savedCount++;
                                    savedTransactions.add(result);
                                  }
                                } catch (e) {
                                  debugPrint('Error saving transaction: $e');
                                }
                              }

                              if (mounted) {
                                setState(() => _isLoading = false);

                                // Auto-sync saved transactions to budgets
                                if (savedCount > 0 &&
                                    savedTransactions.isNotEmpty) {
                                  try {
                                    // Call auto-categorize and sync budgets
                                    final syncResult = await dataService
                                        .autoCategorizeAndSyncBudgets(
                                          userId: widget.userId,
                                          transactions: savedTransactions,
                                        );

                                    final budgetsUpdated =
                                        syncResult['categories_synced'] ?? 0;
                                    debugPrint(
                                      '[Import] Auto-synced to $budgetsUpdated budgets',
                                    );
                                  } catch (e) {
                                    debugPrint(
                                      '[Import] Budget sync error (non-critical): $e',
                                    );
                                    // Sync is best-effort, don't block
                                  }

                                  // Trigger analysis snapshot after import
                                  try {
                                    final dashData = await dataService.getDashboard(widget.userId);
                                    final healthScore = await dataService.getHealthScore(widget.userId);

                                    if (dashData != null) {
                                      final snapshotResult = await dataService.saveAnalysisSnapshot(
                                        userId: widget.userId,
                                        totalIncome: dashData.totalIncome,
                                        totalExpense: dashData.totalExpense,
                                        savingsRate: dashData.savingsRate,
                                        healthScore: healthScore?.totalScore ?? 0,
                                        categoryBreakdown: dashData.categoryBreakdown.map(
                                          (k, v) => MapEntry(k, v.toDouble()),
                                        ),
                                        insights: healthScore?.insights ?? [],
                                      );
                                      debugPrint('[Import] Analysis snapshot triggered');

                                      // Check for new milestones
                                      final newMilestones = List<Map<String, dynamic>>.from(
                                        snapshotResult['newly_achieved_milestones'] ?? [],
                                      );
                                      if (newMilestones.isNotEmpty && mounted) {
                                        for (final m in newMilestones) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '🎉 ${m['name']} unlocked! +${m['xp_reward']} XP',
                                              ),
                                              backgroundColor: const Color(0xFF4CAF50),
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                          await Future.delayed(const Duration(milliseconds: 500));
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint('[Import] Analysis snapshot error (non-critical): $e');
                                  }
                                }

                                Navigator.of(context).pop(true);

                                // Show success message with budget sync details
                                String message =
                                    '✅ Saved $savedCount transaction(s)';
                                if (savedCount > 0) {
                                  message += ' & synced to budgets';
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isLoading
                            ? 'Saving...'
                            : 'Save (${_extractedTransactions.length})',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card widget for import option selection
class _ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ImportOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: iconColor,
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: iconColor,
                      ),
                    ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
