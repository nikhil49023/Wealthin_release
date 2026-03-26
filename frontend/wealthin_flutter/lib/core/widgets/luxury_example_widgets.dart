import 'package:flutter/material.dart';
import '../theme/luxury_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic.dart';

/// Example widgets showcasing luxury color palette and glassmorphic effects
/// Use these as reference for implementing vibrant Indian authentic design

class LuxuryExampleWidgets {
  /// Premium Dashboard Card with glass effect
  static Widget premiumDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        gradient: LuxuryColors.mintBreeze,
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LuxuryColors.goldenHour,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: LuxuryColors.goldenSand.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: LuxuryColors.deepOlive, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: LuxuryColors.textLightSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                color: LuxuryColors.deepOlive,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Transaction Item with luxury colors
  static Widget transactionItem({
    required String title,
    required String amount,
    required String date,
    required bool isIncome,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: LuxuryColors.luxuryGlassCard(borderRadius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isIncome
                    ? LuxuryColors.prosperityFlow
                    : LinearGradient(
                        colors: [
                          LuxuryColors.richBurgundy,
                          LuxuryColors.terracotta,
                        ],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LuxuryColors.deepOlive,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 13,
                      color: LuxuryColors.deepOlive.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'} $amount',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isIncome
                    ? LuxuryColors.forestEmerald
                    : LuxuryColors.richBurgundy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Goal Progress Card
  static Widget goalProgressCard({
    required String goalName,
    required double progress,
    required String currentAmount,
    required String targetAmount,
  }) {
    return PremiumGlassCard(
      gradient: LuxuryColors.lavenderDream,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goalName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: LuxuryColors.deepOlive,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LuxuryColors.goldenHour,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: LuxuryColors.deepOlive,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: LuxuryColors.vanillaLatte.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LuxuryColors.prosperityFlow,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 12,
                      color: LuxuryColors.deepOlive.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentAmount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: LuxuryColors.forestEmerald,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Target',
                    style: TextStyle(
                      fontSize: 12,
                      color: LuxuryColors.deepOlive.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetAmount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: LuxuryColors.deepOlive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Premium Feature Card
  static Widget premiumFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: LuxuryColors.vibrantGlassCard(
          customGradient: LuxuryColors.royalNight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LuxuryColors.goldenHour,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: LuxuryColors.goldenSand.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: LuxuryColors.deepPurple, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: LuxuryColors.peachCream,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: LuxuryColors.vanillaLatte,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stats Card with gradient
  static Widget statsCard({
    required String label,
    required String value,
    required String change,
    required bool isPositive,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPositive
            ? LuxuryColors.prosperityFlow
            : LinearGradient(
                colors: [
                  LuxuryColors.richBurgundy.withValues(alpha: 0.8),
                  LuxuryColors.terracotta.withValues(alpha: 0.6),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LuxuryColors.goldenSand.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPositive
                    ? LuxuryColors.forestEmerald
                    : LuxuryColors.richBurgundy)
                .withValues(alpha: 0.3),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        change,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chat Bubble with luxury gradient
  static Widget chatBubble({
    required String message,
    required bool isUser,
    required String time,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          gradient: isUser ? LuxuryColors.sunriseLuxury : LuxuryColors.mintBreeze,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: LuxuryColors.goldenSand.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? LuxuryColors.peachCream : LuxuryColors.mintWhisper)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: LuxuryColors.deepOlive,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: LuxuryColors.deepOlive.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
