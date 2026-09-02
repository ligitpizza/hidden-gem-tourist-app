import 'package:collab/features/travel_assistant/controller/packing_checklist_controller.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/packing_checklist.dart';
import 'package:collab/features/travel_assistant/model/packing_checklist_repository.dart';
import 'package:collab/features/travel_assistant/model/packing_location_source.dart';
import 'package:collab/features/travel_assistant/model/packing_weather_service.dart';
import 'package:collab/features/travel_assistant/view/travel_assistant_screens.dart';
import 'package:collab/shared/models/destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'custom checklist header fits a narrow screen and add dialog cancels cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = PackingChecklistController(
        locationSource: const _LocationSource(),
        weatherService: _WeatherService(),
        persistence: _ChecklistRepository(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.2)),
            child: child!,
          ),
          home: ReadyToWanderScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Customized Checklist'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Item'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(find.text('Add custom packing item'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add custom packing item'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trip dates display, clear, and open the date-range picker', (
    tester,
  ) async {
    final repository = _ChecklistRepository();
    repository.dates['test-trip'] = PackingTripDateRange(
      start: DateTime(2026, 10, 4),
      end: DateTime(2026, 10, 7),
    );
    final controller = PackingChecklistController(
      locationSource: const _LocationSource(),
      weatherService: _WeatherService(),
      persistence: repository,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ReadyToWanderScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip dates'), findsOneWidget);
    expect(find.textContaining('Oct 4, 2026'), findsOneWidget);
    expect(find.textContaining('Oct 7, 2026'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Trip dates not set'), findsOneWidget);
    expect(repository.dates['test-trip'], isNull);

    await tester.tap(find.text('Set dates'));
    await tester.pumpAndSettle();
    expect(find.text('Select trip dates'), findsOneWidget);
    Navigator.of(tester.element(find.text('Select trip dates'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Trip dates not set'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await controller.setTripDates(
      PackingTripDateRange(
        start: DateTime(2026, 12, 1),
        end: DateTime(2026, 12, 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dec 1, 2026'), findsOneWidget);
  });

  testWidgets('saved itineraries do not show checklist date controls', (
    tester,
  ) async {
    final controller = PackingChecklistController(
      locationSource: const _ItineraryLocationSource(),
      weatherService: _WeatherService(),
      persistence: _ChecklistRepository(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ReadyToWanderScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip dates'), findsNothing);
    expect(find.text('Trip dates not set'), findsNothing);
    expect(find.text('Set dates'), findsNothing);
  });
}

class _LocationSource implements PackingLocationSource {
  const _LocationSource();

  @override
  Future<List<PackingLocationOption>> load() async => const [
    PackingLocationOption(
      id: 'test-trip',
      label: 'Eco Lodge',
      subtitle: 'Saved Eco Partner',
      latitude: 3.139,
      longitude: 101.687,
      categories: {DestinationCategory.attraction},
      ecoPartnerCategory: EcoPartnerCategory.stay,
    ),
  ];
}

class _ItineraryLocationSource implements PackingLocationSource {
  const _ItineraryLocationSource();

  @override
  Future<List<PackingLocationOption>> load() async => const [
    PackingLocationOption(
      id: 'saved-itinerary',
      label: 'Kuala Lumpur',
      subtitle: 'Saved itinerary',
      latitude: 3.139,
      longitude: 101.687,
      categories: {DestinationCategory.attraction},
    ),
  ];
}

class _WeatherService extends PackingWeatherService {
  @override
  Future<PackingWeatherSummary?> getForecast({
    required double latitude,
    required double longitude,
  }) async => null;
}

class _ChecklistRepository implements PackingChecklistRepositoryContract {
  final Map<String, PackingTripDateRange> dates = {};

  @override
  Future<void> clearTripDates(String locationId) async {
    dates.remove(locationId);
  }

  @override
  Future<List<PackingChecklistItem>> loadCustomItems() async => const [];

  @override
  Future<Set<String>> loadPackedIds(String locationId) async => {};

  @override
  Future<PackingTripDateRange?> loadTripDates(String locationId) async =>
      dates[locationId];

  @override
  Future<String?> loadSelection() async => null;

  @override
  Future<void> saveCustomItems(List<PackingChecklistItem> items) async {}

  @override
  Future<void> savePackedIds(String locationId, Set<String> ids) async {}

  @override
  Future<void> saveSelection(String locationId) async {}

  @override
  Future<void> saveTripDates(
    String locationId,
    PackingTripDateRange dates,
  ) async {
    this.dates[locationId] = dates;
  }
}
