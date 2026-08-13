import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';
import '../model/gem_category_preference_repository.dart';
import '../model/gem_category_groups.dart';

/// Single source of truth for "Interested Hidden Gem Categories" — a real
/// singleton (via Riverpod), not per-screen state, so editing it from
/// Profile or Plan Your Route updates both live and persists across
/// restarts.
///
/// [selected] holds specific [DestinationCategory] values (the 15 concrete
/// place types); the 5 broad [HiddenGemCategory] "vibe" groups (via
/// [gemCategoryGroups]) are a pure UI convenience for bulk-selecting their
/// members via [toggleGroup] — there's no separately-stored group state.
class GemCategoryPreferenceController extends ChangeNotifier {
  GemCategoryPreferenceController({GemCategoryPreferenceRepository? repository})
      : _repository = repository ?? GemCategoryPreferenceRepository() {
    _load();
  }

  final GemCategoryPreferenceRepository _repository;

  bool isLoading = true;
  final Set<DestinationCategory> selected = {};

  Future<void> _load() async {
    final stored = await _repository.loadSelected();
    selected
      ..clear()
      ..addAll(stored);
    isLoading = false;
    notifyListeners();
  }

  void toggle(DestinationCategory category) {
    if (!selected.remove(category)) {
      selected.add(category);
    }
    notifyListeners();
    unawaited(_repository.saveSelected(selected));
  }

  /// Selects every member of [group] if not all are already selected,
  /// otherwise deselects all of them — a bulk "select all / clear all" for
  /// that broad vibe.
  void toggleGroup(HiddenGemCategory group) {
    final members = gemCategoryGroups[group] ?? const [];
    final allSelected = members.every(selected.contains);
    if (allSelected) {
      selected.removeAll(members);
    } else {
      selected.addAll(members);
    }
    notifyListeners();
    unawaited(_repository.saveSelected(selected));
  }
}

final gemCategoryPreferenceControllerProvider =
    ChangeNotifierProvider<GemCategoryPreferenceController>((ref) {
  return GemCategoryPreferenceController();
});
