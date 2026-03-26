import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/indian_theme.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/wealthin_logo.dart';

/// Premium AMOLED-Safe Splash Screen
/// Features: Dark-first aesthetic, canvas-drawn logo bloom, Syne typography
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _startSequence();
  }

  void _startSequence() async {
    // 1. Start logo scale and rotation
    _logoController.forward();

    // 2. Start text fade in
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) _textController.forward();

    // 3. Complete splash
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IndianTheme.deepOnyx,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: IndianTheme.amoledGradient,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background: Subtle pulsing mandala rings
            _buildBackgroundMandala(),

            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo Glyph
                _buildAnimatedLogo(),

                const SizedBox(height: 48),

                // App Name (Syne font)
                _buildAppName(),

                const SizedBox(height: 12),

                // Premium Tagline (DM Sans)
                _buildTagline(),
              ],
            ),

            // Bottom loading detail
            _buildBottomIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundMandala() {
    return Opacity(
      opacity: 0.05,
      child: AnimatedBuilder(
        animation: _logoController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _logoController.value * 0.2,
            child: CustomPaint(
              size: const Size(600, 600),
              painter: _MandalaBackdropPainter(color: AppTheme.saffron),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
      child: RotationTransition(
        turns: CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.peacockTeal.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 20,
              ),
            ],
          ),
          child: SizedBox(
            width: 120,
            height: 120,
            child: WealthInLogo(size: 100),
          ),
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return FadeTransition(
      opacity: _textController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic)),
        child: Text(
          'WealthIn',
          style: GoogleFonts.syne(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: AppTheme.pearlWhite,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _textController,
      child: Text(
        'The Dharma of Financial Growth',
        style: GoogleFonts.dmSans(
          fontSize: 15,
          color: AppTheme.silverMist,
          letterSpacing: 2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomIndicator() {
    return Positioned(
      bottom: 60,
      child: FadeTransition(
        opacity: _textController,
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.saffron.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Artha Intelligence Initializing',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppTheme.silverMist.withValues(alpha: 0.4),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MandalaBackdropPainter extends CustomPainter {
  final Color color;
  _MandalaBackdropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 8; i++) {
      canvas.drawCircle(center, radius * (i + 1) / 8, paint);
    }

    for (int i = 0; i < 24; i++) {
      final angle = (i * 2 * pi) / 24;
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * (radius * 0.1),
        center + Offset(cos(angle), sin(angle)) * radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
