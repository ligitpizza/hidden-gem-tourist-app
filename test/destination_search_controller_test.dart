import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/controller/destination_search_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeSearchRepository extends DestinationExplorationRepository {
  _FakeSearchRepository({
    this.searchResult = const [],
    this.trendingResult = const [],
    this.shouldThrowOnSearch = false,
  });
  final List<MapDestination> searchResult;
  final List<MapDestination> trendingResult;
  final bool shouldThrowOnSearch;

  @override
  Future<List<MapDestination>> searchDestinations({
    String query = '',
    HiddenGemCategory? category,
    int limit = 20,
  }) async {
    // Only throw if this is a non-empty search (not a trending load)
    if (shouldThrowOnSearch && query.trim().isNotEmpty) {
      throw Exception('Repository error');
    }
    return query.trim().isEmpty ? trendingResult : searchResult;
  }
}

const _place = MapDestination(
  id: 'p1',
  name: 'Emerald Falls',
  description: '',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);

void main() {
  group('DestinationSearchController', () {
    test('loads trending destinations on construction', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(trendingResult: [_place]));
      await Future<void>.delayed(Duration.zero);

      expect(controller.trending, [_place]);
    });

    test('search debounces and populates results', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      await controller.search('Emerald');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(controller.results, [_place]);
      expect(controller.isSearching, isFalse);
    });

    test('search records a non-empty query into recentSearches', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      await controller.search('Emerald Falls');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(controller.recentSearches, ['Emerald Falls']);
    });

    test('recentSearches dedupes and caps at 5, most-recent-first', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      for (final term in ['a', 'b', 'c', 'd', 'e', 'a']) {
        await controller.search(term);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      expect(controller.recentSearches, ['a', 'e', 'd', 'c', 'b']);
    });

    test('clearing the query empties results without a new search', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));
      await controller.search('Emerald');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      controller.clearQuery();

      expect(controller.query, '');
      expect(controller.results, isEmpty);
    });

    test('superseding a search call resolves the first call\'s Future', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      // Start first search but don't await it yet (simulates un-awaited keystroke)
      final firstFuture = controller.search('E');
      // Immediately start a second search (new keystroke) before first debounce completes
      final secondFuture = controller.search('Em');

      // Both futures should resolve (not hang) despite first being cancelled
      await firstFuture;
      await secondFuture;
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Final results from second search
      expect(controller.results, [_place]);
      expect(controller.isSearching, isFalse);
    });

    test('clearQuery resolves any in-flight search\'s Future', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      // Start a search but don't await yet
      final searchFuture = controller.search('Emerald');
      // Immediately clear the query before 350ms debounce elapses
      controller.clearQuery();

      // The in-flight search's Future should resolve despite being cleared
      await searchFuture;

      expect(controller.query, '');
      expect(controller.results, isEmpty);
    });

    test('repository error leaves isSearching false and Future resolves', () async {
      final controller = DestinationSearchController(
        repository: _FakeSearchRepository(searchResult: [_place], shouldThrowOnSearch: true),
      );

      // This search will throw in the repository, but should handle it gracefully
      await controller.search('Emerald');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // isSearching should be false (not stuck true), results unchanged
      expect(controller.isSearching, isFalse);
      expect(controller.results, isEmpty);
    });
  });
}
