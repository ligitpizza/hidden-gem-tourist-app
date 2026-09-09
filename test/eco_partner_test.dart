import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Eco Partner catalogue model', () {
    test('calculates geographic distance', () {
      final distance = EcoPartnerRepository.distanceKm(
        3.139,
        101.687,
        3.139,
        101.777,
      );
      expect(distance, closeTo(10, 0.2));
    });

    test('maps structured charging details used by catalogue rows', () {
      final details = EcoChargingDetails.fromJson({
        'capacity': 4,
        'access': 'public',
        'operatorName': 'ChargeCo',
        'connectors': [
          {'type': 'type2', 'count': 2, 'output': '22 kW'},
        ],
      });
      expect(details?.capacityLabel, '4 charging points');
      expect(details?.accessLabel, 'Open to the public');
      expect(details?.operatorLabel, 'Operated by ChargeCo');
      expect(details?.connectors.single.displayName, 'Type 2');
    });

    test('gives unnamed EV chargers useful fallback names', () {
      expect(
        resolveEvChargerName(operatorName: 'ChargeCo'),
        'ChargeCo EV charger',
      );
      expect(
        resolveEvChargerName(address: 'Jalan Ampang, Kuala Lumpur'),
        'EV charger near Jalan Ampang',
      );
      expect(resolveEvChargerName(), 'EV charging station');
    });

    test('search result defaults its total to the returned row count', () {
      final partners = [_partner('one'), _partner('two')];
      final result = EcoPartnerSearchResult(
        destination: const EcoDestination('Malaysia', 4.2, 101.9),
        partners: partners,
      );
      expect(result.totalCount, 2);
    });

    test('technical catalogue evidence is presented in friendly language', () {
      expect(
        ecoPartnerEvidenceLabel(
          _partner('vegan').copyWithEvidence('OpenStreetMap diet:vegan tag'),
        ),
        'Listed as vegan-friendly.',
      );
      expect(
        ecoPartnerEvidenceLabel(
          _partner('routes').copyWithEvidence('Routes: T1, T2'),
        ),
        'Scheduled services include: T1, T2',
      );
    });
  });
}

extension on EcoPartner {
  EcoPartner copyWithEvidence(String value) => EcoPartner(
    id: id,
    name: name,
    category: category,
    subtype: subtype,
    latitude: latitude,
    longitude: longitude,
    address: address,
    sustainabilityLabel: sustainabilityLabel,
    evidence: value,
    sourceName: sourceName,
    sourceUrl: sourceUrl,
    lastUpdated: lastUpdated,
  );
}

EcoPartner _partner(String id) => EcoPartner(
  id: id,
  name: id,
  category: EcoPartnerCategory.stay,
  subtype: 'Hotel',
  latitude: 3.14,
  longitude: 101.69,
  address: 'Kuala Lumpur',
  sustainabilityLabel: 'Verified',
  evidence: 'Test',
  sourceName: 'Test',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
);
