import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/app.dart';

void main() {
  testWidgets('HiddenGemsApp renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HiddenGemsApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hidden Gems of Malaysia'), findsOneWidget);
  });
}
