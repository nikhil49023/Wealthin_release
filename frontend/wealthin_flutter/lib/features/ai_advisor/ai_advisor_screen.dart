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
import '../../main.dart' show authService;
import '../../core/services/data_service.dart';

/// AI Advisor Screen - Agentic Chat with Tool Calling
/// Features: Glassmorphism UI, Activity Indicators, Confirmation Flows,
/// Shopping Product Cards, Web Search Progress
class AiAdvisorScreen extends StatelessWidget {
  const AiAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AiAdvisorScreenBody(),
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

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.messageType,
    this.actionId,
    this.actionType,
    this.actionData,
    this.products,
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

  Future<void> _handleSearchRequest(String query, String lowerText) async {
    try {
      // Show search progress
      _updateActivity(AIActivityState.searching, 'Starting web search...', steps: [
        '🔍 Analyzing your request...',
      ]);
      await Future.delayed(const Duration(milliseconds: 500));

      // Determine search type
      String toolName = 'web_search';
      String searchQuery = query;
      
      if (lowerText.contains('amazon')) {
        toolName = 'search_amazon';
        _updateActivity(AIActivityState.searching, 'Searching Amazon India...', steps: [
          '🔍 Analyzing your request...',
          '🛒 Connecting to Amazon India...',
        ]);
      } else if (lowerText.contains('flipkart')) {
        toolName = 'search_flipkart';
        _updateActivity(AIActivityState.searching, 'Searching Flipkart...', steps: [
          '🔍 Analyzing your request...',
          '🛍️ Connecting to Flipkart...',
        ]);
      } else if (lowerText.contains('shop') || lowerText.contains('buy') || lowerText.contains('price')) {
        toolName = 'search_shopping';
        _updateActivity(AIActivityState.searching, 'Searching products...', steps: [
          '🔍 Analyzing your request...',
          '🛒 Searching multiple platforms...',
        ]);
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _updateActivity(AIActivityState.searching, 'Fetching results...', steps: [
        ..._searchSteps,
        '📦 Loading product data...',
      ]);

      // Execute search tool
      final result = await pythonBridge.executeTool(toolName, {'query': searchQuery});

      await Future.delayed(const Duration(milliseconds: 300));
      _updateActivity(AIActivityState.responding, 'Preparing results...', steps: [
        ..._searchSteps,
        '📦 Loading product data...',
        '✨ Formatting results...',
      ]);

      if (result['success'] == true && result['data'] != null) {
        final products = List<Map<String, dynamic>>.from(result['data']);
        
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
        _addAIMessage("I couldn't complete the search right now. Please try again later! 😅");
      }
    } catch (e) {
      _addAIMessage("Oops! Something went wrong with the search. Let me try that differently. 🔄");
    }
    _scrollToBottom();
  }

  Future<void> _handleBudgetRequest(String text) async {
    _updateActivity(AIActivityState.executing, 'Understanding your budget request...');
    
    try {
      // Extract budget details using AI
      final context = await _buildUserContext();
      final response = await aiAgentService.chat(
        "Extract budget details from this request and return JSON only: $text\n"
        "Format: {\"category\": \"...\", \"amount\": number, \"period\": \"monthly/weekly/yearly\"}",
        userId: authService.currentUserId,
        userContext: context,
      );

      // Try to parse budget from response or use defaults
      Map<String, dynamic>? budgetData;
      try {
        final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response.response);
        if (jsonMatch != null) {
          budgetData = json.decode(jsonMatch.group(0)!);
        }
      } catch (_) {}

      budgetData ??= _extractBudgetFromText(text);

      if (budgetData != null && budgetData['amount'] != null) {
        // Create confirmation action
        final result = await pythonBridge.executeTool('create_budget', {
          'category': budgetData['category'] ?? 'General',
          'amount': (budgetData['amount'] as num).toDouble(),
          'period': budgetData['period'] ?? 'monthly',
        });

        final resultStr = result.toString();
        final parsed = json.decode(resultStr);
        
        if (parsed['requires_confirmation'] == true) {
          setState(() {
            _messages.add(_ChatMessage(
              text: parsed['confirmation_message'] ?? 'Create this budget?',
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.confirmation,
              actionId: parsed['action_id'],
              actionType: parsed['action_type'],
              actionData: parsed['action_data'],
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

        final resultStr = result.toString();
        final parsed = json.decode(resultStr);
        
        if (parsed['requires_confirmation'] == true) {
          setState(() {
            _messages.add(_ChatMessage(
              text: parsed['confirmation_message'] ?? 'Create this goal?',
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.confirmation,
              actionId: parsed['action_id'],
              actionType: parsed['action_type'],
              actionData: parsed['action_data'],
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
      _addAIMessage("I'd love to help you set a savings goal! What would you like to save for? 🎯");
    }
  }

  Future<void> _handleCalculationRequest(String text) async {
    _updateActivity(AIActivityState.calculating, 'Crunching the numbers...');
    
    try {
      final context = await _buildUserContext();
      final response = await aiAgentService.chat(text, userId: authService.currentUserId, userContext: context);
      _addAIMessage(response.response);
    } catch (e) {
      _addAIMessage("Let me help you with that calculation! 🧮 Could you provide the specific numbers?");
    }
  }

  Future<void> _handleGeneralChat(String text) async {
    _updateActivity(AIActivityState.thinking, 'Thinking...');
    
    try {
      final context = await _buildUserContext();
      _updateActivity(AIActivityState.responding, 'Preparing response...');
      
      final response = await aiAgentService.chat(text, userId: authService.currentUserId, userContext: context);
      _addAIMessage(response.response);
    } catch (e) {
      _addAIMessage("I'm having a bit of trouble right now. Could you try asking that differently? 🤔");
    }
  }

  void _addAIMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
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
    
    if (text.toLowerCase().contains('lakh')) amount *= 100000;
    else if (text.toLowerCase().contains('k')) amount *= 1000;

    String name = 'Savings Goal';
    final forMatch = RegExp(r'(?:save\s+(?:for|towards?)?|goal\s+(?:for)?)\s+(.+?)(?:\s+(?:of|by|worth)|\d|$)', caseSensitive: false).firstMatch(text);
    if (forMatch != null) {
      name = forMatch.group(1)?.trim() ?? name;
    }

    return {'name': name, 'target_amount': amount};
  }

  Future<void> _confirmAction(String actionId, String actionType, Map<String, dynamic> actionData) async {
    setState(() => _isLoading = true);

    try {
      if (actionType == 'create_budget') {
        await dataService.createBudget(
          userId: authService.currentUserId,
          name: actionData['category'],
          amount: (actionData['amount'] as num).toDouble(),
          category: actionData['category'],
          period: actionData['period'] ?? 'monthly',
        );
        _addSuccessMessage("✅ Budget created successfully!\n\n📊 **${actionData['category']}**: ₹${actionData['amount']}/month\n\nYou can view it in the Budgets section.");
      } else if (actionType == 'create_savings_goal') {
        await dataService.createGoal(
          userId: authService.currentUserId,
          name: actionData['name'],
          targetAmount: (actionData['target_amount'] as num).toDouble(),
          deadline: actionData['deadline'],
        );
        _addSuccessMessage("✅ Savings goal created!\n\n🎯 **${actionData['name']}**: ₹${actionData['target_amount']}\n\nTrack your progress in the Goals section.");
      } else if (actionType == 'add_transaction') {
        await dataService.createTransaction(
          userId: authService.currentUserId,
          amount: (actionData['amount'] as num).toDouble(),
          description: actionData['description'],
          category: actionData['category'],
          type: actionData['type'],
        );
        _addSuccessMessage("✅ Transaction added!\n\n💰 **${actionData['description']}**: ₹${actionData['amount']}");
      }
    } catch (e) {
      _addAIMessage("❌ Couldn't complete that action. Please try again or do it manually in the app.");
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
      // Try to parse if it's JSON, otherwise wrap in a map
      try {
        return json.decode(contextString) as Map<String, dynamic>;
      } catch (_) {
        return {'context': contextString};
      }
    } catch (e) {
      return {'note': 'User context unavailable'};
    }
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF8FFFE), const Color(0xFFF0FDF4)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoading) _buildActivityIndicator(),
            Expanded(child: _buildChatArea()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageWidget(_messages[index]),
    );
  }

  Widget _buildMessageWidget(_ChatMessage msg) {
    if (msg.isUser) return _buildUserBubble(msg);
    
    switch (msg.messageType) {
      case MessageType.products: return _buildProductsCard(msg);
      case MessageType.confirmation: return _buildConfirmationCard(msg);
      case MessageType.success: return _buildSuccessBubble(msg);
      default: return _buildAIBubble(msg);
    }
  }

  Widget _buildUserBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.growthGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Text(msg.text, style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildAIBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Text(msg.text.replaceAll('**', '').replaceAll('*', ''), style: GoogleFonts.inter(fontSize: 15, color: AppTheme.forestGreen, height: 1.5)),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildSuccessBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.emerald.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
        ),
        child: Text(msg.text.replaceAll('**', '').replaceAll('*', ''), style: GoogleFonts.inter(fontSize: 15, color: AppTheme.forestGreen, height: 1.5)),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildConfirmationCard(_ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.text.replaceAll('**', '').replaceAll('*', ''), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.forestGreen)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAction(msg.actionId!, msg.actionType!, msg.actionData!),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Yes, do it!'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _cancelAction(msg.actionId!),
                child: const Text('Cancel'),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

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
      margin: const EdgeInsets.only(bottom: 12, right: 30),
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
                        Text(price.toString(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(source, style: GoogleFonts.inter(fontSize: 10, color: Colors.blue[700])),
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

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleVoiceInput,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _isListening ? Colors.red.withValues(alpha: 0.1) : AppTheme.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : AppTheme.emerald, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(hintText: 'Ask anything...', hintStyle: GoogleFonts.inter(color: Colors.grey[500]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                style: GoogleFonts.inter(fontSize: 15),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: AppTheme.growthGradient, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Icon(_isLoading ? Icons.hourglass_empty : Icons.arrow_upward, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
