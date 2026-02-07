import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

/// WealthIn Premium Animated Splash Screen
/// Features: Particle system, morphing logo, gradient animations
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({super.key, required this.onComplete});
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _textController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _logoGlow;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressValue;
  
  final List<_Particle> _particles = [];
  
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
    
    // Initialize particles
    for (int i = 0; i < 50; i++) {
      _particles.add(_Particle.random());
    }
    
    // Main animation controller (3 seconds)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    
    // Pulse controller (continuous)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Particle controller (continuous)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    
    // Text controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Logo scale animation (bounce in)
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_mainController);
    
    // Logo rotation (subtle 3D effect)
    _logoRotate = Tween<double>(begin: -0.1, end: 0.0).animate(
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
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
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
    Future.delayed(const Duration(milliseconds: 1200), () {
      _textController.forward();
    });
    
    // Complete splash after full animation
    Future.delayed(const Duration(milliseconds: 3500), () {
      widget.onComplete();
    });
  }
  
  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D08),
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(),
          
          // Particle system
          _buildParticleSystem(),
          
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                
                // Animated Logo
                _buildAnimatedLogo(),
                
                const SizedBox(height: 32),
                
                // App Name
                _buildAnimatedText(),
                
                const Spacer(flex: 2),
                
                // Progress indicator
                _buildProgressIndicator(),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
          
          // Glassmorphism overlay at top
          _buildTopOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3 + _pulseController.value * 0.1),
              radius: 1.5 + _pulseController.value * 0.2,
              colors: [
                const Color(0xFF0D1F14),
                const Color(0xFF040D08),
                Colors.black,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildParticleSystem() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            progress: _particleController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
  
  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScale.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_logoRotate.value),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  // Outer glow
                  BoxShadow(
                    color: const Color(0xFF50C878).withOpacity(
                      0.3 * _logoGlow.value + 0.1 * _pulseController.value,
                    ),
                    blurRadius: 40 + 10 * _pulseController.value,
                    spreadRadius: 10 + 5 * _pulseController.value,
                  ),
                  // Inner glow
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.2 * _logoGlow.value),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/wealthin_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallbackLogo(),
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
          colors: [Color(0xFF50C878), Color(0xFF2E8B57)],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Center(
        child: Text(
          'W',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
                // Main title with gradient
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFF2FBF5), Color(0xFF50C878)],
                  ).createShader(bounds),
                  child: Text(
                    'WealthIn',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                Text(
                  'Your Personal Finance AI',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF4A6353),
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
                color: const Color(0xFF0D1F14),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  // Progress fill
                  FractionallySizedBox(
                    widthFactor: _progressValue.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF50C878), Color(0xFFD4AF37)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF50C878).withOpacity(0.5),
                            blurRadius: 8,
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
                color: const Color(0xFF4A6353),
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
  
  Widget _buildTopOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 100,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// Particle class for the particle system
class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  Color color;
  
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
  
  factory _Particle.random() {
    final random = math.Random();
    return _Particle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: random.nextDouble() * 3 + 1,
      speed: random.nextDouble() * 0.5 + 0.2,
      opacity: random.nextDouble() * 0.5 + 0.1,
      color: random.nextBool() 
          ? const Color(0xFF50C878) 
          : const Color(0xFFD4AF37),
    );
  }
}

// Custom painter for particles
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  
  _ParticlePainter({required this.particles, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final y = (particle.y + progress * particle.speed) % 1.0;
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(particle.x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
