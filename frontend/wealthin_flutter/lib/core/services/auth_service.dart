import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<User?>? _idTokenSubscription;
  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;
  bool get isEmailVerified => _user?.emailVerified ?? false;

  AuthService() {
    _initialize();
  }

  void _initialize() {
    try {
      final auth = FirebaseAuth.instance;
      _user = auth.currentUser;

      // Listen to auth state changes
      _authStateSubscription = auth.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
        debugPrint('[AuthService] User changed: ${_user?.email}');
      });

      // Also track ID token updates so email verification refreshes in real time.
      _idTokenSubscription = auth.idTokenChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (error) {
      debugPrint(
        '[AuthService] Firebase is unavailable during startup: $error',
      );
      _user = null;
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      // Send verification email if not verified, but allow login to proceed
      if (refreshedUser != null && !refreshedUser.emailVerified) {
        try {
          await refreshedUser.sendEmailVerification();
          debugPrint('[AuthService] Verification email sent to ${refreshedUser.email}');
        } catch (e) {
          debugPrint('[AuthService] Failed to send verification email: $e');
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // Web Client ID from Firebase Console (for proper Android OAuth)
        clientId: '1078484188114-i9ljp9s8clrumn6jmiv6p7fui81h4c8a.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      debugPrint('[AuthService] Starting Google Sign-In...');
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('[AuthService] Google Sign-In was cancelled by user');
        throw 'Google Sign In was cancelled';
      }

      debugPrint('[AuthService] Google Sign-In successful: ${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('[AuthService] Firebase auth successful for ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Firebase auth error: ${e.code} - ${e.message}');
      throw _handleFirebaseError(e);
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In error: $e');
      throw 'Google Sign In failed: $e';
    }
  }

  /// Register with email and password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Enforce verified-email auth for production readiness.
      await credential.user?.sendEmailVerification();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Get current user asynchronously
  Future<User?> getCurrentUser() async {
    return _user;
  }

  Future<void> reloadCurrentUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    _user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }

  Future<void> resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw 'No authenticated user found';
    }
    await user.sendEmailVerification();
  }

  /// Get current user ID safely
  String get currentUserId => currentUser?.uid ?? 'anonymous';

  // Helper to map Firebase errors to user-friendly messages
  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Invalid email or password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return e.message ?? 'An authentication error occurred';
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _idTokenSubscription?.cancel();
    super.dispose();
  }
}
