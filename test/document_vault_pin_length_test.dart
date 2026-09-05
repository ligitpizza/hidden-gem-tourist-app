import 'package:collab/features/travel_assistant/model/vault_pin_service.dart';
import 'package:collab/features/travel_assistant/view/travel_assistant_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('new vault asks for PIN length before showing inputs', (
    tester,
  ) async {
    await _pumpVault(tester, _FakeVaultPinService());

    expect(find.text('Choose PIN length'), findsOneWidget);
    expect(find.text('4 digits'), findsOneWidget);
    expect(find.text('6 digits'), findsOneWidget);
    expect(find.byKey(const ValueKey('Create PIN-pin-input')), findsNothing);
    expect(find.text('Create PIN & Continue'), findsNothing);
  });

  testWidgets('PIN choice controls box count and clears input when changed', (
    tester,
  ) async {
    await _pumpVault(tester, _FakeVaultPinService());

    await tester.tap(find.text('4 digits'));
    await tester.pump();

    expect(_pinBoxes('Create PIN'), findsNWidgets(4));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('Create PIN-pin-input')))
          .maxLength,
      4,
    );
    await tester.enterText(
      find.byKey(const ValueKey('Create PIN-pin-input')),
      '1234',
    );

    await tester.tap(find.text('6 digits'));
    await tester.pump();

    expect(_pinBoxes('Create PIN'), findsNWidgets(6));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('Create PIN-pin-input')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('selected PIN length is validated exactly', (tester) async {
    await _pumpVault(tester, _FakeVaultPinService());
    await tester.tap(find.text('4 digits'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('Create PIN-pin-input')),
      '123',
    );

    await tester.ensureVisible(find.text('Create PIN & Continue'));
    await tester.tap(find.text('Create PIN & Continue'));
    await tester.pump();

    expect(find.text('Enter a 4-digit PIN.'), findsOneWidget);
  });

  for (final length in [4, 6]) {
    testWidgets('existing $length-digit vault renders $length unlock boxes', (
      tester,
    ) async {
      await _pumpVault(
        tester,
        _FakeVaultPinService(storedPin: List.filled(length, '1').join()),
      );

      expect(find.text('Unlock Document Vault'), findsOneWidget);
      expect(find.text('Create Your Vault PIN'), findsNothing);
      expect(find.text('Choose PIN length'), findsNothing);
      expect(_pinBoxes('Vault PIN'), findsNWidgets(length));
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('Vault PIN-pin-input')),
            )
            .maxLength,
        length,
      );
    });
  }

  testWidgets('offline device without cache cannot create a conflicting PIN', (
    tester,
  ) async {
    await _pumpVault(tester, _FakeVaultPinService(unavailable: true));

    expect(find.text('Vault PIN unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Create Your Vault PIN'), findsNothing);
  });
}

Future<void> _pumpVault(
  WidgetTester tester,
  VaultPinServiceContract service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: DocumentVaultScreen(pinService: service)),
  );
  await tester.pumpAndSettle();
}

Finder _pinBoxes(String label) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('$label-pin-box-');
});

class _FakeVaultPinService implements VaultPinServiceContract {
  _FakeVaultPinService({this.storedPin, this.unavailable = false});

  String? storedPin;
  final bool unavailable;

  @override
  User get currentUser => throw UnimplementedError();

  @override
  Future<VaultPinStatus> loadStatus() async {
    if (unavailable) return const VaultPinStatus.unavailable();
    return storedPin == null
        ? const VaultPinStatus.notConfigured()
        : VaultPinStatus(
            availability: VaultPinAvailability.configured,
            pinLength: storedPin!.length,
            credentialVersion: 1,
            canVerifyOffline: true,
          );
  }

  @override
  Future<VaultPinVerification> verifyPin(String pin) async =>
      VaultPinVerification(
        status: pin == storedPin
            ? VaultPinVerificationStatus.verified
            : VaultPinVerificationStatus.incorrect,
        credentialVersion: 1,
      );

  @override
  Future<void> verifyCurrentPassword(String password) async {}

  @override
  Future<void> writePin(String pin) async => storedPin = pin;
}
