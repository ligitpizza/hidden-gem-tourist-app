import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/hidden_gem.dart';
import '../model/destination_exploration_repository.dart'
    show DestinationExplorationRepository, legDistanceKm, orderByNearestNeighbor;
import '../model/map_destination.dart';

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
    isLoadingCluster = true;
    clusterMessage = null;
    notifyListeners();

    try {
      final anchor = origin ?? await _resolveAnchorFromLocation();
      if (anchor == null) {
        clusterAnchor = null;
        clusterStops = const [];
        clusterMessage = "Couldn't determine your location to find a themed trail.";
        isLoadingCluster = false;
        notifyListeners();
        return;
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

  Future<MapDestination?> _resolveAnchorFromLocation() async {
    final point = await _currentLocation();
    if (point == null) return null;
    return _repository.nearestDestination(point);
  }

  void clearCluster() {
    clusterAnchor = null;
    clusterStops = const [];
    clusterMessage = null;
    isLoadingCluster = false;
    notifyListeners();
  }
}

final destinationMapControllerProvider =
    ChangeNotifierProvider<DestinationMapController>((ref) {
  return DestinationMapController();
});
