// test/itinerary_planner_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collab/features/itinerary_planning/controller/gem_category_preference_controller.dart';
import 'package:collab/features/itinerary_planning/controller/itinerary_planner_controller.dart';
import 'package:collab/features/itinerary_planning/model/itinerary_plan.dart';
import 'package:collab/features/itinerary_planning/model/itinerary_repository.dart';
import 'package:collab/features/itinerary_planning/model/route_metrics.dart';
import 'package:collab/features/itinerary_planning/model/route_path.dart';
import 'package:collab/features/itinerary_planning/model/saved_itineraries_store.dart';
import 'package:collab/features/itinerary_planning/model/saved_itinerary.dart';
import 'package:collab/features/itinerary_planning/model/saved_itinerary_repository.dart';
import 'package:collab/features/itinerary_planning/model/visit_duration_option.dart';
import 'package:collab/shared/models/destination.dart';
import 'package:collab/shared/models/travel_mode.dart';

const _stopA = Destination(
  id: 'a1',
  name: 'Nyonya Baba Cuisine Cafe',
  city: 'George Town',
  category: DestinationCategory.restaurant,
  location: LatLng(5.41, 100.33),
);
const _stopB = Destination(
  id: 'b1',
  name: 'Seng Thor Restaurant',
  city: 'George Town',
  category: DestinationCategory.restaurant,
  location: LatLng(5.42, 100.34),
);

RoutePath _fakeRoutePath(String id, {required bool isRecommended}) => RoutePath(
      id: id,
      label: 'Path $id',
      isRecommended: isRecommended,
      polyline: const [LatLng(5.41, 100.33), LatLng(5.42, 100.34)],
      hiddenGems: const [],
      metricsByMode: const {
        TravelMode.driving: RouteMetrics(distanceKm: 5, durationMinutes: 15, costMyr: 10),
        TravelMode.walking: RouteMetrics(distanceKm: 5, durationMinutes: 60, costMyr: 0),
        TravelMode.public: RouteMetrics(distanceKm: 5, durationMinutes: 30, costMyr: 3),
      },
    );

/// Builds a minimal-but-real [ItineraryPlan] for [destinations] — the exact
/// route/metrics values don't matter for this test, only that the object is
/// valid enough for ItineraryPlannerController to hold in `plan` and read
/// `plan.primaryPath.id` from.
ItineraryPlan _buildFakePlan(List<Destination> destinations) => ItineraryPlan(
      destinations: destinations,
      durationOption: null,
      primaryPath: _fakeRoutePath('A', isRecommended: true),
      alternatePath: _fakeRoutePath('B', isRecommended: false),
      timeline: const [],
      estimatedMinutesNeeded: 15,
      budgetMinutes: null,
    );

class _FakeItineraryRepository extends ItineraryRepository {
  @override
  Future<ItineraryPlan> generate({
    required List<Destination> destinations,
    required VisitDurationOption? durationOption,
    int? customDays,
    Set<DestinationCategory> gemCategories = const {},
  }) async =>
      _buildFakePlan(destinations);
}

class _FakeSavedItineraryRepository extends SavedItineraryRepository {
  // Passed explicitly so the base constructor never falls through to
  // Supabase.instance.client, which throws outside a real app/Supabase.
  // initialize() call — see travel_prep_cover_image_test.dart for the same
  // pattern used elsewhere in this suite.
  _FakeSavedItineraryRepository() : super(client: SupabaseClient('https://example.supabase.co', 'test-key'));

  int saveCalls = 0;
  int updateCalls = 0;
  final List<String> updatedIds = [];

  @override
  Future<SavedItinerary> save(ItineraryPlan plan) async {
    saveCalls++;
    return SavedItinerary(id: 'saved-$saveCalls', plan: plan, savedAt: DateTime(2026));
  }

  @override
  Future<SavedItinerary> update(String id, ItineraryPlan plan) async {
    updateCalls++;
    updatedIds.add(id);
    return SavedItinerary(id: id, plan: plan, savedAt: DateTime(2026));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'saving a fresh itinerary, then planning a second one without clearing manually, creates a NEW record',
      () async {
    final fakeSavedRepo = _FakeSavedItineraryRepository();
    SavedItinerariesStore.instance = SavedItinerariesStore(repository: fakeSavedRepo);

    final controller = ItineraryPlannerController(
      repository: _FakeItineraryRepository(),
      gemCategoryPreference: GemCategoryPreferenceController(),
    );

    // First itinerary: add both stops, generate, save.
    controller.addDestination(_stopA);
    controller.addDestination(_stopB);
    await controller.generateItinerary();
    await controller.saveToAccount();

    expect(fakeSavedRepo.saveCalls, 1);
    expect(controller.selectedDestinations, isEmpty);

    // Second, unrelated itinerary — no manual "clear all chips" step first.
    controller.addDestination(_stopA);
    await controller.generateItinerary();
    await controller.saveToAccount();

    expect(fakeSavedRepo.saveCalls, 2, reason: 'must INSERT a second record, not update the first');
    expect(fakeSavedRepo.updateCalls, 0);
  });

  test('editing a previously-saved itinerary via loadSavedItinerary still updates it in place', () async {
    final fakeSavedRepo = _FakeSavedItineraryRepository();
    SavedItinerariesStore.instance = SavedItinerariesStore(repository: fakeSavedRepo);

    final controller = ItineraryPlannerController(
      repository: _FakeItineraryRepository(),
      gemCategoryPreference: GemCategoryPreferenceController(),
    );

    final existingPlan = _buildFakePlan([_stopA, _stopB]);
    controller.loadSavedItinerary(SavedItinerary(id: 'existing-1', plan: existingPlan, savedAt: DateTime(2026)));

    await controller.saveToAccount();

    expect(fakeSavedRepo.updateCalls, 1);
    expect(fakeSavedRepo.updatedIds, ['existing-1']);
    expect(fakeSavedRepo.saveCalls, 0);
  });
}
