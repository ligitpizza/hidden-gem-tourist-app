import 'dart:async';

import 'package:collab/features/travel_assistant/controller/packing_checklist_controller.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/packing_checklist.dart';
import 'package:collab/features/travel_assistant/model/packing_checklist_repository.dart';
import 'package:collab/features/travel_assistant/model/packing_location_source.dart';
import 'package:collab/features/travel_assistant/model/packing_weather_service.dart';
import 'package:collab/shared/models/destination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('trip date range rejects an end before its start', () {
    expect(
      () => PackingTripDateRange(
        start: DateTime(2026, 10, 7),
        end: DateTime(2026, 10, 4),
      ),
      throwsArgumentError,
    );
  });

  test('only hotel and dining Eco Partners support packing checklists', () {
    expect(
      SavedPackingLocationSource.supportsEcoPartner(EcoPartnerCategory.stay),
      isTrue,
    );
    expect(
      SavedPackingLocationSource.supportsEcoPartner(EcoPartnerCategory.dining),
      isTrue,
    );
    expect(
      SavedPackingLocationSource.supportsEcoPartner(
        EcoPartnerCategory.transport,
      ),
      isFalse,
    );
  });

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
      expect(controller.categoryLabels, ['Hotel']);
      final hotelIds = controller.sections
          .expand((section) => section.items)
          .map((item) => item.id)
          .toSet();
      expect(hotelIds, containsAll(['photo_id', 'hotel_reservation']));
      expect(
        hotelIds,
        containsAll([
          'hotel_payment',
          'insurance_details',
          'power_bank',
          'offline_maps',
          'transport_payment',
          'water_bottle',
          'laundry_bag',
        ]),
      );
      expect(hotelIds, hasLength(15));
      expect(controller.transitScore, 0);
      expect(controller.transitDetail, '0/3 ready');
      expect(hotelIds, isNot(contains('passport')));
      expect(hotelIds, isNot(contains('reusable_cutlery')));

      await controller.toggleItem('photo_id', true);
      await controller.toggleItem('power_bank', true);
      await controller.toggleItem('offline_maps', true);
      await controller.toggleItem('transport_payment', true);
      expect(controller.packedIds, contains('photo_id'));
      expect(controller.transitScore, 100);
      await controller.setTripDates(
        PackingTripDateRange(
          start: DateTime(2026, 10, 4),
          end: DateTime(2026, 10, 7),
        ),
      );

      await controller.selectLocation('eco:2');
      expect(controller.tripLabel, 'Plant Cafe');
      expect(controller.packedIds, isNot(contains('photo_id')));
      expect(controller.tripDates, isNull);
      expect(
        controller.destinationCategories,
        contains(DestinationCategory.restaurant),
      );
      expect(controller.categoryLabels, ['Dining']);
      final diningIds = controller.sections
          .expand((section) => section.items)
          .map((item) => item.id)
          .toSet();
      expect(
        diningIds,
        containsAll([
          'dining_reservation',
          'dietary_note',
          'reusable_container',
          'power_bank',
          'offline_maps',
          'transport_payment',
          'water_bottle',
          'hand_sanitizer',
          'indoor_layer',
        ]),
      );
      expect(diningIds, hasLength(10));
      expect(controller.transitScore, 0);
      expect(diningIds, isNot(contains('passport')));
      expect(diningIds, isNot(contains('first_aid')));
      expect(diningIds, isNot(contains('reusable_cutlery')));

      await controller.selectLocation('eco:1');
      expect(controller.packedIds, contains('photo_id'));
      expect(controller.transitScore, 100);
      expect(controller.tripDates?.start, DateTime(2026, 10, 4));
      expect(controller.tripDates?.end, DateTime(2026, 10, 7));

      await controller.clearTripDates();
      await controller.selectLocation('eco:2');
      await controller.selectLocation('eco:1');
      expect(controller.tripDates, isNull);
    },
  );

  test('saved itineraries do not expose checklist dates', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = PackingChecklistController(
      locationSource: _FakePackingLocationSource(),
      weatherService: _NoWeatherService(),
    );

    await controller.load();
    await controller.selectLocation('itinerary:1');

    expect(controller.canEditTripDates, isFalse);
    expect(controller.tripDates, isNull);
    expect(controller.weatherScore, isNull);
    expect(controller.weatherDetail, 'Forecast temporarily unavailable');

    await controller.setTripDates(
      PackingTripDateRange(
        start: DateTime(2027, 1, 1),
        end: DateTime(2027, 1, 2),
      ),
    );
    expect(controller.tripDates, isNull);
    controller.dispose();
  });

  test(
    'Eco Partner weather waits for dates and refreshes on changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final weatherService = _RecordingWeatherService();
      final controller = PackingChecklistController(
        locationSource: _FakePackingLocationSource(),
        weatherService: weatherService,
        now: () => DateTime(2026, 9, 3),
      );

      await controller.load();
      expect(weatherService.requestedDates, isEmpty);
      expect(controller.forecastStatus, PackingForecastStatus.needsDates);
      expect(controller.weatherScore, isNull);
      expect(controller.weatherDetail, 'Set trip dates for forecast');

      final dates = PackingTripDateRange(
        start: DateTime(2026, 9, 5),
        end: DateTime(2026, 9, 7),
      );
      await controller.setTripDates(dates);

      expect(weatherService.requestedDates, [same(dates)]);
      expect(controller.forecastStatus, PackingForecastStatus.available);
      expect(controller.weatherScore, 0);
      expect(
        controller.sections
            .where((section) => section.name == 'Weather Essentials')
            .expand((section) => section.items)
            .map((item) => item.id),
        containsAll(['umbrella', 'rain_jacket', 'breathable_clothes']),
      );

      await controller.clearTripDates();
      expect(weatherService.requestedDates, hasLength(1));
      expect(controller.forecastStatus, PackingForecastStatus.needsDates);
      expect(controller.weatherScore, isNull);
      expect(
        controller.sections.any(
          (section) => section.name == 'Weather Essentials',
        ),
        isFalse,
      );
      controller.dispose();
    },
  );

  test(
    'controller validates past, distant, and multi-day dining dates',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PackingChecklistController(
        locationSource: _FakePackingLocationSource(),
        weatherService: _NoWeatherService(),
        now: () => DateTime(2026, 9, 3),
      );
      await controller.load();

      expect(
        () => controller.setTripDates(
          PackingTripDateRange(
            start: DateTime(2026, 9, 2),
            end: DateTime(2026, 9, 3),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => controller.setTripDates(
          PackingTripDateRange(
            start: DateTime(2031, 9, 3),
            end: DateTime(2031, 9, 4),
          ),
        ),
        throwsArgumentError,
      );

      await controller.selectLocation('eco:2');
      expect(
        () => controller.setTripDates(
          PackingTripDateRange(
            start: DateTime(2026, 9, 5),
            end: DateTime(2026, 9, 6),
          ),
        ),
        throwsArgumentError,
      );
      await controller.setTripDates(
        PackingTripDateRange(
          start: DateTime(2026, 9, 5),
          end: DateTime(2026, 9, 5),
        ),
      );
      expect(controller.tripDates?.isSingleDay, isTrue);
      controller.dispose();
    },
  );

  test(
    'a stale forecast cannot overwrite a newer location selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = PackingChecklistRepository(userId: 'race-user');
      final dates = PackingTripDateRange(
        start: DateTime(2026, 9, 5),
        end: DateTime(2026, 9, 5),
      );
      await repository.saveTripDates('eco:1', dates);
      await repository.saveTripDates('eco:2', dates);
      final weatherService = _DelayedWeatherService();
      final controller = PackingChecklistController(
        locationSource: _FakePackingLocationSource(),
        weatherService: weatherService,
        persistence: repository,
        now: () => DateTime(2026, 9, 3),
      );

      final initialLoad = controller.load();
      await weatherService.hotelStarted.future;
      final switchLocation = controller.selectLocation('eco:2');
      await weatherService.diningStarted.future;
      weatherService.dining.complete(
        _availableForecast(dates, maximumTemperature: 29),
      );
      await switchLocation;
      weatherService.hotel.complete(
        _availableForecast(dates, maximumTemperature: 38),
      );
      await initialLoad;

      expect(controller.selectedLocationId, 'eco:2');
      expect(controller.weather?.maximumTemperature, 29);
      expect(controller.isLoading, isFalse);
      controller.dispose();
    },
  );

  test(
    'a saved multi-day dining range is normalized to its visit day',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = PackingChecklistRepository(userId: 'dining-user');
      await repository.saveSelection('eco:2');
      await repository.saveTripDates(
        'eco:2',
        PackingTripDateRange(
          start: DateTime(2026, 9, 5),
          end: DateTime(2026, 9, 7),
        ),
      );
      final controller = PackingChecklistController(
        locationSource: _FakePackingLocationSource(),
        weatherService: _NoWeatherService(),
        persistence: repository,
        now: () => DateTime(2026, 9, 3),
      );

      await controller.load();

      expect(controller.selectedLocationId, 'eco:2');
      expect(controller.tripDates?.start, DateTime(2026, 9, 5));
      expect(controller.tripDates?.end, DateTime(2026, 9, 5));
      expect((await repository.loadTripDates('eco:2'))?.isSingleDay, isTrue);
      controller.dispose();
    },
  );

  test('packing cache is isolated by authenticated user ID', () async {
    SharedPreferences.setMockInitialValues({});
    final first = PackingChecklistRepository(userId: 'user-a');
    final second = PackingChecklistRepository(userId: 'user-b');

    await first.saveSelection('eco:1');
    await first.savePackedIds('eco:1', {'passport'});
    await first.saveTripDates(
      'eco:1',
      PackingTripDateRange(
        start: DateTime(2026, 11, 2, 18),
        end: DateTime(2026, 11, 5, 9),
      ),
    );

    expect(await first.loadSelection(), 'eco:1');
    expect(await first.loadPackedIds('eco:1'), {'passport'});
    expect(await second.loadSelection(), isNull);
    expect(await second.loadPackedIds('eco:1'), isEmpty);
    expect((await first.loadTripDates('eco:1'))?.start, DateTime(2026, 11, 2));
    expect(await second.loadTripDates('eco:1'), isNull);
  });
}

class _FakePackingLocationSource implements PackingLocationSource {
  @override
  Future<List<PackingLocationOption>> load() async => [
    const PackingLocationOption(
      id: 'eco:1',
      label: 'Eco Lodge',
      subtitle: 'Saved Eco Partner · Hotel',
      latitude: 5.98,
      longitude: 116.07,
      categories: {DestinationCategory.attraction},
      ecoPartnerCategory: EcoPartnerCategory.stay,
    ),
    const PackingLocationOption(
      id: 'eco:2',
      label: 'Plant Cafe',
      subtitle: 'Saved Eco Partner · Cafe',
      latitude: 5.99,
      longitude: 116.08,
      categories: {DestinationCategory.restaurant},
      ecoPartnerCategory: EcoPartnerCategory.dining,
    ),
    const PackingLocationOption(
      id: 'itinerary:1',
      label: 'Kuala Lumpur → Melaka',
      subtitle: 'Saved itinerary',
      latitude: 3.139,
      longitude: 101.687,
      categories: {DestinationCategory.craft},
    ),
  ];
}

class _NoWeatherService extends PackingWeatherService {
  @override
  Future<PackingForecastResult> getForecast({
    required double latitude,
    required double longitude,
    required PackingTripDateRange dates,
  }) async => const PackingForecastResult.failed();
}

class _RecordingWeatherService extends PackingWeatherService {
  final List<PackingTripDateRange> requestedDates = [];

  @override
  Future<PackingForecastResult> getForecast({
    required double latitude,
    required double longitude,
    required PackingTripDateRange dates,
  }) async {
    requestedDates.add(dates);
    return PackingForecastResult(
      status: PackingForecastStatus.available,
      summary: const PackingWeatherSummary(
        maximumTemperature: 33,
        minimumTemperature: 24,
        rainProbability: 70,
        uvIndex: 8,
      ),
      coverageStart: dates.start,
      coverageEnd: dates.end,
    );
  }
}

class _DelayedWeatherService extends PackingWeatherService {
  final hotel = Completer<PackingForecastResult>();
  final dining = Completer<PackingForecastResult>();
  final hotelStarted = Completer<void>();
  final diningStarted = Completer<void>();

  @override
  Future<PackingForecastResult> getForecast({
    required double latitude,
    required double longitude,
    required PackingTripDateRange dates,
  }) {
    if (latitude == 5.98) {
      hotelStarted.complete();
      return hotel.future;
    }
    diningStarted.complete();
    return dining.future;
  }
}

PackingForecastResult _availableForecast(
  PackingTripDateRange dates, {
  required double maximumTemperature,
}) => PackingForecastResult(
  status: PackingForecastStatus.available,
  summary: PackingWeatherSummary(
    maximumTemperature: maximumTemperature,
    minimumTemperature: 24,
  ),
  coverageStart: dates.start,
  coverageEnd: dates.end,
);
