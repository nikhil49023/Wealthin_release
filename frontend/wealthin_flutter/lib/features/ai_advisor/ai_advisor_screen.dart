import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../widgets/action_card.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scribble_decorations.dart';
import '../../core/widgets/sovereign_widgets.dart';
import '../../core/services/ai_agent_service.dart';
import '../../main.dart' show authService;
import '../../core/services/data_service.dart';

/// AI Advisor Screen - Sovereign Growth Aesthetic 2026
/// Purple-tinted adaptive chat interface with agentic capabilities
class AiAdvisorScreen extends StatelessWidget {
  const AiAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Advisor')),
      body: const AiAdvisorScreenBody(),
    );
  }
}

/// Body content for embedding in tabs
class AiAdvisorScreenBody extends StatefulWidget {
  const AiAdvisorScreenBody({super.key});

  @override
  State<AiAdvisorScreenBody> createState() => _AiAdvisorScreenBodyState();
}

class _AiAdvisorScreenBodyState extends State<AiAdvisorScreenBody>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  late AnimationController _pulseController;
  late AnimationController _gradientController;

  // Speech recognition
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  double _confidence = 0.0; // Used in speech recognition

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _gradientController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Initialize speech recognition
    _initSpeech();

    // Welcome message with Sovereign branding
    _messages.add(
      _ChatMessage(
        text:
            "Welcome to your **Founder's OS** 🚀\n\n"
            "I'm your AI Financial Advisor with agentic capabilities:\n\n"
            "**Sense** • Scan PDFs & receipts automatically\n"
            "**Plan** • Create budgets & savings goals\n"
            "**Act** • Track expenses & schedule payments\n\n"
            "Try: *\"Create a budget of ₹15,000 for food\"*",
        isUser: false,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
      ),
    );
  }

  /// Initialize speech-to-text
  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              // Auto-send if we have recognized words
              if (_lastWords.isNotEmpty) {
                _messageController.text = _lastWords;
                _lastWords = '';
              }
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voice recognition error: ${error.errorMsg}'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to initialize speech: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
          messageType: MessageType.text,
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Call the AI Agent service
    try {
      final userContext = await _buildUserContext();
      final response = await aiAgentService.chat(
        text,
        userContext: userContext,
      );

      if (mounted) {
        final messageType = _detectMessageType(response.response);

        setState(() {
          _messages.add(
            _ChatMessage(
              text: response.response,
              isUser: false,
              timestamp: DateTime.now(),
              messageType: messageType,
              actionType: response.actionType,
              actionData: response.actionData,
              needsConfirmation: response.needsConfirmation,
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
            _ChatMessage(
              text:
                  "I apologize, but I'm experiencing technical difficulties. Please try again in a moment.\n\nError: $e",
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.error,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Build user context for the AI
  Future<Map<String, dynamic>> _buildUserContext() async {
    try {
      final userId = authService.currentUserId;
      // Fetch real context from backend
      final aiContext = await dataService.getAiContext(userId);
      
      if (aiContext.isNotEmpty) {
        return {
          'financial_summary': aiContext,
        };
      }
    } catch (e) {
      debugPrint('Error building user context: $e');
    }
    
    // Fallback
    return {
      'note': 'User financial data unavailable or empty.',
    };
  }

  Future<void> _handleActionConfirm(
    String actionType,
    Map<String, dynamic>? parameters,
  ) async {
    if (parameters == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to confirm action - missing parameters'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Confirm with backend
      final success = await aiAgentService.confirmAction(
        actionType,
        parameters,
      );

      if (mounted) {
        if (success) {
          // TODO: Save to local database based on action type
          await _saveActionLocally(actionType, parameters);

          setState(() {
            _messages.add(
              _ChatMessage(
                text: '✅ Done! I\'ve ${_getActionDescription(actionType)}.',
                isUser: false,
                timestamp: DateTime.now(),
                messageType: MessageType.actionSuccess,
              ),
            );
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_getActionLabel(actionType)} saved successfully!',
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          setState(() {
            _messages.add(
              _ChatMessage(
                text:
                    '❌ Sorry, I couldn\'t complete that action. Please try again.',
                isUser: false,
                timestamp: DateTime.now(),
                messageType: MessageType.error,
              ),
            );
            _isLoading = false;
          });
        }
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: '❌ Error: $e',
              isUser: false,
              timestamp: DateTime.now(),
              messageType: MessageType.error,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Save action to local database
  Future<void> _saveActionLocally(
    String actionType,
    Map<String, dynamic> data,
  ) async {
    // TODO: Implement local database save based on action type
    // For now, we just acknowledge the action
    switch (actionType) {
      case 'create_budget':
        // Save to budgets table
        debugPrint('Saving budget: ${data['category']} - ₹${data['amount']}');
        break;
      case 'create_savings_goal':
        // Save to goals table
        debugPrint('Saving goal: ${data['name']} - ₹${data['target_amount']}');
        break;
      case 'schedule_payment':
        // Save to scheduled payments
        debugPrint('Saving payment: ${data['name']} - ₹${data['amount']}');
        break;
      case 'add_transaction':
        // Save to transactions
        debugPrint(
          'Saving transaction: ${data['description']} - ₹${data['amount']}',
        );
        break;
    }
  }

  String _getActionDescription(String actionType) {
    switch (actionType) {
      case 'create_budget':
        return 'created your budget';
      case 'create_savings_goal':
        return 'set up your savings goal';
      case 'schedule_payment':
        return 'scheduled your payment reminder';
      case 'add_transaction':
        return 'recorded your transaction';
      default:
        return 'completed the action';
    }
  }

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'create_budget':
        return 'Budget';
      case 'create_savings_goal':
        return 'Savings goal';
      case 'schedule_payment':
        return 'Payment reminder';
      case 'add_transaction':
        return 'Transaction';
      default:
        return 'Action';
    }
  }

  void _handleActionCancel() {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: 'Understood. Let me know if you need anything else.',
          isUser: false,
          timestamp: DateTime.now(),
          messageType: MessageType.text,
        ),
      );
    });
    _scrollToBottom();
  }

  MessageType _detectMessageType(String response) {
    if (response.contains('✅') ||
        response.contains('created') ||
        response.contains('set up') ||
        response.contains('confirmed')) {
      return MessageType.actionSuccess;
    } else if (response.contains('📊') ||
        response.contains('Summary') ||
        response.contains('analysis')) {
      return MessageType.summary;
    } else if (response.contains('❌') || response.contains('failed')) {
      return MessageType.error;
    }
    return MessageType.text;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Toggle voice input - start or stop listening
  void _toggleVoiceInput() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.mic_off, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Voice input not available. Please grant microphone permission.',
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isListening) {
      // Stop listening
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      // Start listening
      setState(() {
        _isListening = true;
        _lastWords = '';
        _confidence = 0.0;
      });

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
        localeId: 'en_IN', // Indian English
      );

      // Show listening indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text('Listening... Speak now'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppTheme.royalPurple,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Process speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _confidence = result.confidence;
      _messageController.text = _lastWords;
    });

    // If this is a final result, we can optionally auto-send
    if (result.finalResult && _lastWords.isNotEmpty) {
      // Update text field with recognized text
      _messageController.text = _lastWords;
      setState(() => _isListening = false);

      // Show confidence indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recognized (${(_confidence * 100).toStringAsFixed(0)}%): "$_lastWords"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          _buildBackground(),

          // Scribble Decorations
          Positioned(
            top: 80,
            right: 20,
            child: FloatingScribble(
              color: AppTheme.scribblePrimary,
              size: 50,
              type: ScribbleType.circle,
            ),
          ),
          Positioned(
            top: 200,
            left: 10,
            child: FloatingScribble(
              color: AppTheme.scribbleSecondary,
              size: 40,
              type: ScribbleType.star,
            ),
          ),
          Positioned(
            bottom: 150,
            right: 30,
            child: FloatingScribble(
              color: AppTheme.scribbleTertiary,
              size: 35,
              type: ScribbleType.squiggle,
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildChatArea()),
                _buildQuickActions(),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.mint,
                AppTheme.mintLight,
                Color.lerp(
                  AppTheme.royalPurple.withOpacity(0.03),
                  AppTheme.purpleGlow.withOpacity(0.05),
                  _gradientController.value,
                )!,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.glassWhite.withOpacity(0.85),
                AppTheme.royalPurple.withOpacity(0.03),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.royalPurple.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // AI Avatar with pulse animation - Purple sovereign
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.premiumGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.royalPurple.withOpacity(
                            0.3 + _pulseController.value * 0.2,
                          ),
                          blurRadius: 12 + _pulseController.value * 8,
                          spreadRadius: _pulseController.value * 2,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: AppTheme.royalPurple,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Founder\'s OS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.forestGreen,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online • Ready to help',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildIconButton(
                Icons.info_outline_rounded,
                () => _showCapabilitiesSheet(context),
                'Capabilities',
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                Icons.refresh_rounded,
                _clearChat,
                'Clear chat',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, String tooltip) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF4A5568),
            ),
          ),
        ),
      ),
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        _ChatMessage(
          text: "Chat cleared. How may I assist you?",
          isUser: false,
          timestamp: DateTime.now(),
          messageType: MessageType.text,
        ),
      );
    });
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        final msg = _messages[index];
        return _ChatBubble(
          message: msg,
          onActionConfirm: msg.messageType == MessageType.actionCard
              ? _handleActionConfirm
              : null,
          onActionCancel: msg.messageType == MessageType.actionCard
              ? _handleActionCancel
              : null,
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                // Sovereign purple-tinted glass for AI thinking
                gradient: LinearGradient(
                  colors: [
                    AppTheme.glassWhite.withOpacity(0.95),
                    AppTheme.royalPurple.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.royalPurple.withOpacity(0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.royalPurple.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AI badge
                  const AgenticToolBadge(
                    toolName: 'Processing',
                    isActive: true,
                  ),
                  const SizedBox(width: 12),
                  _AnimatedDot(delay: 0),
                  const SizedBox(width: 6),
                  _AnimatedDot(delay: 150),
                  const SizedBox(width: 6),
                  _AnimatedDot(delay: 300),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildQuickActions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _QuickActionChip(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Create budget',
            color: AppTheme.emerald, // Sovereign emerald for wealth actions
            onTap: () {
              _messageController.text = 'Create a budget of ₹5000 for food';
              _sendMessage();
            },
          ),
          _QuickActionChip(
            icon: Icons.flag_rounded,
            label: 'Set goal',
            color: AppTheme.forestGreen, // Forest green for growth goals
            onTap: () {
              _messageController.text =
                  'Create a savings goal of ₹100000 for emergency fund';
              _sendMessage();
            },
          ),
          _QuickActionChip(
            icon: Icons.auto_awesome,
            label: 'AI insights',
            color: AppTheme.royalPurple, // Purple for AI-powered features
            onTap: () {
              _messageController.text =
                  'Show my spending summary for this month';
              _sendMessage();
            },
          ),
          _QuickActionChip(
            icon: Icons.receipt_long_rounded,
            label: 'Scan receipt',
            color: AppTheme.purpleGlow, // Purple glow for scan features
            onTap: () {
              _messageController.text = 'I want to scan a receipt';
              _sendMessage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.glassWhite.withOpacity(0.9),
                AppTheme.mint.withOpacity(0.85),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: AppTheme.royalPurple.withOpacity(0.08),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Voice Button
                _buildVoiceButton(),
                const SizedBox(width: 12),
                // Input Field with Sovereign styling
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.emerald.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.forestGreen.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask your Founder\'s OS anything...',
                        hintStyle: TextStyle(
                          color: AppTheme.forestGreen.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.forestGreen,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Send Button
                _buildSendButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleVoiceInput,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isListening
                ? AppTheme.error.withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isListening
                  ? AppTheme.error.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Icon(
            _isListening ? Icons.mic : Icons.mic_none_rounded,
            size: 22,
            color: _isListening ? AppTheme.error : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _sendMessage,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: _isLoading
                ? null
                : AppTheme.growthGradient, // Sovereign emerald
            color: _isLoading ? Colors.grey[300] : null,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _isLoading
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.emerald.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  size: 22,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  void _showCapabilitiesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CapabilitiesSheet(),
    );
  }
}

// Message Types
enum MessageType { text, actionSuccess, summary, error, actionCard }

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType messageType;
  final String? actionType;
  final Map<String, dynamic>? actionData;
  final bool needsConfirmation;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageType = MessageType.text,
    this.actionType,
    this.actionData,
    this.needsConfirmation = false,
  });
}

// Chat Bubble Widget
class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final Function(String, Map<String, dynamic>?)? onActionConfirm;
  final VoidCallback? onActionCancel;

  const _ChatBubble({
    required this.message,
    this.onActionConfirm,
    this.onActionCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    if (message.messageType == MessageType.actionCard) {
      return _buildActionCardBubble(context);
    }

    // Show confirmation buttons if action needs confirmation
    if (message.needsConfirmation && message.actionType != null) {
      return _buildConfirmationBubble(context);
    }

    return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              bottom: 12,
              left: isUser ? 60 : 0,
              right: isUser ? 0 : 60,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isUser ? 0 : 10,
                  sigmaY: isUser ? 0 : 10,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // Sovereign Styling: User=Emerald, AI=Purple-tinted glass
                    gradient: isUser
                        ? AppTheme.growthGradient
                        : AppTheme.aiGlassDecoration().gradient,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 20),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: AppTheme.royalPurple.withOpacity(0.15),
                          ),
                    boxShadow: [
                      if (!isUser)
                        BoxShadow(
                          color: AppTheme.royalPurple.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      BoxShadow(
                        color: isUser
                            ? AppTheme.emerald.withOpacity(0.25)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        // AI indicator icon with purple glow
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.royalPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getLeadingIcon() ?? Icons.auto_awesome,
                            size: 16,
                            color: AppTheme.royalPurple,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _getTextColor(),
                            fontWeight: isUser
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(
          begin: isUser ? 0.1 : -0.1,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }

  Color _getTextColor() {
    if (message.isUser) return Colors.white;
    switch (message.messageType) {
      case MessageType.actionSuccess:
        return AppTheme.emerald; // Sovereign emerald
      case MessageType.summary:
        return AppTheme.royalPurple; // Purple for AI summaries
      case MessageType.error:
        return const Color(0xFFC62828);
      default:
        return AppTheme.forestGreen; // Forest green typography
    }
  }

  IconData? _getLeadingIcon() {
    switch (message.messageType) {
      case MessageType.actionSuccess:
        return Icons.check_circle_rounded;
      case MessageType.summary:
        return Icons.analytics_rounded;
      case MessageType.error:
        return Icons.error_outline_rounded;
      default:
        return null;
    }
  }

  Widget _buildActionCardBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 16),
        child: ActionCard(
          actionType: message.actionType ?? 'unknown',
          confirmationMessage: message.text,
          parameters: _extractParameters(),
          onConfirm: () {
            if (onActionConfirm != null) {
              onActionConfirm!(message.actionType ?? '', message.actionData);
            }
          },
          onCancel: onActionCancel ?? () {},
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildConfirmationBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.gradientStart.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gradientStart.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Confirm Button
                      ElevatedButton.icon(
                        onPressed: () {
                          if (onActionConfirm != null) {
                            onActionConfirm!(
                              message.actionType ?? '',
                              message.actionData?['data'],
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Cancel Button
                      OutlinedButton.icon(
                        onPressed: onActionCancel,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Map<String, dynamic> _extractParameters() {
    final params = <String, String>{};
    final data = message.actionData;
    if (data == null) return params;

    data.forEach((key, value) {
      if (value is Map) {
        value.forEach((k, v) {
          if (k == 'amount' || k == 'targetAmount') {
            params[_formatKey(k)] = '₹$v';
          } else {
            params[_formatKey(k)] = v.toString();
          }
        });
      }
    });

    return params;
  }

  String _formatKey(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// Animated Typing Dot
class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              gradient: AppTheme.aiGradient,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// Quick Action Chip
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Capabilities Bottom Sheet
class _CapabilitiesSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.aiGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'What I Can Do',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CapabilityItem(
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF667EEA),
                  title: 'Budget Management',
                  description: 'Create and track spending budgets',
                  example: '"Create a ₹5000 budget for groceries"',
                ),
                _CapabilityItem(
                  icon: Icons.flag_rounded,
                  color: const Color(0xFF38A169),
                  title: 'Savings Goals',
                  description: 'Set and monitor financial goals',
                  example: '"Save ₹100000 for a new bike by December"',
                ),
                _CapabilityItem(
                  icon: Icons.notifications_rounded,
                  color: const Color(0xFFED8936),
                  title: 'Payment Reminders',
                  description: 'Schedule recurring payment alerts',
                  example: '"Remind me about EMI of ₹8000 on 5th"',
                ),
                _CapabilityItem(
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFFE53E3E),
                  title: 'Transaction Tracking',
                  description: 'Log expenses via conversation',
                  example: '"I spent ₹500 on dinner yesterday"',
                ),
                _CapabilityItem(
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFF3182CE),
                  title: 'Financial Analysis',
                  description: 'Get insights on your spending',
                  example: '"Show my spending breakdown"',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String example;

  const _CapabilityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  example,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
