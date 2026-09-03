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

  testWidgets('Up follows nested feature history before its fallback', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: ShellRoutes.travelAssistant,
      routes: [
        GoRoute(
          path: ShellRoutes.travelAssistant,
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.push(ShellRoutes.ecoPartners),
                child: const Text('Open Eco Partners'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: ShellRoutes.ecoPartners,
          builder: (context, state) => Scaffold(
            appBar: const AppHeader.pushed(
              title: 'Eco Partners',
              fallbackPath: ShellRoutes.travelAssistant,
            ),
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      appBar: AppHeader.pushed(
                        title: 'Partner Details',
                        fallbackPath: ShellRoutes.ecoPartners,
                      ),
                      body: Center(child: Text('Partner details page')),
                    ),
                  ),
                ),
                child: const Text('Open Partner Details'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Eco Partners'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Partner Details'));
    await tester.pumpAndSettle();
    expect(find.text('Partner details page'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.text('Open Partner Details'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.text('Open Eco Partners'), findsOneWidget);
  });

  testWidgets('Up uses a nested screen origin when it has no history', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/document-viewer',
      routes: [
        GoRoute(
          path: ShellRoutes.travelAssistant,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Travel Assistant dashboard')),
          ),
        ),
        GoRoute(
          path: ShellRoutes.documentVault,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Document Vault'))),
        ),
        GoRoute(
          path: '/document-viewer',
          builder: (context, state) => const Scaffold(
            appBar: AppHeader.pushed(
              title: 'Passport.pdf',
              fallbackPath: ShellRoutes.documentVault,
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

    expect(find.text('Document Vault'), findsOneWidget);
  });
}
