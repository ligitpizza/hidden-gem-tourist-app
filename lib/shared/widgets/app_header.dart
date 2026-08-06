import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Shared top header — plain surface with a single-pixel bottom border
/// instead of a colored bar, per the Field Journal design system's
/// "Overlays" spec. Two variants:
/// - [AppHeader.tabRoot] — bottom-nav tab screens (Explore, Journal,
///   Badges, Quiz, Dashboard). Leading is styled like a back arrow but
///   currently does nothing — TODO: wire up once these screens have
///   somewhere real to go (e.g. a drawer/menu).
/// - [AppHeader.pushed] — screens reached by pushing (Destination Detail,
///   Journal Detail, Check-in History, …): a real back button.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader.tabRoot({super.key, required this.title, this.actions})
    : showBackButton = false;

  const AppHeader.pushed({super.key, required this.title, this.actions})
    : showBackButton = true;

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.onSurface),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            overlayColor: AppColors.onSurface,
            shape: const CircleBorder(),
          ),
          onPressed: showBackButton ? () => Navigator.of(context).maybePop() : () {},
        ),
        title: Text(title, style: AppTypography.headlineSm),
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
