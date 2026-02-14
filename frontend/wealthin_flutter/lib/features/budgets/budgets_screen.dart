import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart' show authService;
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/database_helper.dart';
import '../../core/services/transaction_categorizer.dart';
import '../../core/constants/categories.dart';
import '../../core/theme/wealthin_theme.dart';
import '../../core/utils/responsive_utils.dart';

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
      // Auto-recalculate budget spending from transactions
      // This ensures budgets always reflect actual transaction data
      await databaseHelper.recalculateBudgetSpending();
      debugPrint('[Budgets] Auto-recalculated spending from transactions');
      
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
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final maxWidth = ResponsiveUtils.getMaxCardWidth(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBudgets,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(padding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overall Budget Summary Card - only show when budgets exist
                        if (_budgets.isNotEmpty) ...[
                          _OverallBudgetCard(
                            totalBudget: _totalBudget,
                            totalSpent: _totalSpent,
                            remaining: remaining,
                            progress: progress,
                          ).animate().fadeIn().slideY(begin: -0.1),
                          const SizedBox(height: 24),
                        ],

                        // Section Header - only show when budgets exist
                        if (_budgets.isNotEmpty) ...[
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
                        ],

                        // Budget Cards or Empty State
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
                                        onTap: () => _showCategoryTransactions(
                                          context,
                                          entry.value,
                                        ),
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
    final amountController = TextEditingController();
    String? selectedCategory;
    // Default to first category if available
    final categories = Categories.budgetable;
    if (categories.isNotEmpty) selectedCategory = categories.first;
    
    // Attempt to match icon, fallback to restaurant
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
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                  
                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCategory = val;
                          // Try to auto-select icon based on category name logic
                          // This is a simple heuristic mapping based on _budgetIcons keys
                          final lower = val.toLowerCase();
                          if (lower.contains('food')) selectedIcon = 'restaurant';
                          else if (lower.contains('shop')) selectedIcon = 'shopping';
                          else if (lower.contains('transport')) selectedIcon = 'transport';
                          else if (lower.contains('entertain')) selectedIcon = 'entertainment';
                          else if (lower.contains('health')) selectedIcon = 'health';
                          else if (lower.contains('bill') || lower.contains('util')) selectedIcon = 'bills';
                          else if (lower.contains('grocer')) selectedIcon = 'groceries';
                          else if (lower.contains('educat')) selectedIcon = 'education';
                          else if (lower.contains('travel')) selectedIcon = 'travel';
                          else if (lower.contains('subscript')) selectedIcon = 'subscriptions';
                          else if (lower.contains('rent') || lower.contains('house')) selectedIcon = 'housing';
                          else selectedIcon = 'other';
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                    ),
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
                  // Icon is automatically determined from category
                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (selectedCategory != null && amount > 0) {
                          // Create budget via API
                          // Use exact category string as ID and Name
                          final created = await dataService.createBudget(
                            userId: _userId,
                            name: selectedCategory!, 
                            amount: amount,
                            category: selectedCategory!, // Crucial: Store exact category name
                          );

                          if (context.mounted) Navigator.pop(context);

                          if (created != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Budget for "$selectedCategory" created! ✅'),
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
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                  // Display category name (read-only for now as it is PK)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: WealthInTheme.gray100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(TransactionCategorizer.getIcon(budget.category)),
                        const SizedBox(width: 12),
                        Text(
                          budget.category,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
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
                  // Icon is fixed based on category
                  const SizedBox(height: 24),
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

    if (confirmed == true) {
      final deleted = await dataService.deleteBudget(_userId, budget.category);
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

  /// Show transactions for a specific budget category
  void _showCategoryTransactions(BuildContext context, BudgetData budget) async {
    // Fetch transactions for this category
    final transactions = await DatabaseHelper().getTransactionsByCategory(
      budget.category,
      limit: 50,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final progress = budget.amount > 0 ? (budget.spent / budget.amount) : 0.0;
        final isOverBudget = budget.spent > budget.amount;
        
        Color progressColor;
        if (progress < 0.5) {
          progressColor = AppTheme.incomeGreen;
        } else if (progress < 0.8) {
          progressColor = AppTheme.warning;
        } else {
          progressColor = AppTheme.expenseRed;
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with budget info
                Container(
                  padding: const EdgeInsets.all(20),
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
                              TransactionCategorizer.getIcon(budget.category),
                              color: progressColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  budget.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${_formatAmount(budget.spent)} of ₹${_formatAmount(budget.amount)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isOverBudget 
                                  ? AppTheme.expenseRed.withValues(alpha: 0.1)
                                  : AppTheme.incomeGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                color: isOverBudget ? AppTheme.expenseRed : AppTheme.incomeGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                Divider(height: 1, color: Colors.grey[200]),
                // Transactions header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions (${transactions.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'This Month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Transactions list
                Expanded(
                  child: transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions this month',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: transactions.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
                            final description = tx['description'] as String? ?? 'Unknown';
                            final date = tx['date'] as String? ?? '';
                            final type = (tx['type'] as String? ?? '').toLowerCase();
                            final isExpense = type == 'expense' || type == 'debit';
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              leading: CircleAvatar(
                                backgroundColor: isExpense 
                                    ? AppTheme.expenseRed.withValues(alpha: 0.1)
                                    : AppTheme.incomeGreen.withValues(alpha: 0.1),
                                child: Icon(
                                  isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: isExpense ? AppTheme.expenseRed : AppTheme.incomeGreen,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatTransactionDate(date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              trailing: Text(
                                '${isExpense ? "-" : "+"}₹${_formatAmount(amount)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isExpense ? AppTheme.expenseRed : AppTheme.incomeGreen,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTransactionDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Today';
      } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        return 'Yesterday';
      }
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}

// Icon mapping for budget categories


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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹${_formatAmount(totalSpent)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'spent of ₹${_formatAmount(totalBudget)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₹${_formatAmount(remaining.abs())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
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
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    this.onTap,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                    TransactionCategorizer.getIcon(budget.category),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 12),
            _TransactionPreview(
              category: budget.category,
              onViewAll: onTap ?? () {},
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Transaction preview widget for budget cards
class _TransactionPreview extends StatefulWidget {
  final String category;
  final VoidCallback onViewAll;

  const _TransactionPreview({
    required this.category,
    required this.onViewAll,
  });

  @override
  State<_TransactionPreview> createState() => _TransactionPreviewState();
}

class _TransactionPreviewState extends State<_TransactionPreview> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final transactions = await DatabaseHelper().getTransactionsByCategory(
        widget.category,
        limit: 3,
        startDate: startOfMonth.toIso8601String().split('T')[0],
      );

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          'No transactions this month',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._transactions.map((tx) => Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tx['description'] ?? 'Transaction',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${(tx['amount'] as num).abs().toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.expenseRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: widget.onViewAll,
          child: Text(
            'View All Transactions →',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
