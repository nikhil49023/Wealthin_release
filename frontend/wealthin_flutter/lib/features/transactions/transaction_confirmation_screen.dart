import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/wealthin_theme.dart';
import '../../core/models/transaction_model.dart';

/// Screen to review and confirm transactions before saving
class TransactionConfirmationScreen extends StatefulWidget {
  final List<TransactionModel> transactions;
  final String? bankName;
  final VoidCallback? onConfirm;

  const TransactionConfirmationScreen({
    super.key,
    required this.transactions,
    this.bankName,
    this.onConfirm,
  });

  @override
  State<TransactionConfirmationScreen> createState() => _TransactionConfirmationScreenState();
}

class _TransactionConfirmationScreenState extends State<TransactionConfirmationScreen> {
  late List<TransactionModel> _transactions;
  final Set<int> _selectedIndices = {};
  bool _selectAll = true;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
    // Select all by default
    _selectedIndices.addAll(List.generate(_transactions.length, (i) => i));
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedIndices.addAll(List.generate(_transactions.length, (i) => i));
      } else {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
      _selectAll = _selectedIndices.length == _transactions.length;
    });
  }

  void _deleteTransaction(int index) {
    setState(() {
      _transactions.removeAt(index);
      _selectedIndices.remove(index);
      // Recalculate indices
      _selectedIndices.clear();
      for (int i = 0; i < _transactions.length; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  void _editTransaction(int index) async {
    final tx = _transactions[index];
    final result = await showDialog<TransactionModel>(
      context: context,
      builder: (context) => _EditTransactionDialog(transaction: tx),
    );
    if (result != null) {
      setState(() {
        _transactions[index] = result;
      });
    }
  }

  List<TransactionModel> get _selectedTransactions {
    return _selectedIndices.map((i) => _transactions[i]).toList();
  }

  double get _totalIncome {
    return _selectedTransactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _totalExpense {
    return _selectedTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review Transactions'),
            if (widget.bankName != null)
              Text(
                widget.bankName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? WealthInColors.textSecondaryDark : WealthInColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _toggleSelectAll,
            icon: Icon(_selectAll ? Icons.deselect : Icons.select_all, size: 20),
            label: Text(_selectAll ? 'Deselect All' : 'Select All'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? WealthInColors.blackCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? WealthInColors.primary.withValues(alpha: 0.2) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? WealthInColors.textSecondaryDark : WealthInColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_selectedIndices.length} of ${_transactions.length}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.arrow_upward, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _currencyFormat.format(_totalIncome),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.arrow_downward, color: Colors.red, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _currencyFormat.format(_totalExpense),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),

          // Transaction List
          Expanded(
            child: _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('No transactions found', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final tx = _transactions[index];
                      final isSelected = _selectedIndices.contains(index);
                      final isIncome = tx.type == 'income';

                      return Dismissible(
                        key: Key('tx_${tx.id ?? index}_${tx.description}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteTransaction(index),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isDark ? WealthInColors.blackCard : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? WealthInColors.primary
                                  : (isDark ? Colors.white12 : Colors.grey.shade200),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _toggleSelection(index),
                            onLongPress: () => _editTransaction(index),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleSelection(index),
                                    activeColor: WealthInColors.primary,
                                  ),
                                  // Category Icon
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(tx.category),
                                      color: isIncome ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.description,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${tx.category} • ${DateFormat('dd MMM').format(tx.date)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isDark ? WealthInColors.textSecondaryDark : WealthInColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Amount
                                  Text(
                                    '${isIncome ? '+' : '-'}${_currencyFormat.format(tx.amount)}',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: isIncome ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate(delay: (index * 30).ms).fadeIn().slideX(begin: 0.05, end: 0);
                    },
                  ),
          ),

          // Confirm Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedIndices.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context, _selectedTransactions);
                          widget.onConfirm?.call();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WealthInColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirm ${_selectedIndices.length} Transactions',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'utilities':
        return Icons.bolt;
      case 'entertainment':
        return Icons.movie;
      case 'medical':
      case 'health':
        return Icons.medical_services;
      case 'education':
        return Icons.school;
      case 'groceries':
        return Icons.local_grocery_store;
      case 'housing':
        return Icons.home;
      case 'income':
      case 'salary':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt;
    }
  }
}

/// Dialog to edit a single transaction
class _EditTransactionDialog extends StatefulWidget {
  final TransactionModel transaction;

  const _EditTransactionDialog({required this.transaction});

  @override
  State<_EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  late TextEditingController _descController;
  late TextEditingController _amountController;
  late String _category;
  late String _type;

  final _categories = [
    'Food', 'Transport', 'Shopping', 'Utilities', 'Entertainment',
    'Medical', 'Education', 'Groceries', 'Housing', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.transaction.description);
    _amountController = TextEditingController(text: widget.transaction.amount.toString());
    _category = widget.transaction.category;
    _type = widget.transaction.type;
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Edit Transaction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _categories.contains(_category) ? _category : 'Other',
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Other'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text) ?? widget.transaction.amount;
            final updated = TransactionModel(
              id: widget.transaction.id,
              amount: amount,
              description: _descController.text,
              category: _category,
              type: _type,
              date: widget.transaction.date,
              paymentMethod: widget.transaction.paymentMethod,
              notes: widget.transaction.notes,
              receiptUrl: widget.transaction.receiptUrl,
              isRecurring: widget.transaction.isRecurring,
              createdAt: widget.transaction.createdAt,
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
