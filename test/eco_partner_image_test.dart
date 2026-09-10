import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/view/widgets/eco_partner_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final value in <(String, String)>[
    ('Bus', 'Bus service'),
    ('MRT', 'MRT service'),
    ('LRT', 'LRT service'),
    ('Light rail', 'LRT service'),
    ('Monorail', 'Monorail service'),
    ('KTM', 'KTM service'),
    ('EV charging', 'EV charging'),
  ]) {
    testWidgets('shows a ${value.$2} fallback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 180,
            child: EcoPartnerImage(partner: _partner(value.$1)),
          ),
        ),
      );

      expect(find.text(value.$2), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  }

  testWidgets('shows a dining-specific fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 180,
          child: EcoPartnerImage(
            partner: _partner(
              'Restaurant',
              category: EcoPartnerCategory.dining,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Dining'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('does not load a legacy Mapillary URL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcoPartnerImage(
          partner: _partner(
            'Bus',
            imageUrl: 'https://legacy-street-images.invalid/example.jpg',
            imageSourceName: 'Mapillary',
          ),
        ),
      ),
    );

    expect(find.text('Bus service'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  test('shortens representative image credit on cards', () {
    expect(
      ecoPartnerPreviewCredit(
        _partner(
          'LRT',
          imageSourceName: 'Representative LRT image · A2613 · CC BY-SA 4.0',
        ),
      ),
      'Representative LRT image',
    );
    expect(
      ecoPartnerPreviewCredit(
        _partner(
          'EV charging',
          imageSourceName:
              'Representative EV charging image - Photo by Dean Fugate - Pexels License',
        ),
      ),
      'Representative EV charging image',
    );
  });
}

EcoPartner _partner(
  String subtype, {
  EcoPartnerCategory category = EcoPartnerCategory.transport,
  String? imageUrl,
  String? imageSourceName,
}) => EcoPartner(
  id: 'gtfs:stop',
  name: 'Transit stop',
  category: category,
  subtype: subtype,
  latitude: 3.14,
  longitude: 101.69,
  address: 'Kuala Lumpur',
  sustainabilityLabel: 'Official public transport stop',
  evidence: 'Official public transport stop.',
  sourceName: 'Official transit feed',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
  imageUrl: imageUrl,
  imageSourceName: imageSourceName,
);
