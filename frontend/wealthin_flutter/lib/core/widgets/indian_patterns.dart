import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/indian_theme.dart';

/// Indian Pattern Widgets
/// Traditional patterns inspired by Indian architecture, rangoli, and mandalas

/// Mandala Pattern Background
class MandalaPattern extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const MandalaPattern({
    super.key,
    this.size = 200,
    this.color = IndianTheme.royalGold,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MandalaPainter(color: color, opacity: opacity),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _MandalaPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw concentric circles
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, maxRadius * (i / 5), paint);
    }

    // Draw radial lines (8-fold symmetry)
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4);
      final startPoint = center;
      final endPoint = Offset(
        center.dx + maxRadius * cos(angle),
        center.dy + maxRadius * sin(angle),
      );
      canvas.drawLine(startPoint, endPoint, paint);
    }

    // Draw petals (flower pattern)
    final petalPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4);
      final petalCenter = Offset(
        center.dx + (maxRadius * 0.7) * cos(angle),
        center.dy + (maxRadius * 0.7) * sin(angle),
      );
      canvas.drawCircle(petalCenter, maxRadius * 0.15, petalPaint);
    }

    // Center circle
    canvas.drawCircle(center, maxRadius * 0.1, petalPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rangoli Corner Pattern
class RangoliCornerPattern extends StatelessWidget {
  final double size;
  final Color color;
  final Alignment alignment;

  const RangoliCornerPattern({
    super.key,
    this.size = 100,
    this.color = IndianTheme.lotusPink,
    this.alignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: CustomPaint(
        size: Size(size, size),
        painter: _RangoliPainter(color: color),
      ),
    );
  }
}

class _RangoliPainter extends CustomPainter {
  final Color color;

  _RangoliPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Draw curved petals
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.2, size.width, 0);
    path.lineTo(size.width, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.4,
      size.width * 0.3,
      size.height,
    );
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Add dots (traditional rangoli dots)
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final x = size.width * (0.2 + i * 0.3);
        final y = size.height * (0.2 + j * 0.3);
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lotus Floating Animation
class FloatingLotus extends StatefulWidget {
  final double size;
  final Color color;

  const FloatingLotus({
    super.key,
    this.size = 60,
    this.color = IndianTheme.lotusPink,
  });

  @override
  State<FloatingLotus> createState() => _FloatingLotusState();
}

class _FloatingLotusState extends State<FloatingLotus>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _LotusPainter(color: widget.color),
          ),
        );
      },
    );
  }
}

class _LotusPainter extends CustomPainter {
  final Color color;

  _LotusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final petalPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Draw 8 petals
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4);
      final path = Path();

      final petalTip = Offset(
        center.dx + size.width * 0.4 * cos(angle),
        center.dy + size.height * 0.4 * sin(angle),
      );

      path.moveTo(center.dx, center.dy);
      path.quadraticBezierTo(
        center.dx + size.width * 0.2 * cos(angle - pi / 8),
        center.dy + size.height * 0.2 * sin(angle - pi / 8),
        petalTip.dx,
        petalTip.dy,
      );
      path.quadraticBezierTo(
        center.dx + size.width * 0.2 * cos(angle + pi / 8),
        center.dy + size.height * 0.2 * sin(angle + pi / 8),
        center.dx,
        center.dy,
      );

      canvas.drawPath(path, petalPaint);
    }

    // Draw center
    final centerPaint = Paint()
      ..color = IndianTheme.turmeric
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.1, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Temple Architecture Border
class TempleArchBorder extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final double borderWidth;

  const TempleArchBorder({
    super.key,
    required this.child,
    this.borderColor = IndianTheme.templeStone,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TempleArchPainter(
        color: borderColor,
        strokeWidth: borderWidth,
      ),
      child: child,
    );
  }
}

class _TempleArchPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _TempleArchPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Top arch
    final archPath = Path();
    archPath.moveTo(0, size.height * 0.2);
    archPath.quadraticBezierTo(
      size.width * 0.5,
      -size.height * 0.1,
      size.width,
      size.height * 0.2,
    );
    canvas.drawPath(archPath, paint);

    // Pillars
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.15, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.85, size.height * 0.2),
      Offset(size.width * 0.85, size.height),
      paint,
    );

    // Decorative lines
    for (int i = 0; i < 3; i++) {
      final y = size.height * (0.3 + i * 0.2);
      canvas.drawLine(
        Offset(size.width * 0.15, y),
        Offset(size.width * 0.85, y),
        paint..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rotating Chakra (Wheel) Animation
class RotatingChakra extends StatefulWidget {
  final double size;
  final Color color;
  final int spokes;

  const RotatingChakra({
    super.key,
    this.size = 80,
    this.color = IndianTheme.peacockBlue,
    this.spokes = 24,
  });

  @override
  State<RotatingChakra> createState() => _RotatingChakraState();
}

class _RotatingChakraState extends State<RotatingChakra>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ChakraPainter(
              color: widget.color,
              spokes: widget.spokes,
            ),
          ),
        );
      },
    );
  }
}

class _ChakraPainter extends CustomPainter {
  final Color color;
  final int spokes;

  _ChakraPainter({required this.color, required this.spokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer circle
    canvas.drawCircle(center, radius, paint);

    // Inner circle
    canvas.drawCircle(center, radius * 0.2, paint);

    // Spokes
    for (int i = 0; i < spokes; i++) {
      final angle = (i * 2 * pi / spokes);
      final outerPoint = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius * 0.2) * cos(angle),
        center.dy + (radius * 0.2) * sin(angle),
      );
      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Subtle Background Pattern Overlay
class IndianPatternOverlay extends StatelessWidget {
  final Widget child;
  final bool showMandala;
  final bool showRangoli;

  const IndianPatternOverlay({
    super.key,
    required this.child,
    this.showMandala = true,
    this.showRangoli = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background patterns
        if (showMandala)
          const Positioned(
            top: -50,
            right: -50,
            child: MandalaPattern(size: 250),
          ),
        if (showMandala)
          const Positioned(
            bottom: -80,
            left: -80,
            child: MandalaPattern(
              size: 300,
              color: IndianTheme.peacockBlue,
              opacity: 0.08,
            ),
          ),
        if (showRangoli)
          const RangoliCornerPattern(
            size: 120,
            alignment: Alignment.topLeft,
          ),
        if (showRangoli)
          const RangoliCornerPattern(
            size: 100,
            color: IndianTheme.turmeric,
            alignment: Alignment.bottomRight,
          ),

        // Main content
        child,
      ],
    );
  }
}

/// Decorative Divider with Pattern
class IndianDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double thickness;

  const IndianDivider({
    super.key,
    this.color = IndianTheme.royalGold,
    this.height = 20,
    this.thickness = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: thickness,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    color.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.auto_awesome,
              size: 16,
              color: color,
            ),
          ),
          Expanded(
            child: Container(
              height: thickness,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer Loading Effect with Indian Colors
class IndianShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const IndianShimmer({
    super.key,
    required this.child,
    this.baseColor = IndianTheme.champagneGold,
    this.highlightColor = IndianTheme.goldShimmer,
  });

  @override
  State<IndianShimmer> createState() => _IndianShimmerState();
}

class _IndianShimmerState extends State<IndianShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
