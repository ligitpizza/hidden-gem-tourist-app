import 'package:collab/features/travel_assistant/controller/eco_partner_controller.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/eco_partner_repository.dart';
import 'package:collab/features/travel_assistant/view/eco_partner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads nationwide recommendations without requesting location', (
    tester,
  ) async {
    final repository = _CatalogScreenRepository([_partner]);
    final controller = _InitialScreenController(repository);

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(repository.coordinateSearches, 1);
    expect(repository.lastScope?.type, EcoPartnerSearchScopeType.nationwide);
    expect(controller.locationRequests, 0);
    expect(find.text('Eco Lodge'), findsNWidgets(2));
    expect(find.text('across Malaysia'), findsOneWidget);
    expect(find.text('Recommended for You'), findsOneWidget);
    expect(find.text('Hotels'), findsNWidgets(2));
    expect(find.text('Dining'), findsOneWidget);
    expect(find.text('Transport (MRT, LRT, etc.)'), findsOneWidget);
    expect(find.text('EV Charging'), findsOneWidget);
    expect(find.byTooltip('Change results layout'), findsNothing);
    expect(
      find.byKey(const ValueKey('eco_partner_more_recommended')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('eco_partner_more_hotel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('eco_partner_more_dining')), findsNothing);
  });

  testWidgets('home rows keep eight previews and append category More cards', (
    tester,
  ) async {
    final repository = _CatalogScreenRepository([
      for (var index = 0; index < 9; index++)
        _categoryPartner(
          'Hotel $index',
          index,
          category: EcoPartnerCategory.stay,
          subtype: 'Hotel',
        ),
      _categoryPartner(
        'Dining One',
        20,
        category: EcoPartnerCategory.dining,
        subtype: 'Restaurant',
      ),
      _categoryPartner(
        'Bus One',
        21,
        category: EcoPartnerCategory.transport,
        subtype: 'Bus',
      ),
      _categoryPartner(
        'EV One',
        22,
        category: EcoPartnerCategory.transport,
        subtype: 'EV charging',
      ),
    ]);
    final controller = _InitialScreenController(repository);

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    int itemCount(EcoPartnerHomeSection section) {
      final childCount = tester
          .widget<ListView>(
            find.byKey(ValueKey('eco_partner_home_list_${section.name}')),
          )
          .childrenDelegate
          .estimatedChildCount!;
      // ListView.separated includes separators in its estimated child count.
      return (childCount + 1) ~/ 2;
    }

    expect(itemCount(EcoPartnerHomeSection.recommended), 8);
    expect(itemCount(EcoPartnerHomeSection.hotel), 9);
    expect(itemCount(EcoPartnerHomeSection.dining), 2);
    expect(itemCount(EcoPartnerHomeSection.transport), 2);
    expect(itemCount(EcoPartnerHomeSection.ev), 2);
    expect(
      find.byKey(const ValueKey('eco_partner_more_recommended')),
      findsNothing,
    );
  });

  testWidgets('each category More card opens its full filtered results', (
    tester,
  ) async {
    const cases = {
      EcoPartnerHomeSection.hotel: (
        filter: 'Stay',
        category: EcoPartnerCategory.stay,
        subtype: 'Hotel',
      ),
      EcoPartnerHomeSection.dining: (
        filter: 'Dining',
        category: EcoPartnerCategory.dining,
        subtype: 'Restaurant',
      ),
      EcoPartnerHomeSection.transport: (
        filter: 'Public Transport',
        category: EcoPartnerCategory.transport,
        subtype: 'Bus',
      ),
      EcoPartnerHomeSection.ev: (
        filter: 'EV Charging',
        category: EcoPartnerCategory.transport,
        subtype: 'EV charging',
      ),
    };

    for (final entry in cases.entries) {
      final section = entry.key;
      final value = entry.value;
      final repository = _CatalogScreenRepository([
        _categoryPartner(
          '${section.name} partner',
          section.index,
          category: value.category,
          subtype: value.subtype,
        ),
      ]);
      final controller = _InitialScreenController(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: EcoPartnersScreen(
            key: ValueKey('more_case_${section.name}'),
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final more = find.byKey(ValueKey('eco_partner_more_${section.name}'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(controller.filter, value.filter);
      expect(controller.currentPage, 0);
      expect(repository.coordinateSearches, 1);
      expect(find.byTooltip('Change results layout'), findsOneWidget);
      for (final candidate in EcoPartnerHomeSection.values) {
        expect(
          find.byKey(ValueKey('eco_partner_more_${candidate.name}')),
          findsNothing,
        );
      }
    }
  });

  testWidgets('More preserves browse settings and resets the main scroll', (
    tester,
  ) async {
    final repository = _CatalogScreenRepository([_partner]);
    final controller = _InitialScreenController(repository);
    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    controller
      ..sort = EcoPartnerSort.nameDescending
      ..layout = EcoPartnerLayout.grid2
      ..areaMode = EcoPartnerAreaMode.statewide
      ..stateFilter = 'Sabah'
      ..currentPage = 4;
    final mainScroll = find.byKey(const ValueKey('eco_partner_main_scroll'));
    final mainScrollable = find
        .descendant(
          of: mainScroll,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    final more = find.byKey(const ValueKey('eco_partner_more_hotel'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(mainScrollable)
        .position
        .pixels;
    expect(before, greaterThan(0));

    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(mainScrollable).position.pixels, 0);
    expect(controller.filter, 'Stay');
    expect(controller.currentPage, 0);
    expect(controller.sort, EcoPartnerSort.nameDescending);
    expect(controller.layout, EcoPartnerLayout.grid2);
    expect(controller.areaMode, EcoPartnerAreaMode.statewide);
    expect(controller.stateFilter, 'Sabah');
    expect(repository.coordinateSearches, 1);
  });

  testWidgets('Up from category More returns to the Eco Partners home view', (
    tester,
  ) async {
    final controller = _InitialScreenController(_CatalogScreenRepository([
      _categoryPartner(
        'Hotel One',
        1,
        category: EcoPartnerCategory.stay,
        subtype: 'Hotel',
      ),
    ]));

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    final more = find.byKey(const ValueKey('eco_partner_more_hotel'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(controller.filter, 'Stay');

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(controller.filter, 'All');
    expect(find.byKey(const ValueKey('eco_partner_more_hotel')), findsOneWidget);
  });

  testWidgets('partner-name suggestions can be selected', (tester) async {
    final somerset = _screenPartner('Somerset Kuala Lumpur', 2);
    final repository = _CatalogScreenRepository([
      somerset,
      _screenPartner('Unrelated Eco Lodge', 3),
    ]);
    final controller = EcoPartnerController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'So');
    await tester.pumpAndSettle();

    final suggestion = find.widgetWithText(ListTile, 'Somerset Kuala Lumpur');
    expect(suggestion, findsOneWidget);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();

    expect(repository.coordinateSearches, 1);
    expect(controller.result?.destination.label, 'Eco Partner name search');
    expect(controller.filteredPartners.map((partner) => partner.name), [
      'Somerset Kuala Lumpur',
    ]);
    expect(find.text('Recommended for You'), findsNothing);
    expect(find.byTooltip('Change results layout'), findsOneWidget);
    expect(find.byKey(const ValueKey('eco_partner_more_hotel')), findsNothing);
  });

  testWidgets('compact grid renders four columns and eight cards', (
    tester,
  ) async {
    final repository = _CatalogScreenRepository([
      for (var index = 0; index < 10; index++)
        _screenPartner('Partner $index', index),
    ]);
    final controller = EcoPartnerController(repository: repository)
      ..layout = EcoPartnerLayout.grid4
      ..filter = 'Stay';

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
    expect(grid.childrenDelegate.estimatedChildCount, 8);
  });

  testWidgets('nearby and statewide filters expose the correct controls', (
    tester,
  ) async {
    final controller = _FilterTestController(_FilterRepository());
    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Filter recommendations'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('All MY'), findsNothing);
    expect(find.text('All Malaysia'), findsNothing);

    await tester.tap(find.text('Statewide'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.text('All Malaysia'), findsOneWidget);
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    final values = dropdown.items!.map((item) => item.value).toList();
    expect(
      values,
      containsAll(['All Malaysia', 'Sabah', 'Sarawak', 'Putrajaya']),
    );
  });

  testWidgets('the whole list card opens Eco Partner details', (tester) async {
    final controller = _FilterTestController(_FilterRepository())
      ..filter = 'Stay'
      ..result = EcoPartnerSearchResult(
        destination: const EcoDestination('Kota Kinabalu', 5.98, 116.07),
        partners: [_partner],
      );
    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.text('Eco Lodge'));
    await tester.pumpAndSettle();

    expect(find.text('Save Eco Partner'), findsOneWidget);
    expect(find.text('Partner Details'), findsOneWidget);
  });

  testWidgets('non-location results show address instead of zero distance', (
    tester,
  ) async {
    final controller = _FilterTestController(_FilterRepository())
      ..filter = 'Stay'
      ..result = EcoPartnerSearchResult(
        destination: const EcoDestination('Malaysia', 4.21, 101.97),
        partners: [_partner],
      );

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.textContaining('Kota Kinabalu, Sabah'), findsOneWidget);
    expect(find.textContaining('0.0 km'), findsNothing);
  });

  testWidgets('transport results use the station name when address is absent', (
    tester,
  ) async {
    final station = EcoPartner(
      id: 'stop:1',
      name: 'Bukit Bintang MRT',
      category: EcoPartnerCategory.transport,
      subtype: 'MRT',
      latitude: 3.146,
      longitude: 101.711,
      address: '',
      sustainabilityLabel: 'MRT public transport',
      evidence: 'Official GTFS stop',
      sourceName: 'Official Malaysia GTFS',
      sourceUrl: 'https://developer.data.gov.my/',
      lastUpdated: DateTime(2026),
    );
    final controller = _FilterTestController(_FilterRepository())
      ..filter = 'Public Transport'
      ..result = EcoPartnerSearchResult(
        destination: const EcoDestination('Malaysia', 4.21, 101.97),
        partners: [station],
      );

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.textContaining('Bukit Bintang MRT, Malaysia'), findsOneWidget);
    expect(find.text('Address unavailable'), findsNothing);
  });

  testWidgets('current-location results show calculated distance', (
    tester,
  ) async {
    final controller = EcoPartnerController(
      repository: _CatalogScreenRepository([_partner]),
      currentLocationLoader: () async =>
          const EcoDestination('Current location', 5.9422, 116.07),
    )..filter = 'Stay';

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    controller.areaMode = EcoPartnerAreaMode.nearby;
    controller.radiusSelection = 10;
    expect(await controller.useCurrentLocation(), isTrue);
    await tester.pumpAndSettle();

    expect(find.textContaining('4.2 km away'), findsOneWidget);
  });

  testWidgets('far name search explains and marks the bypassed radius', (
    tester,
  ) async {
    final far = EcoPartner(
      id: 'hotel:far',
      name: 'Far Eco Hotel',
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
    final controller = EcoPartnerController(
      repository: _CatalogScreenRepository([_partner, far]),
      currentLocationLoader: () async =>
          const EcoDestination('Current location', 3.139, 101.687),
    );

    await tester.pumpWidget(
      MaterialApp(home: EcoPartnersScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    controller.areaMode = EcoPartnerAreaMode.nearby;
    controller.radiusSelection = 50;
    await controller.useCurrentLocation();
    await controller.search('Far Eco');
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Your 50 km nearby filter is paused'),
      findsOneWidget,
    );
    expect(find.text('Outside your 50 km area'), findsOneWidget);
    expect(find.textContaining('0.0 km'), findsNothing);
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

class _FilterTestController extends EcoPartnerController {
  _FilterTestController(EcoPartnerRepositoryContract repository)
    : super(repository: repository);

  @override
  Future<bool> useCurrentLocation({
    bool silentPermissionDenial = false,
  }) async => false;

  @override
  Future<void> loadInitialRecommendations({bool refresh = false}) async {}
}

class _FilterRepository implements EcoPartnerRepositoryContract {
  @override
  Future<EcoPartnerSearchResult> searchCoordinates(
    EcoDestination destination, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async =>
      EcoPartnerSearchResult(destination: destination, partners: const []);

  @override
  Future<EcoPartnerSearchResult> searchDestination(
    String query, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async => const EcoPartnerSearchResult(
    destination: EcoDestination('Origin', 3.14, 101.69),
    partners: [],
  );

  @override
  Future<EcoPartnerSearchResult> enrichResult(
    EcoPartnerSearchResult value, {
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
  }) async => value;
}

class _InitialScreenController extends EcoPartnerController {
  _InitialScreenController(EcoPartnerRepositoryContract repository)
    : super(repository: repository);

  int locationRequests = 0;

  @override
  Future<bool> useCurrentLocation({bool silentPermissionDenial = false}) async {
    locationRequests++;
    return false;
  }
}

class _CatalogScreenRepository implements EcoPartnerRepositoryContract {
  _CatalogScreenRepository(this.partners);

  final List<EcoPartner> partners;
  int coordinateSearches = 0;
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
    return EcoPartnerSearchResult(
      destination: destination,
      partners: partners
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
          .toList(),
    );
  }

  @override
  Future<EcoPartnerSearchResult> searchDestination(
    String query, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) async => EcoPartnerSearchResult(
    destination: const EcoDestination('Search result', 3.14, 101.69),
    partners: partners,
  );

  @override
  Future<EcoPartnerSearchResult> enrichResult(
    EcoPartnerSearchResult value, {
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
  }) async => value;
}

EcoPartner _screenPartner(String name, int index) => EcoPartner(
  id: 'screen:$index',
  name: name,
  category: EcoPartnerCategory.stay,
  subtype: 'Hotel',
  latitude: 3.14 + index / 100,
  longitude: 101.69 + index / 100,
  address: 'Kuala Lumpur',
  sustainabilityLabel: 'GSTC verified',
  evidence: 'Verified evidence',
  sourceName: 'Test source',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
);

EcoPartner _categoryPartner(
  String name,
  int index, {
  required EcoPartnerCategory category,
  required String subtype,
}) => EcoPartner(
  id: 'category:$index:$name',
  name: name,
  category: category,
  subtype: subtype,
  latitude: 3.14 + index / 100,
  longitude: 101.69 + index / 100,
  address: 'Kuala Lumpur',
  sustainabilityLabel: 'Verified sustainable partner',
  evidence: 'Verified evidence',
  sourceName: 'Test source',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
);
