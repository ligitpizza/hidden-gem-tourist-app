// test/rating_tag_style_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/rating_tag_style.dart';

void main() {
  group('toneFor', () {
    test('classifies caution tags', () {
      expect(toneFor('steep terrain'), RatingTagTone.caution);
      expect(toneFor('many stairs'), RatingTagTone.caution);
      expect(toneFor('crowded'), RatingTagTone.caution);
      expect(toneFor('slippery when wet'), RatingTagTone.caution);
    });

    test('classifies positive tags', () {
      expect(toneFor('wheelchair-friendly'), RatingTagTone.positive);
      expect(toneFor('stroller-friendly'), RatingTagTone.positive);
      expect(toneFor('parking available'), RatingTagTone.positive);
      expect(toneFor('family-friendly'), RatingTagTone.positive);
      expect(toneFor('shaded'), RatingTagTone.positive);
    });

    test('unknown tags default to positive', () {
      expect(toneFor('something new'), RatingTagTone.positive);
    });
  });
}
