import 'package:collab/features/travel_prep/controller/packing_checklist_controller.dart';
import 'package:collab/features/travel_prep/model/packing_location_source.dart';
import 'package:collab/features/travel_prep/model/packing_weather_service.dart';
import 'package:collab/shared/models/destination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'switching saved locations keeps independent checklist progress',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PackingChecklistController(
        locationSource: _FakePackingLocationSource(),
        weatherService: _NoWeatherService(),
      );

      await controller.load();
      expect(controller.selectedLocationId, 'eco:1');
      expect(controller.tripLabel, 'Eco Lodge');

      await controller.toggleItem('passport', true);
      expect(controller.packedIds, contains('passport'));

      await controller.selectLocation('eco:2');
      expect(controller.tripLabel, 'Plant Cafe');
      expect(controller.packedIds, isNot(contains('passport')));
      expect(
        controller.destinationCategories,
        contains(DestinationCategory.restaurant),
      );

      await controller.selectLocation('eco:1');
      expect(controller.packedIds, contains('passport'));
    },
  );
}

class _FakePackingLocationSource implements PackingLocationSource {
  @override
  Future<List<PackingLocationOption>> load() async => const [
    PackingLocationOption(
      id: 'eco:1',
      label: 'Eco Lodge',
      subtitle: 'Saved Eco Partner · Hotel',
      latitude: 5.98,
      longitude: 116.07,
      categories: {DestinationCategory.attraction},
    ),
    PackingLocationOption(
      id: 'eco:2',
      label: 'Plant Cafe',
      subtitle: 'Saved Eco Partner · Cafe',
      latitude: 5.99,
      longitude: 116.08,
      categories: {DestinationCategory.restaurant},
    ),
  ];
}

class _NoWeatherService extends PackingWeatherService {
  @override
  Future<PackingWeatherSummary?> getForecast({
    required double latitude,
    required double longitude,
  }) async => null;
}
