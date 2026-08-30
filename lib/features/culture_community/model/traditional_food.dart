class TraditionalFood {
  final String id;
  final String name;
  final String description;
  final List<String> ingredients;
  final String? imageUrl;
  final String culturalHistory;
  final String state;
  final String? region;
  final String culturalCategory;
  final List<String> dietaryTags;
  final List<String> allergens;
  final String? allergyNotes;
  final List<String> travelStyles;

  const TraditionalFood({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.imageUrl,
    required this.culturalHistory,
    required this.state,
    required this.region,
    required this.culturalCategory,
    required this.dietaryTags,
    required this.allergens,
    required this.allergyNotes,
    required this.travelStyles,
  });

  factory TraditionalFood.fromMap(Map<String, dynamic> row) {
    return TraditionalFood(
      id: row['id'] as String,
      name: row['name'] as String,
      description: (row['description'] as String?) ?? '',
      ingredients: List<String>.from((row['ingredients'] as List?) ?? const []),
      imageUrl: row['image_url'] as String?,
      culturalHistory: (row['cultural_history'] as String?) ?? '',
      state: row['state'] as String,
      region: row['region'] as String?,
      culturalCategory: row['cultural_category'] as String,
      dietaryTags: List<String>.from((row['dietary_tags'] as List?) ?? const []),
      allergens: List<String>.from((row['allergens'] as List?) ?? const []),
      allergyNotes: row['allergy_notes'] as String?,
      travelStyles: List<String>.from((row['travel_styles'] as List?) ?? const []),
    );
  }
}
