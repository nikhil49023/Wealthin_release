import 'package:flutter/material.dart';
import 'package:wealthin_flutter/core/theme/wealthin_theme.dart';

/// Metric Card Widget - equivalent to the React MetricCard component
/// Displays a financial metric with icon, title, and value
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final bool isLoading;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            isLoading
                ? Container(
                    height: 32,
                    width: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Income Metric Card
class IncomeCard extends StatelessWidget {
  final double amount;
  final bool isLoading;

  const IncomeCard({
    super.key,
    required this.amount,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      title: 'Your Income',
      value: _formatCurrency(amount),
      icon: Icons.trending_up,
      iconBackgroundColor: WealthInColors.success.withOpacity(0.1),
      iconColor: WealthInColors.success,
      isLoading: isLoading,
    );
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}

/// Expense Metric Card
class ExpenseCard extends StatelessWidget {
  final double amount;
  final bool isLoading;

  const ExpenseCard({
    super.key,
    required this.amount,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      title: 'Your Expenses',
      value: _formatCurrency(amount),
      icon: Icons.trending_down,
      iconBackgroundColor: WealthInColors.error.withOpacity(0.1),
      iconColor: WealthInColors.error,
      isLoading: isLoading,
    );
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}

/// Savings Rate Card
class SavingsRateCard extends StatelessWidget {
  final int savingsRate;
  final bool isLoading;

  const SavingsRateCard({
    super.key,
    required this.savingsRate,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MetricCard(
      title: 'Savings Rate',
      value: '$savingsRate%',
      icon: Icons.savings,
      iconBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      iconColor: theme.colorScheme.primary,
      isLoading: isLoading,
    );
  }
}

/// Savings Metric Card
class SavingsCard extends StatelessWidget {
  final double amount;
  final bool isLoading;

  const SavingsCard({
    super.key,
    required this.amount,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return MetricCard(
      title: 'Total Savings',
      value: _formatCurrency(amount),
      icon: Icons.account_balance_wallet,
      iconBackgroundColor: WealthInColors.primary.withOpacity(0.1),
      iconColor: WealthInColors.primary,
      isLoading: isLoading,
    );
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}
