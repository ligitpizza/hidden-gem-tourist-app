import 'package:flutter/widgets.dart';

/// Shared client-side validation rules for the login/signup forms. Real
/// account rules (uniqueness, actual min password length, etc.) are still
/// enforced server-side by Supabase Auth — these just give fast feedback.
class AuthValidators {
  AuthValidators._();

  static final _emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[a-zA-Z]{2,}$');

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? Function(String?) confirmPassword(TextEditingController passwordField) {
    return (value) {
      final v = value ?? '';
      if (v.isEmpty) return 'Confirm your password';
      if (v != passwordField.text) return 'Passwords do not match';
      return null;
    };
  }

  static String? fullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Name is required';
    if (trimmed.length < 2) return 'Name is too short';
    return null;
  }
}
