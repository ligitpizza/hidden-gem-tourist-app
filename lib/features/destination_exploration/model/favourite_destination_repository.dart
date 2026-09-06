import 'package:supabase_flutter/supabase_flutter.dart';

import 'comparison_destination.dart';
import 'destination_exploration_repository.dart';

/// Reads/writes the traveller's favourited destinations to the
/// `destination_favourites` table (user-scoped via RLS — see
/// supabase/migrations/202608180001_destination_favourites.sql). Mirrors
/// SavedItineraryRepository's shape (lib/features/itinerary_planning/model/
/// saved_itinerary_repository.dart).
///
/// The table only stores the (user_id, destination_id) relationship, not a
/// copy of the destination's fields.
///
/// UPDATE (20260902140000_favourite_destinations_on_places.sql):
/// `destination_id` now references `public.places`, not
/// `public.destinations` — Module 1's Hidden Gem bookmark writes here too,
/// so [fetchAll] resolves rows from the `place_hidden_gem_candidates` view
/// (reusing [DestinationExplorationRepository.mapComparisonRow], which
/// already maps every column this needs by name) rather than
/// [DestinationExplorationRepository.fetchForComparison], which only ever
/// queries `destinations` and would silently drop any Module 1 favourite
/// from this list. This is safe because every `destinations` row was
/// copied into `places` with the same id
/// (20260902120000_merge_destinations_and_add_photos.sql) — `places.id` is
/// a superset of `destinations.id`, so every existing favourite still
/// resolves correctly under the new query. The view, not the raw `places`
/// table, on purpose: `places` has no `avg_rating` column at all (it's
/// only ever computed here from real `reviews` rows) — querying the table
/// directly silently showed 0.0 stars for every favourite regardless of
/// its real rating (20260902150000_favourite_view_full_columns.sql).
class FavouriteDestinationRepository {
  FavouriteDestinationRepository({SupabaseClient? client}) : _clientOverride = client;

  // Resolved lazily (not in the initializer list) so a subclass that
  // overrides every method that touches it — e.g. a test fake — never
  // forces Supabase.instance to be initialized just by being constructed.
  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('A signed-in user is required.');
    return user.id;
  }

  Future<List<ComparisonDestination>> fetchAll() async {
    final rows = await _client
        .from('destination_favourites')
        .select('destination_id')
        .eq('user_id', _userId)
        .order('saved_at', ascending: false);

    final ids = (rows as List).map((row) => (row as Map)['destination_id'] as String).toList();
    if (ids.isEmpty) return const [];

    // Query the view, not the raw `places` table -- `places` has no
    // avg_rating column at all (it's only ever computed here, from real
    // `reviews` rows), so querying the table directly silently showed
    // 0.0 stars for every favourite regardless of its real rating. This
    // view now carries every other column mapComparisonRow needs too
    // (crowd_level, entrance_cost, etc. -- added in
    // 20260902150000_favourite_view_full_columns.sql).
    final placeRows = await _client.from('place_hidden_gem_candidates').select().inFilter('id', ids);
    final destinations =
        (placeRows as List).map((row) => DestinationExplorationRepository.mapComparisonRow(row as Map<String, dynamic>)).toList();

    // Row order isn't preserved by inFilter, and a place deleted since
    // being favourited simply won't come back -- order to match the
    // favourited (most-recent-first) order from destination_favourites
    // instead of whatever order came back above.
    final byId = {for (final d in destinations) d.id: d};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  Future<void> add(String destinationId) async {
    await _client.from('destination_favourites').upsert(
      {'user_id': _userId, 'destination_id': destinationId},
      onConflict: 'user_id,destination_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> remove(String destinationId) async {
    await _client
        .from('destination_favourites')
        .delete()
        .eq('user_id', _userId)
        .eq('destination_id', destinationId);
  }
}
