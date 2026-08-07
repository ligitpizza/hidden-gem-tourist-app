import 'package:flutter/material.dart';

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavDestination({required this.icon, required this.selectedIcon, required this.label});
}

/// All seven destinations, in their branch-index order (matches
/// StatefulShellRoute's branch order in app_router.dart — indices here are
/// what onTabSelected expects). Split across two layers below: [_primaryLeft]
/// + [_primaryRight] always show; [_secondary] lives behind the "More" tab.
const _destinations = [
  _NavDestination(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Map'), // 0
  _NavDestination(icon: Icons.smart_toy_outlined, selectedIcon: Icons.smart_toy, label: 'Assistant'), // 1
  _NavDestination(icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'Explore'), // 2
  _NavDestination(icon: Icons.bookmark_outline, selectedIcon: Icons.bookmark, label: 'Saved'), // 3
  _NavDestination(icon: Icons.luggage_outlined, selectedIcon: Icons.luggage, label: 'Travel Prep'), // 4
  _NavDestination(icon: Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories, label: 'Journal'), // 5
  _NavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'), // 6
];

/// Always-visible tabs, either side of the center "More" button.
const _primaryLeft = [0, 1]; // Map, Explore
const _primaryRight = [5, 6]; // Journal, Profile

/// Tucked behind "More" — everything not important enough for the primary
/// row, revealed as a horizontal strip above it.
const _secondary = [2, 3, 4]; // Assistant, Saved, Travel Prep

/// Two-layer bottom nav: a primary row (Map, Explore, More, Journal,
/// Profile) always visible, and a secondary horizontal strip (Assistant,
/// Saved, Travel Prep) that slides in above it when "More" is tapped —
/// keeps the always-visible row to 5 items instead of cramming in all 7.
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

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  bool _moreExpanded = false;

  bool get _onSecondaryTab => _secondary.contains(widget.currentIndex);

  void _selectPrimary(int index) {
    setState(() => _moreExpanded = false);
    widget.onTabSelected(index);
  }

  void _selectSecondary(int index) {
    setState(() => _moreExpanded = false);
    widget.onTabSelected(index);
  }

  void _toggleMore() {
    setState(() => _moreExpanded = !_moreExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: _moreExpanded
                  ? SizedBox(
                      height: 72,
                      child: Row(
                        children: [
                          for (final i in _secondary)
                            Expanded(
                              child: _NavItem(
                                destination: _destinations[i],
                                selected: widget.currentIndex == i,
                                onTap: () => _selectSecondary(i),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (_moreExpanded)
              Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            SizedBox(
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
                      destination: _NavDestination(
                        icon: Icons.grid_view_outlined,
                        selectedIcon: Icons.grid_view,
                        label: _onSecondaryTab
                            ? _destinations[widget.currentIndex].label
                            : 'More',
                      ),
                      selected: _onSecondaryTab || _moreExpanded,
                      onTap: _toggleMore,
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

  const _NavItem({required this.destination, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
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
            child: Icon(
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
