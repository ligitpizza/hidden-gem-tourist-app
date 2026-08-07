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
