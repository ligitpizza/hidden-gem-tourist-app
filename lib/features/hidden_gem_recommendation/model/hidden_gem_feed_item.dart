import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';

/// One destination card surfaced by Module 1 — "Your Top Matches",
/// "Trending Now", or the Score Detail / transparency screen. Backed by
/// real Supabase data throughout: [matchScore] is the persisted, global
/// Hidden Gem Score (FR2), [personalizedScore] additionally folds in the
/// signed-in tourist's learned category affinity and the current month's
/// seasonal suitability (FR3), and [isTrending]/[trendGrowthRate] come
/// straight from the scheduled trending-detection job (FR4).
class HiddenGemFeedItem {
  final String id;
  final String name;
  final String description;
  final String location;
  final DestinationCategory category;

  /// 0–1 composite Hidden Gem Score, as computed and stored by
  /// `recompute_hidden_gem_scores()`.
  final double matchScore;

  /// 0–1+ personalized score from `get_personalized_recommendations` —
  /// equal to [matchScore] when the tourist has no preference profile yet
  /// or wasn't fetched personally (e.g. the plain trending list).
  final double personalizedScore;

  final bool isHiddenGem;

  /// Raw score components (0–5 unless noted) backing [matchScore] — kept on
  /// the item so the score-detail/transparency screen can show the real
  /// breakdown instead of re-fetching.
  final double avgRating;
  final double uniquenessScore;
  final double accessibilityScore;
  final GemPopularity popularity;

  /// Persisted trending label + growth rate from the scheduled
  /// `detect_trending_destinations()` job (0–1+, shown as "+X%").
  final bool isTrending;
  final double trendGrowthRate;

  const HiddenGemFeedItem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.category,
    required this.matchScore,
    required this.personalizedScore,
    required this.isHiddenGem,
    required this.avgRating,
    required this.uniquenessScore,
    required this.accessibilityScore,
    required this.popularity,
    required this.isTrending,
    required this.trendGrowthRate,
  });

  int get matchPercent => (matchScore.clamp(0, 1) * 100).round();
  int get personalizedPercent => (personalizedScore.clamp(0, 1) * 100).round();
  int get trendPercent => (trendGrowthRate * 100).round();
}
