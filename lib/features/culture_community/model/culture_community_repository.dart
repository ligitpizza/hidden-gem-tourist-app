import 'package:supabase_flutter/supabase_flutter.dart';

import 'cultural_event.dart';
import 'traditional_food.dart';
import 'traditional_food_place.dart';

class CultureCommunityRepository {
  CultureCommunityRepository({
    SupabaseClient? client,
  }) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client =>
      _clientOverride ?? Supabase.instance.client;

  // =========================================================
  // AUTH
  // =========================================================

  bool get isSignedIn =>
      _client.auth.currentUser != null;

  String _requireUserId() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError(
        'You must be signed in to use this feature.',
      );
    }

    return user.id;
  }

  // =========================================================
  // CULTURAL EVENTS
  // =========================================================

  Future<List<CulturalEvent>> fetchCulturalEvents() async {
    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    final rows = await _client
        .from('cultural_events')
        .select()
        .eq(
      'is_active',
      true,
    )
        .gte(
      'end_at',
      now,
    )
        .order(
      'start_at',
      ascending: true,
    );

    return (rows as List)
        .map(
          (row) => CulturalEvent.fromMap(
        (row as Map)
            .cast<String, dynamic>(),
      ),
    )
        .toList();
  }

  // =========================================================
  // TRADITIONAL FOODS
  // =========================================================

  Future<List<TraditionalFood>>
  fetchTraditionalFoods() async {
    final rows = await _client
        .from('traditional_foods')
        .select()
        .eq(
      'is_active',
      true,
    )
        .order(
      'name',
      ascending: true,
    );

    return (rows as List)
        .map(
          (row) => TraditionalFood.fromMap(
        (row as Map)
            .cast<String, dynamic>(),
      ),
    )
        .toList();
  }

  // =========================================================
  // CULTURAL EVENT FAVOURITES
  // =========================================================

  Future<bool> isCulturalEventFavourite(
      String eventId,
      ) async {
    final userId = _requireUserId();

    final result = await _client
        .from('cultural_event_favourites')
        .select('event_id')
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'event_id',
      eventId,
    )
        .maybeSingle();

    return result != null;
  }

  Future<void> addCulturalEventFavourite(
      String eventId,
      ) async {
    final userId = _requireUserId();

    await _client
        .from('cultural_event_favourites')
        .upsert(
      {
        'user_id': userId,
        'event_id': eventId,
      },
      onConflict: 'user_id,event_id',
    );
  }

  Future<void> removeCulturalEventFavourite(
      String eventId,
      ) async {
    final userId = _requireUserId();

    await _client
        .from('cultural_event_favourites')
        .delete()
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'event_id',
      eventId,
    );
  }

  // =========================================================
  // CULTURAL EVENT ITINERARY
  // =========================================================

  Future<bool> isCulturalEventInItinerary(
      String eventId,
      ) async {
    final userId = _requireUserId();

    final result = await _client
        .from(
      'cultural_event_itinerary_items',
    )
        .select('event_id')
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'event_id',
      eventId,
    )
        .maybeSingle();

    return result != null;
  }

  Future<void> addCulturalEventToItinerary({
    required String eventId,
    required DateTime plannedAt,
  }) async {
    final userId = _requireUserId();

    await _client
        .from(
      'cultural_event_itinerary_items',
    )
        .upsert(
      {
        'user_id': userId,
        'event_id': eventId,
        'planned_at':
        plannedAt.toIso8601String(),
      },
      onConflict: 'user_id,event_id',
    );
  }

  Future<void>
  removeCulturalEventFromItinerary(
      String eventId,
      ) async {
    final userId = _requireUserId();

    await _client
        .from(
      'cultural_event_itinerary_items',
    )
        .delete()
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'event_id',
      eventId,
    );
  }

  // =========================================================
  // TRADITIONAL FOOD FAVOURITES
  // =========================================================

  Future<bool> isTraditionalFoodFavourite(
      String foodId,
      ) async {
    final userId = _requireUserId();

    final result = await _client
        .from(
      'traditional_food_favourites',
    )
        .select('food_id')
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'food_id',
      foodId,
    )
        .maybeSingle();

    return result != null;
  }

  Future<void> addTraditionalFoodFavourite(
      String foodId,
      ) async {
    final userId = _requireUserId();

    await _client
        .from(
      'traditional_food_favourites',
    )
        .upsert(
      {
        'user_id': userId,
        'food_id': foodId,
      },
      onConflict: 'user_id,food_id',
    );
  }

  Future<void>
  removeTraditionalFoodFavourite(
      String foodId,
      ) async {
    final userId = _requireUserId();

    await _client
        .from(
      'traditional_food_favourites',
    )
        .delete()
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'food_id',
      foodId,
    );
  }

  // =========================================================
  // FOOD LOCATIONS
  //
  // traditional_foods
  //      ↓
  // traditional_food_location_foods
  //      ↓
  // food_locations
  // =========================================================

  Future<List<TraditionalFoodPlace>>
  fetchTraditionalFoodPlaces(
      String foodId,
      ) async {
    final rows = await _client
        .from(
      'traditional_food_location_foods',
    )
        .select(
      '''
          notes,
          verification_source,
          verification_url,
          verified_at,
          food_locations!inner(
            id,
            name,
            category,
            state,
            city,
            address,
            latitude,
            longitude,
            halal_status,
            description,
            verification_source,
            verification_url,
            verified_at,
            is_active
          )
          ''',
    )
        .eq(
      'food_id',
      foodId,
    )
        .eq(
      'food_locations.is_active',
      true,
    );

    final places = (rows as List)
        .map(
          (row) =>
          TraditionalFoodPlace.fromJoinRow(
            (row as Map)
                .cast<String, dynamic>(),
          ),
    )
        .toList();

    places.sort(
          (a, b) => a.name
          .toLowerCase()
          .compareTo(
        b.name.toLowerCase(),
      ),
    );

    return places;
  }
}