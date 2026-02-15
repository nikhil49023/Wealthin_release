import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../main.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';

/// Premium Register Screen with Firebase Auth - Simple single-step form
class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegisterSuccess;

  const RegisterScreen({super.key, required this.onRegisterSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      // Firebase sends email verification automatically if configured
      // await authService.sendEmailVerification();


      if (mounted) {
        // Show verification email sent message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email sent! Please check your inbox.'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );
        widget.onRegisterSuccess();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.gradientEnd.withValues(alpha: 0.1),
              Colors.white,
              AppTheme.gradientStart.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.success,
                AppTheme.success.withValues(alpha: 0.7),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.success.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 40,
            color: Colors.white,
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          'Create Account',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A202C),
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Text(
          'Fill in your details to get started',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: WealthInTheme.gray600,
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Password field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().shake(),

            // Register button
            FilledButton(
              onPressed: _isLoading ? null : _register,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            // Divider with "or"
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            const SizedBox(height: 24),

            // Google Sign Up Button
            OutlinedButton(
              onPressed: _isLoading ? null : _handleGoogleRegister,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _GoogleLogo(),
                  SizedBox(width: 12),
                  Text(
                    'Sign up with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Terms and conditions
            Text(
              'By creating an account, you agree to our Terms of Service and Privacy Policy',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WealthInTheme.gray500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Future<void> _handleGoogleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.signInWithGoogle();
      if (mounted) {
        widget.onRegisterSuccess();
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
      ..cubicTo(18.21 * s, 15.99 * s, 17.35 * s, 17.25 * s, 16.08 * s, 18.1 * s)
      ..lineTo(16.08 * s, 21.09 * s)
      ..lineTo(19.94 * s, 21.09 * s)
      ..cubicTo(22.21 * s, 19 * s, 23.5 * s, 15.93 * s, 23.5 * s, 12.27 * s)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green arc (bottom right)
    final Path greenPath = Path()
      ..moveTo(12 * s, 24 * s)
      ..cubicTo(15.24 * s, 24 * s, 17.95 * s, 22.92 * s, 19.94 * s, 21.09 * s)
      ..lineTo(16.08 * s, 18.1 * s)
      ..cubicTo(15 * s, 18.82 * s, 13.62 * s, 19.25 * s, 12 * s, 19.25 * s)
      ..cubicTo(8.87 * s, 19.25 * s, 6.22 * s, 17.14 * s, 5.27 * s, 14.29 * s)
      ..lineTo(1.29 * s, 14.29 * s)
      ..lineTo(1.29 * s, 17.38 * s)
      ..cubicTo(3.26 * s, 21.3 * s, 7.31 * s, 24 * s, 12 * s, 24 * s)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow arc (bottom left)
    final Path yellowPath = Path()
      ..moveTo(5.27 * s, 14.29 * s)
      ..cubicTo(5.02 * s, 13.57 * s, 4.88 * s, 12.8 * s, 4.88 * s, 12 * s)
      ..cubicTo(4.88 * s, 11.2 * s, 5.02 * s, 10.43 * s, 5.27 * s, 9.71 * s)
      ..lineTo(5.27 * s, 6.62 * s)
      ..lineTo(1.29 * s, 6.62 * s)
      ..cubicTo(0.47 * s, 8.24 * s, 0 * s, 10.06 * s, 0 * s, 12 * s)
      ..cubicTo(0 * s, 13.94 * s, 0.47 * s, 15.76 * s, 1.29 * s, 17.38 * s)
      ..lineTo(5.27 * s, 14.29 * s)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red arc (top)
    final Path redPath = Path()
      ..moveTo(12 * s, 4.75 * s)
      ..cubicTo(13.77 * s, 4.75 * s, 15.35 * s, 5.36 * s, 16.6 * s, 6.55 * s)
      ..lineTo(20 * s, 3.15 * s)
      ..cubicTo(17.95 * s, 1.19 * s, 15.24 * s, 0 * s, 12 * s, 0 * s)
      ..cubicTo(7.31 * s, 0 * s, 3.26 * s, 2.7 * s, 1.29 * s, 6.62 * s)
      ..lineTo(5.27 * s, 9.71 * s)
      ..cubicTo(6.22 * s, 6.86 * s, 8.87 * s, 4.75 * s, 12 * s, 4.75 * s)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

