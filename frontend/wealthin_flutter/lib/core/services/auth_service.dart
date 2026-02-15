import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  StreamSubscription<User?>? _authStateSubscription;
  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;

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
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw 'Google Sign In was cancelled';
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
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
    super.dispose();
  }
}
