import 'package:collab/core/theme/app_theme.dart';
import 'package:collab/shared/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tab-root header adds branding without changing its actions', (
    tester,
  ) async {
    var actionTaps = 0;

    await tester.pumpWidget(
      _HeaderTestApp(
        header: AppHeader.tabRoot(
          title: 'Travel Assistant',
          actions: [
            IconButton(
              onPressed: () => actionTaps++,
              tooltip: 'Header action',
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Travel Assistant'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    await tester.tap(find.byTooltip('Header action'));
    expect(actionTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pushed header preserves its screen-specific back callback', (
    tester,
  ) async {
    var backTaps = 0;

    await tester.pumpWidget(
      _HeaderTestApp(
        header: AppHeader.pushed(
          title: 'Packing Checklist',
          onBack: () => backTaps++,
        ),
      ),
    );

    expect(find.text('Packing Checklist'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    expect(backTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared header handles dark mode and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const _HeaderTestApp(
        themeMode: ThemeMode.dark,
        textScaler: TextScaler.linear(2),
        header: AppHeader.tabRoot(
          title: 'A very long Travel Assistant screen title',
        ),
      ),
    );

    expect(
      find.text('A very long Travel Assistant screen title'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _HeaderTestApp extends StatelessWidget {
  const _HeaderTestApp({
    required this.header,
    this.themeMode = ThemeMode.light,
    this.textScaler = TextScaler.noScaling,
  });

  final AppHeader header;
  final ThemeMode themeMode;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(appBar: header, body: const SizedBox.expand()),
    );
  }
}
