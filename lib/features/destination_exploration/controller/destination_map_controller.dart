import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hidden_gem.dart';
import '../model/destination_exploration_repository.dart';
import '../model/map_destination.dart';

/// Business logic for the Interactive Destination Map. Kept as a plain
/// [ChangeNotifier] per the module's MVC convention (see
/// itinerary_planning's ItineraryPlannerController for the same pattern).
class DestinationMapController extends ChangeNotifier {
  DestinationMapController({DestinationExplorationRepository? repository})
      : _repository = repository ?? DestinationExplorationRepository() {
    loadDestinations();
  }

  final DestinationExplorationRepository _repository;

  List<MapDestination> destinations = const [];
  bool isLoading = false;
  bool hasError = false;
  final Set<HiddenGemCategory> selectedCategories = {};
  MapDestination? selectedDestination;

  List<MapDestination> get filteredDestinations {
    if (selectedCategories.isEmpty) return destinations;
    return destinations.where((d) => selectedCategories.contains(d.category)).toList();
  }

  Future<void> loadDestinations() async {
    isLoading = true;
    hasError = false;
    notifyListeners();

    try {
      destinations = await _repository.loadDestinations();
    } catch (_) {
      destinations = const [];
      hasError = true;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> retry() => loadDestinations();

  void toggleCategory(HiddenGemCategory category) {
    if (!selectedCategories.remove(category)) {
      selectedCategories.add(category);
    }
    notifyListeners();
  }

  void clearFilters() {
    if (selectedCategories.isEmpty) return;
    selectedCategories.clear();
    notifyListeners();
  }

  void selectDestination(String id) {
    try {
      selectedDestination = destinations.firstWhere((d) => d.id == id);
      notifyListeners();
    } catch (_) {
      // Unknown id, no-op
    }
  }

  void clearSelection() {
    selectedDestination = null;
    notifyListeners();
  }
}

final destinationMapControllerProvider =
    ChangeNotifierProvider<DestinationMapController>((ref) {
  return DestinationMapController();
});
