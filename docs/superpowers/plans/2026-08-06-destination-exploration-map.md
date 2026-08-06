# Destination Exploration — Feature 1: Interactive Destination Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Interactive Destination Map (FR1.1–FR1.5, NFR1, NFR3, NFR11) as a new MVC
feature under `lib/features/destination_exploration/`, wired into the app's existing Map tab.

**Architecture:** MVC matching the project's `itinerary_planning` convention — a
`ChangeNotifier` Controller (Riverpod `ChangeNotifierProvider`) backed by a Repository that
queries a new, dedicated `destinations` Supabase table (standalone — not shared with any
other feature), feeding a `flutter_map` View with proximity-based marker clustering, category
filter chips, and a tap-to-view popup.

**Tech Stack:** Flutter, `flutter_map` (already a dependency), new dependency
`flutter_map_marker_cluster: ^1.4.0`, `flutter_riverpod`, `supabase_flutter`, a new Supabase
migration for the `destinations` table.

## Global Constraints

- Use a new, standalone `destinations` Supabase table — do not reuse
  `place_hidden_gem_candidates` or any other existing table (spec decision, revised
  2026-08-06: Feature 1 must be fully standalone, not sharing data with other features).
- `destinations.category` uses the same raw vocabulary as `DestinationCategory.dbValue`
  (`attraction`, `heritage_site`, `museum`, `viewpoint`, `park`, `beach`, `waterfall`, `cafe`,
  `restaurant`, `craft`, `art`), so `HiddenGemScoring.categoryFromDb` keeps working unmodified.
- Reuse the existing `HiddenGemCategory` enum (food, culture, nature, viewpoint, craft) and
  `HiddenGemScoring.categoryFromDb` mapping for marker color-coding/filtering — do not
  introduce a second, spec-literal 4-category (nature/food/culture/heritage) scheme
  (FR1.1, spec decision).
- Mapping must use OpenStreetMap tiles via `flutter_map` — no billed tile provider (NFR11).
- `flutter_map_marker_cluster` must be pinned to `^1.4.0` — later majors require
  `flutter_map ^8.x`, but this project has `flutter_map: ^7.0.2` pinned.
- Do not modify `lib/features/map/view/map_screen.dart` (the old placeholder — left unused)
  or `lib/shared/models/destination.dart` (the lean model used by itinerary planning) — this
  feature's `MapDestination` model is new and standalone.
- Popups/comparison layouts must be compact/scannable (NFR3) — the popup sheet shows name,
  category, description, and images/placeholder only, no extra chrome.
- Marker clustering must engage automatically as destination density increases (FR1.4,
  NFR1) via proximity-based clustering (`flutter_map_marker_cluster`), not a manual
  count-threshold toggle.
- Missing destination images show a placeholder icon, not a blank/broken image (E2).
- A destination load failure shows a visible error state with retry, not a silently empty
  map (E1).

---

## File Structure

```
supabase/migrations/
  202608060001_destinations.sql                 # Task 1
lib/features/destination_exploration/
  model/
    map_destination.dart                      # Task 1
    destination_exploration_repository.dart   # Task 1
  controller/
    destination_map_controller.dart           # Task 2
  view/
    widgets/
      category_style.dart                     # Task 3
      category_filter_bar.dart                # Task 4
      destination_popup_sheet.dart            # Task 5
    destination_map_screen.dart               # Task 6
lib/core/router/app_router.dart                 # Task 6 (modify)
pubspec.yaml                                    # Task 6 (modify)
test/
  destination_map_repository_test.dart          # Task 1
  destination_map_controller_test.dart          # Task 2
  destination_category_style_test.dart          # Task 3
  destination_category_filter_bar_test.dart     # Task 4
  destination_popup_sheet_test.dart              # Task 5
```

---

### Task 1: Migration + Model + Repository (row mapping)

**Files:**
- Create: `supabase/migrations/202608060001_destinations.sql`
- Create: `lib/features/destination_exploration/model/map_destination.dart`
- Create: `lib/features/destination_exploration/model/destination_exploration_repository.dart`
- Test: `test/destination_map_repository_test.dart`

**Interfaces:**
- Consumes: `HiddenGemCategory` and `HiddenGemScoring.categoryFromDb(String)` from
  `lib/shared/models/hidden_gem.dart` / `lib/shared/services/hidden_gem_scoring.dart`
  (existing, unmodified).
- Produces:
  - `class MapDestination { String id; String name; String description; HiddenGemCategory category; LatLng location; double avgRating; List<String> imageUrls; }`
    (all fields `final`, const constructor, `avgRating` defaults to `0`, `imageUrls` defaults
    to `const []`).
  - `class DestinationExplorationRepository { static MapDestination mapRow(Map<String, dynamic> row); Future<List<MapDestination>> loadDestinations(); }`
    — `loadDestinations()` does **not** catch errors; it lets Supabase exceptions propagate
    (Task 2's Controller is responsible for catching them, so it can distinguish "load
    failed" from "load succeeded with zero rows").

- [ ] **Step 1: Write the `destinations` table migration**

```sql
-- supabase/migrations/202608060001_destinations.sql
create table public.destinations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  category text not null,
  latitude double precision not null,
  longitude double precision not null,
  avg_rating numeric not null default 0,
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.destinations enable row level security;

create policy "Public read access" on public.destinations
  for select using (true);

-- Seed data so the map isn't empty on first run (NFR14). Categories use the
-- same raw vocabulary as DestinationCategory.dbValue / destinationCategoryFromDb
-- so HiddenGemScoring.categoryFromDb keeps mapping them correctly.
insert into public.destinations (name, description, category, latitude, longitude, avg_rating, images) values
  ('Penang Hill', 'A funicular railway up to cool hilltop views over George Town.', 'viewpoint', 5.4225, 100.2769, 4.6, '{}'),
  ('Kek Lok Si Temple', 'One of the largest Buddhist temples in Southeast Asia.', 'heritage_site', 5.3994, 100.2735, 4.5, '{}'),
  ('George Town Street Art', 'Murals and wrought-iron caricatures scattered through the old town.', 'art', 5.4164, 100.3327, 4.4, '{}'),
  ('Penang Peranakan Mansion', 'A restored 19th-century Peranakan mansion turned museum.', 'museum', 5.4145, 100.3384, 4.5, '{}'),
  ('Escape Penang', 'An outdoor adventure and jungle obstacle park.', 'park', 5.4489, 100.2492, 4.3, '{}'),
  ('Batu Ferringhi Beach', 'A popular sandy beach lined with resorts and night markets.', 'beach', 5.4747, 100.2440, 4.1, '{}'),
  ('Tropical Fruit Farm', 'A guided tour through a working tropical fruit orchard.', 'attraction', 5.2503, 100.5928, 4.4, '{}'),
  ('Ban Zaan Wet Market', 'A bustling local seafood and produce market.', 'attraction', 5.4720, 100.2419, 4.0, '{}'),
  ('Air Terjun Titi Kerawang', 'A roadside waterfall on the way around the island.', 'waterfall', 5.4046, 100.2100, 4.2, '{}'),
  ('Seng Thor Restaurant', 'A local favourite for Penang-style seafood.', 'restaurant', 5.4030, 100.3070, 4.3, '{}'),
  ('Nyonya Baba Cuisine Cafe', 'A cosy cafe serving traditional Peranakan dishes.', 'cafe', 5.4180, 100.3300, 4.2, '{}'),
  ('Penang Batik Craft Village', 'Hands-on batik painting workshops in a small craft village.', 'craft', 5.4600, 100.2050, 4.1, '{}');
```

Run this migration against the Supabase project (e.g. `supabase db push` or via the Supabase
dashboard's SQL editor, per however this project's existing migrations are normally applied —
see `supabase/migrations/202608050001_eco_partners.sql` for the prior precedent).

- [ ] **Step 2: Write `MapDestination`**

```dart
// lib/features/destination_exploration/model/map_destination.dart
import 'package:latlong2/latlong.dart';

import '../../../shared/models/hidden_gem.dart';

/// A destination pin on the Interactive Destination Map, sourced from the
/// dedicated `destinations` table. Deliberately separate from the shared
/// lean `Destination` model (used by itinerary planning) since this screen
/// needs description/rating/image fields that model doesn't carry.
class MapDestination {
  final String id;
  final String name;
  final String description;
  final HiddenGemCategory category;
  final LatLng location;
  final double avgRating;
  final List<String> imageUrls;

  const MapDestination({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.location,
    this.avgRating = 0,
    this.imageUrls = const [],
  });
}
```

- [ ] **Step 3: Write the failing repository row-mapping tests**

```dart
// test/destination_map_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/shared/models/hidden_gem.dart';

void main() {
  group('DestinationExplorationRepository.mapRow', () {
    test('maps a full row', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_1',
        'name': 'Penang Hill',
        'description': 'A funicular railway up to cool hilltop views.',
        'category': 'viewpoint',
        'latitude': 5.4225,
        'longitude': 100.2769,
        'avg_rating': 4.6,
        'images': ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
      });

      expect(destination.id, 'place_1');
      expect(destination.name, 'Penang Hill');
      expect(destination.description, 'A funicular railway up to cool hilltop views.');
      expect(destination.category, HiddenGemCategory.viewpoint);
      expect(destination.location.latitude, 5.4225);
      expect(destination.location.longitude, 100.2769);
      expect(destination.avgRating, 4.6);
      expect(destination.imageUrls, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
    });

    test('falls back to a placeholder description when blank', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_2',
        'name': 'Unnamed Spot',
        'description': '   ',
        'category': 'park',
        'latitude': 5.4,
        'longitude': 100.3,
      });

      expect(destination.description, 'No description available yet.');
    });

    test('returns an empty imageUrls list when images is null', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_3',
        'name': 'No Photos Yet',
        'description': 'Nice place.',
        'category': 'craft',
        'latitude': 5.4,
        'longitude': 100.3,
        'images': null,
      });

      expect(destination.imageUrls, isEmpty);
    });

    test('returns an empty imageUrls list when images is not a list', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_4',
        'name': 'Weird Data',
        'description': 'Nice place.',
        'category': 'craft',
        'latitude': 5.4,
        'longitude': 100.3,
        'images': 'not-a-list',
      });

      expect(destination.imageUrls, isEmpty);
    });

    test('unrecognised category strings fall back via HiddenGemScoring', () {
      final destination = DestinationExplorationRepository.mapRow({
        'id': 'place_5',
        'name': 'Mystery Place',
        'description': 'Nice place.',
        'category': 'totally_unknown_category',
        'latitude': 5.4,
        'longitude': 100.3,
      });

      expect(destination.category, HiddenGemCategory.culture);
    });
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/destination_map_repository_test.dart`
Expected: FAIL — `DestinationExplorationRepository` doesn't exist yet (compile error).

- [ ] **Step 5: Write `DestinationExplorationRepository`**

```dart
// lib/features/destination_exploration/model/destination_exploration_repository.dart
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/hidden_gem_scoring.dart';
import 'map_destination.dart';

/// Loads destinations for the Interactive Destination Map from the
/// dedicated `destinations` table (standalone — this feature does not
/// share data with any other module; see the design spec).
class DestinationExplorationRepository {
  /// Pure row -> [MapDestination] mapping, kept separate from the network
  /// call so it's unit-testable without a live Supabase connection.
  static MapDestination mapRow(Map<String, dynamic> row) {
    final rawImages = row['images'];
    final imageUrls = rawImages is List
        ? rawImages.whereType<String>().toList()
        : const <String>[];
    final description = (row['description'] as String?)?.trim();

    return MapDestination(
      id: row['id'] as String,
      name: row['name'] as String,
      description: (description != null && description.isNotEmpty)
          ? description
          : 'No description available yet.',
      category: HiddenGemScoring.categoryFromDb(row['category'] as String),
      location: LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ),
      avgRating: (row['avg_rating'] as num?)?.toDouble() ?? 0.0,
      imageUrls: imageUrls,
    );
  }

  /// Loads every destination for the map. Deliberately does **not** catch
  /// Supabase errors here — the Controller catches them so it can show a
  /// distinct "load failed" state (E1) instead of an indistinguishable
  /// empty result.
  Future<List<MapDestination>> loadDestinations() async {
    final rows = await Supabase.instance.client.from('destinations').select();
    return rows.map(mapRow).toList();
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/destination_map_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/202608060001_destinations.sql lib/features/destination_exploration/model/map_destination.dart lib/features/destination_exploration/model/destination_exploration_repository.dart test/destination_map_repository_test.dart
git commit -m "feat(destination-map): add destinations table migration, MapDestination model, and repository row mapping"
```

---

### Task 2: Controller

**Files:**
- Create: `lib/features/destination_exploration/controller/destination_map_controller.dart`
- Test: `test/destination_map_controller_test.dart`

**Interfaces:**
- Consumes: `MapDestination`, `DestinationExplorationRepository` (Task 1);
  `HiddenGemCategory` (existing).
- Produces:
  - `class DestinationMapController extends ChangeNotifier` with:
    - `DestinationMapController({DestinationExplorationRepository? repository})` — auto-calls
      `loadDestinations()` once on construction.
    - `List<MapDestination> destinations` (default `const []`)
    - `bool isLoading`, `bool hasError`
    - `Set<HiddenGemCategory> selectedCategories` (empty = show all)
    - `MapDestination? selectedDestination`
    - `List<MapDestination> get filteredDestinations`
    - `Future<void> loadDestinations()`
    - `Future<void> retry()`
    - `void toggleCategory(HiddenGemCategory category)`
    - `void clearFilters()`
    - `void selectDestination(String id)`
    - `void clearSelection()`
  - `final destinationMapControllerProvider = ChangeNotifierProvider<DestinationMapController>((ref) => DestinationMapController());`

- [ ] **Step 1: Write the failing controller tests**

```dart
// test/destination_map_controller_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/controller/destination_map_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeRepository extends DestinationExplorationRepository {
  _FakeRepository(this._result, {this.shouldThrow = false});
  final List<MapDestination> _result;
  final bool shouldThrow;

  @override
  Future<List<MapDestination>> loadDestinations() async {
    if (shouldThrow) throw Exception('network error');
    return _result;
  }
}

class _CompleterRepository extends DestinationExplorationRepository {
  _CompleterRepository(this._completer);
  final Completer<List<MapDestination>> _completer;

  @override
  Future<List<MapDestination>> loadDestinations() => _completer.future;
}

const _nature = MapDestination(
  id: 'n1',
  name: 'Forest Park',
  description: 'Trees.',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);
const _food = MapDestination(
  id: 'f1',
  name: 'Hawker Stall',
  description: 'Food.',
  category: HiddenGemCategory.food,
  location: LatLng(5.41, 100.31),
);

void main() {
  group('DestinationMapController', () {
    test('populates destinations on successful load', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      expect(controller.destinations, [_nature, _food]);
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('sets hasError and clears destinations on load failure', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository(const [], shouldThrow: true),
      );
      await controller.loadDestinations();

      expect(controller.hasError, isTrue);
      expect(controller.destinations, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('isLoading is true while the repository call is pending', () async {
      final completer = Completer<List<MapDestination>>();
      final controller = DestinationMapController(
        repository: _CompleterRepository(completer),
      );

      expect(controller.isLoading, isTrue);

      completer.complete(const []);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
    });

    test('filteredDestinations returns everything when no category is selected', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      expect(controller.filteredDestinations, [_nature, _food]);
    });

    test('filteredDestinations narrows to the selected categories', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      controller.toggleCategory(HiddenGemCategory.nature);

      expect(controller.filteredDestinations, [_nature]);
    });

    test('toggleCategory adds then removes a category', () {
      final controller = DestinationMapController(
        repository: _FakeRepository(const []),
      );

      controller.toggleCategory(HiddenGemCategory.craft);
      expect(controller.selectedCategories, {HiddenGemCategory.craft});

      controller.toggleCategory(HiddenGemCategory.craft);
      expect(controller.selectedCategories, isEmpty);
    });

    test('clearFilters empties the selected categories', () {
      final controller = DestinationMapController(
        repository: _FakeRepository(const []),
      );

      controller.toggleCategory(HiddenGemCategory.nature);
      controller.toggleCategory(HiddenGemCategory.food);
      controller.clearFilters();

      expect(controller.selectedCategories, isEmpty);
    });

    test('selectDestination and clearSelection manage selectedDestination', () async {
      final controller = DestinationMapController(
        repository: _FakeRepository([_nature, _food]),
      );
      await controller.loadDestinations();

      controller.selectDestination('f1');
      expect(controller.selectedDestination, _food);

      controller.clearSelection();
      expect(controller.selectedDestination, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/destination_map_controller_test.dart`
Expected: FAIL — `DestinationMapController` doesn't exist yet (compile error).

- [ ] **Step 3: Write `DestinationMapController`**

```dart
// lib/features/destination_exploration/controller/destination_map_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hidden_gem.dart';
import '../model/destination_exploration_repository.dart';
import '../model/map_destination.dart';

/// Business logic for the Interactive Destination Map. Kept as a plain
/// [ChangeNotifier] per the module's MVC convention (see
/// itinerary_planning's ItineraryPlannerController for the same pattern).
class DestinationMapController extends ChangeNotifier {
  DestinationMapController({DestinationExplorationRepository? repository})
      : _repository = repository ?? DestinationExplorationRepository() {
    loadDestinations();
  }

  final DestinationExplorationRepository _repository;

  List<MapDestination> destinations = const [];
  bool isLoading = false;
  bool hasError = false;
  final Set<HiddenGemCategory> selectedCategories = {};
  MapDestination? selectedDestination;

  List<MapDestination> get filteredDestinations {
    if (selectedCategories.isEmpty) return destinations;
    return destinations.where((d) => selectedCategories.contains(d.category)).toList();
  }

  Future<void> loadDestinations() async {
    isLoading = true;
    hasError = false;
    notifyListeners();

    try {
      destinations = await _repository.loadDestinations();
    } catch (_) {
      destinations = const [];
      hasError = true;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> retry() => loadDestinations();

  void toggleCategory(HiddenGemCategory category) {
    if (!selectedCategories.remove(category)) {
      selectedCategories.add(category);
    }
    notifyListeners();
  }

  void clearFilters() {
    if (selectedCategories.isEmpty) return;
    selectedCategories.clear();
    notifyListeners();
  }

  void selectDestination(String id) {
    selectedDestination = destinations.firstWhere((d) => d.id == id);
    notifyListeners();
  }

  void clearSelection() {
    selectedDestination = null;
    notifyListeners();
  }
}

final destinationMapControllerProvider =
    ChangeNotifierProvider<DestinationMapController>((ref) {
  return DestinationMapController();
});
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/destination_map_controller_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/controller/destination_map_controller.dart test/destination_map_controller_test.dart
git commit -m "feat(destination-map): add DestinationMapController"
```

---

### Task 3: Category styling helper

**Files:**
- Create: `lib/features/destination_exploration/view/widgets/category_style.dart`
- Test: `test/destination_category_style_test.dart`

**Interfaces:**
- Consumes: `HiddenGemCategory` (existing).
- Produces: `Color categoryColor(HiddenGemCategory category)`,
  `IconData categoryIcon(HiddenGemCategory category)` — used by Tasks 4, 5, and 6.

- [ ] **Step 1: Write the failing tests**

```dart
// test/destination_category_style_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/view/widgets/category_style.dart';
import 'package:collab/shared/models/hidden_gem.dart';

void main() {
  group('category styling', () {
    test('every category has a distinct color', () {
      final colors = HiddenGemCategory.values.map(categoryColor).toSet();
      expect(colors.length, HiddenGemCategory.values.length);
    });

    test('every category has a distinct icon', () {
      final icons = HiddenGemCategory.values.map(categoryIcon).toSet();
      expect(icons.length, HiddenGemCategory.values.length);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/destination_category_style_test.dart`
Expected: FAIL — `category_style.dart` doesn't exist yet (compile error).

- [ ] **Step 3: Write `category_style.dart`**

```dart
// lib/features/destination_exploration/view/widgets/category_style.dart
import 'package:flutter/material.dart';

import '../../../../shared/models/hidden_gem.dart';

/// Marker/filter-chip color and icon per category. No such mapping exists
/// elsewhere in the app yet, so it's defined here, local to the map.
Color categoryColor(HiddenGemCategory category) {
  switch (category) {
    case HiddenGemCategory.nature:
      return Colors.green.shade600;
    case HiddenGemCategory.food:
      return Colors.orange.shade700;
    case HiddenGemCategory.culture:
      return Colors.deepPurple.shade400;
    case HiddenGemCategory.viewpoint:
      return Colors.blue.shade600;
    case HiddenGemCategory.craft:
      return Colors.brown.shade400;
  }
}

IconData categoryIcon(HiddenGemCategory category) {
  switch (category) {
    case HiddenGemCategory.nature:
      return Icons.park;
    case HiddenGemCategory.food:
      return Icons.restaurant;
    case HiddenGemCategory.culture:
      return Icons.museum;
    case HiddenGemCategory.viewpoint:
      return Icons.landscape;
    case HiddenGemCategory.craft:
      return Icons.palette;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/destination_category_style_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/view/widgets/category_style.dart test/destination_category_style_test.dart
git commit -m "feat(destination-map): add category color/icon styling helper"
```

---

### Task 4: Category filter bar widget

**Files:**
- Create: `lib/features/destination_exploration/view/widgets/category_filter_bar.dart`
- Test: `test/destination_category_filter_bar_test.dart`

**Interfaces:**
- Consumes: `destinationMapControllerProvider`, `DestinationMapController` (Task 2);
  `categoryColor`/`categoryIcon` (Task 3); `HiddenGemCategory` + `.label` (existing).
- Produces: `class CategoryFilterBar extends ConsumerWidget` — a horizontal row of
  `FilterChip`s, one per `HiddenGemCategory.values`, wired to
  `controller.toggleCategory`/`controller.selectedCategories`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/destination_category_filter_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collab/features/destination_exploration/controller/destination_map_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/features/destination_exploration/view/widgets/category_filter_bar.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _EmptyRepository extends DestinationExplorationRepository {
  @override
  Future<List<MapDestination>> loadDestinations() async => const [];
}

void main() {
  testWidgets('tapping a chip toggles that category on the controller', (tester) async {
    final controller = DestinationMapController(repository: _EmptyRepository());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationMapControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CategoryFilterBar()),
        ),
      ),
    );
    await tester.pump();

    expect(controller.selectedCategories, isEmpty);

    await tester.tap(find.text(HiddenGemCategory.nature.label));
    await tester.pump();

    expect(controller.selectedCategories, {HiddenGemCategory.nature});

    await tester.tap(find.text(HiddenGemCategory.nature.label));
    await tester.pump();

    expect(controller.selectedCategories, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/destination_category_filter_bar_test.dart`
Expected: FAIL — `CategoryFilterBar` doesn't exist yet (compile error).

- [ ] **Step 3: Write `CategoryFilterBar`**

```dart
// lib/features/destination_exploration/view/widgets/category_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/hidden_gem.dart';
import '../../controller/destination_map_controller.dart';
import 'category_style.dart';

/// Horizontal row of category filter chips (FR1.3) — toggling a chip
/// narrows [DestinationMapController.filteredDestinations]; deselecting
/// all chips shows every destination again (A1).
class CategoryFilterBar extends ConsumerWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(destinationMapControllerProvider);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: HiddenGemCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = HiddenGemCategory.values[index];
          final selected = controller.selectedCategories.contains(category);
          return FilterChip(
            avatar: Icon(
              categoryIcon(category),
              size: 18,
              color: selected ? Colors.white : categoryColor(category),
            ),
            label: Text(category.label),
            selected: selected,
            selectedColor: categoryColor(category),
            labelStyle: TextStyle(color: selected ? Colors.white : null),
            onSelected: (_) => controller.toggleCategory(category),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/destination_category_filter_bar_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/view/widgets/category_filter_bar.dart test/destination_category_filter_bar_test.dart
git commit -m "feat(destination-map): add category filter bar widget"
```

---

### Task 5: Destination popup sheet widget

**Files:**
- Create: `lib/features/destination_exploration/view/widgets/destination_popup_sheet.dart`
- Test: `test/destination_popup_sheet_test.dart`

**Interfaces:**
- Consumes: `MapDestination` (Task 1); `categoryColor`/`categoryIcon` (Task 3).
- Produces: `class DestinationPopupSheet extends StatelessWidget` with a required
  `destination` constructor parameter — renders name, category icon, images (or a
  placeholder icon when `imageUrls` is empty), and description.

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/destination_popup_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/features/destination_exploration/view/widgets/destination_popup_sheet.dart';
import 'package:collab/shared/models/hidden_gem.dart';

void main() {
  testWidgets('shows a placeholder icon when there are no images', (tester) async {
    const destination = MapDestination(
      id: '1',
      name: 'Test Place',
      description: 'A place worth visiting.',
      category: HiddenGemCategory.nature,
      location: LatLng(5.4, 100.3),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DestinationPopupSheet(destination: destination)),
      ),
    );

    expect(find.text('Test Place'), findsOneWidget);
    expect(find.text('A place worth visiting.'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders an image per URL when images are present', (tester) async {
    const destination = MapDestination(
      id: '2',
      name: 'Gem Spot',
      description: 'Nice.',
      category: HiddenGemCategory.food,
      location: LatLng(5.4, 100.3),
      imageUrls: ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DestinationPopupSheet(destination: destination)),
      ),
    );

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/destination_popup_sheet_test.dart`
Expected: FAIL — `DestinationPopupSheet` doesn't exist yet (compile error).

- [ ] **Step 3: Write `DestinationPopupSheet`**

```dart
// lib/features/destination_exploration/view/widgets/destination_popup_sheet.dart
import 'package:flutter/material.dart';

import '../../model/map_destination.dart';
import 'category_style.dart';

/// Marker-tap detail popup (FR1.2). flutter_map has no built-in popup
/// widget, so this is shown via `showModalBottomSheet`. Kept compact
/// (NFR3): name, category, description, and images or a placeholder (E2)
/// — nothing else.
class DestinationPopupSheet extends StatelessWidget {
  const DestinationPopupSheet({super.key, required this.destination});

  final MapDestination destination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(destination.category), color: categoryColor(destination.category)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(destination.name, style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (destination.imageUrls.isEmpty)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: destination.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    destination.imageUrls[index],
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(destination.description),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/destination_popup_sheet_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/view/widgets/destination_popup_sheet.dart test/destination_popup_sheet_test.dart
git commit -m "feat(destination-map): add destination popup sheet widget"
```

---

### Task 6: Map screen, clustering dependency, and router wiring

**Files:**
- Create: `lib/features/destination_exploration/view/destination_map_screen.dart`
- Modify: `pubspec.yaml` (add `flutter_map_marker_cluster` dependency)
- Modify: `lib/core/router/app_router.dart:19` (import) and `:97` (route builder)

**Interfaces:**
- Consumes: `destinationMapControllerProvider`, `DestinationMapController` (Task 2);
  `CategoryFilterBar` (Task 4); `DestinationPopupSheet` (Task 5); `categoryColor`/
  `categoryIcon` (Task 3).
- Produces: `class DestinationMapScreen extends ConsumerWidget` — the screen wired into the
  `ShellRoutes.map` (`/`) route.

This task has no automated widget test — `flutter_map` widget tests require network tiles
and are explicitly out of scope per the design spec's Testing section. Verification is a
manual run in the browser (Step 6 below), consistent with the project's normal UI
verification process.

- [ ] **Step 1: Add the clustering dependency**

Edit `pubspec.yaml`, adding this line directly after the existing `flutter_map: ^7.0.2` line
(around line 58):

```yaml
  flutter_map: ^7.0.2         # Leaflet/OpenStreetMap renderer for Flutter
  flutter_map_marker_cluster: ^1.4.0  # proximity-based marker clustering (FR1.4)
  latlong2: ^0.9.1
```

Run: `flutter pub get`
Expected: resolves cleanly (no version conflicts — `1.4.0` targets `flutter_map >=7.0.0 <8.0.0`, matching the pinned version).

- [ ] **Step 2: Write `DestinationMapScreen`**

```dart
// lib/features/destination_exploration/view/destination_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../controller/destination_map_controller.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/category_style.dart';
import 'widgets/destination_popup_sheet.dart';

/// Module 2.1's Interactive Destination Map: every destination from the
/// dedicated `destinations` table as a clustered, color-coded marker, with
/// category filters (FR1.3) and a tap-to-view detail popup (FR1.2).
class DestinationMapScreen extends ConsumerWidget {
  const DestinationMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(destinationMapControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const CategoryFilterBar(),
            const SizedBox(height: 8),
            Expanded(child: _MapBody(controller: controller)),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.controller});

  final DestinationMapController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && controller.destinations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('Could not load destinations.'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: controller.retry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(5.4164, 100.3327), // Penang — matches the seeded dataset
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.collab.app',
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            markers: [
              for (final destination in controller.filteredDestinations)
                Marker(
                  point: destination.location,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      controller.selectDestination(destination.id);
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => DestinationPopupSheet(destination: destination),
                      ).whenComplete(controller.clearSelection);
                    },
                    child: Icon(
                      categoryIcon(destination.category),
                      color: categoryColor(destination.category),
                      size: 32,
                    ),
                  ),
                ),
            ],
            builder: (context, markers) => CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '${markers.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Wire the screen into the router**

In `lib/core/router/app_router.dart`, replace the import:

```dart
import '../../features/map/view/map_screen.dart';
```

with:

```dart
import '../../features/destination_exploration/view/destination_map_screen.dart';
```

And replace the `ShellRoutes.map` route builder:

```dart
GoRoute(
  path: ShellRoutes.map,
  builder: (context, state) => const MapScreen(),
),
```

with:

```dart
GoRoute(
  path: ShellRoutes.map,
  builder: (context, state) => const DestinationMapScreen(),
),
```

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: PASS — all existing tests plus the 18 new tests from Tasks 1–5 pass.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze`
Expected: no new errors or warnings introduced by this feature's files.

- [ ] **Step 6: Manually verify in the browser**

Start the app (e.g. via the project's Chrome/web preview workflow), sign in, and land on the
Map tab (the default/root route). Confirm:
- Destination markers render on the Penang-centered map, colored/iconed per category.
- Zooming out clusters nearby markers into a numbered circle; zooming back in un-clusters
  them (A2).
- Tapping a category chip in the filter bar hides non-matching markers; tapping it again (or
  every chip) restores all markers (FR1.3, A1).
- Tapping a marker opens a bottom sheet with the destination's name, description, and either
  its images or the grey placeholder icon (FR1.2, E2).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/destination_exploration/view/destination_map_screen.dart lib/core/router/app_router.dart
git commit -m "feat(destination-map): add map screen and wire it into the Map tab route"
```

---

## Self-Review Notes

**Spec coverage:**
- FR1.1 (color-coded markers by category) — Task 6 (`categoryColor`/`categoryIcon` per
  marker), Task 3.
- FR1.2 (popup with name/description/images) — Task 5, wired in Task 6.
- FR1.3 (client-side category filter buttons) — Task 4.
- FR1.4 (clustering past ~20–30 pins) — Task 6 (`MarkerClusterLayerWidget`).
- FR1.5 (destination data with lat/long/category/name/description/images stored in a
  destinations table) — Task 1 (migration creating `destinations`, `MapDestination` +
  repository).
- NFR1 (performant/uncluttered at scale) — Task 6, proximity clustering.
- NFR3 (compact/scannable popup) — Task 5.
- NFR11 (OSM tiles, no billing risk) — Task 6, `TileLayer` + `flutter_map`.
- Use case A1 (deselect all filters shows everything) — Task 2
  (`filteredDestinations`/`clearFilters` logic), Task 4 test.
- Use case A2 (re-cluster on zoom/pan) — handled by `flutter_map_marker_cluster` itself, no
  extra app code needed.
- Use case E1 (load failure shows error + empty map) — Task 2 (`hasError`), Task 6 (error UI
  + retry).
- Use case E2 (no images shows placeholder) — Task 1 (`imageUrls` defaulting), Task 5.

**Placeholder scan:** no TBD/TODO, no "similar to Task N", no undefined references — checked.

**Type consistency:** `MapDestination` fields, `DestinationMapController` member names
(`destinations`, `isLoading`, `hasError`, `selectedCategories`, `selectedDestination`,
`filteredDestinations`, `loadDestinations`, `retry`, `toggleCategory`, `clearFilters`,
`selectDestination`, `clearSelection`) and `categoryColor`/`categoryIcon` signatures are used
identically across Tasks 1–6 — checked.
