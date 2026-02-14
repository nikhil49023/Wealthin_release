import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart' show authService;
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/theme/wealthin_theme.dart';

/// Scheduled Payments Screen - Manage recurring payments and bills
class ScheduledPaymentsScreen extends StatelessWidget {
  const ScheduledPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Payments')),
      body: const ScheduledPaymentsScreenBody(),
    );
  }
}

/// Body content for embedding in tabs
class ScheduledPaymentsScreenBody extends StatefulWidget {
  const ScheduledPaymentsScreenBody({super.key});

  @override
  State<ScheduledPaymentsScreenBody> createState() =>
      _ScheduledPaymentsScreenBodyState();
}

class _ScheduledPaymentsScreenBodyState
    extends State<ScheduledPaymentsScreenBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ScheduledPaymentData> _allPayments = [];
  List<ScheduledPaymentData> _upcomingPayments = [];
  List<ScheduledPaymentData> _overduePayments = [];

  final DataService dataService = DataService();
  String get _userId => authService.currentUserId;

  final Map<String, IconData> _categoryIcons = {
    'Bills': Icons.receipt_long,
    'Subscriptions': Icons.subscriptions,
    'Insurance': Icons.health_and_safety,
    'Rent': Icons.home,
    'Loan': Icons.account_balance,
    'Utilities': Icons.electrical_services,
    'Internet': Icons.wifi,
    'Phone': Icons.phone_android,
    'Other': Icons.payments,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await dataService.getScheduledPayments(_userId);
      final now = DateTime.now();
      setState(() {
        _allPayments = payments;
        _upcomingPayments = payments
            .where((p) => _parseDate(p.nextDueDate).isAfter(now))
            .toList();
        _overduePayments = payments
            .where((p) => _parseDate(p.nextDueDate).isBefore(now))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading payments: $e');
      setState(() => _isLoading = false);
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab bar in body for embedded use
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 6),
                    const Text('Upcoming'),
                    if (_upcomingPayments.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_upcomingPayments.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber, size: 18),
                    const SizedBox(width: 6),
                    const Text('Overdue'),
                    if (_overduePayments.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_overduePayments.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Tab(text: 'All'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _PaymentsList(
                        payments: _upcomingPayments,
                        emptyMessage: 'No upcoming payments',
                        emptyIcon: Icons.event_available,
                        categoryIcons: _categoryIcons,
                        onMarkPaid: _markAsPaid,
                        onEdit: _showEditPaymentDialog,
                        onDelete: _deletePayment,
                        onRefresh: _loadPayments,
                      ),
                      _PaymentsList(
                        payments: _overduePayments,
                        emptyMessage: 'No overdue payments',
                        emptyIcon: Icons.check_circle_outline,
                        categoryIcons: _categoryIcons,
                        onMarkPaid: _markAsPaid,
                        onEdit: _showEditPaymentDialog,
                        onDelete: _deletePayment,
                        onRefresh: _loadPayments,
                        isOverdue: true,
                      ),
                      _PaymentsList(
                        payments: _allPayments,
                        emptyMessage: 'No scheduled payments',
                        emptyIcon: Icons.payments_outlined,
                        categoryIcons: _categoryIcons,
                        onMarkPaid: _markAsPaid,
                        onEdit: _showEditPaymentDialog,
                        onDelete: _deletePayment,
                        onRefresh: _loadPayments,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
      ).animate().scale(delay: 300.ms),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Bills';
    String selectedFrequency = 'monthly';
    DateTime nextDue = DateTime.now().add(const Duration(days: 7));
    bool autoTrack = true;

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
              child: SingleChildScrollView(
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
                      'Schedule Payment',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Name',
                        hintText: 'e.g., Netflix, Electricity Bill',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.currency_rupee),
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
                      items: _categoryIcons.keys.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(_categoryIcons[cat], size: 20),
                              const SizedBox(width: 10),
                              Text(cat),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'biweekly',
                          child: Text('Bi-weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'quarterly',
                          child: Text('Quarterly'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedFrequency = val!),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text('Next Due: ${_formatDate(nextDue)}'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: nextDue,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => nextDue = picked);
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-track transactions'),
                      subtitle: const Text('Automatically record when paid'),
                      value: autoTrack,
                      onChanged: (val) => setModalState(() => autoTrack = val),
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
                            final result = await dataService
                                .createScheduledPayment(
                                  userId: _userId,
                                  name: name,
                                  amount: amount,
                                  category: selectedCategory,
                                  dueDate: nextDue.toIso8601String().split(
                                    'T',
                                  )[0],
                                  frequency: selectedFrequency,
                                  isAutopay: autoTrack,
                                );
                            if (context.mounted) Navigator.pop(context);
                            if (result != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Payment "$name" scheduled successfully!',
                                  ),
                                  backgroundColor: AppTheme.incomeGreen,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to schedule payment'),
                                  backgroundColor: AppTheme.expenseRed,
                                ),
                              );
                            }
                            _loadPayments();
                          }
                        },
                        child: const Text('Schedule Payment'),
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

  void _showEditPaymentDialog(
    BuildContext context,
    ScheduledPaymentData payment,
  ) {
    final nameController = TextEditingController(text: payment.name);
    final amountController = TextEditingController(
      text: payment.amount.toString(),
    );
    String selectedCategory = payment.category.isNotEmpty
        ? payment.category
        : 'Bills';
    String selectedFrequency = payment.frequency;
    DateTime nextDue = _parseDate(payment.nextDueDate);
    bool autoTrack = payment.isAutopay;

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
              child: SingleChildScrollView(
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
                      'Edit Payment',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Name',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.currency_rupee),
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
                      items: _categoryIcons.keys.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(_categoryIcons[cat], size: 20),
                              const SizedBox(width: 10),
                              Text(cat),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'biweekly',
                          child: Text('Bi-weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'quarterly',
                          child: Text('Quarterly'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedFrequency = val!),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text('Next Due: ${_formatDate(nextDue)}'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: nextDue,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => nextDue = picked);
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-track transactions'),
                      value: autoTrack,
                      onChanged: (val) => setModalState(() => autoTrack = val),
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
                          if (name.isNotEmpty &&
                              amount > 0 &&
                              payment.id != null) {
                            final result = await dataService
                                .updateScheduledPayment(
                                  userId: _userId,
                                  paymentId: payment.id!,
                                  name: name,
                                  amount: amount,
                                  category: selectedCategory,
                                  frequency: selectedFrequency,
                                  isAutopay: autoTrack,
                                );
                            if (context.mounted) Navigator.pop(context);
                            if (result != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Payment "$name" updated successfully!',
                                  ),
                                  backgroundColor: AppTheme.incomeGreen,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update payment'),
                                  backgroundColor: AppTheme.expenseRed,
                                ),
                              );
                            }
                            _loadPayments();
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

  Future<void> _markAsPaid(ScheduledPaymentData payment) async {
    if (payment.id != null) {
      final result = await dataService.markPaymentPaid(_userId, payment.id!);
      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${payment.name} marked as paid!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.incomeGreen,
            ),
          );
        }
        _loadPayments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to mark ${payment.name} as paid'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.expenseRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePayment(ScheduledPaymentData payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Delete "${payment.name}"? This cannot be undone.'),
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

    if (confirmed == true && payment.id != null) {
      final success = await dataService.deleteScheduledPayment(
        _userId,
        payment.id!,
      );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${payment.name}" deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadPayments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete "${payment.name}"'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.expenseRed,
            ),
          );
        }
      }
    }
  }
}

/// Payments list widget
class _PaymentsList extends StatelessWidget {
  final List<ScheduledPaymentData> payments;
  final String emptyMessage;
  final IconData emptyIcon;
  final Map<String, IconData> categoryIcons;
  final Function(ScheduledPaymentData) onMarkPaid;
  final Function(BuildContext, ScheduledPaymentData) onEdit;
  final Function(ScheduledPaymentData) onDelete;
  final VoidCallback onRefresh;
  final bool isOverdue;

  const _PaymentsList({
    required this.payments,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.categoryIcons,
    required this.onMarkPaid,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: WealthInTheme.gray400),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: WealthInTheme.gray600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          return _PaymentCard(
            payment: payment,
            icon: categoryIcons[payment.category] ?? Icons.payments,
            onMarkPaid: () => onMarkPaid(payment),
            onEdit: () => onEdit(context, payment),
            onDelete: () => onDelete(payment),
            isOverdue: isOverdue,
          ).animate(delay: (index * 50).ms).fadeIn().slideX();
        },
      ),
    );
  }
}

/// Individual payment card
class _PaymentCard extends StatelessWidget {
  final ScheduledPaymentData payment;
  final IconData icon;
  final VoidCallback onMarkPaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isOverdue;

  const _PaymentCard({
    required this.payment,
    required this.icon,
    required this.onMarkPaid,
    required this.onEdit,
    required this.onDelete,
    this.isOverdue = false,
  });

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysUntil = _parseDate(
      payment.nextDueDate,
    ).difference(DateTime.now()).inDays;
    final isDueSoon = daysUntil <= 3 && daysUntil >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue
            ? const BorderSide(color: AppTheme.expenseRed, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? AppTheme.expenseRed.withValues(alpha: 0.1)
                          : isDueSoon
                          ? AppTheme.warning.withValues(alpha: 0.1)
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isOverdue
                          ? AppTheme.expenseRed
                          : isDueSoon
                          ? AppTheme.warning
                          : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                payment.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!payment.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: WealthInTheme.gray200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Paused',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: WealthInTheme.gray600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${payment.amount.toStringAsFixed(0)} • ${_capitalizeFirst(payment.frequency)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
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
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.error
                            : isDueSoon
                            ? Icons.warning_amber
                            : Icons.event,
                        size: 16,
                        color: isOverdue
                            ? AppTheme.expenseRed
                            : isDueSoon
                            ? AppTheme.warning
                            : WealthInTheme.gray600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOverdue
                            ? 'Overdue by ${-daysUntil} days'
                            : daysUntil == 0
                            ? 'Due today'
                            : daysUntil == 1
                            ? 'Due tomorrow'
                            : 'Due in $daysUntil days',
                        style: TextStyle(
                          fontSize: 13,
                          color: isOverdue
                              ? AppTheme.expenseRed
                              : isDueSoon
                              ? AppTheme.warning
                              : WealthInTheme.gray600,
                          fontWeight: isOverdue || isDueSoon
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: onMarkPaid,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Mark Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.incomeGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

String _capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
