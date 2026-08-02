import '../models/hidden_gem.dart';

/// The current composite "hidden gem" score: quality (rating) + how
/// distinctive a place is (uniqueness) + how easy it is to actually visit
/// (accessibility) + how undiscovered it still is (popularity — low/medium
/// popularity is rewarded since a place everyone already knows isn't much of
/// a discovery). Category is used as a filter dimension via
/// [HiddenGemCategory] elsewhere, not as a score input here.
///
/// Weights match the team's documented Module 1 formula (Collab Dev ASGM
/// Drafts, "Hidden Gem Scoring Engine"): 40% rating + 25% uniqueness + 20%
/// accessibility + 15% low-popularity. Kept as one shared, plain-parameter
/// formula (used by route generation, the Assistant feed, and the score
/// detail screen) so it's a one-line swap if the team's numbers change —
/// the doc itself notes they're "not final".
class HiddenGemScoring {
  HiddenGemScoring._();

  static const double ratingWeight = 0.40;
  static const double uniquenessWeight = 0.25;
  static const double accessibilityWeight = 0.20;
  static const double popularityWeight = 0.15;

  /// Calibrated against the real Penang dataset so viewpoints/craft/
  /// heritage/museums qualify at a much higher rate than restaurants/cafes,
  /// spreading gems across categories instead of skewing to food.
  static const double qualifyingThreshold = 0.8;

  static double score({
    required double avgRating,
    required double uniqueness,
    required double accessibility,
    required GemPopularity popularity,
  }) {
    final popularityBonus = switch (popularity) {
      GemPopularity.low => 1.0,
      GemPopularity.medium => 0.6,
      GemPopularity.high => 0.25,
    };
    return (avgRating / 5.0) * ratingWeight +
        (uniqueness / 5.0) * uniquenessWeight +
        (accessibility / 5.0) * accessibilityWeight +
        popularityBonus * popularityWeight;
  }

  /// Maps a `places.category` value onto the coarser [HiddenGemCategory]
  /// used for timeline slotting and the user-facing category filter.
  static HiddenGemCategory categoryFromDb(String category) {
    switch (category) {
      case 'restaurant':
      case 'cafe':
        return HiddenGemCategory.food;
      case 'park':
      case 'beach':
      case 'waterfall':
        return HiddenGemCategory.nature;
      case 'viewpoint':
        return HiddenGemCategory.viewpoint;
      case 'craft':
        return HiddenGemCategory.craft;
      case 'heritage_site':
      case 'museum':
      case 'attraction':
      case 'art':
      default:
        return HiddenGemCategory.culture;
    }
  }
}
