import 'package:collab/features/travel_assistant/controller/eco_partner_controller.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial recommendations load nationwide without geolocation', () async {
    final repository = _CatalogRepository(_catalog);
    final controller = EcoPartnerController(repository: repository);

    await controller.loadInitialRecommendations();

    expect(repository.coordinateSearches, 1);
    expect(repository.lastDestination?.label, 'Malaysia');
    expect(repository.lastScope?.type, EcoPartnerSearchScopeType.nationwide);
    expect(controller.scopeLabel, 'across Malaysia');
    expect(controller.filteredPartners, hasLength(_catalog.length));
  });

  test('search matches normalized partner names only', () async {
    final repository = _CatalogRepository(_catalog);
    final controller = EcoPartnerController(repository: repository);
    await controller.loadInitialRecommendations();

    await controller.search('SOMERSET');
    expect(controller.filteredPartners.map((partner) => partner.name), [
      'Somerset Alpha',
      'Somerset Beta',
      'Hotel Somerset',
    ]);
    expect(controller.filteredPartners, isNot(contains(_addressOnlyMatch)));

    await controller.search('somerset-alpha');
    expect(controller.filteredPartners.map((partner) => partner.name), [
      'Somerset Alpha',
    ]);
  });

  test(
    'suggestions use distinct catalog names and prioritize prefixes',
    () async {
      final repository = _CatalogRepository([
        ..._catalog,
        _partner('Somerset Alpha', 99),
      ]);
      final controller = EcoPartnerController(repository: repository);
      await controller.loadInitialRecommendations();

      expect(controller.suggestionsFor('s'), isEmpty);
      expect(controller.suggestionsFor('so').map((partner) => partner.name), [
        'Somerset Alpha',
        'Somerset Beta',
        'Hotel Somerset',
      ]);
    },
  );

  test('suggestions are capped at six results', () async {
    final repository = _CatalogRepository([
      for (var index = 0; index < 8; index++)
        _partner('Somerset ${String.fromCharCode(65 + index)}', index),
    ]);
    final controller = EcoPartnerController(repository: repository);
    await controller.loadInitialRecommendations();

    expect(controller.suggestionsFor('so'), hasLength(6));
  });

  test(
    'selecting a suggestion uses the catalog and clear restores initial',
    () async {
      final repository = _CatalogRepository(_catalog);
      final controller = EcoPartnerController(repository: repository);
      await controller.loadInitialRecommendations();
      final suggestion = controller.suggestionsFor('alpha').single;

      await controller.searchSuggestion(suggestion);

      expect(repository.coordinateSearches, 1);
      expect(controller.result?.destination.label, 'Eco Partner name search');
      expect(controller.filteredPartners.map((partner) => partner.name), [
        'Somerset Alpha',
      ]);

      await controller.clearSearch();
      expect(controller.activeSearchTerm, isEmpty);
      expect(controller.result?.destination.label, 'Malaysia');
      expect(controller.filteredPartners, hasLength(_catalog.length));
    },
  );

  test('submitting an exact suggestion name bypasses geocoding', () async {
    final repository = _CatalogRepository(_catalog);
    final controller = EcoPartnerController(repository: repository);
    await controller.loadInitialRecommendations();

    await controller.search('Somerset Alpha');

    expect(repository.coordinateSearches, 1);
    expect(repository.destinationSearches, 0);
    expect(controller.result?.destination.label, 'Eco Partner name search');
  });

  test(
    'far name search bypasses nearby filters and restores browse state',
    () async {
      final nearby = _partner(
        'Nearby Dining',
        50,
        latitude: 3.14,
        longitude: 101.69,
        category: EcoPartnerCategory.dining,
        subtype: 'Restaurant',
      );
      final far = _partner(
        'Far Eco Hotel',
        51,
        latitude: 5.98,
        longitude: 116.07,
      );
      final repository = _CatalogRepository([nearby, far]);
      final controller =
          EcoPartnerController(
              repository: repository,
              currentLocationLoader: () async =>
                  const EcoDestination('Current location', 3.139, 101.687),
            )
            ..areaMode = EcoPartnerAreaMode.nearby
            ..radiusSelection = 50;

      await controller.loadInitialRecommendations();
      controller.areaMode = EcoPartnerAreaMode.nearby;
      controller.radiusSelection = 50;
      expect(await controller.useCurrentLocation(), isTrue);
      controller.selectFilter('Dining');
      controller.selectLayout(EcoPartnerLayout.grid2);
      controller.currentPage = 1;
      final browseResult = controller.result;

      await controller.search('Far Eco');

      expect(controller.isExplicitSearch, isTrue);
      expect(controller.scopeLabel, 'across Malaysia');
      expect(controller.filteredPartners, [isA<EcoPartner>()]);
      final match = controller.filteredPartners.single;
      expect(match.name, 'Far Eco Hotel');
      expect(match.distanceKm, greaterThan(1000));
      expect(controller.showsUserDistance, isTrue);
      expect(controller.activeNearbyRadius, 50);
      expect(controller.isOutsideBrowseRadius(match), isTrue);
      expect(repository.coordinateSearches, 2);

      await controller.clearSearch();

      expect(controller.isExplicitSearch, isFalse);
      expect(controller.result, same(browseResult));
      expect(controller.result?.destination.label, 'Current location');
      expect(controller.filter, 'Dining');
      expect(controller.layout, EcoPartnerLayout.grid2);
      expect(controller.currentPage, 1);
      expect(controller.radiusSelection, 50);
    },
  );

  test('nearby browsing still excludes partners outside the radius', () async {
    final nearby = _partner(
      'Nearby Hotel',
      60,
      latitude: 3.14,
      longitude: 101.69,
    );
    final far = _partner('Far Hotel', 61, latitude: 5.98, longitude: 116.07);
    final controller =
        EcoPartnerController(
            repository: _CatalogRepository([nearby, far]),
            currentLocationLoader: () async =>
                const EcoDestination('Current location', 3.139, 101.687),
          )
          ..areaMode = EcoPartnerAreaMode.nearby
          ..radiusSelection = 50;

    expect(await controller.useCurrentLocation(), isTrue);

    expect(controller.result?.partners.map((partner) => partner.name), [
      'Nearby Hotel',
    ]);
    expect(controller.isUsingCurrentLocation, isTrue);
    expect(controller.showsUserDistance, isTrue);
  });

  test(
    'failed nationwide fallback preserves the nearby browse result',
    () async {
      final repository = _FailingNationwideRepository(
        _partner('Nearby Hotel', 70, latitude: 3.14, longitude: 101.69),
      );
      final controller =
          EcoPartnerController(
              repository: repository,
              currentLocationLoader: () async =>
                  const EcoDestination('Current location', 3.139, 101.687),
            )
            ..areaMode = EcoPartnerAreaMode.nearby
            ..radiusSelection = 50;

      expect(await controller.useCurrentLocation(), isTrue);
      final browseResult = controller.result;

      await controller.search('Missing Partner');

      expect(controller.isExplicitSearch, isFalse);
      expect(controller.result, same(browseResult));
      expect(controller.result?.destination.label, 'Current location');
      expect(
        controller.error,
        'Search failed. Check your connection and retry.',
      );
    },
  );

  test('compact pagination uses eight cards and resets the page', () {
    final controller = EcoPartnerController(repository: _CatalogRepository([]))
      ..result = EcoPartnerSearchResult(
        destination: const EcoDestination('Malaysia', 4.21, 101.97),
        partners: [
          for (var index = 0; index < 12; index++)
            _partner('Partner $index', index),
        ],
      );

    expect(controller.visiblePartners, hasLength(10));
    controller.goToPage(1);
    expect(controller.currentPage, 1);

    controller.selectLayout(EcoPartnerLayout.grid4);
    expect(controller.currentPage, 0);
    expect(controller.effectivePageSize, 8);
    expect(controller.visiblePartners, hasLength(8));
    expect(controller.totalPages, 2);

    controller.selectLayout(EcoPartnerLayout.grid2);
    expect(controller.effectivePageSize, 10);
  });

  test('home sections are ordered, categorized, capped, and diversified', () {
    final homeCatalog = [
      _partner('Hotel One', 20),
      _partner(
        'Dining One',
        21,
        category: EcoPartnerCategory.dining,
        subtype: 'Restaurant',
      ),
      _partner(
        'Bus One',
        22,
        category: EcoPartnerCategory.transport,
        subtype: 'Bus',
      ),
      _partner(
        'EV One',
        23,
        category: EcoPartnerCategory.transport,
        subtype: 'EV charging',
      ),
      for (var index = 0; index < 8; index++)
        _partner('Hotel Extra $index', 30 + index),
    ];
    final controller = EcoPartnerController(repository: _CatalogRepository([]))
      ..result = EcoPartnerSearchResult(
        destination: const EcoDestination('Malaysia', 4.21, 101.97),
        partners: homeCatalog,
      );

    expect(EcoPartnerHomeSection.values, [
      EcoPartnerHomeSection.recommended,
      EcoPartnerHomeSection.hotel,
      EcoPartnerHomeSection.dining,
      EcoPartnerHomeSection.transport,
      EcoPartnerHomeSection.ev,
    ]);
    final recommended = controller.partnersForHomeSection(
      EcoPartnerHomeSection.recommended,
    );
    expect(recommended, hasLength(8));
    expect(recommended.map((partner) => partner.id).toSet(), hasLength(8));
    expect(recommended.take(4).map((partner) => partner.name), [
      'Hotel One',
      'Dining One',
      'Bus One',
      'EV One',
    ]);
    expect(
      controller
          .partnersForHomeSection(EcoPartnerHomeSection.hotel)
          .every((partner) => partner.category == EcoPartnerCategory.stay),
      isTrue,
    );
    expect(
      controller.partnersForHomeSection(EcoPartnerHomeSection.hotel),
      hasLength(8),
    );
    expect(
      controller
          .partnersForHomeSection(EcoPartnerHomeSection.dining)
          .single
          .name,
      'Dining One',
    );
    expect(
      controller
          .partnersForHomeSection(EcoPartnerHomeSection.transport)
          .single
          .subtype,
      'Bus',
    );
    expect(
      controller
          .partnersForHomeSection(EcoPartnerHomeSection.ev)
          .single
          .subtype,
      'EV charging',
    );
  });

  test('searches and category filters leave the sectioned home', () {
    final controller = EcoPartnerController(repository: _CatalogRepository([]));

    expect(controller.showSectionedHome, isTrue);
    controller.activeSearchTerm = 'Somerset';
    expect(controller.showSectionedHome, isFalse);
    controller.activeSearchTerm = '';
    controller.selectFilter('Dining');
    expect(controller.showSectionedHome, isFalse);
  });

  test('denied current location restores the previous search area', () async {
    final controller = _DeniedLocationController(_CatalogRepository(_catalog))
      ..areaMode = EcoPartnerAreaMode.statewide
      ..stateFilter = 'Sabah'
      ..radiusSelection = 25
      ..currentPage = 1;

    await controller.applySearchArea(
      mode: EcoPartnerAreaMode.nearby,
      radius: 5,
      state: 'All Malaysia',
      useCurrentLocation: true,
    );

    expect(controller.areaMode, EcoPartnerAreaMode.statewide);
    expect(controller.stateFilter, 'Sabah');
    expect(controller.radiusSelection, 25);
    expect(controller.currentPage, 1);
  });
}

final _addressOnlyMatch = _partner(
  'Green Residence',
  4,
  address: 'Somerset Road, Kuala Lumpur',
);

final _catalog = [
  _partner('Somerset Alpha', 1),
  _partner('Somerset Beta', 2),
  _partner('Hotel Somerset', 3),
  _addressOnlyMatch,
  _partner('Unrelated Eco Lodge', 5),
];

EcoPartner _partner(
  String name,
  int index, {
  String? address,
  EcoPartnerCategory category = EcoPartnerCategory.stay,
  String subtype = 'Hotel',
  double? latitude,
  double? longitude,
}) => EcoPartner(
  id: 'partner:$index:$name',
  name: name,
  category: category,
  subtype: subtype,
  latitude: latitude ?? 3.1 + index / 100,
  longitude: longitude ?? 101.6 + index / 100,
  address: address ?? 'Kuala Lumpur',
  sustainabilityLabel: 'Verified sustainable stay',
  evidence: 'Test evidence',
  sourceName: 'Test source',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
);

class _CatalogRepository implements EcoPartnerRepositoryContract {
  _CatalogRepository(this.partners);

  final List<EcoPartner> partners;
  int coordinateSearches = 0;
  int destinationSearches = 0;
  EcoDestination? lastDestination;
  EcoPartnerSearchScope? lastScope;

  @override
  Future<EcoPartnerSearchResult> searchCoordinates(
    EcoDestination destination, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async {
    coordinateSearches++;
    lastDestination = destination;
    lastScope = scope;
    final withDistances = partners
        .map(
          (partner) => partner.withDistance(
            EcoPartnerRepository.distanceKm(
              destination.latitude,
              destination.longitude,
              partner.latitude,
              partner.longitude,
            ),
          ),
        )
        .where(
          (partner) =>
              scope.type != EcoPartnerSearchScopeType.nearby ||
              partner.distanceKm <= scope.radiusKm!,
        )
        .toList();
    return EcoPartnerSearchResult(
      destination: destination,
      partners: withDistances,
    );
  }

  @override
  Future<EcoPartnerSearchResult> searchDestination(
    String query, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async {
    destinationSearches++;
    lastScope = scope;
    return EcoPartnerSearchResult(
      destination: const EcoDestination('Search result', 3.14, 101.69),
      partners: partners,
    );
  }

  @override
  Future<EcoPartnerSearchResult> enrichResult(
    EcoPartnerSearchResult value, {
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
  }) async => value;
}

class _DeniedLocationController extends EcoPartnerController {
  _DeniedLocationController(EcoPartnerRepositoryContract repository)
    : super(repository: repository);

  @override
  Future<bool> useCurrentLocation({
    bool silentPermissionDenial = false,
  }) async => false;
}

class _FailingNationwideRepository implements EcoPartnerRepositoryContract {
  _FailingNationwideRepository(this.partner);

  final EcoPartner partner;

  @override
  Future<EcoPartnerSearchResult> searchCoordinates(
    EcoDestination destination, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async {
    if (scope.type == EcoPartnerSearchScopeType.nationwide) {
      throw StateError('Nationwide provider unavailable');
    }
    return EcoPartnerSearchResult(
      destination: destination,
      partners: [partner.withDistance(1)],
    );
  }

  @override
  Future<EcoPartnerSearchResult> searchDestination(
    String query, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async => throw UnimplementedError();

  @override
  Future<EcoPartnerSearchResult> enrichResult(
    EcoPartnerSearchResult value, {
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
  }) async => value;
}
