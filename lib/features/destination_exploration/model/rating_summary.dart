import 'difficulty_bucket.dart';

/// One badge's share of a destination's ratings (FR4.5) — e.g. "Shaded
/// Trail 84%" in the prepared UI.
class TagFrequency {
  final String tag;
  final double percentage;

  const TagFrequency({required this.tag, required this.percentage});

  @override
  bool operator ==(Object other) =>
      other is TagFrequency && other.tag == tag && other.percentage == percentage;

  @override
  int get hashCode => Object.hash(tag, percentage);
}

class RatingSummary {
  final DifficultyBucket difficultyBucket;
  final double avgDifficulty;
  final int ratingCount;
  final List<TagFrequency> topTags;

  const RatingSummary({
    required this.difficultyBucket,
    required this.avgDifficulty,
    required this.ratingCount,
    required this.topTags,
  });

  @override
  bool operator ==(Object other) =>
      other is RatingSummary &&
      other.difficultyBucket == difficultyBucket &&
      other.avgDifficulty == avgDifficulty &&
      other.ratingCount == ratingCount &&
      listsEqual(other.topTags, topTags);

  @override
  int get hashCode => Object.hash(difficultyBucket, avgDifficulty, ratingCount, Object.hashAll(topTags));
}

bool listsEqual(List<TagFrequency> a, List<TagFrequency> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One row of `destination_ratings`, for the Destination Detail page's
/// paginated review list.
class DestinationReview {
  final String reviewText;
  final int difficultyScore;
  final List<String> generatedTags;
  final DateTime createdAt;

  const DestinationReview({
    required this.reviewText,
    required this.difficultyScore,
    required this.generatedTags,
    required this.createdAt,
  });
}

/// Pure aggregation, separated from the Supabase-calling repository method
/// so it's unit-testable without a network call (same split as
/// DestinationExplorationRepository.mapRow in Feature 1).
RatingSummary summarizeRatings(List<({int difficultyScore, List<String> tags})> ratings) {
  if (ratings.isEmpty) {
    return const RatingSummary(
      difficultyBucket: DifficultyBucket.easy,
      avgDifficulty: 0,
      ratingCount: 0,
      topTags: [],
    );
  }

  final avgDifficulty =
      ratings.map((r) => r.difficultyScore).reduce((a, b) => a + b) / ratings.length;

  final tagCounts = <String, int>{};
  for (final rating in ratings) {
    for (final tag in rating.tags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  final sortedTags = tagCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topTags = sortedTags
      .take(5)
      .map((entry) => TagFrequency(
            tag: entry.key,
            percentage: entry.value / ratings.length * 100,
          ))
      .toList();

  return RatingSummary(
    difficultyBucket: difficultyBucketFor(avgDifficulty),
    avgDifficulty: avgDifficulty,
    ratingCount: ratings.length,
    topTags: topTags,
  );
}
