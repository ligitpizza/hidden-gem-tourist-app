import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal, standalone check-in gate for Feature 4 — not the full
/// gamification_journal check-in experience (see the design spec's
/// Decisions). Scoped to the signed-in user, same pattern as
/// emergency_contact_repository.dart.
class CheckInRepository {
  String get _userId {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw const AuthException('A signed-in user is required.');
    return user.id;
  }

  Future<bool> isCheckedIn(String destinationId) async {
    final rows = await Supabase.instance.client
        .from('destination_checkins')
        .select()
        .eq('user_id', _userId)
        .eq('destination_id', destinationId);
    return rows.isNotEmpty;
  }

  /// Idempotent — checking in twice is a no-op, not an error.
  Future<void> checkIn(String destinationId) async {
    await Supabase.instance.client.from('destination_checkins').upsert({
      'user_id': _userId,
      'destination_id': destinationId,
    });
  }
}
