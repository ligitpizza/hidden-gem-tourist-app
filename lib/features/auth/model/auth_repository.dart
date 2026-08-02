import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth (real email/password accounts — no
/// mock/local auth), matching the module's repository-layer convention.
class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  bool get isLoggedIn => _client.auth.currentSession != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }
}
