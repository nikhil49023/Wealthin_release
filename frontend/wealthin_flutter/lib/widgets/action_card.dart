import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Action Card Widget for AI Advisor
/// Shows pending AI actions with confirm/cancel buttons
class ActionCard extends StatelessWidget {
  final String actionType;
  final Map<String, dynamic> parameters;
  final String confirmationMessage;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isExecuting;

  const ActionCard({
    super.key,
    required this.actionType,
    required this.parameters,
    required this.confirmationMessage,
    required this.onConfirm,
    required this.onCancel,
    this.isExecuting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionConfig = _getActionConfig(actionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            actionConfig.color.withValues(alpha: 0.1),
            actionConfig.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: actionConfig.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: actionConfig.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionConfig.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    actionConfig.icon,
                    color: actionConfig.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionConfig.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: actionConfig.color,
                        ),
                      ),
                      Text(
                        'Confirm this action',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confirmation Message
                Text(
                  confirmationMessage,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),

                // Parameters Preview
                _buildParametersPreview(context, actionConfig),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isExecuting ? null : onCancel,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: isExecuting ? null : onConfirm,
                        icon: isExecuting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(actionConfig.confirmIcon, size: 18),
                        label: Text(isExecuting ? 'Processing...' : 'Confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: actionConfig.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeOut,
        );
  }

  Widget _buildParametersPreview(BuildContext context, _ActionConfig config) {
    final items = <Widget>[];

    parameters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        items.add(
          _ParameterChip(
            label: _formatKey(key),
            value: _formatValue(key, value),
            icon: _getParameterIcon(key),
          ),
        );
      }
    });

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatValue(String key, dynamic value) {
    if (key.contains('amount') || key.contains('limit') || key.contains('principal') || key.contains('emi')) {
      return '₹${_formatNumber(value)}';
    }
    if (key.contains('rate')) {
      return '$value%';
    }
    if (key.contains('months') || key.contains('tenure')) {
      return '$value months';
    }
    return value.toString();
  }

  String _formatNumber(dynamic value) {
    final num = double.tryParse(value.toString()) ?? 0;
    if (num >= 10000000) {
      return '${(num / 10000000).toStringAsFixed(2)} Cr';
    } else if (num >= 100000) {
      return '${(num / 100000).toStringAsFixed(2)} L';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toStringAsFixed(0);
  }

  IconData _getParameterIcon(String key) {
    if (key.contains('category')) return Icons.category;
    if (key.contains('amount') || key.contains('limit') || key.contains('principal')) return Icons.currency_rupee;
    if (key.contains('period') || key.contains('frequency')) return Icons.schedule;
    if (key.contains('name')) return Icons.label;
    if (key.contains('rate')) return Icons.percent;
    if (key.contains('date') || key.contains('deadline')) return Icons.calendar_today;
    return Icons.info_outline;
  }

  _ActionConfig _getActionConfig(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'upsert_budget':
      case 'create_budget':
        return _ActionConfig(
          title: 'Create Budget',
          icon: Icons.account_balance_wallet,
          confirmIcon: Icons.add,
          color: Colors.blue,
        );
      case 'create_savings_goal':
        return _ActionConfig(
          title: 'Savings Goal',
          icon: Icons.flag,
          confirmIcon: Icons.add,
          color: Colors.green,
        );
      case 'schedule_payment':
        return _ActionConfig(
          title: 'Schedule Payment',
          icon: Icons.notifications_active,
          confirmIcon: Icons.alarm_add,
          color: Colors.orange,
        );
      case 'add_debt':
        return _ActionConfig(
          title: 'Track Debt/EMI',
          icon: Icons.credit_card,
          confirmIcon: Icons.add,
          color: Colors.red,
        );
      case 'add_transaction':
        return _ActionConfig(
          title: 'Add Transaction',
          icon: Icons.receipt_long,
          confirmIcon: Icons.add,
          color: Colors.purple,
        );
      case 'analyze_investment':
        return _ActionConfig(
          title: 'Investment Analysis',
          icon: Icons.trending_up,
          confirmIcon: Icons.calculate,
          color: Colors.teal,
        );
      case 'generate_cashflow_analysis':
        return _ActionConfig(
          title: 'Cashflow Analysis',
          icon: Icons.analytics,
          confirmIcon: Icons.play_arrow,
          color: Colors.indigo,
        );
      default:
        return _ActionConfig(
          title: 'AI Action',
          icon: Icons.auto_awesome,
          confirmIcon: Icons.check,
          color: Colors.deepPurple,
        );
    }
  }
}

class _ActionConfig {
  final String title;
  final IconData icon;
  final IconData confirmIcon;
  final Color color;

  _ActionConfig({
    required this.title,
    required this.icon,
    required this.confirmIcon,
    required this.color,
  });
}

class _ParameterChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ParameterChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Investment Calculator Card
/// Shows calculated results with visual breakdown
class InvestmentResultCard extends StatelessWidget {
  final String type; // sip, fd, emi, rd
  final Map<String, dynamic> result;

  const InvestmentResultCard({
    super.key,
    required this.type,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getTypeConfig(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 48),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  config.color.withValues(alpha: 0.2),
                  config.color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(config.icon, color: config.color, size: 28),
                const SizedBox(width: 12),
                Text(
                  config.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: config.color,
                  ),
                ),
              ],
            ),
          ),

          // Results Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildResultsGrid(context, config),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildResultsGrid(BuildContext context, _InvestmentConfig config) {
    final items = <Widget>[];

    result.forEach((key, value) {
      if (key != 'amortization_schedule' && value != null) {
        items.add(_ResultTile(
          label: _formatLabel(key),
          value: _formatResultValue(key, value),
          isHighlighted: _isHighlightField(key),
          color: config.color,
        ));
      }
    });

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items,
    );
  }

  String _formatLabel(String key) {
    final labels = {
      'total_invested': 'Total Invested',
      'future_value': 'Future Value',
      'wealth_gained': 'Wealth Gained',
      'returns_percentage': 'Returns',
      'maturity_amount': 'Maturity Amount',
      'interest_earned': 'Interest Earned',
      'effective_annual_rate': 'Effective Rate',
      'emi': 'Monthly EMI',
      'total_payment': 'Total Payment',
      'total_interest': 'Total Interest',
      'total_deposited': 'Total Deposited',
      'required_monthly_sip': 'Required SIP',
      'cagr': 'CAGR',
    };
    return labels[key] ?? _formatKey(key);
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatResultValue(String key, dynamic value) {
    if (key.contains('rate') || key.contains('percentage') || key == 'cagr') {
      return '$value%';
    }
    if (value is num) {
      if (value >= 10000000) {
        return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
      } else if (value >= 100000) {
        return '₹${(value / 100000).toStringAsFixed(2)} L';
      } else if (value >= 1000) {
        return '₹${value.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
            )}';
      }
      return '₹${value.toStringAsFixed(0)}';
    }
    return value.toString();
  }

  bool _isHighlightField(String key) {
    return key == 'future_value' ||
        key == 'maturity_amount' ||
        key == 'emi' ||
        key == 'wealth_gained' ||
        key == 'required_monthly_sip';
  }

  _InvestmentConfig _getTypeConfig(String type) {
    switch (type.toLowerCase()) {
      case 'sip':
        return _InvestmentConfig(
          title: 'SIP Calculator',
          icon: Icons.trending_up,
          color: Colors.green,
        );
      case 'fd':
        return _InvestmentConfig(
          title: 'FD Calculator',
          icon: Icons.savings,
          color: Colors.blue,
        );
      case 'emi':
        return _InvestmentConfig(
          title: 'EMI Calculator',
          icon: Icons.calculate,
          color: Colors.orange,
        );
      case 'rd':
        return _InvestmentConfig(
          title: 'RD Calculator',
          icon: Icons.account_balance,
          color: Colors.purple,
        );
      default:
        return _InvestmentConfig(
          title: 'Investment Result',
          icon: Icons.analytics,
          color: Colors.teal,
        );
    }
  }
}

class _InvestmentConfig {
  final String title;
  final IconData icon;
  final Color color;

  _InvestmentConfig({
    required this.title,
    required this.icon,
    required this.color,
  });
}

class _ResultTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;
  final Color color;

  const _ResultTile({
    required this.label,
    required this.value,
    required this.isHighlighted,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 18 : 16,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted ? color : null,
            ),
          ),
        ],
      ),
    );
  }
}
