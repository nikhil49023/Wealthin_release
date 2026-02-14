import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/ai_agent_service.dart';
import '../../core/services/python_bridge_service.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart' show authService;
import '../../core/services/data_service.dart';

/// AI Advisor Screen - Agentic Chat with Tool Calling
/// Features: Glassmorphism UI, Activity Indicators, Confirmation Flows,
/// Shopping Product Cards, Web Search Progress
class AiAdvisorScreen extends StatelessWidget {
  const AiAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: const AiAdvisorScreenBody(),
    );
  }
}

class AiAdvisorScreenBody extends StatefulWidget {
  const AiAdvisorScreenBody({super.key});

  @override
  State<AiAdvisorScreenBody> createState() => _AiAdvisorScreenBodyState();
}

enum AIActivityState { idle, thinking, searching, calculating, executing, responding }
enum MessageType { text, products, confirmation, success, error }

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType messageType;
  final String? actionId;
  final String? actionType;
  final Map<String, dynamic>? actionData;
  final List<Map<String, dynamic>>? products;
  final List<Map<String, dynamic>>? sources;  // Web search sources with URLs

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.messageType,
    this.actionId,
    this.actionType,
    this.actionData,
    this.products,
    this.sources,
  });
}

class _AiAdvisorScreenBodyState extends State<AiAdvisorScreenBody>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  AIActivityState _currentActivity = AIActivityState.idle;
  String _activityMessage = '';
  List<String> _searchSteps = [];

  late AnimationController _pulseController;

  // Speech
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _initSpeech();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatMessage(
      text: "Hey there! 👋 I'm your AI financial buddy.\n\n"
          "Here's what I can do for you:\n"
          "• 💰 **Set budgets** - Just ask!\n"
          "• 🎯 **Create savings goals**\n"
          "• 🧮 **Calculate SIP/EMI/FIRE**\n"
          "• 🔍 **Search for products** with prices\n"
          "• 📊 **Analyze your spending**\n\n"
          "Try saying: *\"Set a budget of 5000 for food\"*",
      isUser: false,
      timestamp: DateTime.now(),
      messageType: MessageType.text,
    ));
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateActivity(AIActivityState state, String message, {List<String>? steps}) {
    if (mounted) {
      setState(() {
        _currentActivity = state;
        _activityMessage = message;
        if (steps != null) _searchSteps = steps;
      });
      // Auto-scroll during activity updates (thinking, searching, responding)
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
      ));
      _isLoading = true;
      _searchSteps = [];
    });

    _messageController.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // Detect intent and show appropriate activity
    final lowerText = text.toLowerCase();
    
    if (_containsSearchIntent(lowerText)) {
      await _handleSearchRequest(text, lowerText);
    } else if (_containsBudgetIntent(lowerText)) {
      await _handleBudgetRequest(text);
    } else if (_containsGoalIntent(lowerText)) {
      await _handleGoalRequest(text);
    } else if (_containsPaymentIntent(lowerText)) {
      await _handlePaymentRequest(text);
    } else if (_containsCalculationIntent(lowerText)) {
      await _handleCalculationRequest(text);
    } else {
      await _handleGeneralChat(text);
    }
  }

  bool _containsSearchIntent(String text) {
    return text.contains('search') || text.contains('find') || 
           text.contains('best') || text.contains('buy') ||
           text.contains('shop') || text.contains('amazon') ||
           text.contains('flipkart') || text.contains('price');
  }

  bool _containsBudgetIntent(String text) {
    return text.contains('budget') || text.contains('limit') ||
           (text.contains('set') && text.contains('spend'));
  }

  bool _containsGoalIntent(String text) {
    return text.contains('goal') || text.contains('save for') ||
           text.contains('saving') || text.contains('target');
  }

  bool _containsCalculationIntent(String text) {
    return text.contains('sip') || text.contains('emi') ||
           text.contains('calculate') || text.contains('interest') ||
           text.contains('fire') || text.contains('invest');
  }

  bool _containsPaymentIntent(String text) {
    return text.contains('schedule') || text.contains('remind') ||
           text.contains('bill') || text.contains('emi') ||
           text.contains('rent') || text.contains('payment') ||
           text.contains('recurring') || text.contains('subscription');
  }

  Future<void> _handleSearchRequest(String query, String lowerText) async {
    try {
      // Show search progress
      _updateActivity(AIActivityState.searching, 'Starting web search...', steps: [
        '🔍 Analyzing your request...',
      ]);
      await Future.delayed(const Duration(milliseconds: 500));

      _updateActivity(AIActivityState.searching, 'Searching with DuckDuckGo...', steps: [
        '🔍 Analyzing your request...',
        '🌐 Connecting to DuckDuckGo...',
      ]);

      await Future.delayed(const Duration(milliseconds: 500));
      _updateActivity(AIActivityState.searching, 'Fetching results...', steps: [
        '🔍 Analyzing your request...',
        '🌐 Connecting to DuckDuckGo...',
        '📊 Processing search results...',
      ]);

      // Call agentic chat which will route to web search
      final context = await _buildUserContext();
      final history = _buildConversationHistory();
      final response = await aiAgentService.chat(
        query,
        userId: authService.currentUserId,
        userContext: context,
        conversationHistory: history,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      _updateActivity(AIActivityState.responding, 'Preparing results...', steps: [
        '🔍 Analyzing your request...',
        '🌐 Connecting to DuckDuckGo...',
        '📊 Processing search results...',
        '✨ Formatting results...',
      ]);

      // Extract sources if available
      List<Map<String, dynamic>>? sources;
      if (response.sources != null && response.sources!.isNotEmpty) {
        if (response.sources!.first is Map) {
          sources = List<Map<String, dynamic>>.from(response.sources!);
        }
      }

      // Check if response contains product-like data
      if (sources != null && sources.any((s) => s['price'] != null)) {
        // Display as products
        final products = sources;

        if (products.isNotEmpty) {
          setState(() {
            _messages.add(_ChatMessage(
              text: "🛍️ Found ${products.length} products for you!\n\nHere are the best options:",
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.products,
              products: products,
            ));
            _isLoading = false;
            _currentActivity = AIActivityState.idle;
            _searchSteps = [];
          });
        } else {
          _addAIMessage("🔍 I searched but couldn't find specific products. Try being more specific about what you're looking for!");
        }
      } else {
        // Display as general search results with sources
        _addAIMessage(response.response, sources: sources);
      }
    } catch (e) {
      _addAIMessage("Oops! Something went wrong with the search. Let me try that differently. 🔄");
    }
    _scrollToBottom();
  }

  Future<void> _handleBudgetRequest(String text) async {
    _updateActivity(AIActivityState.executing, 'Understanding your budget request...');
    
    try {
      // Extract budget details directly from user text
      final budgetData = _extractBudgetFromText(text);

      if (budgetData != null && budgetData['amount'] != null) {
        // Call Python bridge to prepare the action
        final result = await pythonBridge.executeTool('create_budget', {
          'category': budgetData['category'] ?? 'General',
          'amount': (budgetData['amount'] as num).toDouble(),
          'period': budgetData['period'] ?? 'monthly',
        });

        // pythonBridge.executeTool returns Map<String, dynamic> directly
        if (result['requires_confirmation'] == true) {
          final actionData = result['action_data'] as Map<String, dynamic>?;
          setState(() {
            _messages.add(_ChatMessage(
              text: result['confirmation_message']?.toString() ?? 'Create this budget?',
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.confirmation,
              actionId: result['action_id']?.toString(),
              actionType: result['action_type']?.toString(),
              actionData: actionData,
            ));
            _isLoading = false;
            _currentActivity = AIActivityState.idle;
          });
          _scrollToBottom();
          return;
        }
      }

      _addAIMessage("I'd love to help you set a budget! 💰\n\nJust tell me:\n• **Category** (Food, Transport, Shopping, etc.)\n• **Amount** in rupees\n• **Period** (weekly, monthly, yearly)\n\nExample: *\"Set a monthly budget of ₹5000 for food\"*");
    } catch (e) {
      debugPrint('Budget request error: $e');
      _addAIMessage("Let me help you create a budget! Tell me the category and amount. 📊");
    }
  }


  Future<void> _handleGoalRequest(String text) async {
    _updateActivity(AIActivityState.executing, 'Setting up your savings goal...');
    
    try {
      final goalData = _extractGoalFromText(text);

      if (goalData != null && goalData['target_amount'] != null) {
        final result = await pythonBridge.executeTool('create_savings_goal', {
          'name': goalData['name'] ?? 'Savings Goal',
          'target_amount': (goalData['target_amount'] as num).toDouble(),
          'deadline': goalData['deadline'],
        });

        // pythonBridge.executeTool returns Map<String, dynamic> directly
        if (result['requires_confirmation'] == true) {
          final actionData = result['action_data'] as Map<String, dynamic>?;
          setState(() {
            _messages.add(_ChatMessage(
              text: result['confirmation_message']?.toString() ?? 'Create this goal?',
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.confirmation,
              actionId: result['action_id']?.toString(),
              actionType: result['action_type']?.toString(),
              actionData: actionData,
            ));
            _isLoading = false;
            _currentActivity = AIActivityState.idle;
          });
          _scrollToBottom();
          return;
        }
      }

      _addAIMessage("🎯 Let's create a savings goal!\n\nTell me:\n• What are you saving for?\n• How much do you need?\n• When do you want to reach it?\n\nExample: *\"Save 50000 for a vacation by December\"*");
    } catch (e) {
      debugPrint('Goal request error: $e');
      _addAIMessage("I'd love to help you set a savings goal! What would you like to save for? 🎯");
    }
  }


  Future<void> _handleCalculationRequest(String text) async {
    _updateActivity(AIActivityState.calculating, 'Crunching the numbers...');
    
    try {
      final context = await _buildUserContext();
      final history = _buildConversationHistory();
      final response = await aiAgentService.chat(
        text,
        userId: authService.currentUserId,
        userContext: context,
        conversationHistory: history,
      );
      _addAIMessage(response.response);
    } catch (e) {
      _addAIMessage("Let me help you with that calculation! 🧮 Could you provide the specific numbers?");
    }
  }

  Future<void> _handlePaymentRequest(String text) async {
    _updateActivity(AIActivityState.executing, 'Setting up your payment reminder...');

    try {
      final paymentData = _extractPaymentFromText(text);

      if (paymentData != null && paymentData['amount'] != null) {
        // Calculate due date using the helper function
        final dueDate = _calculateDueDate(paymentData);

        final result = await pythonBridge.executeTool('create_scheduled_payment', {
          'name': paymentData['name'] ?? 'Payment',
          'amount': (paymentData['amount'] as num).toDouble(),
          'category': paymentData['category'] ?? 'Bills',
          'due_date': dueDate,
          'frequency': paymentData['frequency'] ?? 'monthly',
          'is_autopay': false,
        });

        // pythonBridge.executeTool returns Map<String, dynamic> directly
        if (result['requires_confirmation'] == true) {
          final actionData = result['action_data'] as Map<String, dynamic>?;
          setState(() {
            _messages.add(_ChatMessage(
              text: result['confirmation_message']?.toString() ?? 'Schedule this payment?',
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.confirmation,
              actionId: result['action_id']?.toString(),
              actionType: result['action_type']?.toString(),
              actionData: actionData,
            ));
            _isLoading = false;
            _currentActivity = AIActivityState.idle;
          });
          _scrollToBottom();
          return;
        }
      }

      _addAIMessage("📅 Let's schedule a payment reminder!\n\nTell me:\n• **Name** (Netflix, Rent, EMI, etc.)\n• **Amount** in rupees\n• **Frequency** (monthly, weekly, yearly)\n\nExample: *\"Remind me to pay 499 for Netflix every month\"*");
    } catch (e) {
      debugPrint('Payment request error: $e');
      _addAIMessage("I'd love to help you schedule a payment! Tell me the name and amount. 📅");
    }
  }

  Map<String, dynamic>? _extractPaymentFromText(String text) {
    // Extract amount
    final amountMatch = RegExp(r'(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:₹|rs|rupees?)?', caseSensitive: false).firstMatch(text);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;

    // Extract name - expanded payment names
    String name = 'Payment';
    final paymentNames = [
      'netflix', 'amazon', 'spotify', 'hotstar', 'disney', 'youtube', 'prime',
      'swiggy one', 'swiggy', 'zomato pro', 'zomato', 'gym', 'membership',
      'rent', 'electricity', 'water', 'gas', 'internet', 'phone', 'mobile',
      'insurance', 'emi', 'loan', 'credit card', 'broadband'
    ];

    // Try "for <name>" pattern first
    final forMatch = RegExp(r'(?:for|to)\s+([a-zA-Z\s]+?)(?:\s+(?:monthly|weekly|yearly|quarterly|every|on|\d|$))', caseSensitive: false).firstMatch(text);
    if (forMatch != null) {
      final extractedName = forMatch.group(1)?.trim();
      if (extractedName != null && extractedName.isNotEmpty) {
        name = extractedName.split(' ').map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
      }
    } else {
      // Fall back to keyword matching
      for (final paymentName in paymentNames) {
        if (text.toLowerCase().contains(paymentName)) {
          name = paymentName.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
          break;
        }
      }
    }

    // Extract frequency with aliases
    String frequency = 'monthly';
    final lowerText = text.toLowerCase();
    if (lowerText.contains('week') || lowerText.contains('biweek') || lowerText.contains('fortnightly')) {
      frequency = lowerText.contains('biweek') || lowerText.contains('fortnightly') ? 'biweekly' : 'weekly';
    } else if (lowerText.contains('year') || lowerText.contains('annual')) {
      frequency = 'yearly';
    } else if (lowerText.contains('quarter')) {
      frequency = 'quarterly';
    }

    // Extract due date or day
    String? dueDate;
    int? dueDay;

    // Pattern: "on 5th", "15th of month", etc.
    final dayMatch = RegExp(r'(?:on\s+)?(\d{1,2})(?:st|nd|rd|th)?(?:\s+(?:of|every))?', caseSensitive: false).firstMatch(text);
    if (dayMatch != null) {
      dueDay = int.tryParse(dayMatch.group(1)!);
    }

    // Pattern: dd/mm/yyyy or dd-mm-yyyy
    final dateMatch = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})').firstMatch(text);
    if (dateMatch != null) {
      final day = dateMatch.group(1)!.padLeft(2, '0');
      final month = dateMatch.group(2)!.padLeft(2, '0');
      final year = dateMatch.group(3);
      dueDate = '$year-$month-$day';
    }

    // Extract category based on name - improved mapping
    String category = 'Bills';
    final nameLower = name.toLowerCase();
    if (nameLower.contains('netflix') || nameLower.contains('spotify') || nameLower.contains('hotstar') ||
        nameLower.contains('disney') || nameLower.contains('youtube') || nameLower.contains('prime') ||
        nameLower.contains('amazon') || nameLower.contains('swiggy') || nameLower.contains('zomato')) {
      category = 'Subscriptions';
    } else if (nameLower.contains('rent')) {
      category = 'Rent';
    } else if (nameLower.contains('electricity') || nameLower.contains('water') || nameLower.contains('gas') ||
               nameLower.contains('internet') || nameLower.contains('phone') || nameLower.contains('mobile') ||
               nameLower.contains('broadband')) {
      category = 'Utilities';
    } else if (nameLower.contains('insurance')) {
      category = 'Insurance';
    } else if (nameLower.contains('emi') || nameLower.contains('loan') || nameLower.contains('credit card')) {
      category = 'Loan';
    } else if (nameLower.contains('gym') || nameLower.contains('membership')) {
      category = 'Health & Fitness';
    }

    final result = {
      'name': name,
      'amount': amount,
      'category': category,
      'frequency': frequency,
    };

    if (dueDate != null) {
      result['due_date'] = dueDate;
    } else if (dueDay != null) {
      result['due_day'] = dueDay;
    }

    return result;
  }

  String _calculateDueDate(Map<String, dynamic> paymentData) {
    // If due_date already provided, use it
    if (paymentData.containsKey('due_date')) {
      return paymentData['due_date'] as String;
    }

    final now = DateTime.now();

    // If due_day provided, calculate next occurrence
    if (paymentData.containsKey('due_day')) {
      final dueDay = paymentData['due_day'] as int;

      // Validate day is in valid range
      if (dueDay < 1 || dueDay > 31) {
        // Invalid day, default to 7 days from now
        return now.add(const Duration(days: 7)).toIso8601String().split('T')[0];
      }

      // Calculate next occurrence of this day
      DateTime dueDate;
      if (now.day < dueDay) {
        // This month, if the day hasn't passed yet
        dueDate = DateTime(now.year, now.month, dueDay);
      } else {
        // Next month, if the day has passed
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        dueDate = DateTime(nextYear, nextMonth, dueDay);
      }

      return dueDate.toIso8601String().split('T')[0];
    }

    // Default: 7 days from now
    return now.add(const Duration(days: 7)).toIso8601String().split('T')[0];
  }

  Future<void> _handleGeneralChat(String text) async {
    _updateActivity(AIActivityState.thinking, 'Thinking...');

    try {
      final context = await _buildUserContext();
      final history = _buildConversationHistory();
      _updateActivity(AIActivityState.responding, 'Preparing response...');

      final response = await aiAgentService.chat(
        text,
        userId: authService.currentUserId,
        userContext: context,
        conversationHistory: history,
      );

      // Extract sources if available
      List<Map<String, dynamic>>? sources;
      if (response.sources != null && response.sources!.isNotEmpty) {
        // Check if sources contain URLs (from web search)
        if (response.sources!.first is Map) {
          sources = List<Map<String, dynamic>>.from(response.sources!);
        }
      }

      _addAIMessage(response.response, sources: sources);
    } catch (e) {
      String errorMsg;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
        errorMsg = "The AI is taking too long to respond. This can happen with complex queries — please try a simpler question. ⏱️";
      } else if (errorStr.contains('api key') || errorStr.contains('no api key')) {
        errorMsg = "AI API key not configured. Please check Settings → API Keys. 🔑";
      } else if (errorStr.contains('connection') || errorStr.contains('socket')) {
        errorMsg = "Couldn't connect to the AI engine. Please restart the app and try again. 🔄";
      } else {
        errorMsg = "I'm having a bit of trouble right now. Could you try asking that differently? 🤔";
      }
      debugPrint('[AIAdvisor] Chat error: $e');
      _addAIMessage(errorMsg);
    }
  }

  void _addAIMessage(String text, {List<Map<String, dynamic>>? sources}) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
        sources: sources,
      ));
      _isLoading = false;
      _currentActivity = AIActivityState.idle;
      _searchSteps = [];
    });
    _scrollToBottom();
  }

  Map<String, dynamic>? _extractBudgetFromText(String text) {
    final amountMatch = RegExp(r'(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:₹|rs|rupees?)?', caseSensitive: false).firstMatch(text);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;

    String category = 'General';
    final categories = ['food', 'transport', 'shopping', 'entertainment', 'utilities', 'health', 'education'];
    for (final cat in categories) {
      if (text.toLowerCase().contains(cat)) {
        category = cat[0].toUpperCase() + cat.substring(1);
        break;
      }
    }

    String period = 'monthly';
    if (text.toLowerCase().contains('week')) period = 'weekly';
    if (text.toLowerCase().contains('year')) period = 'yearly';

    return {'category': category, 'amount': amount, 'period': period};
  }

  Map<String, dynamic>? _extractGoalFromText(String text) {
    final amountMatch = RegExp(r'(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:₹|rs|rupees?|k|lakh)?', caseSensitive: false).firstMatch(text);
    if (amountMatch == null) return null;

    var amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;
    
    if (text.toLowerCase().contains('lakh')) {
      amount *= 100000;
    } else if (text.toLowerCase().contains('k')) amount *= 1000;

    String name = 'Savings Goal';
    final forMatch = RegExp(r'(?:save\s+(?:for|towards?)?|goal\s+(?:for)?)\s+(.+?)(?:\s+(?:of|by|worth)|\d|$)', caseSensitive: false).firstMatch(text);
    if (forMatch != null) {
      name = forMatch.group(1)?.trim() ?? name;
    }

    return {'name': name, 'target_amount': amount};
  }

  Future<void> _confirmAction(String actionId, String actionType, Map<String, dynamic> actionData) async {
    debugPrint('[AIAdvisor] Confirming action: $actionType with data: $actionData');
    setState(() => _isLoading = true);

    try {
      if (actionType == 'create_budget') {
        final category = actionData['category']?.toString() ?? 'General';
        final amount = (actionData['amount'] as num?)?.toDouble() ?? 0.0;
        final period = actionData['period']?.toString() ?? 'monthly';
        
        debugPrint('[AIAdvisor] Creating budget: category=$category, amount=$amount, period=$period');
        final result = await dataService.createBudget(
          userId: authService.currentUserId,
          name: category,
          amount: amount,
          category: category,
          period: period,
        );
        debugPrint('[AIAdvisor] Budget created: $result');
        _addSuccessMessage("✅ Budget created successfully!\n\n📊 **$category**: ₹${amount.toStringAsFixed(0)}/$period\n\nYou can view it in the Budgets section.");
      } else if (actionType == 'create_savings_goal') {
        final name = actionData['name']?.toString() ?? 'Savings Goal';
        final targetAmount = (actionData['target_amount'] as num?)?.toDouble() ?? 0.0;
        final deadline = actionData['deadline']?.toString();
        
        debugPrint('[AIAdvisor] Creating goal: name=$name, targetAmount=$targetAmount, deadline=$deadline');
        final result = await dataService.createGoal(
          userId: authService.currentUserId,
          name: name,
          targetAmount: targetAmount,
          deadline: deadline,
        );
        debugPrint('[AIAdvisor] Goal created: $result');
        _addSuccessMessage("✅ Savings goal created!\n\n🎯 **$name**: ₹${targetAmount.toStringAsFixed(0)}\n\nTrack your progress in the Goals section.");
      } else if (actionType == 'add_transaction') {
        final amount = (actionData['amount'] as num?)?.toDouble() ?? 0.0;
        final description = actionData['description']?.toString() ?? 'Transaction';
        final category = actionData['category']?.toString() ?? 'Other';
        final txType = actionData['type']?.toString() ?? 'expense';
        
        debugPrint('[AIAdvisor] Creating transaction: description=$description, amount=$amount, category=$category, type=$txType');
        await dataService.createTransaction(
          userId: authService.currentUserId,
          amount: amount,
          description: description,
          category: category,
          type: txType,
        );
        debugPrint('[AIAdvisor] Transaction created');
        _addSuccessMessage("✅ Transaction added!\n\n💰 **$description**: ₹${amount.toStringAsFixed(0)}");
      } else if (actionType == 'create_scheduled_payment') {
        final name = actionData['name']?.toString() ?? 'Payment';
        final amount = (actionData['amount'] as num?)?.toDouble() ?? 0.0;
        final category = actionData['category']?.toString() ?? 'Bills';
        final dueDate = actionData['due_date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10);
        final frequency = actionData['frequency']?.toString() ?? 'monthly';
        
        debugPrint('[AIAdvisor] Creating scheduled payment: name=$name, amount=$amount, category=$category, dueDate=$dueDate, frequency=$frequency');
        await dataService.createScheduledPayment(
          userId: authService.currentUserId,
          name: name,
          amount: amount,
          category: category,
          dueDate: dueDate,
          frequency: frequency,
        );
        debugPrint('[AIAdvisor] Scheduled payment created');
        _addSuccessMessage("✅ Payment scheduled!\n\n📅 **$name**: ₹${amount.toStringAsFixed(0)} ($frequency)\n\nView in the Payments section.");
      } else {
        debugPrint('[AIAdvisor] Unknown action type: $actionType');
        _addAIMessage("⚠️ Unknown action type: $actionType. Please try again.");
      }
    } catch (e, stackTrace) {
      debugPrint('[AIAdvisor] Error confirming action: $e');
      debugPrint('[AIAdvisor] Stack trace: $stackTrace');
      _addAIMessage("❌ Couldn't complete that action. Error: $e\n\nPlease try again or do it manually in the app.");
    }
  }



  void _cancelAction(String actionId) {
    _addAIMessage("No problem! Let me know if you'd like to do something else. 😊");
  }

  void _addSuccessMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        messageType: MessageType.success,
      ));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<Map<String, dynamic>> _buildUserContext() async {
    try {
      final contextString = await dataService.getAiContext(authService.currentUserId);
      Map<String, dynamic> context;
      // Try to parse if it's JSON, otherwise wrap in a map
      try {
        context = json.decode(contextString) as Map<String, dynamic>;
      } catch (_) {
        context = {'financial_context': contextString};
      }
      
      // Enrich with temporal metadata for time-aware advice
      final now = DateTime.now();
      context['current_date'] = now.toIso8601String().split('T')[0];
      context['current_time'] = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      context['day_of_week'] = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1];
      context['day_of_month'] = now.day;
      context['days_remaining_in_month'] = DateTime(now.year, now.month + 1, 0).day - now.day;
      
      return context;
    } catch (e) {
      return {'note': 'User context unavailable'};
    }
  }

  /// Build conversation history from recent messages for the LLM context window.
  /// Caps at last 20 messages to keep token usage reasonable.
  List<Map<String, String>> _buildConversationHistory() {
    // Exclude system/welcome messages and the latest user message (which is the current query)
    final relevantMessages = _messages
        .where((m) => m.messageType == MessageType.text || m.messageType == MessageType.products)
        .toList();
    
    // Skip the last message (which is the current user query being processed)
    final historyMessages = relevantMessages.length > 1 
        ? relevantMessages.sublist(0, relevantMessages.length - 1) 
        : <_ChatMessage>[];
    
    // Take the most recent 20 messages
    final windowedHistory = historyMessages.length > 20 
        ? historyMessages.sublist(historyMessages.length - 20) 
        : historyMessages;
    
    return windowedHistory.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleVoiceInput() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input not available'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          setState(() => _messageController.text = result.recognizedWords);
          if (result.finalResult) setState(() => _isListening = false);
        },
        listenFor: const Duration(seconds: 30),
        localeId: 'en_IN',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Luxury backgrounds
    final backgroundColor = isDark 
      ? AppTheme.oceanDeep // Deep navy (not pure black)
      : AppTheme.cream; // Soft mint (not plain white)
    
    return Container(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLargeScreen = constraints.maxWidth > 600;
            final contentWidth = isLargeScreen ? 640.0 : constraints.maxWidth;
            
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  children: [
                    // Minimal header
                    _buildMinimalHeader(isDark),
                    // Activity indicator inline (subtle)
                    if (_isLoading) _buildCompactActivityIndicator(isDark),
                    // Main chat area with keyboard-aware padding
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _focusNode.unfocus(),
                        child: _buildChatArea(isDark, keyboardHeight),
                      ),
                    ),
                    // Input area
                    _buildCompactInputArea(isDark),
                    // Keyboard spacer
                    SizedBox(height: keyboardHeight > 0 ? 0 : MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Minimal header like ChatGPT - just status, no big title
  Widget _buildMinimalHeader(bool isDark) {
    final textColor = isDark ? const Color(0xFFE0E7ED) : AppTheme.slate900;
    final subtitleColor = isDark ? AppTheme.oceanMist : AppTheme.slate500;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Minimal AI indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _currentActivity == AIActivityState.idle 
                ? AppTheme.sageGreen 
                : AppTheme.warning,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_currentActivity == AIActivityState.idle 
                    ? AppTheme.sageGreen 
                    : AppTheme.warning).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status text
          Expanded(
            child: Text(
              _currentActivity == AIActivityState.idle 
                ? 'AI Advisor' 
                : _activityMessage,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _currentActivity == AIActivityState.idle 
                  ? textColor 
                  : subtitleColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Clear button
          IconButton(
            onPressed: () => setState(() { 
              _messages.clear(); 
              _addWelcomeMessage(); 
            }),
            icon: Icon(
              Icons.add_comment_outlined,
              size: 20,
              color: subtitleColor,
            ),
            tooltip: 'New chat',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  /// Compact activity indicator that doesn't take much space
  Widget _buildCompactActivityIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark 
          ? AppTheme.oceanMid.withValues(alpha: 0.8) 
          : AppTheme.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
            ? AppTheme.sereneTeal.withValues(alpha: 0.3) 
            : AppTheme.sageGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppTheme.sereneTeal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getActivityTitle(),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? AppTheme.oceanMist : AppTheme.slate700,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 150.ms);
  }

  Widget _buildHeader(bool isLargeScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 0 : 16, 
        vertical: 8
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.growthGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.3 + _pulseController.value * 0.2),
                      blurRadius: 12 + _pulseController.value * 4,
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Text('🤖', style: TextStyle(fontSize: 22)),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Advisor', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.forestGreen)),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _currentActivity == AIActivityState.idle ? AppTheme.success : Colors.amber, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_currentActivity == AIActivityState.idle ? 'Ready to help' : _activityMessage, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          IconButton(onPressed: () => setState(() { _messages.clear(); _addWelcomeMessage(); }), icon: const Icon(Icons.refresh_rounded), color: Colors.grey[600]),
        ],
      ),
    );
  }

  Widget _buildActivityIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildActivityIcon(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getActivityTitle(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
                          Text(_activityMessage, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_searchSteps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...List.generate(_searchSteps.length, (i) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(i == _searchSteps.length - 1 ? Icons.hourglass_top : Icons.check_circle, size: 16, color: i == _searchSteps.length - 1 ? Colors.amber : AppTheme.emerald),
                        const SizedBox(width: 8),
                        Text(_searchSteps[i], style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildActivityIcon() {
    IconData icon = Icons.psychology;
    Color color = AppTheme.emerald;
    
    switch (_currentActivity) {
      case AIActivityState.searching: icon = Icons.travel_explore; color = Colors.blue; break;
      case AIActivityState.calculating: icon = Icons.calculate; color = Colors.purple; break;
      case AIActivityState.executing: icon = Icons.bolt; color = Colors.orange; break;
      default: break;
    }
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22));
  }

  String _getActivityTitle() {
    switch (_currentActivity) {
      case AIActivityState.thinking: return '🤔 Thinking...';
      case AIActivityState.searching: return '🔍 Web Search';
      case AIActivityState.calculating: return '🧮 Calculating';
      case AIActivityState.executing: return '⚡ Taking Action';
      case AIActivityState.responding: return '💬 Responding';
      default: return '';
    }
  }

  Widget _buildChatArea(bool isDark, double keyboardHeight) {
    // Add 1 to message count when loading to show typing indicator
    final itemCount = _messages.length + (_isLoading ? 1 : 0);
    
    return ListView.builder(
      controller: _scrollController,
      // Add bottom padding when keyboard is open to keep messages visible
      padding: EdgeInsets.fromLTRB(16, 4, 16, keyboardHeight > 0 ? 8 : 4),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Show typing indicator as the last item when loading
        if (_isLoading && index == _messages.length) {
          return _buildTypingIndicator(isDark);
        }
        return _buildMessageWidget(_messages[index], isDark);
      },
    );
  }

  Widget _buildMessageWidget(_ChatMessage msg, bool isDark) {
    if (msg.isUser) return _buildUserBubble(msg, isDark);
    
    switch (msg.messageType) {
      case MessageType.products: return _buildProductsCard(msg);
      case MessageType.confirmation: return _buildConfirmationCard(msg, isDark);
      case MessageType.success: return _buildSuccessBubble(msg, isDark);
      default: return _buildAIBubble(msg, isDark);
    }
  }

  Widget _buildUserBubble(_ChatMessage msg, bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.sereneTeal, AppTheme.sereneTealLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.sereneTeal.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  softWrap: true,
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  /// Animated typing indicator shown while AI is processing
  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 80),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppTheme.sereneTeal.withValues(alpha: 0.3)
                      : AppTheme.sageGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDot(0),
                  const SizedBox(width: 4),
                  _buildDot(1),
                  const SizedBox(width: 4),
                  _buildDot(2),
                  const SizedBox(width: 10),
                  Text(
                    'AI is thinking...',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppTheme.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppTheme.sereneTeal.withValues(alpha: 0.3));
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppTheme.sereneTeal,
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (c) => c.repeat())
      .scale(delay: Duration(milliseconds: index * 150), duration: 400.ms, begin: const Offset(0.6, 0.6), end: const Offset(1.0, 1.0))
      .then().scale(duration: 400.ms, begin: const Offset(1.0, 1.0), end: const Offset(0.6, 0.6));
  }

  Widget _buildAIBubble(_ChatMessage msg, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.sereneTeal.withValues(alpha: 0.2)
                            : AppTheme.sageGreen.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black : AppTheme.slate500).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text.replaceAll('**', '').replaceAll('*', ''),
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: isDark ? const Color(0xFFE8EEF4) : AppTheme.slate900,
                        height: 1.5,
                      ),
                      softWrap: true,
                    ),
                  ),
                ),
              ),
            ),
            // Sources section with clickable URLs
            if (msg.sources != null && msg.sources!.isNotEmpty)
              _buildSourcesSection(msg.sources!, isDark),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOut);
  }

  /// Build clickable sources section for web search results
  Widget _buildSourcesSection(List<Map<String, dynamic>> sources, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '🔗 Sources',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ...sources.asMap().entries.map((entry) {
            final idx = entry.key;
            final source = entry.value;
            final title = source['title'] ?? 'Source ${idx + 1}';
            final url = source['url'] ?? '';
            final snippet = source['snippet'] ?? '';
            final sourceLabel = source['source'] ?? 'Web';
            final price = source['price'];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: url.isNotEmpty ? () => _launchUrl(url) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.sereneTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sourceLabel,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.sereneTeal,
                                ),
                              ),
                            ),
                            if (price != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                price,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (snippet.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            snippet,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ).animate(delay: (idx * 100).ms).fadeIn().slideX(begin: -0.05);
          }),
        ],
      ),
    );
  }

  Widget _buildSuccessBubble(_ChatMessage msg, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6, right: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.sageGreen.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.sageGreen.withValues(alpha: 0.3)),
          ),
          child: Text(
            msg.text.replaceAll('**', '').replaceAll('*', ''),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? AppTheme.sageLight : AppTheme.sereneTealDark,
              height: 1.5,
            ),
            softWrap: true,
          ),
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.98, 0.98));
  }

  Widget _buildConfirmationCard(_ChatMessage msg, bool isDark) {
    final bgColor = isDark ? AppTheme.oceanMid : AppTheme.white;
    final textColor = isDark ? const Color(0xFFE0E7ED) : AppTheme.slate900;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.sereneTeal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.text.replaceAll('**', '').replaceAll('*', ''),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                softWrap: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmAction(msg.actionId!, msg.actionType!, msg.actionData!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.sereneTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelAction(msg.actionId!),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.mutedRose,
                        side: BorderSide(color: AppTheme.mutedRose.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // Products card (shared implementation)

  Widget _buildProductsCard(_ChatMessage msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
            child: Text(msg.text, style: GoogleFonts.inter(fontSize: 15, color: AppTheme.forestGreen)),
          ),
        ),
        ...List.generate(
          (msg.products?.length ?? 0).clamp(0, 5),
          (i) => _buildProductCard(msg.products![i]),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final title = product['title'] ?? product['name'] ?? 'Product';
    final price = product['price'] ?? product['extracted_price'] ?? '';
    final link = product['link'] ?? product['url'] ?? '';
    final source = product['source'] ?? _extractPlatform(link);
    final thumbnail = product['thumbnail'] ?? product['image'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: link.isNotEmpty ? () => _launchUrl(link) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (thumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(thumbnail, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.shopping_bag))),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.forestGreen)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            price.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emerald,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              source,
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.blue[700]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (link.isNotEmpty) Icon(Icons.open_in_new, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _extractPlatform(String url) {
    if (url.contains('amazon')) return 'Amazon';
    if (url.contains('flipkart')) return 'Flipkart';
    if (url.contains('myntra')) return 'Myntra';
    if (url.contains('ajio')) return 'Ajio';
    return 'Shop';
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch URL: $e');
    }
  }

  /// Compact input area like ChatGPT/Messenger
  Widget _buildCompactInputArea(bool isDark) {
    final inputBgColor = isDark 
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark 
      ? AppTheme.sereneTeal.withValues(alpha: 0.3) 
      : AppTheme.sageGreen.withValues(alpha: 0.3);
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Voice input button (glassmorphic)
                GestureDetector(
                  onTap: _toggleVoiceInput,
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _isListening 
                        ? AppTheme.mutedRose.withValues(alpha: 0.2) 
                        : inputBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isListening 
                          ? AppTheme.mutedRose.withValues(alpha: 0.5) 
                          : borderColor,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: _isListening ? AppTheme.mutedRose : AppTheme.sereneTeal,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Text input (glassmorphic pill)
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    decoration: BoxDecoration(
                      color: inputBgColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _focusNode.hasPrimaryFocus 
                          ? AppTheme.sereneTeal.withValues(alpha: 0.6)
                          : borderColor,
                        width: _focusNode.hasPrimaryFocus ? 1.5 : 1,
                      ),
                      boxShadow: _focusNode.hasPrimaryFocus ? [
                        BoxShadow(
                          color: AppTheme.sereneTeal.withValues(alpha: 0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ] : null,
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask me anything...',
                        hintStyle: GoogleFonts.dmSans(
                          color: isDark ? Colors.white54 : AppTheme.slate500,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        isDense: true,
                      ),
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: isDark ? const Color(0xFFE8EEF4) : AppTheme.slate900,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send button (gradient when active)
                GestureDetector(
                  onTap: _isLoading || _messageController.text.trim().isEmpty 
                    ? null 
                    : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: _messageController.text.trim().isNotEmpty && !_isLoading
                        ? LinearGradient(
                            colors: [AppTheme.sereneTeal, AppTheme.sereneTealLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                      color: _messageController.text.trim().isEmpty || _isLoading
                        ? inputBgColor
                        : null,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: _messageController.text.trim().isNotEmpty && !_isLoading ? [
                        BoxShadow(
                          color: AppTheme.sereneTeal.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              isDark ? AppTheme.sereneTealLight : AppTheme.sereneTeal,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          color: _messageController.text.trim().isEmpty
                            ? (isDark ? Colors.white54 : AppTheme.slate500)
                            : Colors.white,
                          size: 22,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Legacy input area (kept for compatibility)
  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCompactInputArea(isDark);
  }
}
