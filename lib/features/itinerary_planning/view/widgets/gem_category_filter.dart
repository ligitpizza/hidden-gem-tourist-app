import 'package:flutter/material.dart';

import '../../../../shared/models/hidden_gem.dart';

/// Chip row for picking "Interested Hidden Gem Categories" — shared between
/// Profile (primary editing surface) and Plan Your Route (still editable
/// there too), both backed by the same persisted preference.
class GemCategoryFilter extends StatelessWidget {
  final Set<HiddenGemCategory> selected;
  final ValueChanged<HiddenGemCategory> onToggle;

  const GemCategoryFilter({super.key, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in HiddenGemCategory.values)
          FilterChip(
            label: Text(category.label),
            selected: selected.contains(category),
            onSelected: (_) => onToggle(category),
            showCheckmark: false,
            backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(140),
            selectedColor: colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: selected.contains(category) ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            side: BorderSide(
              color: selected.contains(category) ? colorScheme.primary : colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
