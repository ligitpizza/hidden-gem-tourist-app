import 'package:supabase_flutter/supabase_flutter.dart';

import 'itinerary_plan.dart';
import 'itinerary_plan_codec.dart';
import 'saved_itinerary.dart';

/// Reads/writes generated itineraries to the `saved_itineraries` table
/// (user-scoped via RLS — see supabase/migrations/202608130001_saved_itineraries.sql).
class SavedItineraryRepository {
  SavedItineraryRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('A signed-in user is required.');
    return user.id;
  }

  Future<List<SavedItinerary>> fetchAll() async {
    final rows = await _client
        .from('saved_itineraries')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => _mapRow((row as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<SavedItinerary> save(ItineraryPlan plan) async {
    final row = await _client
        .from('saved_itineraries')
        .insert({
          'user_id': _userId,
          'plan': ItineraryPlanCodec.toJson(plan),
        })
        .select()
        .single();
    return _mapRow(row);
  }

  Future<SavedItinerary> update(String id, ItineraryPlan plan) async {
    final row = await _client
        .from('saved_itineraries')
        .update({'plan': ItineraryPlanCodec.toJson(plan)})
        .eq('id', id)
        .eq('user_id', _userId)
        .select()
        .single();
    return _mapRow(row);
  }

  Future<void> delete(String id) async {
    await _client.from('saved_itineraries').delete().eq('id', id).eq('user_id', _userId);
  }

  SavedItinerary _mapRow(Map<String, dynamic> row) => SavedItinerary(
        id: row['id'] as String,
        plan: ItineraryPlanCodec.fromJson((row['plan'] as Map).cast<String, dynamic>()),
        savedAt: DateTime.parse(row['created_at'] as String),
      );
}
