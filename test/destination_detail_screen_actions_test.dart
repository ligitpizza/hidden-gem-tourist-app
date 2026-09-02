// test/destination_detail_screen_actions_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/favourite_destination_repository.dart';
import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
import 'package:collab/features/gamification_journal/controller/badge_controller.dart';
import 'package:collab/features/gamification_journal/controller/checkin_controller.dart';
import 'package:collab/features/gamification_journal/controller/journal_controller.dart';
import 'package:collab/features/gamification_journal/controller/quiz_controller.dart';
import 'package:collab/features/gamification_journal/model/destination_model.dart';
import 'package:collab/features/gamification_journal/view/checkin/destination_detail_screen.dart';
import 'package:collab/features/itinerary_planning/controller/itinerary_planner_controller.dart';
import 'package:collab/shared/models/hidden_gem.dart';

final _destination = DestinationModel(
  id: 'd1',
  name: 'Escape Penang',
  state: 'Penang',
  category: 'Nature',
  latitude: 5.4489,
  longitude: 100.2492,
  description: 'An outdoor adventure park.',
  imageUrl: 'https://example.com/img.png',
);

class _FakeFavouriteRepository extends FavouriteDestinationRepository {
  final List<String> addedIds = [];
  @override
  Future<void> add(String destinationId) async => addedIds.add(destinationId);
  @override
  Future<void> remove(String destinationId) async {}
  @override
  Future<List<ComparisonDestination>> fetchAll() async => const [];
}

class _FakeDestinationExplorationRepository extends DestinationExplorationRepository {
  @override
  Future<List<ComparisonDestination>> fetchForComparison(List<String> ids) async => [
        const ComparisonDestination(
          id: 'd1',
          name: 'Escape Penang',
          city: 'Penang',
          category: HiddenGemCategory.nature,
          location: LatLng(5.4489, 100.2492),
        ),
      ];
}

List<ChangeNotifierProvider> _journalProviders() => [
      ChangeNotifierProvider<CheckInController>(create: (_) => CheckInController(userId: 'u1')),
      ChangeNotifierProvider<QuizController>(create: (_) => QuizController(userId: 'u1')),
      ChangeNotifierProvider<BadgeController>(create: (_) => BadgeController(userId: 'u1')),
      ChangeNotifierProvider<JournalController>(create: (_) => JournalController(userId: 'u1')),
    ];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FavouriteDestinationsStore.instance = FavouriteDestinationsStore(
      repository: _FakeFavouriteRepository(),
      destinationRepository: _FakeDestinationExplorationRepository(),
    );
  });

  testWidgets('shows Save to Favourites and Add to Itinerary Route below Check In', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MultiProvider(
          providers: _journalProviders(),
          child: MaterialApp(home: DestinationDetailScreen(destination: _destination)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final checkInFinder = find.text('Check In Here');
    final favFinder = find.text('Save to Favourites');
    final itineraryFinder = find.text('Add to Itinerary Route');
    expect(checkInFinder, findsOneWidget);
    expect(favFinder, findsOneWidget);
    expect(itineraryFinder, findsOneWidget);

    // Both new buttons render after (below) the Check In button.
    final checkInY = tester.getCenter(checkInFinder).dy;
    expect(tester.getCenter(favFinder).dy, greaterThan(checkInY));
    expect(tester.getCenter(itineraryFinder).dy, greaterThan(checkInY));
  });

  testWidgets('tapping Save to Favourites adds the destination and flips the button state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MultiProvider(
          providers: _journalProviders(),
          child: MaterialApp(home: DestinationDetailScreen(destination: _destination)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.ensureVisible(find.text('Save to Favourites'));
    await tester.tap(find.text('Save to Favourites'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Saved to Favourites'), findsOneWidget);
  });

  testWidgets('tapping Add to Itinerary Route adds the destination to the itinerary planner', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MultiProvider(
          providers: _journalProviders(),
          child: MaterialApp(home: DestinationDetailScreen(destination: _destination)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.ensureVisible(find.text('Add to Itinerary Route'));
    await tester.tap(find.text('Add to Itinerary Route'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final itineraryController = container.read(itineraryPlannerControllerProvider);
    expect(itineraryController.selectedDestinations.map((d) => d.id), contains('d1'));
  });
}
