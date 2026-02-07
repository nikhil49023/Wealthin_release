import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart' show authService;
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/theme/wealthin_theme.dart';

/// Budget Management Screen - Track spending limits by category
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: const BudgetsScreenBody(),
    );
  }
}

/// Body content for embedding in tabs
class BudgetsScreenBody extends StatefulWidget {
  const BudgetsScreenBody({super.key});

  @override
  State<BudgetsScreenBody> createState() => _BudgetsScreenBodyState();
}

class _BudgetsScreenBodyState extends State<BudgetsScreenBody> {
  bool _isLoading = true;
  List<BudgetData> _budgets = [];
  double _totalBudget = 0;
  double _totalSpent = 0;

  String get _userId => authService.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    try {
      final budgets = await dataService.getBudgets(_userId);

      double totalBudget = 0;
      double totalSpent = 0;
      for (final b in budgets) {
        totalBudget += b.amount;
        totalSpent += b.spent;
      }

      if (mounted) {
        setState(() {
          _budgets = budgets;
          _totalBudget = totalBudget;
          _totalSpent = totalSpent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading budgets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _totalBudget - _totalSpent;
    final progress = _totalBudget > 0 ? (_totalSpent / _totalBudget) : 0.0;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBudgets,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overall Budget Summary Card
                        _OverallBudgetCard(
                          totalBudget: _totalBudget,
                          totalSpent: _totalSpent,
                          remaining: remaining,
                          progress: progress,
                        ).animate().fadeIn().slideY(begin: -0.1),
                        const SizedBox(height: 24),

                        // Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Category Budgets',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showAddBudgetDialog(context),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Budget Cards
                        if (_budgets.isEmpty)
                          _EmptyBudgetsPlaceholder(
                            onAdd: () => _showAddBudgetDialog(context),
                          )
                        else
                          ..._budgets.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child:
                                  _BudgetCard(
                                        budget: entry.value,
                                        onEdit: () => _showEditBudgetDialog(
                                          context,
                                          entry.value,
                                        ),
                                        onDelete: () =>
                                            _deleteBudget(entry.value),
                                      )
                                      .animate(delay: (entry.key * 50).ms)
                                      .fadeIn()
                                      .slideX(),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Budget'),
      ).animate().scale(delay: 300.ms),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedIcon = 'restaurant';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 20),
                  Text(
                    'Create Budget',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g., Food, Transport, Shopping',
                      prefixIcon: Icon(Icons.category),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Limit',
                      hintText: '5000',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Icon',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _budgetIcons.entries.map((entry) {
                      final isSelected = selectedIcon == entry.key;
                      return InkWell(
                        onTap: () =>
                            setModalState(() => selectedIcon = entry.key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.1)
                                :  WealthInTheme.gray100,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppTheme.primary, width: 2)
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            color: isSelected
                                ? AppTheme.primary
                                : WealthInTheme.gray600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (name.isNotEmpty && amount > 0) {
                          // Create budget via API
                          final created = await dataService.createBudget(
                            userId: _userId,
                            name: name,
                            amount: amount,
                            category: name.toLowerCase().replaceAll(' ', '_'),
                            icon: selectedIcon,
                          );

                          if (context.mounted) Navigator.pop(context);

                          if (created != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Budget "$name" created! ✅'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                            _loadBudgets();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to create budget'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Create Budget'),
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

  void _showEditBudgetDialog(BuildContext context, BudgetData budget) {
    final nameController = TextEditingController(text: budget.name);
    final amountController = TextEditingController(
      text: budget.amount.toString(),
    );
    String selectedIcon = budget.icon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 20),
                  Text(
                    'Edit Budget',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Limit',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Text('Icon', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _budgetIcons.entries.map((entry) {
                      final isSelected = selectedIcon == entry.key;
                      return InkWell(
                        onTap: () =>
                            setModalState(() => selectedIcon = entry.key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.1)
                                : WealthInTheme.gray100,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppTheme.primary, width: 2)
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            color: isSelected
                                ? AppTheme.primary
                                : WealthInTheme.gray600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (name.isNotEmpty && amount > 0) {
                          if (context.mounted) Navigator.pop(context);

                          // Update budget via API
                          final updated = await dataService.updateBudget(
                            userId: _userId,
                            category: budget.category,
                            limitAmount: amount,
                          );

                          if (updated != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Budget "$name" updated! ✅'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update budget'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                          _loadBudgets();
                        }
                      },
                      child: const Text('Save Changes'),
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

  Future<void> _deleteBudget(BudgetData budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete "${budget.name}" budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && budget.id != null) {
      final deleted = await dataService.deleteBudget(_userId, budget.id!);
      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Budget "${budget.name}" deleted'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _loadBudgets();
    }
  }
}

// Icon mapping for budget categories
const Map<String, IconData> _budgetIcons = {
  'restaurant': Icons.restaurant,
  'shopping': Icons.shopping_bag,
  'transport': Icons.directions_car,
  'entertainment': Icons.movie,
  'health': Icons.medical_services,
  'bills': Icons.receipt_long,
  'groceries': Icons.local_grocery_store,
  'education': Icons.school,
  'travel': Icons.flight,
  'subscriptions': Icons.subscriptions,
  'legal': Icons.gavel,
  'housing': Icons.home,
  'other': Icons.category,
};

IconData _getIconForBudget(String iconKey) {
  return _budgetIcons[iconKey] ?? Icons.category;
}

/// Overall budget summary card
class _OverallBudgetCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double remaining;
  final double progress;

  const _OverallBudgetCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverBudget = totalSpent > totalBudget;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Budget',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(progress * 100).toInt()}% used',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${_formatAmount(totalSpent)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'spent of ₹${_formatAmount(totalBudget)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isOverBudget
                        ? AppTheme.expenseRed.withValues(alpha: 0.3)
                        : AppTheme.incomeGreen.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isOverBudget ? 'Over by' : 'Remaining',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₹${_formatAmount(remaining.abs())}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? AppTheme.expenseRed : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual budget card
class _BudgetCard extends StatelessWidget {
  final BudgetData budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = budget.amount > 0 ? (budget.spent / budget.amount) : 0.0;
    final remaining = budget.amount - budget.spent;
    final isOverBudget = budget.spent > budget.amount;

    Color progressColor;
    if (progress < 0.5) {
      progressColor = AppTheme.incomeGreen;
    } else if (progress < 0.8) {
      progressColor = AppTheme.warning;
    } else {
      progressColor = AppTheme.expenseRed;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForBudget(budget.icon),
                    color: progressColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_formatAmount(budget.spent)} / ₹${_formatAmount(budget.amount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isOverBudget
                          ? '-₹${_formatAmount(remaining.abs())}'
                          : '₹${_formatAmount(remaining)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOverBudget
                            ? AppTheme.expenseRed
                            : AppTheme.incomeGreen,
                      ),
                    ),
                    Text(
                      isOverBudget ? 'over budget' : 'left',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            size: 20,
                            color: AppTheme.expenseRed,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppTheme.expenseRed),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: WealthInTheme.gray200,
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state placeholder
class _EmptyBudgetsPlaceholder extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyBudgetsPlaceholder({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No budgets yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create category budgets to track your spending limits',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create First Budget'),
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
