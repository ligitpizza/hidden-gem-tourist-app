enum CulturalEventCategory {
  festival,
  culturalShow,
  communityActivity,
}

extension CulturalEventCategoryX on CulturalEventCategory {
  String get label {
    switch (this) {
      case CulturalEventCategory.festival:
        return 'Festival';
      case CulturalEventCategory.culturalShow:
        return 'Cultural Show';
      case CulturalEventCategory.communityActivity:
        return 'Community Activity';
    }
  }

  String get dbValue {
    switch (this) {
      case CulturalEventCategory.festival:
        return 'festival';
      case CulturalEventCategory.culturalShow:
        return 'cultural_show';
      case CulturalEventCategory.communityActivity:
        return 'community_activity';
    }
  }
}

CulturalEventCategory culturalEventCategoryFromDb(
    String value,
    ) {
  switch (value) {
    case 'festival':
      return CulturalEventCategory.festival;

    case 'cultural_show':
      return CulturalEventCategory.culturalShow;

    case 'community_activity':
      return CulturalEventCategory.communityActivity;

    default:
      throw FormatException(
        'Unknown cultural event category: $value',
      );
  }
}

class CulturalEvent {
  const CulturalEvent({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.venueName,
    required this.address,
    required this.state,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.officialCategories,
    required this.scheduleNote,
    required this.sourceName,
    required this.sourceUrl,
    required this.sourceCheckedAt,
    required this.travelStyles,
    required this.isFeatured,
  });

  final String id;
  final String name;
  final CulturalEventCategory category;
  final String description;

  final DateTime startAt;
  final DateTime? endAt;

  final String venueName;
  final String? address;

  final String state;
  final String? city;

  final double latitude;
  final double longitude;

  final String? imageUrl;

  final List<String> officialCategories;
  final String? scheduleNote;

  final String? sourceName;
  final String? sourceUrl;
  final DateTime? sourceCheckedAt;

  final List<String> travelStyles;

  final bool isFeatured;

  factory CulturalEvent.fromMap(
      Map<String, dynamic> row,
      ) {
    return CulturalEvent(
      id: row['id'] as String,
      name: row['name'] as String,
      category: culturalEventCategoryFromDb(
        row['category'] as String,
      ),
      description:
      (row['description'] as String?) ?? '',
      startAt: DateTime.parse(
        row['start_at'] as String,
      ),
      endAt: row['end_at'] == null
          ? null
          : DateTime.parse(
        row['end_at'] as String,
      ),
      venueName: row['venue_name'] as String,
      address: row['address'] as String?,
      state: row['state'] as String,
      city: row['city'] as String?,
      latitude:
      (row['latitude'] as num).toDouble(),
      longitude:
      (row['longitude'] as num).toDouble(),
      imageUrl: row['image_url'] as String?,
      officialCategories: List<String>.from(
        (row['official_categories'] as List?) ??
            const [],
      ),
      scheduleNote: row['schedule_note'] as String?,
      sourceName: row['source_name'] as String?,
      sourceUrl: row['source_url'] as String?,
      sourceCheckedAt:
      row['source_checked_at'] == null
          ? null
          : DateTime.parse(
        row['source_checked_at'] as String,
      ),
      travelStyles: List<String>.from(
        (row['travel_styles'] as List?) ??
            const [],
      ),
      isFeatured:
      (row['is_featured'] as bool?) ?? false,
    );
  }
}