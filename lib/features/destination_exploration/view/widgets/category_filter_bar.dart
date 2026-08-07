// lib/features/destination_exploration/view/widgets/category_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/hidden_gem.dart';
import '../../controller/destination_map_controller.dart';
import 'category_style.dart';

/// A small filter icon that opens a vertical category checklist in a
/// bottom sheet (FR1.3) — kept off the map header itself so the header
/// doesn't get cluttered with a horizontal row of chips. Toggling a
/// category narrows [DestinationMapController.filteredDestinations];
/// deselecting all of them shows every destination again (A1).
class CategoryFilterBar extends ConsumerWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(destinationMapControllerProvider);
    final activeCount = controller.selectedCategories.length;

    return Badge(
      label: Text('$activeCount'),
      isLabelVisible: activeCount > 0,
      child: IconButton.outlined(
        icon: const Icon(Icons.tune),
        tooltip: 'Filter by category',
        onPressed: () => _showCategorySheet(context, controller),
      ),
    );
  }

  void _showCategorySheet(BuildContext context, DestinationMapController controller) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filter by Category', style: Theme.of(context).textTheme.titleMedium),
                    if (controller.selectedCategories.isNotEmpty)
                      TextButton(
                        onPressed: controller.clearFilters,
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final category in HiddenGemCategory.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(categoryIcon(category), color: categoryColor(category)),
                    title: Text(category.label),
                    value: controller.selectedCategories.contains(category),
                    onChanged: (_) => controller.toggleCategory(category),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
