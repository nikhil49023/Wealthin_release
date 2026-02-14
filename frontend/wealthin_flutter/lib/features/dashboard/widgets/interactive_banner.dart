import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Premium Interactive Banner with WealthIn branding
/// Features ivory gradient, 3D-style floating elements, and micro-animations
class InteractiveBanner extends StatefulWidget {
  final String userName;
  final String greeting;
  final VoidCallback? onTap;

  const InteractiveBanner({
    super.key,
    required this.userName,
    required this.greeting,
    this.onTap,
  });

  @override
  State<InteractiveBanner> createState() => _InteractiveBannerState();
}

class _InteractiveBannerState extends State<InteractiveBanner>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  double _dragX = 0;
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) {
        setState(() {
          _dragX = (details.localPosition.dx - 150) / 30;
          _dragY = (details.localPosition.dy - 75) / 30;
        });
      },
      onPanEnd: (_) {
        setState(() {
          _dragX = 0;
          _dragY = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_dragY * 0.01)
          ..rotateY(-_dragX * 0.01),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F3460),
                    ]
                  : [
                      const Color(0xFFFFFFF0), // Ivory
                      const Color(0xFFFFF8E7), // Cream
                      const Color(0xFFFFE4B5), // Moccasin
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFFD4AF37).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Animated background pattern
                _buildAnimatedPattern(isDark),
                
                // Floating 3D elements
                _buildFloatingElements(isDark),
                
                // Content
                _buildContent(theme, isDark),
                
                // Shimmer overlay
                _buildShimmerOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedPattern(bool isDark) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return CustomPaint(
            painter: _PatternPainter(
              progress: _floatController.value,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingElements(bool isDark) {
    return Stack(
      children: [
        // Floating coin 1
        AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final offset = sin(_floatController.value * 2 * pi) * 10;
            return Positioned(
              right: 20,
              top: 20 + offset,
              child: Transform.rotate(
                angle: _floatController.value * 0.5,
                child: _build3DCoin(40, isDark),
              ),
            );
          },
        ),
        
        // Floating coin 2
        AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final offset = cos(_floatController.value * 2 * pi) * 8;
            return Positioned(
              right: 80,
              bottom: 25 + offset,
              child: Transform.rotate(
                angle: -_floatController.value * 0.3,
                child: _build3DCoin(28, isDark),
              ),
            );
          },
        ),
        
        // Floating wallet
        AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final offset = sin(_floatController.value * 2 * pi + 1) * 6;
            return Positioned(
              right: 50,
              top: 60 + offset,
              child: _build3DWallet(isDark),
            );
          },
        ),
        
        // Sparkles
        ..._buildSparkles(isDark),
      ],
    );
  }

  Widget _build3DCoin(double size, bool isDark) {
    final goldColor = isDark 
        ? const Color(0xFFFFD700) 
        : const Color(0xFFD4AF37);
    final shadowColor = isDark 
        ? const Color(0xFFB8860B) 
        : const Color(0xFFAA8C2C);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            goldColor.withValues(alpha: 1.0),
            shadowColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: goldColor.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '₹',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  Widget _build3DWallet(bool isDark) {
    final primaryColor = isDark 
        ? const Color(0xFF4A90D9) 
        : const Color(0xFF8B4513);
    
    return Container(
      width: 45,
      height: 35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            right: 4,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD700),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSparkles(bool isDark) {
    final sparkleColor = isDark 
        ? Colors.white.withValues(alpha: 0.6) 
        : const Color(0xFFD4AF37).withValues(alpha: 0.6);
    
    return List.generate(5, (index) {
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final phase = index * 0.2;
          final opacity = (sin((_floatController.value + phase) * 2 * pi) + 1) / 2;
          final scale = 0.5 + opacity * 0.5;
          
          return Positioned(
            right: 30 + index * 25.0,
            top: 30 + (index % 3) * 40.0,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sparkleColor.withValues(alpha: opacity * 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: sparkleColor.withValues(alpha: opacity * 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subtitleColor = isDark 
        ? Colors.white70 
        : const Color(0xFF1A1A2E).withValues(alpha: 0.7);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark 
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: const Color(0xFFD4AF37),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'WealthIn',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD4AF37),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.greeting,
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
          const SizedBox(height: 4),
          Text(
            widget.userName,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
          const SizedBox(height: 8),
          Text(
            'Your financial journey starts here ✨',
            style: TextStyle(
              fontSize: 13,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildShimmerOverlay() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2 * _shimmerController.value, 0),
                end: Alignment(-0.5 + 2 * _shimmerController.value, 0),
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PatternPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _PatternPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark 
          ? Colors.white.withValues(alpha: 0.03)
          : const Color(0xFFD4AF37).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw flowing curved lines
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final yOffset = size.height * 0.2 + i * size.height * 0.3;
      final xShift = sin(progress * 2 * pi + i) * 20;
      
      path.moveTo(-20 + xShift, yOffset);
      path.quadraticBezierTo(
        size.width * 0.3 + xShift,
        yOffset + 30 * sin(progress * 2 * pi),
        size.width * 0.6 + xShift,
        yOffset - 20,
      );
      path.quadraticBezierTo(
        size.width * 0.8 + xShift,
        yOffset - 40 * cos(progress * 2 * pi),
        size.width + 20 + xShift,
        yOffset + 10,
      );
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
