import 'package:shared_preferences/shared_preferences.dart';

import 'travel_style.dart';

const _prefsKey = 'travel_style_preferences';

/// Persists the traveller's selected [TravelStyle] categories. Real
/// persistence (not mocked) via SharedPreferences — the same mechanism
/// already used for the theme-mode preference.
///
/// This only covers the traveller's *manually chosen* interests (Module 1's
/// "Define Your Travel Style" / "Refresh Your Interests"). The behaviour-
/// driven auto-learning described in the team's "Smart Preference Learning"
/// spec (adjusting weights from views/saves/search history) needs an
/// interaction-tracking table that doesn't exist yet — this repository is
/// the foundation to build that on top of later.
class PreferenceRepository {
  Future<Set<TravelStyle>> loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const [];
    return stored.map(travelStyleFromKey).whereType<TravelStyle>().toSet();
  }

  Future<void> saveSelected(Set<TravelStyle> styles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, styles.map((s) => s.name).toList());
  }
}
