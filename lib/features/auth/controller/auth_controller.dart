import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/auth_repository.dart';

/// Business logic for the login/signup screens. Kept as a plain
/// [ChangeNotifier] per the project's MVC convention, bridged into the app
/// via Riverpod's [ChangeNotifierProvider].
class AuthController extends ChangeNotifier {
  AuthController({AuthRepository? repository}) : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool isSubmitting = false;
  String? errorMessage;

  bool get isLoggedIn => _repository.isLoggedIn;

  /// Returns true on success. Sets [errorMessage] (surfaced by the screen)
  /// and returns false otherwise.
  Future<bool> login({required String email, required String password}) async {
    return _submit(() => _repository.signIn(email: email, password: password));
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return _submit(
      () => _repository.signUp(fullName: fullName, email: email, password: password),
    );
  }

  Future<bool> _submit(Future<void> Function() action) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await action();
      isSubmitting = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      isSubmitting = false;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Check your connection and try again.';
      isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Returns true if the reset email was sent. Errors are surfaced via
  /// [errorMessage] the same way login/signup failures are.
  Future<bool> resetPassword(String email) async {
    return _submit(() => _repository.resetPassword(email));
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }
}

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController();
});
