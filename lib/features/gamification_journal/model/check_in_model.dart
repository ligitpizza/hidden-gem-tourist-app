class CheckInModel {
  final String id;
  final String userId;
  final String destinationId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final bool isHidden;

  CheckInModel({
    required this.id,
    required this.userId,
    required this.destinationId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    this.isHidden = false,
  });

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    return CheckInModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      destinationId: json['destination_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      photoUrl: json['photo_url'] as String?,
      isHidden: json['is_hidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'destination_id': destinationId,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
      'is_hidden': isHidden,
    };
  }

  CheckInModel copyWith({bool? isHidden, String? photoUrl}) {
    return CheckInModel(
      id: id,
      userId: userId,
      destinationId: destinationId,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl ?? this.photoUrl,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}
