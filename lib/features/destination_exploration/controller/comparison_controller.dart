import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../model/comparison_destination.dart';
import '../model/crowd_level.dart';
import '../model/destination_exploration_repository.dart';

/// User-adjustable weighting for Best Pick scoring — matches the prepared
/// UI's four slider dimensions. Hidden Gem Score is deliberately not one of
/// these (see the Feature 3 design spec's revised scoring decision) — it's
/// still computed and displayed, just not weighted into the composite score.
class PriorityWeights {
  final double rating;
  final double cost;
  final double crowd;
  final double accessibility;

  const PriorityWeights({
    this.rating = 0.4,
    this.cost = 0.2,
    this.crowd = 0.2,
    this.accessibility = 0.2,
  });

  PriorityWeights normalized() {
    final sum = rating + cost + crowd + accessibility;
    if (sum <= 0) return this;
    return PriorityWeights(
      rating: rating / sum,
      cost: cost / sum,
      crowd: crowd / sum,
      accessibility: accessibility / sum,
    );
  }
}

/// Business logic for Attraction Comparison (Feature 3). Kept as a plain
/// [ChangeNotifier] per the module's MVC convention.
class ComparisonController extends ChangeNotifier {
  ComparisonController({
    DestinationExplorationRepository? repository,
    Future<LatLng?> Function()? currentLocation,
  })  : _repository = repository ?? DestinationExplorationRepository(),
        _currentLocation = currentLocation ?? _noLocation;

  final DestinationExplorationRepository _repository;
  final Future<LatLng?> Function() _currentLocation;

  static Future<LatLng?> _noLocation() async => null;

  List<ComparisonDestination> destinations = const [];
  bool isLoading = false;
  String? selectionError;
  String? shareError;
  PriorityWeights weights = const PriorityWeights();

  void setWeights(PriorityWeights newWeights) {
    weights = newWeights.normalized();
    notifyListeners();
  }

  Future<void> loadComparison(List<String> ids) async {
    if (ids.length < 2 || ids.length > 3) {
      selectionError = 'Select 2 or 3 destinations to compare.';
      notifyListeners();
      return;
    }

    selectionError = null;
    isLoading = true;
    notifyListeners();

    destinations = await _repository.fetchForComparison(ids);
    isLoading = false;
    notifyListeners();
  }

  double _compositeScore(ComparisonDestination destination) {
    final ratingNorm = destination.avgRating / 5.0;
    final crowdScore = switch (destination.crowdLevel) {
      CrowdLevel.low => 1.0,
      CrowdLevel.medium => 0.6,
      CrowdLevel.high => 0.25,
    };
    final accessibilityNorm = destination.accessibilityScore / 5.0;

    final allHaveCost = destinations.every((d) => d.entranceCost != null);
    if (allHaveCost) {
      final costs = destinations.map((d) => d.entranceCost!).toList();
      final minCost = costs.reduce((a, b) => a < b ? a : b);
      final maxCost = costs.reduce((a, b) => a > b ? a : b);
      final costEfficiency = maxCost == minCost
          ? 1.0
          : (maxCost - destination.entranceCost!) / (maxCost - minCost);

      return weights.rating * ratingNorm +
          weights.cost * costEfficiency +
          weights.crowd * crowdScore +
          weights.accessibility * accessibilityNorm;
    }

    final remainingSum = weights.rating + weights.crowd + weights.accessibility;
    if (remainingSum <= 0) return 0;
    final ratingW = weights.rating / remainingSum;
    final crowdW = weights.crowd / remainingSum;
    final accessibilityW = weights.accessibility / remainingSum;
    return ratingW * ratingNorm + crowdW * crowdScore + accessibilityW * accessibilityNorm;
  }

  ComparisonDestination? get bestPick {
    if (destinations.isEmpty) return null;
    var best = destinations.first;
    var bestScore = _compositeScore(best);
    for (final destination in destinations.skip(1)) {
      final score = _compositeScore(destination);
      if (score > bestScore) {
        best = destination;
        bestScore = score;
      }
    }
    return best;
  }

  Future<double?> distanceFromUser(ComparisonDestination destination) async {
    final point = await _currentLocation();
    if (point == null) return null;
    return legDistanceKm(point, destination.location);
  }
}
