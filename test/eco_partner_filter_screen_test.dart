import 'package:collab/features/travel_prep/controller/eco_partner_controller.dart';
import 'package:collab/features/travel_prep/model/eco_partner.dart';
import 'package:collab/features/travel_prep/model/eco_partner_repository.dart';
import 'package:collab/features/travel_prep/view/eco_partner_screen.dart';
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
    expect(find.text('Hotels'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('EV Charging'), findsOneWidget);
    expect(find.byTooltip('Change results layout'), findsNothing);
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
