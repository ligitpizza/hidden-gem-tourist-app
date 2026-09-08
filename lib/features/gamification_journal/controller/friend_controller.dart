import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/check_in_model.dart';
import '../model/destination_model.dart';
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

/// Which stat the Leaderboard tab is currently ranking by.
enum LeaderboardMetric {
  checkIns('Check-ins'),
  badges('Badges'),
  states('States');

  const LeaderboardMetric(this.label);
  final String label;
}

/// One row on the friend leaderboard — the current user plus every
/// accepted friend, each with the same three counts so any of them can be
/// used to sort/rank.
class LeaderboardEntry {
  final ProfileModel profile;
  final bool isCurrentUser;
  final int checkInCount;
  final int badgeCount;
  final int statesExplored;

  LeaderboardEntry({
    required this.profile,
    required this.isCurrentUser,
    required this.checkInCount,
    required this.badgeCount,
    required this.statesExplored,
  });

  int valueFor(LeaderboardMetric metric) => switch (metric) {
    LeaderboardMetric.checkIns => checkInCount,
    LeaderboardMetric.badges => badgeCount,
    LeaderboardMetric.states => statesExplored,
  };
}

/// One row in the combined Activity tab — a check-in or a badge unlock by
/// the current user or any of their friends, merged into a single
/// chronological feed instead of just the single latest-per-friend line
/// the Friends tab shows.
class ActivityFeedEntry {
  final ProfileModel profile;
  final bool isCurrentUser;
  final DateTime at;

  /// Only set for a check-in entry — the row id reactions attach to.
  /// Badge entries have no reaction target yet (see the reactions
  /// migration's doc comment for why).
  final String? checkInId;
  final String? destinationId;
  final String? badgeId;

  ActivityFeedEntry.checkIn({
    required this.profile,
    required this.isCurrentUser,
    required this.at,
    required String this.checkInId,
    required String this.destinationId,
  }) : badgeId = null;

  ActivityFeedEntry.badge({
    required this.profile,
    required this.isCurrentUser,
    required this.at,
    required String this.badgeId,
  }) : checkInId = null,
       destinationId = null;
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
  List<LeaderboardEntry> leaderboard = [];
  List<ActivityFeedEntry> activityFeed = [];

  /// Reaction count per check-in id, and which of those the current user
  /// has personally reacted to — both keyed by checkInId, populated by
  /// loadReactions() for whatever check-ins are currently on screen.
  Map<String, int> reactionCounts = {};
  Set<String> myReactedCheckInIds = {};

  bool isLoading = false;
  bool isSearching = false;
  bool isLoadingLeaderboard = false;
  bool isLoadingActivityFeed = false;

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

  /// Ranks the current user against their accepted friends. Call after
  /// loadFriends() so `friends` is up to date. [destinationsById] resolves
  /// each check-in's state for the "states explored" metric — passed in
  /// rather than fetched here since CheckInController already loads it.
  Future<void> loadLeaderboard(Map<String, DestinationModel> destinationsById) async {
    isLoadingLeaderboard = true;
    notifyListeners();

    try {
      final ids = [userId, for (final f in friends) f.profile.id];
      final results = await Future.wait([
        _service.fetchProfiles(ids),
        _service.fetchCheckInsForUsers(ids),
        _service.fetchBadgesForUsers(ids),
      ]);
      final profilesById = {
        for (final p in results[0] as List<ProfileModel>) p.id: p,
      };
      final checkIns = results[1] as List<CheckInModel>;
      final badges = results[2] as List<UserBadgeModel>;

      leaderboard = [
        for (final id in ids)
          if (profilesById[id] case final profile?)
            LeaderboardEntry(
              profile: profile,
              isCurrentUser: id == userId,
              checkInCount: checkIns.where((c) => c.userId == id).length,
              badgeCount: badges.where((b) => b.userId == id).length,
              statesExplored: checkIns
                  .where((c) => c.userId == id)
                  .map((c) => destinationsById[c.destinationId]?.state)
                  .whereType<String>()
                  .toSet()
                  .length,
            ),
      ];
    } catch (e) {
      debugPrint('FriendController.loadLeaderboard failed: $e');
    }

    isLoadingLeaderboard = false;
    notifyListeners();
  }

  /// Merges the current user's and every friend's check-ins and badge
  /// unlocks into one chronological feed — call after loadFriends() so
  /// `friends` is up to date. Kept as its own fetch rather than reusing
  /// loadLeaderboard's data so either tab can refresh independently.
  Future<void> loadActivityFeed() async {
    isLoadingActivityFeed = true;
    notifyListeners();

    try {
      final ids = [userId, for (final f in friends) f.profile.id];
      final results = await Future.wait([
        _service.fetchProfiles(ids),
        _service.fetchCheckInsForUsers(ids),
        _service.fetchBadgesForUsers(ids),
      ]);
      final profilesById = {
        for (final p in results[0] as List<ProfileModel>) p.id: p,
      };
      final checkIns = results[1] as List<CheckInModel>;
      final badges = results[2] as List<UserBadgeModel>;

      final entries = <ActivityFeedEntry>[
        for (final c in checkIns)
          if (profilesById[c.userId] case final profile?)
            ActivityFeedEntry.checkIn(
              profile: profile,
              isCurrentUser: c.userId == userId,
              at: c.timestamp,
              checkInId: c.id,
              destinationId: c.destinationId,
            ),
        for (final b in badges)
          if (profilesById[b.userId] case final profile?)
            ActivityFeedEntry.badge(
              profile: profile,
              isCurrentUser: b.userId == userId,
              at: b.earnedAt,
              badgeId: b.badgeId,
            ),
      ]..sort((a, b) => b.at.compareTo(a.at));

      activityFeed = entries.take(50).toList();
      unawaited(loadReactions(activityFeed.map((e) => e.checkInId).nonNulls.toList()));
    } catch (e) {
      debugPrint('FriendController.loadActivityFeed failed: $e');
    }

    isLoadingActivityFeed = false;
    notifyListeners();
  }

  /// Populates reactionCounts/myReactedCheckInIds for [checkInIds] — call
  /// with whatever check-ins are currently on screen (the activity feed
  /// does this itself after loading).
  Future<void> loadReactions(List<String> checkInIds) async {
    if (checkInIds.isEmpty) return;
    try {
      final rows = await _service.fetchReactionsForCheckIns(checkInIds);
      final counts = <String, int>{};
      final mine = <String>{};
      for (final r in rows) {
        counts[r.checkInId] = (counts[r.checkInId] ?? 0) + 1;
        if (r.reactorId == userId) mine.add(r.checkInId);
      }
      reactionCounts = counts;
      myReactedCheckInIds = mine;
      notifyListeners();
    } catch (e) {
      debugPrint('FriendController.loadReactions failed: $e');
    }
  }

  /// Optimistically flips this check-in's reaction so the tap feels
  /// instant, then rolls back if the request actually fails.
  Future<void> toggleReaction(String checkInId) async {
    final alreadyReacted = myReactedCheckInIds.contains(checkInId);
    _applyReactionDelta(checkInId, reacted: !alreadyReacted);
    notifyListeners();

    try {
      if (alreadyReacted) {
        await _service.removeReaction(checkInId);
      } else {
        await _service.addReaction(checkInId);
      }
    } catch (e) {
      _applyReactionDelta(checkInId, reacted: alreadyReacted);
      errorMessage = 'Could not update your reaction. Please try again.';
      notifyListeners();
      debugPrint('FriendController.toggleReaction failed: $e');
    }
  }

  void _applyReactionDelta(String checkInId, {required bool reacted}) {
    final current = reactionCounts[checkInId] ?? 0;
    if (reacted) {
      myReactedCheckInIds.add(checkInId);
      reactionCounts[checkInId] = current + 1;
    } else {
      myReactedCheckInIds.remove(checkInId);
      reactionCounts[checkInId] = current > 0 ? current - 1 : 0;
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
