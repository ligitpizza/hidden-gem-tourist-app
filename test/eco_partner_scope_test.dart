import 'package:collab/features/travel_assistant/controller/eco_partner_controller.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Eco Partner search scopes', () {
    test(
      'statewide selection refreshes once with the selected state',
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
        expect(controller.radiusSelection, 25);
        expect(controller.scopeLabel, 'in Sabah');
      },
    );

    test(
      'nearby and statewide selections are preserved independently',
      () async {
        final controller = EcoPartnerController(
          repository: _RecordingRepository(),
        );

        await controller.applySearchArea(
          mode: EcoPartnerAreaMode.statewide,
          radius: 25,
          state: 'Sarawak',
        );
        await controller.applySearchArea(
          mode: EcoPartnerAreaMode.nearby,
          radius: 25,
          state: 'Sarawak',
        );

        expect(controller.radiusSelection, 25);
        expect(controller.stateFilter, 'Sarawak');
        expect(controller.searchScope.type, EcoPartnerSearchScopeType.nearby);
      },
    );

    test('all Malaysia maps to a nationwide scope', () async {
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

    test('specific states are resolved and passed to every provider', () async {
      final hotels = _RecordingHotelSource();
      final map = _RecordingMapSource();
      final transit = _RecordingTransitSource();
      final repository = EcoPartnerRepository(
        hotels: hotels,
        map: map,
        transit: transit,
        images: _PassthroughImages(),
        stateBoundsResolver: _BoundsResolver(),
      );

      await repository.searchCoordinates(
        const EcoDestination('Origin', 3.14, 101.69),
        scope: const EcoPartnerSearchScope.state('Sabah'),
        includeImages: false,
      );

      for (final scope in [hotels.scope, map.scope, transit.scope]) {
        expect(scope?.type, EcoPartnerSearchScopeType.state);
        expect(scope?.state, 'Sabah');
        expect(scope?.bounds?.south, 4.0);
        expect(scope?.bounds?.east, 119.3);
      }
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

    test('uses a human-readable fallback without inventing an expansion', () {
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
  Future<EcoPartnerSearchResult> searchDestination(
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

class _RecordingHotelSource implements EcoHotelSource {
  EcoPartnerSearchScope? scope;

  @override
  Future<List<EcoPartner>> search(
    EcoDestination destination, {
    required EcoPartnerSearchScope scope,
  }) async {
    this.scope = scope;
    return const [];
  }
}

class _RecordingMapSource implements EcoMapSource {
  EcoPartnerSearchScope? scope;

  @override
  Future<List<EcoPartner>> search(
    EcoDestination destination, {
    required EcoPartnerSearchScope scope,
  }) async {
    this.scope = scope;
    return const [];
  }
}

class _RecordingTransitSource implements EcoTransitSource {
  EcoPartnerSearchScope? scope;

  @override
  Future<List<EcoPartner>> search(
    EcoDestination destination, {
    required EcoPartnerSearchScope scope,
  }) async {
    this.scope = scope;
    return const [];
  }
}

class _PassthroughImages implements EcoPartnerImageSource {
  @override
  Future<List<EcoPartner>> enrich(List<EcoPartner> partners) async => partners;
}

class _BoundsResolver implements EcoStateBoundsResolver {
  @override
  Future<EcoGeoBounds?> resolve(String state) async =>
      const EcoGeoBounds(south: 4.0, north: 7.5, west: 115.0, east: 119.3);
}
