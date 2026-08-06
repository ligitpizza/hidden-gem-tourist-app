enum JournalMediaType { photo, video }

/// One photo or video attached to a journal entry — entries hold a list of
/// these (a carousel) rather than a single photo.
class JournalMediaModel {
  final String id;
  final String url;
  final JournalMediaType type;

  JournalMediaModel({required this.id, required this.url, required this.type});

  factory JournalMediaModel.fromJson(Map<String, dynamic> json) {
    return JournalMediaModel(
      id: json['id'] as String,
      url: json['url'] as String,
      type: JournalMediaType.values.byName(json['type'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'url': url, 'type': type.name};
  }
}
