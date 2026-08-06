class CulturalFactModel {
  final String id;
  final String factText;
  final String category;

  CulturalFactModel({
    required this.id,
    required this.factText,
    required this.category,
  });

  factory CulturalFactModel.fromJson(Map<String, dynamic> json) {
    return CulturalFactModel(
      id: json['id'] as String,
      factText: json['fact_text'] as String,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fact_text': factText,
      'category': category,
    };
  }
}
