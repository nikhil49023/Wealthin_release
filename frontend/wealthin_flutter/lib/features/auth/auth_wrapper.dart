import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../main.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';
import 'login_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Auth Wrapper that checks authentication status and shows login or main app
/// Uses Firebase Auth via AuthService (ChangeNotifier)
class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Timer? _verificationBannerTimer;
  String? _verificationBannerUserId;
  bool _showVerificationBanner = true;

  @override
  void dispose() {
    _verificationBannerTimer?.cancel();
    super.dispose();
  }

  void _startVerificationBannerTimer(String userId) {
    if (_verificationBannerUserId == userId && _verificationBannerTimer != null) {
      return;
    }

    _verificationBannerTimer?.cancel();
    _verificationBannerUserId = userId;
    _showVerificationBanner = true;

    _verificationBannerTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _verificationBannerUserId != userId) return;
      setState(() => _showVerificationBanner = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        final user = authService.currentUser;

        // If user is logged in, show main app or onboarding
        if (user != null) {
          return FutureBuilder<bool>(
            future: _checkOnboardingComplete(),
            builder: (context, snapshot) {
              // Show loading while checking onboarding status
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen(context, 'Setting up your vault...');
              }

              final onboardingComplete = snapshot.data ?? false;

              if (onboardingComplete) {
                // Show email verification prompt if not verified, but allow app access
                if (!authService.isEmailVerified) {
                  _startVerificationBannerTimer(user.uid);
                  return _buildAppWithVerificationPrompt(context, user.uid, user.email ?? 'your email');
                }
                return widget.child;
              } else {
                return OnboardingScreen(
                  onComplete: () {
                    // Force rebuild to re-check status
                    setState(() {});
                  },
                );
              }
            },
          );
        }

        // Otherwise show login screen
        return LoginScreen(
          onLoginSuccess: () {
            // Auth state will update automatically via ListenableBuilder
          },
        );
      },
    );
  }

  Widget _buildAppWithVerificationPrompt(BuildContext context, String userId, String email) {
    if (!_showVerificationBanner) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        // Non-blocking verification prompt banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.mail_outline,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify your email',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Check your inbox for a verification link',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: Colors.blue[700],
                    onPressed: () => setState(() => _showVerificationBanner = false),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await authService.resendVerificationEmail();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification email resent'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Resend'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _checkOnboardingComplete() async {
    // 1. Check local storage first (fastest)
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('onboarding_complete') ?? false) {
      return true;
    }

    // 2. If not found locally, check Firestore profile
    try {
      final user = authService.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (doc.exists && doc.data()?['has_completed_onboarding'] == true) {
          // Sync back to local storage
          await prefs.setBool('onboarding_complete', true);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
    }

    return false;
  }


  Widget _buildLoadingScreen(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF0), // Mint green background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.mint,
              Colors.white,
              AppTheme.mintDark,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sovereign Vault Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.emerald,
                      AppTheme.emeraldLight,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // Rotating purple loader
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF7C3AED), // Purple
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Status message
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF7C3AED), // Purple text
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Privacy message
              Text(
                'Your data moves directly from your vault to your device',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WealthInTheme.gray600,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Lock icon to emphasize privacy
              Icon(
                Icons.lock_outline,
                color: WealthInTheme.gray400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
