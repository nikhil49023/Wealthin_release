import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../core/models/models.dart';
import '../../core/services/data_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../main.dart' show authService;
import 'widgets/health_score_gauge.dart';

class FinancialHealthScreen extends StatefulWidget {
  const FinancialHealthScreen({super.key});

  @override
  State<FinancialHealthScreen> createState() => _FinancialHealthScreenState();
}

class _FinancialHealthScreenState extends State<FinancialHealthScreen> {
  final DataService _dataService = DataService();

  bool _isLoading = true;
  HealthScore? _healthScore;

  @override
  void initState() {
    super.initState();
    _fetchScore();
  }

  Future<void> _fetchScore() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = authService.currentUserId;
      final score = await _dataService.getHealthScore(userId);
      if (mounted) {
        setState(() {
          _healthScore = score;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching health score: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = isDark ? AppTheme.richNavy : AppTheme.lightSurface;
    final cardColor = isDark ? AppTheme.deepSlate : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.pearlWhite : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.silverMist : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: const Text('Financial Health Analysis'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.peacockTeal),
            )
          : _healthScore == null
          ? Center(
              child: Text(
                'Could not fetch analysis',
                style: TextStyle(color: textPrimary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.lg),
              child: Column(
                children: [
                  // Gauge Section
                  Container(
                    padding: DesignTokens.cardPaddingLarge,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: DesignTokens.brLg,
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : AppTheme.lightBorder.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      children: [
                        HealthScoreGauge(score: _healthScore!.totalScore),
                        const SizedBox(height: DesignTokens.lg),
                        Text(
                          _healthScore!.grade,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _getGradeColor(_healthScore!.grade),
                          ),
                        ),
                        const SizedBox(height: DesignTokens.sm),
                        Text(
                          'Financial Stability Check',
                          style: TextStyle(color: textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: DesignTokens.xxl),

                  // Breakdown Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildMetricCard(
                        context,
                        'Savings',
                        _healthScore!.breakdown['savings'] ?? 0,
                        Icons.savings_rounded,
                        AppTheme.info,
                        'Target: >20%',
                      ),
                      _buildMetricCard(
                        context,
                        'Debt Load',
                        _healthScore!.breakdown['debt'] ?? 0,
                        Icons.account_balance_wallet_rounded,
                        AppTheme.error,
                        'Target: <30% DTI',
                      ),
                      _buildMetricCard(
                        context,
                        'Liquidity',
                        _healthScore!.breakdown['liquidity'] ?? 0,
                        Icons.water_drop_rounded,
                        AppTheme.peacockLight,
                        'Target: 6 mo exp',
                      ),
                      _buildMetricCard(
                        context,
                        'Investments',
                        _healthScore!.breakdown['investment'] ?? 0,
                        Icons.trending_up_rounded,
                        AppTheme.success,
                        'Diversity Score',
                      ),
                    ],
                  ),

                  const SizedBox(height: DesignTokens.xxl),

                  // Insights Section
                  if (_healthScore!.insights.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AI Advisor Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.md),
                    ..._healthScore!.insights.map(
                      (insight) => Container(
                        margin: const EdgeInsets.only(bottom: DesignTokens.md),
                        padding: DesignTokens.cardPadding,
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.12),
                          borderRadius: DesignTokens.brMd,
                          border: Border.all(
                            color: AppTheme.info.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.info,
                            ),
                            const SizedBox(width: DesignTokens.md),
                            Expanded(
                              child: Text(
                                insight,
                                style: TextStyle(color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Download Report Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (_healthScore == null) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Generating PDF report with AI analysis...',
                            ),
                          ),
                        );
                        try {
                          final filePath = await pdfReportService
                              .generateHealthReport(
                                healthScore: _healthScore!,
                                dashboardData: null,
                                userName:
                                    authService.currentUser?.displayName ??
                                    'User',
                              );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  '\u2705 Report generated! Opening...',
                                ),
                                action: SnackBarAction(
                                  label: 'Open',
                                  onPressed: () => OpenFile.open(filePath),
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                            await OpenFile.open(filePath);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to generate report: $e'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Download Full Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.peacockTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.brMd,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    double score,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    // Determine progress bar value (0 to 1, max is roughly 30 points per category in backend logic but normalized here)
    // Actually backend returns weighted score. Let's assume max possible for each is ~25-30.
    // For visualization let's just show the raw score with a max of 30.
    double progress = (score / 30).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.deepSlate : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.pearlWhite : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.silverMist : AppTheme.lightTextSecondary;

    return Container(
      padding: DesignTokens.cardPadding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: DesignTokens.brMd,
        border: Border.all(
          color: isDark
              ? Colors.white10
              : AppTheme.lightBorder.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.md),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesignTokens.xs),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesignTokens.sm),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark
                ? Colors.white10
                : AppTheme.lightBorder.withValues(alpha: 0.5),
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'Excellent':
        return AppTheme.success;
      case 'Good':
        return AppTheme.successLight;
      case 'Fair':
        return AppTheme.warning;
      case 'Poor':
        return AppTheme.warningLight;
      default:
        return AppTheme.error;
    }
  }
}
