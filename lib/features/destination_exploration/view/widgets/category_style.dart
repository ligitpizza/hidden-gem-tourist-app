// lib/features/destination_exploration/view/widgets/category_style.dart
import 'package:flutter/material.dart';

import '../../../../shared/models/hidden_gem.dart';

/// Marker/filter-chip color and icon per category. No such mapping exists
/// elsewhere in the app yet, so it's defined here, local to the map.
Color categoryColor(HiddenGemCategory category) {
  switch (category) {
    case HiddenGemCategory.nature:
      return Colors.green.shade600;
    case HiddenGemCategory.food:
      return Colors.orange.shade700;
    case HiddenGemCategory.culture:
      return Colors.deepPurple.shade400;
    case HiddenGemCategory.viewpoint:
      return Colors.blue.shade600;
    case HiddenGemCategory.craft:
      return Colors.brown.shade400;
  }
}

IconData categoryIcon(HiddenGemCategory category) {
  switch (category) {
    case HiddenGemCategory.nature:
      return Icons.park;
    case HiddenGemCategory.food:
      return Icons.restaurant;
    case HiddenGemCategory.culture:
      return Icons.museum;
    case HiddenGemCategory.viewpoint:
      return Icons.landscape;
    case HiddenGemCategory.craft:
      return Icons.palette;
  }
}
