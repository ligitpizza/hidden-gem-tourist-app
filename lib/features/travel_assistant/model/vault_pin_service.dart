import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum VaultPinAvailability { notConfigured, configured, unavailable }

class VaultPinStatus {
  const VaultPinStatus({
    required this.availability,
    this.pinLength,
    this.lockedUntil,
    this.credentialVersion,
    this.canVerifyOffline = false,
    this.remoteAvailable = true,
  });

  const VaultPinStatus.notConfigured()
    : this(availability: VaultPinAvailability.notConfigured);

  const VaultPinStatus.unavailable({bool canVerifyOffline = false})
    : this(
        availability: VaultPinAvailability.unavailable,
        canVerifyOffline: canVerifyOffline,
        remoteAvailable: false,
      );

  final VaultPinAvailability availability;
  final int? pinLength;
  final DateTime? lockedUntil;
  final int? credentialVersion;
  final bool canVerifyOffline;
  final bool remoteAvailable;

  bool get hasPin => availability == VaultPinAvailability.configured;
}

enum VaultPinVerificationStatus {
  verified,
  incorrect,
  locked,
  unavailable,
  notConfigured,
}

class VaultPinVerification {
  const VaultPinVerification({
    required this.status,
    this.attemptsRemaining,
    this.retryAfter,
    this.credentialVersion,
    this.usedOfflineCache = false,
  });

  final VaultPinVerificationStatus status;
  final int? attemptsRemaining;
  final Duration? retryAfter;
  final int? credentialVersion;
  final bool usedOfflineCache;

  bool get isVerified => status == VaultPinVerificationStatus.verified;
}

abstract class VaultPinServiceContract {
  User get currentUser;

  Future<VaultPinStatus> loadStatus();

  Future<VaultPinVerification> verifyPin(String pin);

  Future<void> writePin(String pin);

  Future<void> verifyCurrentPassword(String password);
}

abstract class VaultPinRemoteDataSource {
  Future<VaultPinStatus> loadStatus();

  Future<VaultPinVerification> verifyPin(String pin);

  Future<int> writePin(String pin);
}

class SupabaseVaultPinRemoteDataSource implements VaultPinRemoteDataSource {
  SupabaseVaultPinRemoteDataSource({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  static const _requestTimeout = Duration(seconds: 10);

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @override
  Future<VaultPinStatus> loadStatus() async {
    final value = await _client
        .rpc('get_travel_vault_pin_status')
        .timeout(_requestTimeout);
    final data = _asMap(value);
    if (data['configured'] != true) {
      return const VaultPinStatus.notConfigured();
    }

    return VaultPinStatus(
      availability: VaultPinAvailability.configured,
      pinLength: _asInt(data['pin_length']),
      lockedUntil: _asDateTime(data['locked_until']),
      credentialVersion: _asInt(data['credential_version']),
    );
  }

  @override
  Future<VaultPinVerification> verifyPin(String pin) async {
    final value = await _client
        .rpc('verify_travel_vault_pin', params: {'p_pin': pin})
        .timeout(_requestTimeout);
    final data = _asMap(value);
    final result = data['result'] as String?;
    final status = switch (result) {
      'verified' => VaultPinVerificationStatus.verified,
      'incorrect' => VaultPinVerificationStatus.incorrect,
      'locked' => VaultPinVerificationStatus.locked,
      'not_configured' => VaultPinVerificationStatus.notConfigured,
      _ => VaultPinVerificationStatus.unavailable,
    };

    return VaultPinVerification(
      status: status,
      attemptsRemaining: _asInt(data['attempts_remaining']),
      retryAfter: _durationFromSeconds(data['retry_after_seconds']),
      credentialVersion: _asInt(data['credential_version']),
    );
  }

  @override
  Future<int> writePin(String pin) async {
    final value = await _client
        .rpc('set_travel_vault_pin', params: {'p_pin': pin})
        .timeout(_requestTimeout);
    final data = _asMap(value);
    final version = _asInt(data['credential_version']);
    if (data['result'] != 'written' || version == null) {
      throw StateError('The vault PIN could not be saved.');
    }
    return version;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Unexpected vault PIN response.');
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static Duration? _durationFromSeconds(dynamic value) {
    final seconds = _asInt(value);
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

class VaultPinLocalCredential {
  const VaultPinLocalCredential({required this.pin, this.credentialVersion});

  final String pin;
  final int? credentialVersion;
}

abstract class VaultPinLocalDataSource {
  Future<VaultPinLocalCredential?> read(String userId);

  Future<void> write(
    String userId,
    String pin, {
    required int credentialVersion,
  });
}

class SecureStorageVaultPinLocalDataSource implements VaultPinLocalDataSource {
  SecureStorageVaultPinLocalDataSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _pinKey(String userId) => 'travel_vault_pin_$userId';

  String _versionKey(String userId) =>
      'travel_vault_pin_credential_version_$userId';

  @override
  Future<VaultPinLocalCredential?> read(String userId) async {
    final pin = await _storage.read(key: _pinKey(userId));
    if (pin == null || pin.isEmpty) return null;
    final rawVersion = await _storage.read(key: _versionKey(userId));
    return VaultPinLocalCredential(
      pin: pin,
      credentialVersion: int.tryParse(rawVersion ?? ''),
    );
  }

  @override
  Future<void> write(
    String userId,
    String pin, {
    required int credentialVersion,
  }) async {
    await _storage.write(key: _pinKey(userId), value: pin);
    await _storage.write(
      key: _versionKey(userId),
      value: credentialVersion.toString(),
    );
  }
}

class VaultPinService implements VaultPinServiceContract {
  VaultPinService({
    FlutterSecureStorage? storage,
    SupabaseClient? client,
    VaultPinRemoteDataSource? remote,
    VaultPinLocalDataSource? local,
    String? userId,
  }) : _clientOverride = client,
       _remote = remote ?? SupabaseVaultPinRemoteDataSource(client: client),
       _local = local ?? SecureStorageVaultPinLocalDataSource(storage: storage),
       _userIdOverride = userId;

  final SupabaseClient? _clientOverride;
  final VaultPinRemoteDataSource _remote;
  final VaultPinLocalDataSource _local;
  final String? _userIdOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  String get _userId => _userIdOverride ?? currentUser.id;

  @override
  User get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to use the document vault.');
    }
    return user;
  }

  @override
  Future<VaultPinStatus> loadStatus() async {
    VaultPinLocalCredential? localCredential;
    try {
      localCredential = await _local.read(_userId);
    } catch (_) {
      localCredential = null;
    }

    try {
      final remoteStatus = await _remote.loadStatus();
      if (remoteStatus.hasPin) {
        return VaultPinStatus(
          availability: VaultPinAvailability.configured,
          pinLength: remoteStatus.pinLength,
          lockedUntil: remoteStatus.lockedUntil,
          credentialVersion: remoteStatus.credentialVersion,
          canVerifyOffline: localCredential != null,
        );
      }

      if (localCredential == null) return remoteStatus;

      try {
        final version = await _remote.writePin(localCredential.pin);
        try {
          await _local.write(
            _userId,
            localCredential.pin,
            credentialVersion: version,
          );
        } catch (_) {}
        return VaultPinStatus(
          availability: VaultPinAvailability.configured,
          pinLength: localCredential.pin.length,
          credentialVersion: version,
          canVerifyOffline: true,
        );
      } catch (_) {
        return VaultPinStatus(
          availability: VaultPinAvailability.configured,
          pinLength: localCredential.pin.length,
          credentialVersion: localCredential.credentialVersion,
          canVerifyOffline: true,
          remoteAvailable: false,
        );
      }
    } catch (_) {
      if (localCredential == null) {
        return const VaultPinStatus.unavailable();
      }
      return VaultPinStatus(
        availability: VaultPinAvailability.configured,
        pinLength: localCredential.pin.length,
        credentialVersion: localCredential.credentialVersion,
        canVerifyOffline: true,
        remoteAvailable: false,
      );
    }
  }

  @override
  Future<VaultPinVerification> verifyPin(String pin) async {
    VaultPinVerification result;
    try {
      result = await _remote.verifyPin(pin);
    } catch (_) {
      VaultPinLocalCredential? localCredential;
      try {
        localCredential = await _local.read(_userId);
      } catch (_) {
        localCredential = null;
      }
      if (localCredential == null) {
        return const VaultPinVerification(
          status: VaultPinVerificationStatus.unavailable,
        );
      }
      return VaultPinVerification(
        status: localCredential.pin == pin
            ? VaultPinVerificationStatus.verified
            : VaultPinVerificationStatus.incorrect,
        credentialVersion: localCredential.credentialVersion,
        usedOfflineCache: true,
      );
    }

    if (result.isVerified) {
      try {
        final version = result.credentialVersion ?? 1;
        await _local.write(_userId, pin, credentialVersion: version);
      } catch (_) {
        // Online verification remains valid if secure local caching is denied.
      }
    }
    // Incorrect and locked cloud results are authoritative. A stale local PIN
    // must never override an explicit cloud rejection.
    return result;
  }

  @override
  Future<void> writePin(String pin) async {
    if (!RegExp(r'^(?:\d{4}|\d{6})$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 4 or 6 digits.');
    }
    final version = await _remote.writePin(pin);
    try {
      await _local.write(_userId, pin, credentialVersion: version);
    } catch (_) {
      // Cloud persistence is authoritative; local caching is best effort.
    }
  }

  @override
  Future<void> verifyCurrentPassword(String password) async {
    final email = currentUser.email;
    if (email == null || email.isEmpty) {
      throw StateError(
        'Password verification is unavailable for this account.',
      );
    }
    await _client.auth.signInWithPassword(email: email, password: password);
  }
}
