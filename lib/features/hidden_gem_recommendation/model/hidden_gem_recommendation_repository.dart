import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../../shared/services/hidden_gem_scoring.dart';
import 'hidden_gem_feed_item.dart';

/// Below this many recent engagement events, a place's growth rate is too
/// noisy to trust even if the server already flagged it — mirrors
/// `trending_config.min_engagement_count` client-side as a defensive
/// display-layer guard, in case that row is ever missing.
const _minEngagementForTrending = 5;

/// Data access for Module 1's recommendation surfaces — "Your Top
/// Matches", "Trending Now", and the ranked list behind "View All". Reads
/// the persisted, server-computed Hidden Gem Score and trending label
/// wherever possible (FR2/FR4's use cases both end with the result stored
/// in Supabase, not just computed on the client), falling back to a live
/// client-side score via the shared [HiddenGemScoring] formula only when a
/// place hasn't been through a scoring run yet (e.g. right after seeding,
/// before the first scheduled job fires).
class HiddenGemRecommendationRepository {
  HiddenGemRecommendationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Ranked, personalized recommendations (FR1.2/FR1.3) via the
  /// `get_personalized_recommendations` RPC — folds in the signed-in
  /// tourist's learned category affinity (FR3) and the given month's
  /// seasonal suitability (FR3.4/3.5, defaulting server-side to the
  /// current month). Falls back to the plain global ranking if the RPC
  /// can't be reached (offline, not signed in, or the migration hasn't
  /// been applied yet) so the feed still has something to show.
  Future<List<HiddenGemFeedItem>> personalizedRecommendations({
    int limit = 20,
    int? month,
  }) async {
    try {
      final rows = await _client.rpc('get_personalized_recommendations', params: {
        'p_limit': limit,
        if (month != null) 'p_month': month,
      });
      final items = (rows as List)
          .map((row) => _itemFromRow(row as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    } catch (_) {
      // RPC not reachable yet — fall through to the plain ranking below.
    }
    return _globalTopMatches(limit: limit);
  }

  /// Places currently labelled trending by the scheduled
  /// `detect_trending_destinations()` job (FR4.3), strongest growth first.
  Future<List<HiddenGemFeedItem>> trending({int limit = 10}) async {
    try {
      final rows = await _client
          .from('place_hidden_gem_candidates')
          .select()
          .eq('is_trending', true)
          .order('engagement_growth_rate', ascending: false)
          .limit(limit);
      final items = (rows as List).map((row) => _itemFromRow(row as Map<String, dynamic>)).toList();
      if (items.isNotEmpty) return items;
    } catch (_) {
      // Fall through to the client-side approximation below — covers both
      // an unreachable table and a project where the scheduled job hasn't
      // run yet (is_trending still all-false).
    }
    return _approximateTrendingFromReviews(limit: limit);
  }

  /// Asks the server to recompute every place's Hidden Gem Score right
  /// now, rather than waiting for the next scheduled run — the "... or
  /// when a tourist requests recommendations" trigger from the "Score All
  /// Hidden Gems" use case. Best-effort: a failure here just means the
  /// feed shows whatever was last computed.
  Future<void> requestScoreRefresh() async {
    try {
      await _client.rpc('recompute_hidden_gem_scores');
    } catch (_) {
      // Ignored — see doc comment.
    }
  }

  Future<List<HiddenGemFeedItem>> _globalTopMatches({int limit = 20}) async {
    final items = await _loadCandidates();
    items.sort((a, b) => b.matchScore != a.matchScore
        ? b.matchScore.compareTo(a.matchScore)
        : a.name.compareTo(b.name)); // alphabetical tiebreaker
    return items.take(limit).toList();
  }

  Future<List<HiddenGemFeedItem>> _approximateTrendingFromReviews({int limit = 10}) async {
    final rows = await _loadCandidateRows();
    final scored = rows.map((row) {
      final reviewCount = (row['review_count'] as num?)?.toInt() ?? 0;
      final recentReviewCount = (row['recent_review_count'] as num?)?.toInt() ?? 0;
      final ratio = reviewCount > 0 ? recentReviewCount / reviewCount : 0.0;
      return (row: row, item: _itemFromRow(row, trendGrowthRateOverride: ratio), recentReviewCount: recentReviewCount);
    }).where((r) => r.recentReviewCount >= _minEngagementForTrending).toList()
      ..sort((a, b) => b.item.trendGrowthRate.compareTo(a.item.trendGrowthRate));
    return scored.take(limit).map((r) => r.item).toList();
  }

  Future<List<HiddenGemFeedItem>> _loadCandidates({String state = 'Penang'}) async {
    final rows = await _loadCandidateRows(state: state);
    return rows.map((row) => _itemFromRow(row)).toList();
  }

  Future<List<Map<String, dynamic>>> _loadCandidateRows({String state = 'Penang'}) async {
    try {
      final rows = await _client.from('place_hidden_gem_candidates').select().eq('state', state);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  HiddenGemFeedItem _itemFromRow(Map<String, dynamic> row, {double? trendGrowthRateOverride}) {
    final avgRating = (row['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final uniqueness = (row['uniqueness_score'] as num?)?.toDouble() ?? 0.0;
    final accessibility = (row['accessibility_score'] as num?)?.toDouble() ?? 0.0;
    final popularity = gemPopularityFromDb(row['popularity'] as String?);

    // hidden_gem_score is null until the scoring job has run at least once
    // for this place — compute it live from the same shared formula
    // (kept in sync with the SQL version in
    // recompute_hidden_gem_scores()) so the feed never shows a blank.
    final persistedScore = (row['hidden_gem_score'] as num?)?.toDouble();
    final matchScore = persistedScore ??
        HiddenGemScoring.score(
          avgRating: avgRating,
          uniqueness: uniqueness,
          accessibility: accessibility,
          popularity: popularity,
        );
    final personalizedScore = (row['personalized_score'] as num?)?.toDouble() ?? matchScore;

    return HiddenGemFeedItem(
      id: row['id'] as String,
      name: row['name'] as String,
      description: (row['description'] as String?)?.trim().isNotEmpty == true
          ? row['description'] as String
          : 'Rated ${avgRating.toStringAsFixed(1)}★ by real visitors.',
      location: (row['city'] as String?)?.trim().isNotEmpty == true
          ? row['city'] as String
          : (row['state'] as String? ?? ''),
      category: destinationCategoryFromDb(row['category'] as String),
      matchScore: matchScore,
      personalizedScore: personalizedScore,
      isHiddenGem: matchScore >= HiddenGemScoring.qualifyingThreshold,
      avgRating: avgRating,
      uniquenessScore: uniqueness,
      accessibilityScore: accessibility,
      popularity: popularity,
      isTrending: (row['is_trending'] as bool?) ?? false,
      trendGrowthRate:
          trendGrowthRateOverride ?? (row['engagement_growth_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
