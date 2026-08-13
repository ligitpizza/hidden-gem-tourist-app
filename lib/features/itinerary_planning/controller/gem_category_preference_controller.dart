import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hidden_gem.dart';
import '../model/gem_category_preference_repository.dart';

/// Single source of truth for "Interested Hidden Gem Categories" — a real
/// singleton (via Riverpod), not per-screen state, so editing it from
/// Profile or Plan Your Route updates both live and persists across
/// restarts.
class GemCategoryPreferenceController extends ChangeNotifier {
  GemCategoryPreferenceController({GemCategoryPreferenceRepository? repository})
      : _repository = repository ?? GemCategoryPreferenceRepository() {
    _load();
  }

  final GemCategoryPreferenceRepository _repository;

  bool isLoading = true;
  final Set<HiddenGemCategory> selected = {};

  Future<void> _load() async {
    final stored = await _repository.loadSelected();
    selected
      ..clear()
      ..addAll(stored);
    isLoading = false;
    notifyListeners();
  }

  void toggle(HiddenGemCategory category) {
    if (!selected.remove(category)) {
      selected.add(category);
    }
    notifyListeners();
    unawaited(_repository.saveSelected(selected));
  }
}

final gemCategoryPreferenceControllerProvider =
    ChangeNotifierProvider<GemCategoryPreferenceController>((ref) {
  return GemCategoryPreferenceController();
});
