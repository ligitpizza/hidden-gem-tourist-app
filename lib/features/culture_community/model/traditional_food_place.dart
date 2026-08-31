class TraditionalFoodPlace {
  const TraditionalFoodPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.state,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.halalStatus,
    required this.description,
    required this.verificationSource,
    required this.verificationUrl,
    required this.verifiedAt,
    required this.mappingNotes,
  });

  final String id;
  final String name;
  final String category;

  final String state;
  final String? city;
  final String? address;

  final double latitude;
  final double longitude;

  final String halalStatus;

  final String? description;

  final String? verificationSource;
  final String? verificationUrl;
  final DateTime? verifiedAt;

  final String? mappingNotes;

  factory TraditionalFoodPlace.fromJoinRow(
      Map<String, dynamic> row,
      ) {
    final location = (row['food_locations'] as Map)
        .cast<String, dynamic>();

    return TraditionalFoodPlace(
      id: location['id'] as String,
      name: location['name'] as String,
      category:
      (location['category'] as String?) ??
          'restaurant',
      state:
      (location['state'] as String?) ?? '',
      city: location['city'] as String?,
      address: location['address'] as String?,
      latitude:
      (location['latitude'] as num).toDouble(),
      longitude:
      (location['longitude'] as num).toDouble(),
      halalStatus:
      (location['halal_status'] as String?) ??
          'unknown',
      description:
      location['description'] as String?,
      verificationSource:
      (row['verification_source'] as String?) ??
          location['verification_source'] as String?,
      verificationUrl:
      (row['verification_url'] as String?) ??
          location['verification_url'] as String?,
      verifiedAt:
      _parseDate(
        row['verified_at'] ??
            location['verified_at'],
      ),
      mappingNotes:
      row['notes'] as String?,
    );
  }

  static DateTime? _parseDate(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}