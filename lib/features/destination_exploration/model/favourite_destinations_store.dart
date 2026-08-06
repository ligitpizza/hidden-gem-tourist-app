import 'comparison_destination.dart';

/// In-memory holding pen for favourited destinations until a real
/// persistence layer is agreed on for this module — same "no real
/// persistence yet" stance as SavedItinerariesStore
/// (lib/features/itinerary_planning/model/saved_itineraries_store.dart).
class FavouriteDestinationsStore {
  FavouriteDestinationsStore._internal();

  static final FavouriteDestinationsStore instance = FavouriteDestinationsStore._internal();

  final List<ComparisonDestination> _favourites = [];

  List<ComparisonDestination> get favourites => List.unmodifiable(_favourites);

  void add(ComparisonDestination destination) {
    if (_favourites.any((d) => d.id == destination.id)) return;
    _favourites.add(destination);
  }

  /// Test-only reset — the singleton otherwise persists state across tests.
  void clearForTesting() => _favourites.clear();
}
