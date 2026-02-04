import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart' show authService;
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';

/// Savings Goals Screen - Track progress towards financial goals
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      body: const GoalsScreenBody(),
    );
  }
}

/// Body content for embedding in tabs
class GoalsScreenBody extends StatefulWidget {
  const GoalsScreenBody({super.key});

  @override
  State<GoalsScreenBody> createState() => _GoalsScreenBodyState();
}

class _GoalsScreenBodyState extends State<GoalsScreenBody> {
  bool _isLoading = true;
  List<GoalData> _goals = [];
  Map<String, dynamic> _progress = {};

  String get _userId => authService.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final goals = await dataService.getGoals(_userId);

      // Calculate progress
      double totalTarget = 0;
      double totalCurrent = 0;
      int completed = 0;
      for (final g in goals) {
        totalTarget += g.targetAmount;
        totalCurrent += g.currentAmount;
        if (g.currentAmount >= g.targetAmount) completed++;
      }

      if (mounted) {
        setState(() {
          _goals = goals;
          _progress = {
            'totalGoals': goals.length,
            'completedGoals': completed,
            'totalTarget': totalTarget,
            'totalCurrent': totalCurrent,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGoals,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overall Progress Card
                        _OverallProgressCard(
                          progress: _progress,
                        ).animate().fadeIn().slideY(begin: -0.1),
                        const SizedBox(height: 24),

                        // Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Goals',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showAddGoalDialog(context),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Add Goal'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Goals List
                        if (_goals.isEmpty)
                          _EmptyGoalsPlaceholder(
                            onAdd: () => _showAddGoalDialog(context),
                          )
                        else
                          ..._goals.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child:
                                  _GoalCard(
                                        goal: entry.value,
                                        onEdit: () => _showEditGoalDialog(
                                          context,
                                          entry.value,
                                        ),
                                        onAddFunds: () => _showAddFundsDialog(
                                          context,
                                          entry.value,
                                        ),
                                        onDelete: () =>
                                            _deleteGoal(entry.value),
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
        onPressed: () => _showAddGoalDialog(context),
        icon: const Icon(Icons.flag),
        label: const Text('New Goal'),
      ).animate().scale(delay: 300.ms),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? deadline;

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
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create Savings Goal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      hintText: 'e.g., Emergency Fund, Vacation, New Car',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Target Amount',
                      hintText: '100000',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      deadline != null
                          ? 'Deadline: ${_formatDate(deadline!)}'
                          : 'Set Deadline (Optional)',
                    ),
                    trailing: deadline != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setModalState(() => deadline = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 90),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => deadline = picked);
                      }
                    },
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
                          // Create goal via API
                          final created = await dataService.createGoal(
                            userId: _userId,
                            name: name,
                            targetAmount: amount,
                            deadline: deadline?.toIso8601String(),
                          );

                          if (context.mounted) Navigator.pop(context);

                          if (created != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Goal "$name" created! 🎯'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                            _loadGoals();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to create goal'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Create Goal'),
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

  void _showEditGoalDialog(BuildContext context, GoalData goal) {
    final nameController = TextEditingController(text: goal.name);
    final amountController = TextEditingController(
      text: goal.targetAmount.toString(),
    );
    DateTime? deadline = goal.deadline != null
        ? DateTime.tryParse(goal.deadline!)
        : null;

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
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Edit Goal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      prefixIcon: Icon(Icons.flag),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Target Amount',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      deadline != null
                          ? 'Deadline: ${_formatDate(deadline!)}'
                          : 'Set Deadline',
                    ),
                    trailing: deadline != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setModalState(() => deadline = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            deadline ??
                            DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => deadline = picked);
                      }
                    },
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

                          // Update goal via API
                          final updated = await dataService.updateGoal(
                            userId: _userId,
                            goalId: goal.id!,
                            name: name,
                            targetAmount: amount,
                            deadline: deadline?.toIso8601String(),
                          );

                          if (updated != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Goal "$name" updated! ✅'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update goal'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                          _loadGoals();
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

  void _showAddFundsDialog(BuildContext context, GoalData goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ₹${_formatAmount(goal.currentAmount)} / ₹${_formatAmount(goal.targetAmount)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount to Add',
                prefixText: '₹',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                if (context.mounted) Navigator.pop(context);

                // Add funds via API
                final updated = await dataService.addFundsToGoal(
                  userId: _userId,
                  goalId: goal.id!,
                  amount: amount,
                );

                if (updated != null) {
                  final message = updated.isCompleted
                      ? '🎉 Goal "${goal.name}" completed!'
                      : '₹${_formatAmount(amount)} added to "${goal.name}"';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to add funds'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
                _loadGoals();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(GoalData goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${goal.name}"? This cannot be undone.'),
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

    if (confirmed == true && goal.id != null) {
      final deleted = await dataService.deleteGoal(_userId, goal.id!);
      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal "${goal.name}" deleted'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _loadGoals();
    }
  }
}

/// Overall progress card
class _OverallProgressCard extends StatelessWidget {
  final Map<String, dynamic> progress;

  const _OverallProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalGoals = progress['totalGoals'] ?? 0;
    final completedGoals = progress['completedGoals'] ?? 0;
    final totalTarget = (progress['totalTarget'] ?? 0).toDouble();
    final totalCurrent = (progress['totalCurrent'] ?? 0).toDouble();
    final overallProgress = totalTarget > 0 ? totalCurrent / totalTarget : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
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
                  'Overall Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$completedGoals/$totalGoals complete',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${_formatAmount(totalCurrent)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'saved of ₹${_formatAmount(totalTarget)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: overallProgress.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                      Text(
                        '${(overallProgress * 100).toInt()}%',
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
          ],
        ),
      ),
    );
  }
}

/// Individual goal card
class _GoalCard extends StatelessWidget {
  final GoalData goal;
  final VoidCallback onEdit;
  final VoidCallback onAddFunds;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onAddFunds,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount)
        : 0.0;
    final isCompleted = goal.currentAmount >= goal.targetAmount;
    final daysLeft = goal.deadline != null
        ? DateTime.tryParse(goal.deadline!)?.difference(DateTime.now()).inDays
        : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.incomeGreen.withOpacity(0.1)
                        : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.flag,
                    color: isCompleted
                        ? AppTheme.incomeGreen
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
                              goal.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (goal.status == 'completed')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.incomeGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.incomeGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_formatAmount(goal.currentAmount)} / ₹${_formatAmount(goal.targetAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
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
            const SizedBox(height: 16),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  isCompleted ? AppTheme.incomeGreen : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Footer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (daysLeft != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: daysLeft < 30
                          ? AppTheme.warning.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: daysLeft < 30
                              ? AppTheme.warning
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          daysLeft > 0 ? '$daysLeft days left' : 'Overdue',
                          style: TextStyle(
                            fontSize: 12,
                            color: daysLeft < 30
                                ? AppTheme.warning
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? AppTheme.incomeGreen
                        : AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Add funds button
            if (!isCompleted)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddFunds,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Funds'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.incomeGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.celebration,
                      color: AppTheme.incomeGreen,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Goal Achieved! 🎉',
                      style: TextStyle(
                        color: AppTheme.incomeGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty state placeholder
class _EmptyGoalsPlaceholder extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyGoalsPlaceholder({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No savings goals yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Set financial goals to track your savings progress',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.flag),
              label: const Text('Create First Goal'),
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

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
