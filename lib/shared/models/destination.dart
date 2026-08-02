import 'package:latlong2/latlong.dart';

/// Broad category a searchable destination falls under. Mirrors the
/// `places.category` text values in the Supabase places table.
enum DestinationCategory {
  attraction,
  heritageSite,
  museum,
  viewpoint,
  park,
  beach,
  waterfall,
  cafe,
  restaurant,
  craft,
  art,
}

extension DestinationCategoryX on DestinationCategory {
  String get label {
    switch (this) {
      case DestinationCategory.attraction:
        return 'Attraction';
      case DestinationCategory.heritageSite:
        return 'Heritage Site';
      case DestinationCategory.museum:
        return 'Museum';
      case DestinationCategory.viewpoint:
        return 'Viewpoint';
      case DestinationCategory.park:
        return 'Park';
      case DestinationCategory.beach:
        return 'Beach';
      case DestinationCategory.waterfall:
        return 'Waterfall';
      case DestinationCategory.cafe:
        return 'Cafe';
      case DestinationCategory.restaurant:
        return 'Restaurant';
      case DestinationCategory.craft:
        return 'Craft';
      case DestinationCategory.art:
        return 'Art';
    }
  }

  /// The text value used in the `places.category` column.
  String get dbValue {
    switch (this) {
      case DestinationCategory.attraction:
        return 'attraction';
      case DestinationCategory.heritageSite:
        return 'heritage_site';
      case DestinationCategory.museum:
        return 'museum';
      case DestinationCategory.viewpoint:
        return 'viewpoint';
      case DestinationCategory.park:
        return 'park';
      case DestinationCategory.beach:
        return 'beach';
      case DestinationCategory.waterfall:
        return 'waterfall';
      case DestinationCategory.cafe:
        return 'cafe';
      case DestinationCategory.restaurant:
        return 'restaurant';
      case DestinationCategory.craft:
        return 'craft';
      case DestinationCategory.art:
        return 'art';
    }
  }
}

/// Parses a `places.category` column value into a [DestinationCategory],
/// defaulting to [DestinationCategory.attraction] for anything unrecognised.
DestinationCategory destinationCategoryFromDb(String value) {
  return DestinationCategory.values.firstWhere(
    (c) => c.dbValue == value,
    orElse: () => DestinationCategory.attraction,
  );
}

/// A place a traveller can add as a stop when planning a route.
class Destination {
  final String id;
  final String name;
  final String city;
  final DestinationCategory category;
  final LatLng location;

  const Destination({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.location,
  });
}
