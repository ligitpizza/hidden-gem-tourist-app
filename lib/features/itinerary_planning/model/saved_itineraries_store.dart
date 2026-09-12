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
  String? _userScope;
  int _accountRevision = 0;

  List<SavedItinerary> get saved => List.unmodifiable(_saved);

  /// Clears cached records when authentication moves to another user.
  /// Pending work is tagged with [_accountRevision], so a late response from
  /// the previous account cannot repopulate this store after the switch.
  void scopeToUser(String? userId) {
    final nextScope = userId ?? 'guest';
    if (_userScope == nextScope) return;
    _userScope = nextScope;
    _accountRevision++;
    _saved = [];
    isLoading = false;
    error = null;
    _loadedOnce = false;
  }

  /// Loads from Supabase the first time this is called; a no-op afterwards
  /// unless [refresh] is called explicitly (e.g. pull-to-refresh).
  Future<void> ensureLoaded() async {
    if (_loadedOnce || isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    final revision = _accountRevision;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final saved = await _repository.fetchAll();
      if (revision != _accountRevision) return;
      _saved = saved;
      _loadedOnce = true;
    } catch (_) {
      if (revision != _accountRevision) return;
      error =
          'Could not load your saved itineraries. Check your connection and try again.';
    }
    if (revision != _accountRevision) return;
    isLoading = false;
    notifyListeners();
  }

  Future<SavedItinerary> save(ItineraryPlan plan) async {
    final revision = _accountRevision;
    final saved = await _repository.save(plan);
    if (revision != _accountRevision) return saved;
    _saved = [saved, ..._saved];
    _loadedOnce = true;
    notifyListeners();
    return saved;
  }

  Future<SavedItinerary> update(String id, ItineraryPlan plan) async {
    final revision = _accountRevision;
    final updated = await _repository.update(id, plan);
    if (revision != _accountRevision) return updated;
    _saved = [
      for (final item in _saved)
        if (item.id == id) updated else item,
    ];
    notifyListeners();
    return updated;
  }

  Future<void> remove(String id) async {
    final revision = _accountRevision;
    final previous = _saved;
    _saved = _saved.where((item) => item.id != id).toList();
    notifyListeners();
    try {
      await _repository.delete(id);
    } catch (_) {
      if (revision != _accountRevision) return;
      _saved = previous; // rollback — the delete didn't actually go through
      error =
          'Could not remove this itinerary. Check your connection and try again.';
      notifyListeners();
    }
  }
}
