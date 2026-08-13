import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// Both flutter_riverpod and provider export a ChangeNotifierProvider —
// this file only needs Riverpod's ConsumerWidget/WidgetRef, so hide its
// version to let provider's (used below for the Journal module) resolve
// unambiguously.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/gamification_journal/controller/badge_controller.dart';
import 'features/gamification_journal/controller/checkin_controller.dart';
import 'features/gamification_journal/controller/dashboard_controller.dart';
import 'features/gamification_journal/controller/friend_controller.dart';
import 'features/gamification_journal/controller/journal_controller.dart';
import 'features/gamification_journal/controller/quiz_controller.dart';

/// Flutter's default [ScrollBehavior] leaves mouse out of its drag
/// devices — deliberate upstream, since click-and-drag can conflict with
/// other mouse interactions on desktop/web, but it means every
/// horizontally-swiped carousel (journal media, etc.) can't be dragged
/// with a mouse at all on Windows without this override.
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

class HiddenGemsApp extends ConsumerWidget {
  const HiddenGemsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeModeController = ref.watch(themeModeControllerProvider);

    // The Journal module (Module 6) is mock-backed for now and manages its
    // own state with ChangeNotifier controllers rather than Riverpod —
    // this just makes that state available alongside the rest of the app,
    // it doesn't replace Riverpod anywhere else. Keyed by the signed-in
    // user when available (Supabase is already initialized in main.dart
    // before this widget ever builds); the whole app is auth-gated by the
    // router's redirect, so this only matters for the brief moment before
    // that redirect lands.
    final journalUserId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CheckInController(userId: journalUserId)),
        ChangeNotifierProvider(create: (_) => BadgeController(userId: journalUserId)),
        ChangeNotifierProvider(create: (_) => JournalController(userId: journalUserId)),
        ChangeNotifierProvider(create: (_) => QuizController(userId: journalUserId)),
        ChangeNotifierProvider(create: (_) => FriendController(userId: journalUserId)),
        ChangeNotifierProvider(create: (_) => DashboardController()),
      ],
      child: MaterialApp.router(
        title: 'Hidden Gems of Malaysia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeModeController.themeMode,
        scrollBehavior: _AppScrollBehavior(),
        routerConfig: router,
      ),
    );
  }
}
