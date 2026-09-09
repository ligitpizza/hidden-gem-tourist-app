import 'dart:convert';

import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'nearby catalogue search sends spatial paging parameters to RPC',
    () async {
      http.Request? captured;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode([_row(totalCount: 14, distanceKm: 2.5)]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final repository = EcoPartnerRepository(client: client);

      final result = await repository.searchPage(
        destination: const EcoDestination('Current location', 3.14, 101.69),
        distanceOrigin: const EcoDestination('Current location', 3.14, 101.69),
        scope: const EcoPartnerSearchScope.nearby(25),
        category: 'dining',
        sort: 'name_asc',
        limit: 10,
        offset: 10,
      );

      expect(captured?.url.path, '/rest/v1/rpc/search_eco_partners');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['p_latitude'], 3.14);
      expect(body['p_longitude'], 101.69);
      expect(body['p_radius_km'], 25);
      expect(body['p_state'], isNull);
      expect(body['p_category'], 'dining');
      expect(body['p_limit'], 10);
      expect(body['p_offset'], 10);
      expect(result.totalCount, 14);
      expect(result.partners.single.distanceKm, 2.5);
    },
  );

  test('partner-name search uses Supabase and maps cached metadata', () async {
    http.Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([_row(totalCount: 1, distanceKm: null)]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final repository = EcoPartnerRepository(client: client);

    final result = await repository.searchByName('Green Cafe');

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_query'], 'Green Cafe');
    expect(body['p_latitude'], isNull);
    expect(body['p_radius_km'], isNull);
    expect(result.partners.single.imageUrl, contains('wikimedia.org'));
    expect(result.partners.single.veganClassification, 'Vegan');
    expect(result.partners.single.chargingDetails?.capacity, 4);
    expect(result.partners.single.distanceKm, isNull);
  });
}

Map<String, dynamic> _row({
  required int totalCount,
  required double? distanceKm,
}) => {
  'id': 'osm:node:10',
  'name': 'Green Cafe',
  'category': 'dining',
  'subtype': 'Cafe',
  'state': 'Kuala Lumpur',
  'address': 'Jalan Ampang',
  'latitude': 3.14,
  'longitude': 101.69,
  'sustainability_label': 'Vegan-friendly dining',
  'evidence': 'OpenStreetMap diet:vegan tag',
  'source_name': 'OpenStreetMap contributors',
  'source_url': 'https://www.openstreetmap.org/node/10',
  'source_updated_at': '2026-09-09T00:00:00Z',
  'image_url': 'https://upload.wikimedia.org/photo.jpg',
  'image_source_name': 'Photo: Example · CC BY 4.0',
  'image_source_url': 'https://commons.wikimedia.org/wiki/File:Photo.jpg',
  'transit_routes': <dynamic>[],
  'vegan_classification': 'Vegan',
  'charging_details': {
    'capacity': 4,
    'access': 'public',
    'operatorName': 'ChargeCo',
    'connectors': <dynamic>[],
  },
  'gstc_verified': false,
  'distance_km': distanceKm,
  'total_count': totalCount,
};
