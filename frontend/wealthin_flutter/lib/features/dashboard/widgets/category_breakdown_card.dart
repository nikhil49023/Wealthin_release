import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../widgets/pie_chart_3d.dart';

/// Category Breakdown Card with 3D Pie Chart
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
    return PieChart3DCard(
      title: 'Top Expenses',
      data: categoryBreakdown,
      isLoading: isLoading,
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}
