/// A traveller's interest category — used to personalize which hidden gems
/// get surfaced. Matches the "Define Your Travel Style" set from the
/// Module 1 mockups, and the `travel_style` Postgres enum
/// (supabase/migrations/20260825120000_hidden_gem_recommendation_schema.sql)
/// value-for-value — `.name` below is sent to/read from that column as-is.
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

TravelStyle? travelStyleFromKey(String? key) {
  if (key == null) return null;
  for (final style in TravelStyle.values) {
    if (style.name == key) return style;
  }
  return null;
}
