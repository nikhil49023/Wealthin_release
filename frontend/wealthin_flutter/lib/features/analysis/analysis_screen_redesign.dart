import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/services/data_service.dart';
import '../../core/theme/indian_theme.dart';
import '../../core/widgets/indian_patterns.dart';
import '../../core/widgets/cashflow_graph.dart';
import '../../main.dart' show authService;

/// Redesigned Analysis Screen with Indian Aesthetics
/// Features: Cashflow Graph, Trends, Insights, Category Breakdown
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();

  DashboardData? _dashData;
  List<CashflowDataPoint> _cashflowData = [];
  bool _isLoading = true;
  String _selectedPeriod = '7D'; // 7D, 1M, 3M, 6M, 1Y

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = authService.currentUserId;

      // Load dashboard data
      final dashData = await _dataService.getDashboard(userId);
      if (dashData != null) {
        setState(() {
          _dashData = dashData;
        });

        // Generate cashflow data based on selected period
        await _generateCashflowData(userId);
      }
    } catch (e) {
      debugPrint('Error loading analysis data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateCashflowData(String userId) async {
    final transactions = await _dataService.getTransactions(userId);
    final dataPoints = <CashflowDataPoint>[];

    // Group transactions by period
    final now = DateTime.now();
    int days;

    switch (_selectedPeriod) {
      case '7D':
        days = 7;
        break;
      case '1M':
        days = 30;
        break;
      case '3M':
        days = 90;
        break;
      case '6M':
        days = 180;
        break;
      case '1Y':
        days = 365;
        break;
      default:
        days = 7;
    }

    // Create time buckets
    final bucketCount = min(
      days > 90
          ? 12
          : days > 30
          ? 10
          : 7,
      days,
    );
    final bucketSize = days ~/ bucketCount;

    for (int i = 0; i < bucketCount; i++) {
      final endDate = now.subtract(Duration(days: i * bucketSize));
      final startDate = endDate.subtract(Duration(days: bucketSize));

      double income = 0;
      double expense = 0;

      for (final tx in transactions) {
        if (tx.date.isAfter(startDate) && tx.date.isBefore(endDate)) {
          if (tx.isIncome) {
            income += tx.amount;
          } else {
            expense += tx.amount;
          }
        }
      }

      // Format label based on period
      String label;
      if (days > 90) {
        label = DateFormat('MMM').format(endDate);
      } else if (days > 30) {
        label = DateFormat('d').format(endDate);
      } else {
        label = DateFormat('EEE').format(endDate).substring(0, 1);
      }

      dataPoints.insert(
        0,
        CashflowDataPoint(
          label: label,
          income: income,
          expense: expense,
          date: endDate,
        ),
      );
    }

    setState(() {
      _cashflowData = dataPoints;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? IndianTheme.peacockGradient
                : IndianTheme.sacredMorningGradient,
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: IndianPatternOverlay(
        showMandala: true,
        showRangoli: true,
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? IndianTheme.peacockGradient
                : IndianTheme.sacredMorningGradient,
          ),
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(isDark),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildCashflowSummary(),
                      const SizedBox(height: 16),
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),
                      _buildCashflowGraph(),
                      const SizedBox(height: 16),
                      _buildCategoryBreakdown(),
                      const SizedBox(height: 16),
                      _buildInsightsCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: IndianTheme.templeSunsetGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const RotatingChakra(size: 40, spokes: 12),
                      const SizedBox(width: 12),
                      Text(
                        'Financial Analysis',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your cashflow trends and insights',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashflowSummary() {
    if (_dashData == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CashflowSummaryCard(
        totalIncome: _dashData!.totalIncome,
        totalExpense: _dashData!.totalExpense,
        netSavings: _dashData!.totalIncome - _dashData!.totalExpense,
        savingsRate: _dashData!.savingsRate,
      ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['7D', '1M', '3M', '6M', '1Y'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: IndianTheme.marbleCardDecoration(),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: periods.map((period) {
            final isSelected = period == _selectedPeriod;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedPeriod = period);
                  _loadData();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected ? IndianTheme.sunriseGradient : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      period,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : IndianTheme.templeStone,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
    );
  }

  Widget _buildCashflowGraph() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CashflowGraph(
        dataPoints: _cashflowData,
        height: 350,
      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_dashData == null || _dashData!.categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort categories by amount
    final sortedCategories = _dashData!.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories.take(5).toList();
    final total = sortedCategories.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: IndianTheme.marbleCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: IndianTheme.peacockGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Top Spending Categories',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: IndianTheme.templeGranite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...topCategories.map((entry) {
                final percentage = (entry.value / total * 100);
                return _buildCategoryItem(
                  entry.key,
                  entry.value,
                  percentage,
                );
              }),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildCategoryItem(
    String category,
    double amount,
    double percentage,
  ) {
    final color = _getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: IndianTheme.templeGranite,
                    ),
                  ),
                ],
              ),
              Text(
                '₹${_formatAmount(amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: IndianTheme.templeGranite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: IndianTheme.templeStone.withValues(
                      alpha: 0.2,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: IndianTheme.templeStone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    if (_dashData == null) return const SizedBox.shrink();

    // Generate insights
    final insights = _generateInsights();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: IndianTheme.royalGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: IndianTheme.royalPurple.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Smart Insights',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const IndianDivider(color: Colors.white, height: 12),
              const SizedBox(height: 16),
              ...insights.map((insight) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.95),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  List<String> _generateInsights() {
    final insights = <String>[];

    if (_dashData == null) return insights;

    // Savings rate insight
    if (_dashData!.savingsRate > 30) {
      insights.add(
        'Excellent! You\'re saving ${_dashData!.savingsRate.toStringAsFixed(1)}% of your income.',
      );
    } else if (_dashData!.savingsRate > 20) {
      insights.add(
        'Good savings rate at ${_dashData!.savingsRate.toStringAsFixed(1)}%. Try to push it above 30%.',
      );
    } else if (_dashData!.savingsRate > 10) {
      insights.add(
        'Your savings rate is ${_dashData!.savingsRate.toStringAsFixed(1)}%. Consider cutting down expenses.',
      );
    } else {
      insights.add(
        'Low savings rate at ${_dashData!.savingsRate.toStringAsFixed(1)}%. Review your expenses urgently.',
      );
    }

    // Expense trend insight
    if (_cashflowData.length > 1) {
      final recentExpense = _cashflowData.last.expense;
      final previousExpense = _cashflowData[_cashflowData.length - 2].expense;

      if (recentExpense > previousExpense * 1.2) {
        insights.add(
          'Your expenses increased by ${((recentExpense / previousExpense - 1) * 100).toStringAsFixed(0)}% recently.',
        );
      } else if (recentExpense < previousExpense * 0.8) {
        insights.add(
          'Great job! Your expenses decreased by ${((1 - recentExpense / previousExpense) * 100).toStringAsFixed(0)}%.',
        );
      }
    }

    // Category insight
    if (_dashData!.categoryBreakdown.isNotEmpty) {
      final topCategory = _dashData!.categoryBreakdown.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final total = _dashData!.categoryBreakdown.values.fold<double>(
        0,
        (sum, val) => sum + val,
      );
      final percentage = (topCategory.value / total * 100);

      if (percentage > 40) {
        insights.add(
          '${topCategory.key} takes up ${percentage.toStringAsFixed(0)}% of your spending. Consider if this is optimal.',
        );
      }
    }

    return insights;
  }

  Color _getCategoryColor(String category) {
    final colors = [
      IndianTheme.saffron,
      IndianTheme.peacockBlue,
      IndianTheme.mehendiGreen,
      IndianTheme.lotusPink,
      IndianTheme.turmeric,
      IndianTheme.royalPurple,
      IndianTheme.peacockTeal,
      IndianTheme.vermillion,
    ];

    return colors[category.hashCode % colors.length];
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}
