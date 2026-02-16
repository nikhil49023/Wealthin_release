import 'package:flutter/material.dart';
import '../transactions/transactions_screen.dart';
import '../budgets/budgets_screen.dart';
import '../goals/goals_screen.dart';
import '../payments/scheduled_payments_screen.dart';
import '../../widgets/import_dialog.dart';
import '../../main.dart' show authService;
import '../../core/theme/wealthin_theme.dart';

/// Finance Hub - Consolidated screen for all financial management features
class FinanceHubScreen extends StatefulWidget {
  final int initialTabIndex;

  const FinanceHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends State<FinanceHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshKey = 0;

  final List<_FinanceTab> _tabs = const [
    _FinanceTab(
      label: 'Transactions',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    _FinanceTab(
      label: 'Budgets',
      icon: Icons.pie_chart_outline,
      selectedIcon: Icons.pie_chart,
    ),
    _FinanceTab(
      label: 'Goals',
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag,
    ),
    _FinanceTab(
      label: 'Bills',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = authService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        centerTitle: false,
        actions: [
          // Import button in app bar
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Transactions',
            onPressed: () => _showImportDialog(context, userId),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(tab.label),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Key forces rebuild after import
          _TransactionsTabContent(key: ValueKey('tx_$_refreshKey')),
          _BudgetsTabContent(key: ValueKey('bud_$_refreshKey')),
          _GoalsTabContent(key: ValueKey('goal_$_refreshKey')),
          _PaymentsTabContent(key: ValueKey('pay_$_refreshKey')),
        ],
      ),
      // Floating Action Button for quick import
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImportDialog(context, userId),
        backgroundColor: isDark ? WealthInTheme.emerald : WealthInTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_chart),
        label: const Text('Import'),
      ),
    );
  }

  void _showImportDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => ImportTransactionsDialog(userId: userId),
    ).then((result) {
      // Refresh all tabs when transactions are imported
      if (result == true && mounted) {
        setState(() {
          _refreshKey++; // Force tab views to rebuild and reload data
        });
      }
    });
  }
}

class _FinanceTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _FinanceTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Transactions tab content (without its own AppBar)
class _TransactionsTabContent extends StatelessWidget {
  const _TransactionsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Return the TransactionsScreen (now handles its own Scaffold/AppBar)
    return TransactionsScreen();
  }
}

/// Budgets tab content (without its own AppBar)
class _BudgetsTabContent extends StatelessWidget {
  const _BudgetsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const BudgetsScreenBody();
  }
}

/// Goals tab content (without its own AppBar)
class _GoalsTabContent extends StatelessWidget {
  const _GoalsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const GoalsScreenBody();
  }
}

/// Payments tab content (without its own AppBar)
class _PaymentsTabContent extends StatelessWidget {
  const _PaymentsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScheduledPaymentsScreenBody();
  }
}
