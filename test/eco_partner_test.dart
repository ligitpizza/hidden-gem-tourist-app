import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';

void main() {
  group('eco recommendation mapping', () {
    test('maps only explicit OSM diet tags', () {
      expect(OverpassEcoSource.classifyDiet({'diet:vegan': 'only'}), 'Vegan');
      expect(
        OverpassEcoSource.classifyDiet({'diet:vegetarian': 'only'}),
        'Vegetarian',
      );
      expect(
        OverpassEcoSource.classifyDiet({'diet:vegan': 'yes'}),
        'Veg Options',
      );
      expect(OverpassEcoSource.classifyDiet({'cuisine': 'salad'}), isNull);
    });

    test('calculates geographic distance', () {
      final distance = EcoPartnerRepository.distanceKm(
        3.139,
        101.687,
        3.139,
        101.777,
      );
      expect(distance, closeTo(10, 0.2));
    });

    test('maps charging stations separately from transport routes', () {
      final partner = OverpassEcoSource.mapElement({
        'type': 'node',
        'id': 42,
        'lat': 3.14,
        'lon': 101.69,
        'tags': {
          'amenity': 'charging_station',
          'operator': 'Example',
          'capacity': '4',
        },
      });
      expect(partner?.subtype, 'EV charging');
      expect(partner?.name, 'Example EV charger');
      expect(partner?.chargerDetails, contains('capacity: 4'));
    });

    test('gives unnamed EV chargers useful fallback names', () {
      EcoPartner? charger({
        Object? name,
        Object? operatorName,
        String? street,
        String? nearbyLabel,
      }) => OverpassEcoSource.mapElement({
        'type': 'node',
        'id': 43,
        'lat': 3.14,
        'lon': 101.69,
        'tags': {
          'amenity': 'charging_station',
          if (name != null) 'name': name,
          if (operatorName != null) 'operator': operatorName,
          if (street != null) 'addr:street': street,
        },
      }, nearbyLabel: nearbyLabel);

      expect(charger(name: '  Named charger  ')?.name, 'Named charger');
      expect(
        charger(name: ' ', operatorName: 'ChargeCo')?.name,
        'ChargeCo EV charger',
      );
      expect(
        charger(name: ' ', operatorName: ' ', street: 'Jalan Ampang')?.name,
        'EV charger near Jalan Ampang',
      );
      expect(
        charger(name: ' ', nearbyLabel: 'Kuala Lumpur')?.name,
        'EV charger near Kuala Lumpur',
      );
      expect(charger(name: ' ')?.name, 'EV charging station');
    });
  });
}
