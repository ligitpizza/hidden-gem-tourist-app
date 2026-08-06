import 'package:latlong2/latlong.dart';

import '../../../shared/models/hidden_gem.dart';

/// A destination pin on the Interactive Destination Map, sourced from the
/// dedicated `destinations` table. Deliberately separate from the shared
/// lean `Destination` model (used by itinerary planning) since this screen
/// needs description/rating/image fields that model doesn't carry.
class MapDestination {
  final String id;
  final String name;
  final String description;
  final HiddenGemCategory category;
  final LatLng location;
  final double avgRating;
  final List<String> imageUrls;

  const MapDestination({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.location,
    this.avgRating = 0,
    this.imageUrls = const [],
  });
}
