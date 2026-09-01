import 'package:supabase_flutter/supabase_flutter.dart';

import 'cultural_event.dart';
import 'traditional_food.dart';
import 'traditional_food_place.dart';

class CultureCommunityRepository {
  CultureCommunityRepository({
    SupabaseClient? client,
  }) : _client =
      client ??
          Supabase.instance.client;

  final SupabaseClient _client;

  // =========================================================
  // AUTH
  // =========================================================

  bool get isSignedIn =>
      _client.auth.currentUser != null;

  String _requireUserId() {
    final user =
        _client.auth.currentUser;

    if (user == null) {
      throw StateError(
        'Please sign in first.',
      );
    }

    return user.id;
  }

  // =========================================================
  // CULTURAL EVENTS
  //
  // Expired events are automatically hidden.
  // =========================================================

  Future<List<CulturalEvent>>
  fetchCulturalEvents() async {
    final now =
    DateTime.now()
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
          (row) =>
          CulturalEvent.fromMap(
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
        .order(
      'name',
      ascending: true,
    );

    return (rows as List)
        .map(
          (row) =>
          TraditionalFood.fromMap(
            (row as Map)
                .cast<String, dynamic>(),
          ),
    )
        .toList();
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
          TraditionalFoodPlace
              .fromJoinRow(
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

  // =========================================================
  // EVENT - CHECK SAVED
  // =========================================================

  Future<bool>
  isCulturalEventFavourite(
      String eventId,
      ) async {
    final userId =
    _requireUserId();

    final row = await _client
        .from(
      'cultural_event_favourites',
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

    return row != null;
  }

  // =========================================================
  // EVENT - SAVE
  // =========================================================

  Future<void>
  addCulturalEventFavourite(
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

  // =========================================================
  // EVENT - REMOVE
  // =========================================================

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
  // FOOD - CHECK SAVED
  // =========================================================

  Future<bool>
  isTraditionalFoodFavourite(
      String foodId,
      ) async {
    final userId =
    _requireUserId();

    final row = await _client
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

    return row != null;
  }

  // =========================================================
  // FOOD - SAVE
  // =========================================================

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

  // =========================================================
  // FOOD - REMOVE
  // =========================================================

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
  // RESTAURANT - CHECK SAVED
  // =========================================================

  Future<bool>
  isFoodLocationFavourite(
      String locationId,
      ) async {
    final userId =
    _requireUserId();

    final row = await _client
        .from(
      'food_location_favourites',
    )
        .select('location_id')
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'location_id',
      locationId,
    )
        .maybeSingle();

    return row != null;
  }

  // =========================================================
  // RESTAURANT - SAVE
  // =========================================================

  Future<void>
  addFoodLocationFavourite(
      String locationId,
      ) async {
    final userId =
    _requireUserId();

    await _client
        .from(
      'food_location_favourites',
    )
        .upsert(
      {
        'user_id': userId,
        'location_id': locationId,
      },
      onConflict:
      'user_id,location_id',
    );
  }

  // =========================================================
  // RESTAURANT - REMOVE
  // =========================================================

  Future<void>
  removeFoodLocationFavourite(
      String locationId,
      ) async {
    final userId =
    _requireUserId();

    await _client
        .from(
      'food_location_favourites',
    )
        .delete()
        .eq(
      'user_id',
      userId,
    )
        .eq(
      'location_id',
      locationId,
    );
  }

  // =========================================================
  // ALL SAVED RESTAURANT IDS
  //
  // Used by Food Detail and Nearby screen.
  // =========================================================

  Future<Set<String>>
  fetchFavouriteFoodLocationIds() async {
    final userId =
    _requireUserId();

    final rows = await _client
        .from(
      'food_location_favourites',
    )
        .select('location_id')
        .eq(
      'user_id',
      userId,
    );

    return (rows as List)
        .map(
          (row) =>
      (row as Map)[
      'location_id']
      as String,
    )
        .toSet();
  }

  // =========================================================
  // SAVED EVENTS
  // =========================================================

  Future<List<CulturalEvent>>
  fetchFavouriteCulturalEvents() async {
    final userId =
    _requireUserId();

    final favouriteRows =
    await _client
        .from(
      'cultural_event_favourites',
    )
        .select(
      'event_id, saved_at',
    )
        .eq(
      'user_id',
      userId,
    )
        .order(
      'saved_at',
      ascending: false,
    );

    final favourites =
    (favouriteRows as List)
        .map(
          (row) => (row as Map)
          .cast<
          String,
          dynamic>(),
    )
        .toList();

    if (favourites.isEmpty) {
      return [];
    }

    final eventIds =
    favourites
        .map(
          (row) =>
      row['event_id']
      as String,
    )
        .toList();

    final now =
    DateTime.now()
        .toUtc()
        .toIso8601String();

    final eventRows =
    await _client
        .from(
      'cultural_events',
    )
        .select()
        .inFilter(
      'id',
      eventIds,
    )
        .eq(
      'is_active',
      true,
    )
        .gte(
      'end_at',
      now,
    );

    final eventMap =
    <String, CulturalEvent>{};

    for (final raw
    in eventRows as List) {
      final row = (raw as Map)
          .cast<String, dynamic>();

      final event =
      CulturalEvent.fromMap(
        row,
      );

      eventMap[event.id] = event;
    }

    final result =
    <CulturalEvent>[];

    for (final favourite
    in favourites) {
      final event =
      eventMap[
      favourite['event_id']
      as String];

      if (event != null) {
        result.add(event);
      }
    }

    return result;
  }

  // =========================================================
  // SAVED FOODS
  // =========================================================

  Future<List<TraditionalFood>>
  fetchFavouriteTraditionalFoods() async {
    final userId =
    _requireUserId();

    final favouriteRows =
    await _client
        .from(
      'traditional_food_favourites',
    )
        .select(
      'food_id, saved_at',
    )
        .eq(
      'user_id',
      userId,
    )
        .order(
      'saved_at',
      ascending: false,
    );

    final favourites =
    (favouriteRows as List)
        .map(
          (row) => (row as Map)
          .cast<
          String,
          dynamic>(),
    )
        .toList();

    if (favourites.isEmpty) {
      return [];
    }

    final foodIds =
    favourites
        .map(
          (row) =>
      row['food_id']
      as String,
    )
        .toList();

    final foodRows =
    await _client
        .from(
      'traditional_foods',
    )
        .select()
        .inFilter(
      'id',
      foodIds,
    );

    final foodMap =
    <String, TraditionalFood>{};

    for (final raw
    in foodRows as List) {
      final row = (raw as Map)
          .cast<String, dynamic>();

      final food =
      TraditionalFood.fromMap(
        row,
      );

      foodMap[food.id] = food;
    }

    final result =
    <TraditionalFood>[];

    for (final favourite
    in favourites) {
      final food =
      foodMap[
      favourite['food_id']
      as String];

      if (food != null) {
        result.add(food);
      }
    }

    return result;
  }

  // =========================================================
  // SAVED RESTAURANTS
  // =========================================================

  Future<List<TraditionalFoodPlace>>
  fetchFavouriteFoodLocations() async {
    final userId =
    _requireUserId();

    final favouriteRows =
    await _client
        .from(
      'food_location_favourites',
    )
        .select(
      'location_id, saved_at',
    )
        .eq(
      'user_id',
      userId,
    )
        .order(
      'saved_at',
      ascending: false,
    );

    final favourites =
    (favouriteRows as List)
        .map(
          (row) => (row as Map)
          .cast<
          String,
          dynamic>(),
    )
        .toList();

    if (favourites.isEmpty) {
      return [];
    }

    final locationIds =
    favourites
        .map(
          (row) =>
      row['location_id']
      as String,
    )
        .toList();

    final locationRows =
    await _client
        .from(
      'food_locations',
    )
        .select()
        .inFilter(
      'id',
      locationIds,
    )
        .eq(
      'is_active',
      true,
    );

    final locationMap =
    <String,
        TraditionalFoodPlace>{};

    for (final raw
    in locationRows as List) {
      final row = (raw as Map)
          .cast<String, dynamic>();

      final place =
      TraditionalFoodPlace
          .fromLocationRow(
        row,
      );

      locationMap[place.id] =
          place;
    }

    final result =
    <TraditionalFoodPlace>[];

    for (final favourite
    in favourites) {
      final place =
      locationMap[
      favourite[
      'location_id']
      as String];

      if (place != null) {
        result.add(place);
      }
    }

    return result;
  }
}