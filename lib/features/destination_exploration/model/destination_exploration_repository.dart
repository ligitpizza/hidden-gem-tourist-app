import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/hidden_gem_scoring.dart';
import 'map_destination.dart';

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

  /// Loads every destination for the map. Deliberately does **not** catch
  /// Supabase errors here — the Controller catches them so it can show a
  /// distinct "load failed" state (E1) instead of an indistinguishable
  /// empty result.
  Future<List<MapDestination>> loadDestinations() async {
    final rows = await Supabase.instance.client.from('destinations').select();
    return rows.map(mapRow).toList();
  }
}
