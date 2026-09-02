import 'package:flutter/foundation.dart';

import 'itinerary_plan.dart';
import 'saved_itinerary.dart';
import 'saved_itinerary_repository.dart';

/// Live view over the traveller's saved itineraries, backed by Supabase
/// (`saved_itineraries` table, user-scoped via RLS). A [ChangeNotifier]
/// singleton so the Saved screen can rebuild via [ListenableBuilder] the
/// moment something is saved from Route Optimized, without either screen
/// owning the state.
class SavedItinerariesStore extends ChangeNotifier {
  SavedItinerariesStore({SavedItineraryRepository? repository})
      : _repository = repository ?? SavedItineraryRepository();

  // Mutable (not `final`) so tests can swap in a fake-repository-backed
  // instance instead of hitting real Supabase through the default —
  // mirrors FavouriteDestinationsStore's identical shape (lib/features/
  // destination_exploration/model/favourite_destinations_store.dart).
  static SavedItinerariesStore instance = SavedItinerariesStore();

  final SavedItineraryRepository _repository;

  List<SavedItinerary> _saved = [];
  bool isLoading = false;
  String? error;
  bool _loadedOnce = false;

  List<SavedItinerary> get saved => List.unmodifiable(_saved);

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
      _saved = await _repository.fetchAll();
      _loadedOnce = true;
    } catch (_) {
      error = 'Could not load your saved itineraries. Check your connection and try again.';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<SavedItinerary> save(ItineraryPlan plan) async {
    final saved = await _repository.save(plan);
    _saved = [saved, ..._saved];
    _loadedOnce = true;
    notifyListeners();
    return saved;
  }

  Future<SavedItinerary> update(String id, ItineraryPlan plan) async {
    final updated = await _repository.update(id, plan);
    _saved = [for (final item in _saved) if (item.id == id) updated else item];
    notifyListeners();
    return updated;
  }

  Future<void> remove(String id) async {
    final previous = _saved;
    _saved = _saved.where((item) => item.id != id).toList();
    notifyListeners();
    try {
      await _repository.delete(id);
    } catch (_) {
      _saved = previous; // rollback — the delete didn't actually go through
      error = 'Could not remove this itinerary. Check your connection and try again.';
      notifyListeners();
    }
  }
}
