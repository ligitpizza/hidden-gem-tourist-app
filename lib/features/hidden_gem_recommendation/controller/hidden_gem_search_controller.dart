import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/hidden_gem_feed_item.dart';
import '../model/hidden_gem_recommendation_repository.dart';
import '../model/interaction_repository.dart';

/// "Search For Gem" (UC diagram) — debounced search over real hidden gem
/// data, ranked by Hidden Gem Score. Mirrors
/// DestinationSearchController's debounce/request-id pattern
/// (destination_exploration/controller) for consistency with the rest of
/// the app, not because the two share any code.
class HiddenGemSearchController extends ChangeNotifier {
  HiddenGemSearchController({
    HiddenGemRecommendationRepository? repository,
    InteractionRepository? interactionRepository,
  })  : _repository = repository ?? HiddenGemRecommendationRepository(),
        _interactionRepository = interactionRepository ?? InteractionRepository();

  final HiddenGemRecommendationRepository _repository;
  final InteractionRepository _interactionRepository;

  String query = '';
  List<HiddenGemFeedItem> results = const [];
  bool isSearching = false;
  final List<String> recentSearches = [];

  Timer? _debounce;
  int _requestId = 0;

  Future<void> search(String newQuery) async {
    query = newQuery;
    _debounce?.cancel();

    final trimmed = newQuery.trim();
    if (trimmed.isEmpty) {
      isSearching = false;
      results = const [];
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    final requestId = ++_requestId;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final found = await _repository.search(trimmed);
      if (requestId != _requestId) return; // superseded by a newer keystroke
      results = found;
      isSearching = false;
      _recordRecentSearch(trimmed);
      notifyListeners();
    });
  }

  void _recordRecentSearch(String term) {
    recentSearches.remove(term);
    recentSearches.insert(0, term);
    if (recentSearches.length > 5) recentSearches.removeLast();
  }

  void clearRecentSearches() {
    if (recentSearches.isEmpty) return;
    recentSearches.clear();
    notifyListeners();
  }

  void clearQuery() {
    _debounce?.cancel();
    query = '';
    results = const [];
    isSearching = false;
    notifyListeners();
  }

  /// FR3.1: the "search" interaction is logged when the tourist actually
  /// taps into a result (a real signal about what they wanted), not on
  /// every keystroke of the query itself.
  void logResultTap(HiddenGemFeedItem item) {
    _interactionRepository.logSearch(item.id);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// Deliberately NOT autoDispose — DestinationSearchController
// (destination_exploration/controller) uses a plain, non-autoDispose
// provider for the same reason: closing and reopening the search screen
// should keep [recentSearches] around, the same way Module 2's search
// already behaves. autoDispose would tear the whole controller down
// (recent searches included) the instant the screen isn't watched, which
// is exactly the "recent searches disappeared" behaviour found during
// manual testing.
final hiddenGemSearchControllerProvider = ChangeNotifierProvider<HiddenGemSearchController>((ref) {
  return HiddenGemSearchController();
});
