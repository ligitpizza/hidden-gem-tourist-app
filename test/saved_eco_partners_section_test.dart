import 'dart:async';

import 'package:collab/features/profile/view/widgets/saved_eco_partners_section.dart';
import 'package:collab/features/travel_assistant/model/eco_partner.dart';
import 'package:collab/features/travel_assistant/model/saved_eco_partner.dart';
import 'package:collab/features/travel_assistant/model/saved_eco_partner_repository.dart';
import 'package:collab/features/travel_assistant/model/saved_eco_partners_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saved Eco Partners start collapsed and reveal every card', (
    tester,
  ) async {
    final repository = _SavedRepository([
      _saved('saved-1', 'Eco Lodge'),
      _saved('saved-2', 'Green Cafe'),
    ]);
    final store = SavedEcoPartnersStore(repository: repository);

    await _pumpSection(tester, store);

    expect(find.text('Eco Partners (2)'), findsOneWidget);
    expect(find.text('Eco Lodge'), findsNothing);
    expect(find.text('Green Cafe'), findsNothing);

    await tester.tap(find.text('Eco Partners (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Eco Lodge'), findsOneWidget);
    expect(find.text('Green Cafe'), findsOneWidget);

    await tester.tap(find.text('Eco Partners (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Eco Lodge'), findsNothing);
    expect(find.text('Green Cafe'), findsNothing);
  });

  testWidgets('removing the last expanded partner shows the empty state', (
    tester,
  ) async {
    final repository = _SavedRepository([_saved('saved-1', 'Eco Lodge')]);
    final store = SavedEcoPartnersStore(repository: repository);
    await _pumpSection(tester, store);
    await tester.tap(find.text('Eco Partners (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove saved Eco Partner'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['saved-1']);
    expect(find.text('Eco Partners (0)'), findsOneWidget);
    expect(find.textContaining('No saved Eco Partners yet'), findsOneWidget);
  });

  testWidgets('an expanded saved card still opens partner details', (
    tester,
  ) async {
    final store = SavedEcoPartnersStore(
      repository: _SavedRepository([_saved('saved-1', 'Eco Lodge')]),
    );
    await _pumpSection(tester, store);
    await tester.tap(find.text('Eco Partners (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eco Lodge'));
    await tester.pumpAndSettle();

    expect(find.text('Partner Details'), findsOneWidget);
    expect(find.text('Eco Lodge'), findsOneWidget);
  });

  testWidgets('loading and empty states remain visible without expanding', (
    tester,
  ) async {
    final repository = _SavedRepository([])
      ..fetchCompleter = Completer<List<SavedEcoPartner>>();
    final store = SavedEcoPartnersStore(repository: repository);

    await tester.pumpWidget(_testApp(store));
    await tester.pump();

    expect(find.text('Eco Partners (0)'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.fetchCompleter!.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('No saved Eco Partners yet'), findsOneWidget);
  });

  testWidgets('failed loading exposes Retry without opening a dropdown', (
    tester,
  ) async {
    final repository = _SavedRepository([])..failFetch = true;
    final store = SavedEcoPartnersStore(repository: repository);
    await _pumpSection(tester, store);

    expect(
      find.text('Could not load your saved Eco Partners. Please retry.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    repository.failFetch = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(find.textContaining('No saved Eco Partners yet'), findsOneWidget);
  });
}

Future<void> _pumpSection(
  WidgetTester tester,
  SavedEcoPartnersStore store,
) async {
  await tester.pumpWidget(_testApp(store));
  await tester.pumpAndSettle();
}

Widget _testApp(SavedEcoPartnersStore store) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SavedEcoPartnersSection(store: store),
    ),
  ),
);

SavedEcoPartner _saved(String id, String name) => SavedEcoPartner(
  id: id,
  savedAt: DateTime(2026),
  partner: EcoPartner(
    id: 'partner:$id',
    name: name,
    category: EcoPartnerCategory.stay,
    subtype: 'Hotel',
    latitude: 3.14,
    longitude: 101.69,
    address: 'Kuala Lumpur',
    sustainabilityLabel: 'Verified sustainable partner',
    evidence: 'Verified evidence',
    sourceName: 'Test source',
    sourceUrl: 'https://example.com',
    lastUpdated: DateTime(2026),
  ),
);

class _SavedRepository implements SavedEcoPartnerRepositoryContract {
  _SavedRepository(List<SavedEcoPartner> values) : values = List.of(values);

  final List<SavedEcoPartner> values;
  final List<String> deletedIds = [];
  Completer<List<SavedEcoPartner>>? fetchCompleter;
  bool failFetch = false;
  int fetchCalls = 0;

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    values.removeWhere((saved) => saved.id == id);
  }

  @override
  Future<List<SavedEcoPartner>> fetchAll() async {
    fetchCalls++;
    if (failFetch) throw StateError('offline');
    if (fetchCompleter != null) return fetchCompleter!.future;
    return List.of(values);
  }

  @override
  Future<SavedEcoPartner> save(EcoPartner partner) async => SavedEcoPartner(
    id: 'saved-${values.length + 1}',
    partner: partner,
    savedAt: DateTime(2026),
  );
}
