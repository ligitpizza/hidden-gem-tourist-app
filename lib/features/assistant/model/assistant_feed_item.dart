import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';

/// One card on the Assistant tab's discovery feed ("Top Match" or
/// "Trending" entry) — a real Penang place scored against the same
/// hidden-gem formula used elsewhere in the app, not separately mocked
/// data.
class AssistantFeedItem {
  final String id;
  final String name;
  final String description;
  final String location;
  final DestinationCategory category;

  /// 0–1 composite hidden-gem score, shown to the user as a percentage.
  final double matchScore;
  final bool isHiddenGem;

  /// Raw score components (0–5 unless noted) backing [matchScore] — kept on
  /// the item so the score-detail/transparency screen can show the real
  /// breakdown instead of re-fetching.
  final double avgRating;
  final double uniquenessScore;
  final double accessibilityScore;
  final GemPopularity popularity;

  /// Real "reviews in the last 3 months / all-time reviews" ratio (0–1),
  /// shown as a "+X%" trend indicator.
  final double trendRatio;

  /// Raw count backing [trendRatio] — used to filter out places with too
  /// few recent reviews for the ratio to mean anything.
  final int recentReviewCount;

  const AssistantFeedItem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.category,
    required this.matchScore,
    required this.isHiddenGem,
    required this.avgRating,
    required this.uniquenessScore,
    required this.accessibilityScore,
    required this.popularity,
    required this.trendRatio,
    required this.recentReviewCount,
  });

  int get matchPercent => (matchScore * 100).round();
  int get trendPercent => (trendRatio * 100).round();
}
