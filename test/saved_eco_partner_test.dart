import 'package:collab/features/travel_prep/model/eco_partner.dart';
import 'package:collab/features/travel_prep/model/saved_eco_partner.dart';
import 'package:collab/features/travel_prep/model/saved_eco_partner_repository.dart';
import 'package:collab/features/travel_prep/model/saved_eco_partners_store.dart';
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
