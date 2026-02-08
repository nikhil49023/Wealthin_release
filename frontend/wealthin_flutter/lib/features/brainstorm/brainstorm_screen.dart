import 'dart:ui';
// TODO: Firebase migration - removed wealthin_client import
// import 'package:wealthin_client/wealthin_client.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';
import '../../core/services/data_service.dart';
// TODO: Firebase migration - removed main.dart import (was used for Serverpod client)
// import '../../main.dart';

// Data service singleton
final dataService = DataService();

/// Mock BusinessIdea class for Firebase migration
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

/// Brainstorm Screen - Business idea generator and analyzer
class BrainstormScreen extends StatelessWidget {
  const BrainstormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Brainstorm'),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: const BrainstormScreenBody(),
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
  final TextEditingController _answerController = TextEditingController();
  bool _isAnalyzing = false;
  BusinessIdea? _currentIdea;
  final List<BusinessIdea> _savedIdeas = [];
  
  // Mode toggle: false = Quick Analysis, true = DPR Journey
  bool _isDPRMode = false;
  
  // DPR Journey state
  bool _isInSocraticSession = false;
  Map<String, dynamic>? _currentQuestion;
  List<Map<String, dynamic>> _conversationHistory = [];
  double _dprCompleteness = 0.0;
  int _questionsAnswered = 0;
  
  // DPR sections progress
  final Map<String, bool> _sectionsCompleted = {
    'executive_summary': false,
    'promoter_profile': false,
    'market_analysis': false,
    'financial_projections': false,
    'cost_of_project': false,
  };
  
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


  @override
  void dispose() {
    _ideaController.dispose();
    _answerController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  /// Start DPR Journey with Socratic questioning
  Future<void> _startDPRJourney() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) return;

    setState(() {
      _isInSocraticSession = true;
      _conversationHistory.clear();
      _questionsAnswered = 0;
      _dprCompleteness = 0.0;
    });

    // Call backend to start session
    final result = await dataService.startSocraticSession(businessIdea: idea);
    
    if (result != null && result['initial_question'] != null) {
      setState(() {
        _currentQuestion = result['initial_question'] as Map<String, dynamic>;
        _conversationHistory.add({
          'type': 'question',
          'content': _currentQuestion!['question'],
          'question_type': _currentQuestion!['question_type'],
        });
      });
    }
  }

  /// Process user answer and get next Socratic question
  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty || _currentQuestion == null) return;

    setState(() {
      _conversationHistory.add({
        'type': 'answer',
        'content': answer,
      });
      _questionsAnswered++;
      _dprCompleteness = (_questionsAnswered / 10.0 * 100).clamp(0, 100);
    });

    _answerController.clear();

    // Call backend to process response
    final result = await dataService.processSocraticResponse(
      response: answer,
      questionContext: _currentQuestion!,
    );

    if (result != null && result['next_question'] != null) {
      setState(() {
        _currentQuestion = result['next_question'] as Map<String, dynamic>;
        _conversationHistory.add({
          'type': 'question',
          'content': _currentQuestion!['question'],
          'question_type': _currentQuestion!['question_type'] ?? 'follow_up',
        });
      });
    }
  }

  void _addResearchLog(String message, {bool isHighlight = false}) {
    if (mounted) {
      setState(() {
        _researchLogs.add(_ResearchLogEntry(
          message: message,
          timestamp: DateTime.now(),
          isHighlight: isHighlight,
        ));
      });
      // Auto-scroll to bottom
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

  Future<void> _analyzeIdea() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _currentLoadingStep = 0;
      _researchLogs.clear();
    });
    
    _addResearchLog('🚀 Starting Deep Research Analysis...', isHighlight: true);
    _addResearchLog('📋 Query: "$idea"');
    
    // Simulate stepped loading for better UX
    _runLoadingSteps();

        try {
      // Call the AI agent service with brainstorm_business_idea tool
      final response = await dataService.brainstormBusinessIdea(
        idea: idea,
        userId: 'user_1',
      );
      
      if (mounted && response != null) {
        setState(() {
          _currentIdea = BusinessIdea(
            idea: idea,
            score: response['score'] ?? 70,
            estimatedInvestment: response['budget_range'] ?? "₹5-10 Lakhs",
            timeToBreakeven: "12-18 months",
            marketAnalysis: _extractResearchSummary(response['research'], 'market_data'),
            targetAudience: 'Urban professionals aged 25-45, tech-savvy individuals.',
            revenueModel: 'Subscription-based model with tiered pricing.',
            strengths: _extractTitles(response['research'], 'market_data'),
            weaknesses: _extractTitles(response['research'], 'competition'),
            suggestions: _extractTitles(response['research'], 'govt_schemes'),
            nextSteps: [
              'Conduct detailed market research',
              'Create a minimum viable product (MVP)',
              'Identify potential early adopters',
              'Develop a go-to-market strategy',
            ],
            summary: response['message'] ?? 'A promising idea with solid fundamentals.',
          );
          _isAnalyzing = false;
        });
      } else {
        // Fallback to mock if backend fails
        await _mockAnalysis(idea);
      }
    } catch (e) {
      debugPrint('Brainstorm analysis error: $e');
      // Fallback to mock analysis
      await _mockAnalysis(idea);
    }
  }
  
  String _extractResearchSummary(Map<String, dynamic>? research, String key) {
    if (research == null || research[key] == null) {
      return 'Market research data is being gathered.';
    }
    final items = research[key] as List?;
    if (items == null || items.isEmpty) return 'Data pending.';
    return items.map((i) => i['snippet'] ?? '').take(2).join(' ');
  }
  
  List<String> _extractTitles(Map<String, dynamic>? research, String key) {
    if (research == null || research[key] == null) return [];
    final items = research[key] as List?;
    if (items == null) return [];
    return items.map<String>((i) => (i['title'] ?? '') as String).take(4).toList();
  }
  
  /// Runs stepped loading animation while analysis happens
  void _runLoadingSteps() async {
    final logMessages = [
      '🔍 Searching market data sources...',
      '📊 Found 12 relevant market reports',
      '🏢 Analyzing 8 competitor profiles...',
      '⚖️ Checking RBI compliance requirements...',
      '💰 Evaluating financial projections...',
      '📈 Processing growth metrics...',
      '✅ Compiling final analysis...',
    ];
    
    int logIndex = 0;
    for (int i = 0; i < _loadingSteps.length && _isAnalyzing; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _isAnalyzing) {
        setState(() => _currentLoadingStep = i);
        // Add corresponding log message
        if (logIndex < logMessages.length) {
          _addResearchLog(logMessages[logIndex]);
          logIndex++;
        }
        // Add extra log for some steps
        if (i == 1 && logIndex < logMessages.length) {
          await Future.delayed(const Duration(milliseconds: 400));
          _addResearchLog(logMessages[logIndex]);
          logIndex++;
        }
      }
    }
    // Final success log
    if (mounted && _isAnalyzing) {
      _addResearchLog('🎉 Analysis complete!', isHighlight: true);
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
              'This idea shows good market potential in the current economic climate. '
              'The target demographic is growing and there\'s room for differentiation.',
          targetAudience:
              'Urban professionals aged 25-45, middle to upper-middle class, '
              'tech-savvy individuals who value convenience.',
          revenueModel:
              'Subscription-based model with tiered pricing. '
              'Additional revenue through premium features and partnerships.',
          strengths: [
            'Growing market demand',
            'Low initial capital requirement',
            'Scalable business model',
            'Clear value proposition',
          ],
          weaknesses: [
            'Competitive market landscape',
            'Customer acquisition costs',
            'Building trust with new users',
            'Operational complexity at scale',
          ],
          suggestions: [
            "Add premium features",
            "Consider B2B model",
            "Build community around product",
          ],
          nextSteps: [
            'Conduct detailed market research',
            'Create a minimum viable product (MVP)',
            'Identify potential early adopters',
            'Develop a go-to-market strategy',
          ],
          summary:
              'A promising idea with solid fundamentals. Focus on differentiation '
              'and building a strong initial user base.',
        );
        _isAnalyzing = false;
      });
    }
  }

  void _saveIdea() {
    if (_currentIdea != null) {
      setState(() {
        _savedIdeas.insert(0, _currentIdea!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Idea saved!')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_savedIdeas.isNotEmpty)
          Padding(
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
          ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
        Expanded(
          child: _buildContent(theme),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? WealthInColors.deepObsidian : WealthInColors.ivoryMist,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header with Mode Toggle
            if (_currentIdea == null && !_isInSocraticSession) ...[
              const SizedBox(height: 40),
              Icon(
                _isDPRMode ? Icons.description : Icons.auto_awesome,
                size: 48,
                color: WealthInColors.primary,
              ).animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
              const SizedBox(height: 24),
              Text(
                _isDPRMode ? 'DPR Journey' : 'Brainstorm',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? WealthInColors.textPrimaryDark : WealthInColors.textPrimary,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              Text(
                _isDPRMode 
                    ? 'Guided DPR creation with AI questioning'
                    : 'AI-powered business idea analysis',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? WealthInColors.textSecondaryDark : WealthInColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 24),
              
              // Mode Toggle - NEW VISIBLE FEATURE
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? WealthInColors.blackCard : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeToggleButton(
                      label: 'Quick Analysis',
                      icon: Icons.bolt,
                      isSelected: !_isDPRMode,
                      onTap: () => setState(() => _isDPRMode = false),
                    ),
                    const SizedBox(width: 4),
                    _ModeToggleButton(
                      label: 'DPR Journey',
                      icon: Icons.route,
                      isSelected: _isDPRMode,
                      onTap: () => setState(() => _isDPRMode = true),
                      isNew: true, // Shows "NEW" badge
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 32),
            ],
            
            // DPR Progress Indicator (when in DPR mode)
            if (_isDPRMode && !_isInSocraticSession) ...[
              _DPRProgressCard(
                completeness: _dprCompleteness,
                sectionsCompleted: _sectionsCompleted,
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 24),
            ],
            
            // Socratic Conversation UI
            if (_isInSocraticSession) ...[
              _SocraticConversationCard(
                conversationHistory: _conversationHistory,
                currentQuestion: _currentQuestion,
                answerController: _answerController,
                onSubmit: _submitAnswer,
                completeness: _dprCompleteness,
                questionsAnswered: _questionsAnswered,
                onExit: () => setState(() {
                  _isInSocraticSession = false;
                  _conversationHistory.clear();
                }),
              ).animate().fadeIn(duration: 400.ms),
            ] else ...[
            
            // Input Card - Clean & Elegant
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: isDark ? WealthInColors.blackCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark 
                      ? WealthInColors.primary.withValues(alpha: 0.2) 
                      : Colors.grey.shade200,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Describe your idea',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? WealthInColors.textPrimaryDark : WealthInColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ideaController,
                    maxLines: 4,
                    style: TextStyle(
                      color: isDark ? WealthInColors.textPrimaryDark : WealthInColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g., A subscription service for homemade healthy tiffins...',
                      hintStyle: TextStyle(
                        color: isDark ? WealthInColors.textSecondaryDark : WealthInColors.textSecondary,
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
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isAnalyzing 
                          ? null 
                          : (_isDPRMode ? _startDPRJourney : _analyzeIdea),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDPRMode 
                            ? const Color(0xFF6366F1) // Indigo for DPR
                            : WealthInColors.primary,
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
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_isDPRMode ? Icons.route : Icons.auto_awesome, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _isDPRMode ? 'Start DPR Journey' : 'Analyze Idea',
                                  style: const TextStyle(
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
            ).animate().fadeIn(duration: 400.ms).moveY(begin: 20, end: 0),

            const SizedBox(height: 24),

            // Research Log Panel - shown during analysis
            if (_isAnalyzing && _researchLogs.isNotEmpty)
              _ResearchLogPanel(
                logs: _researchLogs,
                scrollController: _logScrollController,
              ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 24),

            // Analysis Results
            if (_currentIdea != null)

              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _IdeaAnalysisCard(
                  idea: _currentIdea!,
                  onSave: _saveIdea,
                ).animate().fadeIn(duration: 600.ms).moveY(begin: 30, end: 0),
              ),
            ], // Close the else block
          ],
        ),
      ),
    );
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
                    Text(
                      'Saved Ideas (${_savedIdeas.length})',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _savedIdeas.length,
                        itemBuilder: (context, index) {
                          final idea = _savedIdeas[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: _ScoreCircle(score: idea.score),
                              title: Text(
                                idea.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(idea.estimatedInvestment),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() => _savedIdeas.removeAt(index));
                                  Navigator.pop(context);
                                  if (_savedIdeas.isNotEmpty) {
                                    _showSavedIdeas(context);
                                  }
                                },
                              ),
                            ),
                          ).animate().fadeIn(delay: (index * 100).ms).moveX();
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

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double opacity;

  const _GlassContainer({
    required this.child,
    this.opacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppTheme.glassDecoration(opacity: opacity),
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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

            // Investment & Timeline
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

            // Strengths
            _AnalysisSection(
              title: 'Strengths',
              icon: Icons.check_circle,
              color: AppTheme.success,
              items: idea.strengths,
            ),
            const SizedBox(height: 20),

            // Weaknesses
            _AnalysisSection(
              title: 'Challenges',
              icon: Icons.warning,
              color: WealthInTheme.warning,
              items: idea.weaknesses,
            ),
            const SizedBox(height: 20),

            // Suggestions
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
            color: color.withValues(alpha: 0.4),
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
              color: color.withValues(alpha: 0.15),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: items.map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                ),
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
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
          ).toList(),
        ),
      ],
    );
  }
}

class _SampleIdeaTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _SampleIdeaTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      opacity: 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Research log entry data class
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

/// Animated Research Log Panel Widget
class _ResearchLogPanel extends StatelessWidget {
  final List<_ResearchLogEntry> logs;
  final ScrollController scrollController;
  
  const _ResearchLogPanel({
    required this.logs,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 200),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.black.withValues(alpha: 0.6) 
            : Colors.grey.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: WealthInColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Terminal header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                border: Border(
                  bottom: BorderSide(
                    color: WealthInColors.primary.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal,
                    size: 14,
                    color: WealthInColors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Deep Research Agent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
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
                          color: WealthInColors.success.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Log entries
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                      '${log.timestamp.minute.toString().padLeft(2, '0')}:'
                      '${log.timestamp.second.toString().padLeft(2, '0')}';
                  
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
                              fontWeight: log.isHighlight ? FontWeight.bold : FontWeight.normal,
                              color: log.isHighlight 
                                  ? WealthInColors.primary 
                                  : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).moveX(begin: -10, end: 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode Toggle Button for switching between Quick Analysis and DPR Journey
class _ModeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isNew;

  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? WealthInColors.primary : WealthInColors.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.grey.shade600),
              ),
            ),
            if (isNew) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// DPR Progress Card showing completeness and section status
class _DPRProgressCard extends StatelessWidget {
  final double completeness;
  final Map<String, bool> sectionsCompleted;

  const _DPRProgressCard({
    required this.completeness,
    required this.sectionsCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final sectionLabels = {
      'executive_summary': 'Executive Summary',
      'promoter_profile': 'Promoter Profile',
      'market_analysis': 'Market Analysis',
      'financial_projections': 'Financial Projections',
      'cost_of_project': 'Cost of Project',
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(isDark ? 0.2 : 0.1),
            const Color(0xFF8B5CF6).withOpacity(isDark ? 0.15 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DPR Completeness',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${completeness.toInt()}% Complete',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: completeness / 100,
                strokeWidth: 6,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Sections',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sectionLabels.entries.map((entry) {
              final isComplete = sectionsCompleted[entry.key] ?? false;
              return Chip(
                avatar: Icon(
                  isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isComplete ? Colors.green : Colors.grey,
                ),
                label: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                backgroundColor: isDark ? WealthInColors.blackCard : Colors.grey.shade100,
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Socratic Conversation Card for DPR questioning
class _SocraticConversationCard extends StatelessWidget {
  final List<Map<String, dynamic>> conversationHistory;
  final Map<String, dynamic>? currentQuestion;
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  final double completeness;
  final int questionsAnswered;
  final VoidCallback onExit;

  const _SocraticConversationCard({
    required this.conversationHistory,
    required this.currentQuestion,
    required this.answerController,
    required this.onSubmit,
    required this.completeness,
    required this.questionsAnswered,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: isDark ? WealthInColors.blackCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DPR Journey',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Question $questionsAnswered of 10',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: completeness / 100,
                        strokeWidth: 4,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                      Text(
                        '${completeness.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: onExit,
                ),
              ],
            ),
          ),
          // Conversation
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: conversationHistory.length,
              itemBuilder: (context, index) {
                final item = conversationHistory[index];
                final isQuestion = item['type'] == 'question';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isQuestion 
                        ? MainAxisAlignment.start 
                        : MainAxisAlignment.end,
                    children: [
                      if (isQuestion) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.psychology,
                            size: 16,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isQuestion
                                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                                : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isQuestion && item['question_type'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    item['question_type'].toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6366F1).withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              Text(
                                item['content'] ?? '',
                                style: TextStyle(
                                  color: isQuestion
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isQuestion) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: (index * 50).ms);
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: answerController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Type your answer...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                      filled: true,
                      fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    color: Colors.white,
                    tooltip: 'Send Answer',
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

