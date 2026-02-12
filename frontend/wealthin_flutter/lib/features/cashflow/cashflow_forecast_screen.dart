import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:wealthin_flutter/core/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cashflow Forecast Screen - 30/60/90 Day Cash Flow Projections
class CashflowForecastScreen extends StatefulWidget {
  const CashflowForecastScreen({super.key});

  @override
  State<CashflowForecastScreen> createState() => _CashflowForecastScreenState();
}

class _CashflowForecastScreenState extends State<CashflowForecastScreen> {
  bool _isLoading = true;
  int _selectedDays = 90;
  List<Map<String, dynamic>> _projections = [];
  Map<String, dynamic>? _runway;
  List<Map<String, dynamic>> _warnings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? 'default_user';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = await _getCurrentUserId();

      // Load all data in parallel
      final results = await Future.wait([
        DataService().getCashflowForecast(userId, daysAhead: _selectedDays),
        DataService().getRunway(userId),
        DataService().getCashCrunchWarnings(userId, daysAhead: _selectedDays),
      ]);

      setState(() {
        _projections = results[0] as List<Map<String, dynamic>>;
        _runway = results[1] as Map<String, dynamic>?;
        _warnings = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cashflow data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _changePeriod(int days) {
    setState(() => _selectedDays = days);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Flow Forecast'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),

                    // Runway alert card
                    if (_runway != null) _buildRunwayCard(),
                    const SizedBox(height: 24),

                    // Cash flow chart
                    _buildCashflowChart(),
                    const SizedBox(height: 24),

                    // Cash crunch warnings
                    if (_warnings.isNotEmpty) _buildWarningsCard(),
                    const SizedBox(height: 24),

                    // Summary statistics
                    _buildSummaryStats(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forecast Period',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPeriodChip(30),
                const SizedBox(width: 8),
                _buildPeriodChip(60),
                const SizedBox(width: 8),
                _buildPeriodChip(90),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(int days) {
    final isSelected = _selectedDays == days;
    return ChoiceChip(
      label: Text('$days Days'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _changePeriod(days);
      },
      selectedColor: AppTheme.emerald,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildRunwayCard() {
    final runwayMonths = _runway?['runway_months'] as double? ?? 0;
    final runwayDays = _runway?['runway_days'] as int? ?? 0;
    final status = _runway?['status'] as String? ?? 'unknown';
    final recommendation = _runway?['recommendation'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;

    if (status == 'critical') {
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
    } else if (status == 'warning') {
      statusColor = Colors.orange;
      statusIcon = Icons.error_outline;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cash Runway',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${runwayMonths.toStringAsFixed(1)} months ($runwayDays days)',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (recommendation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCashflowChart() {
    if (_projections.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No forecast data available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),
        ),
      );
    }

    // Prepare data points
    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < _projections.length; i++) {
      final projection = _projections[i];
      final balance = (projection['closing_balance'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), balance));

      if (balance < minY) minY = balance;
      if (balance > maxY) maxY = balance;
    }

    // Add padding to Y axis
    final yPadding = (maxY - minY) * 0.1;
    minY = minY - yPadding;
    maxY = maxY + yPadding;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Balance Projection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: (maxY - minY) / 5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₹${_formatCompact(value)}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _selectedDays / 6,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _projections.length) {
                            return const SizedBox.shrink();
                          }
                          final date = _projections[value.toInt()]['date'] as String?;
                          if (date == null) return const SizedBox.shrink();

                          final parsedDate = DateTime.tryParse(date);
                          if (parsedDate == null) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM d').format(parsedDate),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [AppTheme.emerald, AppTheme.secondary],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.emerald.withOpacity(0.3),
                            AppTheme.secondary.withOpacity(0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final projection = _projections[spot.x.toInt()];
                          final date = projection['date'] as String?;
                          final balance = projection['closing_balance'] as num?;

                          return LineTooltipItem(
                            '${date != null ? DateFormat('MMM d').format(DateTime.parse(date)) : ''}\n₹${_formatAmount(balance?.toDouble() ?? 0)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningsCard() {
    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Cash Crunch Alerts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._warnings.take(5).map((warning) {
              final date = warning['date'] as String?;
              final balance = (warning['balance'] as num?)?.toDouble() ?? 0;
              final message = warning['message'] as String? ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: balance < 0
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          date != null
                              ? DateFormat('MMM d')
                                  .format(DateTime.parse(date))
                              : '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: balance < 0 ? Colors.red : Colors.orange,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${_formatAmount(balance)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balance < 0 ? Colors.red : Colors.orange,
                              ),
                            ),
                            if (message.isNotEmpty)
                              Text(
                                message,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (_projections.isEmpty) return const SizedBox.shrink();

    final firstBalance =
        (_projections.first['opening_balance'] as num?)?.toDouble() ?? 0;
    final lastBalance =
        (_projections.last['closing_balance'] as num?)?.toDouble() ?? 0;
    final totalIncome = _projections.fold<double>(
      0,
      (sum, p) => sum + ((p['income'] as num?)?.toDouble() ?? 0),
    );
    final totalExpenses = _projections.fold<double>(
      0,
      (sum, p) => sum + ((p['expenses'] as num?)?.toDouble() ?? 0),
    );
    final netChange = lastBalance - firstBalance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Starting Balance', firstBalance, Colors.blue),
            _buildStatRow('Ending Balance', lastBalance,
                lastBalance >= 0 ? Colors.green : Colors.red),
            _buildStatRow('Total Income', totalIncome, Colors.green),
            _buildStatRow('Total Expenses', totalExpenses, Colors.red),
            const Divider(height: 24),
            _buildStatRow(
              'Net Change',
              netChange,
              netChange >= 0 ? Colors.green : Colors.red,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '₹${_formatAmount(value)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount.abs() >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatCompact(double value) {
    if (value.abs() >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value.abs() >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
