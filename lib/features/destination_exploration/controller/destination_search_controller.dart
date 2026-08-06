import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hidden_gem.dart';
import '../model/destination_exploration_repository.dart';
import '../model/map_destination.dart';

/// A second, alternate way (besides the map popup) to find and select
/// destinations for comparison. Kept separate from [DestinationMapController]
/// — search/browse is a distinct concern with its own lifecycle (query
/// debounce, recent-searches history). Selection itself is not duplicated
/// here — callers toggle selection straight through
/// `DestinationMapController.toggleComparisonSelection`.
class DestinationSearchController extends ChangeNotifier {
  DestinationSearchController({DestinationExplorationRepository? repository})
      : _repository = repository ?? DestinationExplorationRepository() {
    _loadTrending();
  }

  final DestinationExplorationRepository _repository;

  String query = '';
  List<MapDestination> results = const [];
  bool isSearching = false;
  List<MapDestination> trending = const [];
  HiddenGemCategory? categoryFilter;
  final List<String> recentSearches = [];

  Timer? _debounce;
  int _requestId = 0;
  Completer<void>? _pendingCompleter;

  Future<void> _loadTrending() async {
    trending = await _repository.searchDestinations();
    notifyListeners();
  }

  /// Completes the pending completer if it exists and hasn't been completed yet.
  /// Used to ensure in-flight search calls resolve instead of hanging when
  /// superseded, cleared, or disposed.
  void _completePending() {
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete();
    }
  }

  /// Debounced search. Returns a [Future] that completes once the debounced
  /// lookup settles, so tests can `await` it directly — but real callers
  /// (search-as-you-type) are not required to await each keystroke's call.
  /// A call superseded by a newer one before its timer fires completes its
  /// own (now-irrelevant) Future immediately instead of hanging forever —
  /// without this, an un-awaited call whose timer gets cancelled by the
  /// next keystroke would never resolve.
  Future<void> search(String newQuery) async {
    query = newQuery;
    _debounce?.cancel();
    _completePending();

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
    final completer = Completer<void>();
    _pendingCompleter = completer;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final found =
            await _repository.searchDestinations(query: trimmed, category: categoryFilter);
        if (requestId == _requestId) {
          results = found;
          isSearching = false;
          _recordRecentSearch(trimmed);
          notifyListeners();
        }
      } catch (e) {
        // Repository call failed; reset isSearching but keep results as-is
        if (requestId == _requestId) {
          isSearching = false;
          notifyListeners();
        }
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
    await completer.future;
  }

  void _recordRecentSearch(String term) {
    recentSearches.remove(term);
    recentSearches.insert(0, term);
    if (recentSearches.length > 5) recentSearches.removeLast();
  }

  void setCategoryFilter(HiddenGemCategory? category) {
    categoryFilter = category;
    if (query.trim().isNotEmpty) search(query);
  }

  void clearQuery() {
    _debounce?.cancel();
    _completePending();
    query = '';
    results = const [];
    isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _completePending();
    super.dispose();
  }
}

final destinationSearchControllerProvider =
    ChangeNotifierProvider<DestinationSearchController>((ref) {
  return DestinationSearchController();
});
