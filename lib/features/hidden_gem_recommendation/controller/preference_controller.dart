import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/preference_onboarding_gate.dart';
import '../model/preference_repository.dart';
import '../model/travel_preference_profile.dart';
import '../model/travel_style.dart';

/// "Define Your Travel Style" / "Refresh Your Interests" (FR1.1). Enforces
/// the Preference Selection And Preference Update activity diagram's
/// 1–3 category cap and persists via [PreferenceRepository] to Supabase.
class PreferenceController extends ChangeNotifier {
  PreferenceController({
    PreferenceRepository? repository,
    PreferenceOnboardingGate? onboardingGate,
  })  : _repository = repository ?? PreferenceRepository(),
        _onboardingGate = onboardingGate {
    _load();
  }

  static const maxSelections = 3;

  final PreferenceRepository _repository;
  final PreferenceOnboardingGate? _onboardingGate;

  bool isLoading = true;
  bool isSaving = false;
  bool wasAlreadySet = false;
  String? errorMessage;

  final Set<TravelStyle> selected = {};
  BudgetRange? budgetRange;
  final Set<DestinationTypePreference> destinationTypes = {};
  int? intendedTravelMonth;

  bool get canSelectMore => selected.length < maxSelections;
  bool get canConfirm => selected.isNotEmpty && selected.length <= maxSelections;

  Future<void> _load() async {
    final profile = await _repository.load();
    if (profile != null) {
      selected
        ..clear()
        ..addAll(profile.categories);
      budgetRange = profile.budgetRange;
      destinationTypes
        ..clear()
        ..addAll(profile.destinationTypes);
      intendedTravelMonth = profile.intendedTravelMonth;
      wasAlreadySet = profile.hasAnyPreference;
    }
    isLoading = false;
    notifyListeners();
  }

  /// Returns false (without changing anything) if [style] wasn't already
  /// selected and the tourist has already picked [maxSelections] — the
  /// view surfaces that as a "max 3" hint rather than silently ignoring
  /// the tap.
  bool toggle(TravelStyle style) {
    if (selected.remove(style)) {
      notifyListeners();
      return true;
    }
    if (!canSelectMore) return false;
    selected.add(style);
    notifyListeners();
    return true;
  }

  void setBudgetRange(BudgetRange? range) {
    budgetRange = range;
    notifyListeners();
  }

  void toggleDestinationType(DestinationTypePreference type) {
    if (!destinationTypes.remove(type)) {
      destinationTypes.add(type);
    }
    notifyListeners();
  }

  /// Passing the same month again clears it back to "no preference" —
  /// matches how [setBudgetRange] already handles a re-tap.
  void setIntendedTravelMonth(int? month) {
    intendedTravelMonth = intendedTravelMonth == month ? null : month;
    notifyListeners();
  }

  Future<bool> save() async {
    if (!canConfirm) {
      errorMessage = 'Pick 1 to $maxSelections travel styles first.';
      notifyListeners();
      return false;
    }
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.save(
        TravelPreferenceProfile(
          categories: Set.of(selected),
          budgetRange: budgetRange,
          destinationTypes: Set.of(destinationTypes),
          onboardedAt: wasAlreadySet ? null : DateTime.now(),
          intendedTravelMonth: intendedTravelMonth,
        ),
      );
      wasAlreadySet = true;
      isSaving = false;
      notifyListeners();
      _onboardingGate?.markCompleted();
      return true;
    } catch (_) {
      errorMessage = "Couldn't save your preferences — check your connection and try again.";
      isSaving = false;
      notifyListeners();
      return false;
    }
  }
}

final preferenceControllerProvider = ChangeNotifierProvider.autoDispose<PreferenceController>((ref) {
  final onboardingGate = ref.watch(preferenceOnboardingGateProvider);
  return PreferenceController(onboardingGate: onboardingGate);
});
