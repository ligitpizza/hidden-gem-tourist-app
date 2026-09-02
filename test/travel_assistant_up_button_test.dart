import 'package:collab/core/router/shell_routes.dart';
import 'package:collab/shared/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Up button returns a deep-linked page to Travel Assistant', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/deep-linked-checklist',
      routes: [
        GoRoute(
          path: ShellRoutes.travelAssistant,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Travel Assistant dashboard')),
          ),
        ),
        GoRoute(
          path: '/deep-linked-checklist',
          builder: (context, state) => const Scaffold(
            appBar: AppHeader.pushed(
              title: 'Packing Checklist',
              fallbackPath: ShellRoutes.travelAssistant,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('Travel Assistant dashboard'), findsOneWidget);
  });
}
