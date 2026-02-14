import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/services/data_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../main.dart' hide dataService; // for authService

class TrendAnalysisCard extends StatefulWidget {
  const TrendAnalysisCard({super.key});

  @override
  State<TrendAnalysisCard> createState() => _TrendAnalysisCardState();
}

class _TrendAnalysisCardState extends State<TrendAnalysisCard> {
  bool _isLoading = true;
  Map<String, dynamic> _monthlyData = {};

  double _safeDouble(dynamic value) {
    final parsed =
        (value as num?)?.toDouble() ??
        double.tryParse(value?.toString() ?? '') ??
        0.0;
    return parsed.isFinite ? parsed : 0.0;
  }

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    try {
      final userId = authService.currentUserId;
      final data = await dataService.getMonthlyTrends(userId);
      if (mounted) {
        setState(() {
          _monthlyData = data['monthly_data'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_monthlyData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Prepare data for chart
    final List<FlSpot> incomeSpots = [];
    final List<FlSpot> expenseSpots = [];
    int index = 0;

    // Sort keys (dates)
    final sortedKeys = _monthlyData.keys.toList()..sort();

    for (var month in sortedKeys) {
      final data = _monthlyData[month];
      if (data is! Map) continue;
      incomeSpots.add(FlSpot(index.toDouble(), _safeDouble(data['income'])));
      expenseSpots.add(FlSpot(index.toDouble(), _safeDouble(data['expenses'])));
      index++;
    }

    if (incomeSpots.isEmpty && expenseSpots.isEmpty) {
      return const SizedBox.shrink();
    }

    final chartValues = [...incomeSpots, ...expenseSpots].map((spot) => spot.y);
    final maxValue = chartValues.isEmpty ? 0.0 : chartValues.reduce(math.max);
    final maxY = maxValue > 0 ? maxValue * 1.15 : 1.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Trends',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < sortedKeys.length) {
                            // Format 2025-01 to Jan
                            final parts = sortedKeys[value.toInt()].split('-');
                            if (parts.length > 1) {
                              const months = [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ];
                              final monthIndex = int.tryParse(parts[1]) ?? 1;
                              if (monthIndex < 1 ||
                                  monthIndex > months.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  months[monthIndex - 1],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: incomeSpots,
                      isCurved: true,
                      color: AppTheme.incomeGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.incomeGreen.withValues(alpha: 0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: expenseSpots,
                      isCurved: true,
                      color: AppTheme.expenseRed,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: const [
                _LegendItem(color: AppTheme.incomeGreen, label: 'Income'),
                _LegendItem(color: AppTheme.expenseRed, label: 'Expenses'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
