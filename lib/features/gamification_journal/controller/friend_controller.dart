import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/friend_model.dart';
import '../services/mock/mock_friend_service.dart';

/// One accepted friend, joined with their profile and (if loaded) the
/// most recent thing they've done — what FriendsListScreen renders per row.
class FriendEntry {
  final ProfileModel profile;
  final String friendshipId;
  final FriendActivitySummary? activity;

  FriendEntry({required this.profile, required this.friendshipId, this.activity});

  FriendEntry copyWith({FriendActivitySummary? activity}) => FriendEntry(
    profile: profile,
    friendshipId: friendshipId,
    activity: activity ?? this.activity,
  );
}

/// A pending request, joined with the other party's profile — used for
/// both the incoming and outgoing lists.
class FriendRequestEntry {
  final ProfileModel profile;
  final String friendshipId;

  FriendRequestEntry({required this.profile, required this.friendshipId});
}

class FriendController extends ChangeNotifier {
  FriendController({required this.userId, MockFriendService? service})
    : _service = service ?? MockFriendService();

  final String userId;
  final MockFriendService _service;

  List<FriendshipModel> _friendships = [];
  List<FriendEntry> friends = [];
  List<FriendRequestEntry> incomingRequests = [];
  List<FriendRequestEntry> outgoingRequests = [];
  List<ProfileModel> searchResults = [];
  bool isLoading = false;
  bool isSearching = false;

  int get pendingIncomingCount => incomingRequests.length;

  Future<void> loadFriends() async {
    isLoading = true;
    notifyListeners();

    _friendships = await _service.fetchFriendships(userId);

    final accepted = _friendships.where((f) => f.status == FriendshipStatus.accepted).toList();
    final incoming = _friendships
        .where((f) => f.status == FriendshipStatus.pending && f.addresseeId == userId)
        .toList();
    final outgoing = _friendships
        .where((f) => f.status == FriendshipStatus.pending && f.requesterId == userId)
        .toList();

    final otherIds = _friendships.map((f) => f.otherUserId(userId)).toSet().toList();
    final profilesById = {
      for (final p in await _service.fetchProfiles(otherIds)) p.id: p,
    };

    friends = [
      for (final f in accepted)
        if (profilesById[f.otherUserId(userId)] case final profile?)
          FriendEntry(profile: profile, friendshipId: f.id),
    ];
    incomingRequests = [
      for (final f in incoming)
        if (profilesById[f.otherUserId(userId)] case final profile?)
          FriendRequestEntry(profile: profile, friendshipId: f.id),
    ];
    outgoingRequests = [
      for (final f in outgoing)
        if (profilesById[f.otherUserId(userId)] case final profile?)
          FriendRequestEntry(profile: profile, friendshipId: f.id),
    ];

    isLoading = false;
    notifyListeners();

    unawaited(_loadActivity());
  }

  /// Fetched separately (and not awaited by loadFriends) so the friend
  /// list itself renders immediately — each row's activity line fills in
  /// as its own query resolves rather than blocking the whole screen.
  Future<void> _loadActivity() async {
    for (final entry in List.of(friends)) {
      final activity = await _service.fetchRecentActivity(entry.profile.id);
      final index = friends.indexWhere((f) => f.friendshipId == entry.friendshipId);
      if (index == -1) continue;
      friends[index] = friends[index].copyWith(activity: activity);
      notifyListeners();
    }
  }

  Future<void> searchByName(String query) async {
    isSearching = true;
    notifyListeners();
    searchResults = await _service.searchByName(query, excludeUserId: userId);
    isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    searchResults = [];
    notifyListeners();
  }

  /// Null = not friends and no pending request either way — the caller
  /// shows an "Add" button. Otherwise reflects whichever relationship
  /// already exists, so a search result never offers to send a second
  /// request.
  FriendshipModel? relationshipWith(String otherUserId) {
    for (final f in _friendships) {
      if (f.requesterId == otherUserId || f.addresseeId == otherUserId) return f;
    }
    return null;
  }

  Future<void> sendRequest(String toUserId) async {
    await _service.sendRequest(fromUserId: userId, toUserId: toUserId);
    await loadFriends();
  }

  Future<void> acceptRequest(String friendshipId) async {
    await _service.acceptRequest(friendshipId);
    await loadFriends();
  }

  Future<void> declineRequest(String friendshipId) async {
    await _service.removeFriendship(friendshipId);
    await loadFriends();
  }

  Future<void> removeFriend(String friendshipId) async {
    await _service.removeFriendship(friendshipId);
    await loadFriends();
  }
}
