class TraditionalFoodPlace {
  const TraditionalFoodPlace({
    required this.placeId,
    required this.name,
    required this.category,
    required this.state,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.halalStatus,
    required this.description,
  });

  final String placeId;

  final String name;

  final String category;

  final String state;

  final String? city;

  final double latitude;

  final double longitude;

  /// Possible values:
  /// certified
  /// muslim_friendly
  /// non_halal
  /// unknown
  final String halalStatus;

  final String? description;

  factory TraditionalFoodPlace.fromMaps({
    required Map<String, dynamic> linkRow,
    required Map<String, dynamic> placeRow,
  }) {
    return TraditionalFoodPlace(
      placeId: placeRow['id'] as String,
      name:
      (placeRow['name'] as String?) ??
          'Unknown Place',
      category:
      (placeRow['category'] as String?) ?? '',
      state:
      (placeRow['state'] as String?) ?? '',
      city: placeRow['city'] as String?,
      latitude:
      (placeRow['latitude'] as num).toDouble(),
      longitude:
      (placeRow['longitude'] as num).toDouble(),
      halalStatus:
      (linkRow['halal_status'] as String?) ??
          'unknown',
      description:
      placeRow['description'] as String?,
    );
  }
}