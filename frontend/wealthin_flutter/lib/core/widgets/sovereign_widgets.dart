import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// WealthIn 2026 "Sovereign Growth" UI Components
/// Glass Dashboard aesthetic with Green (Wealth) + Purple (Intelligence) accents

// ============== GLASS DASHBOARD CARD ==============

/// Premium glass container with mint tint and subtle shadows
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool hasMintTint;
  final VoidCallback? onTap;
  final bool hasPurpleGlow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.hasMintTint = false,
    this.onTap,
    this.hasPurpleGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: padding ?? const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasMintTint
                        ? [
                            AppTheme.glassMint.withOpacity(0.9),
                            AppTheme.glassWhite.withOpacity(0.85),
                          ]
                        : [
                            AppTheme.glassWhite.withOpacity(0.9),
                            AppTheme.glassWhite.withOpacity(0.8),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: hasPurpleGlow
                        ? AppTheme.royalPurple.withOpacity(0.2)
                        : AppTheme.glassBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: hasPurpleGlow
                          ? AppTheme.royalPurple.withOpacity(0.08)
                          : AppTheme.glassShadow,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    if (hasPurpleGlow)
                      BoxShadow(
                        color: AppTheme.purpleGlow.withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============== PREDICTIVE PROGRESS BAR ==============

/// Progress bar with AI glow projection showing predicted completion
class PredictiveProgressBar extends StatelessWidget {
  final double currentProgress; // 0.0 to 1.0
  final double? predictedProgress; // AI-predicted completion
  final String? label;
  final String? valueLabel;
  final double height;
  final bool showPrediction;

  const PredictiveProgressBar({
    super.key,
    required this.currentProgress,
    this.predictedProgress,
    this.label,
    this.valueLabel,
    this.height = 12,
    this.showPrediction = true,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentProgress.clamp(0.0, 1.0);
    final predicted = (predictedProgress ?? progress).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || valueLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.forestLight,
                    ),
                  ),
                if (valueLabel != null)
                  Text(
                    valueLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.forestGreen,
                    ),
                  ),
              ],
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.mintDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Stack(
            children: [
              // AI Predicted progress (purple glow)
              if (showPrediction && predicted > progress)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: predicted,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.purpleGlow.withOpacity(0.3),
                            AppTheme.purpleGlow.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(height / 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.royalPurple.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Current progress (green)
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.growthGradient,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.emerald.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showPrediction && predicted > progress)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.purpleGlow,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.aiGlow,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI projects ${(predicted * 100).toInt()}% by month end',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.royalPurple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============== SOVEREIGN STAT CARD ==============

/// Compact stat display with icon, value, and trend
class SovereignStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? trend;
  final bool isPositive;
  final VoidCallback? onTap;

  const SovereignStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.trend,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.emerald).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppTheme.emerald,
                ),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppTheme.emerald.withOpacity(0.1)
                        : AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: isPositive ? AppTheme.emerald : AppTheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? AppTheme.emerald : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.forestGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.forestMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============== AI INSIGHT CHIP ==============

/// Purple-tinted chip for AI-generated insights ("FinBites")
class AIInsightChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  const AIInsightChip({
    super.key,
    required this.text,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.royalPurple.withOpacity(0.1),
                AppTheme.purpleLight.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.royalPurple.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.royalPurple.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.auto_awesome,
                size: 16,
                color: AppTheme.royalPurple,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.royalPurple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== ACTION BUTTON ==============

/// Primary action button with emerald styling
class SovereignActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPurple;

  const SovereignActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isPurple = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPurple ? AppTheme.premiumGradient : AppTheme.growthGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isPurple ? AppTheme.aiGlow : AppTheme.successGlow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                else if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============== SOVEREIGN DIVIDER ==============

/// Subtle divider with optional label
class SovereignDivider extends StatelessWidget {
  final String? label;

  const SovereignDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Divider(
        color: AppTheme.mintDark.withOpacity(0.5),
        thickness: 1,
        height: 32,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.mintDark.withOpacity(0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.forestMuted,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.mintDark.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============== AGENTIC TOOL BADGE ==============

/// Badge indicating AI/agentic tool capability
class AgenticToolBadge extends StatelessWidget {
  final String toolName;
  final bool isActive;

  const AgenticToolBadge({
    super.key,
    required this.toolName,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.royalPurple.withOpacity(0.15)
            : AppTheme.mintDark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppTheme.royalPurple.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.play_circle_filled : Icons.code,
            size: 14,
            color: isActive ? AppTheme.royalPurple : AppTheme.forestMuted,
          ),
          const SizedBox(width: 6),
          Text(
            toolName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? AppTheme.royalPurple : AppTheme.forestMuted,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
