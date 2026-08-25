import 'travel_style.dart';

/// FR1.1's "budget range" input. Values match the `budget_range` check
/// constraint on `user_travel_preferences` in Supabase.
enum BudgetRange { budget, midRange, luxury }

extension BudgetRangeX on BudgetRange {
  String get label {
    switch (this) {
      case BudgetRange.budget:
        return 'Budget';
      case BudgetRange.midRange:
        return 'Mid-range';
      case BudgetRange.luxury:
        return 'Luxury';
    }
  }

  String get dbValue {
    switch (this) {
      case BudgetRange.budget:
        return 'budget';
      case BudgetRange.midRange:
        return 'mid_range';
      case BudgetRange.luxury:
        return 'luxury';
    }
  }
}

BudgetRange? budgetRangeFromDb(String? value) {
  switch (value) {
    case 'budget':
      return BudgetRange.budget;
    case 'mid_range':
      return BudgetRange.midRange;
    case 'luxury':
      return BudgetRange.luxury;
    default:
      return null;
  }
}

/// FR1.1's "destination types" input — kept as free-form strings in
/// Supabase (`destination_types text[]`) since, unlike travel style, the
/// team hasn't fixed a vocabulary for this one; these four cover the
/// mockup's intent without overcommitting to a taxonomy the team might
/// still want to change.
enum DestinationTypePreference { urban, rural, natureReserve, mixed }

extension DestinationTypePreferenceX on DestinationTypePreference {
  String get label {
    switch (this) {
      case DestinationTypePreference.urban:
        return 'Urban';
      case DestinationTypePreference.rural:
        return 'Rural';
      case DestinationTypePreference.natureReserve:
        return 'Nature Reserve';
      case DestinationTypePreference.mixed:
        return 'Mixed';
    }
  }

  String get dbValue => name;
}

DestinationTypePreference? destinationTypeFromDb(String value) {
  for (final type in DestinationTypePreference.values) {
    if (type.dbValue == value) return type;
  }
  return null;
}

/// A tourist's travel preference profile (FR1.1) — the "Define Your Travel
/// Style" screen's output, persisted to `user_travel_preferences`.
class TravelPreferenceProfile {
  final Set<TravelStyle> categories;
  final BudgetRange? budgetRange;
  final Set<DestinationTypePreference> destinationTypes;
  final DateTime? onboardedAt;

  const TravelPreferenceProfile({
    required this.categories,
    this.budgetRange,
    this.destinationTypes = const {},
    this.onboardedAt,
  });

  static const empty = TravelPreferenceProfile(categories: {});

  bool get hasAnyPreference => categories.isNotEmpty;

  factory TravelPreferenceProfile.fromRow(Map<String, dynamic> row) {
    final rawCategories = (row['categories'] as List?) ?? const [];
    final rawTypes = (row['destination_types'] as List?) ?? const [];
    return TravelPreferenceProfile(
      categories: rawCategories
          .map((c) => travelStyleFromKey(c as String?))
          .whereType<TravelStyle>()
          .toSet(),
      budgetRange: budgetRangeFromDb(row['budget_range'] as String?),
      destinationTypes: rawTypes
          .map((t) => destinationTypeFromDb(t as String))
          .whereType<DestinationTypePreference>()
          .toSet(),
      onboardedAt:
          row['onboarded_at'] != null ? DateTime.tryParse(row['onboarded_at'] as String) : null,
    );
  }

  Map<String, dynamic> toRow(String userId) {
    return {
      'user_id': userId,
      'categories': categories.map((c) => c.name).toList(),
      'budget_range': budgetRange?.dbValue,
      'destination_types': destinationTypes.map((t) => t.dbValue).toList(),
      'onboarded_at': onboardedAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  TravelPreferenceProfile copyWith({
    Set<TravelStyle>? categories,
    BudgetRange? budgetRange,
    Set<DestinationTypePreference>? destinationTypes,
    DateTime? onboardedAt,
  }) {
    return TravelPreferenceProfile(
      categories: categories ?? this.categories,
      budgetRange: budgetRange ?? this.budgetRange,
      destinationTypes: destinationTypes ?? this.destinationTypes,
      onboardedAt: onboardedAt ?? this.onboardedAt,
    );
  }
}
