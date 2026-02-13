import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart' show authService;
import '../../core/theme/wealthin_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/sms_transaction_service.dart';
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

  // Advanced Filters
  String? _filterCategory;
  DateTimeRange? _filterDateRange;
  double? _filterMinAmount;
  double? _filterMaxAmount;

  // Available categories for filtering
  final List<String> _categories = [
    'Groceries',
    'Food',
    'Transport',
    'Utilities',
    'Rent',
    'Housing',
    'Entertainment',
    'Health',
    'Medical',
    'Education',
    'Legal',
    'Shopping',
    'Salary',
    'Freelance',
    'Other',
  ];

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _autoScanSmsInBackground(); // Auto-scan SMS on startup
  }

  /// Automatically scan SMS for transactions in background
  Future<void> _autoScanSmsInBackground() async {
    try {
      final smsService = SmsTransactionService();

      // Check if permission is granted
      if (!await smsService.hasPermission()) {
        debugPrint(
          '[TransactionsScreen] SMS permission not granted, skipping auto-scan',
        );
        return;
      }

      debugPrint('[TransactionsScreen] Starting auto SMS scan...');

      // Scan silently in background
      final transactionsFound = await smsService.scanAllSms();

      if (transactionsFound > 0) {
        debugPrint(
          '[TransactionsScreen] Auto-scan found $transactionsFound new transactions',
        );

        // Reload transactions to show new ones
        _loadTransactions();

        // Show subtle notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Added $transactionsFound new transaction${transactionsFound > 1 ? 's' : ''} from SMS',
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[TransactionsScreen] Error in auto SMS scan: $e');
    }
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
          'This action cannot be undone. Are you sure you want to delete these transactions?',
        ),
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
            content: Text(
              'Deleted $successCount transaction${successCount != 1 ? 's' : ''}',
            ),
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
      final key =
          '${tx.date.toIso8601String().substring(0, 10)}_${tx.amount.toStringAsFixed(2)}';
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
        content: Text(
          'Found ${duplicateIds.length} potential duplicate${duplicateIds.length > 1 ? 's' : ''} - review and delete',
        ),
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
    var filtered = _transactions;

    // Filter by type
    if (_filterType != 'all') {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }

    // Filter by category
    if (_filterCategory != null) {
      filtered = filtered
          .where(
            (t) => t.category.toLowerCase() == _filterCategory!.toLowerCase(),
          )
          .toList();
    }

    // Filter by date range
    if (_filterDateRange != null) {
      filtered = filtered
          .where(
            (t) =>
                t.date.isAfter(
                  _filterDateRange!.start.subtract(const Duration(days: 1)),
                ) &&
                t.date.isBefore(
                  _filterDateRange!.end.add(const Duration(days: 1)),
                ),
          )
          .toList();
    }

    // Filter by amount range
    if (_filterMinAmount != null) {
      filtered = filtered.where((t) => t.amount >= _filterMinAmount!).toList();
    }
    if (_filterMaxAmount != null) {
      filtered = filtered.where((t) => t.amount <= _filterMaxAmount!).toList();
    }

    return filtered;
  }

  bool get _hasActiveFilters =>
      _filterCategory != null ||
      _filterDateRange != null ||
      _filterMinAmount != null ||
      _filterMaxAmount != null;

  void _clearAllFilters() {
    setState(() {
      _filterCategory = null;
      _filterDateRange = null;
      _filterMinAmount = null;
      _filterMaxAmount = null;
    });
  }

  void _showFilterDialog() {
    String? tempCategory = _filterCategory;
    DateTimeRange? tempDateRange = _filterDateRange;
    double? tempMinAmount = _filterMinAmount;
    double? tempMaxAmount = _filterMaxAmount;
    final minController = TextEditingController(
      text: tempMinAmount?.toStringAsFixed(0) ?? '',
    );
    final maxController = TextEditingController(
      text: tempMaxAmount?.toStringAsFixed(0) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                    // Handle bar
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

                    // Header
                    Row(
                      children: [
                        Text(
                          'Filter Transactions',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        if (_hasActiveFilters)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempCategory = null;
                                tempDateRange = null;
                                tempMinAmount = null;
                                tempMaxAmount = null;
                                minController.clear();
                                maxController.clear();
                              });
                            },
                            child: const Text('Clear All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Date Range Picker
                    Text(
                      'Date Range',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: tempDateRange,
                        );
                        if (picked != null) {
                          setModalState(() => tempDateRange = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tempDateRange != null
                                    ? '${tempDateRange!.start.day}/${tempDateRange!.start.month} - ${tempDateRange!.end.day}/${tempDateRange!.end.month}'
                                    : 'Select date range',
                                style: TextStyle(
                                  color: tempDateRange != null
                                      ? null
                                      : Theme.of(context).hintColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tempDateRange != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    setModalState(() => tempDateRange = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Filter
                    Text(
                      'Category',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempCategory,
                      hint: const Text('All Categories'),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: tempCategory != null
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setModalState(() => tempCategory = null),
                              )
                            : null,
                      ),
                      items: _categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setModalState(() => tempCategory = value),
                    ),
                    const SizedBox(height: 16),

                    // Amount Range
                    Text(
                      'Amount Range (₹)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            decoration: InputDecoration(
                              labelText: 'Min',
                              prefixIcon: const Icon(Icons.currency_rupee),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              tempMinAmount = double.tryParse(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            decoration: InputDecoration(
                              labelText: 'Max',
                              prefixIcon: const Icon(Icons.currency_rupee),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              tempMaxAmount = double.tryParse(value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filterCategory = tempCategory;
                            _filterDateRange = tempDateRange;
                            _filterMinAmount = double.tryParse(
                              minController.text,
                            );
                            _filterMaxAmount = double.tryParse(
                              maxController.text,
                            );
                          });
                          Navigator.pop(context);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Apply Filters'),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                    _selectedIds.length == _filteredTransactions.length &&
                            _filteredTransactions.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: 'Select All',
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: WealthInColors.error),
                  tooltip: 'Delete Selected',
                  onPressed: _selectedIds.isNotEmpty
                      ? _deleteSelectedTransactions
                      : null,
                ),
              ],
            )
          : AppBar(
              title: const Text('Transactions'),
              actions: [
                // Filter button with badge for active filters
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filter',
                      onPressed: _showFilterDialog,
                    ),
                    if (_hasActiveFilters)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: WealthInColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Options',
                  onSelected: (value) {
                    if (value == 'import') {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            ImportTransactionsDialog(userId: _userId),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
                          Icon(
                            Icons.content_copy,
                            color: WealthInColors.warning,
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Find Duplicates'),
                              Text(
                                'Same date & amount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _filterType == 'all',
                        onTap: () => setState(() => _filterType = 'all'),
                      ),
                      _FilterChip(
                        label: 'Income',
                        isSelected: _filterType == 'income',
                        onTap: () => setState(() => _filterType = 'income'),
                        color: WealthInColors.success,
                      ),
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
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
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
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
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
                            bottom: 80,
                          ),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _filteredTransactions[index];
                            final isSelected =
                                transaction.id != null &&
                                _selectedIds.contains(transaction.id);
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
                                    if (_isSelectionMode &&
                                        transaction.id != null) {
                                      _toggleSelection(transaction.id!);
                                    } else if (transaction.id != null) {
                                      // Show recategorize dialog
                                      _showRecategorizeDialog(transaction);
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

  void _showRecategorizeDialog(TransactionData transaction) {
    String selectedCategory = transaction.category;
    final isOther = transaction.category.toLowerCase() == 'other';
    bool applyToAll = false; // NEW: Apply rule to all similar transactions

    // Extract merchant keyword from description for display
    String merchantKeyword = _extractMerchantKeyword(transaction.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                    // Handle bar
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

                    // Header with transaction info
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOther
                                    ? 'Categorize Transaction'
                                    : 'Change Category',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                transaction.description,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${transaction.amount.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),

                    if (isOther) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: WealthInColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: WealthInColors.warning.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: WealthInColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This transaction is uncategorized. Select a category for better budget tracking.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Category selection grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedCategory = cat);
                            }
                          },
                          selectedColor: WealthInColors.primary.withOpacity(
                            0.2,
                          ),
                          checkmarkColor: WealthInColors.primary,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // NEW: "Apply to all" toggle with merchant keyword display
                    if (merchantKeyword.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: WealthInColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: applyToAll
                                ? WealthInColors.primary.withOpacity(0.5)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              applyToAll
                                  ? Icons.auto_awesome
                                  : Icons.auto_awesome_outlined,
                              color: applyToAll
                                  ? WealthInColors.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Apply to all "$merchantKeyword" transactions?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Future transactions will auto-categorize',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: applyToAll,
                              onChanged: (value) =>
                                  setModalState(() => applyToAll = value),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: selectedCategory != transaction.category
                                ? () async {
                                    Navigator.pop(context);

                                    // Update transaction category
                                    final success = await dataService
                                        .updateTransactionCategory(
                                          transaction.id!,
                                          selectedCategory,
                                        );

                                    // NEW: Create merchant rule if "Apply to all" is enabled
                                    if (applyToAll &&
                                        merchantKeyword.isNotEmpty) {
                                      await dataService.addMerchantRule(
                                        keyword: merchantKeyword,
                                        category: selectedCategory,
                                        isAuto: true,
                                      );
                                    }

                                    if (success && mounted) {
                                      final message = applyToAll
                                          ? 'Changed to $selectedCategory (Rule created for "$merchantKeyword")'
                                          : 'Changed to $selectedCategory';
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(message),
                                          backgroundColor:
                                              WealthInColors.success,
                                        ),
                                      );
                                      _loadTransactions();
                                    } else if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Failed to update category',
                                          ),
                                          backgroundColor: WealthInColors.error,
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: Text(
                              applyToAll ? 'Save & Create Rule' : 'Save',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Extract merchant keyword from transaction description for rule creation
  String _extractMerchantKeyword(String description) {
    if (description.isEmpty) return '';

    // Convert to uppercase and clean
    String cleaned = description.toUpperCase().trim();

    // Remove common prefixes
    final prefixes = ['UPI/', 'UPI-', 'POS ', 'NEFT/', 'IMPS/', 'ATM/'];
    for (var prefix in prefixes) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length);
      }
    }

    // Remove trailing reference numbers (e.g., *ORDER123)
    final refPattern = RegExp(r'[\*\-/#]\s*[A-Z0-9]{5,}$');
    cleaned = cleaned.replaceAll(refPattern, '');

    // Remove standalone numbers at end
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), '');

    // Remove common suffixes
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+PRIVATE\s+LIMITED.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+PVT\s+LTD.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+LTD.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+INDIA$', caseSensitive: false),
      '',
    );

    // Replace special chars with spaces
    cleaned = cleaned.replaceAll(RegExp(r'[\-_/\*]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Take first 2 significant words
    final words = cleaned.split(' ').where((w) => w.length > 2).toList();
    if (words.isEmpty) return cleaned.split(' ').first;
    if (words.length >= 2) return '${words[0]} ${words[1]}';
    return words.first;
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
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                            onTap: () =>
                                setModalState(() => selectedType = 'expense'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeButton(
                            label: 'Income',
                            icon: Icons.arrow_upward,
                            isSelected: selectedType == 'income',
                            color: WealthInColors.success,
                            onTap: () =>
                                setModalState(() => selectedType = 'income'),
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
                        DropdownMenuItem(
                          value: 'Groceries',
                          child: Text('Groceries'),
                        ),
                        DropdownMenuItem(value: 'Food', child: Text('Food')),
                        DropdownMenuItem(
                          value: 'Transport',
                          child: Text('Transport'),
                        ),
                        DropdownMenuItem(
                          value: 'Utilities',
                          child: Text('Utilities'),
                        ),
                        DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                        DropdownMenuItem(
                          value: 'Housing',
                          child: Text('Housing'),
                        ),
                        DropdownMenuItem(
                          value: 'Entertainment',
                          child: Text('Entertainment'),
                        ),
                        DropdownMenuItem(
                          value: 'Health',
                          child: Text('Health'),
                        ),
                        DropdownMenuItem(
                          value: 'Medical',
                          child: Text('Medical'),
                        ),
                        DropdownMenuItem(
                          value: 'Education',
                          child: Text('Education'),
                        ),
                        DropdownMenuItem(value: 'Legal', child: Text('Legal')),
                        DropdownMenuItem(
                          value: 'Shopping',
                          child: Text('Shopping'),
                        ),
                        DropdownMenuItem(
                          value: 'Salary',
                          child: Text('Salary'),
                        ),
                        DropdownMenuItem(
                          value: 'Freelance',
                          child: Text('Freelance'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) =>
                          setModalState(() => selectedCategory = value!),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountController.text) ?? 0;
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
                                    content: Text(
                                      'Transaction added successfully!',
                                    ),
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
          color: isSelected
              ? chipColor.withValues(alpha: 0.15)
              : Colors.transparent,
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
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${transaction.category} • ${_formatDate(transaction.date)}${transaction.paymentMethod != null ? ' • ${transaction.paymentMethod}' : ''}',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelectionMode
            ? null
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isIncome ? '+' : '-'}₹${transaction.amount.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('dining')) return Icons.restaurant;
    if (cat.contains('grocery') || cat.contains('groceries'))
      return Icons.local_grocery_store;
    if (cat.contains('transport') ||
        cat.contains('travel') ||
        cat.contains('commute'))
      return Icons.directions_car;
    if (cat.contains('shopping')) return Icons.shopping_bag;
    if (cat.contains('bill') || cat.contains('utilities'))
      return Icons.receipt_long;
    if (cat.contains('entertainment') || cat.contains('movie'))
      return Icons.movie;
    if (cat.contains('health') ||
        cat.contains('medical') ||
        cat.contains('pharmacy'))
      return Icons.medical_services;
    if (cat.contains('education') || cat.contains('school'))
      return Icons.school;
    if (cat.contains('salary') || cat.contains('income'))
      return Icons.attach_money;
    if (cat.contains('invest') ||
        cat.contains('stock') ||
        cat.contains('trading'))
      return Icons.trending_up;
    if (cat.contains('rent') ||
        cat.contains('house') ||
        cat.contains('housing'))
      return Icons.home;
    if (cat.contains('insurance')) return Icons.security;
    if (cat.contains('loan') || cat.contains('emi'))
      return Icons.account_balance;
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
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
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
