import 'dart:convert';

class TravelDocument {
  const TravelDocument({
    required this.id,
    required this.displayName,
    required this.category,
    required this.originalFileName,
    required this.storedPath,
    required this.extension,
    required this.fileSize,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String category;
  final String originalFileName;
  final String storedPath;
  final String extension;
  final int fileSize;
  final DateTime createdAt;

  bool get isPdf => extension.toLowerCase() == 'pdf';

  bool get isImage => const {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  }.contains(extension.toLowerCase());

  TravelDocument copyWith({String? displayName, String? category}) {
    return TravelDocument(
      id: id,
      displayName: displayName ?? this.displayName,
      category: category ?? this.category,
      originalFileName: originalFileName,
      storedPath: storedPath,
      extension: extension,
      fileSize: fileSize,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'category': category,
    'originalFileName': originalFileName,
    'storedPath': storedPath,
    'extension': extension,
    'fileSize': fileSize,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TravelDocument.fromJson(Map<String, dynamic> json) {
    return TravelDocument(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      category: json['category'] as String,
      originalFileName: json['originalFileName'] as String,
      storedPath: json['storedPath'] as String,
      extension: json['extension'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static String encodeList(List<TravelDocument> documents) {
    return jsonEncode(documents.map((document) => document.toJson()).toList());
  }

  static List<TravelDocument> decodeList(String? source) {
    if (source == null || source.isEmpty) return [];
    final values = jsonDecode(source) as List<dynamic>;
    return values
        .map((value) => TravelDocument.fromJson(value as Map<String, dynamic>))
        .toList();
  }
}
