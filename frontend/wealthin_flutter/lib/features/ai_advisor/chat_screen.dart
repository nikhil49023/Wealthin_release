import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../main.dart' show authService, themeModeNotifier;
import '../../core/theme/wealthin_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/backend_config.dart';

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
        text: "Hello! I'm your AI Financial Advisor. How can I help you today?",
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

      final response = await http.post(
        Uri.parse('${backendConfig.baseUrl}/agent/agentic-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'query': text,
          'conversation_history': history,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                text:
                    data['response'] ??
                    'I apologize, I could not process that.',
                isUser: false,
                timestamp: DateTime.now(),
                actionType: data['action_type'],
                actionData: data['action_data'],
                needsConfirmation: data['needs_confirmation'] ?? false,
              ),
            );
            _isLoading = false;
          });
          _scrollToBottom();
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg;
        if (e.toString().contains('Connection refused') ||
            e.toString().contains('SocketException')) {
          errorMsg =
              "Unable to connect to the AI service.\n\n"
              "The backend server may not be running. Please ensure "
              "the WealthIn backend is started.\n\n"
              "Tip: Some features work offline, but AI chat requires "
              "the backend service.";
        } else {
          errorMsg = "Something went wrong. Please try again.\n\nDetails: $e";
        }

        setState(() {
          _messages.add(
            ChatMessage(
              text: errorMsg,
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
              Text(
                'Online',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WealthInColors.success,
                ),
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
            color: WealthInColors.primary.withOpacity(0.6),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? WealthInColors.primary
                    : (isDark
                          ? WealthInColors.blackCard
                          : WealthInColors.surfaceLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: message.isError
                    ? Border.all(color: WealthInColors.error.withOpacity(0.5))
                    : null,
              ),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? Colors.white
                      : (isDark
                            ? WealthInColors.textPrimaryDark
                            : WealthInColors.textPrimary),
                  height: 1.4,
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
                    OutlinedButton(
                      onPressed: _handleCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? WealthInColors.textSecondaryDark
                            : WealthInColors.textSecondary,
                        side: BorderSide(
                          color: isDark
                              ? WealthInColors.blackBorder
                              : WealthInColors.border,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _handleConfirm(
                        message.actionType,
                        message.actionData,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: WealthInColors.success,
                      ),
                      child: const Text('Confirm'),
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
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
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
                  'Create Budget',
                  Icons.account_balance_wallet_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'Plan a Vacation',
                  Icons.flight_takeoff_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'Create Invoice',
                  Icons.receipt_long_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'Calculate SIP',
                  Icons.calculate_outlined,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  'Analyze Spending',
                  Icons.analytics_outlined,
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

  void _showQuickActions(bool isDark) {
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
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionChip(
                  'Create a budget',
                  Icons.account_balance_wallet_outlined,
                  isDark,
                ),
                _buildQuickActionChip('Set savings goal', Icons.flag_outlined, isDark),
                _buildQuickActionChip(
                  'Calculate SIP',
                  Icons.calculate_outlined,
                  isDark,
                ),
                _buildQuickActionChip(
                  'Analyze spending',
                  Icons.analytics_outlined,
                  isDark,
                ),
                _buildQuickActionChip(
                  'Investment advice',
                  Icons.trending_up_outlined,
                  isDark,
                ),
                _buildQuickActionChip(
                  'Tax planning',
                  Icons.receipt_long_outlined,
                  isDark,
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
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
                  color: WealthInColors.primary.withOpacity(0.1),
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
                  color: WealthInTheme.purple.withOpacity(0.1),
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
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: dark ? WealthInColors.blackCard : null,
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _messageController.text = label;
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
