import 'package:collab/features/travel_assistant/model/emergency_contact_repository.dart';
import 'package:collab/features/travel_assistant/model/vault_pin_service.dart';
import 'package:collab/features/travel_assistant/view/emergency_contacts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final length in [4, 6]) {
    testWidgets(
      'locked emergency contacts renders the configured $length-digit PIN',
      (tester) async {
        final pin = List.filled(length, '1').join();
        await tester.pumpWidget(
          MaterialApp(
            home: EmergencyContactsScreen(
              pinService: _FakeVaultPinService(pin),
              repository: EmergencyContactRepository(userId: 'test-user'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final label = 'Enter your $length-digit Vault PIN';
        final input = find.byKey(ValueKey('$label-pin-input'));
        expect(find.text(label), findsOneWidget);
        expect(_pinBoxes(label), findsNWidgets(length));
        expect(tester.widget<TextField>(input).maxLength, length);
        expect(find.text('Unlock contacts'), findsOneWidget);

        await tester.enterText(input, pin);
        await tester.pump();
        await tester.tap(find.text('Unlock contacts'));
        await tester.pumpAndSettle();

        expect(
          find.text('Vault unlocked. All contact details are available.'),
          findsOneWidget,
        );
      },
    );
  }
}

Finder _pinBoxes(String label) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('$label-pin-box-');
});

class _FakeVaultPinService implements VaultPinServiceContract {
  _FakeVaultPinService(this.pin);

  final String pin;

  @override
  User get currentUser => throw UnimplementedError();

  @override
  Future<VaultPinStatus> loadStatus() async => VaultPinStatus(
    availability: VaultPinAvailability.configured,
    pinLength: pin.length,
    credentialVersion: 1,
  );

  @override
  Future<VaultPinVerification> verifyPin(String value) async =>
      VaultPinVerification(
        status: value == pin
            ? VaultPinVerificationStatus.verified
            : VaultPinVerificationStatus.incorrect,
      );

  @override
  Future<void> verifyCurrentPassword(String password) async {}

  @override
  Future<void> writePin(String pin) async {}
}
