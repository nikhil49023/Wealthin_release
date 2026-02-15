import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:open_file/open_file.dart';
import '../../core/services/data_service.dart';
import '../../core/services/gamification_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/wealthin_theme.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart' show authService;
import '../dashboard/widgets/metric_card.dart';
import '../analytics/widgets/health_score_gauge.dart';

/// Analysis Screen - Detailed financial metrics, gamification milestones & insights
/// Contains: Level/XP, Health Score, Metrics, Charts, Milestones, PDF Export
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  DashboardData? _data;
  HealthScore? _healthScore;
  bool _isLoading = true;
  bool _isExporting = false;

  // AI Analysis state
  bool _isAnalyzing = false; // Show AI animation
  bool _hasCachedResults = false;
  String _analysisStatusMessage = 'Loading your financial data...';

  // Animation controller for AI analyzing animation
  late AnimationController _pulseController;

  // Gamification state (powered by GamificationService)
  final GamificationService _gamification = GamificationService.instance;
  List<AchievementState> _achievementStates = [];
  List<AchievementState> _newlyUnlocked = [];
  AchievementCategory? _selectedAchievementCategory;

  // Cooldown state
  bool _canAnalyze = true;
  String? _lastAnalysisDate;
  String? _nextAnalysisDate;
  int _daysRemaining = 0;
  int _hoursRemaining = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _analysisStatusMessage = 'Loading cached analysis...';
    });

    try {
      final userId = authService.currentUserId;

      // Step 0: Initialize gamification engine
      await _gamification.init();

      // Step 1: Quick load - fetch milestones first (has cached analysis data)
      final milestonesData = await _dataService.getMilestones(userId);

      // Extract cached analysis data
      _canAnalyze = milestonesData['can_analyze'] as bool? ?? true;
      _lastAnalysisDate = milestonesData['last_analysis_date'] as String?;
      _nextAnalysisDate = milestonesData['next_analysis_date'] as String?;
      _daysRemaining = (milestonesData['days_remaining'] as num?)?.toInt() ?? 0;
      _hoursRemaining = (milestonesData['hours_remaining'] as num?)?.toInt() ?? 0;

      // Check if we have cached results (previous analysis exists)
      _hasCachedResults = _lastAnalysisDate != null;

      // Step 2: Fetch dashboard and health score
      if (_canAnalyze && !_hasCachedResults) {
        if (mounted) {
          setState(() {
            _isAnalyzing = true;
            _analysisStatusMessage = 'AI is analyzing your finances...';
          });
        }
      }

      // Parallel fetch: dashboard, health score, transactions, budgets, goals
      final results = await Future.wait([
        _dataService.getDashboard(userId),
        _dataService.getHealthScore(userId),
        _dataService.getTransactions(userId),
        _dataService.getBudgets(userId),
        _dataService.getGoals(userId),
      ]);

      final dashData = results[0] as DashboardData?;
      final healthData = results[1] as HealthScore?;
      final transactions = results[2] as List<TransactionModel>? ?? [];
      final budgets = results[3] as List<BudgetModel>? ?? [];
      final goals = results[4] as List<GoalModel>? ?? [];

      // Step 3: Compute gamification stats from real data
      final completedGoals = goals.where((g) => g.status == 'completed').length;
      final userStats = UserStats(
        transactionCount: transactions.length,
        savingsRate: dashData?.savingsRate ?? 0,
        goalsCreated: goals.length,
        goalsCompleted: completedGoals,
        budgetsCreated: budgets.length,
        monthsUnderBudget: _gamification.stats.monthsUnderBudget,
        ideasEvaluated: _gamification.stats.ideasEvaluated,
        dprsCreated: _gamification.stats.dprsCreated,
        currentStreak: _dataService.currentStreak.value,
        healthScore: healthData?.totalScore ?? 0,
        pdfsExported: _gamification.stats.pdfsExported,
        analysesRun: _gamification.stats.analysesRun,
      );

      final newlyUnlocked = await _gamification.updateStats(userStats);
      _achievementStates = _gamification.getAllAchievementStates();

      if (mounted) {
        setState(() {
          _data = dashData;
          _healthScore = healthData;
          _newlyUnlocked = newlyUnlocked;
          _isLoading = false;
          _isAnalyzing = false;
        });
      }

      // Show celebration for newly unlocked achievements
      if (newlyUnlocked.isNotEmpty && mounted) {
        _showAchievementCelebrations(newlyUnlocked);
      }

      // Step 4: Save snapshot in background only if cooldown has passed
      if (_canAnalyze && dashData != null) {
        _saveSnapshotInBackground(userId, dashData, healthData);
      }
    } catch (e) {
      debugPrint('Error loading analysis data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAnalyzing = false;
        });
      }
    }
  }

  /// Show celebration snackbars for newly unlocked achievements
  Future<void> _showAchievementCelebrations(List<AchievementState> achievements) async {
    for (final a in achievements) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(a.definition.tier.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a.definition.name} Unlocked!',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '+${a.definition.xpReward} XP • ${a.definition.tier.label}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Color(a.definition.tier.gradientColors[0]),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Save a snapshot in background to track progress and check milestones
  Future<void> _saveSnapshotInBackground(
    String userId,
    DashboardData? data,
    HealthScore? health,
  ) async {
    if (data == null) return;

    try {
      // Increment analyses_run counter
      await _gamification.incrementStat('analyses_run');

      await _dataService.saveAnalysisSnapshot(
        userId: userId,
        totalIncome: data.totalIncome,
        totalExpense: data.totalExpense,
        savingsRate: data.savingsRate,
        healthScore: health?.totalScore ?? 0,
        categoryBreakdown: data.categoryBreakdown.map(
          (k, v) => MapEntry(k, v.toDouble()),
        ),
        insights: health?.insights ?? [],
        currentStreak: _dataService.currentStreak.value,
      );

      // Refresh achievement states after stat update
      if (mounted) {
        setState(() {
          _achievementStates = _gamification.getAllAchievementStates();
        });
      }
    } catch (e) {
      debugPrint('[Analysis] Snapshot save error (non-critical): $e');
    }
  }

  Future<void> _exportAnalysisAsPDF() async {
    if (_healthScore == null) return;
    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF report with AI analysis...'),
          duration: Duration(seconds: 3),
        ),
      );

      // Get category breakdown for the report
      Map<String, double>? categoryBreakdown;
      try {
        final userId = authService.currentUserId;
        final transactions = await _dataService.getTransactions(userId);
        if (transactions.isNotEmpty) {
          categoryBreakdown = <String, double>{};
          for (final tx in transactions) {
            if (tx.isExpense) {
              categoryBreakdown[tx.category] =
                  (categoryBreakdown[tx.category] ?? 0) + tx.amount;
            }
          }
        }
      } catch (e) {
        debugPrint('[Analysis] Category breakdown error (non-critical): $e');
      }

      final filePath = await pdfReportService.generateHealthReport(
        healthScore: _healthScore!,
        dashboardData: _data,
        userName:
            authService.currentUser?.displayName ?? 'User',
        categoryBreakdown: categoryBreakdown,
      );
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('\u2705 Report generated! Opening...'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenFile.open(filePath),
            ),
          ),
        );
        // Auto-open the PDF
        await OpenFile.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Color _getHealthScoreColor(double score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFCDDC39);
    if (score >= 40) return const Color(0xFFFFC107);
    if (score >= 20) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getHealthScoreLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Needs Work';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final padding = ResponsiveUtils.getResponsivePadding(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExporting ? null : _exportAnalysisAsPDF,
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(_isExporting ? 'Exporting...' : 'Export PDF'),
        backgroundColor: theme.colorScheme.primary,
      ).animate().scale(delay: 500.ms),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Glass header
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: isDark
                  ? theme.scaffoldBackgroundColor
                  : theme.colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [WealthInColors.vaultGreen, WealthInColors.blackElevated]
                          : [WealthInColors.primary, WealthInTheme.emeraldDark],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 15, padding, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Financial Analysis',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your detailed financial health overview',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: EdgeInsets.all(padding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // AI Analyzing Animation (shown during first analysis)
                  if (_isAnalyzing || (_isLoading && !_hasCachedResults))
                    _buildAIAnalyzingCard(theme, isDark)
                        .animate()
                        .fadeIn()
                        .scale(begin: const Offset(0.95, 0.95)),
                  if (_isAnalyzing || (_isLoading && !_hasCachedResults))
                    const SizedBox(height: 16),

                  // Level & XP Card (Gamification)
                  _buildLevelCard(
                    theme,
                    isDark,
                  ).animate().fadeIn().slideY(begin: -0.1),
                  const SizedBox(height: 16),

                  // Analysis Streak Timeline Bar (shows next analysis date)
                  _buildAnalysisStreakBar(
                    theme,
                    isDark,
                  ).animate().fadeIn().slideY(begin: -0.05),
                  const SizedBox(height: 16),

                  // Analysis Cooldown Card
                  if (!_canAnalyze)
                    _buildCooldownCard(
                      theme,
                      isDark,
                    ).animate().fadeIn().slideY(begin: -0.1),
                  if (!_canAnalyze) const SizedBox(height: 16),

                  // Financial Health Score
                  _buildHealthScoreCard(
                    theme,
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 20),

                  // Key Metrics Grid
                  _buildMetricsGrid(theme).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 20),

                  // Achievements Section (Levels + Tiered Badges)
                  _buildAchievementsSection(
                    theme,
                    isDark,
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 20),

                  // Simple Category Summary (replaces complex charts)
                  _buildSimpleCategorySummary(theme, isDark)
                      .animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 20),

                  // Per Capita Insights
                  _buildInsightsCard(theme).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== AI ANALYZING ANIMATION ====================

  /// Beautiful AI analyzing animation card
  Widget _buildAIAnalyzingCard(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Color.lerp(const Color(0xFF1A2F1A), const Color(0xFF0D3B0D),
                          _pulseController.value)!,
                      Color.lerp(const Color(0xFF0D3B0D), const Color(0xFF1A2F1A),
                          _pulseController.value)!,
                    ]
                  : [
                      Color.lerp(const Color(0xFFE8F5E9), const Color(0xFFC8E6C9),
                          _pulseController.value)!,
                      Color.lerp(const Color(0xFFC8E6C9), const Color(0xFFE8F5E9),
                          _pulseController.value)!,
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF4CAF50).withValues(alpha: 0.3),
                const Color(0xFF66BB6A).withValues(alpha: 0.5),
                _pulseController.value,
              )!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  const Color(0xFF4CAF50).withValues(alpha: 0.25),
                  _pulseController.value,
                )!,
                blurRadius: 20 + (_pulseController.value * 10),
                spreadRadius: _pulseController.value * 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated AI Icon
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.2),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4CAF50)
                              .withValues(alpha: 0.3 - (_pulseController.value * 0.2)),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  // Inner circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF4CAF50),
                          Color.lerp(const Color(0xFF388E3C),
                              const Color(0xFF2E7D32), _pulseController.value)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50)
                              .withValues(alpha: 0.3 + (_pulseController.value * 0.2)),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Status text
              Text(
                _analysisStatusMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1B5E20),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Progress indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final delay = index * 0.3;
                  final animValue = ((_pulseController.value + delay) % 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        const Color(0xFF4CAF50),
                        animValue,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Analyzing spending patterns, calculating health score...',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== GAMIFICATION WIDGETS (PREMIUM) ====================

  /// Premium Level & XP card with circular progress ring and named level
  Widget _buildLevelCard(ThemeData theme, bool isDark) {
    final level = _gamification.currentLevel;
    final progress = getLevelProgress(_gamification.totalXP);
    final totalXP = _gamification.totalXP;
    final achievedCount = _gamification.achievedCount;
    final totalAchievements = _gamification.totalCount;

    final Color gradStart = Color(level.gradientColors[0]);
    final Color gradEnd = Color(level.gradientColors[1]);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F1123), const Color(0xFF1A1A3E)]
              : [Colors.white, const Color(0xFFF5F7FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: gradStart.withOpacity(isDark ? 0.4 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradStart.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress ring with level number
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background ring
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 6,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(
                          isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                        ),
                      ),
                    ),
                    // Progress ring
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: progress.progress,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(gradStart),
                      ),
                    ),
                    // Level badge center
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [gradStart, gradEnd],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: gradStart.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          level.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level title + number
                    Row(
                      children: [
                        Text(
                          level.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [gradStart, gradEnd]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Lv.${level.level}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // XP display
                    Row(
                      children: [
                        Icon(Icons.bolt, size: 16, color: gradStart),
                        const SizedBox(width: 4),
                        Text(
                          '$totalXP XP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: gradStart,
                          ),
                        ),
                        if (progress.nextLevel != null) ...[
                          Text(
                            '  •  ${progress.xpForNext - progress.xpInLevel} to ${progress.nextLevel!.title}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Gradient XP Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress.progress,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [gradStart, gradEnd]),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradStart.withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Achievements counter
                    Text(
                      '$achievedCount of $totalAchievements achievements unlocked',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Level progression dots
          const SizedBox(height: 20),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allLevels.length,
              itemBuilder: (context, index) {
                final lvl = allLevels[index];
                final isReached = _gamification.totalXP >= lvl.xpRequired;
                final isCurrent = lvl.level == level.level;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isCurrent ? 28 : 22,
                        height: isCurrent ? 28 : 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isReached
                              ? LinearGradient(colors: [Color(lvl.gradientColors[0]), Color(lvl.gradientColors[1])])
                              : null,
                          color: isReached ? null : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                          border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                          boxShadow: isCurrent
                              ? [BoxShadow(color: Color(lvl.gradientColors[0]).withOpacity(0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            isReached ? lvl.emoji : '${lvl.level}',
                            style: TextStyle(
                              fontSize: isCurrent ? 14 : 10,
                              color: isReached ? null : (isDark ? Colors.white24 : Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Analysis Streak Timeline Bar — minimalistic design
  Widget _buildAnalysisStreakBar(ThemeData theme, bool isDark) {
    // Calculate progress through the 7-day cycle
    double progress = 0.0;
    if (_lastAnalysisDate != null && _nextAnalysisDate != null) {
      try {
        final lastDate = DateTime.parse(_lastAnalysisDate!);
        final nextDate = DateTime.parse(_nextAnalysisDate!);
        final now = DateTime.now();

        final totalDuration = nextDate.difference(lastDate).inHours;
        final elapsed = now.difference(lastDate).inHours;

        if (totalDuration > 0) {
          progress = (elapsed / totalDuration).clamp(0.0, 1.0);
        }
      } catch (e) {
        debugPrint('[Analysis] Error calculating streak progress: $e');
      }
    }

    // Format next analysis date for display
    String nextDateDisplay = 'Not scheduled';
    if (_nextAnalysisDate != null) {
      try {
        final nextDate = DateTime.parse(_nextAnalysisDate!);
        nextDateDisplay = '${nextDate.day}/${nextDate.month}';
      } catch (e) {
        nextDateDisplay = '—';
      }
    }

    final accentColor = _canAnalyze ? const Color(0xFF4CAF50) : const Color(0xFFFF9800);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Top row: icon + label + status badge
          Row(
            children: [
              Icon(
                _canAnalyze ? Icons.check_circle_outline : Icons.schedule,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _canAnalyze ? 'Analysis ready' : 'Next analysis in ${_daysRemaining}d ${_hoursRemaining}h',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                  ),
                ),
              ),
              // Compact date badges
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_lastAnalysisDate != null)
                    Text(
                      _formatAnalysisDate(_lastAnalysisDate!),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 10,
                      color: isDark ? Colors.white24 : Colors.black26),
                  ),
                  Text(
                    nextDateDisplay,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Slim progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.7),
                          accentColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _canAnalyze
            ? const Color(0xFF4CAF50).withOpacity(0.2)
            : const Color(0xFFFF9800).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _canAnalyze ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: _canAnalyze
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF9800),
          ),
          const SizedBox(width: 4),
          Text(
            _canAnalyze ? 'Ready' : '${_daysRemaining}d ${_hoursRemaining}h',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _canAnalyze
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
            ),
          ),
        ],
      ),
    );
  }

  /// Analysis cooldown card - shown when 7-day cooldown is active
  Widget _buildCooldownCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2E1A1E), const Color(0xFF3E2123)]
              : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFF9800).withOpacity(0.3)
              : const Color(0xFFFF9800).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFFFF9800),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Cooldown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next analysis available in $_daysRemaining days, $_hoursRemaining hours',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFFFF9800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analysis runs automatically after transaction imports and has a 7-day cooldown to track meaningful financial changes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_lastAnalysisDate != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last analysis: ${_formatAnalysisDate(_lastAnalysisDate!)}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAnalysisDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  /// Milestones grid section
  /// Premium Achievements Section with category filters, tiered badges, and progress
  Widget _buildAchievementsSection(ThemeData theme, bool isDark) {
    final achievedCount = _gamification.achievedCount;
    final totalCount = _gamification.totalCount;

    // Filter achievements by selected category
    List<AchievementState> displayList;
    if (_selectedAchievementCategory != null) {
      displayList = _achievementStates
          .where((a) => a.definition.category == _selectedAchievementCategory)
          .toList();
    } else {
      displayList = _achievementStates;
    }

    // Sort: achieved first, then by tier (platinum first), then by progress
    displayList.sort((a, b) {
      if (a.achieved != b.achieved) return a.achieved ? -1 : 1;
      if (a.definition.tier != b.definition.tier) {
        return b.definition.tier.sortOrder.compareTo(a.definition.tier.sortOrder);
      }
      return b.progress.compareTo(a.progress);
    });

    // Show max 6 in grid, rest in "View All"
    final gridItems = displayList.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '$achievedCount of $totalCount unlocked',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              // Achievement progress ring
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: totalCount > 0 ? achievedCount / totalCount : 0,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                    ),
                    Text(
                      '${((achievedCount / max(totalCount, 1)) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Category filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip(null, 'All', isDark),
                ...AchievementCategory.values.map(
                  (cat) => _buildCategoryChip(cat, '${cat.emoji} ${cat.label}', isDark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Achievement grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: gridItems.length,
            itemBuilder: (context, index) {
              return _buildAchievementCard(gridItems[index], isDark);
            },
          ),

          if (displayList.length > 6) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => _showAllAchievements(context, isDark),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text(
                  'View all ${displayList.length} achievements',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Category filter chip
  Widget _buildCategoryChip(AchievementCategory? category, String label, bool isDark) {
    final isSelected = _selectedAchievementCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
        backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
        selectedColor: const Color(0xFFFF8F00),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (_) {
          setState(() {
            _selectedAchievementCategory = isSelected ? null : category;
          });
        },
      ),
    );
  }

  /// Single achievement card with tier gradient border and progress
  Widget _buildAchievementCard(AchievementState achievement, bool isDark) {
    final def = achievement.definition;
    final tier = def.tier;
    final achieved = achievement.achieved;
    final progress = achievement.progress;

    final Color tierColor1 = Color(tier.gradientColors[0]);
    final Color tierColor2 = Color(tier.gradientColors[1]);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: achieved
            ? (isDark ? tierColor1.withOpacity(0.12) : tierColor1.withOpacity(0.06))
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: achieved ? tierColor1.withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
          width: achieved ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Tier badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: achieved
                      ? LinearGradient(colors: [tierColor1, tierColor2])
                      : null,
                  color: achieved ? null : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    achieved ? tier.emoji : def.category.emoji,
                    style: TextStyle(fontSize: achieved ? 14 : 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  def.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: achieved
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Description
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              def.description,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Progress bar + XP
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(
                      achieved ? tierColor1 : (isDark ? Colors.white24 : Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                achieved ? '✓' : '+${def.xpReward}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: achieved ? tierColor1 : (isDark ? Colors.white30 : Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show all achievements in a bottom sheet grouped by category
  void _showAllAchievements(BuildContext context, bool isDark) {
    final byCategory = _gamification.getAchievementsByCategory();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'All Achievements',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_gamification.achievedCount}/${_gamification.totalCount}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        ...byCategory.entries.map((entry) {
                        final category = entry.key;
                        final achievements = entry.value;
                        final catAchieved = achievements.where((a) => a.achieved).length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category header
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    '${category.emoji} ${category.label}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$catAchieved/${achievements.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white30 : Colors.black26,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Achievement list
                            ...achievements.map((a) {
                              final tierColor = Color(a.definition.tier.gradientColors[0]);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: a.achieved
                                        ? tierColor.withOpacity(isDark ? 0.1 : 0.05)
                                        : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: a.achieved
                                          ? tierColor.withOpacity(0.4)
                                          : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Tier badge
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: a.achieved
                                              ? LinearGradient(colors: [
                                                  Color(a.definition.tier.gradientColors[0]),
                                                  Color(a.definition.tier.gradientColors[1]),
                                                ])
                                              : null,
                                          color: a.achieved
                                              ? null
                                              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
                                        ),
                                        child: Center(
                                          child: Text(
                                            a.achieved ? a.definition.tier.emoji : a.definition.category.emoji,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    a.definition.name,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: a.achieved
                                                          ? (isDark ? Colors.white : Colors.black87)
                                                          : (isDark ? Colors.white54 : Colors.black45),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: tierColor.withOpacity(isDark ? 0.2 : 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    a.definition.tier.label,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                      color: tierColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              a.definition.description,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white30 : Colors.black38,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // Progress bar
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: a.progress,
                                                minHeight: 4,
                                                backgroundColor: isDark
                                                    ? Colors.white.withOpacity(0.06)
                                                    : Colors.black.withOpacity(0.04),
                                                valueColor: AlwaysStoppedAnimation(
                                                  a.achieved ? tierColor : (isDark ? Colors.white24 : Colors.grey),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // XP reward
                                      Column(
                                        children: [
                                          Text(
                                            a.achieved ? '✓' : '+${a.definition.xpReward}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: a.achieved ? tierColor : (isDark ? Colors.white24 : Colors.grey),
                                            ),
                                          ),
                                          if (!a.achieved)
                                            Text(
                                              'XP',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade400,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== EXISTING WIDGETS (REFRESHED) ====================

  Widget _buildHealthScoreCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    double score = _healthScore?.totalScore ?? 0;
    if (score.isNaN) score = 0;
    final scoreColor = _getHealthScoreColor(score);
    final scoreLabel = _getHealthScoreLabel(score);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.health_and_safety, color: scoreColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Financial Health',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Colors.blue),
                onPressed: _exportAnalysisAsPDF,
                tooltip: 'Export Report',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Gauge Widget
          HealthScoreGauge(score: score, size: 180),

          const SizedBox(height: 12),
          Text(
            scoreLabel,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),

          const SizedBox(height: 24),

          // Clean Pass/Fail Checklist
          if (_healthScore != null)
            Column(
              children: [
                _buildScoreCheckItem(
                  'Savings Rate',
                  _healthScore!.breakdown['savings'] ?? 0,
                  30,
                  Icons.savings_outlined,
                  isDark,
                  'Save 20%+ of income',
                ),
                const SizedBox(height: 8),
                _buildScoreCheckItem(
                  'Debt Management',
                  _healthScore!.breakdown['debt'] ?? 0,
                  25,
                  Icons.account_balance_wallet_outlined,
                  isDark,
                  'Keep debt below 35% of income',
                ),
                const SizedBox(height: 8),
                _buildScoreCheckItem(
                  'Emergency Fund',
                  _healthScore!.breakdown['liquidity'] ?? 0,
                  25,
                  Icons.shield_outlined,
                  isDark,
                  '6 months expenses saved',
                ),
                const SizedBox(height: 8),
                _buildScoreCheckItem(
                  'Goal Progress',
                  _healthScore!.breakdown['investment'] ?? 0,
                  20,
                  Icons.flag_outlined,
                  isDark,
                  'On track with savings goals',
                ),
              ],
            ),

          if (_healthScore?.insights.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            ..._healthScore!.insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCheckItem(
    String label,
    double score,
    double maxScore,
    IconData icon,
    bool isDark,
    String tip,
  ) {
    if (score.isNaN) score = 0;
    final progress = (score / maxScore).clamp(0.0, 1.0);
    final passed = progress >= 0.5;
    final statusColor = passed
        ? const Color(0xFF10B981)
        : (progress >= 0.25 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              passed ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Label and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      passed ? 'Passed' : 'Needs Work',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    color: statusColor,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tip,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    Text(
                      '${score.toStringAsFixed(0)}/${maxScore.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme) {
    final isCompact = MediaQuery.of(context).size.width < 420;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (isCompact) ...[
          IncomeCard(
            amount: _data?.totalIncome ?? 0,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 12),
          ExpenseCard(
            amount: _data?.totalExpense ?? 0,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 12),
          SavingsCard(
            amount: (_data?.totalIncome ?? 0) - (_data?.totalExpense ?? 0),
            isLoading: _isLoading,
          ),
          const SizedBox(height: 12),
          SavingsRateCard(
            savingsRate: (_data?.savingsRate ?? 0).round(),
            isLoading: _isLoading,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: IncomeCard(
                  amount: _data?.totalIncome ?? 0,
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExpenseCard(
                  amount: _data?.totalExpense ?? 0,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SavingsCard(
                  amount: (_data?.totalIncome ?? 0) - (_data?.totalExpense ?? 0),
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SavingsRateCard(
                  savingsRate: (_data?.savingsRate ?? 0).round(),
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Simple category summary - replaces complex charts with clean readable list
  Widget _buildSimpleCategorySummary(ThemeData theme, bool isDark) {
    final categories = _data?.categoryBreakdown ?? {};
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort categories by amount descending
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (sum, e) => sum + e.value);

    final colors = [
      const Color(0xFFFF6384),
      const Color(0xFF36A2EB),
      const Color(0xFFFFCE56),
      const Color(0xFF4BC0C0),
      const Color(0xFF9966FF),
      const Color(0xFFFF9F40),
      const Color(0xFF7CB342),
      const Color(0xFFEC407A),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                color: const Color(0xFF667eea),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Spending Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Where your money goes',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 20),
          ...sorted.take(8).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final percentage = total > 0
                ? (category.value / total * 100).toStringAsFixed(1)
                : '0';
            final barWidth = total > 0
                ? (category.value / total).clamp(0.0, 1.0)
                : 0.0;
            final color = colors[index % colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.key,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '₹${_formatAmount(category.value.toDouble())}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (sorted.length > 8)
            Text(
              '+${sorted.length - 8} more categories',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    final monthlyIncome = _data?.totalIncome ?? 0;
    final monthlyExpenses = _data?.totalExpense ?? 0;
    final dailySpending = monthlyExpenses / 30;
    final perMealBudget = dailySpending / 3;
    final emergencyFundGoal = monthlyExpenses * 6;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights,
                color: const Color(0xFF667eea),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Per Capita Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildInsightRow(
            'Daily Spending',
            '₹${dailySpending.toStringAsFixed(0)}',
            Icons.today,
            const Color(0xFF4CAF50),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Per Meal Budget',
            '₹${perMealBudget.toStringAsFixed(0)}',
            Icons.restaurant,
            const Color(0xFFFF9800),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Emergency Fund Goal',
            '₹${_formatAmount(emergencyFundGoal)}',
            Icons.shield,
            const Color(0xFF2196F3),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Investment Capacity',
            '₹${_formatAmount((monthlyIncome - monthlyExpenses).clamp(0, double.infinity))}',
            Icons.trending_up,
            const Color(0xFF9C27B0),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
