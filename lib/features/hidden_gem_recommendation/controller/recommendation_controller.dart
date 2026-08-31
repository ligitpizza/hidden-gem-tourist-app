import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/hidden_gem_feed_item.dart';
import '../model/hidden_gem_recommendation_repository.dart';

/// Loads the discovery feed's "Your Top Matches" and "Trending Now"
/// sections (FR1.2/1.3, FR4.3) — the View Recommended Destinations use
/// case's entry point.
class RecommendationController extends ChangeNotifier {
  RecommendationController({HiddenGemRecommendationRepository? repository})
      : _repository = repository ?? HiddenGemRecommendationRepository() {
    load();
  }

  final HiddenGemRecommendationRepository _repository;

  bool isLoading = true;
  List<HiddenGemFeedItem> topMatches = const [];
  List<HiddenGemFeedItem> trending = const [];

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    final results = await Future.wait([
      _repository.personalizedRecommendations(),
      _repository.trending(),
    ]);
    topMatches = results[0];
    trending = results[1];

    isLoading = false;
    notifyListeners();
  }

  /// A1 in "View Recommended Destinations": the tourist just changed their
  /// preferences, so re-run scoring/ranking instead of waiting for the
  /// next scheduled job, then reload the feed with the fresh numbers.
  Future<void> refreshAfterPreferenceChange() async {
    await _repository.requestScoreRefresh();
    await load();
  }
}

final recommendationControllerProvider =
    ChangeNotifierProvider.autoDispose<RecommendationController>((ref) {
  return RecommendationController();
});
