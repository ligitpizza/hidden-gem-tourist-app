import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class VaultPinServiceContract {
  User get currentUser;

  Future<String?> readPin();

  Future<void> writePin(String pin);

  Future<void> verifyCurrentPassword(String password);
}

class VaultPinService implements VaultPinServiceContract {
  VaultPinService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    SupabaseClient? client,
  }) : _storage = storage,
       _client = client ?? Supabase.instance.client;

  final FlutterSecureStorage _storage;
  final SupabaseClient _client;

  @override
  User get currentUser =>
      _client.auth.currentUser ??
      (throw const AuthException('A signed-in user is required.'));

  String get _pinKey => 'travel_vault_pin_${currentUser.id}';

  @override
  Future<String?> readPin() => _storage.read(key: _pinKey);

  @override
  Future<void> writePin(String pin) => _storage.write(key: _pinKey, value: pin);

  @override
  Future<void> verifyCurrentPassword(String password) async {
    final email = currentUser.email;
    if (email == null || email.isEmpty) {
      throw const AuthException('No email is available for this account.');
    }
    await _client.auth.signInWithPassword(email: email, password: password);
  }
}
