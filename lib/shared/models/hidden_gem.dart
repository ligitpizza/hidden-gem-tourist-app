import 'package:latlong2/latlong.dart';

/// Why a hidden gem is worth surfacing to the traveller.
enum HiddenGemCategory { food, culture, nature, viewpoint, craft }

extension HiddenGemCategoryX on HiddenGemCategory {
  String get label {
    switch (this) {
      case HiddenGemCategory.food:
        return 'Local Gem';
      case HiddenGemCategory.culture:
        return 'Culture';
      case HiddenGemCategory.nature:
        return 'Nature';
      case HiddenGemCategory.viewpoint:
        return 'Viewpoint';
      case HiddenGemCategory.craft:
        return 'Craft';
    }
  }
}

/// How widely-known a place already is, derived from real review volume.
/// A "hidden" gem favours low/medium popularity — a place everyone already
/// knows about isn't much of a discovery.
enum GemPopularity { low, medium, high }

extension GemPopularityX on GemPopularity {
  String get label {
    switch (this) {
      case GemPopularity.low:
        return 'Low';
      case GemPopularity.medium:
        return 'Medium';
      case GemPopularity.high:
        return 'High';
    }
  }
}

GemPopularity gemPopularityFromDb(String? value) {
  switch (value) {
    case 'low':
      return GemPopularity.low;
    case 'high':
      return GemPopularity.high;
    case 'medium':
    default:
      return GemPopularity.medium;
  }
}

/// An off-the-beaten-path spot discoverable along a generated route.
///
/// The classification fields (rating/uniqueness/accessibility/popularity)
/// feed a composite "hidden gem" score computed in the repository — kept as
/// plain weighted parameters there (not hardcoded) so the definition is a
/// one-line swap once the team finalises the real scoring algorithm.
class HiddenGem {
  final String id;
  final String name;
  final String description;
  final LatLng location;
  final HiddenGemCategory category;
  final double avgRating;
  final double uniquenessScore;
  final double accessibilityScore;
  final GemPopularity popularity;

  const HiddenGem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.category,
    this.avgRating = 0,
    this.uniquenessScore = 0,
    this.accessibilityScore = 0,
    this.popularity = GemPopularity.medium,
  });
}
