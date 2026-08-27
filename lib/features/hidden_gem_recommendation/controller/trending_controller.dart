import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/hidden_gem_feed_item.dart';
import '../model/hidden_gem_recommendation_repository.dart';

/// Backs the dedicated "Trending Now — View All" screen (the View
/// Trending Destination use case), as opposed to the short strip shown
/// inline on the discovery feed.
class TrendingController extends ChangeNotifier {
  TrendingController({HiddenGemRecommendationRepository? repository})
      : _repository = repository ?? HiddenGemRecommendationRepository() {
    load();
  }

  final HiddenGemRecommendationRepository _repository;

  bool isLoading = true;
  List<HiddenGemFeedItem> items = const [];

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    items = await _repository.trending(limit: 30);
    isLoading = false;
    notifyListeners();
  }
}

final trendingControllerProvider = ChangeNotifierProvider.autoDispose<TrendingController>((ref) {
  return TrendingController();
});
