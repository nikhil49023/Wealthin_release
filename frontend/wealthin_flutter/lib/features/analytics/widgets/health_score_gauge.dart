import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

/// Premium Health Score Gauge with animated gradient arc and glow
class HealthScoreGauge extends StatelessWidget {
  final double score; // 0 to 100
  final double size;

  const HealthScoreGauge({
    super.key,
    required this.score,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scoreColor = _getScoreColor(score);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final animatedScore = (value * 100).clamp(0, 100).toDouble();

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: size * 0.95,
                height: size * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scoreColor.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),

              // Custom painted arc
              CustomPaint(
                size: Size(size, size),
                painter: _GaugePainter(
                  progress: value,
                  scoreColor: scoreColor,
                  isDark: isDark,
                ),
              ),

              // Inner circle with gradient
              Container(
                width: size * 0.65,
                height: size * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark ? AppTheme.inkSlate : AppTheme.lightCard,
                      isDark ? AppTheme.deepSlate : AppTheme.lightElevated,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),

              // Score text
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        scoreColor,
                        scoreColor.withValues(alpha: 0.7),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      animatedScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.pearlWhite
                            : AppTheme.lightTextPrimary,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.md,
                      vertical: DesignTokens.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: DesignTokens.brSm,
                    ),
                    child: Text(
                      _getScoreLabel(score),
                      style: TextStyle(
                        fontSize: size * 0.06,
                        fontWeight: FontWeight.w600,
                        color: scoreColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.successLight;
    if (score >= 40) return AppTheme.warning;
    if (score >= 20) return AppTheme.warningLight;
    return AppTheme.error;
  }

  String _getScoreLabel(double score) {
    if (score >= 80) return 'EXCELLENT';
    if (score >= 60) return 'GOOD';
    if (score >= 40) return 'FAIR';
    if (score >= 20) return 'NEEDS WORK';
    return 'CRITICAL';
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color scoreColor;
  final bool isDark;

  _GaugePainter({
    required this.progress,
    required this.scoreColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Background arc
    final bgPaint = Paint()
      ..color = isDark ? Colors.grey.shade800 : Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75, // Start at 135 degrees
      pi * 1.5, // Sweep 270 degrees
      false,
      bgPaint,
    );

    // Progress arc with gradient
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -pi * 0.75,
          endAngle: pi * 0.75,
          colors: [
            scoreColor.withValues(alpha: 0.5),
            scoreColor,
            scoreColor.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi * 0.75,
        pi * 1.5 * progress,
        false,
        progressPaint,
      );

      // End cap glow
      final endAngle = -pi * 0.75 + pi * 1.5 * progress;
      final endPoint = Offset(
        center.dx + radius * cos(endAngle),
        center.dy + radius * sin(endAngle),
      );

      final glowPaint = Paint()
        ..color = scoreColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(endPoint, 10, glowPaint);

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(endPoint, 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.scoreColor != scoreColor;
  }
}
