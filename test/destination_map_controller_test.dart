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
}
