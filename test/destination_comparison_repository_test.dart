import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/crowd_level.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/shared/models/hidden_gem.dart';

void main() {
  group('DestinationExplorationRepository.mapComparisonRow', () {
    test('maps a full row', () {
      final destination = DestinationExplorationRepository.mapComparisonRow({
        'id': 'place_1',
        'name': 'Penang Hill',
        'city': 'George Town',
        'category': 'viewpoint',
        'latitude': 5.4225,
        'longitude': 100.2769,
        'avg_rating': 4.6,
        'uniqueness_score': 4.0,
        'accessibility_score': 3.5,
        'popularity': 'medium',
        'crowd_level': 'high',
        'entrance_cost': 30,
        'difficulty_level': null,
        'accessibility_tags': null,
        'visit_duration_minutes': 90,
        'operating_hours': '9am - 7pm',
      });

      expect(destination.id, 'place_1');
      expect(destination.city, 'George Town');
      expect(destination.category, HiddenGemCategory.viewpoint);
      expect(destination.crowdLevel, CrowdLevel.high);
      expect(destination.entranceCost, 30);
      expect(destination.difficultyLevel, isNull);
      expect(destination.accessibilityTags, isEmpty);
      expect(destination.visitDurationMinutes, 90);
      expect(destination.operatingHours, '9am - 7pm');
      expect(destination.hiddenGemScore, greaterThan(0));
    });

    test('defaults city to empty and popularity/crowd to medium when null', () {
      final destination = DestinationExplorationRepository.mapComparisonRow({
        'id': 'place_2',
        'name': 'Unnamed',
        'city': null,
        'category': 'park',
        'latitude': 5.4,
        'longitude': 100.3,
        'popularity': null,
        'crowd_level': null,
      });

      expect(destination.city, '');
      expect(destination.popularity, GemPopularity.medium);
      expect(destination.crowdLevel, CrowdLevel.medium);
    });

    test('maps accessibility_tags when present', () {
      final destination = DestinationExplorationRepository.mapComparisonRow({
        'id': 'place_3',
        'name': 'Tagged Place',
        'city': 'George Town',
        'category': 'park',
        'latitude': 5.4,
        'longitude': 100.3,
        'accessibility_tags': ['wheelchair-friendly', 'shaded'],
      });

      expect(destination.accessibilityTags, ['wheelchair-friendly', 'shaded']);
    });
  });
}
