import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../../shared/services/hidden_gem_scoring.dart';
import 'assistant_feed_item.dart';

/// Below this many recent reviews, a place's "reviews in the last 3 months
/// / all-time" ratio is too noisy to call "trending" (e.g. 1 recent review
/// out of 1 total reads as "+100%" but means nothing).
const _minRecentReviewsForTrending = 5;

/// Feeds the Assistant tab's "Your Top Matches" and "Trending Now"
/// sections from real Penang place + review data — the same composite
/// hidden-gem score used by route generation, not separately mocked
/// content.
class AssistantFeedRepository {
  Future<List<AssistantFeedItem>> _loadPenangFeed() async {
    try {
      final rows = await Supabase.instance.client
          .from('place_hidden_gem_candidates')
          .select()
          .eq('state', 'Penang');

      return rows.map((row) => _itemFromRow(row)).toList();
    } catch (_) {
      return const [];
    }
  }

  AssistantFeedItem _itemFromRow(Map<String, dynamic> row) {
    final avgRating = (row['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final uniqueness = (row['uniqueness_score'] as num?)?.toDouble() ?? 0.0;
    final accessibility = (row['accessibility_score'] as num?)?.toDouble() ?? 0.0;
    final popularity = gemPopularityFromDb(row['popularity'] as String?);
    final reviewCount = (row['review_count'] as num?)?.toInt() ?? 0;
    final recentReviewCount = (row['recent_review_count'] as num?)?.toInt() ?? 0;

    final score = HiddenGemScoring.score(
      avgRating: avgRating,
      uniqueness: uniqueness,
      accessibility: accessibility,
      popularity: popularity,
    );

    return AssistantFeedItem(
      id: row['id'] as String,
      name: row['name'] as String,
      description: (row['description'] as String?)?.trim().isNotEmpty == true
          ? row['description'] as String
          : 'Rated ${avgRating.toStringAsFixed(1)}★ by real visitors.',
      location: (row['city'] as String?)?.trim().isNotEmpty == true
          ? row['city'] as String
          : (row['state'] as String? ?? ''),
      category: destinationCategoryFromDb(row['category'] as String),
      matchScore: score,
      isHiddenGem: score >= HiddenGemScoring.qualifyingThreshold,
      avgRating: avgRating,
      uniquenessScore: uniqueness,
      accessibilityScore: accessibility,
      popularity: popularity,
      trendRatio: reviewCount > 0 ? recentReviewCount / reviewCount : 0,
      recentReviewCount: recentReviewCount,
    );
  }

  /// Highest-scoring real Penang places, best first.
  Future<List<AssistantFeedItem>> topMatches({int limit = 10}) async {
    final items = await _loadPenangFeed();
    items.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return items.take(limit).toList();
  }

  /// Places with the strongest real recent-review activity relative to
  /// their all-time review count, best first.
  Future<List<AssistantFeedItem>> trending({int limit = 10}) async {
    final items = await _loadPenangFeed();
    final eligible = items
        .where((i) => i.recentReviewCount >= _minRecentReviewsForTrending)
        .toList()
      ..sort((a, b) => b.trendRatio.compareTo(a.trendRatio));
    return eligible.take(limit).toList();
  }
}
