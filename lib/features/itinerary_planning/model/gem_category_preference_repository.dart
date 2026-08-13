import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/hidden_gem.dart';

const _prefsKey = 'itinerary_gem_category_preferences';

/// Persists which [HiddenGemCategory]s the traveller cares about for hidden
/// gems inserted into a generated route — the "Interested Hidden Gem
/// Categories" filter. Real, persisted (SharedPreferences), and shared
/// between Profile (where it's set) and Plan Your Route (where it's used
/// and can also still be edited) so both stay in sync.
class GemCategoryPreferenceRepository {
  Future<Set<HiddenGemCategory>> loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const [];
    final result = <HiddenGemCategory>{};
    for (final key in stored) {
      for (final category in HiddenGemCategory.values) {
        if (category.name == key) {
          result.add(category);
          break;
        }
      }
    }
    return result;
  }

  Future<void> saveSelected(Set<HiddenGemCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, categories.map((c) => c.name).toList());
  }
}
