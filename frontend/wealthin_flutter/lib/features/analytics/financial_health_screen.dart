import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/models.dart';
import '../../core/services/data_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/pdf_report_service.dart';
import 'widgets/health_score_gauge.dart';

class FinancialHealthScreen extends StatefulWidget {
  const FinancialHealthScreen({super.key});

  @override
  State<FinancialHealthScreen> createState() => _FinancialHealthScreenState();
}

class _FinancialHealthScreenState extends State<FinancialHealthScreen> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  HealthScore? _healthScore;

  @override
  void initState() {
    super.initState();
    _fetchScore();
  }

  Future<void> _fetchScore() async {
    setState(() => _isLoading = true);
    final user = await _authService.getCurrentUser();
    if (user != null) {
      final score = await _dataService.getHealthScore(user.id);
      setState(() {
        _healthScore = score;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Financial Health Analysis'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _healthScore == null
              ? const Center(child: Text('Could not fetch analysis', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Gauge Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            HealthScoreGauge(score: _healthScore!.totalScore),
                            const SizedBox(height: 16),
                            Text(
                              _healthScore!.grade,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _getGradeColor(_healthScore!.grade),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Financial Stability Check',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
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
                            'Savings',
                            _healthScore!.breakdown['savings'] ?? 0,
                            Icons.savings_rounded,
                            Colors.blue,
                            'Target: >20%',
                          ),
                          _buildMetricCard(
                            'Debt Load',
                            _healthScore!.breakdown['debt'] ?? 0,
                            Icons.account_balance_wallet_rounded,
                            Colors.redAccent,
                            'Target: <30% DTI',
                          ),
                          _buildMetricCard(
                            'Liquidity',
                            _healthScore!.breakdown['liquidity'] ?? 0,
                            Icons.water_drop_rounded,
                            Colors.cyan,
                            'Target: 6 mo exp',
                          ),
                          _buildMetricCard(
                            'Investments',
                            _healthScore!.breakdown['investment'] ?? 0,
                            Icons.trending_up_rounded,
                            Colors.green,
                            'Diversity Score',
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Insights Section
                      if (_healthScore!.insights.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'AI Advisor Insights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._healthScore!.insights.map((insight) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline, color: Colors.blueAccent),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      insight,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            )),
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
                              const SnackBar(content: Text('Generating PDF report...')),
                            );
                            try {
                              final filePath = await pdfReportService.generateHealthReport(
                                healthScore: _healthScore!,
                                dashboardData: null,
                                userName: _authService.currentUser?.userMetadata?['display_name'] as String? ?? 'User',
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Report saved: $filePath'),
                                    action: SnackBarAction(
                                      label: 'Open',
                                      onPressed: () => launchUrl(Uri.file(filePath)),
                                    ),
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to generate report: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Download Full Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricCard(String title, double score, IconData icon, Color color, String subtitle) {
    // Determine progress bar value (0 to 1, max is roughly 30 points per category in backend logic but normalized here)
    // Actually backend returns weighted score. Let's assume max possible for each is ~25-30.
    // For visualization let's just show the raw score with a max of 30.
    double progress = (score / 30).clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                score.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white38,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
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
      case 'Excellent': return const Color(0xFF4CAF50);
      case 'Good': return const Color(0xFFCDDC39);
      case 'Fair': return const Color(0xFFFFC107);
      case 'Poor': return const Color(0xFFFF9800);
      default: return const Color(0xFFF44336);
    }
  }
}
