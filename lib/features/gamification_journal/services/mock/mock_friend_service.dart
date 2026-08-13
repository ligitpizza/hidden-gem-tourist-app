import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/friend_model.dart';

/// Backs the Friends feature against the real `profiles`/`friendships`
/// tables (see
/// supabase/migrations/20260813120000_journal_real_activity_and_friends.sql).
/// Unlike the module's other services, this one was never mock — there's
/// no offline/test-seed switch here because Friends has no widget/
/// integration test coverage yet.
class MockFriendService {
  Future<List<ProfileModel>> searchByName(String query, {required String excludeUserId}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final rows = await Supabase.instance.client
        .from('profiles')
        .select()
        .ilike('full_name', '%$trimmed%')
        .neq('id', excludeUserId)
        .limit(20);
    return rows.map((r) => ProfileModel.fromJson(r)).toList();
  }

  Future<List<ProfileModel>> fetchProfiles(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await Supabase.instance.client
        .from('profiles')
        .select()
        .inFilter('id', ids);
    return rows.map((r) => ProfileModel.fromJson(r)).toList();
  }

  /// Every friendship row (any status) involving [userId], in either
  /// direction — the controller sorts these into friends/incoming/outgoing.
  Future<List<FriendshipModel>> fetchFriendships(String userId) async {
    final rows = await Supabase.instance.client
        .from('friendships')
        .select()
        .or('requester_id.eq.$userId,addressee_id.eq.$userId');
    return rows.map((r) => FriendshipModel.fromJson(r)).toList();
  }

  Future<void> sendRequest({required String fromUserId, required String toUserId}) async {
    await Supabase.instance.client.from('friendships').insert({
      'requester_id': fromUserId,
      'addressee_id': toUserId,
    });
  }

  Future<void> acceptRequest(String friendshipId) async {
    await Supabase.instance.client
        .from('friendships')
        .update({'status': 'accepted', 'responded_at': DateTime.now().toIso8601String()})
        .eq('id', friendshipId);
  }

  /// Used for both declining an incoming request and cancelling an
  /// outgoing one, and for unfriending — all three are just "remove this
  /// row" from either party's side.
  Future<void> removeFriendship(String friendshipId) async {
    await Supabase.instance.client.from('friendships').delete().eq('id', friendshipId);
  }

  /// The single most recent thing [friendUserId] has done — an unlocked
  /// badge or a check-in, whichever is more recent. Both queries rely on
  /// the "Friends view non-hidden ..." RLS policies, so this naturally
  /// returns nothing for a non-friend or for hidden activity.
  Future<FriendActivitySummary?> fetchRecentActivity(String friendUserId) async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client
          .from('journal_user_badges')
          .select('badge_id, earned_at')
          .eq('user_id', friendUserId)
          .order('earned_at', ascending: false)
          .limit(1),
      client
          .from('journal_check_ins')
          .select('destination_id, timestamp')
          .eq('user_id', friendUserId)
          .order('timestamp', ascending: false)
          .limit(1),
    ]);

    final badgeRows = results[0];
    final checkInRows = results[1];

    final badgeAt = badgeRows.isEmpty ? null : DateTime.parse(badgeRows.first['earned_at'] as String);
    final checkInAt =
        checkInRows.isEmpty ? null : DateTime.parse(checkInRows.first['timestamp'] as String);

    if (badgeAt == null && checkInAt == null) return null;
    if (badgeAt != null && (checkInAt == null || badgeAt.isAfter(checkInAt))) {
      return FriendActivitySummary(badgeId: badgeRows.first['badge_id'] as String, at: badgeAt);
    }
    return FriendActivitySummary(
      destinationId: checkInRows.first['destination_id'] as String,
      at: checkInAt!,
    );
  }
}
