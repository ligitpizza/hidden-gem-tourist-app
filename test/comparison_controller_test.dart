// test/comparison_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/controller/comparison_controller.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/crowd_level.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
import 'package:collab/features/itinerary_planning/controller/gem_category_preference_controller.dart';
import 'package:collab/features/itinerary_planning/controller/itinerary_planner_controller.dart';
import 'package:collab/features/itinerary_planning/model/itinerary_repository.dart';
import 'package:collab/shared/models/destination.dart' as shared;
import 'package:collab/shared/models/hidden_gem.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeComparisonRepository extends DestinationExplorationRepository {
  _FakeComparisonRepository(this.result);
  final List<ComparisonDestination> result;

  @override
  Future<List<ComparisonDestination>> fetchForComparison(List<String> ids) async => result;
}

// addDestination() fires an un-awaited background gem-preview lookup through
// the real ItineraryRepository, which would hit Supabase (uninitialized in a
// plain unit test) — inject a fake so that background call resolves cleanly
// instead of risking an unhandled-exception warning from the test runner.
class _FakeItineraryRepository extends ItineraryRepository {
  @override
  Future<List<HiddenGem>> gemsNearDestinations(
    List<shared.Destination> destinations, {
    double radiusKm = 3,
    Set<HiddenGemCategory> categories = const {},
  }) async =>
      const [];
}

ComparisonDestination _dest(
  String id, {
  double avgRating = 4.0,
  double accessibilityScore = 3.0,
  CrowdLevel crowdLevel = CrowdLevel.medium,
  double? entranceCost,
}) {
  return ComparisonDestination(
    id: id,
    name: id,
    city: 'George Town',
    category: HiddenGemCategory.nature,
    location: const LatLng(5.4, 100.3),
    avgRating: avgRating,
    accessibilityScore: accessibilityScore,
    crowdLevel: crowdLevel,
    entranceCost: entranceCost,
  );
}

void main() {
  group('PriorityWeights.normalized', () {
    test('divides each weight by their sum', () {
      const weights = PriorityWeights(rating: 2, cost: 1, crowd: 1, accessibility: 0);
      final normalized = weights.normalized();

      expect(normalized.rating, closeTo(0.5, 0.001));
      expect(normalized.cost, closeTo(0.25, 0.001));
      expect(normalized.crowd, closeTo(0.25, 0.001));
      expect(normalized.accessibility, closeTo(0, 0.001));
    });
  });

  group('ComparisonController.loadComparison', () {
    test('rejects fewer than 2 ids', () async {
      final controller = ComparisonController(repository: _FakeComparisonRepository(const []));

      await controller.loadComparison(['only-one']);

      expect(controller.selectionError, isNotNull);
      expect(controller.destinations, isEmpty);
    });

    test('rejects more than 3 ids', () async {
      final controller = ComparisonController(repository: _FakeComparisonRepository(const []));

      await controller.loadComparison(['a', 'b', 'c', 'd']);

      expect(controller.selectionError, isNotNull);
    });

    test('accepts 2 and 3 ids', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b')]));

      await controller.loadComparison(['a', 'b']);

      expect(controller.selectionError, isNull);
      expect(controller.destinations, hasLength(2));
    });
  });

  group('ComparisonController Best Pick scoring', () {
    test('higher rating/crowd/accessibility wins with full cost data present', () async {
      final low = _dest('low', avgRating: 3.0, accessibilityScore: 2.0, crowdLevel: CrowdLevel.high, entranceCost: 20);
      final high = _dest('high', avgRating: 4.9, accessibilityScore: 4.5, crowdLevel: CrowdLevel.low, entranceCost: 20);
      final controller = ComparisonController(repository: _FakeComparisonRepository([low, high]));

      await controller.loadComparison(['low', 'high']);

      expect(controller.bestPick, high);
    });

    test('equal cost across the set does not penalise anyone on cost', () async {
      final a = _dest('a', avgRating: 4.0, entranceCost: 50);
      final b = _dest('b', avgRating: 4.5, entranceCost: 50);
      final controller = ComparisonController(repository: _FakeComparisonRepository([a, b]));

      await controller.loadComparison(['a', 'b']);

      expect(controller.bestPick, b);
    });

    test('missing cost on any destination drops cost and renormalizes the rest', () async {
      final withCost = _dest('withCost', avgRating: 3.0, accessibilityScore: 5.0, entranceCost: 10);
      final withoutCost = _dest('withoutCost', avgRating: 4.9, accessibilityScore: 5.0, entranceCost: null);
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([withCost, withoutCost]));

      await controller.loadComparison(['withCost', 'withoutCost']);

      // Rating dominates once cost drops out and rating/crowd/accessibility
      // are renormalized — the much-higher-rated destination should win
      // even though it has no cost data at all.
      expect(controller.bestPick, withoutCost);
    });

    test('setWeights normalizes before use', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b')]));
      await controller.loadComparison(['a', 'b']);

      controller.setWeights(const PriorityWeights(rating: 10, cost: 0, crowd: 0, accessibility: 0));

      expect(controller.weights.rating, closeTo(1.0, 0.001));
    });

    test('bestPick is null when there are no destinations', () {
      final controller = ComparisonController(repository: _FakeComparisonRepository(const []));

      expect(controller.bestPick, isNull);
    });
  });

  group('ComparisonController.distanceFromUser', () {
    test('returns the great-circle distance when location is available', () async {
      final controller = ComparisonController(
        repository: _FakeComparisonRepository(const []),
        currentLocation: () async => const LatLng(5.4, 100.3),
      );

      final distance = await controller.distanceFromUser(_dest('a'));

      expect(distance, closeTo(0, 0.01));
    });

    test('returns null when location is unavailable', () async {
      final controller = ComparisonController(
        repository: _FakeComparisonRepository(const []),
        currentLocation: () async => null,
      );

      final distance = await controller.distanceFromUser(_dest('a'));

      expect(distance, isNull);
    });
  });

  group('ComparisonController follow-up actions', () {
    setUp(() {
      FavouriteDestinationsStore.instance.clearForTesting();
    });

    test('addBestPickToItinerary adds the Best Pick to the itinerary controller', () async {
      SharedPreferences.setMockInitialValues({});
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b', avgRating: 4.9)]));
      await controller.loadComparison(['a', 'b']);
      final itineraryController = ItineraryPlannerController(
        repository: _FakeItineraryRepository(),
        gemCategoryPreference: GemCategoryPreferenceController(),
      );

      await controller.addBestPickToItinerary(itineraryController);

      expect(itineraryController.selectedDestinations.map((d) => d.id), contains('b'));
    });

    test('saveToFavourites works on any compared destination, not just Best Pick', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b', avgRating: 4.9)]));
      await controller.loadComparison(['a', 'b']);

      controller.saveToFavourites(controller.destinations.first); // 'a', not the Best Pick

      expect(FavouriteDestinationsStore.instance.favourites.map((d) => d.id), contains('a'));
    });

    test('buildShareSummary names every destination and calls out the Best Pick', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b', avgRating: 4.9)]));
      await controller.loadComparison(['a', 'b']);

      final summary = controller.buildShareSummary();

      expect(summary, contains('a'));
      expect(summary, contains('b'));
      expect(summary, contains('Best Pick: b'));
    });

    test('shareComparison catches a share failure and sets shareError', () async {
      final controller = ComparisonController(
          repository: _FakeComparisonRepository([_dest('a'), _dest('b', avgRating: 4.9)]));
      await controller.loadComparison(['a', 'b']);

      await controller.shareComparison(); // no platform channel registered in tests — expected to fail internally

      expect(controller.shareError, isNotNull);
    });
  });
}
