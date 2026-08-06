import 'journal_media_model.dart';

enum LocalSupportOption { foodCafe, souvenirsHandicrafts, localGuideTransport }

extension LocalSupportOptionLabel on LocalSupportOption {
  String get label {
    switch (this) {
      case LocalSupportOption.foodCafe:
        return 'Food/Café';
      case LocalSupportOption.souvenirsHandicrafts:
        return 'Souvenirs/Handicrafts';
      case LocalSupportOption.localGuideTransport:
        return 'Local Guide/Transport';
    }
  }
}

class JournalEntryModel {
  final String id;
  final String userId;
  final String checkInId;
  final String destinationId;
  final String notes;
  final List<JournalMediaModel> media;

  /// Local spending logged per category — a category counts as "supported"
  /// simply by having a positive amount here, so there's no separate
  /// boolean toggle to keep in sync. Fully optional: an entry with an
  /// empty map is still a complete entry.
  final Map<LocalSupportOption, double> spendingByCategory;

  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntryModel({
    required this.id,
    required this.userId,
    required this.checkInId,
    required this.destinationId,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.media = const [],
    this.spendingByCategory = const {},
  });

  double get totalSpendingRM =>
      spendingByCategory.values.fold(0, (sum, v) => sum + v);

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      checkInId: json['check_in_id'] as String,
      destinationId: json['destination_id'] as String,
      notes: json['notes'] as String? ?? '',
      media: (json['media'] as List<dynamic>? ?? [])
          .map((m) => JournalMediaModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      spendingByCategory: (json['spending_by_category'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(
                LocalSupportOption.values.byName(key),
                (value as num).toDouble(),
              )),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'check_in_id': checkInId,
      'destination_id': destinationId,
      'notes': notes,
      'media': media.map((m) => m.toJson()).toList(),
      'spending_by_category':
          spendingByCategory.map((key, value) => MapEntry(key.name, value)),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  JournalEntryModel copyWith({
    String? notes,
    List<JournalMediaModel>? media,
    Map<LocalSupportOption, double>? spendingByCategory,
    DateTime? updatedAt,
  }) {
    return JournalEntryModel(
      id: id,
      userId: userId,
      checkInId: checkInId,
      destinationId: destinationId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      media: media ?? this.media,
      spendingByCategory: spendingByCategory ?? this.spendingByCategory,
    );
  }
}
