import 'dart:convert';
import 'dart:math' as math;
import 'package:serverpod/serverpod.dart' hide Transaction;
import '../services/zoho_service.dart';
import '../generated/protocol.dart';

/// AgentEndpoint: The brain of the agentic system.
/// Handles intent detection, tool calling, and action execution.
class AgentEndpoint extends Endpoint {
  
  /// Main chat endpoint with function calling support
  Future<Map<String, dynamic>> chat(
    Session session,
    String userMessage, {
    int? userId,
    List<Transaction>? recentTransactions,
  }) async {
    try {
      // Build context from user data
      final transactionContext = recentTransactions?.map((t) => 
        '- ${t.description}: ₹${t.amount} (${t.type}) on ${t.date.toIso8601String().split('T')[0]}'
      ).join('\n') ?? 'No transaction history available.';

      // System prompt with function calling instructions
      const systemPrompt = '''You are "WealthIn," a friendly and proactive financial advisor for entrepreneurs in India.
Your tone should be encouraging and helpful. You have the power to take actions on behalf of the user.

**AVAILABLE TOOLS:**
You can trigger these actions by responding with a JSON object:

1. `upsert_budget` - Set spending limits
   Parameters: {"category": "Food", "limit": 5000, "period": "monthly"}

2. `create_savings_goal` - Create savings targets
   Parameters: {"name": "Emergency Fund", "target_amount": 100000, "deadline": "2025-12-31"}

3. `add_debt` - Track loans/EMIs
   Parameters: {"name": "Car Loan", "principal": 500000, "interest_rate": 9.5, "emi": 11000, "tenure_months": 60}

4. `schedule_payment` - Set payment reminders
   Parameters: {"name": "Rent", "amount": 15000, "frequency": "monthly", "next_due": "2025-02-01"}

5. `analyze_investment` - Calculate returns (SIP, FD, EMI)
   Parameters: {"investment_type": "sip", "principal": 5000, "rate": 12, "duration_months": 60}

6. `generate_cashflow_analysis` - Analyze spending patterns
   Parameters: {"period": "month"}

**RESPONSE FORMAT:**
- If the user wants to take an action, respond ONLY with a JSON object:
  {"action": "tool_name", "parameters": {...}, "confirmation_message": "I'll set a ₹5,000 limit for Food. Confirm?"}

- If the user just wants advice or information, respond naturally in markdown.

**PROACTIVE SUGGESTIONS:**
- If you notice spending patterns, proactively suggest budgets.
- If the user mentions saving, suggest creating a goal.
- Always be action-oriented - offer to DO things, not just advise.
''';

      final userPrompt = '''User's message: "$userMessage"

Recent Transactions:
$transactionContext

Analyze the user's intent and respond appropriately.''';

      // Call Zoho LLM
      final response = await ZohoService().chat(systemPrompt, userPrompt);
      
      // Try to parse as a tool call
      final toolCall = _parseToolCall(response);
      
      if (toolCall != null) {
        // It's a tool call - return action card data
        return {
          'type': 'action_card',
          'tool_name': toolCall['action'],
          'parameters': toolCall['parameters'],
          'confirmation_message': toolCall['confirmation_message'] ?? 'Would you like me to proceed?',
          'raw_response': response,
        };
      } else {
        // Regular text response
        return {
          'type': 'text',
          'message': response,
        };
      }
    } catch (e) {
      session.log('Agent Error: $e', level: LogLevel.error);
      return {
        'type': 'error',
        'message': 'I encountered an issue processing your request. Please try again.',
      };
    }
  }

  /// Execute a confirmed action
  Future<Map<String, dynamic>> executeAction(
    Session session,
    String actionType,
    String parametersJson,
    int userId,
  ) async {
    try {
      final params = jsonDecode(parametersJson) as Map<String, dynamic>;
      
      switch (actionType) {
        case 'upsert_budget':
          return await _executeBudgetAction(session, params, userId);
        case 'create_savings_goal':
          return await _executeGoalAction(session, params, userId);
        case 'add_debt':
          return await _executeDebtAction(session, params, userId);
        case 'schedule_payment':
          return await _executeScheduledPaymentAction(session, params, userId);
        case 'analyze_investment':
          return await _executeInvestmentAnalysis(params);
        case 'generate_cashflow_analysis':
          return await _executeCashflowAnalysis(session, params, userId);
        default:
          return {'success': false, 'error': 'Unknown action type: $actionType'};
      }
    } catch (e) {
      session.log('Action Execution Error: $e', level: LogLevel.error);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse LLM response for tool calls
  Map<String, dynamic>? _parseToolCall(String response) {
    try {
      // Find JSON in response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        if (parsed.containsKey('action') || parsed.containsKey('tool_name')) {
          return {
            'action': parsed['action'] ?? parsed['tool_name'],
            'parameters': parsed['parameters'] ?? parsed['params'] ?? {},
            'confirmation_message': parsed['confirmation_message'] ?? parsed['message'],
          };
        }
      }
    } catch (e) {
      // Not a tool call, just regular text
    }
    return null;
  }

  /// Execute budget upsert
  Future<Map<String, dynamic>> _executeBudgetAction(
    Session session,
    Map<String, dynamic> params,
    int userId,
  ) async {
    final budget = Budget(
      name: params['category'] as String,
      category: params['category'] as String,
      amount: (params['limit'] as num).toDouble(),
      limit: (params['limit'] as num).toDouble(),
      period: params['period'] as String? ?? 'monthly',
      spent: 0,
      icon: '💰',
      userProfileId: userId,
      createdAt: DateTime.now(),
    );
    
    // Check if budget exists for this category
    final existing = await Budget.db.findFirstRow(
      session,
      where: (t) => t.userProfileId.equals(userId) & t.category.equals(params['category'] as String),
    );
    
    if (existing != null) {
      existing.limit = budget.limit;
      existing.amount = budget.amount;
      existing.period = budget.period;
      existing.updatedAt = DateTime.now();
      await Budget.db.updateRow(session, existing);
      return {'success': true, 'message': 'Budget updated successfully!', 'id': existing.id};
    } else {
      final created = await Budget.db.insertRow(session, budget);
      return {'success': true, 'message': 'Budget created successfully!', 'id': created.id};
    }
  }

  /// Execute savings goal creation
  Future<Map<String, dynamic>> _executeGoalAction(
    Session session,
    Map<String, dynamic> params,
    int userId,
  ) async {
    DateTime? deadline;
    if (params['deadline'] != null) {
      deadline = DateTime.tryParse(params['deadline'] as String);
    }
    
    final goal = Goal(
      name: params['name'] as String,
      targetAmount: (params['target_amount'] as num).toDouble(),
      currentAmount: 0,
      deadline: deadline,
      status: 'in_progress',
      isDefault: false,
      userProfileId: userId,
      createdAt: DateTime.now(),
    );
    
    final created = await Goal.db.insertRow(session, goal);
    return {'success': true, 'message': 'Savings goal created!', 'id': created.id};
  }

  /// Execute debt tracking
  Future<Map<String, dynamic>> _executeDebtAction(
    Session session,
    Map<String, dynamic> params,
    int userId,
  ) async {
    final debt = Debt(
      userProfileId: userId,
      name: params['name'] as String,
      debtType: params['debt_type'] as String? ?? 'loan',
      principal: (params['principal'] as num).toDouble(),
      interestRate: (params['interest_rate'] as num?)?.toDouble() ?? 0,
      emi: (params['emi'] as num?)?.toDouble(),
      startDate: DateTime.now(),
      tenureMonths: params['tenure_months'] as int?,
      remainingAmount: (params['principal'] as num).toDouble(),
      status: 'active',
      createdAt: DateTime.now(),
    );
    
    final created = await Debt.db.insertRow(session, debt);
    return {'success': true, 'message': 'Debt added for tracking!', 'id': created.id};
  }

  /// Execute scheduled payment creation
  Future<Map<String, dynamic>> _executeScheduledPaymentAction(
    Session session,
    Map<String, dynamic> params,
    int userId,
  ) async {
    DateTime nextDue = DateTime.now().add(const Duration(days: 30));
    if (params['next_due'] != null) {
      nextDue = DateTime.tryParse(params['next_due'] as String) ?? nextDue;
    }
    
    final payment = ScheduledPayment(
      userProfileId: userId,
      name: params['name'] as String,
      amount: (params['amount'] as num).toDouble(),
      frequency: params['frequency'] as String? ?? 'monthly',
      nextDueDate: nextDue,
      autoTrack: params['auto_track'] as bool? ?? false,
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    final created = await ScheduledPayment.db.insertRow(session, payment);
    return {'success': true, 'message': 'Payment scheduled!', 'id': created.id};
  }

  /// Execute investment analysis (calls Python sidecar)
  Future<Map<String, dynamic>> _executeInvestmentAnalysis(
    Map<String, dynamic> params,
  ) async {
    // This would call the Python sidecar
    // For now, return calculated data
    final type = params['investment_type'] as String? ?? 'sip';
    final principal = (params['principal'] as num).toDouble();
    final rate = (params['rate'] as num).toDouble();
    final months = params['duration_months'] as int? ?? 12;
    
    switch (type) {
      case 'sip':
        final monthlyRate = rate / 12 / 100;
        final futureValue = principal * ((math.pow(1 + monthlyRate, months) - 1) / monthlyRate) * (1 + monthlyRate);
        final totalInvested = principal * months;
        return {
          'success': true,
          'type': 'sip',
          'data': {
            'total_invested': totalInvested,
            'future_value': futureValue.round(),
            'total_returns': (futureValue - totalInvested).round(),
          }
        };
      case 'fd':
        final maturity = principal * math.pow(1 + rate / 400, 4 * months / 12);
        return {
          'success': true,
          'type': 'fd',
          'data': {
            'principal': principal,
            'maturity_value': maturity.round(),
            'total_interest': (maturity - principal).round(),
          }
        };
      case 'emi':
        final monthlyRate = rate / 12 / 100;
        final emi = principal * monthlyRate * math.pow(1 + monthlyRate, months) / (math.pow(1 + monthlyRate, months) - 1);
        return {
          'success': true,
          'type': 'emi',
          'data': {
            'emi': emi.round(),
            'total_payment': (emi * months).round(),
            'total_interest': (emi * months - principal).round(),
          }
        };
      default:
        return {'success': false, 'error': 'Unknown investment type'};
    }
  }

  /// Execute cashflow analysis
  Future<Map<String, dynamic>> _executeCashflowAnalysis(
    Session session,
    Map<String, dynamic> params,
    int userId,
  ) async {
    final period = params['period'] as String? ?? 'month';
    
    // Get transactions for the period
    DateTime startDate;
    switch (period) {
      case 'week':
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case 'quarter':
        startDate = DateTime.now().subtract(const Duration(days: 90));
        break;
      case 'year':
        startDate = DateTime.now().subtract(const Duration(days: 365));
        break;
      default:
        startDate = DateTime.now().subtract(const Duration(days: 30));
    }
    
    final transactions = await Transaction.db.find(
      session,
      where: (t) => t.userProfileId.equals(userId) & t.date.notEquals(startDate),
    );
    
    // Filter by date in Dart since Serverpod might not support > for DateTime
    final filteredTransactions = transactions.where((t) => t.date.isAfter(startDate)).toList();
    
    double totalIncome = 0;
    double totalExpense = 0;
    final expenseByCategory = <String, double>{};
    
    for (final t in filteredTransactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        final cat = t.category;
        expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + t.amount;
      }
    }

    
    final savingsRate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100).round() : 0;
    
    return {
      'success': true,
      'data': {
        'period': period,
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'net_cashflow': totalIncome - totalExpense,
        'savings_rate': savingsRate,
        'expense_breakdown': expenseByCategory.entries.map((e) => {'name': e.key, 'value': e.value}).toList(),
      }
    };
  }

  /// Get pending AI actions for a user
  Future<List<AgentAction>> getPendingActions(Session session, int userId) async {
    return await AgentAction.db.find(
      session,
      where: (a) => a.userProfileId.equals(userId) & a.status.equals('pending'),
      orderBy: (a) => a.createdAt,
      orderDescending: true,
    );
  }
}
