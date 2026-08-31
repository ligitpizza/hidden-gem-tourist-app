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
    // it doesn't replace Riverpod anywhere else.
    //
    // StreamBuilder + a ValueKey on the signed-in user's id is doing real
    // work here, not just decoration: Provider's `create:` only runs once
    // per provider instance, and nothing this widget already watches
    // (the router, the theme controller) changes value on sign-in/out —
    // so without this, signing out and into a *different* account without
    // a full app restart left every controller here still scoped to
    // whichever user was first signed in, silently reading and writing
    // that stale user's data under the new session (surfaced as, e.g.,
    // "everyone sees the same friend list" during two-account testing).
    // Keying on the id forces Flutter to tear down and rebuild this whole
    // subtree — fresh controllers, clean state — whenever it changes.
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final journalUserId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';

        return MultiProvider(
          key: ValueKey(journalUserId),
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
      },
    );
  }
}
