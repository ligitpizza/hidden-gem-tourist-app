import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// A transient banner that slides down from the top of the screen, holds
/// briefly, then slides back up on its own — the "snackbar from the top"
/// used for things that happen passively in the background (e.g. a friend
/// request arriving) rather than as a direct result of the user's own
/// action, where a bottom SnackBar would normally do.
void showTopNotificationBanner(
  BuildContext context, {
  required String message,
  IconData icon = Icons.notifications_outlined,
  VoidCallback? onTap,
  Duration displayDuration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopBanner(
      message: message,
      icon: icon,
      displayDuration: displayDuration,
      onTap: () {
        onTap?.call();
        entry.remove();
      },
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopBanner extends StatefulWidget {
  const _TopBanner({
    required this.message,
    required this.icon,
    required this.displayDuration,
    required this.onTap,
    required this.onDismiss,
  });

  final String message;
  final IconData icon;
  final Duration displayDuration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _offset = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
    _controller.forward();
    Future.delayed(widget.displayDuration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _offset,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              color: colors.surfaceContainerHigh,
              elevation: 6,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () {
                  _controller.stop();
                  widget.onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
                        child: Icon(widget.icon, size: 18, color: colors.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: AppTypography.bodySm.copyWith(color: colors.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.close, size: 16, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
