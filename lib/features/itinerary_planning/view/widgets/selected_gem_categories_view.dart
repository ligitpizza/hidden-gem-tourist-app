import 'package:flutter/material.dart';

import '../../../../shared/models/destination.dart';

/// Read-only display of the traveller's current "Interested Hidden Gem
/// Categories" — Plan Your Route only shows what's selected; editing now
/// happens exclusively in Profile (see `GemCategoryFilter`), so both
/// screens stay visually consistent without duplicating the editing UI.
class SelectedGemCategoriesView extends StatelessWidget {
  final Set<DestinationCategory> selected;

  const SelectedGemCategoriesView({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (selected.isEmpty) {
      return Text(
        'No categories selected yet — add your interests in Profile.',
        style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in selected)
          Chip(
            label: Text(category.label),
            backgroundColor: colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            side: BorderSide(color: colorScheme.primary),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
