import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/destination.dart';

const _prefsKey = 'itinerary_gem_category_preferences_v2';

/// Persists which specific [DestinationCategory]s the traveller cares about
/// for hidden gems inserted into a generated route — the "Interested Hidden
/// Gem Categories" filter. Real, persisted (SharedPreferences), and shared
/// between Profile (where it's set) and Plan Your Route (where it's used
/// and can also still be edited) so both stay in sync.
class GemCategoryPreferenceRepository {
  Future<Set<DestinationCategory>> loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const [];
    final result = <DestinationCategory>{};
    for (final key in stored) {
      for (final category in DestinationCategory.values) {
        if (category.name == key) {
          result.add(category);
          break;
        }
      }
    }
    return result;
  }

  Future<void> saveSelected(Set<DestinationCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, categories.map((c) => c.name).toList());
  }
}
