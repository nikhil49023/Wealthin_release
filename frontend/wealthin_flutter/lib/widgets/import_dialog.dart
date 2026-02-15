import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
  bool _isSaving = false; // Prevent double-tap on save
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
      // Save PDF to temp file
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/statement_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(_fileBytes!);

      debugPrint('[ImportDialog] PDF saved to: $tempPath');

      // Use local parser flow via DataService
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

      try {
        await tempFile.delete();
      } catch (_) {}

      final confidence = (result['confidence'] is num)
          ? (result['confidence'] as num).toDouble()
          : double.tryParse(result['confidence']?.toString() ?? '');
      if (confidence != null && confidence < 0.7 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Low confidence extraction. Please verify details.'),
            backgroundColor: Colors.orange,
          ),
        );
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

  /// Detect bank/source from filename
  String _detectBank(String? filename) {
    if (filename == null) return 'Statement';
    final lower = filename.toLowerCase();

    if (lower.contains('phonepe')) return 'PhonePe';
    if (lower.contains('gpay') || lower.contains('googlepay')) {
      return 'Google Pay';
    }
    if (lower.contains('paytm')) return 'Paytm';
    if (lower.contains('hdfc')) return 'HDFC Bank';
    if (lower.contains('sbi')) return 'SBI';
    if (lower.contains('icici')) return 'ICICI Bank';
    if (lower.contains('axis')) return 'Axis Bank';
    if (lower.contains('kotak')) return 'Kotak Bank';
    if (lower.contains('upi')) return 'UPI History';

    return 'Statement';
  }

  Widget _buildTipRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
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

                // Tips & Guidelines
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Tips for best results',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTipRow(theme, Icons.picture_as_pdf, 'PDF: Max 5 pages, selectable text works best'),
                      const SizedBox(height: 4),
                      _buildTipRow(theme, Icons.image, 'Image: Clear photo, good lighting, no blur'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📝 For handwritten notes, use this format:',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '  15/02/2026  Swiggy          ₹250\n'
                              '  15/02/2026  Uber Ride       ₹150\n'
                              '  14/02/2026  Grocery Store   ₹1,200',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                height: 1.5,
                              ),
                            ),
                          ],
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
                      onPressed: (_isLoading || _isSaving)
                          ? null
                          : () async {
                              // Guard against double-tap
                              if (_isSaving) return;
                              setState(() {
                                _isSaving = true;
                                _isLoading = true;
                              });

                              // Capture navigator/scaffold before async gap
                              final nav = Navigator.of(context);
                              final scaffold = ScaffoldMessenger.of(context);
                              final userId = widget.userId;

                              // Save transactions to database
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
                                        userId: userId,
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

                              // CLOSE DIALOG IMMEDIATELY — don't wait for sync/analysis
                              nav.pop(true);

                              // Show success snackbar right away
                              String message =
                                  '✅ Saved $savedCount transaction(s)';
                              if (savedCount > 0) {
                                message += ' & syncing budgets...';
                              }
                              scaffold.showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );

                              // Run heavy background work AFTER dialog is closed
                              if (savedCount > 0 &&
                                  savedTransactions.isNotEmpty) {
                                // Budget sync (fire and forget)
                                dataService
                                    .autoCategorizeAndSyncBudgets(
                                      userId: userId,
                                      transactions: savedTransactions,
                                    )
                                    .then((syncResult) {
                                  final budgetsUpdated =
                                      syncResult['categories_synced'] ?? 0;
                                  debugPrint(
                                    '[Import] Auto-synced to $budgetsUpdated budgets',
                                  );
                                }).catchError((e) {
                                  debugPrint(
                                    '[Import] Budget sync error (non-critical): $e',
                                  );
                                });

                                // Analysis snapshot (fire and forget)
                                () async {
                                  try {
                                    final dashData = await dataService
                                        .getDashboard(userId);
                                    final healthScore = await dataService
                                        .getHealthScore(userId);

                                    if (dashData != null) {
                                      await dataService
                                          .saveAnalysisSnapshot(
                                            userId: userId,
                                            totalIncome: dashData.totalIncome,
                                            totalExpense: dashData.totalExpense,
                                            savingsRate: dashData.savingsRate,
                                            healthScore:
                                                healthScore?.totalScore ?? 0,
                                            categoryBreakdown: dashData
                                                .categoryBreakdown
                                                .map(
                                                  (k, v) =>
                                                      MapEntry(k, v.toDouble()),
                                                ),
                                            insights:
                                                healthScore?.insights ?? [],
                                          );
                                      debugPrint(
                                        '[Import] Analysis snapshot triggered',
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      '[Import] Analysis snapshot error (non-critical): $e',
                                    );
                                  }
                                }();
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
