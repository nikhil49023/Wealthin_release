import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../main.dart' show isFirebaseAvailable;

class AuthService extends ChangeNotifier {
  // Only access Firebase instances if Firebase is available
  FirebaseAuth? _authInstance;


  FirebaseAuth get _auth {
    _authInstance ??= isFirebaseAvailable
        ? FirebaseAuth.instance
        : throw 'Firebase not available';
    return _authInstance!;
  }

  // Google Sign-In is only available on non-web platforms unless configured
  // On web, it requires a Google Client ID which is not set
  bool get _isWebPlatform => kIsWeb;

  // Lazy initialization flag for GoogleSignIn
  bool _googleSignInInitialized = false;
  bool _googleSignInAvailable = !kIsWeb; // Disabled on web by default
  
  // Store the current signed-in account
  GoogleSignInAccount? _currentGoogleAccount;

  /// Initialize Google Sign-In (must be called before using it)
  Future<void> initializeGoogleSignIn() async {
    if (_isWebPlatform || !isFirebaseAvailable || _googleSignInInitialized) return;
    
    try {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
      debugPrint('[AuthService] Google Sign-In initialized');
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In initialization failed: $e');
      _googleSignInAvailable = false;
    }
  }

  /// Get the current Google account (if signed in with Google)
  GoogleSignInAccount? get currentGoogleAccount => _currentGoogleAccount;

  // Firestore removed for local-only setup
  
  User? get currentUser => isFirebaseAvailable ? _auth.currentUser : null;
  bool get isAuthenticated => currentUser != null;
  Stream<User?> get authStateChanges =>
      isFirebaseAvailable ? _auth.authStateChanges() : Stream.value(null);

  /// Get current user ID safely (returns 'anonymous' if Firebase unavailable or no user)
  String get currentUserId => currentUser?.uid ?? 'anonymous';

  /// Check if Google Sign-In is available
  bool get isGoogleSignInAvailable =>
      _googleSignInAvailable && !_isWebPlatform && isFirebaseAvailable;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Register with email and password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      notifyListeners();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google
  /// Note: This only authenticates the user, Drive backup permission is requested separately
  Future<UserCredential?> signInWithGoogle() async {
    // Google Sign-In is not available on web without a client ID
    if (_isWebPlatform) {
      throw 'Google Sign-In is not available on web. Please use email login.';
    }

    if (!_googleSignInAvailable) {
      throw 'Google Sign-In is not configured. Please use email login.';
    }

    // Ensure Google Sign-In is initialized
    await initializeGoogleSignIn();
    
    if (!_googleSignInInitialized) {
      throw 'Google Sign-In is not available. Please use email login.';
    }

    try {
      // Trigger the authentication flow (no Drive scope - that's requested separately)
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email'],
      );

      // Store the account for later use
      _currentGoogleAccount = googleUser;

      // Get authentication tokens
      final googleAuth = googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      notifyListeners();
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User cancelled the sign-in
        return null;
      }
      throw 'Google sign-in failed: ${e.description ?? e.code}';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      // Mark Google Sign-In as unavailable if it fails due to configuration
      if (e.toString().contains('ClientID not set')) {
        _googleSignInAvailable = false;
        throw 'Google Sign-In is not configured. Please use email login.';
      }
      throw 'Google sign-in failed: $e';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (_googleSignInInitialized) {
        await GoogleSignIn.instance.signOut();
        _currentGoogleAccount = null;
      }
    } catch (_) {
      // Ignore Google sign-out errors
    }
    await _auth.signOut();
    notifyListeners();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Helper methods for profile management would go here if using local DB
  
  /// Get user profile (Mock implementation for now as Firestore is removed)
  Future<Map<String, dynamic>?> getUserProfile() async {
     if (currentUser == null) return null;
     return {
       'uid': currentUser!.uid,
       'email': currentUser!.email,
       'displayName': currentUser!.displayName,
     };
  }

  /// Update user preferences (Mock implementation)
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    // TODO: persist to local DB
  }

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.sendEmailVerification();
    }
  }

  /// Check if current user's email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Handle Firebase Auth exceptions with user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Invalid password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}
