import 'package:collab/features/travel_prep/model/eco_partner.dart';
import 'package:collab/features/travel_prep/view/eco_partner_detail_screen.dart';
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
}
