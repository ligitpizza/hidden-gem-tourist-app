/// A row from `public.profiles` — the searchable, public-read half of a
/// user's identity (their `auth.users` row itself isn't queryable from
/// the client).
class ProfileModel {
  final String id;
  final String fullName;

  ProfileModel({required this.id, required this.fullName});

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
    );
  }
}

enum FriendshipStatus { pending, accepted }

/// A row from `public.friendships` — one relationship, in either
/// direction. [requesterId] sent the request; [addresseeId] is the one
/// who accepts/declines it.
class FriendshipModel {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;

  /// False from the moment the addressee accepts until the requester
  /// opens the Friends list and sees it — drives the "new friend" red dot,
  /// same pattern as UserBadgeModel.acknowledged.
  final bool requesterAcknowledged;

  FriendshipModel({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.requesterAcknowledged = true,
  });

  /// The user id on the other side of this relationship, from [viewerId]'s
  /// point of view.
  String otherUserId(String viewerId) =>
      viewerId == requesterId ? addresseeId : requesterId;

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: (json['status'] as String) == 'accepted'
          ? FriendshipStatus.accepted
          : FriendshipStatus.pending,
      createdAt: DateTime.parse(json['created_at'] as String),
      requesterAcknowledged: json['requester_acknowledged'] as bool? ?? true,
    );
  }
}

/// The single most recent thing a friend has done — either an unlocked
/// badge or a check-in, whichever is more recent — resolved into the
/// "mini announcement" shown on FriendsListScreen. Name lookups (badge
/// name, destination name) happen in the view layer against catalogues
/// the app already has loaded, same as profile_screen.dart already does
/// for its own destination-name lookups.
class FriendActivitySummary {
  final String? badgeId;
  final String? destinationId;
  final DateTime at;

  const FriendActivitySummary({this.badgeId, this.destinationId, required this.at});

  bool get isBadge => badgeId != null;
}
