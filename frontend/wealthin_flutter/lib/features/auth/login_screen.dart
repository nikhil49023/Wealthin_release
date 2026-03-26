import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../core/theme/indian_theme.dart';
import '../../core/widgets/indian_patterns.dart';
import '../../core/widgets/glassmorphic.dart';
import 'register_screen.dart';

/// Premium Indian-Inspired Login Screen with Glassmorphism
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _gradientController;
  late AnimationController _mandalaController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _mandalaController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _gradientController.dispose();
    _mandalaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.signInWithGoogle();
      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: IndianTheme.sunriseGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Reset Password',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: GoogleFonts.poppins(
                color: IndianTheme.templeStone,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            GlassTextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              labelText: 'Email',
              prefixIcon: Icons.email_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: IndianTheme.templeStone),
            ),
          ),
          Container(
            decoration: IndianTheme.goldButtonDecoration(),
            child: TextButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid email'),
                      backgroundColor: IndianTheme.vermillion,
                    ),
                  );
                  return;
                }

                try {
                  await authService.sendPasswordResetEmail(email);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset email sent to $email'),
                        backgroundColor: IndianTheme.mehendiGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: IndianTheme.vermillion,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Send Reset Link',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(),

          // Floating particles
          _buildFloatingParticles(),

          // Background patterns
          _buildBackgroundPatterns(),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildLoginForm(),
                      const SizedBox(height: 24),
                      _buildRegisterLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                IndianTheme.kesarCream,
                IndianTheme.goldShimmer,
                IndianTheme.lotusPetal.withValues(alpha: 0.3),
                IndianTheme.marbleCream,
              ],
              stops: [
                0,
                0.3 + (_gradientController.value * 0.2),
                0.6 + (_gradientController.value * 0.2),
                1,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingParticles() {
    final random = Random(42);
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: List.generate(12, (index) {
        final size = 3.0 + random.nextDouble() * 5;
        final left = random.nextDouble() * screenSize.width;
        final top = random.nextDouble() * screenSize.height;

        return Positioned(
          left: left,
          top: top,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: IndianTheme.royalGold
                  .withValues(alpha: 0.3 + random.nextDouble() * 0.3),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 2.seconds)
              .then()
              .fadeOut(duration: 2.seconds)
              .moveY(begin: 0, end: -15, duration: 4.seconds),
        );
      }),
    );
  }

  Widget _buildBackgroundPatterns() {
    return Stack(
      children: [
        // Top-right mandala
        Positioned(
          top: -60,
          right: -60,
          child: AnimatedBuilder(
            animation: _mandalaController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _mandalaController.value * 2 * pi,
                child: MandalaPattern(
                  size: 200,
                  color: IndianTheme.saffron,
                  opacity: 0.08,
                ),
              );
            },
          ),
        ),

        // Bottom-left mandala
        Positioned(
          bottom: -80,
          left: -80,
          child: AnimatedBuilder(
            animation: _mandalaController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_mandalaController.value * 2 * pi * 0.5,
                child: MandalaPattern(
                  size: 250,
                  color: IndianTheme.peacockBlue,
                  opacity: 0.06,
                ),
              );
            },
          ),
        ),

        // Rangoli corners
        const RangoliCornerPattern(
          size: 100,
          alignment: Alignment.topLeft,
          color: IndianTheme.lotusPink,
        ),
        const RangoliCornerPattern(
          size: 80,
          alignment: Alignment.bottomRight,
          color: IndianTheme.turmeric,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Animated logo with glow
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: IndianTheme.templeSunsetGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: IndianTheme.saffron.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: IndianTheme.royalGold.withValues(alpha: 0.3),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 56,
            color: Colors.white,
          ),
        )
            .animate()
            .scale(duration: 800.ms, curve: Curves.elasticOut)
            .fadeIn(),
        const SizedBox(height: 28),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              IndianTheme.saffronDeep,
              IndianTheme.royalGold,
              IndianTheme.saffronDeep,
            ],
          ).createShader(bounds),
          child: Text(
            'WealthIn',
            style: GoogleFonts.playfairDisplay(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'Your Sovereign Financial Companion',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: IndianTheme.templeStone,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildLoginForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.8),
                IndianTheme.goldShimmer.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: IndianTheme.royalGold.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: IndianTheme.templeStone.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: IndianTheme.sunriseGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sign In',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: IndianTheme.templeGranite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Email field
                GlassTextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                GlassTextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outlined,
                  suffixIcon:
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  onSuffixTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.poppins(
                        color: IndianTheme.peacockBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: IndianTheme.vermillion.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: IndianTheme.vermillion.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: IndianTheme.vermillion,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              color: IndianTheme.vermillion,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().shake(),

                // Login button
                GlassButton(
                  text: 'Sign In',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _login,
                  gradient: IndianTheme.templeSunsetGradient,
                ),

                const SizedBox(height: 24),

                // Divider with "or"
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              IndianTheme.templeStone.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or continue with',
                        style: GoogleFonts.poppins(
                          color: IndianTheme.templeStone,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              IndianTheme.templeStone.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Google Sign In Button
                _buildGoogleButton(),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isLoading || _isGoogleLoading ? null : _handleGoogleLogin,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: IndianTheme.templeStone.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: IndianTheme.templeStone.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isGoogleLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    IndianTheme.templeStone,
                  ),
                ),
              )
            else
              const _GoogleLogo(),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: IndianTheme.templeGranite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.poppins(color: IndianTheme.templeStone),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RegisterScreen(
                  onRegisterSuccess: widget.onLoginSuccess,
                ),
              ),
            );
          },
          child: ShaderMask(
            shaderCallback: (bounds) => IndianTheme.sunriseGradient.createShader(bounds),
            child: Text(
              'Sign Up',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}

/// Google logo using custom paint for reliability
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;

    // Google G logo colors
    final Paint bluePaint = Paint()..color = const Color(0xFF4285F4);
    final Paint greenPaint = Paint()..color = const Color(0xFF34A853);
    final Paint yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final Paint redPaint = Paint()..color = const Color(0xFFEA4335);

    // Blue arc (right side)
    final Path bluePath = Path()
      ..moveTo(23.5 * s, 12.27 * s)
      ..cubicTo(23.5 * s, 11.48 * s, 23.42 * s, 10.73 * s, 23.29 * s, 10 * s)
      ..lineTo(12 * s, 10 * s)
      ..lineTo(12 * s, 14.51 * s)
      ..lineTo(18.47 * s, 14.51 * s)
      ..cubicTo(18.18 * s, 15.99 * s, 17.34 * s, 17.25 * s, 16.08 * s, 18.1 * s)
      ..lineTo(16.08 * s, 21.09 * s)
      ..lineTo(19.94 * s, 21.09 * s)
      ..cubicTo(22.21 * s, 19.01 * s, 23.5 * s, 15.92 * s, 23.5 * s, 12.27 * s)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green arc (bottom)
    final Path greenPath = Path()
      ..moveTo(12 * s, 24 * s)
      ..cubicTo(15.24 * s, 24 * s, 17.95 * s, 22.92 * s, 19.94 * s, 21.09 * s)
      ..lineTo(16.08 * s, 18.1 * s)
      ..cubicTo(14.99 * s, 18.84 * s, 13.62 * s, 19.27 * s, 12 * s, 19.27 * s)
      ..cubicTo(8.87 * s, 19.27 * s, 6.23 * s, 17.16 * s, 5.27 * s, 14.29 * s)
      ..lineTo(1.29 * s, 14.29 * s)
      ..lineTo(1.29 * s, 17.35 * s)
      ..cubicTo(3.26 * s, 21.25 * s, 7.31 * s, 24 * s, 12 * s, 24 * s)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow arc (left bottom)
    final Path yellowPath = Path()
      ..moveTo(5.27 * s, 14.29 * s)
      ..cubicTo(5.02 * s, 13.54 * s, 4.89 * s, 12.78 * s, 4.89 * s, 12 * s)
      ..cubicTo(4.89 * s, 11.22 * s, 5.03 * s, 10.46 * s, 5.27 * s, 9.71 * s)
      ..lineTo(5.27 * s, 6.65 * s)
      ..lineTo(1.29 * s, 6.65 * s)
      ..cubicTo(0.47 * s, 8.29 * s, 0 * s, 10.09 * s, 0 * s, 12 * s)
      ..cubicTo(0 * s, 13.91 * s, 0.47 * s, 15.71 * s, 1.29 * s, 17.35 * s)
      ..lineTo(5.27 * s, 14.29 * s)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red arc (top)
    final Path redPath = Path()
      ..moveTo(12 * s, 4.73 * s)
      ..cubicTo(13.77 * s, 4.73 * s, 15.36 * s, 5.33 * s, 16.6 * s, 6.47 * s)
      ..lineTo(19.99 * s, 3.09 * s)
      ..cubicTo(17.93 * s, 1.18 * s, 15.24 * s, 0 * s, 12 * s, 0 * s)
      ..cubicTo(7.31 * s, 0 * s, 3.26 * s, 2.75 * s, 1.29 * s, 6.65 * s)
      ..lineTo(5.27 * s, 9.71 * s)
      ..cubicTo(6.23 * s, 6.84 * s, 8.87 * s, 4.73 * s, 12 * s, 4.73 * s)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
