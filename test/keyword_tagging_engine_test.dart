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
      expect(KeywordTaggingEngine.tagsFor('a ramp leads up to the entrance'), ['ramp available']);
      expect(KeywordTaggingEngine.tagsFor('sturdy handrail the whole way'), ['handrail available']);
      expect(KeywordTaggingEngine.tagsFor('very uneven ground'), ['uneven terrain']);
      expect(KeywordTaggingEngine.tagsFor('a narrow path near the edge'), ['narrow pathway']);
      expect(KeywordTaggingEngine.tagsFor('gets muddy after rain'), ['muddy when wet']);
      expect(KeywordTaggingEngine.tagsFor('clean public toilet on site'), ['restroom available']);
      expect(KeywordTaggingEngine.tagsFor('a few benches to rest on'), ['seating available']);
      expect(KeywordTaggingEngine.tagsFor('well signposted trail'), ['well signposted']);
      expect(KeywordTaggingEngine.tagsFor('good for elderly visitors'), ['elderly-friendly']);
      expect(KeywordTaggingEngine.tagsFor('brought my dog along'), ['pet-friendly']);
    });

    test('is case-insensitive', () {
      expect(KeywordTaggingEngine.tagsFor('WHEELCHAIR accessible'), ['wheelchair-friendly']);
    });

    test('produces multiple deduplicated tags from one review', () {
      final tags = KeywordTaggingEngine.tagsFor(
        'The path was a bit slippery but wheelchair-friendly at the base, wheelchair ramps everywhere',
      );
      expect(tags, ['slippery when wet', 'wheelchair-friendly', 'ramp available']);
    });

    test('returns an empty list when nothing matches', () {
      expect(KeywordTaggingEngine.tagsFor('Absolutely breathtaking views'), isEmpty);
    });
  });

  group('KeywordTaggingEngine.tagsFor negation handling', () {
    test('drops a keyword with no negated-tag counterpart when negated', () {
      expect(KeywordTaggingEngine.tagsFor('no parking on site'), isEmpty);
      expect(KeywordTaggingEngine.tagsFor("doesn't have stairs"), isEmpty);
    });

    test('tags the explicit opposite when a keyword with a negated-tag counterpart is negated', () {
      expect(KeywordTaggingEngine.tagsFor('unable to use wheelchair'), ['wheelchair-unfriendly']);
      expect(KeywordTaggingEngine.tagsFor('not wheelchair friendly'), ['wheelchair-unfriendly']);
      expect(KeywordTaggingEngine.tagsFor('no stroller access here'), ['stroller-unfriendly']);
    });

    test('tags both the positive and negated counterpart for a mixed review', () {
      final tags = KeywordTaggingEngine.tagsFor(
        'Unable to use wheelchair on the upper trail, but the lower path is wheelchair friendly',
      );
      expect(tags, ['wheelchair-friendly', 'wheelchair-unfriendly']);
    });

    test('a negation cue that follows the keyword still negates it', () {
      // The negation ("not good") describes wheelchair accessibility but
      // comes *after* "wheelchair" in the sentence, not before it — the
      // word-window check must look both directions, not just backward.
      final tags = KeywordTaggingEngine.tagsFor(
        "here got a lot of chair to seat, but it's not friendly for stroller. "
        'the wheelchair accessibility is not good too',
      );
      expect(tags, contains('wheelchair-unfriendly'));
      expect(tags, isNot(contains('wheelchair-friendly')));
      expect(tags, contains('stroller-unfriendly'));
    });

    test('a negation cue far outside the word window does not suppress the tag', () {
      // "Not" here modifies "crowded", not "wheelchair" — 7 words separate
      // them, past the 4-word negation window, so wheelchair still tags
      // positively and not its negated counterpart.
      final tags = KeywordTaggingEngine.tagsFor(
        'Not crowded at all on weekdays, and the wheelchair access was great',
      );
      expect(tags, contains('wheelchair-friendly'));
      expect(tags, isNot(contains('wheelchair-unfriendly')));
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
