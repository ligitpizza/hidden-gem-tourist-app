import 'package:collab/features/travel_prep/controller/eco_partner_controller.dart';
import 'package:collab/features/travel_prep/model/eco_partner.dart';
import 'package:collab/features/travel_prep/model/eco_partner_repository.dart';
import 'package:collab/features/travel_prep/view/eco_partner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
