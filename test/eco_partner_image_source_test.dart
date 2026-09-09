import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue image metadata remains attached to a partner', () {
    final partner = EcoPartner(
      id: 'osm:node:1',
      name: 'Green Cafe',
      category: EcoPartnerCategory.dining,
      subtype: 'Cafe',
      latitude: 3.14,
      longitude: 101.69,
      address: 'Kuala Lumpur',
      sustainabilityLabel: 'Vegan-friendly dining',
      evidence: 'OpenStreetMap diet:vegan tag',
      sourceName: 'OpenStreetMap contributors',
      sourceUrl: 'https://www.openstreetmap.org/node/1',
      lastUpdated: DateTime(2026),
      imageUrl: 'https://upload.wikimedia.org/photo.jpg',
      imageSourceName: 'Photo: Example · CC BY-SA 4.0 · Wikimedia Commons',
      imageSourceUrl: 'https://commons.wikimedia.org/wiki/File:Photo.jpg',
    );

    expect(partner.imageUrl, contains('wikimedia.org'));
    expect(partner.imageSourceName, contains('CC BY-SA 4.0'));
    expect(partner.imageSourceUrl, contains('commons.wikimedia.org'));
  });

  test('missing cached image metadata is represented by nulls', () {
    final partner = EcoPartner(
      id: 'osm:node:2',
      name: 'Local Cafe',
      category: EcoPartnerCategory.dining,
      subtype: 'Cafe',
      latitude: 3.14,
      longitude: 101.69,
      address: '',
      sustainabilityLabel: 'Vegetarian-friendly dining',
      evidence: 'OpenStreetMap diet:vegetarian tag',
      sourceName: 'OpenStreetMap contributors',
      sourceUrl: 'https://www.openstreetmap.org/node/2',
      lastUpdated: DateTime(2026),
    );

    expect(partner.imageUrl, isNull);
    expect(partner.imageSourceName, isNull);
  });
}
