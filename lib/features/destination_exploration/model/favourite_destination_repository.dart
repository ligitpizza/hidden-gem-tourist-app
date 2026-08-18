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
/// copy of the destination's fields — [fetchAll] resolves the full
/// [ComparisonDestination] rows via the existing [DestinationExplorationRepository.fetchForComparison]
/// rather than duplicating that mapping here.
class FavouriteDestinationRepository {
  FavouriteDestinationRepository({
    SupabaseClient? client,
    DestinationExplorationRepository? destinationRepository,
  })  : _clientOverride = client,
        _destinationRepository = destinationRepository ?? DestinationExplorationRepository();

  // Resolved lazily (not in the initializer list) so a subclass that
  // overrides every method that touches it — e.g. a test fake — never
  // forces Supabase.instance to be initialized just by being constructed.
  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  final DestinationExplorationRepository _destinationRepository;

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

    // fetchForComparison doesn't preserve input order, and a destination
    // deleted since being favourited simply won't come back — order the
    // resolved destinations to match the favourited (most-recent-first)
    // order rather than whatever fetchForComparison happens to return.
    final destinations = await _destinationRepository.fetchForComparison(ids);
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
