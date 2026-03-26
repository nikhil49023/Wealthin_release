import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/hybrid_ai_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/indian_theme.dart';
import '../../core/widgets/indian_patterns.dart';
import '../../main.dart' show authService;
import '../brainstorm/enhanced_brainstorm_screen.dart';

/// Premium AI Advisor Screen with Indian Aesthetics
/// Features: Mode selector (Chat, Ideas, Research), Glassmorphic design, Indian patterns
class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

enum AIMode { chat, ideas, research }

class _AiAdvisorScreenState extends State<AiAdvisorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  AIMode _currentMode = AIMode.chat;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _messages.add(
      Message(
        text: 'Namaste! I\'m your AI financial advisor. Ask me anything about budgeting, saving, investing, or financial planning. I\'m here to help you achieve prosperity.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await hybridAI.chat(
        text,
        userId: authService.currentUserId,
      );

      setState(() {
        _messages.add(Message(
          text: response.response,
          isUser: false,
          timestamp: DateTime.now(),
          mode: response.inferenceMode ?? 'AI',
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(Message(
          text: 'I apologize, but I couldn\'t process your request. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
  }

  void _switchMode(AIMode mode) {
    if (mode == AIMode.ideas) {
      // Navigate to Ideas/Brainstorm screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EnhancedBrainstormScreen()),
      );
    } else {
      setState(() => _currentMode = mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? IndianTheme.peacockGradient
                  : IndianTheme.sacredMorningGradient,
            ),
          ),

          // Background patterns
          const IndianPatternOverlay(
            showMandala: true,
            showRangoli: false,
            child: SizedBox.expand(),
          ),

          // Main content
          Column(
            children: [
              // Custom App Bar
              _buildAppBar(),

              // Mode Selector
              _buildModeSelector(),

              // Messages
              Expanded(child: _buildMessageList()),

              // Input Area
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 16,
        right: 16,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        gradient: isDark
            ? IndianTheme.templeSunsetGradient
            : IndianTheme.sunriseGradient,
        boxShadow: [
          BoxShadow(
            color: IndianTheme.saffron.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Financial Advisor',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Your path to prosperity',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // Animated Lotus indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + (_pulseController.value * 0.1),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    boxShadow: [
                      BoxShadow(
                        color: IndianTheme.lotusPink
                            .withValues(alpha: 0.3 * _pulseController.value),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.filter_vintage_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isDark ? AppTheme.inkSlate : AppTheme.lightCard)
                      .withValues(alpha: 0.95),
                  (isDark ? AppTheme.deepSlate : IndianTheme.goldShimmer)
                      .withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: IndianTheme.royalGold.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: IndianTheme.royalGold.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildModeButton(
                  mode: AIMode.chat,
                  icon: Icons.chat_rounded,
                  label: 'Chat',
                ),
                _buildModeButton(
                  mode: AIMode.ideas,
                  icon: Icons.lightbulb_rounded,
                  label: 'Ideas',
                ),
                _buildModeButton(
                  mode: AIMode.research,
                  icon: Icons.search_rounded,
                  label: 'Research',
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildModeButton({
    required AIMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentMode == mode;
    final isIdeas = mode == AIMode.ideas;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? (isIdeas
                    ? LinearGradient(
                        colors: [
                          IndianTheme.turmeric,
                          IndianTheme.turmericPaste,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : IndianTheme.chatUserGradient)
                : (isIdeas
                    ? LinearGradient(
                        colors: [
                          IndianTheme.turmeric.withValues(alpha: 0.3),
                          IndianTheme.turmericPaste.withValues(alpha: 0.2),
                        ],
                      )
                    : null),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isIdeas
                              ? IndianTheme.turmeric
                              : IndianTheme.saffron)
                          .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected || isIdeas
                    ? Colors.white
                  : (isDark ? AppTheme.silverMist : IndianTheme.templeStone),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected || isIdeas
                        ? Colors.white
                        : (isDark ? AppTheme.silverMist : IndianTheme.templeStone),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isIdeas) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildLoadingIndicator();
        }

        final message = _messages[index];
        return _MessageBubble(message: message)
            .animate()
            .fadeIn(duration: 200.ms)
            .slideX(
              begin: message.isUser ? 0.1 : -0.1,
              end: 0,
              duration: 200.ms,
            );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isDark ? AppTheme.inkSlate : AppTheme.lightCard)
                      .withValues(alpha: 0.95),
                  (isDark ? AppTheme.deepSlate : IndianTheme.goldShimmer)
                      .withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: IndianTheme.royalGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(IndianTheme.saffron),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Thinking...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? AppTheme.silverMist : IndianTheme.templeStone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1500.ms,
          color: IndianTheme.royalGold.withValues(alpha: 0.3),
        );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.richNavy : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Quick suggestions button
            Container(
              margin: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: _showQuickSuggestions,
                icon: const Icon(Icons.tips_and_updates_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.deepSlate : IndianTheme.goldShimmer,
                  foregroundColor: isDark ? AppTheme.champagneGold : IndianTheme.saffronDeep,
                  padding: const EdgeInsets.all(10),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.inkSlate : IndianTheme.marbleCream,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: IndianTheme.champagneGold.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !_isLoading,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? AppTheme.pearlWhite : IndianTheme.templeGranite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask about your finances...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: (isDark ? AppTheme.silverMist : IndianTheme.templeStone)
                          .withValues(alpha: 0.7),
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
                gradient: IndianTheme.templeSunsetGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: IndianTheme.saffron.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: _isLoading
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white,
                ),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(10),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickSuggestions() {
    final suggestions = [
      'How can I improve my savings rate?',
      'Suggest a budget for my income',
      'Best investment options for beginners',
      'How to reduce my monthly expenses?',
      'Should I invest in mutual funds or stocks?',
      'Tips for building an emergency fund',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isDark
                ? IndianTheme.sacredNightGradient
                : IndianTheme.sacredMorningGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: IndianTheme.royalGold.withValues(alpha: 0.3),
              width: 2,
            ),
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
                    color: (isDark ? AppTheme.silverMist : IndianTheme.templeStone)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    color: IndianTheme.saffron,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Quick Suggestions',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.pearlWhite : IndianTheme.templeGranite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((suggestion) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _controller.text = suggestion;
                      _sendMessage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.inkSlate : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: IndianTheme.champagneGold,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? AppTheme.pearlWhite : IndianTheme.templeGranite,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

/// Simple message model
class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String mode;
  final bool isError;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.mode = 'AI',
    this.isError = false,
  });
}

/// Premium Message Bubble with Indian styling
class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? IndianTheme.templeSunsetGradient
                    : (message.isError
                        ? LinearGradient(
                            colors: [
                              IndianTheme.vermillion.withValues(alpha: 0.1),
                              IndianTheme.vermillionLight.withValues(alpha: 0.05),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              (isDark ? AppTheme.inkSlate : Colors.white)
                                  .withValues(alpha: 0.95),
                              (isDark ? AppTheme.deepSlate : IndianTheme.goldShimmer)
                                  .withValues(alpha: 0.3),
                            ],
                          )),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                border: message.isUser
                    ? null
                    : Border.all(
                        color: message.isError
                            ? IndianTheme.vermillion.withValues(alpha: 0.3)
                            : IndianTheme.royalGold.withValues(alpha: 0.2),
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (message.isUser
                            ? IndianTheme.saffron
                            : IndianTheme.templeStone)
                        .withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  color: message.isUser
                      ? Colors.white
                      : (message.isError
                          ? IndianTheme.vermillion
                          : (isDark ? AppTheme.pearlWhite : IndianTheme.templeGranite)),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            if (!message.isUser && message.mode != 'AI')
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 11,
                      color: IndianTheme.peacockBlue,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      message.mode,
                      style: GoogleFonts.poppins(
                        color: (isDark ? AppTheme.silverMist : IndianTheme.templeStone)
                            .withValues(alpha: 0.7),
                        fontSize: 10,
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
