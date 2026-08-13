import 'package:flutter/material.dart';

import '../../../../shared/models/destination.dart';
import '../../../../shared/models/hidden_gem.dart';
import '../../model/gem_category_groups.dart';

/// The browsable "add a category" picker for "Interested Hidden Gem
/// Categories" — Profile's sole editing surface (tucked inside a
/// collapsed-by-default section there). Plan Your Route only *displays*
/// the current selection (see `SelectedGemCategoriesView`); it doesn't
/// embed this picker.
///
/// Shows all 20 categories the app knows about: the 5 broad "vibe" groups
/// from [HiddenGemCategory] (each a bulk select-all/clear-all for its
/// members) and the 15 specific place types from [DestinationCategory]
/// underneath the group they belong to (see [gemCategoryGroups]). An
/// unselected specific chip shows a "+" to make the add action explicit.
class GemCategoryFilter extends StatelessWidget {
  final Set<DestinationCategory> selected;
  final ValueChanged<DestinationCategory> onToggle;
  final ValueChanged<HiddenGemCategory> onToggleGroup;

  const GemCategoryFilter({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    final groups = HiddenGemCategory.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _GroupSection(
            group: groups[i],
            selected: selected,
            onToggle: onToggle,
            onToggleGroup: onToggleGroup,
          ),
        ],
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  final HiddenGemCategory group;
  final Set<DestinationCategory> selected;
  final ValueChanged<DestinationCategory> onToggle;
  final ValueChanged<HiddenGemCategory> onToggleGroup;

  const _GroupSection({
    required this.group,
    required this.selected,
    required this.onToggle,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final members = gemCategoryGroups[group] ?? const <DestinationCategory>[];
    final selectedCount = members.where(selected.contains).length;
    final allSelected = members.isNotEmpty && selectedCount == members.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onToggleGroup(group),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: allSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: allSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$selectedCount/${members.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: allSelected
                          ? colorScheme.onPrimary.withAlpha(200)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in members)
              FilterChip(
                avatar: selected.contains(category)
                    ? null
                    : Icon(Icons.add, size: 16, color: colorScheme.onSurfaceVariant),
                label: Text(category.label),
                selected: selected.contains(category),
                onSelected: (_) => onToggle(category),
                showCheckmark: true,
                backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(140),
                selectedColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color:
                      selected.contains(category) ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                side: BorderSide(
                  color: selected.contains(category) ? colorScheme.primary : colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
