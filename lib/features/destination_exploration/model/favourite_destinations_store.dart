import 'package:flutter/foundation.dart';

import 'comparison_destination.dart';

/// In-memory holding pen for favourited destinations until a real
/// persistence layer is agreed on for this module — same "no real
/// persistence yet" stance as SavedItinerariesStore
/// (lib/features/itinerary_planning/model/saved_itineraries_store.dart).
///
/// A [ChangeNotifier] (rather than a plain singleton) so the Saved screen's
/// favourites section can rebuild live via [ListenableBuilder] when
/// something is added from the comparison screen.
class FavouriteDestinationsStore extends ChangeNotifier {
  FavouriteDestinationsStore._internal();

  static final FavouriteDestinationsStore instance = FavouriteDestinationsStore._internal();

  final List<ComparisonDestination> _favourites = [];

  List<ComparisonDestination> get favourites => List.unmodifiable(_favourites);

  bool contains(String id) => _favourites.any((d) => d.id == id);

  void add(ComparisonDestination destination) {
    if (contains(destination.id)) return;
    _favourites.add(destination);
    notifyListeners();
  }

  /// Test-only reset — the singleton otherwise persists state across tests.
  void clearForTesting() {
    _favourites.clear();
    notifyListeners();
  }
}
