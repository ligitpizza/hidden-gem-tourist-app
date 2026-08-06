// test/destination_rating_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/difficulty_bucket.dart';
import 'package:collab/features/destination_exploration/model/rating_summary.dart';

void main() {
  group('summarizeRatings', () {
    test('returns an empty/zeroed summary for no ratings', () {
      final summary = summarizeRatings(const []);

      expect(summary.ratingCount, 0);
      expect(summary.avgDifficulty, 0);
      expect(summary.topTags, isEmpty);
    });

    test('averages difficulty into the correct bucket', () {
      final summary = summarizeRatings(const [
        (difficultyScore: 4, tags: <String>[]),
        (difficultyScore: 4, tags: <String>[]),
      ]);

      expect(summary.avgDifficulty, 4.0);
      expect(summary.difficultyBucket, DifficultyBucket.hard);
      expect(summary.ratingCount, 2);
    });

    test('computes tag percentages and keeps only the top 5, most-frequent first', () {
      final summary = summarizeRatings(const [
        (difficultyScore: 2, tags: ['shaded', 'family-friendly']),
        (difficultyScore: 2, tags: ['shaded']),
        (difficultyScore: 2, tags: ['shaded']),
        (difficultyScore: 2, tags: ['family-friendly']),
      ]);

      expect(summary.topTags.first.tag, 'shaded');
      expect(summary.topTags.first.percentage, closeTo(75, 0.01)); // 3 of 4
      expect(summary.topTags[1].tag, 'family-friendly');
      expect(summary.topTags[1].percentage, closeTo(50, 0.01)); // 2 of 4
    });

    test('a frequency tie keeps insertion/discovery order', () {
      final summary = summarizeRatings(const [
        (difficultyScore: 2, tags: ['alpha']),
        (difficultyScore: 2, tags: ['beta']),
      ]);

      expect(summary.topTags.map((t) => t.tag), ['alpha', 'beta']);
    });

    test('multiple tied tags preserve insertion order regardless of vocabulary size', () {
      final summary = summarizeRatings(const [
        (difficultyScore: 2, tags: ['delta']),
        (difficultyScore: 2, tags: ['alpha']),
        (difficultyScore: 2, tags: ['charlie']),
        (difficultyScore: 2, tags: ['bravo']),
      ]);

      // All tags have frequency 1, should be ordered by first occurrence
      expect(summary.topTags.map((t) => t.tag), ['delta', 'alpha', 'charlie', 'bravo']);
      expect(summary.topTags.map((t) => t.percentage), [25.0, 25.0, 25.0, 25.0]);
    });
  });
}
