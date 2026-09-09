import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/view/eco_partner_detail_screen.dart';
import 'package:collab/features/travel_assistant/view/widgets/transit_mode_icon.dart';
import 'package:collab/features/itinerary_planning/model/transitous_routing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('transit route identifiers check live in-app journeys', (
    tester,
  ) async {
    final partner = EcoPartner(
      id: 'stop:1',
      name: 'Kota Kinabalu transit stop',
      category: EcoPartnerCategory.transport,
      subtype: 'Bus',
      latitude: 5.9804,
      longitude: 116.0735,
      address: 'Kota Kinabalu, Sabah',
      sustainabilityLabel: 'Bus public transport',
      evidence: 'Official GTFS stop',
      sourceName: 'Official Malaysia GTFS',
      sourceUrl: 'https://developer.data.gov.my/',
      lastUpdated: DateTime(2026),
      transitRoutes: const [
        EcoTransitRouteInfo(
          mode: 'Bus',
          shortName: 'KGL',
          longName: 'Kota Kinabalu Local Bus',
        ),
        EcoTransitRouteInfo(mode: 'Bus', shortName: 'T1'),
        EcoTransitRouteInfo(
          mode: 'KTM',
          shortName: 'ETS',
          longName: 'Keretapi Tanah Melayu ETS',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: partner,
          destinationLabel: 'Kota Kinabalu',
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Kota Kinabalu Local Bus (KGL)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Scheduled routes serving this stop'), findsOneWidget);
    expect(find.text('Bus route T1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ActionChip, 'Keretapi Tanah Melayu ETS (ETS)'),
        matching: find.byIcon(Icons.train_outlined),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ActionChip>(
            find.widgetWithText(ActionChip, 'Kota Kinabalu Local Bus (KGL)'),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.textContaining('live journey is available'), findsOneWidget);
    expect(find.textContaining('Maps'), findsNothing);
  });

  testWidgets('no-coverage route is hidden while generic transit stays usable', (
    tester,
  ) async {
    final partner = _transitPartner(routeCount: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: partner,
          destinationLabel: 'Malaysia',
          transitService: _FailingTransitService(
            TransitRouteFailure.noCoverage,
          ),
          routeOriginLoader: () async => const LatLng(3.14, 101.69),
        ),
      ),
    );
    final firstRoute = find.text('Test route 1 (T1)');
    await tester.scrollUntilVisible(
      firstRoute,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();

    await tester.tap(firstRoute);
    await tester.pumpAndSettle();

    expect(find.text('Test route 1 (T1)'), findsNothing);
    expect(find.text('Test route 2 (T2)'), findsOneWidget);
    expect(
      find.text(
        'That route isn’t available for a live trip from your location. Try another route.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Show route'), findsOneWidget);
  });

  testWidgets('scheduled-route section collapses when its last route fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: _transitPartner(routeCount: 1),
          destinationLabel: 'Malaysia',
          transitService: _FailingTransitService(
            TransitRouteFailure.noCoverage,
          ),
          routeOriginLoader: () async => const LatLng(3.14, 101.69),
        ),
      ),
    );
    final firstRoute = find.text('Test route 1 (T1)');
    await tester.scrollUntilVisible(
      firstRoute,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();

    await tester.tap(firstRoute);
    await tester.pumpAndSettle();

    expect(find.text('Scheduled routes serving this stop'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Show route'), findsOneWidget);
  });

  testWidgets('retryable transit failure keeps the route chip visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: _transitPartner(routeCount: 1),
          destinationLabel: 'Malaysia',
          transitService: _FailingTransitService(
            TransitRouteFailure.connection,
          ),
          routeOriginLoader: () async => const LatLng(3.14, 101.69),
        ),
      ),
    );
    final firstRoute = find.text('Test route 1 (T1)');
    await tester.scrollUntilVisible(
      firstRoute,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();

    await tester.tap(firstRoute);
    await tester.pumpAndSettle();

    expect(find.text('Test route 1 (T1)'), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsOneWidget);
  });

  test('transit icons recognize Transitous and Malaysian rail modes', () {
    for (final mode in const [
      'RAIL',
      'HIGHSPEED_RAIL',
      'LONG_DISTANCE',
      'REGIONAL_RAIL',
      'SUBURBAN',
      'SUBWAY',
      'KTM',
      'ETS',
      'MRT',
      'LRT',
      'Monorail',
      'Light rail',
    ]) {
      expect(transitModeIcon(mode), Icons.train_outlined, reason: mode);
    }

    expect(transitModeIcon('BUS'), Icons.directions_bus_outlined);
    expect(transitModeIcon('WALK'), Icons.directions_walk);
    expect(
      transitModeIcon('unexpected transit mode'),
      Icons.directions_transit,
    );
  });

  testWidgets('charging and source details use friendly language', (
    tester,
  ) async {
    final charger = EcoPartner(
      id: 'charger:friendly',
      name: 'City charger',
      category: EcoPartnerCategory.transport,
      subtype: 'EV charging',
      latitude: 3.14,
      longitude: 101.69,
      address: 'Kuala Lumpur',
      sustainabilityLabel: 'EV charging infrastructure',
      evidence: 'Mapped charging station',
      sourceName: 'OpenStreetMap via Nominatim',
      sourceUrl: 'https://www.openstreetmap.org/node/42',
      lastUpdated: DateTime(2026, 9, 6),
      imageSourceName: 'Nearby street-level image · Mapillary',
      imageSourceUrl: 'https://www.mapillary.com/app/?pKey=42',
      imageCapturedAt: DateTime(2020),
      chargingDetails: const EcoChargingDetails(
        capacity: 1,
        access: 'yes',
        operatorName: 'ChargeCo',
        connectors: [
          EcoChargingConnector(type: 'type2', count: 2, output: '22 kW'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: charger,
          destinationLabel: 'Kuala Lumpur',
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Source & freshness'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1 charging point'), findsOneWidget);
    expect(find.text('Open to the public'), findsOneWidget);
    expect(find.text('2 × Type 2 · up to 22 kW'), findsOneWidget);
    expect(find.text('Operated by ChargeCo'), findsOneWidget);
    expect(
      find.text('Place information from OpenStreetMap contributors'),
      findsOneWidget,
    );
    expect(find.text('Last checked 6 September 2026'), findsOneWidget);
    expect(
      find.text('Street-level photo from Mapillary · Captured in 2020'),
      findsOneWidget,
    );
    expect(find.byTooltip('Open place information source'), findsOneWidget);
    expect(find.byTooltip('Open photo source'), findsOneWidget);
    expect(find.textContaining('capacity:'), findsNothing);
    expect(find.textContaining('access: yes'), findsNothing);
    expect(find.textContaining('operator:'), findsNothing);
    expect(find.textContaining('via Nominatim'), findsNothing);
  });

  testWidgets('empty charging metadata does not show a charging card', (
    tester,
  ) async {
    final charger = EcoPartner(
      id: 'charger:empty',
      name: 'Unspecified charger',
      category: EcoPartnerCategory.transport,
      subtype: 'EV charging',
      latitude: 3.14,
      longitude: 101.69,
      address: 'Kuala Lumpur',
      sustainabilityLabel: 'EV charging infrastructure',
      evidence: 'Mapped charging station',
      sourceName: 'OpenStreetMap',
      sourceUrl: 'https://www.openstreetmap.org/node/43',
      lastUpdated: DateTime(2026, 9, 6),
      chargingDetails: const EcoChargingDetails(operatorName: 'yes'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: charger,
          destinationLabel: 'Kuala Lumpur',
        ),
      ),
    );

    expect(find.text('Charging details'), findsNothing);
  });

  testWidgets('legacy in-memory charger metadata still renders', (
    tester,
  ) async {
    final charger = EcoPartner(
      id: 'charger:legacy',
      name: 'Legacy charger',
      category: EcoPartnerCategory.transport,
      subtype: 'EV charging',
      latitude: 3.14,
      longitude: 101.69,
      address: 'Kuala Lumpur',
      sustainabilityLabel: 'EV charging infrastructure',
      evidence: 'Mapped charging station',
      sourceName: 'OpenStreetMap via Nominatim',
      sourceUrl: 'https://www.openstreetmap.org/node/44',
      lastUpdated: DateTime(2026, 9, 6),
      chargerDetails: 'capacity: 1 · access: yes',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: charger,
          destinationLabel: 'Kuala Lumpur',
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Charging details'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1 charging point'), findsOneWidget);
    expect(find.text('Open to the public'), findsOneWidget);
    expect(find.textContaining('capacity:'), findsNothing);
  });

  testWidgets('distance is hidden without a user-location reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: _detailPartner,
          destinationLabel: 'Malaysia',
        ),
      ),
    );

    expect(find.textContaining('0.0 km away'), findsNothing);
  });

  testWidgets('transport details use the station name when address is absent', (
    tester,
  ) async {
    final station = EcoPartner(
      id: 'stop:blank-address',
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

    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: station,
          destinationLabel: 'Malaysia',
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Bukit Bintang MRT, Malaysia'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Bukit Bintang MRT, Malaysia'), findsOneWidget);
    expect(find.text('Location available on the map'), findsNothing);
  });

  testWidgets('distance is shown for current-location results', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: _detailPartner.withDistance(6.4),
          destinationLabel: 'Current location',
          showDistance: true,
        ),
      ),
    );

    expect(find.text('6.4 km away'), findsOneWidget);
  });

  testWidgets('far search result shows its nearby-area status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerDetailScreen(
          partner: _detailPartner.withDistance(243.7),
          destinationLabel: 'Eco Partner name search',
          showDistance: true,
          outsideRadiusKm: 50,
        ),
      ),
    );

    expect(find.text('243.7 km away'), findsOneWidget);
    expect(find.text('Outside your 50 km area'), findsOneWidget);
  });
}

final _detailPartner = EcoPartner(
  id: 'hotel:detail',
  name: 'Detail Eco Hotel',
  category: EcoPartnerCategory.stay,
  subtype: 'Hotel',
  latitude: 3.14,
  longitude: 101.69,
  address: 'Kuala Lumpur',
  sustainabilityLabel: 'GSTC verified',
  evidence: 'Verified evidence',
  sourceName: 'Test source',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
);

EcoPartner _transitPartner({required int routeCount}) => EcoPartner(
  id: 'stop:test',
  name: 'Test stop',
  category: EcoPartnerCategory.transport,
  subtype: 'Bus',
  latitude: 3.15,
  longitude: 101.7,
  address: 'Test road',
  sustainabilityLabel: 'Public transport',
  evidence: 'Official GTFS stop',
  sourceName: 'Official Malaysia GTFS',
  sourceUrl: 'https://developer.data.gov.my/',
  lastUpdated: DateTime(2026),
  transitRoutes: [
    for (var index = 1; index <= routeCount; index++)
      EcoTransitRouteInfo(
        mode: 'Bus',
        shortName: 'T$index',
        longName: 'Test route $index',
      ),
  ],
);

class _FailingTransitService extends TransitousRoutingService {
  _FailingTransitService(this.failure);

  final TransitRouteFailure failure;

  @override
  Future<TransitRoute> planOrThrow(
    LatLng from,
    LatLng to, {
    Iterable<String> preferredRouteNames = const [],
    String? preferredRouteLabel,
  }) async => throw TransitRouteException(failure, 'Technical provider error');
}
