import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/shared/models/hidden_gem.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';

void main() {
  group('DestinationExplorationRepository.mapRow', () {
    test('maps a full row', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_1',
        'name': 'Penang Hill',
        'description': 'A funicular railway up to cool hilltop views.',
        'category': 'viewpoint',
        'latitude': 5.4225,
        'longitude': 100.2769,
        'avg_rating': 4.6,
        'images': ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
      });

      expect(destination.id, 'place_1');
      expect(destination.name, 'Penang Hill');
      expect(destination.description, 'A funicular railway up to cool hilltop views.');
      expect(destination.category, HiddenGemCategory.viewpoint);
      expect(destination.location.latitude, 5.4225);
      expect(destination.location.longitude, 100.2769);
      expect(destination.avgRating, 4.6);
      expect(destination.imageUrls, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
    });

    test('falls back to a placeholder description when blank', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_2',
        'name': 'Unnamed Spot',
        'description': '   ',
        'category': 'park',
        'latitude': 5.4,
        'longitude': 100.3,
      });

      expect(destination.description, 'No description available yet.');
    });

    test('returns an empty imageUrls list when images is null', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_3',
        'name': 'No Photos Yet',
        'description': 'Nice place.',
        'category': 'craft',
        'latitude': 5.4,
        'longitude': 100.3,
        'images': null,
      });

      expect(destination.imageUrls, isEmpty);
    });

    test('returns an empty imageUrls list when images is not a list', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_4',
        'name': 'Weird Data',
        'description': 'Nice place.',
        'category': 'craft',
        'latitude': 5.4,
        'longitude': 100.3,
        'images': 'not-a-list',
      });

      expect(destination.imageUrls, isEmpty);
    });

    test('unrecognised category strings fall back via HiddenGemScoring', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_5',
        'name': 'Mystery Place',
        'description': 'Nice place.',
        'category': 'totally_unknown_category',
        'latitude': 5.4,
        'longitude': 100.3,
      });

      expect(destination.category, HiddenGemCategory.culture);
    });
  });

  group('legDistanceKm', () {
    test('computes a known distance', () {
      // Kuala Lumpur city centre to Batu Caves, ~11.5km apart.
      final km = legDistanceKm(
        const LatLng(3.1390, 101.6869),
        const LatLng(3.2379, 101.6840),
      );
      expect(km, closeTo(11.5, 1.0));
    });

    test('is zero for the same point', () {
      const point = LatLng(5.4164, 100.3327);
      expect(legDistanceKm(point, point), closeTo(0, 0.001));
    });
  });

  group('orderByNearestNeighbor', () {
    const origin = MapDestination(
      id: 'origin',
      name: 'Origin',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 0),
    );
    const near = MapDestination(
      id: 'near',
      name: 'Near',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 1),
    );
    const far = MapDestination(
      id: 'far',
      name: 'Far',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 5),
    );
    const mid = MapDestination(
      id: 'mid',
      name: 'Mid',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 3),
    );

    test('returns an empty list for no candidates', () {
      expect(orderByNearestNeighbor(origin, const []), isEmpty);
    });

    test('returns the single candidate unchanged', () {
      expect(orderByNearestNeighbor(origin, [near]), [near]);
    });

    test('greedily visits closest-first from a scrambled input', () {
      final ordered = orderByNearestNeighbor(origin, [far, near, mid]);
      expect(ordered, [near, mid, far]);
    });
  });
}
