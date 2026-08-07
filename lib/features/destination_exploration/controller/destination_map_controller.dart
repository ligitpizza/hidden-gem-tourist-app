import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/hidden_gem.dart';
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

final destinationMapControllerProvider =
    ChangeNotifierProvider<DestinationMapController>((ref) {
  return DestinationMapController();
});
