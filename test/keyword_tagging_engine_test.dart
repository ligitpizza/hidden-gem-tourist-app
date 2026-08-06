import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/difficulty_bucket.dart';
import 'package:collab/features/destination_exploration/model/keyword_tagging_engine.dart';

void main() {
  group('KeywordTaggingEngine.tagsFor', () {
    test('matches each keyword to its tag', () {
      expect(KeywordTaggingEngine.tagsFor('great for wheelchair users'), ['wheelchair-friendly']);
      expect(KeywordTaggingEngine.tagsFor('bring a stroller'), ['stroller-friendly']);
      expect(KeywordTaggingEngine.tagsFor('very steep near the top'), ['steep terrain']);
      expect(KeywordTaggingEngine.tagsFor('lots of stairs'), ['many stairs']);
      expect(KeywordTaggingEngine.tagsFor('free parking available'), ['parking available']);
      expect(KeywordTaggingEngine.tagsFor('gets crowded on weekends'), ['crowded']);
      expect(KeywordTaggingEngine.tagsFor('great for kids'), ['family-friendly']);
      expect(KeywordTaggingEngine.tagsFor('good family spot'), ['family-friendly']);
      expect(KeywordTaggingEngine.tagsFor('lots of shade'), ['shaded']);
      expect(KeywordTaggingEngine.tagsFor('slippery when wet'), ['slippery when wet']);
    });

    test('is case-insensitive', () {
      expect(KeywordTaggingEngine.tagsFor('WHEELCHAIR accessible'), ['wheelchair-friendly']);
    });

    test('produces multiple deduplicated tags from one review', () {
      final tags = KeywordTaggingEngine.tagsFor(
        'The path was a bit slippery but wheelchair-friendly at the base, wheelchair ramps everywhere',
      );
      expect(tags, ['slippery when wet', 'wheelchair-friendly']);
    });

    test('returns an empty list when nothing matches', () {
      expect(KeywordTaggingEngine.tagsFor('Absolutely breathtaking views'), isEmpty);
    });
  });

  group('difficultyBucketFor', () {
    test('boundary values', () {
      expect(difficultyBucketFor(2.0), DifficultyBucket.easy);
      expect(difficultyBucketFor(2.01), DifficultyBucket.moderate);
      expect(difficultyBucketFor(3.5), DifficultyBucket.moderate);
      expect(difficultyBucketFor(3.51), DifficultyBucket.hard);
    });
  });
}
