import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

/// App-wide light/dark/system theme preference, persisted across restarts.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController() {
    _load();
  }

  ThemeMode themeMode = ThemeMode.system;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    themeMode = _fromKey(stored);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _toKey(mode));
  }

  String _toKey(ThemeMode mode) => mode.name;

  ThemeMode _fromKey(String? key) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == key,
      orElse: () => ThemeMode.system,
    );
  }
}

final themeModeControllerProvider = ChangeNotifierProvider<ThemeModeController>((ref) {
  return ThemeModeController();
});
