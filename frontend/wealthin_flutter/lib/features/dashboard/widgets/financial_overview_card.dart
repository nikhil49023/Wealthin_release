import 'package:flutter/material.dart';
// TODO: Firebase migration - removed wealthin_client import
// import 'package:wealthin_client/wealthin_client.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../main.dart' show authService;
// TODO: Firebase migration - removed main.dart import (was used for Serverpod client)
// import '../../../main.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/data_service.dart';
import '../../budgets/budgets_screen.dart';
import '../../goals/goals_screen.dart';
import '../../payments/scheduled_payments_screen.dart';
import '../../../core/theme/wealthin_theme.dart';

/// Financial Overview Card - Summary of budgets, goals, and payments
class FinancialOverviewCard extends StatefulWidget {
  const FinancialOverviewCard({super.key});

  @override
  State<FinancialOverviewCard> createState() => _FinancialOverviewCardState();
}

class _FinancialOverviewCardState extends State<FinancialOverviewCard> {
  bool _isLoading = true;
  List<BudgetData> _budgets = [];
  List<GoalData> _goals = [];
  List<ScheduledPaymentData> _upcomingPayments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = authService.currentUserId;

    try {
      setState(() => _isLoading = true);

      // Load data from API in parallel
      final results = await Future.wait([
        dataService.getBudgets(userId),
        dataService.getGoals(userId),
        dataService.getScheduledPayments(userId),
      ]);

      if (!mounted) return;
      setState(() {
        _budgets = results[0] as List<BudgetData>;
        _goals = results[1] as List<GoalData>;
        _upcomingPayments = (results[2] as List<ScheduledPaymentData>)
            .where((p) => p.isActive)
            .take(3)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading financial overview: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    // Calculate totals
    double totalBudgetSpent = 0;
    double totalBudgetLimit = 0;
    for (final b in _budgets) {
      totalBudgetSpent += b.spent;
      totalBudgetLimit += b.amount;
    }

    double totalSaved = 0;
    double totalGoalTarget = 0;
    int completedGoals = 0;
    for (final g in _goals) {
      totalSaved += g.currentAmount;
      totalGoalTarget += g.targetAmount;
      if (g.currentAmount >= g.targetAmount) completedGoals++;
    }

    double upcomingTotal = 0;
    for (final p in _upcomingPayments) {
      upcomingTotal += p.amount;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.8),
                              AppTheme.primary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Financial Overview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Overview Items
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columnCount = width >= 900
                    ? 3
                    : width >= 560
                    ? 2
                    : 1;
                final itemWidth = columnCount == 1
                    ? width
                    : (width - (12 * (columnCount - 1))) / columnCount;

                final cards = [
                  _OverviewItem(
                    icon: Icons.pie_chart_rounded,
                    iconColor: const Color(
                      0xFF6C63FF,
                    ), // Keep specific brand color or move to theme
                    title: 'Budgets',
                    value: '₹${_formatAmount(totalBudgetSpent)}',
                    subtitle: 'of ₹${_formatAmount(totalBudgetLimit)}',
                    progress: totalBudgetLimit > 0
                        ? totalBudgetSpent / totalBudgetLimit
                        : 0,
                    progressColor: totalBudgetSpent > totalBudgetLimit * 0.9
                        ? AppTheme.expenseRed
                        : totalBudgetSpent > totalBudgetLimit * 0.75
                        ? AppTheme.warning
                        : AppTheme.incomeGreen,
                    onTap: () => _navigateTo(context, const BudgetsScreen()),
                  ).animate().fadeIn(delay: 100.ms),
                  _OverviewItem(
                    icon: Icons.flag_rounded,
                    iconColor: AppTheme.incomeGreen,
                    title: 'Goals',
                    value: '₹${_formatAmount(totalSaved)}',
                    subtitle: '$completedGoals/${_goals.length} complete',
                    progress: totalGoalTarget > 0
                        ? totalSaved / totalGoalTarget
                        : 0,
                    progressColor: AppTheme.incomeGreen,
                    onTap: () => _navigateTo(context, const GoalsScreen()),
                  ).animate().fadeIn(delay: 200.ms),
                  _OverviewItem(
                    icon: Icons.event_note_rounded,
                    iconColor: AppTheme.warning,
                    title: 'Upcoming',
                    value: '₹${_formatAmount(upcomingTotal)}',
                    subtitle: '${_upcomingPayments.length} payments due',
                    showProgress: false,
                    badge: _upcomingPayments.isNotEmpty
                        ? '${_upcomingPayments.length}'
                        : null,
                    onTap: () =>
                        _navigateTo(context, const ScheduledPaymentsScreen()),
                  ).animate().fadeIn(delay: 300.ms),
                ];

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: itemWidth.isFinite ? itemWidth : width,
                          child: card,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // Upcoming payments preview
            if (_upcomingPayments.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Next Due',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              ..._upcomingPayments.take(2).map((payment) {
                final dueDate =
                    DateTime.tryParse(payment.nextDueDate) ?? DateTime.now();
                final daysUntil = dueDate.difference(DateTime.now()).inDays;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UpcomingPaymentRow(
                    name: payment.name,
                    amount: payment.amount,
                    daysUntil: daysUntil,
                    onTap: () =>
                        _navigateTo(context, const ScheduledPaymentsScreen()),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color progressColor;
  final bool showProgress;
  final String? badge;
  final VoidCallback onTap;

  const _OverviewItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    this.progress = 0,
    this.progressColor = AppTheme.primary,
    this.showProgress = true,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WealthInTheme.gray200.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 20),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (showProgress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: WealthInTheme.gray200,
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpcomingPaymentRow extends StatelessWidget {
  final String name;
  final double amount;
  final int daysUntil;
  final VoidCallback onTap;

  const _UpcomingPaymentRow({
    required this.name,
    required this.amount,
    required this.daysUntil,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrgent = daysUntil <= 3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isUrgent
                    ? AppTheme.warning.withValues(alpha: 0.1)
                    : WealthInTheme.gray600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.event,
                size: 16,
                color: isUrgent ? AppTheme.warning : WealthInTheme.gray600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    daysUntil == 0
                        ? 'Due today'
                        : daysUntil == 1
                        ? 'Due tomorrow'
                        : 'Due in $daysUntil days',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isUrgent
                          ? AppTheme.warning
                          : WealthInTheme.gray600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: WealthInTheme.gray400,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAmount(double amount) {
  if (amount >= 100000) {
    return '${(amount / 100000).toStringAsFixed(1)}L';
  } else if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toStringAsFixed(0);
}
