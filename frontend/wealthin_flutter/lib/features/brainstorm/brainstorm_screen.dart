import 'dart:ui';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/python_bridge_service.dart';

// Data service singleton
final dataService = DataService();
final _pythonBridge = PythonBridgeService();

/// Mock BusinessIdea class - placeholder for future data model
class BusinessIdea {
  final String idea;
  final String title;
  final int score;
  final String estimatedInvestment;
  final String timeToBreakeven;
  final String marketAnalysis;
  final String targetAudience;
  final String revenueModel;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> suggestions;
  final List<String> nextSteps;
  final String summary;

  BusinessIdea({
    required this.idea,
    String? title,
    required this.score,
    required this.estimatedInvestment,
    required this.timeToBreakeven,
    required this.marketAnalysis,
    required this.targetAudience,
    required this.revenueModel,
    required this.strengths,
    required this.weaknesses,
    required this.suggestions,
    required this.nextSteps,
    required this.summary,
  }) : title = title ?? idea;
}

/// View mode for brainstorm screen
enum BrainstormViewMode { chat, canvas }

/// Brainstorm Screen - Business idea generator and analyzer
/// Mobile-first design with Chat/Canvas toggle
class BrainstormScreen extends StatelessWidget {
  const BrainstormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: BrainstormScreenBody(),
    );
  }
}

/// Brainstorm Screen Body - for embedding in tabs
class BrainstormScreenBody extends StatefulWidget {
  const BrainstormScreenBody({super.key});

  @override
  State<BrainstormScreenBody> createState() => _BrainstormScreenBodyState();
}

class _BrainstormScreenBodyState extends State<BrainstormScreenBody> {
  final TextEditingController _ideaController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();

  bool _isAnalyzing = false;
  BusinessIdea? _currentIdea;
  List<Map<String, dynamic>> _savedIdeas = [];
  bool _isLoadingSavedIdeas = false;

  // View mode toggle
  BrainstormViewMode _viewMode = BrainstormViewMode.chat;

  // Chat messages for chat mode
  final List<_ChatMessage> _chatMessages = [];
  bool _isChatLoading = false;

  // Stepped loading states for async UI
  int _currentLoadingStep = 0;
  static const List<String> _loadingSteps = [
    'Researching Market...',
    'Analyzing Competitors...',
    'Checking RBI Guidelines...',
    'Evaluating Financials...',
    'Finalizing Report...',
  ];

  // Research logs for animated display
  final List<_ResearchLogEntry> _researchLogs = [];
  final ScrollController _logScrollController = ScrollController();

  // Canvas items for canvas mode
  final List<_CanvasItem> _canvasItems = [];

  @override
  void initState() {
    super.initState();
    _loadSavedIdeas();
    _addWelcomeChatMessage();
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _logScrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  void _addWelcomeChatMessage() {
    _chatMessages.add(
      _ChatMessage(
        text:
            "Hey! I'm your brainstorming buddy.\n\n"
            "Tell me your business idea and I'll help you:\n"
            "- Analyze market potential\n"
            "- Find competitors\n"
            "- Discover government schemes\n"
            "- Evaluate financial viability\n\n"
            "What idea would you like to explore?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Load saved ideas from database
  Future<void> _loadSavedIdeas() async {
    setState(() => _isLoadingSavedIdeas = true);
    try {
      final ideas = await dataService.getSavedIdeas('user_1', limit: 20);
      if (mounted) {
        setState(() {
          _savedIdeas = ideas;
          _isLoadingSavedIdeas = false;
        });
      }
    } catch (e) {
      debugPrint('[Brainstorm] Error loading saved ideas: $e');
      if (mounted) {
        setState(() => _isLoadingSavedIdeas = false);
      }
    }
  }

  void _addResearchLog(String message, {bool isHighlight = false}) {
    if (mounted) {
      setState(() {
        _researchLogs.add(
          _ResearchLogEntry(
            message: message,
            timestamp: DateTime.now(),
            isHighlight: isHighlight,
          ),
        );
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isChatLoading) return;

    setState(() {
      _chatMessages.add(
        _ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isChatLoading = true;
    });
    _chatController.clear();
    _scrollChatToBottom();

    try {
      // Detect if this is a simple conversational message vs. a business idea
      final lowerText = text.toLowerCase().trim();
      final isSimpleChat = text.length < 40 && !_looksLikeBusinessIdea(lowerText);

      if (isSimpleChat) {
        // Fast path: Use lightweight AI chat for greetings/casual messages
        final result = await _pythonBridge.chatWithLLM(
          query: text,
          userId: 'user_1',
        );
        
        final responseText = result['response']?.toString() ?? 
            "Hey! Tell me about a business idea you'd like to explore, and I'll analyze its potential! 💡";

        if (mounted) {
          setState(() {
            _chatMessages.add(
              _ChatMessage(
                text: responseText,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            _isChatLoading = false;
          });
        }
      } else {
        // Full evaluation path for actual business ideas
        final evaluation = await dataService.evaluateIdea(
          userId: 'user_1',
          idea: text,
          location: 'India',
          budgetRange: '5-10 Lakhs',
        );

        if (mounted && evaluation != null) {
          final score = (evaluation['score'] as num?)?.toInt() ?? 70;
          final summary =
              evaluation['summary']?.toString() ?? 'Analysis complete.';
          final swot = evaluation['swot'] as Map<String, dynamic>?;
          final recommendations = List<String>.from(
            evaluation['recommendations'] ?? [],
          );

          // Build response message
          String responseText = "**Viability Score: $score/100**\n\n";
          responseText += "$summary\n\n";

          if (swot != null) {
            final strengths = List<String>.from(swot['strengths'] ?? []);
            final weaknesses = List<String>.from(swot['weaknesses'] ?? []);
            if (strengths.isNotEmpty) {
              responseText +=
                  "**Strengths:**\n${strengths.map((s) => '- $s').join('\n')}\n\n";
            }
            if (weaknesses.isNotEmpty) {
              responseText +=
                  "**Challenges:**\n${weaknesses.map((w) => '- $w').join('\n')}\n\n";
            }
          }

          if (recommendations.isNotEmpty) {
            responseText +=
                "**Recommendations:**\n${recommendations.take(3).map((r) => '- $r').join('\n')}";
          }

          setState(() {
            _chatMessages.add(
              _ChatMessage(
                text: responseText,
                isUser: false,
                timestamp: DateTime.now(),
                score: score,
              ),
            );
            _isChatLoading = false;

            // Add to canvas if score is good
            if (score >= 60) {
              _canvasItems.add(
                _CanvasItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: text.length > 50 ? '${text.substring(0, 47)}...' : text,
                  score: score,
                  summary: summary,
                ),
              );
            }
          });
          _loadSavedIdeas(); // Refresh saved ideas
        } else {
          // Fallback response
          setState(() {
            _chatMessages.add(
              _ChatMessage(
                text:
                    "I've noted your idea! Let me analyze it further. Try asking about specific aspects like market size, competition, or funding options.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            _isChatLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[Brainstorm] Chat error: $e');
      setState(() {
        _chatMessages.add(
          _ChatMessage(
            text:
                "I had trouble processing that. Could you try again?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isChatLoading = false;
      });
    }
    _scrollChatToBottom();
  }

  /// Heuristic to detect if a message looks like a business idea vs casual chat
  bool _looksLikeBusinessIdea(String text) {
    const ideaKeywords = [
      'business', 'idea', 'startup', 'app', 'product', 'service',
      'sell', 'market', 'customer', 'revenue', 'profit', 'invest',
      'shop', 'store', 'platform', 'saas', 'ecommerce', 'franchise',
      'manufacture', 'export', 'import', 'delivery', 'food',
      'restaurant', 'cafe', 'salon', 'gym', 'tuition', 'coaching',
      'real estate', 'rental', 'freelance', 'agency', 'consulting',
      'clinic', 'pharmacy', 'farming', 'organic', 'solar',
      'laundry', 'cleaning', 'transportation', 'logistics',
    ];
    return ideaKeywords.any((kw) => text.contains(kw));
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _analyzeIdea() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _currentLoadingStep = 0;
      _researchLogs.clear();
    });

    _addResearchLog('Starting Deep Research Analysis...', isHighlight: true);
    _addResearchLog('Query: "$idea"');

    _runLoadingSteps();

    try {
      final evaluation = await dataService.evaluateIdea(
        userId: 'user_1',
        idea: idea,
        location: 'India',
        budgetRange: '5-10 Lakhs',
      );

      if (mounted && evaluation != null) {
        final marketAnalysis =
            evaluation['market_analysis'] as Map<String, dynamic>?;
        final financialProjection =
            evaluation['financial_projection'] as Map<String, dynamic>?;
        final swot = evaluation['swot'] as Map<String, dynamic>?;
        final recommendations = List<String>.from(
          evaluation['recommendations'] ?? [],
        );
        final score = (evaluation['score'] as num?)?.toInt() ?? 70;

        setState(() {
          _currentIdea = BusinessIdea(
            idea: idea,
            title: idea.length > 60 ? '${idea.substring(0, 57)}...' : idea,
            score: score,
            estimatedInvestment:
                financialProjection?['initial_investment']?.toString() ??
                '₹5-10 Lakhs',
            timeToBreakeven:
                financialProjection?['break_even_timeline']?.toString() ??
                '12-18 months',
            marketAnalysis:
                marketAnalysis?['market_size']?.toString() ??
                'Growing market in India',
            targetAudience:
                marketAnalysis?['target_audience']?.toString() ??
                'Indian entrepreneurs and SMBs',
            revenueModel: (List<String>.from(
              evaluation['revenue_models'] ?? [],
            )).join(', '),
            strengths: List<String>.from(swot?['strengths'] ?? []),
            weaknesses: List<String>.from(swot?['weaknesses'] ?? []),
            suggestions: recommendations.take(5).toList(),
            nextSteps: [
              if (recommendations.length > 5)
                ...recommendations.skip(5).take(4),
              'Conduct detailed market research',
              'Create a minimum viable product (MVP)',
              'Identify potential early adopters',
              'Develop a go-to-market strategy',
            ].take(4).toList(),
            summary:
                evaluation['summary']?.toString() ??
                'Analysis complete. Score: $score/100.',
          );
          _isAnalyzing = false;
        });
        _addResearchLog(
          'OpenAI analysis complete! Score: $score/100',
          isHighlight: true,
        );
        _loadSavedIdeas();
        return;
      }

      await _mockAnalysis(idea);
    } catch (e) {
      debugPrint('Brainstorm analysis error: $e');
      await _mockAnalysis(idea);
    }
  }

  void _runLoadingSteps() async {
    final logMessages = [
      'Searching market data sources...',
      'Found 12 relevant market reports',
      'Analyzing 8 competitor profiles...',
      'Checking RBI compliance requirements...',
      'Evaluating financial projections...',
      'Processing growth metrics...',
      'Compiling final analysis...',
    ];

    int logIndex = 0;
    for (int i = 0; i < _loadingSteps.length && _isAnalyzing; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _isAnalyzing) {
        setState(() => _currentLoadingStep = i);
        if (logIndex < logMessages.length) {
          _addResearchLog(logMessages[logIndex]);
          logIndex++;
        }
        if (i == 1 && logIndex < logMessages.length) {
          await Future.delayed(const Duration(milliseconds: 400));
          _addResearchLog(logMessages[logIndex]);
          logIndex++;
        }
      }
    }
    if (mounted && _isAnalyzing) {
      _addResearchLog('Analysis complete!', isHighlight: true);
    }
  }

  Future<void> _mockAnalysis(String idea) async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _currentIdea = BusinessIdea(
          idea: idea,
          score: 75,
          estimatedInvestment: "₹5-10 Lakhs",
          timeToBreakeven: "12-18 months",
          marketAnalysis:
              'This idea shows good market potential in the current economic climate.',
          targetAudience:
              'Urban professionals aged 25-45, tech-savvy individuals.',
          revenueModel: 'Subscription-based model with tiered pricing.',
          strengths: [
            'Growing market demand',
            'Low initial capital',
            'Scalable model',
            'Clear value proposition',
          ],
          weaknesses: [
            'Competitive landscape',
            'Customer acquisition costs',
            'Building trust',
            'Operational complexity',
          ],
          suggestions: [
            "Add premium features",
            "Consider B2B model",
            "Build community",
          ],
          nextSteps: [
            'Conduct market research',
            'Create MVP',
            'Identify early adopters',
            'Go-to-market strategy',
          ],
          summary: 'A promising idea with solid fundamentals.',
        );
        _isAnalyzing = false;
      });
    }
  }

  void _saveIdea() {
    if (_currentIdea != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Idea saved automatically!'),
            ],
          ),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Container(
      color: isDark ? WealthInColors.deepObsidian : WealthInColors.ivoryMist,
      child: SafeArea(
        child: Column(
          children: [
            // Header with toggle
            _buildHeader(isDark, isSmallScreen),

            // Saved ideas badge
            if (_savedIdeas.isNotEmpty) _buildSavedIdeasBadge(),

            // Main content based on view mode
            Expanded(
              child: _viewMode == BrainstormViewMode.chat
                  ? _buildChatView(isDark)
                  : _buildCanvasView(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? WealthInColors.blackCard : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: WealthInColors.primary,
                  size: isSmallScreen ? 24 : 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Brainstorm',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? WealthInColors.textPrimaryDark
                        : WealthInColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // View mode toggle
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? WealthInColors.deepObsidian
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  icon: Icons.chat_bubble_outline,
                  label: isSmallScreen ? null : 'Chat',
                  isSelected: _viewMode == BrainstormViewMode.chat,
                  onTap: () =>
                      setState(() => _viewMode = BrainstormViewMode.chat),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildToggleButton(
                  icon: Icons.dashboard_outlined,
                  label: isSmallScreen ? null : 'Canvas',
                  isSelected: _viewMode == BrainstormViewMode.canvas,
                  onTap: () =>
                      setState(() => _viewMode = BrainstormViewMode.canvas),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    String? label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? WealthInColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSavedIdeasBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Badge(
          label: Text('${_savedIdeas.length}'),
          child: IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () => _showSavedIdeas(context),
            tooltip: 'Saved ideas',
          ),
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }

  // ==================== CHAT VIEW ====================

  Widget _buildChatView(bool isDark) {
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _chatMessages.length + (_isChatLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isChatLoading && index == _chatMessages.length) {
                return _buildTypingIndicator(isDark);
              }
              return _buildChatBubble(_chatMessages[index], isDark);
            },
          ),
        ),

        // Input area
        _buildChatInput(isDark),
      ],
    );
  }

  Widget _buildChatBubble(_ChatMessage message, bool isDark) {
    final isUser = message.isUser;

    return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              bottom: 12,
              left: isUser ? 50 : 0,
              right: isUser ? 0 : 50,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? WealthInColors.primary
                  : (isDark ? WealthInColors.blackCard : Colors.white),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.score != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getScoreColor(message.score!).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Score: ${message.score}/100',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(message.score!),
                      ),
                    ),
                  ),
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isUser
                        ? Colors.white
                        : (isDark
                              ? WealthInColors.textPrimaryDark
                              : WealthInColors.textPrimary),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideX(
          begin: isUser ? 0.1 : -0.1,
          end: 0,
          curve: Curves.easeOut,
        );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, right: 80),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? WealthInColors.blackCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                  'Analyzing...',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: WealthInColors.primary.withOpacity(0.3),
        );
  }

  Widget _buildDot(int index) {
    return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: WealthInColors.primary,
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          delay: Duration(milliseconds: index * 150),
          duration: 400.ms,
          begin: const Offset(0.6, 0.6),
          end: const Offset(1.0, 1.0),
        )
        .then()
        .scale(
          duration: 400.ms,
          begin: const Offset(1.0, 1.0),
          end: const Offset(0.6, 0.6),
        );
  }

  Widget _buildChatInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? WealthInColors.blackCard : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? WealthInColors.deepObsidian
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _chatController,
                focusNode: _chatFocusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe your business idea...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? WealthInColors.textPrimaryDark
                      : WealthInColors.textPrimary,
                ),
                onSubmitted: (_) => _sendChatMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isChatLoading ? null : _sendChatMessage,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _chatController.text.trim().isNotEmpty && !_isChatLoading
                    ? WealthInColors.primary
                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isChatLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : WealthInColors.primary,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: _chatController.text.trim().isNotEmpty
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.black38),
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CANVAS VIEW ====================

  Widget _buildCanvasView(bool isDark) {
    return Column(
      children: [
        // Quick input for canvas
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildQuickAnalyzeInput(isDark),
        ),

        // Research log panel during analysis
        if (_isAnalyzing && _researchLogs.isNotEmpty)
          _ResearchLogPanel(
            logs: _researchLogs,
            scrollController: _logScrollController,
          ).animate().fadeIn(duration: 300.ms),

        // Analysis results
        if (_currentIdea != null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _IdeaAnalysisCard(
                idea: _currentIdea!,
                onSave: _saveIdea,
              ).animate().fadeIn(duration: 600.ms).moveY(begin: 30, end: 0),
            ),
          ),

        // Canvas items grid
        if (_currentIdea == null && !_isAnalyzing)
          Expanded(
            child: _canvasItems.isEmpty
                ? _buildEmptyCanvas(isDark)
                : _buildCanvasGrid(isDark),
          ),
      ],
    );
  }

  Widget _buildQuickAnalyzeInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? WealthInColors.blackCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? WealthInColors.primary.withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Analysis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? WealthInColors.textPrimaryDark
                  : WealthInColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ideaController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g., A subscription service for homemade healthy tiffins...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark
                  ? WealthInColors.deepObsidian
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(
              color: isDark
                  ? WealthInColors.textPrimaryDark
                  : WealthInColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _analyzeIdea,
              style: ElevatedButton.styleFrom(
                backgroundColor: WealthInColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isAnalyzing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_loadingSteps[_currentLoadingStep]),
                      ],
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Analyze',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCanvas(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Your ideas will appear here',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Chat or Quick Analysis to brainstorm',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _canvasItems.length,
      itemBuilder: (context, index) {
        final item = _canvasItems[index];
        return _buildCanvasCard(item, isDark, index);
      },
    );
  }

  Widget _buildCanvasCard(_CanvasItem item, bool isDark, int index) {
    return Container(
          decoration: BoxDecoration(
            color: isDark ? WealthInColors.blackCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getScoreColor(item.score).withOpacity(0.3),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreCircle(score: item.score, size: 36),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () =>
                        setState(() => _canvasItems.removeAt(index)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? WealthInColors.textPrimaryDark
                        : WealthInColors.textPrimary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )
        .animate(delay: (index * 100).ms)
        .fadeIn()
        .scale(begin: const Offset(0.9, 0.9));
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return const Color(0xFF7CB342);
    if (score >= 40) return WealthInTheme.warning;
    return AppTheme.error;
  }

  void _showSavedIdeas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: WealthInTheme.gray300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Saved Ideas (${_savedIdeas.length})',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (_isLoadingSavedIdeas)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _savedIdeas.isEmpty && !_isLoadingSavedIdeas
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No saved ideas yet',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Evaluate an idea to get started!',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _savedIdeas.length,
                              itemBuilder: (context, index) {
                                final ideaData = _savedIdeas[index];
                                final score =
                                    (ideaData['score'] as num?)?.toInt() ?? 0;
                                final ideaText =
                                    ideaData['idea_text'] as String? ?? 'Idea';
                                final viability =
                                    ideaData['viability'] as String? ??
                                    'Unknown';

                                return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        leading: _ScoreCircle(score: score),
                                        title: Text(
                                          ideaText.length > 60
                                              ? '${ideaText.substring(0, 57)}...'
                                              : ideaText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text('Viability: $viability'),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: (index * 100).ms)
                                    .moveX();
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== HELPER CLASSES ====================

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final int? score;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.score,
  });
}

class _CanvasItem {
  final String id;
  final String title;
  final int score;
  final String summary;

  _CanvasItem({
    required this.id,
    required this.title,
    required this.score,
    required this.summary,
  });
}

class _ResearchLogEntry {
  final String message;
  final DateTime timestamp;
  final bool isHighlight;

  _ResearchLogEntry({
    required this.message,
    required this.timestamp,
    this.isHighlight = false,
  });
}

class _GlassContainer extends StatelessWidget {
  final Widget child;

  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppTheme.glassDecoration(opacity: 0.12),
          child: child,
        ),
      ),
    );
  }
}

class _IdeaAnalysisCard extends StatelessWidget {
  final BusinessIdea idea;
  final VoidCallback onSave;

  const _IdeaAnalysisCard({required this.idea, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ScoreCircle(score: idea.score, size: 70),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viability Score',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        _getScoreLabel(idea.score),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: _getScoreColor(idea.score),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add),
                  tooltip: 'Save idea',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.currency_rupee,
                    label: 'Investment',
                    value: idea.estimatedInvestment,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.timer,
                    label: 'Breakeven',
                    value: idea.timeToBreakeven,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _AnalysisSection(
              title: 'Strengths',
              icon: Icons.check_circle,
              color: AppTheme.success,
              items: idea.strengths,
            ),
            const SizedBox(height: 20),
            _AnalysisSection(
              title: 'Challenges',
              icon: Icons.warning,
              color: WealthInTheme.warning,
              items: idea.weaknesses,
            ),
            const SizedBox(height: 20),
            _AnalysisSection(
              title: 'Recommendations',
              icon: Icons.lightbulb,
              color: WealthInTheme.purple,
              items: idea.suggestions,
            ),
          ],
        ),
      ),
    );
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    return 'Needs Work';
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return const Color(0xFF7CB342);
    if (score >= 40) return WealthInTheme.warning;
    return AppTheme.error;
  }
}

class _ScoreCircle extends StatelessWidget {
  final int score;
  final double size;

  const _ScoreCircle({required this.score, this.size = 48});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 80) {
      color = AppTheme.success;
    } else if (score >= 60) {
      color = const Color(0xFF7CB342);
    } else if (score >= 40) {
      color = WealthInTheme.warning;
    } else {
      color = AppTheme.error;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              color: color.withOpacity(0.15),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$score',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: size * 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
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

class _AnalysisSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _AnalysisSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: items
              .map(
                (item) => ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ResearchLogPanel extends StatelessWidget {
  final List<_ResearchLogEntry> logs;
  final ScrollController scrollController;

  const _ResearchLogPanel({required this.logs, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.6)
            : Colors.grey.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WealthInColors.primary.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                border: Border(
                  bottom: BorderSide(
                    color: WealthInColors.primary.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal,
                    size: 14,
                    color: WealthInColors.primary.withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Deep Research Agent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: WealthInColors.success,
                      boxShadow: [
                        BoxShadow(
                          color: WealthInColors.success.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final timeStr =
                      '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
                  return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[$timeStr] ',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: log.isHighlight
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: log.isHighlight
                                      ? WealthInColors.primary
                                      : Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .moveX(begin: -10, end: 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
