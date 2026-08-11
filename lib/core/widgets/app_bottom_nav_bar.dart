import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/gamification_journal/controller/badge_controller.dart';
import '../../features/gamification_journal/controller/checkin_controller.dart';
import '../../features/gamification_journal/controller/quiz_controller.dart';
import '../router/shell_routes.dart';

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavDestination({required this.icon, required this.selectedIcon, required this.label});
}

/// The seven real shell branches, in branch-index order (matches
/// StatefulShellRoute's branch order in app_router.dart — indices here are
/// what onTabSelected expects). Split below: [_primaryLeft] + [_primaryRight]
/// always show; [_secondaryBranches] lives behind the "More" menu.
const _destinations = [
  _NavDestination(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Map'), // 0
  _NavDestination(icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'Explore'), // 1
  _NavDestination(icon: Icons.smart_toy_outlined, selectedIcon: Icons.smart_toy, label: 'Assistant'), // 2
  _NavDestination(icon: Icons.bookmark_outline, selectedIcon: Icons.bookmark, label: 'Saved'), // 3
  _NavDestination(icon: Icons.luggage_outlined, selectedIcon: Icons.luggage, label: 'Travel Prep'), // 4
  _NavDestination(icon: Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories, label: 'Journal'), // 5
  _NavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'), // 6
];

/// Always-visible tabs, either side of the center "More" button.
const _primaryLeft = [0, 2]; // Map, Assistant
const _primaryRight = [5, 6]; // Journal, Profile

/// Tucked behind "More" — real shell branches selected the same way as the
/// primary tabs.
const _secondaryBranches = [1, 3, 4]; // Explore, Saved, Travel Prep

/// A "More" menu entry that isn't a shell branch — it pushes a route
/// instead of switching tabs. [indicatorKey] is looked up against live
/// controller state to decide whether to show a notification badge
/// ('badges' → an unviewed-unlock dot, 'quizzes' → a pending-retake count).
class _MorePushEntry {
  final IconData icon;
  final String label;
  final String path;
  final String? indicatorKey;
  const _MorePushEntry({required this.icon, required this.label, required this.path, this.indicatorKey});
}

const _morePushEntries = [
  _MorePushEntry(icon: Icons.emoji_events_outlined, label: 'Badges', path: ShellRoutes.journalBadges, indicatorKey: 'badges'),
  _MorePushEntry(icon: Icons.quiz_outlined, label: 'Quizzes', path: ShellRoutes.journalQuizzes, indicatorKey: 'quizzes'),
  _MorePushEntry(icon: Icons.history_outlined, label: 'Check-ins', path: ShellRoutes.journalHistory),
];

int _pendingQuizCount(BuildContext context) {
  final checkInController = context.watch<CheckInController>();
  final quizController = context.watch<QuizController>();
  final checkedInIds = checkInController.history.map((c) => c.destinationId).toSet();
  return quizController.pendingQuizCount(checkedInIds);
}

/// Bottom nav: a primary row (Map, Assistant, More, Journal, Profile)
/// always visible, plus a "More" button that opens a dark overlay — sized
/// to stop just above the nav bar itself (rather than the whole screen)
/// so the bar stays visible, undimmed, and tappable — with the remaining
/// destinations (Explore, Saved, Travel Prep, Badges, Quizzes, Check-ins).
/// The whole overlay is clipped to that region too, so the nav bar always
/// paints in front of it — the panel visually emerges from behind the bar
/// rather than ever sliding over it, even mid-animation.
class AppBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> with TickerProviderStateMixin {
  OverlayEntry? _moreEntry;
  AnimationController? _moreController;

  bool get _onSecondaryBranch => _secondaryBranches.contains(widget.currentIndex);
  bool get _isMoreOpen => _moreEntry != null;

  @override
  void didUpdateWidget(covariant AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Safety net for any tab change that doesn't route through
    // _selectPrimary/_MoreMenuOverlay below (e.g. deep links) — the menu
    // should never survive a tab switch regardless of how it happened.
    if (oldWidget.currentIndex != widget.currentIndex && _isMoreOpen) {
      _closeMoreMenu();
    }
  }

  void _selectPrimary(int index) {
    if (_isMoreOpen) _closeMoreMenu();
    widget.onTabSelected(index);
  }

  Future<void> _closeMoreMenu() async {
    final controller = _moreController;
    if (controller == null) return;
    _moreController = null;
    await controller.reverse();
    _moreEntry?.remove();
    _moreEntry = null;
    controller.dispose();
    if (mounted) setState(() {});
  }

  void _openMoreMenu(BuildContext context) {
    if (_isMoreOpen) {
      _closeMoreMenu();
      return;
    }

    final navBarHeight = 72 + MediaQuery.of(context).padding.bottom;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _moreController = controller;

    final entry = OverlayEntry(
      builder: (overlayContext) => _MoreMenuOverlay(
        animation: controller,
        currentIndex: widget.currentIndex,
        navBarHeight: navBarHeight,
        onClose: _closeMoreMenu,
        onSelectBranch: (index) {
          _closeMoreMenu();
          widget.onTabSelected(index);
        },
        onPushRoute: (path) {
          _closeMoreMenu();
          context.push(path);
        },
      ),
    );
    _moreEntry = entry;
    Overlay.of(context).insert(entry);
    controller.forward();
    setState(() {});
  }

  @override
  void dispose() {
    _moreEntry?.remove();
    _moreController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (final i in _primaryLeft)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: widget.currentIndex == i,
                    onTap: () => _selectPrimary(i),
                  ),
                ),
              Expanded(
                child: _NavItem(
                  destination: _onSecondaryBranch
                      ? _destinations[widget.currentIndex]
                      : const _NavDestination(
                          icon: Icons.grid_view_outlined,
                          selectedIcon: Icons.grid_view,
                          label: 'More',
                        ),
                  selected: _onSecondaryBranch || _isMoreOpen,
                  showIndicator: !_onSecondaryBranch,
                  onTap: () => _openMoreMenu(context),
                ),
              ),
              for (final i in _primaryRight)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: widget.currentIndex == i,
                    onTap: () => _selectPrimary(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a small notification dot/count on top of [child] based on
/// [indicatorKey] and live controller state — used for both the collapsed
/// "More" nav item (any unviewed badge or pending quiz, anywhere inside)
/// and each individual tile inside the open menu.
class _Indicator extends StatelessWidget {
  const _Indicator({required this.indicatorKey, required this.child});

  final String? indicatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (indicatorKey) {
      case 'badges':
        final hasUnviewed = context.watch<BadgeController>().hasUnviewedBadges;
        return hasUnviewed ? Badge(child: child) : child;
      case 'quizzes':
        final count = _pendingQuizCount(context);
        return count > 0 ? Badge(label: Text('$count'), child: child) : child;
      default:
        return child;
    }
  }
}

/// Dark-barrier overlay shown when "More" is tapped. Stops just above the
/// bottom nav bar (rather than covering the whole screen) so the bar
/// stays visible, undimmed, and tappable while the menu is open — and the
/// whole thing is wrapped in a [ClipRect] bounded to that same region, so
/// the panel can never paint over the nav bar even mid-slide: it visually
/// emerges from behind the bar rather than sliding over it.
class _MoreMenuOverlay extends StatelessWidget {
  const _MoreMenuOverlay({
    required this.animation,
    required this.currentIndex,
    required this.navBarHeight,
    required this.onClose,
    required this.onSelectBranch,
    required this.onPushRoute,
  });

  final Animation<double> animation;
  final int currentIndex;
  final double navBarHeight;
  final VoidCallback onClose;
  final ValueChanged<int> onSelectBranch;
  final ValueChanged<String> onPushRoute;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final panelContent = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'More',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [
              for (final i in _secondaryBranches)
                _MoreMenuTile(
                  destination: _destinations[i],
                  selected: currentIndex == i,
                  onTap: () => onSelectBranch(i),
                ),
              for (final entry in _morePushEntries)
                _MoreMenuTile(
                  destination: _NavDestination(
                    icon: entry.icon,
                    selectedIcon: entry.icon,
                    label: entry.label,
                  ),
                  selected: false,
                  indicatorKey: entry.indicatorKey,
                  onTap: () => onPushRoute(entry.path),
                ),
            ],
          ),
        ],
      ),
    );

    // Everything below — barrier and panel alike — lives inside this one
    // ClipRect, capped at navBarHeight from the bottom. Without it, the
    // SlideTransition's child briefly paints past its Positioned box
    // during the animation (that's how the slide effect works), and since
    // Overlay entries always paint above the base route — nav bar
    // included — that overflow would render on top of the bar. Clipping
    // the region away entirely means the bar is always the frontmost
    // thing there, regardless of paint order.
    return ClipRect(
      clipper: _BottomInsetClipper(navBarHeight),
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: animation,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Container(color: Colors.black54),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: navBarHeight,
            child: SafeArea(
              top: false,
              bottom: false,
              child: SlideTransition(
                // Starts shifted down by its own full height, i.e. flush
                // with the nav bar's top edge, and slides up to Offset.zero.
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  // Material provides the ink-splash context the InkWell
                  // tiles below need — a manually-inserted OverlayEntry has
                  // no Material ancestor of its own. Elevation is 0 since
                  // the BoxShadow above already handles depth (a plain
                  // Material elevation shadow wraps every edge, including
                  // the bottom, which reads oddly since the panel sits
                  // flush against the nav bar there).
                  child: Material(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    child: panelContent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips to the full width, from the top of the screen down to
/// [bottomInset] above the bottom edge — i.e. everything except the nav
/// bar's own strip.
class _BottomInsetClipper extends CustomClipper<Rect> {
  const _BottomInsetClipper(this.bottomInset);

  final double bottomInset;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width, size.height - bottomInset);

  @override
  bool shouldReclip(covariant _BottomInsetClipper oldClipper) => oldClipper.bottomInset != bottomInset;
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.indicatorKey,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final String? indicatorKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Indicator(
              indicatorKey: indicatorKey,
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              destination.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// Shown only on the collapsed "More" button — a small dot summarizing
  /// whether anything inside the menu needs attention (an unviewed badge
  /// or a pending quiz), so a Tourist doesn't have to open it to find out.
  final bool showIndicator;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.showIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final hasUnviewedBadges = showIndicator && context.watch<BadgeController>().hasUnviewedBadges;
    final pendingQuizzes = showIndicator ? _pendingQuizCount(context) : 0;
    final showDot = hasUnviewedBadges || pendingQuizzes > 0;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: showDot
                ? Badge(
                    child: Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      color: selected ? color : colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  )
                : Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    color: selected ? color : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
          ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            style: TextStyle(
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
