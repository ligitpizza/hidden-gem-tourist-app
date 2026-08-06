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

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: HiddenGemCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = HiddenGemCategory.values[index];
          final selected = controller.selectedCategories.contains(category);
          return FilterChip(
            avatar: Icon(
              categoryIcon(category),
              size: 18,
              color: selected ? Colors.white : categoryColor(category),
            ),
            label: Text(category.label),
            selected: selected,
            selectedColor: categoryColor(category),
            labelStyle: TextStyle(color: selected ? Colors.white : null),
            onSelected: (_) => controller.toggleCategory(category),
          );
        },
      ),
    );
  }
}
