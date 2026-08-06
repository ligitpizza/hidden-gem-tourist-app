import 'package:latlong2/latlong.dart';

import '../../../shared/models/hidden_gem.dart';
import '../../../shared/services/hidden_gem_scoring.dart';
import 'crowd_level.dart';

/// A destination with every field Attraction Comparison needs — richer than
/// Feature 1's lean [MapDestination], which only carries what a map
/// marker/popup needs.
class ComparisonDestination {
  final String id;
  final String name;
  final String city;
  final HiddenGemCategory category;
  final LatLng location;
  final double avgRating;
  final double uniquenessScore;
  final double accessibilityScore;
  final GemPopularity popularity;
  final CrowdLevel crowdLevel;
  final double? entranceCost;
  final String? difficultyLevel;
  final List<String> accessibilityTags;
  final int? visitDurationMinutes;
  final String? operatingHours;

  const ComparisonDestination({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.location,
    this.avgRating = 0,
    this.uniquenessScore = 0,
    this.accessibilityScore = 0,
    this.popularity = GemPopularity.medium,
    this.crowdLevel = CrowdLevel.medium,
    this.entranceCost,
    this.difficultyLevel,
    this.accessibilityTags = const [],
    this.visitDurationMinutes,
    this.operatingHours,
  });

  /// Computed on demand from the shared formula — never stored, so the
  /// formula only ever lives in one place (FR3.3).
  double get hiddenGemScore => HiddenGemScoring.score(
        avgRating: avgRating,
        uniqueness: uniquenessScore,
        accessibility: accessibilityScore,
        popularity: popularity,
      );
}
