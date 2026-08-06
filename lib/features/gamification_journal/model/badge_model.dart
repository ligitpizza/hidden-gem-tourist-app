enum BadgeCriteriaType { totalCheckIns, categoryCount, stateVisit, quizzesCompleted }

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String iconFilename;
  final BadgeCriteriaType criteriaType;
  final int threshold;

  /// Only used when criteriaType is categoryCount (e.g. "Nature") or
  /// stateVisit (e.g. "Perak"). Null for totalCheckIns.
  final String? targetValue;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconFilename,
    required this.criteriaType,
    required this.threshold,
    this.targetValue,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      iconFilename: json['icon_filename'] as String,
      criteriaType: BadgeCriteriaType.values.byName(json['criteria_type'] as String),
      threshold: json['threshold'] as int,
      targetValue: json['target_value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_filename': iconFilename,
      'criteria_type': criteriaType.name,
      'threshold': threshold,
      'target_value': targetValue,
    };
  }
}
