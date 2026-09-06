import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';
import 'package:dio/dio.dart';

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
          'capacity': '1',
          'access': 'yes',
          'socket:type2': '2',
          'socket:type2:output': '22 kW',
        },
      });
      expect(partner?.subtype, 'EV charging');
      expect(partner?.name, 'Example EV charger');
      expect(partner?.chargingDetails?.capacityLabel, '1 charging point');
      expect(partner?.chargingDetails?.accessLabel, 'Open to the public');
      expect(partner?.chargingDetails?.operatorLabel, 'Operated by Example');
      expect(
        partner?.chargingDetails?.connectors.single.summary,
        '2 × Type 2 · up to 22 kW',
      );
    });

    test('translates access values and ignores boolean operator tags', () {
      final publicDetails = EcoChargingDetails.fromOsmTags({
        'operator': 'yes',
        'capacity': '4',
        'access': 'customers',
      });
      final privateDetails = EcoChargingDetails.fromOsmTags({
        'access': 'private',
      });

      expect(publicDetails.capacityLabel, '4 charging points');
      expect(publicDetails.accessLabel, 'Customers only');
      expect(publicDetails.operatorLabel, isNull);
      expect(privateDetails.accessLabel, 'Private access');
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
          'name': ?name,
          'operator': ?operatorName,
          'addr:street': ?street,
        },
      }, nearbyLabel: nearbyLabel);

      expect(charger(name: '  Named charger  ')?.name, 'Named charger');
      expect(
        charger(name: ' ', operatorName: 'ChargeCo')?.name,
        'ChargeCo EV charger',
      );
      expect(
        charger(name: ' ', operatorName: 'yes', street: 'Jalan Ampang')?.name,
        'EV charger near Jalan Ampang',
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

    test('keeps successful OSM categories when another query fails', () async {
      final dio = Dio();
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            if (options.queryParameters['q'] == 'charging station') {
              handler.resolve(
                Response<List<Map<String, dynamic>>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'osm_type': 'node',
                      'osm_id': 42,
                      'lat': '3.14',
                      'lon': '101.69',
                      'category': 'amenity',
                      'type': 'charging_station',
                      'name': 'Nearby charger',
                      'display_name': 'Nearby charger, Kuala Lumpur',
                      'extratags': {
                        'capacity': '4',
                        'access': 'yes',
                        'socket:type2_combo': '1',
                      },
                    },
                  ],
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Category unavailable',
              ),
            );
          },
        ),
      );

      final partners = await OverpassEcoSource(dio: dio).search(
        const EcoDestination('Current location', 3.139, 101.687),
        scope: const EcoPartnerSearchScope.nearby(10),
      );

      expect(requests, 3);
      expect(partners.map((partner) => partner.name), ['Nearby charger']);
      expect(
        partners.single.chargingDetails?.capacityLabel,
        '4 charging points',
      );
      expect(
        partners.single.chargingDetails?.connectors.single.displayName,
        'CCS (Combo 2)',
      );
    });
  });
}
