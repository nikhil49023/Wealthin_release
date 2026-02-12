import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// WealthIn Premium 3D Animated Splash Screen
/// Features: 3D rotating cube, morphing orbs, glassmorphism, smooth transitions
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({super.key, required this.onComplete});
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _orbController;
  late AnimationController _rotationController;
  late AnimationController _textController;
  Timer? _textAnimationTimer;
  Timer? _completionTimer;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoRotateY;
  late Animation<double> _logoRotateX;
  late Animation<double> _logoGlow;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressValue;
  
  final List<_FloatingOrb> _orbs = [];
  
  @override
  void initState() {
    super.initState();
    
    // Set status bar to transparent
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    // Initialize floating orbs for 3D effect
    for (int i = 0; i < 8; i++) {
      _orbs.add(_FloatingOrb.random());
    }
    
    // Main animation controller (3 seconds)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    
    // Orb floating controller (continuous)
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    
    // 3D rotation controller (continuous gentle motion)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
    
    // Text controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Logo scale animation (3D bounce in)
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_mainController);
    
    // 3D Y-axis rotation (initial spin-in)
    _logoRotateY = Tween<double>(begin: -math.pi / 2, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    
    // 3D X-axis tilt
    _logoRotateX = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    
    // Logo glow intensity
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeInOut),
      ),
    );
    
    // Text animations
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );
    
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Progress bar
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
    
    // Start animations
    _mainController.forward();
    
    // Start text animation after logo settles
    _textAnimationTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _textController.forward();
    });
    
    // Complete splash after full animation
    _completionTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      widget.onComplete();
    });
  }
  
  @override
  void dispose() {
    _textAnimationTimer?.cancel();
    _completionTimer?.cancel();
    _mainController.dispose();
    _orbController.dispose();
    _rotationController.dispose();
    _textController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A), // Deep navy/obsidian
      body: Stack(
        children: [
          // Animated gradient background
          _build3DBackground(),
          
          // Floating 3D orbs
          _buildFloatingOrbs(),
          
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                
                // 3D Animated Logo
                _build3DLogo(),
                
                const SizedBox(height: 40),
                
                // App Name with gradient
                _buildAnimatedText(),
                
                const Spacer(flex: 2),
                
                // Progress indicator
                _buildProgressIndicator(),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
          
          // Glassmorphism overlay at top
          _buildGlassOverlay(),
        ],
      ),
    );
  }
  
  Widget _build3DBackground() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        final rotationValue = _rotationController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(rotationValue * 2 * math.pi) * 0.3,
                math.cos(rotationValue * 2 * math.pi) * 0.2 - 0.3,
              ),
              radius: 1.8,
              colors: const [
                Color(0xFF1A2744), // Navy blue
                Color(0xFF0F1629), // Dark navy
                Color(0xFF0A0E1A), // Deep obsidian
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFloatingOrbs() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        return CustomPaint(
          painter: _OrbPainter(
            orbs: _orbs,
            progress: _orbController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
  
  Widget _build3DLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _rotationController]),
      builder: (context, child) {
        // Subtle continuous 3D motion after initial animation
        final continuousRotateY = _mainController.isCompleted
            ? math.sin(_rotationController.value * 2 * math.pi) * 0.05
            : 0.0;
        final continuousRotateX = _mainController.isCompleted
            ? math.cos(_rotationController.value * 2 * math.pi) * 0.03
            : 0.0;
        
        return Transform.scale(
          scale: _logoScale.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // Perspective
              ..rotateY(_logoRotateY.value + continuousRotateY)
              ..rotateX(_logoRotateX.value + continuousRotateX),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  // Primary glow - Gold/Amber
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(
                      0.4 * _logoGlow.value,
                    ),
                    blurRadius: 50,
                    spreadRadius: 15,
                  ),
                  // Secondary glow - Navy accent
                  BoxShadow(
                    color: const Color(0xFF4B7BEC).withOpacity(
                      0.3 * _logoGlow.value,
                    ),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  // Subtle shadow for depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E3A5F).withOpacity(0.9), // Dark navy
                        const Color(0xFF0D1B2A).withOpacity(0.95), // Deeper navy
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Image.asset(
                    'assets/wealthin_logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFallbackLogo() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFF5E6A3)],
          ).createShader(bounds),
          child: const Text(
            'W',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAnimatedText() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Opacity(
          opacity: _textFade.value,
          child: SlideTransition(
            position: _textSlide,
            child: Column(
              children: [
                // Main title with gold gradient
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFF5E6A3), Color(0xFFD4AF37)],
                  ).createShader(bounds),
                  child: Text(
                    'WealthIn',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tagline
                Text(
                  'Your Personal Finance AI',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF8B9DC3), // Muted navy-gray
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildProgressIndicator() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Column(
          children: [
            // Progress bar container
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  // Progress fill with gold gradient
                  FractionallySizedBox(
                    widthFactor: _progressValue.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFF5E6A3)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Loading text
            Text(
              _getLoadingText(_progressValue.value),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF8B9DC3),
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
  
  String _getLoadingText(double progress) {
    if (progress < 0.3) return 'Initializing...';
    if (progress < 0.6) return 'Loading AI Engine...';
    if (progress < 0.9) return 'Preparing Your Dashboard...';
    return 'Almost Ready...';
  }
  
  Widget _buildGlassOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 120,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0E1A).withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Floating orb class for 3D particle effect
class _FloatingOrb {
  double x;
  double y;
  double z; // Depth for 3D effect
  double size;
  double speed;
  double opacity;
  Color color;
  
  _FloatingOrb({
    required this.x,
    required this.y,
    required this.z,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
  
  factory _FloatingOrb.random() {
    final random = math.Random();
    final colors = [
      const Color(0xFFD4AF37), // Gold
      const Color(0xFF4B7BEC), // Blue accent
      const Color(0xFF1E3A5F), // Navy
    ];
    return _FloatingOrb(
      x: random.nextDouble(),
      y: random.nextDouble(),
      z: random.nextDouble() * 0.5 + 0.5, // 0.5 to 1.0 for depth
      size: random.nextDouble() * 40 + 20,
      speed: random.nextDouble() * 0.3 + 0.1,
      opacity: random.nextDouble() * 0.15 + 0.05,
      color: colors[random.nextInt(colors.length)],
    );
  }
}

// Custom painter for 3D orbs
class _OrbPainter extends CustomPainter {
  final List<_FloatingOrb> orbs;
  final double progress;
  
  _OrbPainter({required this.orbs, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final y = (orb.y + progress * orb.speed) % 1.0;
      final scaledSize = orb.size * orb.z; // Scale by depth
      final scaledOpacity = orb.opacity * orb.z; // Fade by depth
      
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withOpacity(scaledOpacity),
            orb.color.withOpacity(0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(orb.x * size.width, y * size.height),
            radius: scaledSize,
          ),
        );
      
      canvas.drawCircle(
        Offset(orb.x * size.width, y * size.height),
        scaledSize,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => true;
}
