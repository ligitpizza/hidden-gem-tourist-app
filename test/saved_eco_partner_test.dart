import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/saved_eco_partner.dart';
import 'package:collab/features/travel_assistant/model/saved_eco_partner_repository.dart';
import 'package:collab/features/travel_assistant/model/saved_eco_partners_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('saved Eco Partner store saves and removes the same partner', () async {
    final repository = _MemorySavedEcoPartnerRepository();
    final store = SavedEcoPartnersStore(repository: repository);

    await store.ensureLoaded();
    expect(store.saved, isEmpty);

    expect(await store.toggle(_partner), isTrue);
    expect(store.isSaved(_partner.id), isTrue);
    expect(store.saved.single.partner.name, 'Eco Lodge');

    expect(await store.toggle(_partner), isFalse);
    expect(store.saved, isEmpty);
    expect(repository.deletedIds, ['saved-1']);
  });

  test(
    'missing Supabase table falls back to a persistent local save',
    () async {
      SharedPreferences.setMockInitialValues({});
      final local = LocalSavedEcoPartnerRepository(userId: () => 'user-1');
      final repository = ResilientSavedEcoPartnerRepository(
        remote: _MissingTableRepository(),
        local: local,
      );

      expect(await repository.fetchAll(), isEmpty);
      final saved = await repository.save(_partner);
      expect(saved.id, startsWith('local:'));

      final afterRestart = LocalSavedEcoPartnerRepository(
        userId: () => 'user-1',
      );
      expect((await afterRestart.fetchAll()).single.partner.name, 'Eco Lodge');
    },
  );

  test('repairs an unnamed saved EV charger from its address', () {
    final value = SavedEcoPartnerCodec.toJson(_evPartner);
    value['name'] = ' ';
    value['address'] = 'Jalan Tun Razak, Kuala Lumpur';

    final restored = SavedEcoPartnerCodec.fromJson(value);

    expect(restored.name, 'EV charger near Jalan Tun Razak');
  });

  test('round-trips structured charging details with a legacy summary', () {
    final value = SavedEcoPartnerCodec.toJson(_evPartner);

    expect(value['chargingDetails'], isA<Map<String, dynamic>>());
    expect(value['chargerDetails'], contains('capacity: 1'));

    final restored = SavedEcoPartnerCodec.fromJson(value);
    expect(restored.chargingDetails?.capacityLabel, '1 charging point');
    expect(restored.chargingDetails?.accessLabel, 'Open to the public');
    expect(
      restored.chargingDetails?.connectors.single.summary,
      '2 × Type 2 · up to 22 kW',
    );
  });

  test('upgrades legacy charger detail strings when loading', () {
    final value = SavedEcoPartnerCodec.toJson(_evPartner)
      ..remove('chargingDetails')
      ..['chargerDetails'] =
          'operator: yes · capacity: 1 · access: customers · '
          'type2: 2 · type2:output: 22 kW';

    final restored = SavedEcoPartnerCodec.fromJson(value);

    expect(restored.chargingDetails?.capacityLabel, '1 charging point');
    expect(restored.chargingDetails?.accessLabel, 'Customers only');
    expect(restored.chargingDetails?.operatorLabel, isNull);
    expect(
      restored.chargingDetails?.connectors.single.summary,
      '2 × Type 2 · up to 22 kW',
    );
  });

  test('removes legacy Mapillary metadata when reading saved partners', () {
    final value = SavedEcoPartnerCodec.toJson(_partner)
      ..['imageUrl'] = 'https://legacy-street-images.invalid/example.jpg'
      ..['imageSourceName'] = 'Nearby street-level image · Mapillary'
      ..['imageSourceUrl'] = 'https://legacy-street-images.invalid/photo/1'
      ..['imageCapturedAt'] = '2020-01-01T00:00:00.000Z';

    final restored = SavedEcoPartnerCodec.fromJson(value);

    expect(restored.imageUrl, isNull);
    expect(restored.imageSourceName, isNull);
    expect(restored.imageSourceUrl, isNull);
    expect(restored.imageCapturedAt, isNull);
  });

  test('does not persist legacy Mapillary metadata', () {
    final value = SavedEcoPartnerCodec.toJson(
      EcoPartner(
        id: _partner.id,
        name: _partner.name,
        category: _partner.category,
        subtype: _partner.subtype,
        latitude: _partner.latitude,
        longitude: _partner.longitude,
        address: _partner.address,
        sustainabilityLabel: _partner.sustainabilityLabel,
        evidence: _partner.evidence,
        sourceName: _partner.sourceName,
        sourceUrl: _partner.sourceUrl,
        lastUpdated: _partner.lastUpdated,
        imageUrl: 'https://legacy-street-images.invalid/example.jpg',
        imageSourceName: 'Nearby street-level image · Mapillary',
        imageSourceUrl: 'https://legacy-street-images.invalid/photo/1',
        imageCapturedAt: DateTime(2020),
      ),
    );

    expect(value['imageUrl'], isNull);
    expect(value['imageSourceName'], isNull);
    expect(value['imageSourceUrl'], isNull);
    expect(value['imageCapturedAt'], isNull);
  });
}

final _partner = EcoPartner(
  id: 'hotel:1',
  name: 'Eco Lodge',
  category: EcoPartnerCategory.stay,
  subtype: 'Hotel',
  latitude: 5.98,
  longitude: 116.07,
  address: 'Kota Kinabalu, Sabah',
  sustainabilityLabel: 'GSTC verified',
  evidence: 'Verified evidence',
  sourceName: 'Test source',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
);

final _evPartner = EcoPartner(
  id: 'charger:1',
  name: 'Original charger',
  category: EcoPartnerCategory.transport,
  subtype: 'EV charging',
  latitude: 3.16,
  longitude: 101.72,
  address: 'Kuala Lumpur',
  sustainabilityLabel: 'EV charging infrastructure',
  evidence: 'Mapped charging station',
  sourceName: 'OpenStreetMap',
  sourceUrl: 'https://www.openstreetmap.org/node/1',
  lastUpdated: DateTime(2026),
  chargingDetails: const EcoChargingDetails(
    capacity: 1,
    access: 'yes',
    connectors: [
      EcoChargingConnector(type: 'type2', count: 2, output: '22 kW'),
    ],
  ),
);

class _MemorySavedEcoPartnerRepository
    implements SavedEcoPartnerRepositoryContract {
  final List<SavedEcoPartner> values = [];
  final List<String> deletedIds = [];

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    values.removeWhere((saved) => saved.id == id);
  }

  @override
  Future<List<SavedEcoPartner>> fetchAll() async => List.of(values);

  @override
  Future<SavedEcoPartner> save(EcoPartner partner) async {
    final saved = SavedEcoPartner(
      id: 'saved-1',
      partner: partner,
      savedAt: DateTime(2026),
    );
    values.insert(0, saved);
    return saved;
  }
}

class _MissingTableRepository implements SavedEcoPartnerRepositoryContract {
  static const _error = PostgrestException(
    message: "Could not find the table 'public.saved_eco_partners'",
    code: 'PGRST205',
  );

  @override
  Future<void> delete(String id) => Future.error(_error);

  @override
  Future<List<SavedEcoPartner>> fetchAll() => Future.error(_error);

  @override
  Future<SavedEcoPartner> save(EcoPartner partner) => Future.error(_error);
}
