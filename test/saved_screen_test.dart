// test/saved_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/favourite_destination_repository.dart';
import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
import 'package:collab/features/gamification_journal/controller/badge_controller.dart';
import 'package:collab/features/gamification_journal/controller/checkin_controller.dart';
import 'package:collab/features/gamification_journal/controller/journal_controller.dart';
import 'package:collab/features/gamification_journal/controller/quiz_controller.dart';
import 'package:collab/features/gamification_journal/view/checkin/destination_detail_screen.dart';
import 'package:collab/features/itinerary_planning/model/saved_itineraries_store.dart';
import 'package:collab/features/itinerary_planning/model/saved_itinerary_repository.dart';
import 'package:collab/features/saved/view/saved_screen.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeSavedItineraryRepository extends SavedItineraryRepository {
  // Passed explicitly so the base constructor never falls through to
  // Supabase.instance.client, which throws outside a real app/Supabase.
  // initialize() call — see itinerary_planner_controller_test.dart for the
  // same pattern.
  _FakeSavedItineraryRepository() : super(client: SupabaseClient('https://example.supabase.co', 'test-key'));
}

class _FakeFavouriteRepository extends FavouriteDestinationRepository {
  @override
  Future<void> add(String destinationId) async {}
  @override
  Future<void> remove(String destinationId) async {}
  @override
  Future<List<ComparisonDestination>> fetchAll() async => const [];
}

const _favourite = ComparisonDestination(
  id: 'd1',
  name: 'Kek Lok Si Temple',
  city: 'George Town',
  category: HiddenGemCategory.culture,
  location: LatLng(5.4, 100.3),
  avgRating: 4.5,
);

Widget _wrap() {
  return ProviderScope(
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<CheckInController>(create: (_) => CheckInController(userId: 'u1')),
        ChangeNotifierProvider<QuizController>(create: (_) => QuizController(userId: 'u1')),
        ChangeNotifierProvider<BadgeController>(create: (_) => BadgeController(userId: 'u1')),
        ChangeNotifierProvider<JournalController>(create: (_) => JournalController(userId: 'u1')),
      ],
      child: const MaterialApp(home: SavedScreen()),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SavedItinerariesStore.instance = SavedItinerariesStore(repository: _FakeSavedItineraryRepository());
    FavouriteDestinationsStore.instance = FavouriteDestinationsStore(repository: _FakeFavouriteRepository())
      ..add(_favourite);
  });

  testWidgets('tapping a favourite card opens the destination detail page', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Kek Lok Si Temple'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(DestinationDetailScreen), findsOneWidget);
  });

  testWidgets('category filter chips narrow the favourites list', (tester) async {
    const foodFavourite = ComparisonDestination(
      id: 'd2',
      name: 'Seng Thor Restaurant',
      city: 'George Town',
      category: HiddenGemCategory.food,
      location: LatLng(5.41, 100.31),
    );
    await FavouriteDestinationsStore.instance.add(foodFavourite);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Kek Lok Si Temple'), findsOneWidget);
    expect(find.text('Seng Thor Restaurant'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Culture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Kek Lok Si Temple'), findsOneWidget);
    expect(find.text('Seng Thor Restaurant'), findsNothing);
  });
}
