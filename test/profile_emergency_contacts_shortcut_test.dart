import 'dart:convert';

import 'package:collab/core/router/shell_routes.dart';
import 'package:collab/features/profile/view/widgets/profile_emergency_contacts_shortcut.dart';
import 'package:collab/features/travel_assistant/model/emergency_contact.dart';
import 'package:collab/features/travel_assistant/model/emergency_contact_repository.dart';
import 'package:collab/features/travel_assistant/model/vault_pin_service.dart';
import 'package:collab/features/travel_assistant/view/emergency_contacts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'travel_emergency_contacts_test-user': jsonEncode([
        _approved.toJson(),
        _private.toJson(),
      ]),
    });
  });

  testWidgets(
    'Profile shortcut opens locked contacts and both back actions return',
    (tester) async {
      final repository = EmergencyContactRepository(userId: 'test-user');
      late final GoRouter router;
      router = GoRouter(
        initialLocation: ShellRoutes.profile,
        routes: [
          GoRoute(
            path: ShellRoutes.profile,
            builder: (context, state) => Scaffold(
              body: ProfileEmergencyContactsShortcut(
                onTap: () => context.push(ShellRoutes.profileEmergencyContacts),
              ),
            ),
            routes: [
              GoRoute(
                path: 'emergency-contacts',
                builder: (context, state) => EmergencyContactsScreen(
                  repository: repository,
                  pinService: _ConfiguredPinService(),
                  fallbackPath: ShellRoutes.profile,
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Contacts'), findsOneWidget);
      expect(find.text('Call approved contacts without a PIN'), findsOneWidget);

      Future<void> openLockedContacts() async {
        await tester.tap(find.text('Emergency Contacts'));
        await tester.pumpAndSettle();
        expect(find.text('Approved Contact'), findsOneWidget);
        expect(find.text('Private Contact'), findsNothing);
        expect(find.text('approved@example.com'), findsNothing);
        expect(find.byTooltip('Call'), findsOneWidget);
        expect(find.text('Unlock contacts'), findsOneWidget);
        expect(find.text('Add contact'), findsNothing);
      }

      await openLockedContacts();
      await tester.enterText(
        find.byKey(const ValueKey('Enter your 4-digit Vault PIN-pin-input')),
        '1234',
      );
      await tester.pump();
      await tester.tap(find.text('Unlock contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Private Contact'), findsOneWidget);
      expect(find.text('approved@example.com'), findsOneWidget);
      expect(find.text('Add contact'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        ShellRoutes.profile,
      );
      expect(find.text('Call approved contacts without a PIN'), findsOneWidget);

      await openLockedContacts();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        ShellRoutes.profile,
      );
      expect(find.text('Call approved contacts without a PIN'), findsOneWidget);
    },
  );
}

const _approved = EmergencyContact(
  id: 'approved',
  name: 'Approved Contact',
  relationship: 'Sibling',
  phone: '+60111111111',
  country: 'Malaysia',
  email: 'approved@example.com',
  notes: 'Private note',
  availableWhenLocked: true,
);

const _private = EmergencyContact(
  id: 'private',
  name: 'Private Contact',
  relationship: 'Friend',
  phone: '+60222222222',
  country: 'Malaysia',
  email: 'private@example.com',
  availableWhenLocked: false,
);

class _ConfiguredPinService implements VaultPinServiceContract {
  @override
  User get currentUser => throw UnimplementedError();

  @override
  Future<VaultPinStatus> loadStatus() async => const VaultPinStatus(
    availability: VaultPinAvailability.configured,
    pinLength: 4,
    credentialVersion: 1,
  );

  @override
  Future<VaultPinVerification> verifyPin(String pin) async =>
      VaultPinVerification(
        status: pin == '1234'
            ? VaultPinVerificationStatus.verified
            : VaultPinVerificationStatus.incorrect,
      );

  @override
  Future<void> verifyCurrentPassword(String password) async {}

  @override
  Future<void> writePin(String pin) async {}
}
