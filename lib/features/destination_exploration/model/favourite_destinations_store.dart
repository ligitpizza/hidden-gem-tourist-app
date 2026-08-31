import 'package:flutter/foundation.dart';

import 'comparison_destination.dart';
import 'favourite_destination_repository.dart';

/// Live view over the traveller's favourited destinations, backed by
/// Supabase (`destination_favourites` table, user-scoped via RLS). A
/// [ChangeNotifier] singleton so the Saved screen can rebuild via
/// [ListenableBuilder] the moment something is saved from the Comparison
/// screen, without either screen owning the state — mirrors
/// SavedItinerariesStore's shape (lib/features/itinerary_planning/model/
/// saved_itineraries_store.dart).
class FavouriteDestinationsStore extends ChangeNotifier {
  FavouriteDestinationsStore({FavouriteDestinationRepository? repository})
      : _repository = repository ?? FavouriteDestinationRepository();

  // Mutable (not `final`) so tests can swap in a fake-repository-backed
  // instance instead of hitting real Supabase through the default —
  // ComparisonController.saveToFavourites always goes through this
  // singleton rather than an injected store.
  static FavouriteDestinationsStore instance = FavouriteDestinationsStore();

  final FavouriteDestinationRepository _repository;

  List<ComparisonDestination> _favourites = [];
  bool isLoading = false;
  String? error;
  bool _loadedOnce = false;

  List<ComparisonDestination> get favourites => List.unmodifiable(_favourites);

  bool contains(String id) => _favourites.any((d) => d.id == id);

  /// Loads from Supabase the first time this is called; a no-op afterwards
  /// unless [refresh] is called explicitly (e.g. pull-to-refresh).
  Future<void> ensureLoaded() async {
    if (_loadedOnce || isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      _favourites = await _repository.fetchAll();
      _loadedOnce = true;
    } catch (_) {
      error = 'Could not load your favourite destinations. Check your connection and try again.';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> add(ComparisonDestination destination) async {
    if (contains(destination.id)) return;
    _favourites = [destination, ..._favourites];
    _loadedOnce = true;
    notifyListeners();
    try {
      await _repository.add(destination.id);
    } catch (_) {
      _favourites = _favourites.where((d) => d.id != destination.id).toList(); // rollback
      error = 'Could not save this destination. Check your connection and try again.';
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    final previous = _favourites;
    _favourites = _favourites.where((d) => d.id != id).toList();
    notifyListeners();
    try {
      await _repository.remove(id);
    } catch (_) {
      _favourites = previous; // rollback — the delete didn't actually go through
      error = 'Could not remove this favourite. Check your connection and try again.';
      notifyListeners();
    }
  }

  /// Test-only reset — the singleton otherwise persists state across tests.
  void clearForTesting() {
    _favourites = [];
    isLoading = false;
    error = null;
    _loadedOnce = false;
  }
}
