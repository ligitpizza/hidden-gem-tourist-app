import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/destination.dart';
import '../../../shared/models/travel_mode.dart';
import '../model/itinerary_plan.dart';
import '../model/itinerary_repository.dart';
import '../model/itinerary_stop.dart';
import '../model/route_path.dart';
import '../model/saved_itineraries_store.dart';
import '../model/saved_itinerary.dart';
import '../model/visit_duration_option.dart';
import 'gem_category_preference_controller.dart';

/// Business logic for Smart Itinerary Planning (Module 3), shared across the
/// Plan Your Route / Route Optimized / Day Trip screens via
/// [itineraryPlannerControllerProvider] so state survives navigation between
/// them. Kept as a plain [ChangeNotifier] per the module's MVC convention.
class ItineraryPlannerController extends ChangeNotifier {
  ItineraryPlannerController({
    ItineraryRepository? repository,
    required GemCategoryPreferenceController gemCategoryPreference,
  })  : _repository = repository ?? ItineraryRepository(),
        _gemCategoryPreference = gemCategoryPreference {
    // "Interested Hidden Gem Categories" is a single shared preference (also
    // editable from Profile) — react to changes made there so the gem
    // preview count on this screen stays live regardless of where the
    // traveller last edited it.
    _gemCategoryPreference.addListener(_onGemCategoryPreferenceChanged);
  }

  final ItineraryRepository _repository;
  final GemCategoryPreferenceController _gemCategoryPreference;

  void _onGemCategoryPreferenceChanged() {
    unawaited(_refreshGemPreview());
  }

  String searchQuery = '';
  List<Destination> searchResults = const [];
  bool isSearching = false;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  final List<Destination> selectedDestinations = [];

  bool allocateDuration = true;
  VisitDurationOption selectedDurationOption = VisitDurationOption.oneDay;
  int customDays = 2;

  Set<DestinationCategory> get selectedGemCategories => _gemCategoryPreference.selected;

  bool isGenerating = false;
  ItineraryPlan? plan;

  TravelMode selectedTravelMode = TravelMode.driving;
  String selectedPathId = 'A';
  bool isSaved = false;
  bool isSaving = false;
  String? saveError;

  /// Set by [loadSavedItinerary] — while non-null, [saveToAccount] updates
  /// that existing saved record in place instead of inserting a new one, so
  /// an Edit → regenerate → Save cycle replaces the original rather than
  /// duplicating it. Cleared when the traveller clears every destination
  /// (the clearest signal they're starting a genuinely new itinerary).
  String? _editingSavedItineraryId;

  bool get canGenerate => selectedDestinations.length >= 2;

  int previewGemCount = 0;
  bool isLoadingGemPreview = false;
  int _gemPreviewRequestId = 0;

  Future<void> _refreshGemPreview() async {
    final requestId = ++_gemPreviewRequestId;
    if (selectedDestinations.isEmpty) {
      previewGemCount = 0;
      isLoadingGemPreview = false;
      notifyListeners();
      return;
    }

    isLoadingGemPreview = true;
    notifyListeners();

    final gems = await _repository.gemsNearDestinations(
      selectedDestinations,
      categories: selectedGemCategories,
    );
    if (requestId != _gemPreviewRequestId) return; // superseded by a newer selection change
    previewGemCount = gems.length;
    isLoadingGemPreview = false;
    notifyListeners();
  }

  RoutePath? get selectedRoutePath => plan?.pathById(selectedPathId);

  bool get isPlanFeasible => plan?.isFeasible ?? true;
  String? get feasibilityMessage => plan?.feasibilityMessage;

  List<ItineraryStop> get timeline => plan?.timeline ?? const [];

  String? get otherPathId {
    final currentPlan = plan;
    if (currentPlan == null) return null;
    return selectedPathId == currentPlan.primaryPath.id
        ? currentPlan.alternatePath.id
        : currentPlan.primaryPath.id;
  }

  void updateSearchQuery(String query) {
    searchQuery = query;
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      isSearching = false;
      searchResults = const [];
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    final requestId = ++_searchRequestId;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await _repository.search(query);
      if (requestId != _searchRequestId) return; // superseded by a newer keystroke
      searchResults = results;
      isSearching = false;
      notifyListeners();
    });
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    searchQuery = '';
    searchResults = const [];
    isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _gemCategoryPreference.removeListener(_onGemCategoryPreferenceChanged);
    super.dispose();
  }

  void addDestination(Destination destination) {
    if (selectedDestinations.any((d) => d.id == destination.id)) return;
    selectedDestinations.add(destination);
    searchQuery = '';
    searchResults = const [];
    notifyListeners();
    unawaited(_refreshGemPreview());
  }

  void removeDestination(String id) {
    selectedDestinations.removeWhere((d) => d.id == id);
    if (selectedDestinations.isEmpty) _editingSavedItineraryId = null;
    notifyListeners();
    unawaited(_refreshGemPreview());
  }

  void setAllocateDuration(bool value) {
    allocateDuration = value;
    notifyListeners();
  }

  void setDurationOption(VisitDurationOption option) {
    selectedDurationOption = option;
    notifyListeners();
  }

  void setCustomDays(int days) {
    customDays = days.clamp(1, 60);
    notifyListeners();
  }

  Future<void> generateItinerary() async {
    if (!canGenerate || isGenerating) return;
    isGenerating = true;
    notifyListeners();

    plan = await _repository.generate(
      destinations: List.unmodifiable(selectedDestinations),
      durationOption: allocateDuration ? selectedDurationOption : null,
      customDays: customDays,
      gemCategories: Set.unmodifiable(selectedGemCategories),
    );
    selectedPathId = plan!.primaryPath.id;
    selectedTravelMode = TravelMode.driving;
    isSaved = false;
    isGenerating = false;
    notifyListeners();
  }

  /// Loads a previously-saved plan straight into the controller — no
  /// regeneration, no network call — so Route Optimized/Day Trip can
  /// display it as-is (View), or Plan Your Route can be reopened with its
  /// destinations pre-filled, ready to change and regenerate (Edit).
  void loadSavedItinerary(SavedItinerary saved) {
    selectedDestinations
      ..clear()
      ..addAll(saved.plan.destinations);
    plan = saved.plan;
    selectedPathId = saved.plan.primaryPath.id;
    selectedTravelMode = TravelMode.driving;
    isSaved = true; // it came from the store, so it's already saved
    saveError = null;
    _editingSavedItineraryId = saved.id;
    notifyListeners();
    unawaited(_refreshGemPreview());
  }

  void selectPath(String id) {
    if (selectedPathId == id) return;
    selectedPathId = id;
    notifyListeners();
  }

  void selectTravelMode(TravelMode mode) {
    if (selectedTravelMode == mode) return;
    selectedTravelMode = mode;
    notifyListeners();
  }

  Future<void> saveToAccount() async {
    final currentPlan = plan;
    if (currentPlan == null || isSaving) return;
    isSaving = true;
    saveError = null;
    notifyListeners();
    try {
      final editingId = _editingSavedItineraryId;
      final saved = editingId != null
          ? await SavedItinerariesStore.instance.update(editingId, currentPlan)
          : await SavedItinerariesStore.instance.save(currentPlan);
      // Track the id either way — a second tap of "Save to Account" on the
      // same plan (fresh or edited) should update it too, not duplicate it.
      _editingSavedItineraryId = saved.id;
      isSaved = true;
    } catch (_) {
      saveError = 'Could not save this itinerary. Check your connection and try again.';
    }
    isSaving = false;
    notifyListeners();
  }

  String buildShareSummary() {
    final currentPlan = plan;
    if (currentPlan == null) return '';
    final path = selectedRoutePath;
    final metrics = path?.metricsFor(selectedTravelMode);
    final stops = currentPlan.destinations.map((d) => d.name).join(' -> ');

    final buffer = StringBuffer()
      ..writeln('My itinerary: $stops')
      ..writeln('Mode: ${selectedTravelMode.label}');
    if (metrics != null) {
      buffer.writeln(
        '${metrics.formattedDistance} | ${metrics.formattedDuration} | ${metrics.formattedCost}',
      );
    }
    if (path != null && path.hiddenGems.isNotEmpty) {
      buffer.writeln('Hidden gems: ${path.hiddenGems.map((g) => g.name).join(', ')}');
    }
    return buffer.toString();
  }
}

final itineraryPlannerControllerProvider =
    ChangeNotifierProvider<ItineraryPlannerController>((ref) {
  // `ref.read` (not `.watch`) — this provider must not rebuild (and lose
  // in-progress planning state) just because the shared category
  // preference changed; the controller listens to it directly instead.
  final gemCategoryPreference = ref.read(gemCategoryPreferenceControllerProvider);
  return ItineraryPlannerController(gemCategoryPreference: gemCategoryPreference);
});
