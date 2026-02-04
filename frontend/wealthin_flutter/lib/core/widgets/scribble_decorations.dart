import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter for funky scribble/doodle decorations
class ScribblePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int seed;

  ScribblePainter({
    this.color = const Color(0xFF667EEA),
    this.strokeWidth = 2.0,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final random = math.Random(seed);

    // Draw wavy lines
    _drawWavyLine(canvas, size, paint, random, 0.1);
    _drawWavyLine(canvas, size, paint, random, 0.9);

    // Draw circles/spirals
    _drawSpiral(canvas, size, paint, random);

    // Draw small dots
    _drawDots(canvas, size, paint, random);
  }

  void _drawWavyLine(
    Canvas canvas,
    Size size,
    Paint paint,
    math.Random random,
    double yFactor,
  ) {
    final path = Path();
    final y = size.height * yFactor;
    path.moveTo(0, y);

    for (double x = 0; x < size.width; x += 20) {
      final waveHeight = 10 + random.nextDouble() * 15;
      final cp1y = y - waveHeight;
      final cp2y = y + waveHeight;
      path.cubicTo(
        x + 5,
        cp1y,
        x + 15,
        cp2y,
        x + 20,
        y,
      );
    }

    canvas.drawPath(path, paint);
  }

  void _drawSpiral(Canvas canvas, Size size, Paint paint, math.Random random) {
    final centerX = size.width * (0.8 + random.nextDouble() * 0.15);
    final centerY = size.height * (0.2 + random.nextDouble() * 0.1);

    final path = Path();
    double angle = 0;
    double radius = 5;

    path.moveTo(centerX, centerY);

    for (int i = 0; i < 30; i++) {
      angle += 0.5;
      radius += 1.5;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  void _drawDots(Canvas canvas, Size size, Paint paint, math.Random random) {
    final dotPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 2 + random.nextDouble() * 4;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scribble decoration widget
class ScribbleDecoration extends StatelessWidget {
  final Widget child;
  final Color color;
  final int seed;

  const ScribbleDecoration({
    super.key,
    required this.child,
    this.color = const Color(0xFF667EEA),
    this.seed = 42,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ScribblePainter(color: color, seed: seed),
      child: child,
    );
  }
}

/// Animated floating scribble/doodle
class FloatingScribble extends StatefulWidget {
  final Color color;
  final double size;
  final ScribbleType type;

  const FloatingScribble({
    super.key,
    this.color = const Color(0xFF667EEA),
    this.size = 60,
    this.type = ScribbleType.circle,
  });

  @override
  State<FloatingScribble> createState() => _FloatingScribbleState();
}

class _FloatingScribbleState extends State<FloatingScribble>
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

    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
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
            painter: _ScribbleShapePainter(
              color: widget.color,
              type: widget.type,
            ),
          ),
        );
      },
    );
  }
}

enum ScribbleType { circle, star, squiggle, arrow }

class _ScribbleShapePainter extends CustomPainter {
  final Color color;
  final ScribbleType type;

  _ScribbleShapePainter({required this.color, required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case ScribbleType.circle:
        _drawHandDrawnCircle(canvas, size, paint);
        break;
      case ScribbleType.star:
        _drawHandDrawnStar(canvas, size, paint);
        break;
      case ScribbleType.squiggle:
        _drawSquiggle(canvas, size, paint);
        break;
      case ScribbleType.arrow:
        _drawArrow(canvas, size, paint);
        break;
    }
  }

  void _drawHandDrawnCircle(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Imperfect circle using bezier curves
    path.moveTo(center.dx + radius, center.dy);
    for (double angle = 0; angle <= math.pi * 2; angle += math.pi / 4) {
      final wobble = (math.Random().nextDouble() - 0.5) * 4;
      final x = center.dx + (radius + wobble) * math.cos(angle + 0.1);
      final y = center.dy + (radius + wobble) * math.sin(angle + 0.1);
      path.lineTo(x, y);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawHandDrawnStar(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 5;
    final innerRadius = outerRadius * 0.4;

    for (int i = 0; i < 10; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi / 5) - math.pi / 2;
      final wobble = (math.Random().nextDouble() - 0.5) * 3;
      final x = center.dx + (radius + wobble) * math.cos(angle);
      final y = center.dy + (radius + wobble) * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawSquiggle(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    path.moveTo(0, size.height / 2);

    for (double x = 0; x < size.width; x += 10) {
      final y = size.height / 2 + math.sin(x / 5) * 10;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    path.moveTo(5, size.height / 2);
    path.lineTo(size.width - 15, size.height / 2);
    path.moveTo(size.width - 25, size.height / 2 - 10);
    path.lineTo(size.width - 10, size.height / 2);
    path.lineTo(size.width - 25, size.height / 2 + 10);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
