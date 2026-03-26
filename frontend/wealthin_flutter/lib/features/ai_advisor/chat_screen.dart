import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/services/hybrid_ai_service.dart';
import '../../core/services/memory_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/indian_theme.dart';
import '../../core/widgets/wealthin_logo.dart';
import '../../main.dart' show authService;
import '../brainstorm/enhanced_brainstorm_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum MessageType { text, chart, table }

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String mode;
  final bool isError;
  final MessageType type;
  final Map<String, dynamic>? chartData;
  final List<List<String>>? tableData;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.mode = '',
    this.isError = false,
    this.type = MessageType.text,
    this.chartData,
    this.tableData,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHAT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _initSpeech();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text:
            '**Namaste!** I\'m **Artha**, your personal Indian financial advisor.\n\n'
            'I combine ancient wealth philosophy with modern fintech intelligence. '
            'Ask me anything about:\n'
            '- 💰 Budgeting & savings\n'
            '- 📈 Investments (Mutual Funds, PPF, NPS, SGB)\n'
            '- 🏠 Loans & EMI planning\n'
            '- 📊 Your spending patterns\n\n'
            'I can also show you charts and tables — just ask!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingController.dispose();
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

  // ── Parse AI response text for embedded chart / table JSON ──
  ChatMessage _parseResponse(String rawText, String mode) {
    // Try to extract JSON chart spec: {"chart":{...}}
    final chartMatch = RegExp(
      r'\{"chart"\s*:\s*\{[^}]*\}[^}]*\}',
      dotAll: true,
    ).firstMatch(rawText);

    if (chartMatch != null) {
      try {
        final jsonStr = chartMatch.group(0)!;
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final chart = decoded['chart'] as Map<String, dynamic>;
        // Remove the JSON block from the display text
        final cleanText = rawText.replaceAll(chartMatch.group(0)!, '').trim();
        return ChatMessage(
          text: cleanText.isEmpty ? 'Here is your chart:' : cleanText,
          isUser: false,
          timestamp: DateTime.now(),
          mode: mode,
          type: MessageType.chart,
          chartData: chart,
        );
      } catch (_) {}
    }

    // Try to detect markdown table
    final tableMatch = RegExp(
      r'(\|.+\|\s*\n\|[-| :]+\|\s*\n(\|.+\|\s*\n?)+)',
    ).firstMatch(rawText);
    if (tableMatch != null) {
      final tableText = tableMatch.group(0)!;
      final parsed = _parseMarkdownTable(tableText);
      if (parsed != null && parsed.length > 1) {
        final cleanText = rawText.replaceAll(tableText, '').trim();
        return ChatMessage(
          text: cleanText,
          isUser: false,
          timestamp: DateTime.now(),
          mode: mode,
          type: MessageType.table,
          tableData: parsed,
        );
      }
    }

    return ChatMessage(
      text: rawText,
      isUser: false,
      timestamp: DateTime.now(),
      mode: mode,
    );
  }

  List<List<String>>? _parseMarkdownTable(String tableText) {
    try {
      final lines = tableText
          .split('\n')
          .where(
            (l) =>
                l.trim().isNotEmpty &&
                !RegExp(r'^\|[-| :]+\|$').hasMatch(l.trim()),
          )
          .toList();
      return lines.map((line) {
        return line
            .split('|')
            .where((cell) => cell.isNotEmpty)
            .map((cell) => cell.trim())
            .toList();
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userId = authService.currentUserId;

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

    _controller.clear();
    HapticFeedback.lightImpact();
    _scrollToBottom();

    // Build conversation history for context
    final history = _messages
        .where((m) => !m.isError)
        .take(10)
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();

    // Inject memory context
    final memCtx = await memoryService.buildMemoryContext(userId);

    try {
      final response = await hybridAI.chat(
        text,
        conversationHistory: history,
        userContext: memCtx.isNotEmpty ? {'memory': memCtx} : null,
        userId: userId,
      );

      // Extract and save memory facts asynchronously
      unawaited(memoryService.extractAndSave(response.response, userId));

      setState(() {
        _messages.add(
          _parseResponse(
            response.response,
            response.inferenceMode ?? 'Artha',
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error connecting to Artha. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _toggleVoice() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _controller.text = result.recognizedWords;
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepOnyx : AppTheme.lightSurface,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isCompact = MediaQuery.of(context).size.width < 380;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? AppTheme.richNavy : AppTheme.lightCard;
    final titleColor = isDark ? AppTheme.pearlWhite : AppTheme.lightTextPrimary;
    final subtitleColor = isDark
        ? AppTheme.silverMist
        : AppTheme.lightTextSecondary;
    final statusBg = isDark
        ? AppTheme.peacockTeal.withValues(alpha: 0.15)
        : AppTheme.peacockTeal.withValues(alpha: 0.12);

    return AppBar(
      backgroundColor: barBg,
      elevation: 0,
      titleSpacing: 12,
      title: Row(
        children: [
          const WealthInLogo(size: 34, showGlow: false),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Artha',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.syne(
                    color: titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'AI Financial Advisor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: subtitleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Online indicator
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.peacockTeal.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.peacockLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isCompact ? 'On' : 'Online',
                style: GoogleFonts.dmSans(
                  color: AppTheme.peacockLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Options',
          color: isDark ? AppTheme.inkSlate : AppTheme.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            if (value == 'ideas') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EnhancedBrainstormScreen(),
                ),
              );
            } else if (value == 'clear') {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'ideas',
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    size: 16,
                    color: AppTheme.royalGold,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ideas Mode',
                    style: GoogleFonts.dmSans(
                      color: isDark
                          ? AppTheme.pearlWhite
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clear Chat',
                    style: GoogleFonts.dmSans(
                      color: isDark
                          ? AppTheme.pearlWhite
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          icon: Icon(
            Icons.more_vert_rounded,
            color: isDark ? AppTheme.silverMist : AppTheme.lightTextSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppTheme.royalGold.withValues(alpha: 0.12),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildTypingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          margin: const EdgeInsets.only(right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.inkSlate : AppTheme.lightCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(
              color: AppTheme.royalGold.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _typingController,
                builder: (_, _) {
                  final offset = math.sin(
                    (_typingController.value * 2 * math.pi) + (i * 1.1),
                  );
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7 + (offset * 3),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? AppTheme.peacockLight
                                  : AppTheme.peacockTeal)
                              .withValues(alpha: 0.7 + offset * 0.3),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.inkSlate : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isListening
              ? AppTheme.royalGold.withValues(alpha: 0.60)
              : AppTheme.royalGold.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Voice button
          if (_speechAvailable)
            GestureDetector(
              onTap: _toggleVoice,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppTheme.royalGold.withValues(alpha: 0.20)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening
                        ? AppTheme.royalGold
                        : AppTheme.silverMist,
                    size: 20,
                  ),
                ),
              ),
            ),
          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoading,
              maxLines: 4,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: GoogleFonts.dmSans(
                color: isDark ? AppTheme.pearlWhite : AppTheme.lightTextPrimary,
                fontSize: 15,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'Ask Artha anything...',
                hintStyle: GoogleFonts.dmSans(
                  color:
                      (isDark
                              ? AppTheme.silverMist
                              : AppTheme.lightTextSecondary)
                          .withValues(alpha: 0.7),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                // No fill since the container handles the decoration
                filled: false,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          // Send button
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isLoading
                      ? (isDark ? AppTheme.inkSlate : AppTheme.lightBorder)
                      : AppTheme.peacockTeal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _isLoading
                      ? (isDark
                            ? AppTheme.silverMist
                            : AppTheme.lightTextSecondary)
                      : AppTheme.pearlWhite,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHAT BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            _buildBubble(context),
            if (!message.isUser && message.mode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4),
                child: Text(
                  '⚡ ${message.mode}',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.silverMist.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    if (message.isUser) {
      return _UserBubble(message: message);
    } else if (message.isError) {
      return _ErrorBubble(message: message);
    } else if (message.type == MessageType.chart) {
      return _ChartBubble(message: message);
    } else if (message.type == MessageType.table) {
      return _TableBubble(message: message);
    } else {
      return _AiBubble(message: message);
    }
  }
}

// ── User bubble ──
class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        gradient: IndianTheme.chatUserGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        message.text,
        style: GoogleFonts.dmSans(
          color: AppTheme.pearlWhite,
          fontSize: 14.5,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── AI text bubble with Markdown ──
class _AiBubble extends StatelessWidget {
  final ChatMessage message;
  const _AiBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = isDark ? AppTheme.inkSlate : AppTheme.lightCard;
    final textColor = isDark ? AppTheme.pearlWhite : AppTheme.lightTextPrimary;
    final secondaryText = isDark
        ? AppTheme.silverMist
        : AppTheme.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(
          color: AppTheme.royalGold.withValues(alpha: 0.12),
        ),
      ),
      child: MarkdownBody(
        data: message.text,
        styleSheet: MarkdownStyleSheet(
          p: GoogleFonts.dmSans(
            color: textColor,
            fontSize: 14.5,
            height: 1.55,
          ),
          h1: GoogleFonts.syne(
            color: AppTheme.champagneGold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          h2: GoogleFonts.syne(
            color: AppTheme.champagneGold,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          h3: GoogleFonts.syne(
            color: AppTheme.champagneGold,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          strong: GoogleFonts.dmSans(
            color: AppTheme.champagneGold,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
          em: GoogleFonts.dmSans(
            color: secondaryText,
            fontStyle: FontStyle.italic,
            fontSize: 14.5,
          ),
          code: GoogleFonts.sourceCodePro(
            color: isDark ? AppTheme.peacockLight : AppTheme.peacockTeal,
            fontSize: 13,
            backgroundColor: isDark
                ? AppTheme.deepSlate
                : AppTheme.lightSurface,
          ),
          blockquote: GoogleFonts.dmSans(
            color: secondaryText,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          listBullet: GoogleFonts.dmSans(
            color: AppTheme.peacockLight,
            fontSize: 14.5,
          ),
          blockquoteDecoration: BoxDecoration(
            color: isDark ? AppTheme.deepSlate : AppTheme.lightSurface,
            border: Border(
              left: BorderSide(color: AppTheme.peacockTeal, width: 3),
            ),
          ),
          codeblockDecoration: BoxDecoration(
            color: isDark ? AppTheme.deepSlate : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.inkSlate : AppTheme.lightBorder,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error bubble ──
class _ErrorBubble extends StatelessWidget {
  final ChatMessage message;
  const _ErrorBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.text,
              style: GoogleFonts.dmSans(
                color: isDark ? AppTheme.pearlWhite : AppTheme.lightTextPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline chart bubble using fl_chart ──
class _ChartBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChartBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chart = message.chartData!;
    final type = chart['type'] as String? ?? 'bar';
    final rawLabels = chart['labels'] as List<dynamic>? ?? [];
    final rawData = chart['data'] as List<dynamic>? ?? [];

    final labels = rawLabels.map((e) => e.toString()).toList();
    final data = rawData.map((e) => (e as num).toDouble()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text.isNotEmpty)
          _AiBubble(
            message: ChatMessage(
              text: message.text,
              isUser: false,
              timestamp: message.timestamp,
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          height: 240,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.inkSlate : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.peacockTeal.withValues(alpha: 0.25),
            ),
          ),
          child: type == 'pie'
              ? _PieChartWidget(labels: labels, data: data)
              : _BarLineChart(
                  labels: labels,
                  data: data,
                  isLine: type == 'line',
                ),
        ),
      ],
    );
  }
}

class _BarLineChart extends StatelessWidget {
  final List<String> labels;
  final List<double> data;
  final bool isLine;
  const _BarLineChart({
    required this.labels,
    required this.data,
    this.isLine = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.reduce((a, b) => a > b ? a : b);

    if (isLine) {
      final spots = List.generate(
        data.length,
        (i) => FlSpot(i.toDouble(), data[i]),
      );
      return LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.deepSlate, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final i = val.round();
                  if (i < 0 || i >= labels.length)
                    return const SizedBox.shrink();
                  return Text(
                    labels[i],
                    style: GoogleFonts.dmSans(
                      color: AppTheme.silverMist,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.peacockLight,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.royalGold,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.peacockTeal.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final i = val.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: GoogleFonts.dmSans(
                      color: AppTheme.silverMist,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          data.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                width: 16,
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [IndianTheme.peacockTeal, IndianTheme.peacockLight],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          ),
        ),
        maxY: maxVal * 1.2,
      ),
    );
  }
}

class _PieChartWidget extends StatelessWidget {
  final List<String> labels;
  final List<double> data;
  const _PieChartWidget({required this.labels, required this.data});

  static const _colors = [
    IndianTheme.peacockTeal,
    IndianTheme.royalGold,
    IndianTheme.lotusPink,
    IndianTheme.saffron,
    IndianTheme.mehendiGreen,
    IndianTheme.peacockLight,
    IndianTheme.champagneGold,
  ];

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0.0, (a, b) => a + b);
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: List.generate(data.length, (i) {
                final pct = total > 0 ? data[i] / total * 100 : 0;
                return PieChartSectionData(
                  value: data[i],
                  title: '${pct.toStringAsFixed(0)}%',
                  titleStyle: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  color: _colors[i % _colors.length],
                  radius: 60,
                );
              }),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            labels.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colors[i % _colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[i],
                    style: GoogleFonts.dmSans(
                      color: AppTheme.silverMist,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Table bubble ──
class _TableBubble extends StatelessWidget {
  final ChatMessage message;
  const _TableBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = message.tableData!;
    if (rows.isEmpty) return const SizedBox.shrink();

    final headers = rows.first;
    final dataRows = rows.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text.isNotEmpty)
          _AiBubble(
            message: ChatMessage(
              text: message.text,
              isUser: false,
              timestamp: message.timestamp,
            ),
          ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.inkSlate : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.royalGold.withValues(alpha: 0.15),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppTheme.peacockTeal.withValues(alpha: 0.15),
                ),
                headingTextStyle: GoogleFonts.dmSans(
                  color: AppTheme.champagneGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                dataTextStyle: GoogleFonts.dmSans(
                  color: AppTheme.pearlWhite,
                  fontSize: 12,
                ),
                dividerThickness: 0.5,
                columnSpacing: 20,
                horizontalMargin: 12,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 48,
                columns: headers
                    .map(
                      (h) => DataColumn(
                        label: Text(h),
                      ),
                    )
                    .toList(),
                rows: dataRows
                    .map(
                      (row) => DataRow(
                        cells: List.generate(
                          headers.length,
                          (i) => DataCell(
                            Text(i < row.length ? row[i] : ''),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
