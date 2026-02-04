import 'package:serverpod/serverpod.dart' hide Transaction;
import '../services/ai_router_service.dart';
import '../services/ai_tools_service.dart';
import '../generated/protocol.dart';

/// AI Advisor Endpoint with smart routing between RAG and LLM
/// Now with tool/action capabilities for budgets, goals, transactions
class AiAdvisorEndpoint extends Endpoint {
  final AIRouterService _router = AIRouterService();
  final AIToolsService _tools = AIToolsService();

  /// Patterns that indicate an action request (should trigger tools)
  static final _actionPatterns = [
    RegExp(r'\b(create|add|set|make|start)\s+(a\s+)?(budget|goal|savings|reminder|payment|transaction)', caseSensitive: false),
    RegExp(r'\b(budget|save|track|record|schedule)\b.*\b(for|of)\s+\d+', caseSensitive: false),
    RegExp(r'\b(spent|earned|paid|received)\s+.*₹?\d+', caseSensitive: false),
    RegExp(r'\b(remind|schedule|setup)\s+(me\s+)?(about|for|to)', caseSensitive: false),
    RegExp(r'₹\s*\d+.*\b(budget|goal|payment)', caseSensitive: false),
  ];

  /// Check if query is requesting an action
  bool _isActionQuery(String query) {
    return _actionPatterns.any((pattern) => pattern.hasMatch(query));
  }
  
  /// Smart query processor - routes to RAG/LLM or tools based on intent
  Future<String> askAdvisor(Session session, String query) async {
    try {
      final userId = await _getUserId(session);
      
      // Check if this is an action request
      if (_isActionQuery(query)) {
        session.log('Action query detected, routing to AI Tools');
        return await _processWithTools(session, query, userId);
      }
      
      // Get user's recent transactions for context
      final recentTransactions = await _getRecentTransactions(session, userId);
      
      // Use smart router to determine RAG vs LLM
      final result = await _router.processQuery(
        query,
        recentTransactions: recentTransactions,
      );
      
      session.log(
        'AI Router Decision: ${result.decision.reason} (RAG: ${result.decision.useRag}, Confidence: ${result.decision.confidence})',
      );
      
      return result.response;
    } catch (e) {
      session.log('AI Advisor Error: $e', level: LogLevel.error);
      return "I'm having trouble processing your request right now. Please try again.";
    }
  }

  /// Process query with tools - explicitly uses function calling
  Future<String> askWithTools(Session session, String query) async {
    try {
      final userId = await _getUserId(session);
      return await _processWithTools(session, query, userId);
    } catch (e) {
      session.log('AI Tools Error: $e', level: LogLevel.error);
      return "I understood your request but couldn't complete the action. Please try again.";
    }
  }

  /// Internal method to process with tools
  Future<String> _processWithTools(Session session, String query, int userId) async {
    final result = await _tools.processWithTools(session, query, userId);
    
    if (result.actionTaken) {
      session.log('AI Action Executed: ${result.actionType}');
      
      // Log the action to database
      try {
        final action = AgentAction(
          userProfileId: userId,
          actionType: result.actionType ?? 'unknown',
          parameters: result.actionData?.toString() ?? '{}',
          status: 'completed',
          resultMessage: result.response,
          createdAt: DateTime.now(),
        );
        await AgentAction.db.insertRow(session, action);
      } catch (e) {
        session.log('Failed to log action: $e');
      }
    }
    
    return result.response;
  }

  /// Get user's recent transactions for context
  Future<List<Map<String, dynamic>>?> _getRecentTransactions(Session session, int userId) async {
    try {
      final transactions = await Transaction.db.find(
        session,
        where: (t) => t.userProfileId.equals(userId),
        orderBy: (t) => t.date,
        orderDescending: true,
        limit: 10,
      );
      return transactions.map((t) => {
        'amount': t.amount,
        'description': t.description,
        'type': t.type,
        'category': t.category,
        'date': t.date.toIso8601String(),
      }).toList();
    } catch (e) {
      session.log('Could not fetch transactions for context: $e');
      return null;
    }
  }

  /// Get user ID from session (with fallback for now)
  Future<int> _getUserId(Session session) async {
    // TODO: Implement proper auth - get from session
    // final authInfo = await session.authenticated;
    // if (authInfo != null) return authInfo.userId;
    return 1; // Fallback for development
  }

  /// Get routing decision without executing (for debugging/UI)
  Future<Map<String, dynamic>> getRouteDecision(Session session, String query) async {
    final decision = _router.routeQuery(query);
    return {
      ...decision.toJson(),
      'isActionQuery': _isActionQuery(query),
    };
  }

  /// Get available AI tools/actions
  Future<List<Map<String, dynamic>>> getAvailableTools(Session session) async {
    return [
      {'name': 'create_budget', 'description': 'Create a budget for a spending category'},
      {'name': 'create_savings_goal', 'description': 'Set a savings target'},
      {'name': 'schedule_payment', 'description': 'Schedule a recurring payment reminder'},
      {'name': 'add_transaction', 'description': 'Record an income or expense'},
      {'name': 'get_spending_summary', 'description': 'Get spending analysis'},
    ];
  }

  /// Ask advisor with structured response for action confirmation flow
  /// Returns full response with action data for UI to show confirmation cards
  Future<Map<String, dynamic>> askAdvisorStructured(Session session, String query) async {
    try {
      final userId = await _getUserId(session);
      
      // Check if this is an action request
      if (_isActionQuery(query)) {
        session.log('Action query detected, routing to AI Tools with structured response');
        final result = await _tools.processWithTools(session, query, userId);
        
        // Return structured response with action details
        return {
          'type': result.actionTaken ? 'action' : 'text',
          'response': result.response,
          'actionTaken': result.actionTaken,
          'actionType': result.actionType,
          'actionData': result.actionData,
          'requiresConfirmation': result.actionTaken,
          'error': result.error,
        };
      }
      
      // Get user's recent transactions for context
      final recentTransactions = await _getRecentTransactions(session, userId);
      
      // Use smart router for non-action queries
      final result = await _router.processQuery(
        query,
        recentTransactions: recentTransactions,
      );
      
      return {
        'type': 'text',
        'response': result.response,
        'actionTaken': false,
        'routingDecision': {
          'useRag': result.decision.useRag,
          'reason': result.decision.reason,
          'confidence': result.decision.confidence,
        },
      };
    } catch (e) {
      session.log('AI Advisor Structured Error: $e', level: LogLevel.error);
      return {
        'type': 'error',
        'response': "I'm having trouble processing your request right now. Please try again.",
        'error': e.toString(),
      };
    }
  }

  /// Preview an action without executing it - for confirmation flow
  Future<Map<String, dynamic>> previewAction(Session session, String query) async {
    try {
      // Parse the query to extract action details without executing
      final actionDetails = _extractActionDetails(query);
      
      return {
        'success': true,
        'actionType': actionDetails['type'],
        'parameters': actionDetails['parameters'],
        'description': actionDetails['description'],
        'canExecute': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Execute a confirmed action
  Future<Map<String, dynamic>> confirmAction(
    Session session,
    String actionType,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final userId = await _getUserId(session);
      
      // Execute the action directly
      final result = await _tools.executeConfirmedAction(
        session,
        actionType,
        parameters,
        userId,
      );
      
      return {
        'success': result['success'] ?? false,
        'message': result['message'],
        'data': result,
      };
    } catch (e) {
      session.log('Confirm Action Error: $e', level: LogLevel.error);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Extract action details from query for preview
  Map<String, dynamic> _extractActionDetails(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Budget extraction
    if (lowerQuery.contains('budget')) {
      final amountMatch = RegExp(r'₹?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)').firstMatch(query);
      final amount = amountMatch != null 
          ? double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0
          : 0;
      
      // Try to extract category
      String category = 'General';
      for (final cat in ['food', 'groceries', 'transport', 'entertainment', 'shopping', 'bills', 'health']) {
        if (lowerQuery.contains(cat)) {
          category = cat[0].toUpperCase() + cat.substring(1);
          break;
        }
      }
      
      return {
        'type': 'create_budget',
        'parameters': {'category': category, 'amount': amount, 'period': 'monthly'},
        'description': 'Create a monthly budget of ₹$amount for $category',
      };
    }
    
    // Goal extraction
    if (lowerQuery.contains('goal') || lowerQuery.contains('save')) {
      final amountMatch = RegExp(r'₹?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)').firstMatch(query);
      final amount = amountMatch != null 
          ? double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0
          : 0;
      
      String name = 'Savings Goal';
      for (final goal in ['emergency', 'vacation', 'car', 'house', 'wedding', 'education']) {
        if (lowerQuery.contains(goal)) {
          name = '${goal[0].toUpperCase()}${goal.substring(1)} Fund';
          break;
        }
      }
      
      return {
        'type': 'create_savings_goal',
        'parameters': {'name': name, 'targetAmount': amount},
        'description': 'Create a savings goal of ₹$amount for $name',
      };
    }
    
    // Payment/Reminder extraction
    if (lowerQuery.contains('remind') || lowerQuery.contains('schedule') || lowerQuery.contains('payment')) {
      final amountMatch = RegExp(r'₹?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)').firstMatch(query);
      final amount = amountMatch != null 
          ? double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0
          : 0;
      
      final dayMatch = RegExp(r'(\d{1,2})(?:st|nd|rd|th)?').firstMatch(query);
      final day = dayMatch != null ? int.tryParse(dayMatch.group(1)!) ?? 1 : 1;
      
      String name = 'Payment';
      for (final payment in ['rent', 'emi', 'electricity', 'water', 'internet', 'phone', 'subscription']) {
        if (lowerQuery.contains(payment)) {
          name = payment[0].toUpperCase() + payment.substring(1);
          break;
        }
      }
      
      return {
        'type': 'schedule_payment',
        'parameters': {'name': name, 'amount': amount, 'dueDay': day, 'frequency': 'monthly'},
        'description': 'Schedule a monthly $name payment of ₹$amount on day $day',
      };
    }
    
    // Transaction extraction
    if (lowerQuery.contains('spent') || lowerQuery.contains('paid') || lowerQuery.contains('bought')) {
      final amountMatch = RegExp(r'₹?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)').firstMatch(query);
      final amount = amountMatch != null 
          ? double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0
          : 0;
      
      return {
        'type': 'add_transaction',
        'parameters': {'description': query, 'amount': amount, 'type': 'expense'},
        'description': 'Record an expense of ₹$amount',
      };
    }
    
    return {
      'type': 'unknown',
      'parameters': {},
      'description': 'Unknown action',
    };
  }
}
