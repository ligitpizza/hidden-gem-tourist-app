import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/travel_prep/model/eco_partner_repository.dart';

void main() {
  group('eco recommendation mapping', () {
    test('maps only explicit OSM diet tags', () {
      expect(OverpassEcoSource.classifyDiet({'diet:vegan': 'only'}), 'Vegan');
      expect(OverpassEcoSource.classifyDiet({'diet:vegetarian': 'only'}), 'Vegetarian');
      expect(OverpassEcoSource.classifyDiet({'diet:vegan': 'yes'}), 'Veg Options');
      expect(OverpassEcoSource.classifyDiet({'cuisine': 'salad'}), isNull);
    });

    test('calculates geographic distance', () {
      final distance = EcoPartnerRepository.distanceKm(3.139, 101.687, 3.139, 101.777);
      expect(distance, closeTo(10, 0.2));
    });

    test('maps charging stations separately from transport routes', () {
      final partner = OverpassEcoSource.mapElement({
        'type': 'node', 'id': 42, 'lat': 3.14, 'lon': 101.69,
        'tags': {'amenity': 'charging_station', 'operator': 'Example', 'capacity': '4'},
      });
      expect(partner?.subtype, 'EV charging');
      expect(partner?.chargerDetails, contains('capacity: 4'));
    });
  });
}
