
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/wealthin_theme.dart';
import '../../../../core/services/data_service.dart';
import '../../finance/finance_hub_screen.dart';

class RecentTransactionsCard extends StatelessWidget {
  final List<TransactionData> transactions;
  final bool isLoading;

  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (transactions.isEmpty) {
      return _buildEmptyState(theme, isDark);
    }

    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? WealthInColors.blackCard : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to Finance Hub (Transactions tab)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FinanceHubScreen(initialTabIndex: 0),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: transactions.length,
                separatorBuilder: (context, index) =>
                    Divider(color: isDark ? WealthInColors.blackBorder : null),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionItem(context, transaction, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? WealthInColors.blackCard : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: isDark
                  ? WealthInColors.textSecondaryDark
                  : WealthInColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No recent transactions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add transactions to track your spending',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? WealthInColors.textSecondaryDark
                    : WealthInColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    TransactionData transaction,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isExpense = transaction.isExpense;
    final color = isExpense ? WealthInColors.error : WealthInColors.success;
    final date = transaction.date; // Already a DateTime

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(transaction.category),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? WealthInColors.textSecondaryDark
                        : WealthInColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '-' : '+'}₹${transaction.amount.toStringAsFixed(0)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                transaction.category,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? WealthInColors.textSecondaryDark
                      : WealthInColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('dining')) return Icons.restaurant;
    if (cat.contains('grocery') || cat.contains('groceries')) return Icons.local_grocery_store;
    if (cat.contains('transport') || cat.contains('travel') || cat.contains('commute')) return Icons.directions_car;
    if (cat.contains('shopping')) return Icons.shopping_bag;
    if (cat.contains('bill') || cat.contains('utilities')) return Icons.receipt_long;
    if (cat.contains('entertainment') || cat.contains('movie')) return Icons.movie;
    if (cat.contains('health') || cat.contains('medical') || cat.contains('pharmacy')) return Icons.medical_services;
    if (cat.contains('education') || cat.contains('school')) return Icons.school;
    if (cat.contains('salary') || cat.contains('income')) return Icons.attach_money;
    if (cat.contains('invest') || cat.contains('stock') || cat.contains('trading')) return Icons.trending_up;
    if (cat.contains('rent') || cat.contains('house') || cat.contains('housing')) return Icons.home;
    if (cat.contains('insurance')) return Icons.security;
    if (cat.contains('loan') || cat.contains('emi')) return Icons.account_balance;
    if (cat.contains('care') || cat.contains('salon')) return Icons.spa;
    if (cat.contains('transfer')) return Icons.swap_horiz;
    
    return Icons.category;
  }
}
