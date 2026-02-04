import 'package:serverpod/serverpod.dart' hide Transaction;
import '../generated/protocol.dart';
import 'openai_service.dart';

/// AIToolsService - Enables the AI advisor to take actions in the app
/// Implements function calling for budgets, payments, savings goals, etc.
class AIToolsService {
  static final AIToolsService _instance = AIToolsService._internal();
  factory AIToolsService() => _instance;
  AIToolsService._internal();

  final OpenAIService _openai = OpenAIService();

  /// Available tools/functions the AI can call
  static final List<Map<String, dynamic>> _tools = [
    {
      'name': 'create_budget',
      'description':
          'Create a new budget category for the user. Use when user wants to set a spending limit for a category.',
      'parameters': {
        'type': 'object',
        'properties': {
          'category': {
            'type': 'string',
            'description':
                'Budget category name (e.g., Food, Transport, Entertainment)',
          },
          'amount': {
            'type': 'number',
            'description': 'Monthly budget amount in INR',
          },
          'period': {
            'type': 'string',
            'enum': ['monthly', 'weekly', 'yearly'],
            'description': 'Budget period',
          },
        },
        'required': ['category', 'amount'],
      },
    },
    {
      'name': 'create_savings_goal',
      'description':
          'Create a savings goal for the user. Use when user wants to save for something.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Name of the savings goal (e.g., Emergency Fund, Vacation)',
          },
          'targetAmount': {
            'type': 'number',
            'description': 'Target amount to save in INR',
          },
          'targetDate': {
            'type': 'string',
            'description': 'Target date to reach the goal (YYYY-MM-DD format)',
          },
          'currentAmount': {
            'type': 'number',
            'description': 'Current saved amount (default 0)',
          },
        },
        'required': ['name', 'targetAmount'],
      },
    },
    {
      'name': 'schedule_payment',
      'description':
          'Schedule a recurring payment or reminder. Use when user wants to set up bill reminders.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Payment name (e.g., Rent, Netflix, EMI)',
          },
          'amount': {
            'type': 'number',
            'description': 'Payment amount in INR',
          },
          'dueDay': {
            'type': 'integer',
            'description': 'Day of month when payment is due (1-31)',
          },
          'frequency': {
            'type': 'string',
            'enum': ['monthly', 'weekly', 'yearly', 'once'],
            'description': 'Payment frequency',
          },
          'category': {
            'type': 'string',
            'description': 'Category of the payment',
          },
        },
        'required': ['name', 'amount', 'dueDay'],
      },
    },
    {
      'name': 'add_transaction',
      'description':
          'Add a new transaction (income or expense). Use when user mentions spending or earning money.',
      'parameters': {
        'type': 'object',
        'properties': {
          'description': {
            'type': 'string',
            'description': 'Transaction description',
          },
          'amount': {
            'type': 'number',
            'description': 'Transaction amount in INR',
          },
          'type': {
            'type': 'string',
            'enum': ['income', 'expense'],
            'description': 'Transaction type',
          },
          'category': {
            'type': 'string',
            'description': 'Transaction category',
          },
        },
        'required': ['description', 'amount', 'type'],
      },
    },
    {
      'name': 'get_spending_summary',
      'description':
          'Get spending summary for a period. Use when user asks about their spending.',
      'parameters': {
        'type': 'object',
        'properties': {
          'period': {
            'type': 'string',
            'enum': ['today', 'week', 'month', 'year'],
            'description': 'Time period for summary',
          },
          'category': {
            'type': 'string',
            'description': 'Optional category filter',
          },
        },
        'required': ['period'],
      },
    },
  ];

  /// Process a query with tool/function calling capability
  Future<AIToolResponse> processWithTools(
    Session session,
    String query,
    int userId,
  ) async {
    try {
      // Ask OpenAI if it needs to call any tools
      final result = await _openai.functionCall(
        query,
        _tools,
        systemPrompt: '''You are WealthIn AI, a financial assistant. 
You can help users manage their finances by:
- Creating budgets
- Setting savings goals  
- Scheduling payment reminders
- Adding transactions
- Getting spending summaries

If the user's request requires any of these actions, call the appropriate function.
If it's just a question or conversation, respond normally without calling functions.
Always be helpful and use Indian Rupee (₹) for amounts.''',
      );

      if (result['type'] == 'function_call') {
        // Execute the function
        final functionName = result['function'] as String;
        final arguments = result['arguments'] as Map<String, dynamic>;

        final actionResult = await _executeFunction(
          session,
          functionName,
          arguments,
          userId,
        );

        return AIToolResponse(
          response: actionResult['message'] as String,
          actionTaken: true,
          actionType: functionName,
          actionData: actionResult,
        );
      } else {
        // No function call, return the message
        return AIToolResponse(
          response: result['content'] as String? ?? '',
          actionTaken: false,
        );
      }
    } catch (e) {
      session.log('AI Tools error: $e', level: LogLevel.error);
      return AIToolResponse(
        response:
            "I understood your request but couldn't complete the action. Please try again.",
        actionTaken: false,
        error: e.toString(),
      );
    }
  }

  /// Execute a confirmed action directly (for confirmation flow)
  Future<Map<String, dynamic>> executeConfirmedAction(
    Session session,
    String actionType,
    Map<String, dynamic> parameters,
    int userId,
  ) async {
    try {
      return await _executeFunction(session, actionType, parameters, userId);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to execute action: $e',
      };
    }
  }

  /// Execute a function/tool
  Future<Map<String, dynamic>> _executeFunction(
    Session session,
    String functionName,
    Map<String, dynamic> args,
    int userId,
  ) async {
    switch (functionName) {
      case 'create_budget':
        return await _createBudget(session, args, userId);
      case 'create_savings_goal':
        return await _createSavingsGoal(session, args, userId);
      case 'schedule_payment':
        return await _schedulePayment(session, args, userId);
      case 'add_transaction':
        return await _addTransaction(session, args, userId);
      case 'get_spending_summary':
        return await _getSpendingSummary(session, args, userId);
      default:
        return {'success': false, 'message': 'Unknown action'};
    }
  }

  Future<Map<String, dynamic>> _createBudget(
    Session session,
    Map<String, dynamic> args,
    int userId,
  ) async {
    final category = args['category'] as String;
    final amount = (args['amount'] as num).toDouble();
    final period = args['period'] as String? ?? 'monthly';

    try {
      final budget = Budget(
        userProfileId: userId,
        name: category,
        category: category,
        amount: amount,
        period: period,
        spent: 0,
        icon: _getCategoryIcon(category),
      );

      await Budget.db.insertRow(session, budget);

      return {
        'success': true,
        'message':
            '✅ Budget created! I\'ve set a $period budget of ₹${amount.toStringAsFixed(0)} for $category. You can view and track it in the Budgets section.',
        'budget': {
          'category': category,
          'amount': amount,
          'period': period,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create budget: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _createSavingsGoal(
    Session session,
    Map<String, dynamic> args,
    int userId,
  ) async {
    final name = args['name'] as String;
    final targetAmount = (args['targetAmount'] as num).toDouble();
    final currentAmount = (args['currentAmount'] as num?)?.toDouble() ?? 0;
    final targetDateStr = args['targetDate'] as String?;

    DateTime? targetDate;
    if (targetDateStr != null) {
      try {
        targetDate = DateTime.parse(targetDateStr);
      } catch (_) {}
    }

    try {
      final goal = Goal(
        userProfileId: userId,
        name: name,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        deadline: targetDate ?? DateTime.now().add(const Duration(days: 365)),
        isDefault: false,
      );

      await Goal.db.insertRow(session, goal);

      final remaining = targetAmount - currentAmount;
      return {
        'success': true,
        'message':
            '🎯 Savings goal "$name" created! Target: ₹${targetAmount.toStringAsFixed(0)}. You need to save ₹${remaining.toStringAsFixed(0)} more. Check the Goals section to track progress!',
        'goal': {
          'name': name,
          'targetAmount': targetAmount,
          'currentAmount': currentAmount,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create savings goal: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _schedulePayment(
    Session session,
    Map<String, dynamic> args,
    int userId,
  ) async {
    final name = args['name'] as String;
    final amount = (args['amount'] as num).toDouble();
    final dueDay = args['dueDay'] as int;
    final frequency = args['frequency'] as String? ?? 'monthly';
    final category = args['category'] as String? ?? 'Bills';

    try {
      // Calculate the next due date based on dueDay
      final now = DateTime.now();
      var nextDue = DateTime(now.year, now.month, dueDay);
      if (nextDue.isBefore(now)) {
        nextDue = DateTime(now.year, now.month + 1, dueDay);
      }

      final payment = ScheduledPayment(
        userProfileId: userId,
        name: name,
        amount: amount,
        nextDueDate: nextDue,
        frequency: frequency,
        category: category,
        isActive: true,
        autoTrack: false,
        createdAt: DateTime.now(),
      );

      await ScheduledPayment.db.insertRow(session, payment);

      return {
        'success': true,
        'message':
            '📅 Payment reminder set! I\'ll remind you about "$name" (₹${amount.toStringAsFixed(0)}) on day $dueDay of each month. View all scheduled payments in the Payments section.',
        'payment': {
          'name': name,
          'amount': amount,
          'dueDay': dueDay,
          'frequency': frequency,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to schedule payment: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _addTransaction(
    Session session,
    Map<String, dynamic> args,
    int userId,
  ) async {
    final description = args['description'] as String;
    final amount = (args['amount'] as num).toDouble();
    final type = args['type'] as String;
    final category = args['category'] as String? ?? 'Other';

    try {
      final transaction = Transaction(
        userProfileId: userId,
        description: description,
        amount: amount,
        type: type,
        category: category,
        date: DateTime.now(),
      );

      await Transaction.db.insertRow(session, transaction);

      final icon = type == 'income' ? '💰' : '💸';
      final verb = type == 'income' ? 'recorded' : 'recorded';

      return {
        'success': true,
        'message':
            '$icon Transaction $verb! ${type == 'income' ? '+' : '-'}₹${amount.toStringAsFixed(0)} for "$description" ($category). View all transactions in the Transactions section.',
        'transaction': {
          'description': description,
          'amount': amount,
          'type': type,
          'category': category,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to add transaction: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _getSpendingSummary(
    Session session,
    Map<String, dynamic> args,
    int userId,
  ) async {
    final period = args['period'] as String;
    final categoryFilter = args['category'] as String?;

    try {
      DateTime startDate;
      final now = DateTime.now();

      switch (period) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      var query = Transaction.db.find(
        session,
        where: (t) => t.userProfileId.equals(userId) & t.date.notEquals(null),
      );

      final transactions = await query;

      // Filter by date and optionally category
      final filtered = transactions.where((t) {
        if (t.date.isBefore(startDate)) return false;
        if (categoryFilter != null && t.category != categoryFilter) {
          return false;
        }
        return true;
      }).toList();

      double totalIncome = 0;
      double totalExpense = 0;
      final categoryTotals = <String, double>{};

      for (final t in filtered) {
        if (t.type == 'income') {
          totalIncome += t.amount;
        } else {
          totalExpense += t.amount;
          categoryTotals[t.category] =
              (categoryTotals[t.category] ?? 0) + t.amount;
        }
      }

      // Build summary message
      final buffer = StringBuffer();
      buffer.writeln('📊 **Spending Summary ($period)**');
      buffer.writeln('');
      buffer.writeln('💰 Income: ₹${totalIncome.toStringAsFixed(0)}');
      buffer.writeln('💸 Expenses: ₹${totalExpense.toStringAsFixed(0)}');
      buffer.writeln(
        '💵 Net: ₹${(totalIncome - totalExpense).toStringAsFixed(0)}',
      );

      if (categoryTotals.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('**By Category:**');
        final sorted = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sorted.take(5)) {
          buffer.writeln('• ${entry.key}: ₹${entry.value.toStringAsFixed(0)}');
        }
      }

      return {
        'success': true,
        'message': buffer.toString(),
        'data': {
          'income': totalIncome,
          'expense': totalExpense,
          'categories': categoryTotals,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get spending summary: $e',
      };
    }
  }

  /// Get category icon for budget
  String _getCategoryIcon(String category) {
    final icons = {
      'food': '🍔',
      'groceries': '🛒',
      'transport': '🚗',
      'entertainment': '🎬',
      'shopping': '🛍️',
      'bills': '📄',
      'health': '💊',
      'education': '📚',
      'travel': '✈️',
      'utilities': '💡',
      'rent': '🏠',
      'other': '📦',
    };
    return icons[category.toLowerCase()] ?? '💰';
  }
}

/// Response from AI with potential action
class AIToolResponse {
  final String response;
  final bool actionTaken;
  final String? actionType;
  final Map<String, dynamic>? actionData;
  final String? error;

  AIToolResponse({
    required this.response,
    required this.actionTaken,
    this.actionType,
    this.actionData,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'response': response,
    'actionTaken': actionTaken,
    if (actionType != null) 'actionType': actionType,
    if (actionData != null) 'actionData': actionData,
    if (error != null) 'error': error,
  };
}
