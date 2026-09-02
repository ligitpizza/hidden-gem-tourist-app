import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:collab/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The app now reads Supabase.instance while building its router (auth
    // gate, onboarding gate), so this smoke test needs an initialized
    // client too — dummy credentials are fine since nothing here logs in.
    // Supabase persists its session via shared_preferences, which needs
    // its mock channel handler registered before initialize() touches it.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://example.supabase.co', publishableKey: 'test-anon-key');
  });

  testWidgets('HiddenGemsApp renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HiddenGemsApp()),
    );
    await tester.pumpAndSettle();

    // Signed out (no real session against the dummy project above), so the
    // router redirects to Login — its own screen carries the app title.
    expect(find.text('Hidden Gems of Malaysia'), findsOneWidget);
  });
}
