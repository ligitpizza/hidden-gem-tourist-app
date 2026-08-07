import 'package:flutter/material.dart';

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavDestination({required this.icon, required this.selectedIcon, required this.label});
}

/// Bottom navigation destinations: Map | Explore | Assistant | Saved |
/// Travel Prep | Journal | Profile.
const _destinations = [
  _NavDestination(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Map'),
  _NavDestination(icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'Explore'),
  _NavDestination(icon: Icons.smart_toy_outlined, selectedIcon: Icons.smart_toy, label: 'Assistant'),
  _NavDestination(icon: Icons.bookmark_outline, selectedIcon: Icons.bookmark, label: 'Saved'),
  _NavDestination(icon: Icons.luggage_outlined, selectedIcon: Icons.luggage, label: 'Travel Prep'),
  _NavDestination(icon: Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories, label: 'Journal'),
  _NavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
];

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          // 64 was too tight — content (icon container + spacing + label)
          // overflowed by ~1px on some devices' font/scale metrics.
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: currentIndex == i,
                    onTap: () => onTabSelected(i),
                  ),
                ),
            ],
          ),
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
