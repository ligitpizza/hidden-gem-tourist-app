import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

class HiddenGemsApp extends ConsumerWidget {
  const HiddenGemsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeModeController = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: 'Hidden Gems of Malaysia',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeController.themeMode,
      routerConfig: router,
    );
  }
}
