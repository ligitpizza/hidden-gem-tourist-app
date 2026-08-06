import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Horizontal-bar breakdown of check-ins per category. Kept dependency-free
/// (no chart library) since simple proportional bars don't need one —
/// fl_chart is reserved for the economic impact pie chart, where slices
/// need to interlock precisely.
class CategoryBreakdownList extends StatelessWidget {
  const CategoryBreakdownList({super.key, required this.breakdown});

  final Map<String, int> breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Check in at a few destinations to see your category breakdown.',
          style: AppTypography.bodySm,
        ),
      );
    }

    final maxCount = breakdown.values.reduce((a, b) => a > b ? a : b);
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedEntries.map((entry) {
        final ratio = maxCount == 0 ? 0.0 : entry.value / maxCount;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  ),
                  Text('${entry.value}', style: AppTypography.bodySm),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
