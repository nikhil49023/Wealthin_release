import 'package:flutter/material.dart';
// TODO: Firebase migration - removed wealthin_client import
// import 'package:wealthin_client/wealthin_client.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../main.dart' show authService;
// TODO: Firebase migration - removed main.dart import (was used for Serverpod client)
// import '../../main.dart';
import '../../core/services/data_service.dart';
import 'widgets/metric_card.dart';
import 'widgets/finbite_card.dart';
import 'widgets/cashflow_card.dart';
import 'widgets/financial_overview_card.dart';
import 'widgets/trend_analysis_card.dart';
import 'widgets/category_breakdown_card.dart';
import 'widgets/recent_transactions_card.dart';
import '../finance/financial_tools_screen.dart';
import '../ai_advisor/chat_screen.dart';
import '../../core/theme/wealthin_theme.dart';

/// Dashboard Screen - Main financial overview with REAL DATA from Python backend
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _isLoadingInsight = true;
  String _greeting = '';
  final String _userName = 'there';

  // Financial Summary State - REAL DATA
  DashboardData? _data;
  DailyInsight? _dailyInsight;

  // Cache for insights (24h)
  static DailyInsight? _cachedInsight;
  static DateTime? _cacheTime;

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _loadDashboardData();
    _loadDailyInsight();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 18) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final userId = authService.currentUserId;
      final dashboardData = await dataService.getDashboard(userId);

      if (mounted) {
        setState(() {
          _data = dashboardData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDailyInsight({bool forceRefresh = false}) async {
    // Check cache first (24h validity)
    if (!forceRefresh && _cachedInsight != null && _cacheTime != null) {
      final cacheAge = DateTime.now().difference(_cacheTime!);
      if (cacheAge.inHours < 24) {
        if (mounted) {
          setState(() {
            _dailyInsight = _cachedInsight;
            _isLoadingInsight = false;
          });
        }
        return;
      }
    }

    setState(() => _isLoadingInsight = true);

    try {
      final userId = authService.currentUserId;
      final insight = await dataService.getDailyInsight(userId);

      if (insight != null) {
        // Update cache
        _cachedInsight = insight;
        _cacheTime = DateTime.now();

        if (mounted) {
          setState(() {
            _dailyInsight = insight;
            _isLoadingInsight = false;
          });
        }
      } else {
        throw Exception('Failed to load insight');
      }
    } catch (e) {
      debugPrint('Error loading daily insight: $e');
      if (mounted) {
        setState(() {
          _dailyInsight = DailyInsight(
            headline: '📊 Financial Snapshot',
            insightText: 'Import transactions to get personalized insights.',
            recommendation:
                'Scan a bank statement or add transactions manually.',
            trendIndicator: 'stable',
          );
          _isLoadingInsight = false;
        });
      }
    }
  }

  // ==================== DOCUMENT SCANNER ====================

  final ImagePicker _imagePicker = ImagePicker();

  void _showScannerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: WealthInTheme.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Scan Document',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI will automatically extract transaction details',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WealthInTheme.gray600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ScanOptionCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Camera',
                    subtitle: 'Take a photo',
                    onTap: () {
                      Navigator.pop(context);
                      _scanWithCamera();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ScanOptionCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Gallery',
                    subtitle: 'Choose image',
                    onTap: () {
                      Navigator.pop(context);
                      _scanFromGallery();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ScanOptionCard(
              icon: Icons.picture_as_pdf_rounded,
              title: 'Bank Statement (PDF)',
              subtitle: 'Import multiple transactions',
              onTap: () {
                Navigator.pop(context);
                _scanBankStatement();
              },
              fullWidth: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _scanWithCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        await _processReceiptImage(image.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open camera: $e');
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        await _processReceiptImage(image.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open gallery: $e');
    }
  }

  Future<void> _processReceiptImage(String filePath) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Analyzing receipt...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AI is extracting transaction details',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WealthInTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final receipt = await dataService.scanReceipt(filePath);
      Navigator.pop(context); // Close loading dialog

      if (receipt != null) {
        _showReceiptResultDialog(receipt);
      } else {
        _showErrorSnackBar('Could not extract receipt data. Please try again.');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('Error scanning receipt: $e');
    }
  }

  void _showReceiptResultDialog(ReceiptData receipt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: WealthInTheme.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: WealthInTheme.emerald),
            ),
            const SizedBox(width: 12),
            const Text('Receipt Scanned'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReceiptField('Merchant', receipt.merchantName ?? 'Unknown'),
            _buildReceiptField(
              'Amount',
              '₹${receipt.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
            ),
            _buildReceiptField('Date', receipt.date ?? 'Unknown'),
            _buildReceiptField('Category', receipt.category ?? 'Uncategorized'),
            if (receipt.confidence != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(
                  value: receipt.confidence! / 100,
                  backgroundColor: WealthInTheme.gray200,
                  valueColor: AlwaysStoppedAnimation(
                    receipt.confidence! > 70 ? WealthInTheme.emerald : WealthInTheme.warning,
                  ),
                ),
              ),
            if (receipt.confidence != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Confidence: ${receipt.confidence!.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WealthInTheme.gray600,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Discard'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _saveReceiptAsTransaction(receipt);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: WealthInTheme.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReceiptAsTransaction(ReceiptData receipt) async {
    final userId = authService.currentUserId;

    try {
      await dataService.createTransaction(
        userId: userId,
        amount: receipt.totalAmount ?? 0,
        description: receipt.merchantName ?? 'Scanned Receipt',
        category: receipt.category ?? 'Uncategorized',
        type: 'expense',
        date: receipt.date ?? DateTime.now().toIso8601String(),
        paymentMethod: receipt.paymentMethod,
        notes: 'Scanned from receipt',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Transaction saved: ₹${receipt.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                ),
              ],
            ),
            backgroundColor: WealthInTheme.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        _loadDashboardData(); // Refresh dashboard
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save transaction: $e');
    }
  }

  Future<void> _scanBankStatement() async {
    try {
      // Use file_picker for PDF
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Bank Statement Scanner'),
          content: const Text(
            'This feature requires selecting a PDF bank statement. The AI will extract all transactions automatically.\n\nNote: Ensure your bank statement is in a standard PDF format.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Select PDF'),
            ),
          ],
        ),
      );

      if (result == true) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.single.path != null) {
          final filePath = result.files.single.path!;
          
          if (mounted) {
            // Show loading dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Processing Statement...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI is extracting transactions from your PDF',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WealthInTheme.gray600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final importResult = await dataService.importFromPdf(authService.currentUserId, filePath);
          
          if (mounted) {
             Navigator.pop(context); // Close loading dialog
             
             if (importResult != null && importResult.success) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Row(
                     children: [
                       const Icon(Icons.check_circle, color: Colors.white),
                       const SizedBox(width: 8),
                       Text(
                         'Imported ${importResult.importedCount} transactions successfully!',
                       ),
                     ],
                   ),
                   backgroundColor: WealthInTheme.emerald,
                   behavior: SnackBarBehavior.floating,
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(10),
                   ),
                 ),
               );
               _loadDashboardData(); // Refresh dashboard
             } else {
               _showErrorSnackBar(importResult?.message ?? 'Failed to import PDF');
             }
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: WealthInTheme.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet =
            constraints.maxWidth > 600 && constraints.maxWidth <= 900;
        final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: isDesktop || isTablet
                  ? _buildDesktopGrid(theme, crossAxisCount)
                  : _buildMobileLayout(theme),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddTransactionDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Transaction'),
          ).animate().scale(delay: 500.ms, curve: Curves.elasticOut),
        );
      },
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme).animate().fadeIn().slideY(begin: -0.2, end: 0),
          const SizedBox(height: 24),
          _buildMobileMetrics().animate().fadeIn(delay: 100.ms).slideX(),
          const SizedBox(height: 16),
          IncomeCard(
            amount: _data?.totalIncome ?? 0,
            isLoading: _isLoading,
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          CashflowCard(
            data: _data,
            isLoading: _isLoading,
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 24),
          const TrendAnalysisCard().animate().fadeIn(delay: 275.ms), 
          const SizedBox(height: 24),
          CategoryBreakdownCard(
            categoryBreakdown: _data?.categoryBreakdown ?? {},
            isLoading: _isLoading,
          ).animate().fadeIn(delay: 290.ms),
          const SizedBox(height: 24),
          RecentTransactionsCard(
            transactions: _data?.recentTransactions ?? [],
            isLoading: _isLoading,
          ).animate().fadeIn(delay: 295.ms),
          const SizedBox(height: 24),
          _buildSuggestionCard(
            theme,
          ).animate().shimmer(delay: 1000.ms, duration: 1200.ms),
          const SizedBox(height: 24),
          const FinancialOverviewCard().animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 24),
          _buildQuickActions(
            theme,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildDesktopGrid(ThemeData theme, int crossAxisCount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 32),
          StaggeredGrid.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            children: [
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: ExpenseCard(
                  amount: _data?.totalExpense ?? 0,
                  isLoading: _isLoading,
                ).animate().fadeIn().scale(),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: IncomeCard(
                  amount: _data?.totalIncome ?? 0,
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 100.ms).scale(),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: SavingsRateCard(
                  savingsRate: _data?.savingsRate.toInt() ?? 0,
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 200.ms).scale(),
              ),
              // Cash Flow Card
              StaggeredGridTile.count(
                crossAxisCellCount: crossAxisCount > 2 ? 2 : crossAxisCount,
                mainAxisCellCount: 1.2,
                child: CashflowCard(
                  data: _data,
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 250.ms),
              ),
              // Category Breakdown Card
              StaggeredGridTile.count(
                crossAxisCellCount: crossAxisCount > 2 ? 1 : crossAxisCount,
                mainAxisCellCount: 1.2,
                child: CategoryBreakdownCard(
                  categoryBreakdown: _data?.categoryBreakdown ?? {},
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 260.ms),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: crossAxisCount > 2 ? 1 : crossAxisCount,
                mainAxisCellCount: 1.2, // Taller for list
                child: RecentTransactionsCard(
                  transactions: _data?.recentTransactions ?? [],
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 265.ms),
              ),
              // Trend Analysis
              StaggeredGridTile.count(
                crossAxisCellCount: crossAxisCount > 2 ? 2 : crossAxisCount,
                mainAxisCellCount: 1.2,
                child: const TrendAnalysisCard().animate().fadeIn(
                  delay: 270.ms,
                ),
              ),
              // Financial Overview Card
              StaggeredGridTile.count(
                crossAxisCellCount: crossAxisCount > 2 ? 1 : crossAxisCount,
                mainAxisCellCount: crossAxisCount > 2 ? 1.2 : 1.5,
                child: const FinancialOverviewCard().animate().fadeIn(
                  delay: 280.ms,
                ),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: crossAxisCount,
                mainAxisCellCount: 1, // Shorter height for AI card in grid
                child: _buildSuggestionCard(
                  theme,
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: crossAxisCount,
                mainAxisCellCount: 0.5,
                child: _buildQuickActions(
                  theme,
                ).animate().fadeIn(delay: 400.ms),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: theme.textTheme.headlineMedium,
            ),
            Text(
              '$_greeting, $_userName',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => _showUpdatesSheet(context),
          icon: const Icon(Icons.notifications_outlined),
          iconSize: 24,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            foregroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileMetrics() {
    return SizedBox(
      height: 140,
      child: PageView(
        controller: PageController(viewportFraction: 0.9),
        padEnds: false,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ExpenseCard(
              amount: _data?.totalExpense ?? 0,
              isLoading: _isLoading,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SavingsCard(
              amount: _data?.balance ?? 0,
              isLoading: _isLoading,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SavingsRateCard(
              savingsRate: _data?.savingsRate.toInt() ?? 0,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(ThemeData theme) {
    return FinBiteCard(
      insight: _dailyInsight,
      isLoading: _isLoadingInsight,
      onRefresh: () => _loadDailyInsight(forceRefresh: true),
      onTap: () {
        // Navigate to AI advisor for more details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tap "Advisor" for personalized financial advice!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.qr_code_scanner_rounded, // Minimalistic
                label: 'Scan',
                onTap: () => _showScannerOptions(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.calculate_outlined, // Minimalistic
                label: 'Tools',
                onTap: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinancialToolsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Advisor',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showUpdatesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.25,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: WealthInTheme.gray300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Latest Updates',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: const [
                        Center(child: Text('No new updates')),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedType = 'expense';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                ],
                onChanged: (value) => selectedType = value!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0 && descController.text.isNotEmpty) {
                  final userId = authService.currentUserId;
                  try {
                    await dataService.createTransaction(
                      userId: userId,
                      amount: amount,
                      description: descController.text,
                      category: 'Uncategorized',
                      type: selectedType,
                      date: DateTime.now().toIso8601String(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Transaction added: ₹${amount.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                          backgroundColor: WealthInTheme.emerald,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      _loadDashboardData(); // Refresh dashboard
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error adding transaction: $e'),
                          backgroundColor: WealthInTheme.coral,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered 
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scan option card for the document scanner bottom sheet
class _ScanOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ScanOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: fullWidth
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: WealthInTheme.gray600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: WealthInTheme.gray400,
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: WealthInTheme.gray600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
