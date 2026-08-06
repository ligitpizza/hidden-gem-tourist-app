import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/controller/destination_search_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeSearchRepository extends DestinationExplorationRepository {
  _FakeSearchRepository({this.searchResult = const [], this.trendingResult = const []});
  final List<MapDestination> searchResult;
  final List<MapDestination> trendingResult;

  @override
  Future<List<MapDestination>> searchDestinations({
    String query = '',
    HiddenGemCategory? category,
    int limit = 20,
  }) async {
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
  });
}
