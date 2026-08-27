import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hidden_gem.dart';

/// The current composite "hidden gem" score: quality (rating) + how
/// distinctive a place is (uniqueness) + how easy it is to actually visit
/// (accessibility) + how undiscovered it still is (popularity — low/medium
/// popularity is rewarded since a place everyone already knows isn't much of
/// a discovery). Category is used as a filter dimension via
/// [HiddenGemCategory] elsewhere, not as a score input here.
///
/// Weights match Module 1's documented formula: 40% rating + 25%
/// uniqueness + 20% accessibility + 15% low-popularity. Kept as one
/// shared, plain-parameter formula (used by route generation, the
/// discovery feed, and the score detail screen) so it's a one-line swap if
/// the numbers change.
///
/// The fields below are mutable (not `const`) and default to those exact
/// values, but [loadConfig] overwrites them from the
/// `hidden_gem_scoring_config` table on Supabase at app start (see
/// `main.dart`) — every existing caller of [score] automatically picks up
/// a config change with no code change of its own, satisfying Module 1's
/// NFR5.1 ("scoring weights ... configurable without requiring changes to
/// the application source code"). The authoritative, persisted per-place
/// score still lives in `places.hidden_gem_score` (recomputed server-side
/// by `recompute_hidden_gem_scores()`) — this client-side copy exists so
/// every module has an instant, offline-safe fallback formula rather than
/// a network round trip for every score it needs.
class HiddenGemScoring {
  HiddenGemScoring._();

  static double ratingWeight = 0.40;
  static double uniquenessWeight = 0.25;
  static double accessibilityWeight = 0.20;
  static double popularityWeight = 0.15;

  static double popularityBonusLow = 1.0;
  static double popularityBonusMedium = 0.6;
  static double popularityBonusHigh = 0.25;

  /// Calibrated against the real Penang dataset so viewpoints/craft/
  /// heritage/museums qualify at a much higher rate than restaurants/cafes,
  /// spreading gems across categories instead of skewing to food.
  static double qualifyingThreshold = 0.8;

  /// Pulls the latest weights/threshold from `hidden_gem_scoring_config`.
  /// Safe to call repeatedly (e.g. after a tourist changes their
  /// preferences) and safe to fail silently (offline, table not migrated
  /// yet, etc.) — on any error the previous values (or the defaults above)
  /// stay in effect.
  static Future<void> loadConfig({SupabaseClient? client}) async {
    try {
      final row = await (client ?? Supabase.instance.client)
          .from('hidden_gem_scoring_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return;
      ratingWeight = (row['rating_weight'] as num?)?.toDouble() ?? ratingWeight;
      uniquenessWeight = (row['uniqueness_weight'] as num?)?.toDouble() ?? uniquenessWeight;
      accessibilityWeight = (row['accessibility_weight'] as num?)?.toDouble() ?? accessibilityWeight;
      popularityWeight = (row['popularity_weight'] as num?)?.toDouble() ?? popularityWeight;
      popularityBonusLow = (row['popularity_bonus_low'] as num?)?.toDouble() ?? popularityBonusLow;
      popularityBonusMedium =
          (row['popularity_bonus_medium'] as num?)?.toDouble() ?? popularityBonusMedium;
      popularityBonusHigh = (row['popularity_bonus_high'] as num?)?.toDouble() ?? popularityBonusHigh;
      qualifyingThreshold = (row['qualifying_threshold'] as num?)?.toDouble() ?? qualifyingThreshold;
    } catch (_) {
      // Keep whatever values were already in effect — see doc comment.
    }
  }

  static double score({
    required double avgRating,
    required double uniqueness,
    required double accessibility,
    required GemPopularity popularity,
  }) {
    final popularityBonus = switch (popularity) {
      GemPopularity.low => popularityBonusLow,
      GemPopularity.medium => popularityBonusMedium,
      GemPopularity.high => popularityBonusHigh,
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
      case 'island':
      case 'mountain':
        return HiddenGemCategory.nature;
      case 'viewpoint':
        return HiddenGemCategory.viewpoint;
      case 'craft':
        return HiddenGemCategory.craft;
      case 'heritage_site':
      case 'museum':
      case 'attraction':
      case 'art':
      case 'theme_park':
      case 'mall':
      default:
        return HiddenGemCategory.culture;
    }
  }
}
