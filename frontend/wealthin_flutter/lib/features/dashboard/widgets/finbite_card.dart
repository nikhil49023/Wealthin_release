import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wealthin_flutter/core/services/data_service.dart';

/// FinBite Card - AI-powered daily financial insight widget
class FinBiteCard extends StatelessWidget {
  final DailyInsight? insight;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final VoidCallback? onTap;

  const FinBiteCard({
    super.key,
    this.insight,
    this.isLoading = false,
    this.onRefresh,
    this.onTap,
  });

  /// Default/loading state insight
  static DailyInsight loadingInsight() {
    return DailyInsight(
      headline: '📊 Analyzing your finances...',
      insightText: 'Please wait while we crunch the numbers.',
      recommendation: '',
      trendIndicator: 'stable',
    );
  }

  /// Fallback insight when no data available
  static DailyInsight emptyInsight() {
    return DailyInsight(
      headline: '💡 Start tracking today!',
      insightText: 'Add transactions to get personalized AI insights.',
      recommendation: 'Tap the + button to record your first transaction.',
      trendIndicator: 'stable',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayInsight = insight ?? emptyInsight();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getGradientColors(displayInsight.trendIndicator, theme),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row with icon and refresh
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _TrendIcon(trend: displayInsight.trendIndicator),
                        const SizedBox(width: 8),
                        Text(
                          'AI FinBite',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (onRefresh != null)
                      IconButton(
                        onPressed: isLoading ? null : onRefresh,
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Headline
                if (isLoading)
                  _LoadingShimmer(height: 24, width: 200)
                else
                  Text(
                    displayInsight.headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 8),

                // Insight Text
                if (isLoading)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LoadingShimmer(height: 14, width: double.infinity),
                      const SizedBox(height: 4),
                      _LoadingShimmer(height: 14, width: 180),
                    ],
                  )
                else
                  Text(
                    displayInsight.insightText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.95),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                // Category highlight chip
                if (!isLoading && displayInsight.categoryHighlight != null) ...[
                  const SizedBox(height: 10),
                  _CategoryChip(
                    category: displayInsight.categoryHighlight!,
                    amount: displayInsight.amountHighlight,
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                ],

                // Recommendation
                if (!isLoading && displayInsight.recommendation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.tips_and_updates,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayInsight.recommendation,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String trend, ThemeData theme) {
    switch (trend) {
      case 'up':
        return [
          const Color(0xFF2E7D32), // Green 800
          const Color(0xFF43A047), // Green 600
        ];
      case 'down':
        return [
          const Color(0xFFE65100), // Orange 900
          const Color(0xFFF57C00), // Orange 700
        ];
      case 'stable':
      default:
        return [
          theme.colorScheme.primary,
          theme.colorScheme.primary.withOpacity(0.8),
        ];
    }
  }
}

/// Animated trend icon based on financial health
class _TrendIcon extends StatelessWidget {
  final String trend;

  const _TrendIcon({required this.trend});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bgColor;

    switch (trend) {
      case 'up':
        icon = Icons.trending_up;
        bgColor = Colors.white.withOpacity(0.2);
        break;
      case 'down':
        icon = Icons.trending_down;
        bgColor = Colors.white.withOpacity(0.2);
        break;
      case 'stable':
      default:
        icon = Icons.trending_flat;
        bgColor = Colors.white.withOpacity(0.2);
        break;
    }

    return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.1, 1.1),
          duration: 1500.ms,
          curve: Curves.easeInOut,
        );
  }
}

/// Category highlight chip
class _CategoryChip extends StatelessWidget {
  final String category;
  final double? amount;

  const _CategoryChip({required this.category, this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCategoryIcon(category),
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            category,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 8),
            Text(
              '₹${_formatAmount(amount!)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lowerCat = category.toLowerCase();
    if (lowerCat.contains('food') || lowerCat.contains('restaurant')) {
      return Icons.restaurant;
    } else if (lowerCat.contains('transport') || lowerCat.contains('travel')) {
      return Icons.directions_car;
    } else if (lowerCat.contains('shopping')) {
      return Icons.shopping_bag;
    } else if (lowerCat.contains('entertainment')) {
      return Icons.movie;
    } else if (lowerCat.contains('health') || lowerCat.contains('medical')) {
      return Icons.medical_services;
    } else if (lowerCat.contains('bill') || lowerCat.contains('utility')) {
      return Icons.receipt_long;
    } else {
      return Icons.category;
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

/// Shimmer loading placeholder
class _LoadingShimmer extends StatelessWidget {
  final double height;
  final double width;

  const _LoadingShimmer({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: Colors.white.withOpacity(0.5),
        );
  }
}
