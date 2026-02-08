import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/data_service.dart';
import '../../main.dart' show authService;
import '../dashboard/widgets/cashflow_card.dart';
import '../dashboard/widgets/trend_analysis_card.dart';
import '../dashboard/widgets/category_breakdown_card.dart';
import '../dashboard/widgets/financial_overview_card.dart';
import '../dashboard/widgets/metric_card.dart';

/// Analysis Screen - Detailed financial metrics and insights
/// Contains: Income/Expense/Savings cards, Financial Health Score, Charts
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final DataService _dataService = DataService();
  DashboardData? _data;
  bool _isLoading = true;
  int _financialHealthScore = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = authService.currentUserId;
      final data = await _dataService.getDashboard(userId);
      final healthScore = _calculateHealthScore(data);
      
      if (mounted) {
        setState(() {
          _data = data;
          _financialHealthScore = healthScore;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analysis data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateHealthScore(DashboardData? data) {
    if (data == null) return 0;
    
    int score = 25; // Base score (reduced from 50)
    
    // === SAVINGS RATE (0-25 points) ===
    // 30%+ savings = excellent, 20% = good, 10% = fair
    final savingsRate = data.savingsRate;
    if (savingsRate >= 30) {
      score += 25;
    } else if (savingsRate >= 20) {
      score += 20;
    } else if (savingsRate >= 10) {
      score += 12;
    } else if (savingsRate > 0) {
      score += 5;
    }
    
    // === EXPENSE TO INCOME RATIO (0-20 points) ===
    // Spending less than 70% of income is healthy
    if (data.totalIncome > 0) {
      final ratio = data.totalExpense / data.totalIncome;
      if (ratio < 0.5) {
        score += 20; // Excellent: spending < 50%
      } else if (ratio < 0.7) {
        score += 15; // Good: spending < 70%
      } else if (ratio < 0.85) {
        score += 8;  // Fair: spending < 85%
      } else if (ratio < 1.0) {
        score += 3;  // Warning: spending < 100%
      }
      // No points if spending >= income
    }
    
    // === EMERGENCY FUND PROGRESS (0-15 points) ===
    // 6 months of expenses is the goal
    final monthlyExpenses = data.totalExpense;
    final emergencyFundGoal = monthlyExpenses * 6;
    final currentSavings = data.totalIncome - data.totalExpense;
    
    if (emergencyFundGoal > 0 && currentSavings > 0) {
      // Calculate how many months of expenses saved
      final monthsCovered = currentSavings / (monthlyExpenses > 0 ? monthlyExpenses : 1);
      if (monthsCovered >= 6) {
        score += 15; // Full emergency fund
      } else if (monthsCovered >= 3) {
        score += 10; // 3+ months covered
      } else if (monthsCovered >= 1) {
        score += 5;  // At least 1 month covered
      }
    }
    
    // === INCOME CONSISTENCY (0-10 points) ===
    // Having regular income is a positive sign
    if (data.totalIncome > 0) {
      score += 8; // Base points for having income
      // Could be enhanced to check transaction regularity
    }
    
    // === DIVERSIFICATION BONUS (0-5 points) ===
    // Multiple income sources or balanced spending
    final categoryCount = data.categoryBreakdown.length;
    if (categoryCount >= 5) {
      score += 5; // Tracking multiple categories shows awareness
    } else if (categoryCount >= 3) {
      score += 3;
    }
    
    return score.clamp(0, 100);
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFF8BC34A);
    if (score >= 40) return const Color(0xFFFFC107);
    if (score >= 20) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getHealthScoreLabel(int score) {
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
    
    return Scaffold(
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
                          ? [
                              const Color(0xFF0D1F14), // Vault Green
                              const Color(0xFF132B1C), // Dark vault
                            ]
                          : [
                              const Color(0xFF046307), // True Emerald
                              const Color(0xFF2E8B57), // Emerald Dark
                            ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Financial Analysis',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
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
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Financial Health Score
                  _buildHealthScoreCard(theme).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 20),
                  
                  // Key Metrics Grid
                  _buildMetricsGrid(theme).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 20),
                  
                  // Cashflow Chart
                  CashflowCard(
                    data: _data,
                    isLoading: _isLoading,
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 20),
                  
                  // Trend Analysis
                  const TrendAnalysisCard().animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 20),
                  
                  // Category Breakdown
                  CategoryBreakdownCard(
                    categoryBreakdown: _data?.categoryBreakdown ?? {},
                    isLoading: _isLoading,
                  ).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 20),
                  
                  // Per Capita Insights
                  _buildInsightsCard(theme).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 20),
                  
                  // Financial Overview
                  const FinancialOverviewCard().animate().fadeIn(delay: 350.ms),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final scoreColor = _getHealthScoreColor(_financialHealthScore);
    final scoreLabel = _getHealthScoreLabel(_financialHealthScore);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety,
                color: scoreColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Financial Health Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Score gauge
          SizedBox(
            height: 150,
            width: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 150,
                  width: 150,
                  child: CircularProgressIndicator(
                    value: _isLoading ? null : _financialHealthScore / 100,
                    strokeWidth: 12,
                    backgroundColor: isDark 
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLoading ? '--' : '$_financialHealthScore',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Score breakdown - 2x2 grid
          Row(
            children: [
              Expanded(
                child: _buildScoreFactor(
                  'Savings Rate',
                  '${(_data?.savingsRate ?? 0).toStringAsFixed(1)}%',
                  Icons.savings,
                  const Color(0xFF4CAF50),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScoreFactor(
                  'Expense Ratio',
                  _data != null && _data!.totalIncome > 0
                      ? '${((_data!.totalExpense / _data!.totalIncome) * 100).toStringAsFixed(0)}%'
                      : '0%',
                  Icons.pie_chart,
                  const Color(0xFF2196F3),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScoreFactor(
                  'Emergency Fund',
                  _data != null && _data!.totalExpense > 0
                      ? '${((_data!.totalIncome - _data!.totalExpense) / _data!.totalExpense).toStringAsFixed(1)}mo'
                      : '0mo',
                  Icons.shield,
                  const Color(0xFF9C27B0),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScoreFactor(
                  'Categories',
                  '${_data?.categoryBreakdown.length ?? 0}',
                  Icons.category,
                  const Color(0xFFFF9800),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreFactor(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme) {
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

  Widget _buildInsightRow(String label, String value, IconData icon, Color color, bool isDark) {
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
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
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
