import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/destination.dart' as shared;
import '../../../shared/models/hidden_gem.dart';
import '../../itinerary_planning/controller/itinerary_planner_controller.dart';
import '../model/destination_exploration_repository.dart'
    show DestinationExplorationRepository, legDistanceKm, orderByNearestNeighbor;
import '../model/map_destination.dart';

/// The map's two display modes: normal browsing (tap for a brief popup,
/// double-tap for the full detail page) vs. comparison selection (tap
/// toggles a destination in/out of [DestinationMapController.selectedForComparison]).
enum MapViewMode { explore, comparison }

/// Business logic for the Interactive Destination Map. Kept as a plain
/// [ChangeNotifier] per the module's MVC convention (see
/// itinerary_planning's ItineraryPlannerController for the same pattern).
class DestinationMapController extends ChangeNotifier {
  DestinationMapController({
    DestinationExplorationRepository? repository,
    Future<LatLng?> Function()? currentLocation,
  })  : _repository = repository ?? DestinationExplorationRepository(),
        _currentLocation = currentLocation ?? _defaultCurrentLocation {
    loadDestinations();
  }

  final DestinationExplorationRepository _repository;
  final Future<LatLng?> Function() _currentLocation;

  static Future<LatLng?> _defaultCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  List<MapDestination> destinations = const [];
  bool isLoading = false;
  bool hasError = false;
  final Set<HiddenGemCategory> selectedCategories = {};
  MapDestination? selectedDestination;

  MapDestination? clusterAnchor;
  List<MapDestination> clusterStops = const [];
  bool isLoadingCluster = false;
  String? clusterMessage;

  final Set<String> selectedForComparison = {};
  MapViewMode mode = MapViewMode.explore;

  /// The user's last-known position — set by [viewThemedCluster] (when
  /// resolving from current location) and by the map's locate-me control,
  /// so a single "you are here" marker stays in sync regardless of which
  /// action fetched it.
  LatLng? userLocation;

  void setUserLocation(LatLng point) {
    userLocation = point;
    notifyListeners();
  }

  /// Shown by the view when a selection attempt is rejected because the
  /// 3-destination comparison cap is already reached.
  static const comparisonLimitMessage =
      'You can compare up to 3 destinations — remove one first.';

  void setMode(MapViewMode newMode) {
    if (mode == newMode) return;
    mode = newMode;
    notifyListeners();
  }

  List<MapDestination> get filteredDestinations {
    if (selectedCategories.isEmpty) return destinations;
    return destinations.where((d) => selectedCategories.contains(d.category)).toList();
  }

  List<LatLng> get clusterPolyline {
    final anchor = clusterAnchor;
    if (anchor == null) return const [];
    return [anchor.location, ...clusterStops.map((d) => d.location)];
  }

  List<double> get legDistancesKm {
    final points = clusterPolyline;
    if (points.length < 2) return const [];
    return [
      for (var i = 0; i < points.length - 1; i++) legDistanceKm(points[i], points[i + 1]),
    ];
  }

  double get totalDistanceKm => legDistancesKm.fold(0.0, (sum, d) => sum + d);

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

  Future<void> viewThemedCluster({MapDestination? origin}) async {
    if (isLoadingCluster) return;

    isLoadingCluster = true;
    clusterMessage = null;
    notifyListeners();

    try {
      MapDestination? anchor = origin;

      if (anchor == null) {
        // Try to resolve anchor from current location
        final point = await _currentLocation();
        if (point == null) {
          clusterAnchor = null;
          clusterStops = const [];
          clusterMessage = "Couldn't determine your location to find a themed trail.";
          isLoadingCluster = false;
          notifyListeners();
          return;
        }
        userLocation = point;
        anchor = await _repository.nearestDestination(point);
        if (anchor == null) {
          clusterAnchor = null;
          clusterStops = const [];
          clusterMessage = 'No themed cluster available nearby.';
          isLoadingCluster = false;
          notifyListeners();
          return;
        }
      }

      final candidates = await _repository.nearbyByCategory(origin: anchor);
      clusterAnchor = anchor;
      clusterStops = orderByNearestNeighbor(anchor, candidates);
      clusterMessage = clusterStops.isEmpty ? 'No themed cluster available nearby.' : null;
    } catch (_) {
      clusterAnchor = null;
      clusterStops = const [];
      clusterMessage = "Couldn't load a themed cluster right now.";
    }

    isLoadingCluster = false;
    notifyListeners();
  }

  void clearCluster() {
    clusterAnchor = null;
    clusterStops = const [];
    clusterMessage = null;
    isLoadingCluster = false;
    notifyListeners();
  }

  /// Adds every stop of the current themed trail (anchor + [clusterStops])
  /// to the itinerary planner — the trail's one follow-up action, since
  /// otherwise viewing it has no real outcome beyond dismissing the card.
  /// Returns how many were newly added (already-planned stops are skipped,
  /// not duplicated) so the view can show accurate feedback.
  int addTrailToItinerary(ItineraryPlannerController itineraryController) {
    final anchor = clusterAnchor;
    if (anchor == null) return 0;

    var added = 0;
    for (final destination in [anchor, ...clusterStops]) {
      final alreadyPlanned =
          itineraryController.selectedDestinations.any((d) => d.id == destination.id);
      if (alreadyPlanned) continue;
      itineraryController.addDestination(shared.Destination(
        id: destination.id,
        name: destination.name,
        city: '',
        category: _representativeCategory(destination.category),
        location: destination.location,
      ));
      added++;
    }
    return added;
  }

  bool get canCompare =>
      selectedForComparison.length == 2 || selectedForComparison.length == 3;

  /// Toggles [id] in/out of the comparison selection. Returns false (and
  /// leaves the selection unchanged) if adding would exceed the 3-item cap,
  /// so the view can surface [comparisonLimitMessage].
  bool toggleComparisonSelection(String id) {
    if (selectedForComparison.contains(id)) {
      selectedForComparison.remove(id);
      notifyListeners();
      return true;
    }
    if (selectedForComparison.length >= 3) return false;
    selectedForComparison.add(id);
    notifyListeners();
    return true;
  }

  void clearComparisonSelection() {
    if (selectedForComparison.isEmpty) return;
    selectedForComparison.clear();
    notifyListeners();
  }
}

/// A representative [shared.DestinationCategory] for a [HiddenGemCategory] —
/// lossy (several raw categories bucket into one HiddenGemCategory) but
/// good enough for the itinerary integration, which only needs *a*
/// reasonable category for display. Mirrors
/// ComparisonController's identical mapping (destination_exploration's own
/// small, self-contained duplication rather than a shared cross-file
/// dependency for a 6-line switch).
shared.DestinationCategory _representativeCategory(HiddenGemCategory category) {
  switch (category) {
    case HiddenGemCategory.food:
      return shared.DestinationCategory.restaurant;
    case HiddenGemCategory.culture:
      return shared.DestinationCategory.heritageSite;
    case HiddenGemCategory.nature:
      return shared.DestinationCategory.park;
    case HiddenGemCategory.viewpoint:
      return shared.DestinationCategory.viewpoint;
    case HiddenGemCategory.craft:
      return shared.DestinationCategory.craft;
  }
}

final destinationMapControllerProvider =
    ChangeNotifierProvider<DestinationMapController>((ref) {
  return DestinationMapController();
});
