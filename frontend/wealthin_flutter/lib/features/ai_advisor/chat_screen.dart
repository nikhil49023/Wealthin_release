import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart' show authService, themeModeNotifier;
import '../../core/theme/wealthin_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/ai_agent_service.dart';

/// Professional AI Chat Screen - Clean Formal Design
/// Deep black dark mode with sharp accent colors
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text: """**Welcome to your AI Financial Advisor**

I can help you with:
• **Product Search** - Find the best deals online
• **Calculations** - SIP returns, EMI, compound interest
• **Budgeting** - Create and manage budgets
• **Travel** - Hotels and flight search
• **News** - Latest financial updates

Try the quick actions below or ask me anything.""",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final userId = authService.currentUserId;

      // Build conversation history
      final history = _messages
          .take(_messages.length - 1) // Exclude the message we just added
          .map(
            (m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            },
          )
          .toList();

      // Get context from data service
      final contextStr = await dataService.getAiContext(userId);
      final Map<String, dynamic> context = {
        'financial_context': contextStr,
      };

      // Use AIAgentService (handles platform-specific routing)
      final agentResponse = await aiAgentService.chat(
        text,
        conversationHistory: history,
        userContext: context,
        userId: userId,
      );


      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: agentResponse.response,
              isUser: false,
              timestamp: DateTime.now(),
              actionType: agentResponse.actionType,
              actionData: agentResponse.actionData,
              needsConfirmation: agentResponse.needsConfirmation,
              isError: agentResponse.error != null,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: "I'm having trouble connecting to my brain. Details: $e",
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
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

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _handleConfirm(
    String? actionType,
    Map<String, dynamic>? actionData,
  ) async {
    if (actionType == null || actionData == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = authService.currentUserId;
      bool success = false;

      // Execute action based on type
      switch (actionType) {
        case 'create_budget':
          final result = await dataService.createBudget(
            userId: userId,
            name: actionData['name'] ?? 'Budget',
            amount: _parseAmount(actionData['amount']),
            category: actionData['category'] ?? 'Other',
          );
          success = result != null;
          break;
        case 'create_savings_goal':
          final result = await dataService.createGoal(
            userId: userId,
            name: actionData['name'] ?? 'Goal',
            targetAmount: _parseAmount(actionData['target_amount']),
          );
          success = result != null;
          break;
        case 'schedule_payment':
          // Calculate next due date from due_day
          final now = DateTime.now();
          final dueDay = actionData['due_day'] as int? ?? 1;
          // Handle valid days (e.g. 31st in Feb)
          var nextMonth = now.month;
          var nextYear = now.year;
          if (now.day > dueDay) {
            nextMonth++;
            if (nextMonth > 12) {
              nextMonth = 1;
              nextYear++;
            }
          }
          // Simple safeguard for days like 31st
          final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          final safeDay = dueDay > lastDayOfNextMonth ? lastDayOfNextMonth : dueDay;
          
          final nextDate = DateTime(nextYear, nextMonth, safeDay);
          final dueDateStr = DateFormat('yyyy-MM-dd').format(nextDate);

          final result = await dataService.createScheduledPayment(
            userId: userId,
            name: actionData['name'] ?? 'Payment',
            amount: _parseAmount(actionData['amount']),
            category: actionData['category'] ?? 'Bills',
            dueDate: dueDateStr,
            frequency: actionData['frequency'] ?? 'monthly',
          );
          success = result != null;
          break;
        case 'add_transaction':
           final result = await dataService.createTransaction(
              userId: userId,
              description: actionData['description'] ?? 'Transaction',
              amount: _parseAmount(actionData['amount']),
              type: actionData['type'] ?? 'expense',
              category: actionData['category'] ?? 'General',
              date: actionData['date'],
           );
           success = result != null;
           break;
        default:
          success = true;
      }

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: success
                  ? '✅ Done! I\'ve completed that for you.'
                  : '❌ Sorry, there was an issue completing that action.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: '❌ Error: $e',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _handleCancel() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'No problem. Let me know if you need anything else.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? WealthInColors.black
          : WealthInColors.background,
      appBar: _buildAppBar(theme, isDark),
      body: Column(
        children: [
          Expanded(child: _buildChatArea(theme, isDark)),
          _buildInputArea(theme, isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? WealthInColors.black : WealthInColors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: WealthInTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Advisor',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: DataService().userCredits,
                builder: (context, credits, child) {
                  return Text(
                    'Credits: $credits',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: credits < 10 
                        ? WealthInColors.error 
                        : WealthInColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Theme toggle
        IconButton(
          onPressed: () {
            themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
          },
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
        IconButton(
          onPressed: () => _showClearDialog(),
          icon: const Icon(Icons.refresh_outlined),
        ),
        const SizedBox(width: 8),
      ],
    );

  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear the conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(ThemeData theme, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator(isDark);
        }
        return _buildMessageBubble(_messages[index], theme, isDark);
      },
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? WealthInColors.blackCard
              : WealthInColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildDot(int index) {
    return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: WealthInColors.primary.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        )
        .animate(
          onPlay: (c) => c.repeat(),
        )
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.2, 1.2),
          delay: Duration(milliseconds: index * 150),
          duration: const Duration(milliseconds: 400),
        );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeData theme,
    bool isDark,
  ) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Message bubble with enhanced styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser 
                    ? LinearGradient(
                        colors: [
                          WealthInColors.primary,
                          WealthInColors.primary.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser 
                    ? null 
                    : (isDark
                        ? WealthInColors.blackCard
                        : WealthInColors.surfaceLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: message.isError
                    ? Border.all(color: WealthInColors.error.withValues(alpha: 0.5))
                    : (!isUser ? Border.all(
                        color: isDark 
                            ? WealthInColors.blackBorder 
                            : WealthInColors.border.withValues(alpha: 0.5),
                        width: 0.5,
                      ) : null),
                boxShadow: isUser ? [
                  BoxShadow(
                    color: WealthInColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: _buildRichText(message.text, isUser, theme, isDark),
            ),
            // Product Cards for Shopping Results
            if (!isUser && _isShoppingAction(message.actionType) && message.actionData != null)
              _buildProductCards(message.actionData!, theme, isDark),
            // Action type indicator
            if (!isUser && message.actionType != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: WealthInColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getActionIcon(message.actionType!),
                        size: 12,
                        color: WealthInColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getActionLabel(message.actionType!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: WealthInColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Confirmation buttons
            if (!isUser &&
                message.needsConfirmation &&
                message.actionType != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? WealthInColors.textSecondaryDark
                            : WealthInColors.textSecondary,
                        side: BorderSide(
                          color: isDark
                              ? WealthInColors.blackBorder
                              : WealthInColors.border,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _handleConfirm(
                        message.actionType,
                        message.actionData,
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Confirm'),
                      style: FilledButton.styleFrom(
                        backgroundColor: WealthInColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? WealthInColors.textSecondaryDark
                      : WealthInColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }

  /// Build rich text with clean formatting (no visible markdown characters)
  Widget _buildRichText(String text, bool isUser, ThemeData theme, bool isDark) {
    final baseColor = isUser
        ? Colors.white
        : (isDark ? WealthInColors.textPrimaryDark : WealthInColors.textPrimary);
    
    // Clean the text first - remove emojis from section headers, sanitize
    String cleanText = _sanitizeAIResponse(text);
    
    // Split text into lines and process
    final lines = cleanText.split('\n');
    final List<Widget> widgets = [];
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // Check for section headers (lines with only bold text)
      if (_isSectionHeader(line)) {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: i > 0 ? 12 : 0, bottom: 4),
          child: Text(
            _extractHeaderText(line),
            style: theme.textTheme.titleSmall?.copyWith(
              color: baseColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
        continue;
      }
      
      // Check for bullet points
      if (line.startsWith('• ') || line.startsWith('- ') || line.startsWith('→ ')) {
        final bulletText = line.substring(2).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•', style: TextStyle(color: baseColor)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormattedText(bulletText, baseColor, theme),
              ),
            ],
          ),
        ));
        continue;
      }
      
      // Check for numbered lists
      final numberedMatch = RegExp(r'^(\d+)[\.\)]\s*').firstMatch(line);
      if (numberedMatch != null) {
        final listText = line.substring(numberedMatch.end).trim();
        final num = numberedMatch.group(1)!;
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text('$num.', style: TextStyle(color: baseColor)),
              ),
              Expanded(
                child: _buildFormattedText(listText, baseColor, theme),
              ),
            ],
          ),
        ));
        continue;
      }
      
      // Regular text
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: _buildFormattedText(line, baseColor, theme),
      ));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  /// Sanitize AI response - remove unnecessary characters and clean formatting
  String _sanitizeAIResponse(String text) {
    // Remove triple asterisks
    text = text.replaceAll('***', '');
    // Clean up multiple newlines
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Remove stray single asterisks at line starts
    text = text.replaceAll(RegExp(r'^\*\s+', multiLine: true), '• ');
    // Clean JSON blocks if present
    text = text.replaceAll(RegExp(r'```json[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // Remove markdown code ticks
    text = text.replaceAll('`', '');
    return text.trim();
  }

  /// Check if line is a section header (surrounded by **)
  bool _isSectionHeader(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('**') && trimmed.endsWith('**') && 
           trimmed.length > 4 && !trimmed.substring(2, trimmed.length - 2).contains('**');
  }

  /// Extract header text from **header**
  String _extractHeaderText(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      return trimmed.substring(2, trimmed.length - 2).trim();
    }
    return trimmed;
  }

  /// Build formatted text with bold/italic support
  Widget _buildFormattedText(String text, Color baseColor, ThemeData theme) {
    final spans = _parseInlineFormattingClean(text, baseColor);
    return Text.rich(
      TextSpan(children: spans),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: baseColor,
        height: 1.5,
      ),
    );
  }

  /// Parse inline formatting and return clean text spans (no visible **)
  List<InlineSpan> _parseInlineFormattingClean(String text, Color baseColor) {
    final List<InlineSpan> spans = [];
    final pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_');
    
    int lastEnd = 0;
    final matches = pattern.allMatches(text).toList();
    
    for (final match in matches) {
      // Add text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: baseColor),
        ));
      }
      
      // Determine if bold or italic
      if (match.group(1) != null) {
        // Bold
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
        ));
      } else if (match.group(2) != null) {
        // Italic
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(color: baseColor.withValues(alpha: 0.85), fontStyle: FontStyle.italic),
        ));
      }
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: baseColor),
      ));
    }
    
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: TextStyle(color: baseColor)));
    }
    
    return spans;
  }


  List<InlineSpan> _parseInlineFormatting(String text, Color baseColor) {
    final List<InlineSpan> spans = [];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    final italicPattern = RegExp(r'_(.+?)_');
    
    int lastEnd = 0;
    final matches = boldPattern.allMatches(text).toList();
    
    for (final match in matches) {
      // Add text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: baseColor),
        ));
      }
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      String remaining = text.substring(lastEnd);
      
      // Check for italics in remaining
      final italicMatches = italicPattern.allMatches(remaining).toList();
      int italicLastEnd = 0;
      
      for (final iMatch in italicMatches) {
        if (iMatch.start > italicLastEnd) {
          spans.add(TextSpan(
            text: remaining.substring(italicLastEnd, iMatch.start),
            style: TextStyle(color: baseColor),
          ));
        }
        spans.add(TextSpan(
          text: iMatch.group(1),
          style: TextStyle(color: baseColor.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
        ));
        italicLastEnd = iMatch.end;
      }
      
      if (italicLastEnd < remaining.length) {
        spans.add(TextSpan(
          text: remaining.substring(italicLastEnd),
          style: TextStyle(color: baseColor),
        ));
      }
    }
    
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: TextStyle(color: baseColor)));
    }
    
    return spans;
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'shopping_search':
      case 'search_amazon':
      case 'search_flipkart':
        return Icons.shopping_cart_outlined;
      case 'search_myntra':
        return Icons.checkroom_outlined;
      case 'search_hotels':
        return Icons.hotel_outlined;
      case 'search_maps':
        return Icons.map_outlined;
      case 'search_news':
        return Icons.newspaper_outlined;
      case 'calculate_sip':
        return Icons.trending_up_outlined;
      case 'calculate_emi':
        return Icons.calculate_outlined;
      case 'create_budget':
        return Icons.account_balance_wallet_outlined;
      case 'create_savings_goal':
        return Icons.flag_outlined;
      case 'add_transaction':
        return Icons.receipt_long_outlined;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'shopping_search':
        return 'Shopping';
      case 'search_amazon':
        return 'Amazon';
      case 'search_flipkart':
        return 'Flipkart';
      case 'search_myntra':
        return 'Fashion';
      case 'search_hotels':
        return 'Hotels';
      case 'search_maps':
        return 'Nearby';
      case 'search_news':
        return 'News';
      case 'calculate_sip':
        return 'SIP Calc';
      case 'calculate_emi':
        return 'EMI Calc';
      case 'create_budget':
        return 'Budget';
      case 'create_savings_goal':
        return 'Goal';
      case 'add_transaction':
        return 'Transaction';
      default:
        return 'AI Action';
    }
  }

  /// Check if action is shopping-related
  bool _isShoppingAction(String? actionType) {
    if (actionType == null) return false;
    // Show product cards for any web search
    return ['shopping_search', 'search_amazon', 'search_flipkart', 'search_myntra', 
            'search_shopping', 'web_search']
        .contains(actionType);
  }

  /// Build product/result cards from action data
  Widget _buildProductCards(Map<String, dynamic> actionData, ThemeData theme, bool isDark) {
    // Try to extract results from various possible structures
    List<dynamic> results = [];
    
    // Check for DuckDuckGo results structure - show ALL results, not just shopping
    if (actionData['results'] != null && actionData['results'] is List) {
      final resultsList = actionData['results'] as List;
      results.addAll(resultsList.whereType<Map<String, dynamic>>());
    }
    
    // Check for combined Amazon+Flipkart structure (from Python backend)
    if (results.isEmpty) {
      if (actionData['amazon'] != null && actionData['amazon'] is List) {
        for (var item in (actionData['amazon'] as List)) {
          if (item is Map<String, dynamic>) {
            item['source'] = 'Amazon';
            results.add(item);
          }
        }
      }
      if (actionData['flipkart'] != null && actionData['flipkart'] is List) {
        for (var item in (actionData['flipkart'] as List)) {
          if (item is Map<String, dynamic>) {
            item['source'] = 'Flipkart';
            results.add(item);
          }
        }
      }
    }
    
    // Check for other product data structures
    if (results.isEmpty) {
      if (actionData['products'] != null && actionData['products'] is List) {
        results = actionData['products'] as List<dynamic>;
      } else if (actionData['data'] != null && actionData['data'] is List) {
        results = actionData['data'] as List<dynamic>;
      } else if (actionData['shopping_results'] != null) {
        results = actionData['shopping_results'] as List<dynamic>;
      } else if (actionData['organic_results'] != null) {
        results = actionData['organic_results'] as List<dynamic>;
      }
    }
    
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Limit to first 5 results
    final displayResults = results.take(5).toList();
    
    // Determine card height based on category
    final category = actionData['category'] as String?;
    final isShopping = category == 'shopping' || category == 'fashion';
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: isShopping ? 200 : 160, // Taller for shopping results
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayResults.length,
        itemBuilder: (context, index) {
          final item = displayResults[index] as Map<String, dynamic>;
          return _buildResultCard(item, theme, isDark, isShopping);
        },
      ),
    );
  }

  /// Build a result card (product or general search result)
  Widget _buildResultCard(Map<String, dynamic> item, ThemeData theme, bool isDark, bool isShopping) {
    final title = item['title']?.toString() ?? item['name']?.toString() ?? 'Result';
    final snippet = item['snippet']?.toString() ?? '';
    final link = item['link']?.toString() ?? item['url']?.toString() ?? '';
    final source = item['source']?.toString() ?? _extractSourceFromLink(link);
    final image = item['thumbnail']?.toString() ?? item['image']?.toString();
    
    // Handle price
    String priceStr = '';
    double? priceNumeric;
    
    if (item['price'] is num) {
      priceNumeric = (item['price'] as num).toDouble();
      priceStr = '₹${_formatPrice(priceNumeric)}';
    } else if (item['price'] is String) {
      priceStr = item['price'] as String;
      priceNumeric = _extractNumericPrice(priceStr);
      if (!priceStr.startsWith('₹')) priceStr = '₹$priceStr';
    } else if (item['price_display'] != null) {
      priceStr = item['price_display'].toString();
      priceNumeric = _extractNumericPrice(priceStr);
    }
    
    // Card width depends on content type
    final cardWidth = isShopping ? 180.0 : 220.0;
    
    return GestureDetector(
      onTap: link.isNotEmpty ? () => _launchUrl(link) : null,
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? WealthInColors.blackCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? WealthInColors.blackBorder : WealthInColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon/image
              Container(
                height: isShopping ? 60 : 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getSourceColor(source).withValues(alpha: 0.1),
                      _getSourceColor(source).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Image or icon
                    if (image != null && image.isNotEmpty)
                      Positioned.fill(
                        child: Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              _getSourceIcon(source),
                              size: 24,
                              color: _getSourceColor(source),
                            ),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          _getSourceIcon(source),
                          size: 24,
                          color: _getSourceColor(source),
                        ),
                      ),
                    // Source badge
                    if (source.isNotEmpty)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSourceColor(source),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            source.length > 10 ? source.substring(0, 10) : source,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title.length > 50 ? '${title.substring(0, 47)}...' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? WealthInColors.textPrimaryDark : WealthInColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Snippet (if not shopping)
                      if (!isShopping && snippet.isNotEmpty)
                        Expanded(
                          child: Text(
                            snippet.length > 60 ? '${snippet.substring(0, 57)}...' : snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? WealthInColors.textSecondaryDark : WealthInColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Price + Link Row
                      Row(
                        children: [
                          // Price badge (if available)
                          if (priceStr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: WealthInColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: WealthInColors.success.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                priceStr.length > 12 ? '${priceStr.substring(0, 12)}' : priceStr,
                                style: TextStyle(
                                  color: WealthInColors.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const Spacer(),
                          // Link icon
                          if (link.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: WealthInColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: WealthInColors.primary,
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
        ),
      ),
    );
  }
  
  /// Build old product card (fallback)
  Widget _buildProductCard(Map<String, dynamic> product, ThemeData theme, bool isDark) {
    return _buildResultCard(product, theme, isDark, true);
  }
  
  /// Extract source name from URL
  String _extractSourceFromLink(String link) {
    final lower = link.toLowerCase();
    if (lower.contains('amazon')) return 'Amazon';
    if (lower.contains('flipkart')) return 'Flipkart';
    if (lower.contains('myntra')) return 'Myntra';
    if (lower.contains('ajio')) return 'AJIO';
    if (lower.contains('meesho')) return 'Meesho';
    if (lower.contains('makemytrip')) return 'MMT';
    if (lower.contains('booking.com')) return 'Booking';
    if (lower.contains('tripadvisor')) return 'TripAdvisor';
    if (lower.contains('moneycontrol')) return 'Moneycontrol';
    if (lower.contains('economictimes')) return 'ET';
    if (lower.contains('wikipedia')) return 'Wikipedia';
    return 'Web';
  }
  
  /// Get color for source
  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'amazon':
        return const Color(0xFFFF9900);
      case 'flipkart':
        return const Color(0xFF2874F0);
      case 'myntra':
        return const Color(0xFFFF3F6C);
      case 'ajio':
        return const Color(0xFF333333);
      case 'meesho':
        return const Color(0xFFE91E63);
      case 'mmt':
        return const Color(0xFFE13A0E);
      case 'booking':
        return const Color(0xFF003580);
      default:
        return WealthInColors.primary;
    }
  }
  
  /// Get icon for source
  IconData _getSourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'amazon':
      case 'flipkart':
      case 'myntra':
      case 'ajio':
      case 'meesho':
        return Icons.shopping_bag_outlined;
      case 'mmt':
      case 'booking':
      case 'tripadvisor':
        return Icons.hotel_outlined;
      case 'moneycontrol':
      case 'et':
        return Icons.show_chart;
      case 'wikipedia':
        return Icons.menu_book_outlined;
      default:
        return Icons.link;
    }
  }
  
  /// Format price with commas
  String _formatPrice(double price) {
    if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(1)}L';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}K';
    }
    return price.toStringAsFixed(0);
  }

  
  /// Extract numeric price from string like "₹12,999" or "Rs. 12999"
  double _extractNumericPrice(String priceStr) {
    final cleaned = priceStr.replaceAll(RegExp(r'[₹Rs.,\s]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
  
  /// Add product to savings goal
  void _addProductToSavingsGoal(String productName, double price) async {
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not determine product price'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Savings Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create a savings goal for:'),
            const SizedBox(height: 8),
            Text(
              productName.length > 50 ? '${productName.substring(0, 50)}...' : productName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Target: ₹${price.toStringAsFixed(0)}',
              style: TextStyle(
                color: WealthInColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Goal'),
            style: FilledButton.styleFrom(
              backgroundColor: WealthInColors.success,
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        final userId = authService.currentUserId;
        final goalName = productName.length > 30 
            ? '${productName.substring(0, 30)}...' 
            : productName;
        
        final result = await dataService.createGoal(
          userId: userId,
          name: goalName,
          targetAmount: price,
        );
        
        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                text: result != null
                    ? '🎯 **Savings Goal Created!**\n\n• **Goal:** $goalName\n• **Target:** ₹${price.toStringAsFixed(0)}\n\n_Track your progress in the Goals section!_'
                    : '❌ Failed to create savings goal. Please try again.',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            _isLoading = false;
          });
          _scrollToBottom();
          
          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Savings goal created: ₹${price.toStringAsFixed(0)}'),
                  ],
                ),
                backgroundColor: WealthInColors.success,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                text: '❌ Error creating goal: $e',
                isUser: false,
                timestamp: DateTime.now(),
                isError: true,
              ),
            );
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    }
  }
  /// Launch URL helper
  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${time.minute.toString().padLeft(2, '0')} $amPm';
  }

  Widget _buildInputArea(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? WealthInColors.black : WealthInColors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? WealthInColors.blackBorder : WealthInColors.border,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick action chips - always visible
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _buildQuickActionChip(
                  'Phones under 20000',
                  Icons.smartphone_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'SIP Calculator',
                  Icons.trending_up_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'EMI Calculator',
                  Icons.calculate_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'Hotels in Goa',
                  Icons.hotel_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'Financial News',
                  Icons.newspaper_outlined,
                  isDark,
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Task switcher
              IconButton(
                onPressed: () => _showTaskSwitcher(isDark),
                icon: Icon(
                  Icons.widgets_outlined,
                  color: isDark
                      ? WealthInColors.textSecondaryDark
                      : WealthInColors.textSecondary,
                ),
              ),
              // Text input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? WealthInColors.blackCard
                        : WealthInColors.surfaceLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? WealthInColors.textSecondaryDark
                            : WealthInColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              Container(
                decoration: BoxDecoration(
                  gradient: WealthInTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: Icon(
                    Icons.send_rounded,
                    color: _isLoading ? Colors.white54 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _showTaskSwitcher(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? WealthInColors.blackCard : WealthInColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tasks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: WealthInColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chat_outlined, color: WealthInColors.primary),
              ),
              title: const Text('AI Chat'),
              subtitle: const Text('Current conversation'),
              trailing: const Icon(Icons.check_circle, color: WealthInColors.success),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: WealthInTheme.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.history_outlined, color: WealthInTheme.purple),
              ),
              title: const Text('Chat History'),
              subtitle: const Text('Previous conversations'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat history coming soon!')),
                );
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon, [bool? isDark]) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    
    // Map chip labels to actual queries
    final queryMap = {
      'Phones under 20000': 'Best phones under 20000',
      'SIP Calculator': 'Calculate SIP 5000 for 10 years at 12%',
      'EMI Calculator': 'EMI for 10 lakh loan at 9% for 20 years',
      'Hotels in Goa': 'Hotels in Goa',
      'Financial News': 'Latest financial news India',
    };
    
    return ActionChip(
      avatar: Icon(icon, size: 16, color: dark ? WealthInColors.primary : WealthInColors.primary),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: dark ? WealthInColors.textPrimaryDark : WealthInColors.textPrimary,
        ),
      ),
      backgroundColor: dark ? WealthInColors.blackCard : WealthInColors.surfaceLight,
      side: BorderSide(
        color: dark ? WealthInColors.blackBorder : WealthInColors.border,
        width: 0.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _messageController.text = queryMap[label] ?? label;
        _sendMessage();
      },
    );
  }
}

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? actionType;
  final Map<String, dynamic>? actionData;
  final bool needsConfirmation;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionType,
    this.actionData,
    this.needsConfirmation = false,
    this.isError = false,
  });
}
