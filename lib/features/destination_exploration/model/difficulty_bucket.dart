enum DifficultyBucket { easy, moderate, hard }

extension DifficultyBucketX on DifficultyBucket {
  String get label {
    switch (this) {
      case DifficultyBucket.easy:
        return 'Easy';
      case DifficultyBucket.moderate:
        return 'Moderate';
      case DifficultyBucket.hard:
        return 'Hard';
    }
  }
}

/// Aggregated 1-5 difficulty scores bucket into a coarse label (FR4.4).
DifficultyBucket difficultyBucketFor(double avgDifficulty) {
  if (avgDifficulty <= 2.0) return DifficultyBucket.easy;
  if (avgDifficulty <= 3.5) return DifficultyBucket.moderate;
  return DifficultyBucket.hard;
}
