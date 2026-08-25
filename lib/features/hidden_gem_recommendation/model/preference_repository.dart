import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'travel_preference_profile.dart';
import 'travel_style.dart';

const _cachedCategoriesKey = 'travel_style_preferences';

/// Persists the tourist's travel preference profile (FR1.1) to
/// `user_travel_preferences` in Supabase — RLS-scoped to the signed-in
/// user, satisfying NFR4.1. A SharedPreferences copy of just the category
/// selection is kept as a best-effort offline read fallback (the same
/// mechanism the original local-only version of this repository used) so a
/// returning tourist without a network connection still sees their last
/// known choices instead of an empty screen.
class PreferenceRepository {
  PreferenceRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Null means "no profile saved yet" (new tourist) as distinct from an
  /// empty-but-saved profile — callers that care about first-launch vs.
  /// deliberately-cleared preferences can tell the two apart.
  Future<TravelPreferenceProfile?> load() async {
    final userId = _userId;
    if (userId == null) return null;

    try {
      final row = await _client
          .from('user_travel_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      final profile = TravelPreferenceProfile.fromRow(row);
      await _cacheCategories(profile.categories);
      return profile;
    } catch (_) {
      final cached = await _cachedCategories();
      return cached.isEmpty ? null : TravelPreferenceProfile(categories: cached);
    }
  }

  Future<void> save(TravelPreferenceProfile profile) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Cannot save travel preferences: no signed-in tourist.');
    }
    await _client.from('user_travel_preferences').upsert(profile.toRow(userId));
    await _cacheCategories(profile.categories);
  }

  Future<Set<TravelStyle>> _cachedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_cachedCategoriesKey) ?? const [];
    return stored.map(travelStyleFromKey).whereType<TravelStyle>().toSet();
  }

  Future<void> _cacheCategories(Set<TravelStyle> styles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cachedCategoriesKey, styles.map((s) => s.name).toList());
  }
}
