import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/preference_repository.dart';
import '../model/travel_style.dart';

class PreferenceController extends ChangeNotifier {
  PreferenceController({PreferenceRepository? repository})
      : _repository = repository ?? PreferenceRepository() {
    _load();
  }

  final PreferenceRepository _repository;

  bool isLoading = true;
  bool isSaving = false;
  final Set<TravelStyle> selected = {};

  Future<void> _load() async {
    final stored = await _repository.loadSelected();
    selected
      ..clear()
      ..addAll(stored);
    isLoading = false;
    notifyListeners();
  }

  void toggle(TravelStyle style) {
    if (!selected.remove(style)) {
      selected.add(style);
    }
    notifyListeners();
  }

  Future<void> save() async {
    isSaving = true;
    notifyListeners();
    await _repository.saveSelected(selected);
    isSaving = false;
    notifyListeners();
  }
}

final preferenceControllerProvider = ChangeNotifierProvider<PreferenceController>((ref) {
  return PreferenceController();
});
