import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../../shared/models/travel_mode.dart';
import '../../../shared/services/hidden_gem_scoring.dart';
import '../../../shared/services/place_cost_estimator.dart';
import 'itinerary_plan.dart';
import 'itinerary_stop.dart';
import 'nominatim_geocoding_service.dart';
import 'osrm_routing_service.dart';
import 'route_metrics.dart';
import 'route_path.dart';
import 'transitous_routing_service.dart';
import 'visit_duration_option.dart';

/// Route + timeline generation for Smart Itinerary Planning.
///
/// Distances/times come from real OSRM routing (driving + walking) when
/// reachable, falling back to straight-line estimates if the routing
/// service is unavailable (offline, rate-limited, etc.) so the itinerary
/// still generates. Hidden gems are found along each leg's actual road
/// corridor (not just near the endpoints) and threaded into the route as
/// real waypoints. The composite "hidden gem" score (rating + category +
/// uniqueness + accessibility + popularity) is a placeholder definition —
/// kept as plain weighted parameters here, not baked into the database, so
/// it's a one-line swap once the team finalises the real algorithm.
class ItineraryRepository {
  ItineraryRepository({
    OsrmRoutingService? routingService,
    TransitousRoutingService? transitRoutingService,
    NominatimGeocodingService? geocodingService,
  })  : _routingService = routingService ?? OsrmRoutingService(),
        _transitService = transitRoutingService ?? TransitousRoutingService(),
        _geocodingService = geocodingService ?? NominatimGeocodingService();

  final OsrmRoutingService _routingService;
  final TransitousRoutingService _transitService;
  final NominatimGeocodingService _geocodingService;

  static const _distance = Distance();

  // How far (km) from a leg's road corridor a place can be and still count
  // as "along the route", and how many gems a single leg may detour through.
  static const double _corridorKm = 2.0;
  static const int _maxGemsPerLeg = 3;

  static final List<Destination> _destinationCatalogue = [
    const Destination(
      id: 'kl_city_centre',
      name: 'Kuala Lumpur',
      city: 'Kuala Lumpur',
      category: DestinationCategory.attraction,
      location: LatLng(3.1390, 101.6869),
    ),
    const Destination(
      id: 'batu_caves',
      name: 'Batu Caves',
      city: 'Selangor',
      category: DestinationCategory.heritageSite,
      location: LatLng(3.2379, 101.6840),
    ),
    const Destination(
      id: 'petaling_street',
      name: 'Petaling Street',
      city: 'Kuala Lumpur',
      category: DestinationCategory.attraction,
      location: LatLng(3.1430, 101.6970),
    ),
    const Destination(
      id: 'central_market',
      name: 'Central Market',
      city: 'Kuala Lumpur',
      category: DestinationCategory.heritageSite,
      location: LatLng(3.1439, 101.6955),
    ),
    const Destination(
      id: 'vcr_cafe',
      name: 'VCR Cafe, Bukit Bintang',
      city: 'Kuala Lumpur',
      category: DestinationCategory.cafe,
      location: LatLng(3.1466, 101.7107),
    ),
    const Destination(
      id: 'kl_forest_eco_park',
      name: 'KL Forest Eco Park',
      city: 'Kuala Lumpur',
      category: DestinationCategory.park,
      location: LatLng(3.1486, 101.7051),
    ),
    const Destination(
      id: 'islamic_arts_museum',
      name: 'Islamic Arts Museum Malaysia',
      city: 'Kuala Lumpur',
      category: DestinationCategory.museum,
      location: LatLng(3.1421, 101.6885),
    ),
    const Destination(
      id: 'thean_hou_temple',
      name: 'Thean Hou Temple',
      city: 'Kuala Lumpur',
      category: DestinationCategory.heritageSite,
      location: LatLng(3.1226, 101.6836),
    ),
  ];

  static final List<HiddenGem> _gemCatalogue = [
    const HiddenGem(
      id: 'dark_cave',
      name: 'Dark Cave Exploration',
      description:
          'A specialized guided walk through a conservation cave system home to rare endemic fauna.',
      location: LatLng(3.2390, 101.6832),
      category: HiddenGemCategory.culture,
    ),
    const HiddenGem(
      id: 'hawker_center',
      name: 'Local Hawker Center',
      description:
          'Expert-curated stop for authentic Nasi Lemak and local coffee away from the tourist crowds.',
      location: LatLng(3.2100, 101.6800),
      category: HiddenGemCategory.food,
    ),
    const HiddenGem(
      id: 'mural_alley',
      name: 'Kwai Chai Hong Mural Alley',
      description: 'A restored heritage lane covered in murals depicting old Kuala Lumpur life.',
      location: LatLng(3.1443, 101.6978),
      category: HiddenGemCategory.culture,
    ),
    const HiddenGem(
      id: 'rooftop_viewpoint',
      name: 'Perdana Rooftop Viewpoint',
      description: 'A quiet rooftop with an unobstructed view of the KL skyline at golden hour.',
      location: LatLng(3.1440, 101.6890),
      category: HiddenGemCategory.viewpoint,
    ),
    const HiddenGem(
      id: 'kopitiam_corner',
      name: 'Old Town Kopitiam Corner',
      description: 'A decades-old coffee shop still roasting beans the traditional way.',
      location: LatLng(3.1447, 101.6949),
      category: HiddenGemCategory.food,
    ),
    const HiddenGem(
      id: 'batik_workshop',
      name: 'Traditional Batik Workshop',
      description: 'A small family-run studio offering hands-on batik painting sessions.',
      location: LatLng(3.1415, 101.6900),
      category: HiddenGemCategory.craft,
    ),
    const HiddenGem(
      id: 'jungle_trail',
      name: 'Bukit Nanas Jungle Trail',
      description: 'A short rainforest boardwalk trail tucked right in the middle of the city.',
      location: LatLng(3.1495, 101.7040),
      category: HiddenGemCategory.nature,
    ),
  ];

  /// Searches real places (name/state/city) in Supabase, best-rated first —
  /// a broad query like a state or city name can match thousands of rows,
  /// and plain alphabetical order buries well-known spots under
  /// symbol/number-prefixed names.
  ///
  /// If nothing is recorded in the database, the traveller isn't limited to
  /// the curated dataset — the search falls through to free-text geocoding
  /// (Nominatim) so they can plan a route to *any* real place. Hidden gems
  /// are still sourced from the curated database separately, along
  /// whichever route that produces.
  Future<List<Destination>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return _destinationCatalogue.take(6).toList();
    }

    final dbResults = await _searchDatabase(trimmed);
    if (dbResults.isNotEmpty) return dbResults;

    final geocoded = await _geocodingService.search(trimmed);
    if (geocoded.isNotEmpty) return geocoded;

    // Nothing recorded and geocoding found nothing (or is unreachable) —
    // fall back to the small local catalogue so the search bar still
    // returns something.
    final lower = trimmed.toLowerCase();
    return _destinationCatalogue
        .where((d) =>
            d.name.toLowerCase().contains(lower) ||
            d.city.toLowerCase().contains(lower) ||
            d.category.label.toLowerCase().contains(lower))
        .toList();
  }

  Future<List<Destination>> _searchDatabase(String trimmed) async {
    try {
      // Strip characters that are structurally significant in PostgREST's
      // `.or()` filter syntax so a search term can't break out of it.
      final safe = trimmed.replaceAll(RegExp(r'[,()]'), ' ').trim();
      final rows = await Supabase.instance.client
          .from('place_hidden_gem_candidates')
          .select()
          .or('name.ilike.%$safe%,state.ilike.%$safe%,city.ilike.%$safe%')
          .order('avg_rating', ascending: false)
          .limit(40);

      return rows.map((row) => _destinationFromRow(row)).toList();
    } catch (_) {
      return const [];
    }
  }

  Destination _destinationFromRow(Map<String, dynamic> row) {
    return Destination(
      id: row['id'] as String,
      name: row['name'] as String,
      city: (row['city'] as String?) ?? (row['state'] as String?) ?? '',
      category: destinationCategoryFromDb(row['category'] as String),
      location: LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ),
    );
  }

  /// Preview count for the "Plan Your Route" page, before a path exists yet
  /// — finds real hidden gems within [radiusKm] of any selected destination,
  /// applying the same composite score + optional category filter used by
  /// route generation.
  Future<List<HiddenGem>> gemsNearDestinations(
    List<Destination> destinations, {
    double radiusKm = 3,
    Set<HiddenGemCategory> categories = const {},
  }) async {
    if (destinations.isEmpty) return const [];

    try {
      final lats = destinations.map((d) => d.location.latitude);
      final lngs = destinations.map((d) => d.location.longitude);
      final bufferDeg = radiusKm / 111.0;
      final candidates = await _scoredPlacesInBounds(
        minLat: lats.reduce(min) - bufferDeg,
        maxLat: lats.reduce(max) + bufferDeg,
        minLng: lngs.reduce(min) - bufferDeg,
        maxLng: lngs.reduce(max) + bufferDeg,
        categories: categories,
      );

      return candidates
          .where((c) => destinations.any(
                (d) => _distance.as(LengthUnit.Kilometer, d.location, c.gem.location) <= radiusKm,
              ))
          .map((c) => c.gem)
          .toList();
    } catch (_) {
      // Supabase unreachable — fall back to the small local catalogue so
      // route generation still works offline.
      return _gemCatalogue
          .where((gem) => destinations.any(
                (d) => _distance.as(LengthUnit.Kilometer, d.location, gem.location) <= radiusKm,
              ))
          .toList();
    }
  }

  /// Fetches places inside a bounding box, joins in their real review
  /// metrics, and scores each against the composite hidden-gem formula.
  /// Returns only places that clear [HiddenGemScoring.qualifyingThreshold]
  /// and (when non-empty) [categories].
  Future<List<_ScoredGem>> _scoredPlacesInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required Set<HiddenGemCategory> categories,
    Set<String> excludeIds = const {},
  }) async {
    // A single view join (place + its real review metrics) instead of a
    // bbox query followed by a huge `id in (...)` join — a busy corridor can
    // contain 1000+ candidate places, which blows PostgREST's URL length
    // limit if the ids are round-tripped through a second request.
    final placeRows = await Supabase.instance.client
        .from('place_hidden_gem_candidates')
        .select()
        .gte('latitude', minLat)
        .lte('latitude', maxLat)
        .gte('longitude', minLng)
        .lte('longitude', maxLng);

    if (placeRows.isEmpty) return const [];

    final scored = <_ScoredGem>[];
    for (final place in placeRows) {
      final id = place['id'] as String;
      if (excludeIds.contains(id)) continue;

      final category = HiddenGemScoring.categoryFromDb(place['category'] as String);
      if (categories.isNotEmpty && !categories.contains(category)) continue;

      final avgRating = (place['avg_rating'] as num?)?.toDouble() ?? 0.0;
      final uniqueness = (place['uniqueness_score'] as num?)?.toDouble() ?? 0.0;
      final accessibility = (place['accessibility_score'] as num?)?.toDouble() ?? 0.0;
      final popularity = gemPopularityFromDb(place['popularity'] as String?);

      final score = HiddenGemScoring.score(
        avgRating: avgRating,
        uniqueness: uniqueness,
        accessibility: accessibility,
        popularity: popularity,
      );
      if (score < HiddenGemScoring.qualifyingThreshold) continue;

      final location = LatLng(
        (place['latitude'] as num).toDouble(),
        (place['longitude'] as num).toDouble(),
      );
      final description = place['description'] as String?;

      scored.add(_ScoredGem(
        gem: HiddenGem(
          id: id,
          name: place['name'] as String,
          description: (description != null && description.trim().isNotEmpty)
              ? description
              : 'Rated ${avgRating.toStringAsFixed(1)}★ with ${popularity.label.toLowerCase()} '
                  'popularity — a strong hidden-gem match for this route.',
          location: location,
          category: category,
          avgRating: avgRating,
          uniquenessScore: uniqueness,
          accessibilityScore: accessibility,
          popularity: popularity,
        ),
        score: score,
      ));
    }
    return scored;
  }

  /// Finds qualifying hidden gems within [_corridorKm] of [corridor] (a
  /// leg's actual road/footpath polyline, not just its two endpoints),
  /// ordered by position along the corridor so inserting them as waypoints
  /// produces a sensible start-to-end visiting order.
  Future<List<HiddenGem>> _findGemsAlongCorridor(
    List<LatLng> corridor, {
    required Set<HiddenGemCategory> categories,
    Set<String> excludeIds = const {},
  }) async {
    if (corridor.isEmpty) return const [];

    try {
      final lats = corridor.map((p) => p.latitude);
      final lngs = corridor.map((p) => p.longitude);
      final bufferDeg = _corridorKm / 111.0;
      final scored = await _scoredPlacesInBounds(
        minLat: lats.reduce(min) - bufferDeg,
        maxLat: lats.reduce(max) + bufferDeg,
        minLng: lngs.reduce(min) - bufferDeg,
        maxLng: lngs.reduce(max) + bufferDeg,
        categories: categories,
        excludeIds: excludeIds,
      );
      if (scored.isEmpty) return const [];

      final withProjection = <(_ScoredGem, ({double distanceKm, int vertexIndex}))>[];
      for (final candidate in scored) {
        final projection = _nearestVertex(candidate.gem.location, corridor);
        if (projection.distanceKm <= _corridorKm) {
          withProjection.add((candidate, projection));
        }
      }
      if (withProjection.isEmpty) return const [];

      withProjection.sort((a, b) => b.$1.score.compareTo(a.$1.score));
      final picked = withProjection.take(_maxGemsPerLeg).toList()
        ..sort((a, b) => a.$2.vertexIndex.compareTo(b.$2.vertexIndex));
      return picked.map((p) => p.$1.gem).toList();
    } catch (_) {
      return const [];
    }
  }

  /// `null` = no cap (the traveller filtered to *only* Food gems, i.e. they
  /// explicitly want more food stops). Otherwise at most 2 auto-recommended
  /// food gems across the whole trip — logically nobody wants a restaurant
  /// on every leg.
  int? _foodGemCapFor(Set<HiddenGemCategory> categories) {
    if (categories.length == 1 && categories.single == HiddenGemCategory.food) return null;
    return 2;
  }

  List<HiddenGem> _capFoodGems(List<HiddenGem> gems, {required int? cap, required int alreadyPicked}) {
    if (cap == null) return gems;
    var count = alreadyPicked;
    final kept = <HiddenGem>[];
    for (final gem in gems) {
      if (gem.category == HiddenGemCategory.food) {
        if (count >= cap) continue;
        count++;
      }
      kept.add(gem);
    }
    return kept;
  }

  ({double distanceKm, int vertexIndex}) _nearestVertex(LatLng point, List<LatLng> corridor) {
    var best = double.infinity;
    var bestIndex = 0;
    for (var i = 0; i < corridor.length; i++) {
      final d = _distance.as(LengthUnit.Kilometer, point, corridor[i]);
      if (d < best) {
        best = d;
        bestIndex = i;
      }
    }
    return (distanceKm: best, vertexIndex: bestIndex);
  }

  Future<ItineraryPlan> generate({
    required List<Destination> destinations,
    required VisitDurationOption? durationOption,
    int? customDays,
    Set<HiddenGemCategory> gemCategories = const {},
  }) async {
    assert(destinations.length >= 2, 'Need at least 2 destinations to generate a route.');

    final hopsA = <_Hop>[];
    final hopsB = <_Hop>[];

    // Travellers don't want a restaurant-per-leg — cap how many
    // system-*recommended* food gems can be threaded into each path across
    // the whole trip (the traveller's own chosen destinations are never
    // capped, only the auto-inserted hidden gems). Skipped entirely when
    // "Food" is the traveller's sole selected gem category, signalling they
    // specifically want more food stops.
    final foodGemCap = _foodGemCapFor(gemCategories);
    var foodCountA = 0;
    var foodCountB = 0;

    for (var i = 0; i < destinations.length - 1; i++) {
      final start = destinations[i].location;
      final end = destinations[i + 1].location;

      var corridorA = <LatLng>[start, end];
      var corridorB = _buildAlternatePolyline([start, end]);
      try {
        final legRoutes = await _routingService.drivingRoute([start, end], alternatives: true);
        corridorA = legRoutes.first.polyline;
        if (legRoutes.length > 1) corridorB = legRoutes[1].polyline;
      } on OsrmException {
        // Corridor search still works on the straight-line fallback path.
      }

      var gemsA = await _findGemsAlongCorridor(corridorA, categories: gemCategories);
      var gemsB = await _findGemsAlongCorridor(
        corridorB,
        categories: gemCategories,
        excludeIds: gemsA.map((g) => g.id).toSet(),
      );

      gemsA = _capFoodGems(gemsA, cap: foodGemCap, alreadyPicked: foodCountA);
      foodCountA += gemsA.where((g) => g.category == HiddenGemCategory.food).length;
      gemsB = _capFoodGems(gemsB, cap: foodGemCap, alreadyPicked: foodCountB);
      foodCountB += gemsB.where((g) => g.category == HiddenGemCategory.food).length;

      hopsA.add(await _buildHop(start, end, gemsA));
      hopsB.add(await _buildHop(start, end, gemsB));
    }

    // Public transport can't detour through hidden gems the way driving/
    // walking can — a bus follows a fixed route — so it's computed once
    // from the traveller's original stops and shared by both paths.
    final publicMetrics = await _realPublicMetrics(destinations);

    // Category-based entrance/meal cost estimate — mode-independent (a
    // museum ticket costs the same whether you drove or walked there), so
    // it's computed once from the destinations and added on top of each
    // path's own travel cost below. Gem costs differ per path since A/B
    // thread through different gems.
    final destinationsCostMyr = destinations.fold(
      0.0,
      (sum, d) => sum + PlaceCostEstimator.forDestinationCategory(d.category),
    );

    final primaryPath = _assemblePath(
      id: 'A',
      label: 'Path A',
      isRecommended: true,
      hops: hopsA,
      publicOverride: publicMetrics,
      destinationsCostMyr: destinationsCostMyr,
    );
    final alternatePath = _assemblePath(
      id: 'B',
      label: 'Path B',
      isRecommended: false,
      hops: hopsB,
      publicOverride: publicMetrics,
      destinationsCostMyr: destinationsCostMyr,
    );

    final timelineResult = _buildTimeline(destinations: destinations, hops: hopsA);

    return ItineraryPlan(
      destinations: destinations,
      durationOption: durationOption,
      primaryPath: primaryPath,
      alternatePath: alternatePath,
      timeline: timelineResult.stops,
      estimatedMinutesNeeded: timelineResult.totalMinutes,
      budgetMinutes: durationOption?.totalMinutes(customDays: customDays),
    );
  }

  /// Chains real OSRM legs through `[start, ...gems, end]` so hidden gems
  /// become genuine waypoints on the routed path, not just markers dropped
  /// near it. Falls back to a straight-line segment (with a speed-based time
  /// estimate) for any leg OSRM can't route, so one bad segment doesn't fail
  /// the whole hop.
  Future<_Hop> _buildHop(LatLng start, LatLng end, List<HiddenGem> gems) async {
    final waypoints = [start, ...gems.map((g) => g.location), end];
    final polyline = <LatLng>[];
    final driveSegmentMinutes = <int>[];
    final walkSegmentMinutes = <int>[];
    var drivingKm = 0.0;
    var drivingMin = 0;
    var walkingKm = 0.0;
    var walkingMin = 0;

    for (var i = 0; i < waypoints.length - 1; i++) {
      final from = waypoints[i];
      final to = waypoints[i + 1];
      try {
        final driveLeg = (await _routingService.drivingRoute([from, to])).first;
        polyline.addAll(polyline.isEmpty ? driveLeg.polyline : driveLeg.polyline.skip(1));
        drivingKm += driveLeg.distanceKm;
        drivingMin += driveLeg.durationMinutes;
        driveSegmentMinutes.add(driveLeg.durationMinutes);

        final walkLeg = await _routingService.walkingRoute([from, to]);
        walkingKm += walkLeg.distanceKm;
        walkingMin += walkLeg.durationMinutes;
        walkSegmentMinutes.add(walkLeg.durationMinutes);
      } on OsrmException {
        final segmentKm = _distance.as(LengthUnit.Kilometer, from, to);
        final segmentDriveMin = (segmentKm / 40 * 60).round().clamp(5, 240);
        final segmentWalkMin = (segmentKm / 5 * 60).round().clamp(2, 600);

        polyline.addAll(polyline.isEmpty ? [from, to] : [to]);
        drivingKm += segmentKm;
        drivingMin += segmentDriveMin;
        driveSegmentMinutes.add(segmentDriveMin);
        walkingKm += segmentKm;
        walkingMin += segmentWalkMin;
        walkSegmentMinutes.add(segmentWalkMin);
      }
    }

    return _Hop(
      gems: gems,
      polyline: polyline,
      drivingDistanceKm: drivingKm,
      drivingMinutes: drivingMin,
      walkingDistanceKm: walkingKm,
      walkingMinutes: walkingMin,
      driveSegmentMinutes: driveSegmentMinutes,
      walkSegmentMinutes: walkSegmentMinutes,
    );
  }

  /// Real point-to-point public transit estimate (Rapid Penang bus, via
  /// Transitous — free/keyless, no self-hosting) across the traveller's
  /// original stops. Returns null if any leg has no transit connection, so
  /// callers can fall back to the distance-based heuristic instead of
  /// mixing real and guessed numbers in one estimate.
  Future<RouteMetrics?> _realPublicMetrics(List<Destination> destinations) async {
    var totalKm = 0.0;
    var totalMinutes = 0;

    for (var i = 0; i < destinations.length - 1; i++) {
      final route = await _transitService.plan(
        destinations[i].location,
        destinations[i + 1].location,
      );
      if (route == null) return null;
      totalKm += route.distanceKm;
      totalMinutes += route.durationMinutes;
    }

    return RouteMetrics(
      distanceKm: totalKm,
      durationMinutes: totalMinutes,
      costMyr: 2 + totalKm * 0.15,
    );
  }

  /// Concatenates hop polylines into one path (dropping duplicate junction
  /// points) and sums their distance/duration into driving + walking
  /// metrics. "Public" transport uses [publicOverride] (a real Transitous
  /// itinerary) when available, falling back to a driving-distance-based
  /// heuristic when there's no transit coverage for this route.
  ///
  /// [destinationsCostMyr] (entrance fees/meals, mode-independent) is added
  /// on top of each mode's travel cost, along with this path's own gems'
  /// estimated cost — the "Estimated Cost" a traveller sees is travel +
  /// activity cost combined, not just fuel/fare.
  RoutePath _assemblePath({
    required String id,
    required String label,
    required bool isRecommended,
    required List<_Hop> hops,
    RouteMetrics? publicOverride,
    required double destinationsCostMyr,
  }) {
    final polyline = <LatLng>[];
    for (final hop in hops) {
      polyline.addAll(polyline.isEmpty ? hop.polyline : hop.polyline.skip(1));
    }

    final drivingDistanceKm = hops.fold(0.0, (sum, h) => sum + h.drivingDistanceKm);
    final drivingMinutes = hops.fold(0, (sum, h) => sum + h.drivingMinutes);
    final walkingDistanceKm = hops.fold(0.0, (sum, h) => sum + h.walkingDistanceKm);
    final walkingMinutes = hops.fold(0, (sum, h) => sum + h.walkingMinutes);

    final gems = hops.expand((h) => h.gems).toList();
    final gemsCostMyr = gems.fold(
      0.0,
      (sum, g) => sum + PlaceCostEstimator.forGemCategory(g.category),
    );
    final activityCostMyr = destinationsCostMyr + gemsCostMyr;
    final publicBase = publicOverride ??
        RouteMetrics(
          distanceKm: drivingDistanceKm,
          durationMinutes: (drivingDistanceKm / 22 * 60).round() + 12,
          costMyr: 2 + drivingDistanceKm * 0.15,
        );

    return RoutePath(
      id: id,
      label: label,
      isRecommended: isRecommended,
      polyline: polyline,
      hiddenGems: gems,
      metricsByMode: {
        TravelMode.driving: RouteMetrics(
          distanceKm: drivingDistanceKm,
          durationMinutes: drivingMinutes,
          costMyr: 3 + drivingDistanceKm * 0.6 + activityCostMyr,
        ),
        TravelMode.walking: RouteMetrics(
          distanceKm: walkingDistanceKm,
          durationMinutes: walkingMinutes,
          costMyr: activityCostMyr,
        ),
        TravelMode.public: RouteMetrics(
          distanceKm: publicBase.distanceKm,
          durationMinutes: publicBase.durationMinutes,
          costMyr: publicBase.costMyr + activityCostMyr,
        ),
      },
    );
  }

  List<LatLng> _buildAlternatePolyline(List<LatLng> primary) {
    if (primary.length < 2) return primary;
    final result = <LatLng>[primary.first];
    for (var i = 0; i < primary.length - 1; i++) {
      result.add(_bowedMidpoint(primary[i], primary[i + 1], bendPositive: i.isEven));
      result.add(primary[i + 1]);
    }
    return result;
  }

  /// Offsets the midpoint of a segment perpendicular to its direction so the
  /// alternate path visibly bows away from the primary one on the map.
  LatLng _bowedMidpoint(LatLng a, LatLng b, {required bool bendPositive}) {
    final midLat = (a.latitude + b.latitude) / 2;
    final midLng = (a.longitude + b.longitude) / 2;
    final dLat = b.latitude - a.latitude;
    final dLng = b.longitude - a.longitude;
    final sign = bendPositive ? 1 : -1;
    return LatLng(midLat - dLng * 0.4 * sign, midLng + dLat * 0.4 * sign);
  }

  // Category-based visit duration and "opening hours" placeholders — real
  // per-place hours/durations aren't available (no paid Google Places data,
  // same constraint noted throughout this module), so these are reasonable,
  // clearly-invented stand-ins used only to keep the generated schedule
  // realistic (a museum won't get scheduled at 8pm; a viewpoint won't eat a
  // 90-minute block).
  static const Map<DestinationCategory, int> _destinationVisitMinutes = {
    DestinationCategory.attraction: 90,
    DestinationCategory.heritageSite: 75,
    DestinationCategory.museum: 90,
    DestinationCategory.viewpoint: 30,
    DestinationCategory.park: 75,
    DestinationCategory.beach: 120,
    DestinationCategory.waterfall: 60,
    DestinationCategory.cafe: 45,
    DestinationCategory.restaurant: 60,
    DestinationCategory.craft: 60,
    DestinationCategory.art: 60,
    DestinationCategory.island: 180,
    DestinationCategory.mountain: 150,
    DestinationCategory.themePark: 240,
    DestinationCategory.mall: 90,
  };

  static const Map<HiddenGemCategory, int> _gemVisitMinutes = {
    HiddenGemCategory.food: 45,
    HiddenGemCategory.culture: 40,
    HiddenGemCategory.nature: 35,
    HiddenGemCategory.viewpoint: 25,
    HiddenGemCategory.craft: 40,
  };

  static const Map<DestinationCategory, (int open, int close)> _destinationHours = {
    DestinationCategory.attraction: (8, 20),
    DestinationCategory.heritageSite: (9, 17),
    DestinationCategory.museum: (9, 17),
    DestinationCategory.viewpoint: (6, 20),
    DestinationCategory.park: (7, 19),
    DestinationCategory.beach: (6, 20),
    DestinationCategory.waterfall: (7, 18),
    DestinationCategory.cafe: (8, 21),
    DestinationCategory.restaurant: (11, 21),
    DestinationCategory.craft: (9, 18),
    DestinationCategory.art: (9, 18),
    DestinationCategory.island: (7, 18),
    DestinationCategory.mountain: (6, 17),
    DestinationCategory.themePark: (9, 21),
    DestinationCategory.mall: (10, 22),
  };

  static const Map<HiddenGemCategory, (int open, int close)> _gemHours = {
    HiddenGemCategory.food: (11, 21),
    HiddenGemCategory.culture: (9, 17),
    HiddenGemCategory.nature: (7, 19),
    HiddenGemCategory.viewpoint: (6, 20),
    HiddenGemCategory.craft: (9, 18),
  };

  static const int _dayStartHour = 9;
  static const int _dayEndHour = 21; // "9am to 9pm" touring window
  static const int _lunchBreakMinutes = 60;
  static const int _dinnerBreakMinutes = 60;

  /// Flattens the primary path's hops into a single ordered sequence of
  /// stops (destinations interleaved with the hidden gems threaded into
  /// each leg), each carrying its own placeholder visit duration/opening
  /// window and the real routed travel time from whatever precedes it.
  /// [_scheduleItems] then packs this sequence across as many days as it
  /// actually takes.
  List<_PlanItem> _flattenPlanItems({
    required List<Destination> destinations,
    required List<_Hop> hops,
  }) {
    final items = <_PlanItem>[_PlanItem.forDestination(destinations.first, travelMinutesFromPrevious: 0, isFirst: true)];

    for (var i = 0; i < hops.length; i++) {
      final hop = hops[i];
      for (var g = 0; g < hop.gems.length; g++) {
        items.add(_PlanItem.forGem(hop.gems[g], travelMinutesFromPrevious: hop.driveSegmentMinutes[g]));
      }
      items.add(_PlanItem.forDestination(
        destinations[i + 1],
        travelMinutesFromPrevious: hop.driveSegmentMinutes.last,
        isFirst: false,
      ));
    }
    return items;
  }

  /// Packs the flattened stop sequence into real, scheduled days: each day
  /// runs 9am–9pm, a stop that wouldn't fit (or that closes before it could
  /// be visited) rolls to the next day instead, and a lunch/dinner break is
  /// inserted once per day when the schedule crosses midday/evening —
  /// unless the very next stop is itself a food stop, which serves as the
  /// meal instead of adding a separate break.
  ({List<ItineraryStop> stops, int totalMinutes}) _scheduleItems(List<_PlanItem> items) {
    final stops = <ItineraryStop>[];
    var dayIndex = 0;
    var clock = DateTime(2000, 1, 1, _dayStartHour);
    var hadLunch = false;
    var hadDinner = false;

    for (var idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      var arrival = clock.add(Duration(minutes: item.travelMinutesFromPrevious));
      var rolledToNewDay = false;

      final currentDayEnd = DateTime(2000, 1, 1 + dayIndex, _dayEndHour);
      final closeTime = DateTime(2000, 1, 1 + dayIndex, item.closeHour);
      final wouldOverrunDay = arrival.add(Duration(minutes: item.visitMinutes)).isAfter(currentDayEnd);
      final wouldMissClosing = arrival.isAfter(closeTime);
      if (idx > 0 && (wouldOverrunDay || wouldMissClosing)) {
        dayIndex++;
        hadLunch = false;
        hadDinner = false;
        clock = DateTime(2000, 1, 1 + dayIndex, _dayStartHour);
        arrival = clock;
        rolledToNewDay = true;
      }

      final openTime = DateTime(2000, 1, 1 + dayIndex, item.openHour);
      if (arrival.isBefore(openTime)) arrival = openTime;

      if (!rolledToNewDay && stops.isNotEmpty) {
        stops[stops.length - 1] =
            stops.last.copyWith(travelToNext: '${item.travelMinutesFromPrevious} min drive');
      }

      if (!hadLunch && arrival.hour >= 12) {
        if (item.isFood) {
          hadLunch = true;
        } else {
          final breakStart =
              arrival.hour >= 12 ? arrival : DateTime(2000, 1, 1 + dayIndex, 12);
          stops.add(_breakStop(dayIndex, breakStart, 'Lunch Break'));
          arrival = breakStart.add(const Duration(minutes: _lunchBreakMinutes));
          hadLunch = true;
        }
      }
      if (!hadDinner && arrival.hour >= 18) {
        if (item.isFood) {
          hadDinner = true;
        } else {
          stops.add(_breakStop(dayIndex, arrival, 'Dinner Break'));
          arrival = arrival.add(const Duration(minutes: _dinnerBreakMinutes));
          hadDinner = true;
        }
      }

      stops.add(ItineraryStop(
        time: _formatTime(arrival),
        title: item.title,
        description: item.description,
        meta: item.meta,
        badge: item.badge,
        isMainDestination: item.isMainDestination,
        imagePlaceholderCount: item.imagePlaceholderCount,
        dayIndex: dayIndex,
      ));

      clock = arrival.add(Duration(minutes: item.visitMinutes));
    }

    // Expressed in the same "9-hour touring day" units as
    // VisitDurationOption.totalMinutes, so estimatedMinutesNeeded vs.
    // budgetMinutes reduces to a simple "days used <= days planned" check.
    final daysUsed = dayIndex + 1;
    return (stops: stops, totalMinutes: daysUsed * activeHoursPerDay * 60);
  }

  ItineraryStop _breakStop(int dayIndex, DateTime time, String title) {
    return ItineraryStop(
      time: _formatTime(time),
      title: title,
      description: 'Scheduled downtime to eat and recharge before the next stop.',
      meta: _formatStayDuration(title == 'Lunch Break' ? _lunchBreakMinutes : _dinnerBreakMinutes),
      badge: StopBadge.mealBreak,
      isMainDestination: false,
      dayIndex: dayIndex,
    );
  }

  /// Builds the day-trip timeline from the primary path's hops.
  /// [_scheduleItems] always schedules every stop, using as many days as it
  /// actually takes — [ItineraryPlan.isFeasible] (compared against
  /// `durationOption`/`customDays`, back in [generate]) is what tells the
  /// traveller if that's more than they planned for.
  ({List<ItineraryStop> stops, int totalMinutes}) _buildTimeline({
    required List<Destination> destinations,
    required List<_Hop> hops,
  }) {
    final items = _flattenPlanItems(destinations: destinations, hops: hops);
    return _scheduleItems(items);
  }

  String _formatTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  static String _formatStayDuration(int minutes) {
    final hours = minutes / 60;
    if (hours < 1) return '$minutes min';
    if (hours == hours.roundToDouble()) return '${hours.round()} hr';
    return '${hours.toStringAsFixed(1)} hr';
  }
}

class _ScoredGem {
  final HiddenGem gem;
  final double score;
  const _ScoredGem({required this.gem, required this.score});
}

/// A destination or hidden gem awaiting scheduling — carries its own
/// placeholder visit duration and "opening hours" (see the category maps on
/// [ItineraryRepository]) plus the real routed travel time from whichever
/// stop precedes it, so [ItineraryRepository._scheduleItems] can pack a
/// sequence of these into actual days.
class _PlanItem {
  final String title;
  final String description;
  final String meta;
  final StopBadge badge;
  final bool isMainDestination;
  final bool isFood;
  final int visitMinutes;
  final int openHour;
  final int closeHour;
  final int imagePlaceholderCount;
  final int travelMinutesFromPrevious;

  const _PlanItem({
    required this.title,
    required this.description,
    required this.meta,
    required this.badge,
    required this.isMainDestination,
    required this.isFood,
    required this.visitMinutes,
    required this.openHour,
    required this.closeHour,
    required this.imagePlaceholderCount,
    required this.travelMinutesFromPrevious,
  });

  factory _PlanItem.forDestination(
    Destination destination, {
    required int travelMinutesFromPrevious,
    required bool isFirst,
  }) {
    final visitMinutes = ItineraryRepository._destinationVisitMinutes[destination.category] ?? 60;
    final hours = ItineraryRepository._destinationHours[destination.category] ?? (9, 18);
    return _PlanItem(
      title: destination.name,
      description: isFirst
          ? 'Starting point of your journey.'
          : 'A ${destination.category.label.toLowerCase()} stop on your route.',
      meta: '${ItineraryRepository._formatStayDuration(visitMinutes)} • ${destination.category.label}',
      badge: StopBadge.selected,
      isMainDestination: true,
      isFood: destination.category == DestinationCategory.restaurant ||
          destination.category == DestinationCategory.cafe,
      visitMinutes: visitMinutes,
      openHour: hours.$1,
      closeHour: hours.$2,
      imagePlaceholderCount: destination.category == DestinationCategory.heritageSite ? 2 : 0,
      travelMinutesFromPrevious: travelMinutesFromPrevious,
    );
  }

  factory _PlanItem.forGem(HiddenGem gem, {required int travelMinutesFromPrevious}) {
    final visitMinutes = ItineraryRepository._gemVisitMinutes[gem.category] ?? 30;
    final hours = ItineraryRepository._gemHours[gem.category] ?? (9, 18);
    return _PlanItem(
      title: gem.name,
      description: gem.description,
      meta: '${gem.category.label} • ${gem.popularity.label} popularity',
      badge: StopBadge.localGem,
      isMainDestination: false,
      isFood: gem.category == HiddenGemCategory.food,
      visitMinutes: visitMinutes,
      openHour: hours.$1,
      closeHour: hours.$2,
      imagePlaceholderCount: 0,
      travelMinutesFromPrevious: travelMinutesFromPrevious,
    );
  }
}

/// One leg of the routed path (between two consecutive user-selected
/// destinations), possibly detouring through hidden gems as real waypoints.
class _Hop {
  final List<HiddenGem> gems;
  final List<LatLng> polyline;
  final double drivingDistanceKm;
  final int drivingMinutes;
  final double walkingDistanceKm;
  final int walkingMinutes;

  /// Per-segment minutes aligned to `[start, ...gems, end]` — e.g. with 2
  /// gems this has 3 entries: start→gem0, gem0→gem1, gem1→end.
  final List<int> driveSegmentMinutes;
  final List<int> walkSegmentMinutes;

  const _Hop({
    required this.gems,
    required this.polyline,
    required this.drivingDistanceKm,
    required this.drivingMinutes,
    required this.walkingDistanceKm,
    required this.walkingMinutes,
    required this.driveSegmentMinutes,
    required this.walkSegmentMinutes,
  });
}
