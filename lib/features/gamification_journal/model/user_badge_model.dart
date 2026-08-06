class UserBadgeModel {
  final String userId;
  final String badgeId;
  final DateTime earnedAt;
  final bool isHidden;

  UserBadgeModel({
    required this.userId,
    required this.badgeId,
    required this.earnedAt,
    this.isHidden = false,
  });

  factory UserBadgeModel.fromJson(Map<String, dynamic> json) {
    return UserBadgeModel(
      userId: json['user_id'] as String,
      badgeId: json['badge_id'] as String,
      earnedAt: DateTime.parse(json['earned_at'] as String),
      isHidden: json['is_hidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'badge_id': badgeId,
      'earned_at': earnedAt.toIso8601String(),
      'is_hidden': isHidden,
    };
  }

  UserBadgeModel copyWith({bool? isHidden}) {
    return UserBadgeModel(
      userId: userId,
      badgeId: badgeId,
      earnedAt: earnedAt,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}

/// Computed, not stored — drives the "3 of 5 spots visited" progress bar
/// for badges the user hasn't unlocked yet.
class BadgeProgressModel {
  final String badgeId;
  final int current;
  final int target;

  BadgeProgressModel({
    required this.badgeId,
    required this.current,
    required this.target,
  });

  bool get isComplete => current >= target;
  double get ratio => target == 0 ? 0 : (current / target).clamp(0, 1);
}
