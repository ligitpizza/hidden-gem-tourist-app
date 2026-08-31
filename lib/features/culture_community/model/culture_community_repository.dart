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
  // AUTHENTICATION
  // =========================================================

  bool get isSignedIn =>
      _client.auth.currentUser != null;

  String _requireUserId() {
    final user =
        _client.auth.currentUser;

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

  Future<List<CulturalEvent>>
  fetchCulturalEvents() async {
    final rows = await _client
        .from('cultural_events')
        .select()
        .eq(
      'is_active',
      true,
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
    final userId =
    _requireUserId();

    final result = await _client
        .from(
      'cultural_event_favourites',
    )
        .select(
      'event_id',
    )
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
    final userId =
    _requireUserId();

    await _client
        .from(
      'cultural_event_favourites',
    )
        .upsert(
      {
        'user_id': userId,
        'event_id': eventId,
      },
      onConflict:
      'user_id,event_id',
    );
  }

  Future<void>
  removeCulturalEventFavourite(
      String eventId,
      ) async {
    final userId =
    _requireUserId();

    await _client
        .from(
      'cultural_event_favourites',
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
  // CULTURAL EVENT ITINERARY
  // =========================================================

  Future<bool>
  isCulturalEventInItinerary(
      String eventId,
      ) async {
    final userId =
    _requireUserId();

    final result = await _client
        .from(
      'cultural_event_itinerary_items',
    )
        .select(
      'event_id',
    )
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

  Future<void>
  addCulturalEventToItinerary({
    required String eventId,
    required DateTime plannedAt,
  }) async {
    final userId =
    _requireUserId();

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
      onConflict:
      'user_id,event_id',
    );
  }

  Future<void>
  removeCulturalEventFromItinerary(
      String eventId,
      ) async {
    final userId =
    _requireUserId();

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

  Future<bool>
  isTraditionalFoodFavourite(
      String foodId,
      ) async {
    final userId =
    _requireUserId();

    final result = await _client
        .from(
      'traditional_food_favourites',
    )
        .select(
      'food_id',
    )
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

  Future<void>
  addTraditionalFoodFavourite(
      String foodId,
      ) async {
    final userId =
    _requireUserId();

    await _client
        .from(
      'traditional_food_favourites',
    )
        .upsert(
      {
        'user_id': userId,
        'food_id': foodId,
      },
      onConflict:
      'user_id,food_id',
    );
  }

  Future<void>
  removeTraditionalFoodFavourite(
      String foodId,
      ) async {
    final userId =
    _requireUserId();

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
  // TRADITIONAL FOOD LOCATIONS
  // =========================================================

  Future<List<TraditionalFoodPlace>>
  fetchTraditionalFoodPlaces(
      String foodId,
      ) async {
    // ---------------------------------------------------------
    // STEP 1:
    // Get links from traditional_food_places.
    // ---------------------------------------------------------

    final linkRows = await _client
        .from(
      'traditional_food_places',
    )
        .select(
      'place_id, halal_status',
    )
        .eq(
      'food_id',
      foodId,
    );

    final links = (linkRows as List)
        .map(
          (row) => (row as Map)
          .cast<String, dynamic>(),
    )
        .toList();

    // No restaurant linked to this food.
    if (links.isEmpty) {
      return const [];
    }

    // ---------------------------------------------------------
    // STEP 2:
    // Get place IDs.
    // ---------------------------------------------------------

    final placeIds = links
        .map(
          (row) =>
      row['place_id'] as String,
    )
        .toList();

    // ---------------------------------------------------------
    // STEP 3:
    // Fetch actual records from team's existing places table.
    //
    // IMPORTANT:
    // Your real columns are latitude + longitude.
    // ---------------------------------------------------------

    final placeRows = await _client
        .from(
      'places',
    )
        .select(
      '''
          id,
          name,
          category,
          state,
          city,
          latitude,
          longitude,
          description
          ''',
    )
        .inFilter(
      'id',
      placeIds,
    );

    final places = (placeRows as List)
        .map(
          (row) => (row as Map)
          .cast<String, dynamic>(),
    )
        .toList();

    // ---------------------------------------------------------
    // STEP 4:
    // Merge traditional_food_places with places.
    // ---------------------------------------------------------

    final result =
    <TraditionalFoodPlace>[];

    for (final link in links) {
      final placeId =
      link['place_id'] as String;

      Map<String, dynamic>?
      matchingPlace;

      for (final place in places) {
        if (place['id'] ==
            placeId) {
          matchingPlace =
              place;

          break;
        }
      }

      if (matchingPlace == null) {
        continue;
      }

      // We cannot place a marker if coordinates are missing.
      if (matchingPlace['latitude'] ==
          null ||
          matchingPlace['longitude'] ==
              null) {
        continue;
      }

      result.add(
        TraditionalFoodPlace.fromMaps(
          linkRow: link,
          placeRow:
          matchingPlace,
        ),
      );
    }

    return result;
  }
}