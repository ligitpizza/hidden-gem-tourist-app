import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';

/// Shared top header — plain surface with a single-pixel bottom border
/// instead of a colored bar, per the Field Journal design system's
/// "Overlays" spec. Two variants:
/// - [AppHeader.tabRoot] — bottom-nav tab screens (Explore, Journal,
///   Badges, Quiz, Dashboard). No leading icon — there's nothing to go
///   back to from a tab root.
/// - [AppHeader.pushed] — screens reached by pushing (Destination Detail,
///   Journal Detail, Check-in History, …): a real back button.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader.tabRoot({super.key, required this.title, this.actions})
    : showBackButton = false,
      fallbackPath = null;

  const AppHeader.pushed({
    super.key,
    required this.title,
    this.actions,
    this.fallbackPath,
  }) : showBackButton = true;

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final String? fallbackPath;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        border: Border(
          bottom: BorderSide(color: AppColors.of(context).outlineVariant),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.of(context).onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: showBackButton ? 12 : 20,
        leading: showBackButton
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.of(context).onSurface,
                ),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  overlayColor: AppColors.of(context).onSurface,
                  shape: const CircleBorder(),
                ),
                onPressed: () {
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
            : null,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headlineSm,
        ),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
