import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/indian_theme.dart';

/// Cashflow Graph Widget
/// Shows income vs expenses over time with Indian-inspired visuals.
class CashflowGraph extends StatelessWidget {
  final List<CashflowDataPoint> dataPoints;
  final double height;

  const CashflowGraph({
    super.key,
    required this.dataPoints,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (dataPoints.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: isDark
            ? IndianTheme.sacredNightGradient
            : IndianTheme.sacredMorningGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: IndianTheme.royalGold.withValues(alpha: 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: IndianTheme.saffron.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                    gradient: IndianTheme.sunriseGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cashflow Trends',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? IndianTheme.pearlWhite
                            : IndianTheme.templeGranite,
                      ),
                    ),
                    Text(
                      'Income vs Expenses',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark
                            ? IndianTheme.silverMist
                            : IndianTheme.templeStone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildChart(isDark)),
            const SizedBox(height: 16),
            _buildLegend(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: isDark
            ? IndianTheme.sacredNightGradient
            : IndianTheme.sacredMorningGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: IndianTheme.royalGold.withValues(alpha: 0.28),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 64,
              color: (isDark ? IndianTheme.silverMist : IndianTheme.templeStone)
                  .withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No cashflow data yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDark ? IndianTheme.silverMist : IndianTheme.templeStone,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add transactions to see your cashflow trends',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: (isDark ? IndianTheme.silverMist : IndianTheme.templeStone)
                    .withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(bool isDark) {
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (int i = 0; i < dataPoints.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), dataPoints[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), dataPoints[i].expense));
    }

    final maxY = dataPoints.fold<double>(
      0,
      (max, point) => max > point.income && max > point.expense
          ? max
          : (point.income > point.expense ? point.income : point.expense),
    );

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY == 0 ? 1 : maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: IndianTheme.templeStone.withValues(alpha: 0.12),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= dataPoints.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    dataPoints[value.toInt()].label,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isDark
                          ? IndianTheme.silverMist
                          : IndianTheme.templeStone,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY == 0 ? 1 : maxY / 5,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₹${_formatAmount(value)}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark
                        ? IndianTheme.silverMist
                        : IndianTheme.templeStone,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble(),
        minY: 0,
        maxY: maxY == 0 ? 100 : maxY * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            gradient: IndianTheme.prosperityGradient,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  IndianTheme.mehendiGreen.withValues(alpha: 0.25),
                  IndianTheme.mehendiGreen.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            gradient: const LinearGradient(
              colors: [IndianTheme.vermillion, IndianTheme.saffron],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  IndianTheme.vermillion.withValues(alpha: 0.2),
                  IndianTheme.vermillion.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          'Income',
          IndianTheme.mehendiGreen,
          Icons.arrow_upward_rounded,
          isDark,
        ),
        const SizedBox(width: 24),
        _buildLegendItem(
          'Expenses',
          IndianTheme.vermillion,
          Icons.arrow_downward_rounded,
          isDark,
        ),
      ],
    );
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? IndianTheme.silverMist : IndianTheme.templeStone,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

/// Cashflow Data Point Model
class CashflowDataPoint {
  final String label;
  final double income;
  final double expense;
  final DateTime date;

  CashflowDataPoint({
    required this.label,
    required this.income,
    required this.expense,
    required this.date,
  });

  double get netCashflow => income - expense;
}

/// Cashflow Summary Card
class CashflowSummaryCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate;

  const CashflowSummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: IndianTheme.templeSunsetGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: IndianTheme.saffron.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cashflow Summary',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildMetric('Income', totalIncome, Icons.arrow_upward_rounded, Colors.white)),
                Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildMetric('Expenses', totalExpense, Icons.arrow_downward_rounded, Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Savings',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        '₹${_formatAmount(netSavings)}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${savingsRate.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: IndianTheme.mehendiGreen,
                      ),
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

  Widget _buildMetric(String label, double value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: color.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${_formatAmount(value)}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(2)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}
