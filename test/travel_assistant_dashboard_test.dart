import 'dart:async';

import 'package:collab/core/router/shell_routes.dart';
import 'package:collab/features/travel_assistant/controller/packing_checklist_controller.dart';
import 'package:collab/features/travel_assistant/controller/travel_assistant_dashboard_controller.dart';
import 'package:collab/features/travel_assistant/model/packing_checklist.dart';
import 'package:collab/features/travel_assistant/model/packing_checklist_repository.dart';
import 'package:collab/features/travel_assistant/model/packing_location_source.dart';
import 'package:collab/features/travel_assistant/model/packing_weather_service.dart';
import 'package:collab/features/travel_assistant/model/travel_document.dart';
import 'package:collab/features/travel_assistant/model/travel_assistant_cover_image.dart';
import 'package:collab/features/travel_assistant/view/travel_assistant_screens.dart';
import 'package:collab/shared/models/destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('dashboard title metadata supports single and multi-stop trips', () {
    const single = PackingLocationOption(
      id: 'one',
      label: 'Penang Hill',
      subtitle: 'Saved itinerary',
      latitude: 5.42,
      longitude: 100.27,
      categories: {DestinationCategory.viewpoint},
      dashboardTitle: 'Penang Hill',
      dashboardSubtitle: 'Saved itinerary',
    );
    const multi = PackingLocationOption(
      id: 'many',
      label: 'Penang Hill → George Town → Batu Ferringhi',
      subtitle: 'Saved itinerary',
      latitude: 5.42,
      longitude: 100.27,
      categories: {DestinationCategory.viewpoint},
      dashboardTitle: 'Penang Hill → Batu Ferringhi',
      dashboardSubtitle: '3-stop saved itinerary',
    );

    expect(single.heroTitle, 'Penang Hill');
    expect(single.heroSubtitle, 'Saved itinerary');
    expect(multi.heroTitle, 'Penang Hill → Batu Ferringhi');
    expect(multi.heroSubtitle, '3-stop saved itinerary');
  });

  test('controller loads selected trip and actual document metadata', () async {
    final checklist = _checklistController([_location]);
    final controller = TravelAssistantDashboardController(
      checklistController: checklist,
      documentLoader: () async => [_document(1), _document(2)],
      ecoPartnerCountLoader: () async => 3,
      coverResolver: _FakeCoverResolver(_cover),
    );

    await controller.load();

    expect(controller.heroTitle, 'Kota Kinabalu');
    expect(controller.heroSubtitle, 'Saved itinerary');
    expect(controller.documentCount, 2);
    expect(controller.documentBytes, 3000);
    expect(controller.ecoPartnerCount, 3);
    expect(
      controller.documentDescription,
      '2 documents stored securely for your journey.',
    );
    expect(
      controller.packingDescription,
      'Tailored to Kota Kinabalu, its forecast, and planned activities.',
    );
    expect(controller.coverImage, same(_cover));

    controller.dispose();
    checklist.dispose();
  });

  test(
    'document count refreshes and failures preserve dashboard use',
    () async {
      var documents = <TravelDocument>[];
      var shouldFail = false;
      final checklist = _checklistController([_location]);
      final controller = TravelAssistantDashboardController(
        checklistController: checklist,
        documentLoader: () async {
          if (shouldFail) throw StateError('offline');
          return documents;
        },
        ecoPartnerCountLoader: () async => 0,
        coverResolver: const _FakeCoverResolver(null),
      );

      await controller.load();
      expect(
        controller.documentDescription,
        'No documents stored yet. Add your essential travel files securely.',
      );

      documents = [_document(1)];
      await controller.refreshDocuments();
      expect(
        controller.documentDescription,
        '1 document stored securely for your journey.',
      );

      shouldFail = true;
      await controller.refreshDocuments();
      expect(controller.documentCount, 1);
      expect(controller.hasSelectedLocation, isTrue);

      controller.dispose();
      checklist.dispose();
    },
  );

  testWidgets('dashboard renders dynamic hero and revised descriptions', (
    tester,
  ) async {
    final checklist = _checklistController([_location]);
    final controller = TravelAssistantDashboardController(
      checklistController: checklist,
      documentLoader: () async => [_document(1), _document(2)],
      ecoPartnerCountLoader: () async => 3,
      coverResolver: const _FakeCoverResolver(null),
    );

    await tester.pumpWidget(
      MaterialApp(home: TravelAssistantDashboardScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PACKING FOR'), findsOneWidget);
    expect(find.text('Kota Kinabalu'), findsOneWidget);
    expect(find.text('0/10 packed'), findsNWidgets(2));
    expect(find.text('3 saved'), findsOneWidget);
    expect(find.text('2 files'), findsOneWidget);
    expect(find.text('Emerald\nFalls'), findsNothing);
    expect(
      find.text(
        'Tailored to Kota Kinabalu, its forecast, and planned activities.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Eco Recommendations'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(
        'Discover sustainable hotels, dining, public transport and EV charging partners across Malaysia.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Document Vault'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('2 documents stored securely for your journey.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    checklist.dispose();
  });

  testWidgets('dashboard keeps its controller through application reassemble', (
    tester,
  ) async {
    final checklist = _checklistController([_location]);
    final controller = TravelAssistantDashboardController(
      checklistController: checklist,
      documentLoader: () async => const [],
      ecoPartnerCountLoader: () async => 0,
      coverResolver: const _FakeCoverResolver(null),
    );

    await tester.pumpWidget(
      MaterialApp(home: TravelAssistantDashboardScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    // Exercise the same State callback Flutter invokes during hot reload.
    // ignore: invalid_use_of_protected_member
    tester.state(find.byType(TravelAssistantDashboardScreen)).reassemble();
    await tester.pump();

    expect(find.text('Kota Kinabalu'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    checklist.dispose();
  });

  testWidgets('hero loading summaries fit a narrow screen with scaled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locations = Completer<List<PackingLocationOption>>();
    final documents = Completer<List<TravelDocument>>();
    final checklist = PackingChecklistController(
      locationSource: _DelayedLocationSource(locations.future),
      weatherService: _NoWeatherService(),
      persistence: _MemoryChecklistRepository(),
    );
    final controller = TravelAssistantDashboardController(
      checklistController: checklist,
      documentLoader: () => documents.future,
      ecoPartnerCountLoader: () async => 12,
      coverResolver: const _FakeCoverResolver(null),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: TravelAssistantDashboardScreen(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Loading'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    locations.complete([_location]);
    documents.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('0/10 packed'), findsNWidgets(2));
    expect(find.text('12 saved'), findsOneWidget);
    expect(find.text('0 files'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    checklist.dispose();
  });

  testWidgets('hero summaries open each feature and refresh on return', (
    tester,
  ) async {
    var ecoPartnerCount = 2;
    var documents = [_document(1), _document(2)];
    final checklist = _checklistController([_location]);
    final controller = TravelAssistantDashboardController(
      checklistController: checklist,
      documentLoader: () async => documents,
      ecoPartnerCountLoader: () async => ecoPartnerCount,
      coverResolver: const _FakeCoverResolver(null),
    );
    final router = GoRouter(
      initialLocation: ShellRoutes.travelAssistant,
      routes: [
        GoRoute(
          path: ShellRoutes.travelAssistant,
          builder: (_, _) =>
              TravelAssistantDashboardScreen(controller: controller),
        ),
        GoRoute(
          path: ShellRoutes.checklist,
          builder: (_, _) => const Scaffold(body: Text('Checklist route')),
        ),
        GoRoute(
          path: ShellRoutes.ecoPartners,
          builder: (_, _) => const Scaffold(body: Text('Eco Partners route')),
        ),
        GoRoute(
          path: ShellRoutes.documentVault,
          builder: (_, _) => const Scaffold(body: Text('Vault route')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(
      find.ancestor(of: find.text('Packing'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Checklist route'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(
      find.ancestor(
        of: find.text('Eco Partners'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Eco Partners route'), findsOneWidget);
    ecoPartnerCount = 4;
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('4 saved'), findsOneWidget);

    await tester.tap(
      find.ancestor(of: find.text('Vault'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vault route'), findsOneWidget);
    documents = [_document(1)];
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('1 file'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    controller.dispose();
    checklist.dispose();
  });

  testWidgets('hero keeps independent unavailable and file count states', (
    tester,
  ) async {
    final checklist = _checklistController([_location]);
    final controller = TravelAssistantDashboardController(
      checklistController: checklist,
      documentLoader: () async => [_document(1)],
      ecoPartnerCountLoader: () async => throw StateError('offline'),
      coverResolver: const _FakeCoverResolver(null),
    );

    await tester.pumpWidget(
      MaterialApp(home: TravelAssistantDashboardScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('1 file'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    checklist.dispose();
  });

  testWidgets('dashboard shows a checklist CTA without a selected location', (
    tester,
  ) async {
    final checklist = _checklistController(const []);
    final controller = TravelAssistantDashboardController(
      checklistController: checklist,
      documentLoader: () async => const [],
      ecoPartnerCountLoader: () async => 0,
      coverResolver: const _FakeCoverResolver(null),
    );

    await tester.pumpWidget(
      MaterialApp(home: TravelAssistantDashboardScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a destination'), findsOneWidget);
    expect(find.text('Choose trip'), findsOneWidget);
    expect(find.text('0% Ready'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    checklist.dispose();
  });
}

const _location = PackingLocationOption(
  id: 'itinerary:1',
  label: 'Kota Kinabalu',
  subtitle: 'Saved itinerary',
  latitude: 5.98,
  longitude: 116.07,
  categories: {DestinationCategory.attraction},
  dashboardTitle: 'Kota Kinabalu',
  dashboardSubtitle: 'Saved itinerary',
  lookupName: 'Kota Kinabalu',
  destinationId: 'destination-1',
  primaryCategory: DestinationCategory.attraction,
);

const _cover = TravelAssistantCoverImage(
  imageUrl: 'https://upload.wikimedia.org/example.jpg',
  attribution: 'Photo: Example · CC BY-SA 4.0',
  attributionUrl: 'https://commons.wikimedia.org/example',
  source: TravelAssistantCoverSource.wikipedia,
);

PackingChecklistController _checklistController(
  List<PackingLocationOption> locations,
) => PackingChecklistController(
  locationSource: _FakeLocationSource(locations),
  weatherService: _NoWeatherService(),
  persistence: _MemoryChecklistRepository(),
);

TravelDocument _document(int index) => TravelDocument(
  id: 'doc-$index',
  displayName: 'Document $index',
  category: 'Other',
  originalFileName: 'document-$index.pdf',
  storedPath: '/document-$index.pdf',
  extension: 'pdf',
  fileSize: index * 1000,
  createdAt: DateTime.utc(2026, 9, index),
);

class _FakeCoverResolver implements TravelAssistantCoverImageResolverContract {
  const _FakeCoverResolver(this.image);

  final TravelAssistantCoverImage? image;

  @override
  Future<TravelAssistantCoverImage?> resolve(
    PackingLocationOption location,
  ) async => image;
}

class _FakeLocationSource implements PackingLocationSource {
  const _FakeLocationSource(this.locations);

  final List<PackingLocationOption> locations;

  @override
  Future<List<PackingLocationOption>> load() async => locations;
}

class _DelayedLocationSource implements PackingLocationSource {
  const _DelayedLocationSource(this.result);

  final Future<List<PackingLocationOption>> result;

  @override
  Future<List<PackingLocationOption>> load() => result;
}

class _NoWeatherService extends PackingWeatherService {
  @override
  Future<PackingWeatherSummary?> getForecast({
    required double latitude,
    required double longitude,
  }) async => null;
}

class _MemoryChecklistRepository implements PackingChecklistRepositoryContract {
  String? selection;
  Set<String> packedIds = {};
  List<PackingChecklistItem> customItems = const [];
  final Map<String, PackingTripDateRange> dates = {};

  @override
  Future<void> clearTripDates(String locationId) async {
    dates.remove(locationId);
  }

  @override
  Future<List<PackingChecklistItem>> loadCustomItems() async => customItems;

  @override
  Future<Set<String>> loadPackedIds(String locationId) async => packedIds;

  @override
  Future<PackingTripDateRange?> loadTripDates(String locationId) async =>
      dates[locationId];

  @override
  Future<String?> loadSelection() async => selection;

  @override
  Future<void> saveCustomItems(List<PackingChecklistItem> items) async {
    customItems = items;
  }

  @override
  Future<void> savePackedIds(String locationId, Set<String> ids) async {
    packedIds = ids;
  }

  @override
  Future<void> saveSelection(String locationId) async {
    selection = locationId;
  }

  @override
  Future<void> saveTripDates(
    String locationId,
    PackingTripDateRange dates,
  ) async {
    this.dates[locationId] = dates;
  }
}
