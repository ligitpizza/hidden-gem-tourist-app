import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/theme/app_theme.dart' as core_theme;

/// Shared top header — plain surface with a single-pixel bottom border
/// instead of a colored bar, per the Field Journal design system's
/// "Overlays" spec. Two variants:
/// - [AppHeader.tabRoot] — bottom-nav tab screens (Explore, Journal,
///   Badges, Quiz, Dashboard). Uses the shared Hidden Gems emblem instead
///   of a back button because there's nothing to go back to from a tab root.
/// - [AppHeader.pushed] — screens reached by pushing (Destination Detail,
///   Journal Detail, Check-in History, …): a real back button.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader.tabRoot({super.key, required this.title, this.actions})
    : showBackButton = false,
      fallbackPath = null,
      onBack = null;

  const AppHeader.pushed({
    super.key,
    required this.title,
    this.actions,
    this.fallbackPath,
    this.onBack,
  }) : showBackButton = true;

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final String? fallbackPath;

  /// Handles a screen-specific back state before route navigation is used.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: showBackButton ? 56 : 60,
        titleSpacing: 0,
        leading: showBackButton
            ? _HeaderBackButton(
                onPressed: () {
                  if (onBack != null) {
                    onBack!();
                    return;
                  }
                  final navigator = Navigator.maybeOf(context);
                  if (navigator?.canPop() == true) {
                    navigator!.pop();
                    return;
                  }
                  final router = GoRouter.of(context);
                  if (router.canPop()) {
                    router.pop();
                    return;
                  }
                  if (context.mounted && fallbackPath != null) {
                    context.go(fallbackPath!);
                  }
                },
              )
            : const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: _HiddenGemsEmblem(),
              ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headlineSm.copyWith(color: colors.onSurface),
        ),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      color: colors.onSurface,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: colors.surfaceContainerHigh,
        overlayColor: colors.onSurface,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _HiddenGemsEmblem extends StatelessWidget {
  const _HiddenGemsEmblem();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hidden Gems Malaysia',
      image: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: core_theme.AppTheme.primarySeed,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: core_theme.AppTheme.gemGold,
                size: 22,
              ),
              Positioned(
                top: 7,
                right: 6,
                child: Icon(
                  Icons.auto_awesome,
                  color: core_theme.AppTheme.gemGoldSoft,
                  size: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
