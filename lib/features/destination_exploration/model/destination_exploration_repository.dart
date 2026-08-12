import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/hidden_gem.dart';
import '../../../shared/services/hidden_gem_scoring.dart';
import 'comparison_destination.dart';
import 'crowd_level.dart';
import 'map_destination.dart';

/// Great-circle distance between two points, in kilometres.
double legDistanceKm(LatLng a, LatLng b) {
  const distance = Distance();
  return distance.as(LengthUnit.Kilometer, a, b);
}

/// Greedy nearest-neighbour visiting order starting from [origin]: repeatedly
/// picks the closest not-yet-visited candidate to the last-placed stop.
List<MapDestination> orderByNearestNeighbor(
  MapDestination origin,
  List<MapDestination> candidates,
) {
  final remaining = List<MapDestination>.from(candidates);
  final ordered = <MapDestination>[];
  var current = origin.location;

  while (remaining.isNotEmpty) {
    remaining.sort(
      (a, b) => legDistanceKm(current, a.location).compareTo(legDistanceKm(current, b.location)),
    );
    final next = remaining.removeAt(0);
    ordered.add(next);
    current = next.location;
  }

  return ordered;
}

/// Loads destinations for the Interactive Destination Map from the
/// dedicated `destinations` table (standalone — this feature does not
/// share data with any other module; see the design spec).
class DestinationExplorationRepository {
  /// Pure row -> [MapDestination] mapping, kept separate from the network
  /// call so it's unit-testable without a live Supabase connection.
  static MapDestination mapRow(Map<String, dynamic> row) {
    final rawImages = row['images'];
    final imageUrls = rawImages is List
        ? rawImages.whereType<String>().toList()
        : const <String>[];
    final description = (row['description'] as String?)?.trim();

    return MapDestination(
      id: row['id'] as String,
      name: row['name'] as String,
      description: (description != null && description.isNotEmpty)
          ? description
          : 'No description available yet.',
      category: HiddenGemScoring.categoryFromDb(row['category'] as String),
      location: LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ),
      avgRating: (row['avg_rating'] as num?)?.toDouble() ?? 0.0,
      imageUrls: imageUrls,
    );
  }

  /// Pure row -> [ComparisonDestination] mapping, kept separate from the
  /// network call so it's unit-testable without a live Supabase connection.
  static ComparisonDestination mapComparisonRow(Map<String, dynamic> row) {
    final rawTags = row['accessibility_tags'];
    final accessibilityTags =
        rawTags is List ? rawTags.whereType<String>().toList() : const <String>[];
    final rawImages = row['images'];
    final imageUrls =
        rawImages is List ? rawImages.whereType<String>().toList() : const <String>[];

    return ComparisonDestination(
      id: row['id'] as String,
      name: row['name'] as String,
      city: (row['city'] as String?) ?? '',
      category: HiddenGemScoring.categoryFromDb(row['category'] as String),
      location: LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ),
      avgRating: (row['avg_rating'] as num?)?.toDouble() ?? 0.0,
      uniquenessScore: (row['uniqueness_score'] as num?)?.toDouble() ?? 0.0,
      accessibilityScore: (row['accessibility_score'] as num?)?.toDouble() ?? 0.0,
      popularity: gemPopularityFromDb(row['popularity'] as String?),
      crowdLevel: crowdLevelFromDb(row['crowd_level'] as String?),
      entranceCost: (row['entrance_cost'] as num?)?.toDouble(),
      difficultyLevel: row['difficulty_level'] as String?,
      accessibilityTags: accessibilityTags,
      visitDurationMinutes: (row['visit_duration_minutes'] as num?)?.toInt(),
      operatingHours: row['operating_hours'] as String?,
      imageUrls: imageUrls,
    );
  }

  /// Loads every destination for the map. Deliberately does **not** catch
  /// Supabase errors here — the Controller catches them so it can show a
  /// distinct "load failed" state (E1) instead of an indistinguishable
  /// empty result.
  Future<List<MapDestination>> loadDestinations() async {
    final rows = await Supabase.instance.client.from('destinations').select();
    return rows.map(mapRow).toList();
  }

  static const double clusterRadiusKm = 12;
  static const int clusterMaxStops = 8;

  /// Same-category destinations near [origin], closest-first, within
  /// [radiusKm] and capped at [maxStops] — the visiting order (nearest-
  /// neighbour) is computed separately by [orderByNearestNeighbor].
  Future<List<MapDestination>> nearbyByCategory({
    required MapDestination origin,
    double radiusKm = clusterRadiusKm,
    int maxStops = clusterMaxStops,
  }) async {
    final bufferDeg = radiusKm / 111.0;
    final lat = origin.location.latitude;
    final lng = origin.location.longitude;

    final rows = await Supabase.instance.client
        .from('destinations')
        .select()
        .gte('latitude', lat - bufferDeg)
        .lte('latitude', lat + bufferDeg)
        .gte('longitude', lng - bufferDeg)
        .lte('longitude', lng + bufferDeg);

    final candidates = rows
        .map(mapRow)
        .where((d) => d.id != origin.id && d.category == origin.category)
        .where((d) => legDistanceKm(origin.location, d.location) <= radiusKm)
        .toList()
      ..sort(
        (a, b) => legDistanceKm(origin.location, a.location)
            .compareTo(legDistanceKm(origin.location, b.location)),
      );

    return candidates.take(maxStops).toList();
  }

  /// Same-category destinations near an arbitrary [location] — the user's
  /// current position, rather than another destination's — closest-first,
  /// within [radiusKm] and capped at [maxStops]. Unlike [nearbyByCategory]
  /// (which searches around another destination and excludes it by id),
  /// every match here is a genuine candidate; the nearest one becomes the
  /// trail's anchor at the call site.
  Future<List<MapDestination>> nearbyByCategoryNearLocation({
    required LatLng location,
    required HiddenGemCategory category,
    double radiusKm = clusterRadiusKm,
    int maxStops = clusterMaxStops,
  }) async {
    final bufferDeg = radiusKm / 111.0;
    final lat = location.latitude;
    final lng = location.longitude;

    final rows = await Supabase.instance.client
        .from('destinations')
        .select()
        .gte('latitude', lat - bufferDeg)
        .lte('latitude', lat + bufferDeg)
        .gte('longitude', lng - bufferDeg)
        .lte('longitude', lng + bufferDeg);

    final candidates = rows
        .map(mapRow)
        .where((d) => d.category == category)
        .where((d) => legDistanceKm(location, d.location) <= radiusKm)
        .toList()
      ..sort(
        (a, b) => legDistanceKm(location, a.location).compareTo(legDistanceKm(location, b.location)),
      );

    return candidates.take(maxStops).toList();
  }

  /// The closest destination (any category) to [point], searching an
  /// expanding radius so a sparse area doesn't require scanning the whole
  /// table. Returns null if nothing is found even at the widest radius.
  Future<MapDestination?> nearestDestination(LatLng point) async {
    for (final radiusKm in const [5.0, 10.0, 20.0, 40.0]) {
      final bufferDeg = radiusKm / 111.0;
      final rows = await Supabase.instance.client
          .from('destinations')
          .select()
          .gte('latitude', point.latitude - bufferDeg)
          .lte('latitude', point.latitude + bufferDeg)
          .gte('longitude', point.longitude - bufferDeg)
          .lte('longitude', point.longitude + bufferDeg);

      if (rows.isEmpty) continue;

      final candidates = rows.map(mapRow).toList()
        ..sort(
          (a, b) =>
              legDistanceKm(point, a.location).compareTo(legDistanceKm(point, b.location)),
        );
      return candidates.first;
    }
    return null;
  }

  Future<List<ComparisonDestination>> fetchForComparison(List<String> ids) async {
    final rows =
        await Supabase.instance.client.from('destinations').select().inFilter('id', ids);
    return rows.map(mapComparisonRow).toList();
  }

  Future<List<MapDestination>> searchDestinations({
    String query = '',
    HiddenGemCategory? category,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    final filterBuilder = Supabase.instance.client.from('destinations').select();
    final rows = trimmed.isEmpty
        ? await filterBuilder.order('avg_rating', ascending: false).limit(limit)
        : await filterBuilder
            .ilike('name', '%${trimmed.replaceAll(RegExp(r'[,()%]'), ' ').trim()}%')
            .order('avg_rating', ascending: false)
            .limit(limit);

    final results = rows.map(mapRow).toList();
    if (category == null) return results;
    return results.where((d) => d.category == category).toList();
  }
}
