import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  
  User? _user;
  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;

  AuthService() {
    _initialize();
  }

  void _initialize() {
    final session = Supabase.instance.client.auth.currentSession;
    _user = session?.user;
    
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
      debugPrint('[AuthService] User changed: ${_user?.email}');
    });
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw _handleSupabaseError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Register with email and password
  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      return response;
    } on AuthException catch (e) {
       throw _handleSupabaseError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleSupabaseError(e);
    }
  }

  /// Get current user ID safely
  String get currentUserId => currentUser?.id ?? 'anonymous';

  // Helper code to map Supabase errors to user-friendly messages
  String _handleSupabaseError(AuthException e) {
    // Supabase error messages are generally readable, but we can customize
    if (e.message.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (e.message.contains('User already registered')) {
      return 'An account already exists with this email';
    }
    return e.message;
  }
}

