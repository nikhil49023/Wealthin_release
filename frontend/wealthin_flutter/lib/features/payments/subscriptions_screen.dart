import 'package:flutter/material.dart';
import 'package:wealthin_flutter/core/services/database_helper.dart';
import 'package:wealthin_flutter/core/services/python_bridge_service.dart';

/// Subscriptions Screen - Displays detected recurring payments
/// Uses Python-based pattern recognition to identify subscriptions and recurring habits
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _subscriptions = [];
  List<dynamic> _recurringHabits = [];
  double _monthlyTotal = 0;
  double _annualTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch transactions from database
      final db = DatabaseHelper();
      final transactions = await db.getTransactions();
      
      if (transactions.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No transactions found. Import statements to detect subscriptions.';
        });
        return;
      }

      // Prepare transactions for Python analysis
      final txList = transactions.map((tx) => {
        'description': tx['description'] ?? '',
        'amount': (tx['amount'] as num?)?.toDouble() ?? 0.0,
        'date': tx['date'] ?? '',
        'category': tx['category'] ?? 'Other',
        'merchant': tx['merchant'] ?? tx['description'] ?? '',
      }).toList();

      // Call Python subscription detection
      final result = await pythonBridge.detectSubscriptions(txList);

      if (result['success'] == true) {
        setState(() {
          _subscriptions = result['subscriptions'] ?? [];
          _recurringHabits = result['recurring_habits'] ?? [];
          _monthlyTotal = (result['total_monthly_cost'] as num?)?.toDouble() ?? 0;
          _annualTotal = (result['annual_projection'] as num?)?.toDouble() ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = result['error'] ?? 'Failed to analyze subscriptions';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubscriptions,
          ),
        ],
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing recurring payments...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 64, color: theme.hintColor),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSubscriptions,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_subscriptions.isEmpty && _recurringHabits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
              const SizedBox(height: 16),
              Text(
                'No Subscriptions Detected',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Import more bank statements to detect recurring payments',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Card
          _buildSummaryCard(theme, isDark),
          const SizedBox(height: 24),
          
          // Active Subscriptions Section
          if (_subscriptions.isNotEmpty) ...[
            Text(
              'Active Subscriptions',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._subscriptions.map((sub) => _buildSubscriptionCard(sub, theme, isDark)),
            const SizedBox(height: 24),
          ],
          
          // Recurring Habits Section
          if (_recurringHabits.isNotEmpty) ...[
            Text(
              'Recurring Habits',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Frequent but variable spending patterns',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 12),
            ..._recurringHabits.map((habit) => _buildHabitCard(habit, theme, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.deepPurple[800]!, Colors.purple[900]!]
              : [Colors.deepPurple[400]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.subscriptions, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Subscription Burden',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Monthly', '₹${_formatAmount(_monthlyTotal)}'),
              _buildSummaryItem('Yearly', '₹${_formatAmount(_annualTotal)}'),
              _buildSummaryItem('Count', '${_subscriptions.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(dynamic sub, ThemeData theme, bool isDark) {
    final merchant = sub['merchant'] ?? 'Unknown';
    final amount = (sub['average_amount'] as num?)?.toDouble() ?? 0;
    final frequency = sub['frequency'] ?? 'monthly';
    final category = sub['category'] ?? 'Other';
    final confidence = (sub['confidence'] as num?)?.toDouble() ?? 0;
    final nextExpected = sub['next_expected'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(category).withValues(alpha: 0.2),
          child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category)),
        ),
        title: Text(
          _capitalizeFirst(merchant),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$frequency • $category'),
            if (nextExpected != null) ...[
              const SizedBox(height: 2),
              Text(
                'Next: $nextExpected',
                style: TextStyle(color: theme.hintColor, fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${_formatAmount(amount)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(confidence * 100).toInt()}% sure',
              style: TextStyle(color: theme.hintColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(dynamic habit, ThemeData theme, bool isDark) {
    final merchant = habit['merchant'] ?? 'Unknown';
    final amount = (habit['average_amount'] as num?)?.toDouble() ?? 0;
    final frequency = habit['frequency'] ?? 'irregular';
    final occurrences = habit['occurrences'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.repeat, size: 20),
        title: Text(_capitalizeFirst(merchant)),
        subtitle: Text('$occurrences times • $frequency'),
        trailing: Text(
          '~₹${_formatAmount(amount)}',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Entertainment': Colors.purple,
      'Shopping': Colors.orange,
      'Food & Dining': Colors.red,
      'Utilities': Colors.blue,
      'Transport': Colors.teal,
      'Healthcare': Colors.green,
      'Other': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
      'Entertainment': Icons.movie,
      'Shopping': Icons.shopping_bag,
      'Food & Dining': Icons.restaurant,
      'Utilities': Icons.bolt,
      'Transport': Icons.directions_car,
      'Healthcare': Icons.medical_services,
      'Other': Icons.category,
    };
    return icons[category] ?? Icons.category;
  }
}
