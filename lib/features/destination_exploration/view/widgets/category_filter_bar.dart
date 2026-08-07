// lib/features/destination_exploration/view/widgets/category_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/hidden_gem.dart';
import '../../controller/destination_map_controller.dart';
import 'category_style.dart';

/// Horizontal row of category filter chips (FR1.3) — toggling a chip
/// narrows [DestinationMapController.filteredDestinations]; deselecting
/// all chips shows every destination again (A1).
class CategoryFilterBar extends ConsumerWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(destinationMapControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in HiddenGemCategory.values)
            FilterChip(
              avatar: Icon(
                categoryIcon(category),
                size: 18,
                color: controller.selectedCategories.contains(category)
                    ? Colors.white
                    : categoryColor(category),
              ),
              label: Text(category.label),
              selected: controller.selectedCategories.contains(category),
              selectedColor: categoryColor(category),
              labelStyle: TextStyle(
                color: controller.selectedCategories.contains(category) ? Colors.white : null,
              ),
              onSelected: (_) => controller.toggleCategory(category),
            ),
        ],
      ),
    );
  }
}
