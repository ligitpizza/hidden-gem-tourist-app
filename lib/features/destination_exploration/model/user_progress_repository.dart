import 'package:supabase_flutter/supabase_flutter.dart';

/// A minimal points/badge hook for the rating-submission flow only — not
/// the broader gamification_journal system (see the design spec's
/// Decisions). One badge type ('pathfinder'), unlocked once per region.
class UserProgressRepository {
  String get _userId {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw const AuthException('A signed-in user is required.');
    return user.id;
  }

  Future<int> awardPoints(int amount) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('user_trail_points')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    final newTotal = ((existing?['total_points'] as num?)?.toInt() ?? 0) + amount;
    await client.from('user_trail_points').upsert({
      'user_id': _userId,
      'total_points': newTotal,
    });
    return newTotal;
  }

  Future<bool> awardPathfinderBadgeIfNew(String region) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('user_badges')
        .select()
        .eq('user_id', _userId)
        .eq('badge_id', 'pathfinder')
        .eq('region', region)
        .maybeSingle();

    if (existing != null) return false;

    await client.from('user_badges').insert({
      'user_id': _userId,
      'badge_id': 'pathfinder',
      'region': region,
    });
    return true;
  }
}
