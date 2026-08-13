import '../../../shared/models/hidden_gem.dart';
import '../../destination_exploration/model/map_destination.dart';

/// Maps destination_exploration's 5-bucket [HiddenGemCategory] to this
/// module's plain category label — viewpoint/craft don't have a natural
/// equivalent here, so they fall back to Culture.
String _journalCategoryLabel(HiddenGemCategory category) => switch (category) {
      HiddenGemCategory.nature => 'Nature',
      HiddenGemCategory.food => 'Food',
      HiddenGemCategory.culture => 'Culture',
      HiddenGemCategory.viewpoint => 'Culture',
      HiddenGemCategory.craft => 'Culture',
    };

/// The `destinations` table only carries a town/area-level `city` column
/// (e.g. "George Town", "Batu Ferringhi") — there's no real Malaysian
/// state column. Both the Dashboard's "states explored" ring and this
/// module's stateVisit badges need an actual state, so this resolves the
/// known towns to their state; anything unrecognised falls back to the
/// raw city value rather than silently guessing, so new areas still show
/// *something* meaningful instead of breaking.
const Map<String, String> _cityToState = {
  'george town': 'Penang',
  'batu ferringhi': 'Penang',
  'teluk bahang': 'Penang',
  'balik pulau': 'Penang',
  'bayan lepas': 'Penang',
  'butterworth': 'Penang',
  // Added with the nationwide destination set (see
  // supabase/migrations/20260813130000_nationwide_destinations.sql).
  'kuala lumpur': 'Kuala Lumpur',
  'gombak': 'Selangor',
  'bandar sunway': 'Selangor',
  'putrajaya': 'Putrajaya',
  'melaka city': 'Malacca',
  'nusajaya': 'Johor',
  'desaru': 'Johor',
  'cameron highlands': 'Pahang',
  'tioman island': 'Pahang',
  'genting highlands': 'Pahang',
  'perhentian islands': 'Terengganu',
  'kota bharu': 'Kelantan',
  'batu gajah': 'Perak',
  'langkawi': 'Kedah',
  'kaki bukit': 'Perlis',
  'port dickson': 'Negeri Sembilan',
  'kundasang': 'Sabah',
};

String stateForCity(String city) {
  final match = _cityToState[city.trim().toLowerCase()];
  return match ?? city;
}

class DestinationModel {
  final String id;
  final String name;
  final String state;
  final String category; // Nature, Food, Adventure, Culture, Relaxation
  final double latitude;
  final double longitude;
  final String description;
  final String imageUrl;
  final double checkInRadiusMeters;

  DestinationModel({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.imageUrl,
    this.checkInRadiusMeters = 300,
  });

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    return DestinationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      category: json['category'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String,
      imageUrl: json['image_url'] as String,
      checkInRadiusMeters:
          (json['check_in_radius_meters'] as num?)?.toDouble() ?? 300,
    );
  }

  /// Builds a [DestinationModel] from an already-loaded [MapDestination]
  /// (destination_exploration's own model) — used when the interactive map
  /// opens the existing Destination Detail screen on double-tap, so no
  /// extra network round-trip is needed for data already on screen.
  factory DestinationModel.fromMapDestination(
    MapDestination destination, {
    String state = 'Penang',
  }) {
    return DestinationModel(
      id: destination.id,
      name: destination.name,
      state: state,
      category: _journalCategoryLabel(destination.category),
      latitude: destination.location.latitude,
      longitude: destination.location.longitude,
      description: destination.description,
      imageUrl: destination.imageUrls.isNotEmpty
          ? destination.imageUrls.first
          : 'https://picsum.photos/seed/${destination.id}/900/600',
    );
  }
}
