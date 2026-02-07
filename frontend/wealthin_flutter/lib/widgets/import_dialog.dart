import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, TargetPlatform;
import '../core/services/backend_config.dart';
import '../core/services/pdf_to_image_service.dart';
import '../core/services/mlkit_bank_statement_parser.dart';
import '../core/services/native_receipt_service.dart';
import '../core/services/data_service.dart';
import '../core/services/python_bridge_service.dart';

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
        // Use Python PDF parser directly - MUCH more accurate than OCR
        if (pythonBridge.isPythonAvailable) {
          debugPrint('[ImportDialog] Using Python PDF parser (no OCR)');
          
          // Save PDF to temp file for Python to read
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/statement_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(_fileBytes!);
          
          debugPrint('[ImportDialog] PDF saved to: $tempPath');
          
          // Call Python PDF parser directly
          final result = await pythonBridge.executeTool('parse_pdf_statement', {
            'file_path': tempPath
          });
          
          // Clean up temp file
          try { await tempFile.delete(); } catch (_) {}
          
          // Result is already a Map from executeTool
          final parsed = result;
          
          // Check for page limit exceeded error
          if (parsed['page_limit_exceeded'] == true) {
            final pageCount = parsed['page_count'] ?? 'unknown';
            final maxPages = parsed['max_pages'] ?? 5;
            throw Exception(
              'PDF has $pageCount pages. Maximum allowed is $maxPages pages.\n\nPlease split your bank statement into smaller parts.'
            );
          }
          
          if (parsed['success'] == true && parsed['transactions'] != null) {
            final transactions = List<Map<String, dynamic>>.from(parsed['transactions']);
            final deduped = _deduplicateTransactions(transactions);
            
            if (deduped.isNotEmpty) {
              setState(() {
                _bankDetected = parsed['bank_detected']?.toString() ?? 'Bank Statement';
                _extractedTransactions = deduped;
                _showPreview = true;
                _isLoading = false;
              });
              debugPrint('[ImportDialog] Python parser found ${deduped.length} transactions');
              return;
            }
          }
          
          // If Python parser failed, fall back to OCR
          debugPrint('[ImportDialog] Python parser returned no transactions, falling back to OCR');
        }
        
        // Fallback: OCR-based parsing if Python parser unavailable or failed
        final allImages = await PdfToImageService.convertAllPagesToImages(_fileBytes!);
        
        if (allImages.isEmpty) {
          throw Exception('Failed to convert PDF to images');
        }
        
        debugPrint('[ImportDialog] OCR fallback: Processing ${allImages.length} pages');
        
        List<Map<String, dynamic>> allTransactions = [];
        String? detectedBank;
        
        final tempDir = await getTemporaryDirectory();
        
        for (int pageNum = 0; pageNum < allImages.length; pageNum++) {
          final imageBase64 = allImages[pageNum];
          final imageBytes = base64Decode(imageBase64);
          final tempPath = '${tempDir.path}/statement_page${pageNum}_${DateTime.now().millisecondsSinceEpoch}.png';
          
          final result = await MlKitBankStatementParser.parseFromImageBytes(imageBytes, tempPath);
          
          if (result['success'] == true) {
            final txns = List<Map<String, dynamic>>.from(result['transactions'] ?? []);
            allTransactions.addAll(txns);
            detectedBank ??= result['bank_detected'];
          }
        }
        
        final deduped = _deduplicateTransactions(allTransactions);
        
        if (deduped.isNotEmpty) {
          setState(() {
            _bankDetected = detectedBank ?? 'Unknown';
            _extractedTransactions = deduped;
            _showPreview = true;
            _isLoading = false;
          });
        } else {
          throw Exception('No transactions found in the PDF. Try a clearer statement.');
        }
      } else {
        // Original HTTP logic for desktop
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
        // Use Native ML Kit Service
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$_fileName');
        await tempFile.writeAsBytes(_fileBytes!);
        
        // Use Native Receipt Service
        final result = await NativeReceiptService().extractReceipt(tempFile.path);
        
        setState(() {
          if (result['success'] == true) {
            // Unwrap the inner transaction object
            _extractedTransactions = [result['transaction']];
          } else {
             _error = result['error'] ?? 'Failed to recognize text';
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
          throw Exception(errorData['detail'] ?? 'Failed to extract from image');
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
  List<Map<String, dynamic>> _deduplicateTransactions(List<Map<String, dynamic>> transactions) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    
    for (final tx in transactions) {
      final desc = tx['description']?.toString() ?? '';
      final key = '${tx['date']}_${tx['amount']}_${desc.length > 15 ? desc.substring(0, 15) : desc}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(tx);
      }
    }
    
    return result;
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
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
                            t['description'] ?? 'Transaction',
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different file or format',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                      onPressed: _isLoading ? null : () async {
                        // Actually save transactions to database
                        setState(() => _isLoading = true);
                        
                        int savedCount = 0;
                        for (final tx in _extractedTransactions) {
                          try {
                            final amount = tx['amount'] is num
                                ? (tx['amount'] as num).toDouble()
                                : double.tryParse(tx['amount'].toString()) ?? 0;
                            
                            if (amount <= 0) continue;
                            
                            final result = await dataService.createTransaction(
                              userId: widget.userId,
                              amount: amount,
                              description: tx['description']?.toString() ?? 'Transaction',
                              category: tx['category']?.toString() ?? 'Other',
                              type: tx['type']?.toString() ?? 'expense',
                              date: tx['date']?.toString(),
                              notes: tx['merchant']?.toString(),
                            );
                            
                            if (result != null) {
                              savedCount++;
                            }
                          } catch (e) {
                            debugPrint('Error saving transaction: $e');
                          }
                        }
                        
                        if (mounted) {
                          setState(() => _isLoading = false);
                          Navigator.of(context).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Saved $savedCount transaction(s) to database',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Saving...' : 'Save (${_extractedTransactions.length})'),
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
