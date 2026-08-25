import 'package:supabase_flutter/supabase_flutter.dart';

/// Logs a tourist's interactions with destinations (FR3.1) — the raw
/// signal `user_category_affinity` and the trending-detection job both
/// read. Fire-and-forget by design: a logging failure must never block the
/// user's actual action (viewing/searching/saving a place), so every
/// public method here swallows its own errors after one retry (matching
/// the "Interact with Destination" use case's E2: retry once, then give up
/// quietly and preserve the previous state rather than surface an error).
///
/// Other modules call this directly to report an interaction — it's the
/// one piece of Module 1 other feature owners are expected to import; the
/// category tag itself is filled in server-side (via the
/// `user_interactions_set_category` trigger from
/// `place_travel_style_map`), so callers only ever need a place id.
class InteractionRepository {
  InteractionRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> logView(String placeId) => _log(placeId, 'view');
  Future<void> logSearch(String placeId) => _log(placeId, 'search');
  Future<void> logSave(String placeId) => _log(placeId, 'save');
  Future<void> logItineraryAdd(String placeId) => _log(placeId, 'itinerary_add');

  /// Undoes a bookmark tap — removes this tourist's `save` interaction(s)
  /// on [placeId]. Deliberately the only reversible interaction type
  /// (view/search stay append-only, real history); backed by a
  /// `for delete ... where interaction_type = 'save'` RLS policy, so this
  /// can never touch a view/search row even if called with the wrong id.
  Future<void> unsave(String placeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _client
            .from('user_interactions')
            .delete()
            .eq('user_id', userId)
            .eq('place_id', placeId)
            .eq('interaction_type', 'save');
        return;
      } catch (_) {
        // Retry once, then drop it silently — see class doc.
      }
    }
  }

  Future<void> _log(String placeId, String interactionType) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _client.from('user_interactions').insert({
          'user_id': userId,
          'place_id': placeId,
          'interaction_type': interactionType,
        });
        return;
      } catch (_) {
        // Retry once (E2), then drop it silently — see class doc.
      }
    }
  }
}
