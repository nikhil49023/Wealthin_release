import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CategoryBreakdownCard extends StatelessWidget {
  final Map<String, double> categoryBreakdown;
  final bool isLoading;

  const CategoryBreakdownCard({
    super.key,
    required this.categoryBreakdown,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort categories by amount
    final sortedEntries = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    final topEntries = sortedEntries.take(5).toList(); // Show top 5
    // Calculate total expense for percentage
    final double total = sortedEntries.fold(0, (sum, item) => sum + item.value);

    // If total is 0 avoid division by zero
    if (total == 0) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Expenses',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Pie Chart
                SizedBox(
                  height: 150,
                  width: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: topEntries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isTouched = false; 
                        final radius = isTouched ? 60.0 : 50.0;
                        const shadows = [Shadow(color: Colors.black, blurRadius: 2)];
                        
                        return PieChartSectionData(
                          color: _getColor(index),
                          value: item.value,
                          title: '${((item.value/total)*100).toStringAsFixed(0)}%',
                          radius: radius,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: shadows,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: topEntries.asMap().entries.map((entry) {
                       return Padding(
                         padding: const EdgeInsets.symmetric(vertical: 4),
                         child: Row(
                           children: [
                             Container(
                               width: 12,
                               height: 12,
                               decoration: BoxDecoration(
                                 color: _getColor(entry.key),
                                 shape: BoxShape.circle,
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 entry.value.key,
                                 style: Theme.of(context).textTheme.bodyMedium,
                                 overflow: TextOverflow.ellipsis,
                               ),
                             ),
                             Text(
                               '₹${entry.value.value.toStringAsFixed(0)}',
                               style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                       );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getColor(int index) {
    const colors = [
      AppTheme.expenseRed,
      Color(0xFFFFA726), // Orange
      Color(0xFF26A69A), // Teal
      Color(0xFF7E57C2), // Deep Purple
      Color(0xFF5C6BC0), // Indigo
      Colors.grey,
    ];
    return colors[index % colors.length];
  }
}
