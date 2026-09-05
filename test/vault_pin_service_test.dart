import 'package:collab/features/travel_assistant/model/vault_pin_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VaultPinService', () {
    test('detects an existing cloud PIN on a new device', () async {
      final remote = _FakeRemote(pin: '123456');
      final service = VaultPinService(
        remote: remote,
        local: _MemoryLocal(),
        userId: 'user-a',
      );

      final status = await service.loadStatus();

      expect(status.hasPin, isTrue);
      expect(status.pinLength, 6);
      expect(status.canVerifyOffline, isFalse);
    });

    test('caches a correctly verified cloud PIN for offline use', () async {
      final local = _MemoryLocal();
      final remote = _FakeRemote(pin: '1234');
      final service = VaultPinService(
        remote: remote,
        local: local,
        userId: 'user-a',
      );

      final result = await service.verifyPin('1234');

      expect(result.status, VaultPinVerificationStatus.verified);
      expect((await local.read('user-a'))?.pin, '1234');
      expect((await local.read('user-a'))?.credentialVersion, 1);
    });

    test('does not use a stale cache after explicit cloud rejection', () async {
      final local = _MemoryLocal()..seed('user-a', '1111', 1);
      final remote = _FakeRemote(pin: '2222');
      final service = VaultPinService(
        remote: remote,
        local: local,
        userId: 'user-a',
      );

      final result = await service.verifyPin('1111');

      expect(result.status, VaultPinVerificationStatus.incorrect);
      expect(result.usedOfflineCache, isFalse);
    });

    test('allows offline verification only when a cache exists', () async {
      final local = _MemoryLocal()..seed('user-a', '1234', 2);
      final service = VaultPinService(
        remote: _FakeRemote(throwNetworkError: true),
        local: local,
        userId: 'user-a',
      );

      final correct = await service.verifyPin('1234');
      final incorrect = await service.verifyPin('9999');

      expect(correct.status, VaultPinVerificationStatus.verified);
      expect(correct.usedOfflineCache, isTrue);
      expect(incorrect.status, VaultPinVerificationStatus.incorrect);
      expect(incorrect.usedOfflineCache, isTrue);
    });

    test('reports unavailable when offline without a cache', () async {
      final service = VaultPinService(
        remote: _FakeRemote(throwNetworkError: true),
        local: _MemoryLocal(),
        userId: 'user-a',
      );

      expect(
        (await service.loadStatus()).availability,
        VaultPinAvailability.unavailable,
      );
      expect(
        (await service.verifyPin('1234')).status,
        VaultPinVerificationStatus.unavailable,
      );
    });

    test('migrates a legacy local-only PIN to cloud status', () async {
      final local = _MemoryLocal()..seed('user-a', '654321', null);
      final remote = _FakeRemote();
      final service = VaultPinService(
        remote: remote,
        local: local,
        userId: 'user-a',
      );

      final status = await service.loadStatus();

      expect(remote.pin, '654321');
      expect(status.hasPin, isTrue);
      expect(status.pinLength, 6);
      expect(status.credentialVersion, 1);
      expect((await local.read('user-a'))?.credentialVersion, 1);
    });

    test('returns a five-attempt lockout response', () async {
      final service = VaultPinService(
        remote: _FakeRemote(pin: '1234'),
        local: _MemoryLocal(),
        userId: 'user-a',
      );

      VaultPinVerification? result;
      for (var attempt = 0; attempt < 5; attempt++) {
        result = await service.verifyPin('9999');
      }

      expect(result?.status, VaultPinVerificationStatus.locked);
      expect(result?.retryAfter, const Duration(minutes: 5));
    });

    test('PIN reset updates the cached credential version', () async {
      final local = _MemoryLocal();
      final remote = _FakeRemote(pin: '1234');
      final service = VaultPinService(
        remote: remote,
        local: local,
        userId: 'user-a',
      );

      await service.writePin('654321');

      expect(remote.pin, '654321');
      expect((await local.read('user-a'))?.credentialVersion, 2);
    });
  });
}

class _FakeRemote implements VaultPinRemoteDataSource {
  _FakeRemote({this.pin, this.throwNetworkError = false});

  String? pin;
  bool throwNetworkError;
  int version = 1;
  int failures = 0;

  void _checkNetwork() {
    if (throwNetworkError) throw Exception('offline');
  }

  @override
  Future<VaultPinStatus> loadStatus() async {
    _checkNetwork();
    if (pin == null) return const VaultPinStatus.notConfigured();
    return VaultPinStatus(
      availability: VaultPinAvailability.configured,
      pinLength: pin!.length,
      credentialVersion: version,
    );
  }

  @override
  Future<VaultPinVerification> verifyPin(String candidate) async {
    _checkNetwork();
    if (pin == null) {
      return const VaultPinVerification(
        status: VaultPinVerificationStatus.notConfigured,
      );
    }
    if (candidate == pin) {
      failures = 0;
      return VaultPinVerification(
        status: VaultPinVerificationStatus.verified,
        credentialVersion: version,
      );
    }
    failures++;
    if (failures >= 5) {
      return VaultPinVerification(
        status: VaultPinVerificationStatus.locked,
        retryAfter: const Duration(minutes: 5),
        credentialVersion: version,
      );
    }
    return VaultPinVerification(
      status: VaultPinVerificationStatus.incorrect,
      attemptsRemaining: 5 - failures,
      credentialVersion: version,
    );
  }

  @override
  Future<int> writePin(String value) async {
    _checkNetwork();
    version = pin == null ? 1 : version + 1;
    pin = value;
    failures = 0;
    return version;
  }
}

class _MemoryLocal implements VaultPinLocalDataSource {
  final Map<String, VaultPinLocalCredential> values = {};

  void seed(String userId, String pin, int? version) {
    values[userId] = VaultPinLocalCredential(
      pin: pin,
      credentialVersion: version,
    );
  }

  @override
  Future<VaultPinLocalCredential?> read(String userId) async => values[userId];

  @override
  Future<void> write(
    String userId,
    String pin, {
    required int credentialVersion,
  }) async {
    seed(userId, pin, credentialVersion);
  }
}
