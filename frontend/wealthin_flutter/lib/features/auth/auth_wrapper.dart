import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';
import 'login_screen.dart';

/// Auth Wrapper that checks authentication status and shows login or main app
/// Uses Firebase Auth state management for reactive updates
class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    // If Firebase is not available (e.g., Linux), skip auth and show main app directly
    if (!isFirebaseAvailable) {
      return widget.child;
    }

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen(context, 'Authenticating...');
        }

        final user = authService.currentUser;

        // If user is logged in, show main app
        if (user != null) {
          return widget.child;
        }

        // Otherwise show login screen
        return LoginScreen(
          onLoginSuccess: () {
            // Auth state will update automatically via StreamBuilder
          },
        );
      },
    );
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
