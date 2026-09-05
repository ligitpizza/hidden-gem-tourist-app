import 'package:collab/features/travel_assistant/model/travel_document.dart';
import 'package:collab/features/travel_assistant/model/travel_document_repository.dart';
import 'package:collab/features/travel_assistant/model/vault_pin_service.dart';
import 'package:collab/features/travel_assistant/view/travel_assistant_screens.dart';
import 'package:collab/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const userId = 'vault-filter-test-user';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'travel_vault_documents_v3_$userId': TravelDocument.encodeList(
        _documents,
      ),
    });
  });

  testWidgets('filter sheet supports counts, multiple categories, and reset', (
    tester,
  ) async {
    await _pumpUnlockedVault(tester, userId: userId);

    expect(find.text('3 documents'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vault-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Filter documents'), findsOneWidget);
    expect(find.text('1 document'), findsNWidgets(3));

    await tester.tap(find.byKey(const Key('vault-filter-Passports')));
    await tester.tap(find.byKey(const Key('vault-filter-Insurance')));
    await tester.tap(find.byKey(const Key('vault-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text('Passport Copy'), findsOneWidget);
    expect(find.text('Hotel Stay'), findsNothing);
    expect(find.text('2 of 3 documents'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('vault-document-policy')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Policy'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vault-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vault-filter-reset')));
    await tester.tap(find.byKey(const Key('vault-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text('3 documents'), findsOneWidget);
  });

  testWidgets(
    'category filters combine with search and search clears selection',
    (tester) async {
      await _pumpUnlockedVault(tester, userId: userId);

      await _tapDocumentCard(tester, 'passport');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'hotel');
      await tester.pump();
      expect(find.text('Hotel Stay'), findsOneWidget);
      expect(find.text('1 of 3 documents'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNothing);

      await tester.tap(find.byKey(const Key('vault-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vault-filter-Bookings')));
      await tester.tap(find.byKey(const Key('vault-filter-apply')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'policy');
      await tester.pump();

      expect(find.text('No matching documents'), findsOneWidget);
    },
  );

  testWidgets('known and unknown categories use their subtle card accents', (
    tester,
  ) async {
    final docs = [
      _documents.first,
      TravelDocument(
        id: 'unknown',
        displayName: 'Custom Permit',
        category: 'Permits',
        originalFileName: 'permit.pdf',
        storedPath: 'missing-permit.pdf',
        extension: 'pdf',
        fileSize: 120,
        createdAt: DateTime(2026, 8, 1),
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'travel_vault_documents_v3_$userId': TravelDocument.encodeList(docs),
    });
    const scheme = ColorScheme.light(surface: Color(0xFFFDFCFB));
    await _pumpUnlockedVault(
      tester,
      userId: userId,
      theme: ThemeData(colorScheme: scheme),
    );

    final passport = tester.widget<Card>(
      find.byKey(const Key('vault-document-passport')),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('vault-document-unknown')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final unknown = tester.widget<Card>(
      find.byKey(const Key('vault-document-unknown')),
    );

    expect(
      passport.color,
      Color.alphaBlend(
        const Color(0xFF1565C0).withValues(alpha: .08),
        scheme.surface,
      ),
    );
    expect(
      unknown.color,
      Color.alphaBlend(
        const Color(0xFF546E7A).withValues(alpha: .08),
        scheme.surface,
      ),
    );

    await _tapDocumentCard(tester, 'passport');
    await tester.pump();
    final selected = tester.widget<Card>(
      find.byKey(const Key('vault-document-passport')),
    );
    expect(
      (selected.shape! as RoundedRectangleBorder).side.color,
      scheme.primary,
    );
  });

  testWidgets('vault layout remains usable on a narrow dark screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpUnlockedVault(tester, userId: userId, theme: ThemeData.dark());
    await tester.tap(find.byKey(const Key('vault-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('Filter documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter and selection updates keep semantics stable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpUnlockedVault(tester, userId: userId);

    await tester.tap(find.byKey(const Key('vault-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vault-filter-Passports')));
    await tester.tap(find.byKey(const Key('vault-filter-apply')));
    await tester.pumpAndSettle();
    await _tapDocumentCard(tester, 'passport');
    await tester.pumpAndSettle();

    expect(find.text('1 of 3 documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _pumpUnlockedVault(
  WidgetTester tester, {
  required String userId,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: DocumentVaultScreen(
        pinService: _ConfiguredPinService(),
        repository: TravelDocumentRepository(userId: userId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('Vault PIN-pin-input')),
    '1234',
  );
  await tester.tap(find.text('Unlock Vault'));
  await tester.pumpAndSettle();
}

Future<void> _tapDocumentCard(WidgetTester tester, String id) async {
  final finder = find.byKey(Key('vault-document-$id'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final topLeft = tester.getTopLeft(finder);
  await tester.tapAt(topLeft + const Offset(24, 24));
}

final _documents = [
  TravelDocument(
    id: 'passport',
    displayName: 'Passport Copy',
    category: 'Passports',
    originalFileName: 'passport.pdf',
    storedPath: 'missing-passport.pdf',
    extension: 'pdf',
    fileSize: 100,
    createdAt: DateTime(2026, 9, 1),
  ),
  TravelDocument(
    id: 'hotel',
    displayName: 'Hotel Stay',
    category: 'Bookings',
    originalFileName: 'hotel.pdf',
    storedPath: 'missing-hotel.pdf',
    extension: 'pdf',
    fileSize: 200,
    createdAt: DateTime(2026, 8, 30),
  ),
  TravelDocument(
    id: 'policy',
    displayName: 'Policy',
    category: 'Insurance',
    originalFileName: 'policy.pdf',
    storedPath: 'missing-policy.pdf',
    extension: 'pdf',
    fileSize: 300,
    createdAt: DateTime(2026, 8, 20),
  ),
];

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
        credentialVersion: 1,
      );

  @override
  Future<void> verifyCurrentPassword(String password) async {}

  @override
  Future<void> writePin(String pin) async {}
}
