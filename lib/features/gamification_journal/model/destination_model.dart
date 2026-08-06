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
}
