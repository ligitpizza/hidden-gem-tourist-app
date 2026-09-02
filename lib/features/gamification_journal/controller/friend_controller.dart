import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/check_in_model.dart';
import '../model/friend_model.dart';
import '../model/user_badge_model.dart';
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

  /// Surfaces the last action's failure (send/accept/decline/remove/
  /// search) so the UI can show it instead of failing silently — set to
  /// null again the moment a new action starts.
  String? errorMessage;

  /// Fires the moment another Tourist sends this user a friend request —
  /// the app shell listens to this to pop the top banner regardless of
  /// which tab is currently open.
  final _incomingRequestController = StreamController<FriendRequestEntry>.broadcast();
  Stream<FriendRequestEntry> get incomingRequestEvents => _incomingRequestController.stream;
  bool _isListeningForIncomingRequests = false;

  /// Call once (e.g. at app start) — safe to call more than once, later
  /// calls are ignored so only one realtime subscription is ever open.
  void startListeningForIncomingRequests() {
    if (_isListeningForIncomingRequests) return;
    _isListeningForIncomingRequests = true;
    _service.subscribeToFriendshipChanges(
      userId: userId,
      onIncomingRequest: (friendshipId, requesterId) async {
        final profiles = await _service.fetchProfiles([requesterId]);
        if (profiles.isEmpty) return;
        _incomingRequestController.add(
          FriendRequestEntry(profile: profiles.first, friendshipId: friendshipId),
        );
      },
      // Covers every other change too (accepted, declined, unfriended,
      // from either side) so this device's Friends state stays live
      // without needing its own manual refresh.
      onAnyChange: () => loadFriends(),
    );
  }

  @override
  void dispose() {
    _service.unsubscribeFriendshipChanges();
    _incomingRequestController.close();
    super.dispose();
  }

  int get pendingIncomingCount => incomingRequests.length;

  /// True when at least one request *this user sent* was accepted and
  /// hasn't been seen yet — drives the "new friend" dot, separate from
  /// pendingIncomingCount (which is about requests waiting on *this
  /// user* to respond).
  bool get hasNewAcceptedFriends => _friendships.any(
    (f) =>
        f.requesterId == userId &&
        f.status == FriendshipStatus.accepted &&
        !f.requesterAcknowledged,
  );

  Future<void> loadFriends() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
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
    } catch (e) {
      errorMessage = 'Could not load friends. Please try again.';
      debugPrint('FriendController.loadFriends failed: $e');
    }

    isLoading = false;
    notifyListeners();

    unawaited(_loadActivity());
  }

  /// Fetched separately (and not awaited by loadFriends) so the friend
  /// list itself renders immediately — each row's activity line fills in
  /// as its own query resolves rather than blocking the whole screen.
  Future<void> _loadActivity() async {
    for (final entry in List.of(friends)) {
      try {
        final activity = await _service.fetchRecentActivity(entry.profile.id);
        final index = friends.indexWhere((f) => f.friendshipId == entry.friendshipId);
        if (index == -1) continue;
        friends[index] = friends[index].copyWith(activity: activity);
        notifyListeners();
      } catch (e) {
        // A single friend's activity failing to load shouldn't block the
        // rest of the list — that row just keeps showing "No activity yet".
        debugPrint('FriendController._loadActivity failed for ${entry.profile.id}: $e');
      }
    }
  }

  /// Marks the app's own "new friend" dot as seen — call when the Tourist
  /// opens the Friends list.
  Future<void> acknowledgeNewFriends() async {
    if (!hasNewAcceptedFriends) return;
    try {
      await _service.acknowledgeNewAcceptances(userId);
      for (var i = 0; i < _friendships.length; i++) {
        if (_friendships[i].requesterId == userId && !_friendships[i].requesterAcknowledged) {
          _friendships[i] = FriendshipModel(
            id: _friendships[i].id,
            requesterId: _friendships[i].requesterId,
            addresseeId: _friendships[i].addresseeId,
            status: _friendships[i].status,
            createdAt: _friendships[i].createdAt,
            requesterAcknowledged: true,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('FriendController.acknowledgeNewFriends failed: $e');
    }
  }

  Future<void> searchByName(String query) async {
    isSearching = true;
    errorMessage = null;
    notifyListeners();

    try {
      searchResults = await _service.searchByName(query, excludeUserId: userId);
    } catch (e) {
      searchResults = [];
      errorMessage = 'Search failed. Please try again.';
      debugPrint('FriendController.searchByName failed: $e');
    }

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

  /// Reads a friend or a preview target's public check-ins/badges —
  /// separate from this user's own data, so it doesn't touch `friends`
  /// or any other state here. Used by FriendProfilePreviewScreen.
  Future<(List<CheckInModel>, List<UserBadgeModel>)> fetchPublicActivity(String otherUserId) async {
    final results = await Future.wait([
      _service.fetchPublicCheckIns(otherUserId),
      _service.fetchPublicBadges(otherUserId),
    ]);
    return (results[0] as List<CheckInModel>, results[1] as List<UserBadgeModel>);
  }

  /// Returns true on success. On failure, sets [errorMessage] and returns
  /// false so the caller can show it instead of the action silently doing
  /// nothing.
  Future<bool> sendRequest(String toUserId) => _runAction(
    () => _service.sendRequest(fromUserId: userId, toUserId: toUserId),
    failureMessage: 'Could not send the friend request. Please try again.',
  );

  Future<bool> acceptRequest(String friendshipId) => _runAction(
    () => _service.acceptRequest(friendshipId),
    failureMessage: 'Could not accept the request. Please try again.',
  );

  Future<bool> declineRequest(String friendshipId) => _runAction(
    () => _service.removeFriendship(friendshipId),
    failureMessage: 'Could not decline the request. Please try again.',
  );

  Future<bool> removeFriend(String friendshipId) => _runAction(
    () => _service.removeFriendship(friendshipId),
    failureMessage: 'Could not remove this friend. Please try again.',
  );

  Future<bool> _runAction(Future<void> Function() action, {required String failureMessage}) async {
    errorMessage = null;
    try {
      await action();
      await loadFriends();
      return true;
    } catch (e) {
      errorMessage = failureMessage;
      debugPrint('FriendController action failed: $e');
      notifyListeners();
      return false;
    }
  }
}
