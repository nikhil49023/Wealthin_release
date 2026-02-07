import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart' show authService;
import '../../core/theme/wealthin_theme.dart';
import '../../core/services/data_service.dart';
import '../../widgets/import_dialog.dart';

/// Transactions Screen - List and manage transactions with Bulk Delete
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final DataService dataService = DataService();
  String get _userId => authService.currentUserId;

  bool _isLoading = true;
  List<TransactionData> _transactions = [];
  String _filterType = 'all'; // 'all', 'income', 'expense'
  
  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final transactions = await dataService.getTransactions(_userId);
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelectedTransactions() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Transaction${count > 1 ? 's' : ''}?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete these transactions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: WealthInColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      int successCount = 0;
      
      // Execute deletions
      // Optimization: Could be parallelized but sequential is safer for now
      for (final id in _selectedIds) {
        final success = await dataService.deleteTransaction(_userId, id);
        if (success) successCount++;
      }

      _selectedIds.clear();
      _isSelectionMode = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $successCount transaction${successCount != 1 ? 's' : ''}'),
            backgroundColor: WealthInColors.success,
          ),
        );
        _loadTransactions(); // Reload to refresh list
      }
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredTransactions.length) {
        _selectedIds.clear(); // Deselect all if all selected
      } else {
        _selectedIds.clear();
        for (var t in _filteredTransactions) {
          if (t.id != null) _selectedIds.add(t.id!);
        }
      }
    });
  }

  /// Find duplicate transactions (same date + same amount)
  void _findDuplicates() {
    final Map<String, List<TransactionData>> grouped = {};
    
    for (var tx in _transactions) {
      // Key by date (day only) + amount
      final key = '${tx.date.toIso8601String().substring(0, 10)}_${tx.amount.toStringAsFixed(2)}';
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    
    // Find groups with more than one transaction
    final duplicateIds = <int>{};
    for (var group in grouped.values) {
      if (group.length > 1) {
        // Mark all but the first as duplicates
        for (int i = 1; i < group.length; i++) {
          if (group[i].id != null) {
            duplicateIds.add(group[i].id!);
          }
        }
      }
    }
    
    if (duplicateIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No duplicate transactions found'),
          backgroundColor: WealthInColors.success,
        ),
      );
      return;
    }
    
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      _selectedIds.addAll(duplicateIds);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found ${duplicateIds.length} potential duplicate${duplicateIds.length > 1 ? 's' : ''} - review and delete'),
        backgroundColor: WealthInColors.warning,
        action: SnackBarAction(
          label: 'Delete All',
          textColor: Colors.white,
          onPressed: _deleteSelectedTransactions,
        ),
      ),
    );
  }

  List<TransactionData> get _filteredTransactions {
    if (_filterType == 'all') return _transactions;
    return _transactions.where((t) => t.type == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('${_selectedIds.length} Selected'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIds.length == _filteredTransactions.length && _filteredTransactions.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all
                  ),
                  tooltip: 'Select All',
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: WealthInColors.error),
                  tooltip: 'Delete Selected',
                  onPressed: _selectedIds.isNotEmpty ? _deleteSelectedTransactions : null,
                ),
              ],
            )
          : AppBar(
              title: const Text('Transactions'),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Options',
                  onSelected: (value) {
                    if (value == 'import') {
                      showDialog(
                        context: context,
                        builder: (context) => ImportTransactionsDialog(userId: _userId),
                      ).then((result) {
                        if (result == true) {
                          _loadTransactions();
                        }
                      });
                    } else if (value == 'find_duplicates') {
                      _findDuplicates();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.document_scanner, color: primaryColor),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Import Transactions'),
                              Text(
                                'PDF or Image',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'find_duplicates',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy, color: WealthInColors.warning),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Find Duplicates'),
                              Text(
                                'Same date & amount',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Filter Chips
              if (!_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _filterType == 'all',
                        onTap: () => setState(() => _filterType = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Income',
                        isSelected: _filterType == 'income',
                        onTap: () => setState(() => _filterType = 'income'),
                        color: WealthInColors.success,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Expense',
                        isSelected: _filterType == 'expense',
                        onTap: () => setState(() => _filterType = 'expense'),
                        color: WealthInColors.error,
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideX(),

              // Transactions List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredTransactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your first transaction or import from PDF',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 500.ms)
                        : RefreshIndicator(
                            onRefresh: _loadTransactions,
                            child: ListView.builder(
                              padding: EdgeInsets.only(
                                left: 16, 
                                right: 16, 
                                top: _isSelectionMode ? 16 : 0, // Adjust padding
                                bottom: 80
                              ),
                              itemCount: _filteredTransactions.length,
                              itemBuilder: (context, index) {
                                final transaction = _filteredTransactions[index];
                                final isSelected = transaction.id != null && _selectedIds.contains(transaction.id);
                                return _TransactionTile(
                                  transaction: transaction,
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: isSelected,
                                  onLongPress: () {
                                    if (transaction.id == null) return;
                                    setState(() {
                                      _isSelectionMode = true;
                                      _toggleSelection(transaction.id!);
                                    });
                                  },
                                  onTap: () {
                                    if (_isSelectionMode && transaction.id != null) {
                                      _toggleSelection(transaction.id!);
                                    } else {
                                      // Show details logic if needed, currently nothing
                                    }
                                  },
                                )
                                .animate()
                                .fadeIn(delay: (50 * index).ms)
                                .slideX(begin: 0.1, end: 0);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTransactionDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedType = 'expense';
    String selectedCategory = 'Groceries';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
                  const SizedBox(height: 16),
                  Text(
                    'Add Transaction',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  // Type Selection
                  Row(
                    children: [
                      Expanded(
                        child: _TypeButton(
                          label: 'Expense',
                          icon: Icons.arrow_downward,
                          isSelected: selectedType == 'expense',
                          color: WealthInColors.error,
                          onTap: () => setModalState(() => selectedType = 'expense'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeButton(
                          label: 'Income',
                          icon: Icons.arrow_upward,
                          isSelected: selectedType == 'income',
                          color: WealthInColors.success,
                          onTap: () => setModalState(() => selectedType = 'income'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                      DropdownMenuItem(value: 'Food', child: Text('Food')),
                      DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                      DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                      DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                      DropdownMenuItem(value: 'Housing', child: Text('Housing')),
                      DropdownMenuItem(value: 'Entertainment',child: Text('Entertainment')),
                      DropdownMenuItem(value: 'Health', child: Text('Health')),
                      DropdownMenuItem(value: 'Medical', child: Text('Medical')),
                      DropdownMenuItem(value: 'Education', child: Text('Education')),
                      DropdownMenuItem(value: 'Legal', child: Text('Legal')),
                      DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                      DropdownMenuItem(value: 'Salary', child: Text('Salary')),
                      DropdownMenuItem(value: 'Freelance', child: Text('Freelance')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setModalState(() => selectedCategory = value!),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount > 0 && descController.text.isNotEmpty) {
                          final result = await dataService.createTransaction(
                            userId: _userId,
                            amount: amount,
                            description: descController.text,
                            category: selectedCategory,
                            type: selectedType,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (result != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Transaction added successfully!'),
                                ),
                              );
                              _loadTransactions();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to add transaction'),
                                  backgroundColor: WealthInTheme.coral,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Add Transaction'),
                      ),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipColor : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionData transaction;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final color = isIncome ? WealthInColors.success : WealthInColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        onLongPress: onLongPress,
        onTap: onTap,
        leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (val) => onTap(),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            )
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(transaction.category),
                color: color,
              ),
            ),
        title: Text(
          transaction.merchant ?? transaction.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${transaction.category} • ${_formatDate(transaction.date)}${transaction.paymentMethod != null ? ' • ${transaction.paymentMethod}' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: isSelectionMode 
            ? null 
            : Text(
                '${isIncome ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : null),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
