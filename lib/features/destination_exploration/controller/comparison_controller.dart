import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/models/destination.dart' as shared;
import '../../../shared/models/hidden_gem.dart' show HiddenGemCategory, HiddenGemCategoryX;
import '../../itinerary_planning/controller/itinerary_planner_controller.dart';
import '../model/comparison_destination.dart';
import '../model/crowd_level.dart';
import '../model/destination_exploration_repository.dart';
import '../model/favourite_destinations_store.dart';

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
  String? loadError;
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
    loadError = null;
    isLoading = true;
    notifyListeners();

    try {
      destinations = await _repository.fetchForComparison(ids);
    } catch (_) {
      loadError = "Couldn't load the comparison right now.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
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

  /// The composite Best Pick score for [destination] under the current
  /// [weights] — exposes the otherwise-private scoring calculation so the
  /// View can show a match score/percentage (FR3.8), without duplicating
  /// the formula.
  double scoreFor(ComparisonDestination destination) => _compositeScore(destination);

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

  Future<void> addBestPickToItinerary(ItineraryPlannerController itineraryController) async {
    final pick = bestPick;
    if (pick == null) return;
    itineraryController.addDestination(shared.Destination(
      id: pick.id,
      name: pick.name,
      city: pick.city,
      category: _representativeCategory(pick.category),
      location: pick.location,
    ));
  }

  Future<void> saveToFavourites(ComparisonDestination destination) {
    return FavouriteDestinationsStore.instance.add(destination);
  }

  /// A per-destination breakdown (category, rating, Hidden Gem score,
  /// entrance cost, crowd level) rather than just names + one score, so the
  /// shared text stands on its own the way the itinerary's share summary
  /// does (see ItineraryPlannerController.buildShareSummary) instead of
  /// needing the app open to make sense of it.
  String buildShareSummary() {
    final buffer = StringBuffer()
      ..writeln('My comparison: ${destinations.map((d) => d.name).join(' vs ')}');
    final pick = bestPick;
    if (pick != null) buffer.writeln('Best Pick: ${pick.name}');
    buffer.writeln();

    for (final destination in destinations) {
      buffer
        ..writeln('${destination.name} — ${destination.category.label}')
        ..writeln(
          '★${destination.avgRating.toStringAsFixed(1)} | '
          'Hidden Gem ${(destination.hiddenGemScore * 10).toStringAsFixed(1)}/10 | '
          '${_formatEntranceCost(destination.entranceCost)} | '
          '${destination.crowdLevel.label} crowds',
        )
        ..writeln();
    }
    return buffer.toString().trimRight();
  }

  Future<void> shareComparison() async {
    try {
      shareError = null;
      await Share.share(buildShareSummary());
    } catch (_) {
      shareError = "Couldn't share the comparison right now.";
    }
    notifyListeners();
  }
}

String _formatEntranceCost(double? cost) {
  if (cost == null) return 'Cost not listed';
  if (cost == 0) return 'Free entry';
  return 'RM ${cost.toStringAsFixed(2)}';
}

/// A representative [shared.DestinationCategory] for a [HiddenGemCategory] —
/// lossy (several raw categories bucket into one HiddenGemCategory) but
/// good enough for the itinerary integration, which only needs *a*
/// reasonable category for display, not the original raw value.
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
