import 'package:collab/features/travel_assistant/controller/eco_partner_controller.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Eco Partner search scopes', () {
    test(
      'statewide selection sends the stored state to the repository',
      () async {
        final repository = _RecordingRepository();
        final controller = EcoPartnerController(repository: repository)
          ..result = _emptyResult
          ..currentPage = 2;

        await controller.applySearchArea(
          mode: EcoPartnerAreaMode.statewide,
          radius: 25,
          state: 'Sabah',
        );

        expect(repository.coordinateSearches, 1);
        expect(repository.lastScope?.type, EcoPartnerSearchScopeType.state);
        expect(repository.lastScope?.state, 'Sabah');
        expect(controller.currentPage, 0);
        expect(controller.scopeLabel, 'in Sabah');
      },
    );

    test(
      'nearby scope keeps the selected radius for the spatial RPC',
      () async {
        final controller = EcoPartnerController(
          repository: _RecordingRepository(),
        );
        await controller.applySearchArea(
          mode: EcoPartnerAreaMode.nearby,
          radius: 25,
          state: 'Sarawak',
        );
        expect(controller.searchScope.type, EcoPartnerSearchScopeType.nearby);
        expect(controller.searchScope.radiusKm, 25);
      },
    );

    test('all Malaysia maps to nationwide without geocoding', () async {
      final controller = EcoPartnerController(
        repository: _RecordingRepository(),
      );
      await controller.applySearchArea(
        mode: EcoPartnerAreaMode.statewide,
        radius: 10,
        state: 'All Malaysia',
      );
      expect(controller.searchScope.type, EcoPartnerSearchScopeType.nationwide);
      expect(controller.scopeLabel, 'across Malaysia');
    });
  });

  group('EcoTransitRouteInfo', () {
    test('uses the official long name with its route code', () {
      const route = EcoTransitRouteInfo(
        mode: 'Bus',
        shortName: 'KGL',
        longName: 'Kota Kinabalu Local Bus',
      );
      expect(route.displayLabel, 'Kota Kinabalu Local Bus (KGL)');
    });

    test('uses a human-readable route fallback', () {
      const route = EcoTransitRouteInfo(mode: 'Bus', shortName: 'KGL');
      expect(route.displayLabel, 'Bus route KGL');
    });
  });
}

const _emptyResult = EcoPartnerSearchResult(
  destination: EcoDestination('Origin', 3.14, 101.69),
  partners: [],
);

class _RecordingRepository implements EcoPartnerRepositoryContract {
  int coordinateSearches = 0;
  EcoPartnerSearchScope? lastScope;

  @override
  Future<EcoPartnerSearchResult> searchCoordinates(
    EcoDestination destination, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async {
    coordinateSearches++;
    lastScope = scope;
    return EcoPartnerSearchResult(destination: destination, partners: const []);
  }

  @override
  Future<EcoPartnerSearchResult> searchByName(
    String query, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async {
    lastScope = scope;
    return _emptyResult;
  }

  @override
  Future<EcoPartnerSearchResult> enrichResult(
    EcoPartnerSearchResult value, {
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
  }) async => value;
}
