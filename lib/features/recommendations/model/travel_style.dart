/// A traveller's interest category — used to personalize which hidden gems
/// get surfaced. Matches the "Define Your Travel Style" set from the
/// team's Module 1 mockups.
enum TravelStyle {
  nature,
  culture,
  adventure,
  localFood,
  heritage,
  wellness,
  urbanExploration,
  fauna,
  flora,
}

extension TravelStyleX on TravelStyle {
  String get label {
    switch (this) {
      case TravelStyle.nature:
        return 'Nature';
      case TravelStyle.culture:
        return 'Culture';
      case TravelStyle.adventure:
        return 'Adventure';
      case TravelStyle.localFood:
        return 'Local Food';
      case TravelStyle.heritage:
        return 'Heritage';
      case TravelStyle.wellness:
        return 'Wellness';
      case TravelStyle.urbanExploration:
        return 'Urban Exploration';
      case TravelStyle.fauna:
        return 'Fauna';
      case TravelStyle.flora:
        return 'Flora';
    }
  }
}

TravelStyle? travelStyleFromKey(String key) {
  for (final style in TravelStyle.values) {
    if (style.name == key) return style;
  }
  return null;
}
