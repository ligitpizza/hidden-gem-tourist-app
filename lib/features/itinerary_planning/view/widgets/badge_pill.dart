import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../model/itinerary_stop.dart';

class BadgePill extends StatelessWidget {
  final StopBadge badge;

  const BadgePill({super.key, required this.badge});

  Color _background(ColorScheme colorScheme) {
    switch (badge) {
      case StopBadge.selected:
        return colorScheme.primaryContainer;
      case StopBadge.recommended:
      case StopBadge.localGem:
        return AppTheme.gemGoldSoft;
      case StopBadge.mealBreak:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _foreground(ColorScheme colorScheme) {
    switch (badge) {
      case StopBadge.selected:
        return colorScheme.primary;
      case StopBadge.recommended:
      case StopBadge.localGem:
        return AppTheme.gemGold;
      case StopBadge.mealBreak:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: _background(colorScheme), borderRadius: BorderRadius.circular(20)),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _foreground(colorScheme),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
