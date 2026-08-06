import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/controller/destination_map_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeRepository extends DestinationExplorationRepository {
  _FakeRepository(this._result, {this.shouldThrow = false});
  final List<MapDestination> _result;
  final bool shouldThrow;

  @override
  Future<List<MapDestination>> loadDestinations() async {
    if (shouldThrow) throw Exception('network error');
    return _result;
  }
}

class _CompleterRepository extends DestinationExplorationRepository {
  _CompleterRepository(this._completer);
  final Completer<List<MapDestination>> _completer;

  @override
  Future<List<MapDestination>> loadDestinations() => _completer.future;
}

class _ClusterFakeRepository extends DestinationExplorationRepository {
  _ClusterFakeRepository({
    this.nearbyResult = const [],
    this.nearestResult,
    this.throwOnNearby = false,
  });
  final List<MapDestination> nearbyResult;
  final MapDestination? nearestResult;
  final bool throwOnNearby;

  @override
  Future<List<MapDestination>> loadDestinations() async => const [];

  @override
  Future<List<MapDestination>> nearbyByCategory({
    required MapDestination origin,
    double radiusKm = DestinationExplorationRepository.clusterRadiusKm,
    int maxStops = DestinationExplorationRepository.clusterMaxStops,
  }) async {
    if (throwOnNearby) throw Exception('network error');
    return nearbyResult;
  }

  @override
  Future<MapDestination?> nearestDestination(LatLng point) async => nearestResult;
}

const _nature = MapDestination(
  id: 'n1',
  name: 'Forest Park',
  description: 'Trees.',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);
const _food = MapDestination(
  id: 'f1',
  name: 'Hawker Stall',
  description: 'Food.',
  category: HiddenGemCategory.food,
  location: LatLng(5.41, 100.31),
);

const _anchor = MapDestination(
  id: 'anchor',
  name: 'Anchor',
  description: '',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);
const _stop1 = MapDestination(
  id: 'stop1',
  name: 'Stop 1',
  description: '',
  category: HiddenGemCategory.nature,
  location: LatLng(5.41, 100.31),
);

void main() {
  group('DestinationMapController', () {
    test('populates destinations on successful load', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      expect(controller.destinations, [_nature, _food]);
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('sets hasError and clears destinations on load failure', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository(const [], shouldThrow: true),
      );
      await controller.loadDestinations();

      expect(controller.hasError, isTrue);
      expect(controller.destinations, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('isLoading is true while the repository call is pending', () async {
      final completer = Completer<List<MapDestination>>();
      final controller = DestinationMapController(
        repository: _CompleterRepository(completer),
      );

      expect(controller.isLoading, isTrue);

      completer.complete(const []);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
    });

    test('filteredDestinations returns everything when no category is selected', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      expect(controller.filteredDestinations, [_nature, _food]);
    });

    test('filteredDestinations narrows to the selected categories', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      controller.toggleCategory(HiddenGemCategory.nature);

      expect(controller.filteredDestinations, [_nature]);
    });

    test('toggleCategory adds then removes a category', () {
      final controller = DestinationMapController(
        repository: _FakeRepository(const []),
      );

      controller.toggleCategory(HiddenGemCategory.craft);
      expect(controller.selectedCategories, {HiddenGemCategory.craft});

      controller.toggleCategory(HiddenGemCategory.craft);
      expect(controller.selectedCategories, isEmpty);
    });

    test('clearFilters empties the selected categories', () {
      final controller = DestinationMapController(
        repository: _FakeRepository(const []),
      );

      controller.toggleCategory(HiddenGemCategory.nature);
      controller.toggleCategory(HiddenGemCategory.food);
      controller.clearFilters();

      expect(controller.selectedCategories, isEmpty);
    });

    test('selectDestination and clearSelection manage selectedDestination', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      controller.selectDestination('f1');
      expect(controller.selectedDestination, _food);

      controller.clearSelection();
      expect(controller.selectedDestination, isNull);
    });

    test('selectDestination with unknown id does not throw', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      controller.selectDestination('f1');
      expect(controller.selectedDestination, _food);

      // Attempting to select an unknown id should not throw and should not change selection
      controller.selectDestination('unknown-id');
      expect(controller.selectedDestination, _food);
    });
  });

  group('DestinationMapController cluster', () {
    test('viewThemedCluster with an explicit origin populates the cluster', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1]),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.clusterAnchor, _anchor);
      expect(controller.clusterStops, [_stop1]);
      expect(controller.clusterMessage, isNull);
      expect(controller.clusterPolyline, [_anchor.location, _stop1.location]);
    });

    test('viewThemedCluster with no origin resolves the anchor from location', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1], nearestResult: _anchor),
        currentLocation: () async => const LatLng(5.4, 100.3),
      );

      await controller.viewThemedCluster();

      expect(controller.clusterAnchor, _anchor);
      expect(controller.clusterStops, [_stop1]);
    });

    test('sets a message when location cannot be determined and no origin is given', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(),
        currentLocation: () async => null,
      );

      await controller.viewThemedCluster();

      expect(controller.clusterMessage, "Couldn't determine your location to find a themed trail.");
      expect(controller.clusterAnchor, isNull);
    });

    test('sets "no cluster available" when location resolves but no destination found', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearestResult: null),
        currentLocation: () async => const LatLng(5.4, 100.3),
      );

      await controller.viewThemedCluster();

      expect(controller.clusterMessage, 'No themed cluster available nearby.');
      expect(controller.clusterAnchor, isNull);
    });

    test('sets a "no cluster available" message on zero results', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: const []),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.clusterMessage, 'No themed cluster available nearby.');
      expect(controller.clusterStops, isEmpty);
    });

    test('sets a failure message when the repository throws', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(throwOnNearby: true),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.clusterMessage, "Couldn't load a themed cluster right now.");
    });

    test('legDistancesKm and totalDistanceKm reflect the polyline', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1]),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.legDistancesKm, hasLength(1));
      expect(controller.legDistancesKm.first, closeTo(legDistanceKm(_anchor.location, _stop1.location), 0.001));
      expect(controller.totalDistanceKm, closeTo(controller.legDistancesKm.first, 0.001));
    });

    test('clearCluster resets all cluster fields', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1]),
      );
      await controller.viewThemedCluster(origin: _anchor);

      controller.clearCluster();

      expect(controller.clusterAnchor, isNull);
      expect(controller.clusterStops, isEmpty);
      expect(controller.clusterMessage, isNull);
      expect(controller.isLoadingCluster, isFalse);
    });
  });

  group('DestinationMapController comparison selection', () {
    test('toggling adds and removes an id', () {
      final controller = DestinationMapController(repository: _FakeRepository(const []));

      controller.toggleComparisonSelection('a');
      expect(controller.selectedForComparison, {'a'});

      controller.toggleComparisonSelection('a');
      expect(controller.selectedForComparison, isEmpty);
    });

    test('canCompare is true only at 2 or 3 selections', () {
      final controller = DestinationMapController(repository: _FakeRepository(const []));

      expect(controller.canCompare, isFalse);
      controller.toggleComparisonSelection('a');
      expect(controller.canCompare, isFalse);
      controller.toggleComparisonSelection('b');
      expect(controller.canCompare, isTrue);
      controller.toggleComparisonSelection('c');
      expect(controller.canCompare, isTrue);
    });

    test('a 4th toggle is a no-op', () {
      final controller = DestinationMapController(repository: _FakeRepository(const []));

      controller.toggleComparisonSelection('a');
      controller.toggleComparisonSelection('b');
      controller.toggleComparisonSelection('c');
      controller.toggleComparisonSelection('d');

      expect(controller.selectedForComparison, {'a', 'b', 'c'});
    });
  });
}
