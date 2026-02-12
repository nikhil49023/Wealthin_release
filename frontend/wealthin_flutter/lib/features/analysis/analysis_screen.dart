import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/data_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/models/models.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart' show authService;
import '../dashboard/widgets/cashflow_card.dart';
import '../dashboard/widgets/trend_analysis_card.dart';
import '../dashboard/widgets/category_breakdown_card.dart';
import '../dashboard/widgets/financial_overview_card.dart';
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

  // Gamification state
  int _userLevel = 1;
  int _totalXP = 0;
  int _xpToNextLevel = 100;
  int _milestonesAchieved = 0;
  int _totalMilestones = 14;
  List<Map<String, dynamic>> _milestones = [];
  List<Map<String, dynamic>> _newlyAchieved = [];

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
    setState(() {
      _isLoading = true;
      _analysisStatusMessage = 'Loading cached analysis...';
    });

    try {
      final userId = authService.currentUserId;

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

      if (mounted) {
        setState(() {
          _userLevel = (milestonesData['level'] as num?)?.toInt() ?? 1;
          _totalXP = (milestonesData['total_xp'] as num?)?.toInt() ?? 0;
          _xpToNextLevel = (milestonesData['xp_to_next_level'] as num?)?.toInt() ?? 100;
          _milestonesAchieved = (milestonesData['milestones_achieved'] as num?)?.toInt() ?? 0;
          _totalMilestones = (milestonesData['total_milestones'] as num?)?.toInt() ?? 14;
          _milestones = List<Map<String, dynamic>>.from(milestonesData['milestones'] ?? []);
        });
      }

      // Step 2: Fetch dashboard and health score
      if (_canAnalyze && !_hasCachedResults) {
        // First analysis - show AI analyzing animation
        if (mounted) {
          setState(() {
            _isAnalyzing = true;
            _analysisStatusMessage = 'AI is analyzing your finances...';
          });
        }
      }

      // Parallel fetch: dashboard and health score
      final results = await Future.wait([
        _dataService.getDashboard(userId),
        _dataService.getHealthScore(userId),
      ]);

      final dashData = results[0] as DashboardData?;
      final healthData = results[1] as HealthScore?;

      if (mounted) {
        setState(() {
          _data = dashData;
          _healthScore = healthData;
          _isLoading = false;
          _isAnalyzing = false;
        });
      }

      // Step 3: Save snapshot in background only if cooldown has passed
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

  /// Save a snapshot in background to track progress and check milestones
  Future<void> _saveSnapshotInBackground(
    String userId,
    DashboardData? data,
    HealthScore? health,
  ) async {
    if (data == null) return;

    try {
      final result = await _dataService.saveAnalysisSnapshot(
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

      final newMilestones = List<Map<String, dynamic>>.from(
        result['newly_achieved_milestones'] ?? [],
      );
      if (newMilestones.isNotEmpty && mounted) {
        setState(() {
          _newlyAchieved = newMilestones;
          _userLevel = (result['user_level'] as num?)?.toInt() ?? _userLevel;
          _totalXP = (result['total_xp'] as num?)?.toInt() ?? _totalXP;
        });
        // Show celebration for new milestones
        for (final m in newMilestones) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('🎉 ', style: TextStyle(fontSize: 20)),
                    Expanded(
                      child: Text(
                        '${m['name']} unlocked! +${m['xp_reward']} XP',
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
    } catch (e) {
      debugPrint('[Analysis] Snapshot save error (non-critical): $e');
    }
  }

  Future<void> _exportAnalysisAsPDF() async {
    if (_healthScore == null) return;
    setState(() => _isExporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF report...'),
          duration: Duration(seconds: 2),
        ),
      );
      final filePath = await pdfReportService.generateHealthReport(
        healthScore: _healthScore!,
        dashboardData: _data,
        userName:
            authService.currentUser?.userMetadata?['display_name'] as String? ??
            'User',
      );
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved: $filePath'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => launchUrl(Uri.file(filePath)),
            ),
          ),
        );
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
        backgroundColor: const Color(0xFF046307),
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
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF0D1F14), const Color(0xFF132B1C)]
                          : [const Color(0xFF046307), const Color(0xFF2E8B57)],
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

                  // Milestones Section
                  _buildMilestonesSection(
                    theme,
                    isDark,
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 20),

                  // Cashflow Chart
                  CashflowCard(
                    data: _data,
                    isLoading: _isLoading,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 20),

                  // Trend Analysis
                  const TrendAnalysisCard().animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 20),

                  // Category Breakdown
                  CategoryBreakdownCard(
                    categoryBreakdown: _data?.categoryBreakdown ?? {},
                    isLoading: _isLoading,
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 20),

                  // Per Capita Insights
                  _buildInsightsCard(theme).animate().fadeIn(delay: 350.ms),
                  const SizedBox(height: 20),

                  // Financial Overview
                  const FinancialOverviewCard().animate().fadeIn(delay: 400.ms),
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
                const Color(0xFF4CAF50).withOpacity(0.3),
                const Color(0xFF66BB6A).withOpacity(0.5),
                _pulseController.value,
              )!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  const Color(0xFF4CAF50).withOpacity(0.1),
                  const Color(0xFF4CAF50).withOpacity(0.25),
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
                              .withOpacity(0.3 - (_pulseController.value * 0.2)),
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
                              .withOpacity(0.3 + (_pulseController.value * 0.2)),
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
                        const Color(0xFF4CAF50).withOpacity(0.3),
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

  // ==================== GAMIFICATION WIDGETS ====================

  /// Level & XP progress card at the top
  Widget _buildLevelCard(ThemeData theme, bool isDark) {
    final xpProgress = _xpToNextLevel > 0
        ? ((_totalXP % _xpToNextLevel) / _xpToNextLevel).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2196F3).withOpacity(0.3)
              : const Color(0xFF2196F3).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_userLevel',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Level $_userLevel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_totalXP XP',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // XP Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_milestonesAchieved of $_totalMilestones milestones achieved',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Analysis Streak Timeline Bar - visualizes analysis schedule with next date marker
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
        nextDateDisplay = '${nextDate.day}/${nextDate.month}/${nextDate.year}';
      } catch (e) {
        nextDateDisplay = 'Unknown';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2C1E), const Color(0xFF1E3A24)]
              : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : const Color(0xFF4CAF50).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.timeline,
                          color: Color(0xFF4CAF50),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analysis Timeline',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '7-Day Analysis Cycle',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 8),
                        _buildAnalysisStatusBadge(),
                      ],
                    ],
                  ),
                  if (isCompact) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildAnalysisStatusBadge(),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Visual timeline bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Analysis',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lastAnalysisDate != null
                            ? _formatAnalysisDate(_lastAnalysisDate!)
                            : 'Not yet',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Next Analysis',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextDateDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar with marker
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxLeft = (constraints.maxWidth - 20)
                      .clamp(0.0, double.infinity)
                      .toDouble();
                  final markerLeft = ((constraints.maxWidth * progress) - 10)
                      .clamp(0.0, maxLeft)
                      .toDouble();

                  return Stack(
                    children: [
                      // Background track
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),

                      // Filled progress
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4CAF50),
                                const Color(0xFF66BB6A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Next analysis date marker (at 100%)
                      Positioned(
                        right: 0,
                        top: -4,
                        child: Column(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _canAnalyze
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFF9800),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_canAnalyze
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFFFF9800))
                                        .withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _canAnalyze ? Icons.check : Icons.flag,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Current position marker (moving)
                      if (!_canAnalyze)
                        Positioned(
                          left: markerLeft,
                          top: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2196F3),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.circle,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // Day markers (0, 1, 2, 3, 4, 5, 6, 7)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(8, (index) {
                  return Text(
                    'D$index',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info text
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
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _canAnalyze
                        ? 'Analysis ready! Import transactions to trigger automatic analysis.'
                        : 'Analysis cooldown active. Tracking meaningful financial changes over 7 days.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
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
  Widget _buildMilestonesSection(ThemeData theme, bool isDark) {
    // Default milestones if none loaded from backend
    final milestoneData = _milestones.isNotEmpty
        ? _milestones
        : _getDefaultMilestones();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFFFC107),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Milestones',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_milestonesAchieved / $_totalMilestones',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFC107),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: milestoneData.length > 9
                ? 9
                : milestoneData.length, // Show first 9
            itemBuilder: (context, index) {
              final m = milestoneData[index];
              final achieved = m['achieved'] == true;
              final name = m['name'] ?? 'Milestone';
              final xp = m['xp_reward'] ?? 0;
              final icon = _getMilestoneIcon(name);

              return Container(
                decoration: BoxDecoration(
                  color: achieved
                      ? (isDark
                            ? const Color(0xFF1B5E20).withOpacity(0.3)
                            : const Color(0xFFE8F5E9))
                      : (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(14),
                  border: achieved
                      ? Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.4),
                        )
                      : Border.all(color: Colors.transparent),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 28,
                      color: achieved
                          ? const Color(0xFF4CAF50)
                          : (isDark ? Colors.white24 : Colors.grey.shade400),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: achieved
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white38 : Colors.grey),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achieved ? '✓ +$xp XP' : '$xp XP',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: achieved
                            ? const Color(0xFF4CAF50)
                            : (isDark ? Colors.white24 : Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (milestoneData.length > 9) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () =>
                    _showAllMilestones(context, milestoneData, isDark),
                child: Text(
                  'View all $_totalMilestones milestones',
                  style: const TextStyle(color: Color(0xFF2196F3)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllMilestones(
    BuildContext context,
    List<Map<String, dynamic>> milestones,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All Milestones',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: milestones.length,
                      itemBuilder: (context, index) {
                        final m = milestones[index];
                        final achieved = m['achieved'] == true;
                        return ListTile(
                          leading: Icon(
                            _getMilestoneIcon(m['name'] ?? ''),
                            color: achieved
                                ? const Color(0xFF4CAF50)
                                : Colors.grey,
                          ),
                          title: Text(
                            m['name'] ?? 'Milestone',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: achieved ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(m['description'] ?? ''),
                          trailing: Text(
                            achieved
                                ? '✓ +${m['xp_reward']} XP'
                                : '${m['xp_reward']} XP',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: achieved
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                            ),
                          ),
                        );
                      },
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

  IconData _getMilestoneIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('first') || lower.contains('step')) return Icons.flag;
    if (lower.contains('budget')) return Icons.account_balance_wallet;
    if (lower.contains('saver') || lower.contains('saving')) {
      return Icons.savings;
    }
    if (lower.contains('champion')) return Icons.emoji_events;
    if (lower.contains('debt')) return Icons.money_off;
    if (lower.contains('guardian')) return Icons.shield;
    if (lower.contains('liquidity')) return Icons.water_drop;
    if (lower.contains('invest')) return Icons.trending_up;
    if (lower.contains('analyst')) return Icons.analytics;
    if (lower.contains('streak')) return Icons.local_fire_department;
    if (lower.contains('goal') && lower.contains('set')) {
      return Icons.track_changes;
    }
    if (lower.contains('goal') && lower.contains('achiev')) {
      return Icons.check_circle;
    }
    if (lower.contains('idea') || lower.contains('innovat')) {
      return Icons.lightbulb;
    }
    if (lower.contains('dpr')) return Icons.description;
    return Icons.star;
  }

  List<Map<String, dynamic>> _getDefaultMilestones() {
    return [
      {
        'name': 'First Step',
        'xp_reward': 10,
        'achieved': false,
        'description': 'Track your first ₹5,000 in spending',
      },
      {
        'name': 'Budget Master',
        'xp_reward': 50,
        'achieved': false,
        'description': 'Set up budgets for all categories',
      },
      {
        'name': 'Saver Initiate',
        'xp_reward': 25,
        'achieved': false,
        'description': 'Achieve 10% savings rate',
      },
      {
        'name': 'Savings Champion',
        'xp_reward': 100,
        'achieved': false,
        'description': 'Sustain 30% savings rate',
      },
      {
        'name': 'Debt Manager',
        'xp_reward': 75,
        'achieved': false,
        'description': 'Reduce debt below ₹5 Lakhs',
      },
      {
        'name': 'Financial Guardian',
        'xp_reward': 150,
        'achieved': false,
        'description': 'Become completely debt-free',
      },
      {
        'name': 'Liquidity Expert',
        'xp_reward': 100,
        'achieved': false,
        'description': 'Build 6 months emergency fund',
      },
      {
        'name': 'Investor',
        'xp_reward': 75,
        'achieved': false,
        'description': 'Invest ₹1 Lakh',
      },
      {
        'name': 'Analyst',
        'xp_reward': 50,
        'achieved': false,
        'description': 'Analyze 50+ transactions',
      },
      {
        'name': 'Streak Master',
        'xp_reward': 60,
        'achieved': false,
        'description': '30-day daily tracking streak',
      },
      {
        'name': 'Goal Setter',
        'xp_reward': 40,
        'achieved': false,
        'description': 'Create 3+ financial goals',
      },
      {
        'name': 'Goal Achiever',
        'xp_reward': 80,
        'achieved': false,
        'description': 'Complete your first goal',
      },
      {
        'name': 'Idea Innovator',
        'xp_reward': 45,
        'achieved': false,
        'description': 'Evaluate 3 business ideas',
      },
      {
        'name': 'DPR Champion',
        'xp_reward': 120,
        'achieved': false,
        'description': 'Create your first DPR',
      },
    ];
  }

  // ==================== EXISTING WIDGETS (REFRESHED) ====================

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

          // Breakdown Grid
          if (_healthScore != null)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildScoreFactor(
                  'Savings (30%)',
                  _healthScore!.breakdown['savings'] ?? 0,
                  30,
                  Icons.savings,
                  const Color(0xFF4CAF50),
                  isDark,
                ),
                _buildScoreFactor(
                  'Debt (30%)',
                  _healthScore!.breakdown['debt'] ?? 0,
                  30,
                  Icons.account_balance_wallet,
                  const Color(0xFFF44336),
                  isDark,
                ),
                _buildScoreFactor(
                  'Liquidity (20%)',
                  _healthScore!.breakdown['liquidity'] ?? 0,
                  20,
                  Icons.water_drop,
                  const Color(0xFF2196F3),
                  isDark,
                ),
                _buildScoreFactor(
                  'Invest (20%)',
                  _healthScore!.breakdown['investment'] ?? 0,
                  20,
                  Icons.trending_up,
                  const Color(0xFF9C27B0),
                  isDark,
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
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
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

  Widget _buildScoreFactor(
    String label,
    double score,
    double maxScore,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    if (score.isNaN) score = 0;
    // Determine progress bar value
    double progress = (score / maxScore).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 4),
          Text(
            '${score.toStringAsFixed(1)} / $maxScore pts',
            style: TextStyle(fontSize: 10, color: color),
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
          const SizedBox(height: 12),
          _buildInsightRow(
            'Per Meal Budget',
            '₹${perMealBudget.toStringAsFixed(0)}',
            Icons.restaurant,
            const Color(0xFFFF9800),
            isDark,
          ),
          const SizedBox(height: 12),
          _buildInsightRow(
            'Emergency Fund Goal',
            '₹${_formatAmount(emergencyFundGoal)}',
            Icons.shield,
            const Color(0xFF2196F3),
            isDark,
          ),
          const SizedBox(height: 12),
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
