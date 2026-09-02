import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/view/eco_partner_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transit route identifiers are actionable', (tester) async {
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

    expect(find.text('Transit routes serving this stop'), findsOneWidget);
    expect(find.text('Bus route T1'), findsOneWidget);
    expect(
      tester
          .widget<ActionChip>(
            find.widgetWithText(ActionChip, 'Kota Kinabalu Local Bus (KGL)'),
          )
          .onPressed,
      isNotNull,
    );
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
