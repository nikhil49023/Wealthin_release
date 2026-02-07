import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:wealthin_flutter/core/theme/wealthin_theme.dart';
import '../../../core/theme/app_theme.dart';

/// Metric Card Widget - Glassmorphic design with blur effect
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
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)]
                  : [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0.55)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppTheme.sereneTeal.withValues(alpha: 0.2)
                  : AppTheme.sageGreen.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppTheme.slate500).withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : AppTheme.slate500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              isLoading
                  ? Container(
                      height: 32,
                      width: 100,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.1) 
                            : AppTheme.sageGreen.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  : Text(
                      value,
                      style: GoogleFonts.dmSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.slate900,
                      ),
                    ),
            ],
          ),
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
      iconBackgroundColor: WealthInColors.success.withValues(alpha: 0.1),
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
      iconBackgroundColor: WealthInColors.error.withValues(alpha: 0.1),
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
      iconBackgroundColor: WealthInColors.primary.withValues(alpha: 0.1),
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
