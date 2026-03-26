import 'package:flutter/material.dart';
import 'dart:math' as math;

/// WealthIn Logo — Canvas-drawn premium widget
/// Draws a stylised ₹ symbol with an upward growth arc
/// forming the second horizontal bar — representing wealth growth.
class WealthInLogo extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color accentColor;
  final bool showGlow;

  const WealthInLogo({
    super.key,
    this.size = 40,
    this.primaryColor = const Color(0xFF0A7070), // peacockTeal
    this.accentColor = const Color(0xFFC9A84C), // royalGold
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.30),
                  blurRadius: size * 0.4,
                  spreadRadius: size * 0.05,
                ),
              ],
            )
          : null,
      child: CustomPaint(
        size: Size(size, size),
        painter: _WealthInLogoPainter(
          primary: primaryColor,
          accent: accentColor,
        ),
      ),
    );
  }
}

class _WealthInLogoPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  _WealthInLogoPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Background circle ──
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0D1117),
          const Color(0xFF141924),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawCircle(Offset(cx, h / 2), w / 2, bgPaint);

    // ── Gold ring border ──
    final borderPaint = Paint()
      ..color = accent.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;
    canvas.drawCircle(Offset(cx, h / 2), w / 2 - w * 0.015, borderPaint);

    final strokeW = w * 0.065;
    final rupeeLeft = cx - w * 0.22;
    final rupeeRight = cx + w * 0.22;

    // ── ₹ symbol ──
    // Main vertical stroke
    final vertPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(rupeeLeft + strokeW / 2, h * 0.22),
      Offset(rupeeLeft + strokeW / 2, h * 0.78),
      vertPaint,
    );

    // Top horizontal bar
    final hBarPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.85
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(rupeeLeft, h * 0.25),
      Offset(rupeeRight, h * 0.25),
      hBarPaint,
    );

    // ── Curved arch (₹ second bar → growth arc) ──
    final archPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.85
      ..strokeCap = StrokeCap.round;

    final archPath = Path();
    archPath.moveTo(rupeeLeft, h * 0.41);
    archPath.cubicTo(
      rupeeLeft + (rupeeRight - rupeeLeft) * 0.3,
      h * 0.33, // cp1
      rupeeLeft + (rupeeRight - rupeeLeft) * 0.7,
      h * 0.33, // cp2
      rupeeRight,
      h * 0.41, // end
    );
    canvas.drawPath(archPath, archPaint);

    // ── Growth arrow stem (diagonal from arch end going up-right) ──
    final arrowPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.7
      ..strokeCap = StrokeCap.round;

    final arrowX1 = rupeeLeft + (rupeeRight - rupeeLeft) * 0.55;
    final arrowY1 = h * 0.5;
    final arrowX2 = rupeeRight + w * 0.02;
    final arrowY2 = h * 0.30;
    canvas.drawLine(
      Offset(arrowX1, arrowY1),
      Offset(arrowX2, arrowY2),
      arrowPaint,
    );

    // Arrow head
    const headLen = 0.07;
    final angle = math.atan2(arrowY2 - arrowY1, arrowX2 - arrowX1);
    final arrowHeadPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.65
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(arrowX2, arrowY2),
      Offset(
        arrowX2 - w * headLen * math.cos(angle - 0.5),
        arrowY2 - h * headLen * math.sin(angle - 0.5),
      ),
      arrowHeadPaint,
    );
    canvas.drawLine(
      Offset(arrowX2, arrowY2),
      Offset(
        arrowX2 - w * headLen * math.cos(angle + 0.5),
        arrowY2 - h * headLen * math.sin(angle + 0.5),
      ),
      arrowHeadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WealthInLogoPainter old) =>
      old.primary != primary || old.accent != accent;
}
