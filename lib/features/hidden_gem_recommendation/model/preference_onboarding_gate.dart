import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'preference_repository.dart';

/// Tracks, per signed-in tourist, whether the mandatory "Define Your
/// Travel Style" setup (Preference Selection And Preference Update
/// activity diagram) has been completed — read by the router's `redirect`
/// to bounce a freshly-registered tourist there before they reach the
/// shell, the same way [AuthRepository]'s `isLoggedIn` gates the shell on
/// sign-in state.
///
/// go_router's `redirect` must answer synchronously on every navigation,
/// so this caches the answer per user id instead of awaiting Supabase on
/// each check; [refresh] is fire-and-forget from the router and just
/// notifies listeners (which re-runs `redirect`) once the real answer is
/// known.
class PreferenceOnboardingGate extends ChangeNotifier {
  PreferenceOnboardingGate({PreferenceRepository? repository, SupabaseClient? client})
      : _repository = repository ?? PreferenceRepository(),
        _client = client ?? Supabase.instance.client;

  final PreferenceRepository _repository;
  final SupabaseClient _client;

  bool _needsSetup = false;
  String? _checkedForUserId;

  bool get needsSetup => _needsSetup;

  Future<void> refresh() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _checkedForUserId = null;
      if (_needsSetup) {
        _needsSetup = false;
        notifyListeners();
      }
      return;
    }
    if (_checkedForUserId == userId) return; // already resolved this session

    final profile = await _repository.load();
    final needsSetup = profile == null || !profile.hasAnyPreference;
    _checkedForUserId = userId;
    if (needsSetup != _needsSetup) {
      _needsSetup = needsSetup;
      notifyListeners();
    }
  }

  /// Called by the setup screen right after a successful save, so the
  /// router stops redirecting there without waiting on another round trip.
  void markCompleted() {
    if (!_needsSetup) return;
    _needsSetup = false;
    notifyListeners();
  }
}

/// App-lifetime singleton (not autoDispose) — the router holds a
/// `refreshListenable` reference to this for as long as the app runs, so
/// it must not get torn down between screen visits the way an
/// autoDispose-scoped controller would.
final preferenceOnboardingGateProvider = ChangeNotifierProvider<PreferenceOnboardingGate>((ref) {
  return PreferenceOnboardingGate();
});
