# Destination Exploration — Feature 3: Attraction Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Attraction Comparison (FR3.1–FR3.11) as Model + Controller only (no View) —
destination search, selection, Best Pick scoring, and the three follow-up actions.

**Architecture:** Extends Feature 1's `destinations` table (new migration) and
`DestinationExplorationRepository`/`DestinationMapController`; adds two new controllers
(`DestinationSearchController`, `ComparisonController`) and a `ComparisonDestination` model
richer than Feature 1's map-marker `MapDestination`.

**Tech Stack:** Same as Features 1–2 (Flutter, `flutter_riverpod`, `supabase_flutter`,
`latlong2`, `geolocator`) plus `share_plus` (already a dependency, unused by this module yet).

**Prerequisite:** Features 1 and 2's plans already executed —
`DestinationExplorationRepository`, `MapDestination`, `DestinationMapController`,
`legDistanceKm` all exist as those plans built them.

## Global Constraints

- Best Pick's 4 weighted dimensions are Rating / Cost Efficiency / Crowd Density /
  Accessibility — **not** Hidden Gem Score, which is computed and available but never enters
  `compositeScore` (see the Feature 3 spec's revised "Best Pick weighting dimensions").
- When any compared destination is missing `entranceCost`, the `cost` dimension is dropped and
  the other three weights are renormalized by their existing proportions — not a second
  hardcoded ratio.
- `Save to Favourites` uses a new in-memory `FavouriteDestinationsStore`, mirroring
  `SavedItinerariesStore`'s "no real persistence layer yet" pattern exactly.
- `Add to Itinerary` reuses the existing `ItineraryPlannerController.addDestination()` —
  no new itinerary-mutation logic.
- No View is built in this plan — every task's deliverable is verified by `flutter test`, not
  a browser run.

---

## File Structure

```
supabase/migrations/
  202608060002_destinations_comparison_fields.sql   # Task 1
lib/features/destination_exploration/
  model/
    crowd_level.dart                            # Task 1
    comparison_destination.dart                 # Task 1
    destination_exploration_repository.dart     # Task 1 (modify: fetchForComparison), Task 2 (modify: searchDestinations)
    favourite_destinations_store.dart           # Task 4
  controller/
    destination_search_controller.dart          # Task 2
    destination_map_controller.dart             # Task 3 (modify)
    comparison_controller.dart                  # Task 5, Task 6 (modify)
test/
  destination_comparison_repository_test.dart     # Task 1
  destination_search_controller_test.dart         # Task 2
  destination_map_controller_test.dart            # Task 3 (modify)
  favourite_destinations_store_test.dart          # Task 4
  comparison_controller_test.dart                 # Task 5, Task 6 (modify)
```

---

### Task 1: Migration, model, and `fetchForComparison`

**Files:**
- Create: `supabase/migrations/202608060002_destinations_comparison_fields.sql`
- Create: `lib/features/destination_exploration/model/crowd_level.dart`
- Create: `lib/features/destination_exploration/model/comparison_destination.dart`
- Modify: `lib/features/destination_exploration/model/destination_exploration_repository.dart`
- Test: `test/destination_comparison_repository_test.dart`

**Interfaces:**
- Consumes: `HiddenGemScoring`, `HiddenGemCategory`, `GemPopularity`/`gemPopularityFromDb`
  (existing, shared).
- Produces:
  - `enum CrowdLevel { low, medium, high }`, `CrowdLevel crowdLevelFromDb(String? value)`.
  - `class ComparisonDestination` with fields `id, name, city, category (HiddenGemCategory), location (LatLng), avgRating, uniquenessScore, accessibilityScore, popularity (GemPopularity), crowdLevel (CrowdLevel), entranceCost (double?), difficultyLevel (String?), accessibilityTags (List<String>), visitDurationMinutes (int?), operatingHours (String?)`, plus a `double get hiddenGemScore` computed getter.
  - `DestinationExplorationRepository.fetchForComparison(List<String> ids)`.

- [ ] **Step 1: Write the migration**

```sql
-- supabase/migrations/202608060002_destinations_comparison_fields.sql
alter table public.destinations
  add column city text not null default '',
  add column uniqueness_score numeric not null default 0,
  add column accessibility_score numeric not null default 0,
  add column popularity text not null default 'medium',
  add column crowd_level text not null default 'medium',
  add column entrance_cost numeric,
  add column difficulty_level text,
  add column accessibility_tags text[],
  add column visit_duration_minutes integer,
  add column operating_hours text;

-- Give the seeded demo rows non-trivial scoring/comparison data instead of
-- leaving them all at the defaults above.
update public.destinations set
  city = 'George Town',
  uniqueness_score = 4.0,
  accessibility_score = 3.5,
  popularity = 'medium',
  crowd_level = 'medium',
  entrance_cost = 30,
  visit_duration_minutes = 90
where name = 'Penang Hill';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 4.5,
  accessibility_score = 3.0,
  popularity = 'high',
  crowd_level = 'high',
  entrance_cost = 0,
  visit_duration_minutes = 60
where name = 'Kek Lok Si Temple';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 4.2,
  accessibility_score = 4.5,
  popularity = 'high',
  crowd_level = 'high',
  entrance_cost = 0,
  visit_duration_minutes = 120
where name = 'George Town Street Art';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 3.8,
  accessibility_score = 4.0,
  popularity = 'low',
  crowd_level = 'low',
  entrance_cost = 25,
  visit_duration_minutes = 60
where name = 'Penang Peranakan Mansion';
```

Run this migration against the Supabase project, same as Feature 1's Task 1.

- [ ] **Step 2: Write `CrowdLevel`**

```dart
// lib/features/destination_exploration/model/crowd_level.dart

/// How busy a destination typically is, self-reported per destination (not
/// crowd-sourced like the difficulty/accessibility ratings in Feature 4).
enum CrowdLevel { low, medium, high }

extension CrowdLevelX on CrowdLevel {
  String get label {
    switch (this) {
      case CrowdLevel.low:
        return 'Low';
      case CrowdLevel.medium:
        return 'Medium';
      case CrowdLevel.high:
        return 'High';
    }
  }
}

CrowdLevel crowdLevelFromDb(String? value) {
  switch (value) {
    case 'low':
      return CrowdLevel.low;
    case 'high':
      return CrowdLevel.high;
    case 'medium':
    default:
      return CrowdLevel.medium;
  }
}
```

- [ ] **Step 3: Write `ComparisonDestination`**

```dart
// lib/features/destination_exploration/model/comparison_destination.dart
import 'package:latlong2/latlong.dart';

import '../../../shared/models/hidden_gem.dart';
import '../../../shared/services/hidden_gem_scoring.dart';
import 'crowd_level.dart';

/// A destination with every field Attraction Comparison needs — richer than
/// Feature 1's lean [MapDestination], which only carries what a map
/// marker/popup needs.
class ComparisonDestination {
  final String id;
  final String name;
  final String city;
  final HiddenGemCategory category;
  final LatLng location;
  final double avgRating;
  final double uniquenessScore;
  final double accessibilityScore;
  final GemPopularity popularity;
  final CrowdLevel crowdLevel;
  final double? entranceCost;
  final String? difficultyLevel;
  final List<String> accessibilityTags;
  final int? visitDurationMinutes;
  final String? operatingHours;

  const ComparisonDestination({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.location,
    this.avgRating = 0,
    this.uniquenessScore = 0,
    this.accessibilityScore = 0,
    this.popularity = GemPopularity.medium,
    this.crowdLevel = CrowdLevel.medium,
    this.entranceCost,
    this.difficultyLevel,
    this.accessibilityTags = const [],
    this.visitDurationMinutes,
    this.operatingHours,
  });

  /// Computed on demand from the shared formula — never stored, so the
  /// formula only ever lives in one place (FR3.3).
  double get hiddenGemScore => HiddenGemScoring.score(
        avgRating: avgRating,
        uniqueness: uniquenessScore,
        accessibility: accessibilityScore,
        popularity: popularity,
      );
}
```

- [ ] **Step 4: Write the failing repository test**

```dart
// test/destination_comparison_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/crowd_level.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/shared/models/hidden_gem.dart';

void main() {
  group('DestinationExplorationRepository.mapComparisonRow', () {
    test('maps a full row', () {
      final destination = DestinationExplorationRepository.mapComparisonRow({
        'id': 'place_1',
        'name': 'Penang Hill',
        'city': 'George Town',
        'category': 'viewpoint',
        'latitude': 5.4225,
        'longitude': 100.2769,
        'avg_rating': 4.6,
        'uniqueness_score': 4.0,
        'accessibility_score': 3.5,
        'popularity': 'medium',
        'crowd_level': 'high',
        'entrance_cost': 30,
        'difficulty_level': null,
        'accessibility_tags': null,
        'visit_duration_minutes': 90,
        'operating_hours': '9am - 7pm',
      });

      expect(destination.id, 'place_1');
      expect(destination.city, 'George Town');
      expect(destination.category, HiddenGemCategory.viewpoint);
      expect(destination.crowdLevel, CrowdLevel.high);
      expect(destination.entranceCost, 30);
      expect(destination.difficultyLevel, isNull);
      expect(destination.accessibilityTags, isEmpty);
      expect(destination.visitDurationMinutes, 90);
      expect(destination.operatingHours, '9am - 7pm');
      expect(destination.hiddenGemScore, greaterThan(0));
    });

    test('defaults city to empty and popularity/crowd to medium when null', () {
      final destination = DestinationExplorationRepository.mapComparisonRow({
        'id': 'place_2',
        'name': 'Unnamed',
        'city': null,
        'category': 'park',
        'latitude': 5.4,
        'longitude': 100.3,
        'popularity': null,
        'crowd_level': null,
      });

      expect(destination.city, '');
      expect(destination.popularity, GemPopularity.medium);
      expect(destination.crowdLevel, CrowdLevel.medium);
    });

    test('maps accessibility_tags when present', () {
      final destination = DestinationExplorationRepository.mapComparisonRow({
        'id': 'place_3',
        'name': 'Tagged Place',
        'city': 'George Town',
        'category': 'park',
        'latitude': 5.4,
        'longitude': 100.3,
        'accessibility_tags': ['wheelchair-friendly', 'shaded'],
      });

      expect(destination.accessibilityTags, ['wheelchair-friendly', 'shaded']);
    });
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/destination_comparison_repository_test.dart`
Expected: FAIL — `mapComparisonRow` doesn't exist yet (compile error).

- [ ] **Step 6: Add `mapComparisonRow` and `fetchForComparison` to the repository**

```dart
// lib/features/destination_exploration/model/destination_exploration_repository.dart
// Add these imports at the top:
// import '../../../shared/models/hidden_gem.dart' show GemPopularity, gemPopularityFromDb;
// import 'comparison_destination.dart';
// import 'crowd_level.dart';

// Add inside the DestinationExplorationRepository class:

  static ComparisonDestination mapComparisonRow(Map<String, dynamic> row) {
    final rawTags = row['accessibility_tags'];
    final accessibilityTags =
        rawTags is List ? rawTags.whereType<String>().toList() : const <String>[];

    return ComparisonDestination(
      id: row['id'] as String,
      name: row['name'] as String,
      city: (row['city'] as String?) ?? '',
      category: HiddenGemScoring.categoryFromDb(row['category'] as String),
      location: LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ),
      avgRating: (row['avg_rating'] as num?)?.toDouble() ?? 0.0,
      uniquenessScore: (row['uniqueness_score'] as num?)?.toDouble() ?? 0.0,
      accessibilityScore: (row['accessibility_score'] as num?)?.toDouble() ?? 0.0,
      popularity: gemPopularityFromDb(row['popularity'] as String?),
      crowdLevel: crowdLevelFromDb(row['crowd_level'] as String?),
      entranceCost: (row['entrance_cost'] as num?)?.toDouble(),
      difficultyLevel: row['difficulty_level'] as String?,
      accessibilityTags: accessibilityTags,
      visitDurationMinutes: (row['visit_duration_minutes'] as num?)?.toInt(),
      operatingHours: row['operating_hours'] as String?,
    );
  }

  Future<List<ComparisonDestination>> fetchForComparison(List<String> ids) async {
    final rows =
        await Supabase.instance.client.from('destinations').select().inFilter('id', ids);
    return rows.map(mapComparisonRow).toList();
  }
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/destination_comparison_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/202608060002_destinations_comparison_fields.sql lib/features/destination_exploration/model/crowd_level.dart lib/features/destination_exploration/model/comparison_destination.dart lib/features/destination_exploration/model/destination_exploration_repository.dart test/destination_comparison_repository_test.dart
git commit -m "feat(destination-comparison): add comparison fields migration, ComparisonDestination, fetchForComparison"
```

---

### Task 2: Destination search

**Files:**
- Modify: `lib/features/destination_exploration/model/destination_exploration_repository.dart`
- Create: `lib/features/destination_exploration/controller/destination_search_controller.dart`
- Test: `test/destination_search_controller_test.dart`

**Interfaces:**
- Consumes: `MapDestination`, `mapRow` (Feature 1), `HiddenGemCategory`.
- Produces:
  - `DestinationExplorationRepository.searchDestinations({String query = '', HiddenGemCategory? category, int limit = 20})`.
  - `class DestinationSearchController extends ChangeNotifier` with `query`, `results`,
    `isSearching`, `trending`, `categoryFilter`, `recentSearches`, `search(String)`,
    `setCategoryFilter(HiddenGemCategory?)`, `clearQuery()`.
  - `destinationSearchControllerProvider`.

- [ ] **Step 1: Add `searchDestinations` to the repository**

```dart
// lib/features/destination_exploration/model/destination_exploration_repository.dart
// Add inside the DestinationExplorationRepository class:

  Future<List<MapDestination>> searchDestinations({
    String query = '',
    HiddenGemCategory? category,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    final filterBuilder = Supabase.instance.client.from('destinations').select();
    final rows = trimmed.isEmpty
        ? await filterBuilder.order('avg_rating', ascending: false).limit(limit)
        : await filterBuilder
            .ilike('name', '%${trimmed.replaceAll(RegExp(r'[,()%]'), ' ').trim()}%')
            .order('avg_rating', ascending: false)
            .limit(limit);

    final results = rows.map(mapRow).toList();
    if (category == null) return results;
    return results.where((d) => d.category == category).toList();
  }
```

(No dedicated unit test for this method itself — it needs a live Supabase connection, same as
`loadDestinations`/`nearbyByCategory`. It's exercised indirectly through
`DestinationSearchController`'s tests below via a fake repository, and verified for real when
a View is eventually wired up.)

- [ ] **Step 2: Write the failing controller tests**

```dart
// test/destination_search_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/controller/destination_search_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/features/destination_exploration/model/map_destination.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeSearchRepository extends DestinationExplorationRepository {
  _FakeSearchRepository({this.searchResult = const [], this.trendingResult = const []});
  final List<MapDestination> searchResult;
  final List<MapDestination> trendingResult;

  @override
  Future<List<MapDestination>> searchDestinations({
    String query = '',
    HiddenGemCategory? category,
    int limit = 20,
  }) async {
    return query.trim().isEmpty ? trendingResult : searchResult;
  }
}

const _place = MapDestination(
  id: 'p1',
  name: 'Emerald Falls',
  description: '',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);

void main() {
  group('DestinationSearchController', () {
    test('loads trending destinations on construction', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(trendingResult: [_place]));
      await Future<void>.delayed(Duration.zero);

      expect(controller.trending, [_place]);
    });

    test('search debounces and populates results', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      await controller.search('Emerald');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(controller.results, [_place]);
      expect(controller.isSearching, isFalse);
    });

    test('search records a non-empty query into recentSearches', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      await controller.search('Emerald Falls');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(controller.recentSearches, ['Emerald Falls']);
    });

    test('recentSearches dedupes and caps at 5, most-recent-first', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));

      for (final term in ['a', 'b', 'c', 'd', 'e', 'a']) {
        await controller.search(term);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      expect(controller.recentSearches, ['a', 'e', 'd', 'c', 'b']);
    });

    test('clearing the query empties results without a new search', () async {
      final controller =
          DestinationSearchController(repository: _FakeSearchRepository(searchResult: [_place]));
      await controller.search('Emerald');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      controller.clearQuery();

      expect(controller.query, '');
      expect(controller.results, isEmpty);
    });
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/destination_search_controller_test.dart`
Expected: FAIL — `DestinationSearchController` doesn't exist yet (compile error).

- [ ] **Step 4: Write `DestinationSearchController`**

```dart
// lib/features/destination_exploration/controller/destination_search_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hidden_gem.dart';
import '../model/destination_exploration_repository.dart';
import '../model/map_destination.dart';

/// A second, alternate way (besides the map popup) to find and select
/// destinations for comparison. Kept separate from [DestinationMapController]
/// — search/browse is a distinct concern with its own lifecycle (query
/// debounce, recent-searches history). Selection itself is not duplicated
/// here — callers toggle selection straight through
/// `DestinationMapController.toggleComparisonSelection`.
class DestinationSearchController extends ChangeNotifier {
  DestinationSearchController({DestinationExplorationRepository? repository})
      : _repository = repository ?? DestinationExplorationRepository() {
    _loadTrending();
  }

  final DestinationExplorationRepository _repository;

  String query = '';
  List<MapDestination> results = const [];
  bool isSearching = false;
  List<MapDestination> trending = const [];
  HiddenGemCategory? categoryFilter;
  final List<String> recentSearches = [];

  Timer? _debounce;
  int _requestId = 0;
  Completer<void>? _pendingCompleter;

  Future<void> _loadTrending() async {
    trending = await _repository.searchDestinations();
    notifyListeners();
  }

  /// Debounced search. Returns a [Future] that completes once the debounced
  /// lookup settles, so tests can `await` it directly — but real callers
  /// (search-as-you-type) are not required to await each keystroke's call.
  /// A call superseded by a newer one before its timer fires completes its
  /// own (now-irrelevant) Future immediately instead of hanging forever —
  /// without this, an un-awaited call whose timer gets cancelled by the
  /// next keystroke would never resolve.
  Future<void> search(String newQuery) async {
    query = newQuery;
    _debounce?.cancel();
    if (_pendingCompleter?.isCompleted == false) _pendingCompleter!.complete();

    final trimmed = newQuery.trim();
    if (trimmed.isEmpty) {
      isSearching = false;
      results = const [];
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    final requestId = ++_requestId;
    final completer = Completer<void>();
    _pendingCompleter = completer;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final found =
          await _repository.searchDestinations(query: trimmed, category: categoryFilter);
      if (requestId == _requestId) {
        results = found;
        isSearching = false;
        _recordRecentSearch(trimmed);
        notifyListeners();
      }
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
  }

  void _recordRecentSearch(String term) {
    recentSearches.remove(term);
    recentSearches.insert(0, term);
    if (recentSearches.length > 5) recentSearches.removeLast();
  }

  void setCategoryFilter(HiddenGemCategory? category) {
    categoryFilter = category;
    if (query.trim().isNotEmpty) search(query);
  }

  void clearQuery() {
    _debounce?.cancel();
    query = '';
    results = const [];
    isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final destinationSearchControllerProvider =
    ChangeNotifierProvider<DestinationSearchController>((ref) {
  return DestinationSearchController();
});
```

Note: unlike `ItineraryPlannerController.updateSearchQuery` (fire-and-forget), `search()` here
returns a `Future` that completes once the debounced lookup finishes, so tests can `await` it
directly instead of racing a `Future.delayed`. The `Future.delayed` calls in Step 2's tests
still work either way (they wait at least as long as the debounce), but prefer `await controller.search(...)`
going forward once this method exists.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/destination_search_controller_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/destination_exploration/model/destination_exploration_repository.dart lib/features/destination_exploration/controller/destination_search_controller.dart test/destination_search_controller_test.dart
git commit -m "feat(destination-comparison): add searchDestinations and DestinationSearchController"
```

---

### Task 3: Selection for comparison

**Files:**
- Modify: `lib/features/destination_exploration/controller/destination_map_controller.dart`
- Modify: `test/destination_map_controller_test.dart`

**Interfaces:**
- Produces (added to `DestinationMapController`): `Set<String> selectedForComparison`,
  `bool get canCompare`, `void toggleComparisonSelection(String id)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/destination_map_controller_test.dart — add to the existing file

void main() {
  // ... existing groups stay ...

  group('DestinationMapController comparison selection', () {
    test('toggling adds and removes an id', () {
      final controller = DestinationMapController(repository: _FakeRepository(const []));

      controller.toggleComparisonSelection('a');
      expect(controller.selectedForComparison, {'a'});

      controller.toggleComparisonSelection('a');
      expect(controller.selectedForComparison, isEmpty);
    });

    test('canCompare is true only at 2 or 3 selections', () {
      final controller = DestinationMapController(repository: _FakeRepository(const []));

      expect(controller.canCompare, isFalse);
      controller.toggleComparisonSelection('a');
      expect(controller.canCompare, isFalse);
      controller.toggleComparisonSelection('b');
      expect(controller.canCompare, isTrue);
      controller.toggleComparisonSelection('c');
      expect(controller.canCompare, isTrue);
    });

    test('a 4th toggle is a no-op', () {
      final controller = DestinationMapController(repository: _FakeRepository(const []));

      controller.toggleComparisonSelection('a');
      controller.toggleComparisonSelection('b');
      controller.toggleComparisonSelection('c');
      controller.toggleComparisonSelection('d');

      expect(controller.selectedForComparison, {'a', 'b', 'c'});
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/destination_map_controller_test.dart`
Expected: FAIL — `selectedForComparison`/`canCompare`/`toggleComparisonSelection` don't exist
yet (compile error).

- [ ] **Step 3: Add the selection code**

```dart
// lib/features/destination_exploration/controller/destination_map_controller.dart
// Add alongside the existing selection state:

  final Set<String> selectedForComparison = {};

  bool get canCompare =>
      selectedForComparison.length == 2 || selectedForComparison.length == 3;

  void toggleComparisonSelection(String id) {
    if (selectedForComparison.contains(id)) {
      selectedForComparison.remove(id);
    } else {
      if (selectedForComparison.length >= 3) return;
      selectedForComparison.add(id);
    }
    notifyListeners();
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/destination_map_controller_test.dart`
Expected: PASS (18 tests — 15 existing + 3 new).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/controller/destination_map_controller.dart test/destination_map_controller_test.dart
git commit -m "feat(destination-comparison): add selection-for-comparison to DestinationMapController"
```

---

### Task 4: Favourites store

**Files:**
- Create: `lib/features/destination_exploration/model/favourite_destinations_store.dart`
- Test: `test/favourite_destinations_store_test.dart`

**Interfaces:**
- Consumes: `ComparisonDestination` (Task 1).
- Produces: `class FavouriteDestinationsStore` with `instance`, `favourites` (getter),
  `add(ComparisonDestination)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/favourite_destinations_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
import 'package:collab/shared/models/hidden_gem.dart';

const _destination = ComparisonDestination(
  id: 'd1',
  name: 'Emerald Falls',
  city: 'George Town',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);

void main() {
  setUp(() {
    // Reset the singleton's state between tests since it's process-global.
    FavouriteDestinationsStore.instance.clearForTesting();
  });

  test('add appends a destination', () {
    FavouriteDestinationsStore.instance.add(_destination);

    expect(FavouriteDestinationsStore.instance.favourites, [_destination]);
  });

  test('adding the same id twice does not duplicate', () {
    FavouriteDestinationsStore.instance.add(_destination);
    FavouriteDestinationsStore.instance.add(_destination);

    expect(FavouriteDestinationsStore.instance.favourites, hasLength(1));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/favourite_destinations_store_test.dart`
Expected: FAIL — `FavouriteDestinationsStore` doesn't exist yet (compile error).

- [ ] **Step 3: Write `FavouriteDestinationsStore`**

```dart
// lib/features/destination_exploration/model/favourite_destinations_store.dart
import 'comparison_destination.dart';

/// In-memory holding pen for favourited destinations until a real
/// persistence layer is agreed on for this module — same "no real
/// persistence yet" stance as SavedItinerariesStore
/// (lib/features/itinerary_planning/model/saved_itineraries_store.dart).
class FavouriteDestinationsStore {
  FavouriteDestinationsStore._internal();

  static final FavouriteDestinationsStore instance = FavouriteDestinationsStore._internal();

  final List<ComparisonDestination> _favourites = [];

  List<ComparisonDestination> get favourites => List.unmodifiable(_favourites);

  void add(ComparisonDestination destination) {
    if (_favourites.any((d) => d.id == destination.id)) return;
    _favourites.add(destination);
  }

  /// Test-only reset — the singleton otherwise persists state across tests.
  void clearForTesting() => _favourites.clear();
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/favourite_destinations_store_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/model/favourite_destinations_store.dart test/favourite_destinations_store_test.dart
git commit -m "feat(destination-comparison): add FavouriteDestinationsStore"
```

---

### Task 5: `ComparisonController` — loading and Best Pick scoring

**Files:**
- Create: `lib/features/destination_exploration/controller/comparison_controller.dart`
- Test: `test/comparison_controller_test.dart`

**Interfaces:**
- Consumes: `ComparisonDestination`, `CrowdLevel`, `DestinationExplorationRepository.fetchForComparison` (Task 1); `legDistanceKm` (Feature 2, `destination_exploration_repository.dart`).
- Produces:
  - `class PriorityWeights` — `{double rating, double cost, double crowd, double accessibility}`, `const` constructor with defaults `(0.4, 0.2, 0.2, 0.2)`, `PriorityWeights normalized()`.
  - `class ComparisonController extends ChangeNotifier` with `destinations`, `isLoading`,
    `selectionError`, `weights`, `setWeights(PriorityWeights)`,
    `loadComparison(List<String> ids)`, `bestPick` (getter),
    `distanceFromUser(ComparisonDestination)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/comparison_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:collab/features/destination_exploration/controller/comparison_controller.dart';
import 'package:collab/features/destination_exploration/model/comparison_destination.dart';
import 'package:collab/features/destination_exploration/model/crowd_level.dart';
import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart';
import 'package:collab/shared/models/hidden_gem.dart';

class _FakeComparisonRepository extends DestinationExplorationRepository {
  _FakeComparisonRepository(this.result);
  final List<ComparisonDestination> result;

  @override
  Future<List<ComparisonDestination>> fetchForComparison(List<String> ids) async => result;
}

ComparisonDestination _dest(
  String id, {
  double avgRating = 4.0,
  double accessibilityScore = 3.0,
  CrowdLevel crowdLevel = CrowdLevel.medium,
  double? entranceCost,
}) {
  return ComparisonDestination(
    id: id,
    name: id,
    city: 'George Town',
    category: HiddenGemCategory.nature,
    location: const LatLng(5.4, 100.3),
    avgRating: avgRating,
    accessibilityScore: accessibilityScore,
    crowdLevel: crowdLevel,
    entranceCost: entranceCost,
  );
}

void main() {
  group('PriorityWeights.normalized', () {
    test('divides each weight by their sum', () {
      const weights = PriorityWeights(rating: 2, cost: 1, crowd: 1, accessibility: 0);
      final normalized = weights.normalized();

      expect(normalized.rating, closeTo(0.5, 0.001));
      expect(normalized.cost, closeTo(0.25, 0.001));
      expect(normalized.crowd, closeTo(0.25, 0.001));
      expect(normalized.accessibility, closeTo(0, 0.001));
    });
  });

  group('ComparisonController.loadComparison', () {
    test('rejects fewer than 2 ids', () async {
      final controller = ComparisonController(repository: _FakeComparisonRepository(const []));

      await controller.loadComparison(['only-one']);

      expect(controller.selectionError, isNotNull);
      expect(controller.destinations, isEmpty);
    });

    test('rejects more than 3 ids', () async {
      final controller = ComparisonController(repository: _FakeComparisonRepository(const []));

      await controller.loadComparison(['a', 'b', 'c', 'd']);

      expect(controller.selectionError, isNotNull);
    });

    test('accepts 2 and 3 ids', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b')]));

      await controller.loadComparison(['a', 'b']);

      expect(controller.selectionError, isNull);
      expect(controller.destinations, hasLength(2));
    });
  });

  group('ComparisonController Best Pick scoring', () {
    test('higher rating/crowd/accessibility wins with full cost data present', () async {
      final low = _dest('low', avgRating: 3.0, accessibilityScore: 2.0, crowdLevel: CrowdLevel.high, entranceCost: 20);
      final high = _dest('high', avgRating: 4.9, accessibilityScore: 4.5, crowdLevel: CrowdLevel.low, entranceCost: 20);
      final controller = ComparisonController(repository: _FakeComparisonRepository([low, high]));

      await controller.loadComparison(['low', 'high']);

      expect(controller.bestPick, high);
    });

    test('equal cost across the set does not penalise anyone on cost', () async {
      final a = _dest('a', avgRating: 4.0, entranceCost: 50);
      final b = _dest('b', avgRating: 4.5, entranceCost: 50);
      final controller = ComparisonController(repository: _FakeComparisonRepository([a, b]));

      await controller.loadComparison(['a', 'b']);

      expect(controller.bestPick, b);
    });

    test('missing cost on any destination drops cost and renormalizes the rest', () async {
      final withCost = _dest('withCost', avgRating: 3.0, accessibilityScore: 5.0, entranceCost: 10);
      final withoutCost = _dest('withoutCost', avgRating: 4.9, accessibilityScore: 5.0, entranceCost: null);
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([withCost, withoutCost]));

      await controller.loadComparison(['withCost', 'withoutCost']);

      // Rating dominates once cost drops out and rating/crowd/accessibility
      // are renormalized — the much-higher-rated destination should win
      // even though it has no cost data at all.
      expect(controller.bestPick, withoutCost);
    });

    test('setWeights normalizes before use', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b')]));
      await controller.loadComparison(['a', 'b']);

      controller.setWeights(const PriorityWeights(rating: 10, cost: 0, crowd: 0, accessibility: 0));

      expect(controller.weights.rating, closeTo(1.0, 0.001));
    });

    test('bestPick is null when there are no destinations', () {
      final controller = ComparisonController(repository: _FakeComparisonRepository(const []));

      expect(controller.bestPick, isNull);
    });
  });

  group('ComparisonController.distanceFromUser', () {
    test('returns the great-circle distance when location is available', () async {
      final controller = ComparisonController(
        repository: _FakeComparisonRepository(const []),
        currentLocation: () async => const LatLng(5.4, 100.3),
      );

      final distance = await controller.distanceFromUser(_dest('a'));

      expect(distance, closeTo(0, 0.01));
    });

    test('returns null when location is unavailable', () async {
      final controller = ComparisonController(
        repository: _FakeComparisonRepository(const []),
        currentLocation: () async => null,
      );

      final distance = await controller.distanceFromUser(_dest('a'));

      expect(distance, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/comparison_controller_test.dart`
Expected: FAIL — `ComparisonController`/`PriorityWeights` don't exist yet (compile error).

- [ ] **Step 3: Write `PriorityWeights` and the core of `ComparisonController`**

```dart
// lib/features/destination_exploration/controller/comparison_controller.dart
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../model/comparison_destination.dart';
import '../model/crowd_level.dart';
import '../model/destination_exploration_repository.dart';

/// User-adjustable weighting for Best Pick scoring — matches the prepared
/// UI's four slider dimensions. Hidden Gem Score is deliberately not one of
/// these (see the Feature 3 design spec's revised scoring decision) — it's
/// still computed and displayed, just not weighted into the composite score.
class PriorityWeights {
  final double rating;
  final double cost;
  final double crowd;
  final double accessibility;

  const PriorityWeights({
    this.rating = 0.4,
    this.cost = 0.2,
    this.crowd = 0.2,
    this.accessibility = 0.2,
  });

  PriorityWeights normalized() {
    final sum = rating + cost + crowd + accessibility;
    if (sum <= 0) return this;
    return PriorityWeights(
      rating: rating / sum,
      cost: cost / sum,
      crowd: crowd / sum,
      accessibility: accessibility / sum,
    );
  }
}

/// Business logic for Attraction Comparison (Feature 3). Kept as a plain
/// [ChangeNotifier] per the module's MVC convention.
class ComparisonController extends ChangeNotifier {
  ComparisonController({
    DestinationExplorationRepository? repository,
    Future<LatLng?> Function()? currentLocation,
  })  : _repository = repository ?? DestinationExplorationRepository(),
        _currentLocation = currentLocation ?? _noLocation;

  final DestinationExplorationRepository _repository;
  final Future<LatLng?> Function() _currentLocation;

  static Future<LatLng?> _noLocation() async => null;

  List<ComparisonDestination> destinations = const [];
  bool isLoading = false;
  String? selectionError;
  String? shareError;
  PriorityWeights weights = const PriorityWeights();

  void setWeights(PriorityWeights newWeights) {
    weights = newWeights.normalized();
    notifyListeners();
  }

  Future<void> loadComparison(List<String> ids) async {
    if (ids.length < 2 || ids.length > 3) {
      selectionError = 'Select 2 or 3 destinations to compare.';
      notifyListeners();
      return;
    }

    selectionError = null;
    isLoading = true;
    notifyListeners();

    destinations = await _repository.fetchForComparison(ids);
    isLoading = false;
    notifyListeners();
  }

  double _compositeScore(ComparisonDestination destination) {
    final ratingNorm = destination.avgRating / 5.0;
    final crowdScore = switch (destination.crowdLevel) {
      CrowdLevel.low => 1.0,
      CrowdLevel.medium => 0.6,
      CrowdLevel.high => 0.25,
    };
    final accessibilityNorm = destination.accessibilityScore / 5.0;

    final allHaveCost = destinations.every((d) => d.entranceCost != null);
    if (allHaveCost) {
      final costs = destinations.map((d) => d.entranceCost!).toList();
      final minCost = costs.reduce((a, b) => a < b ? a : b);
      final maxCost = costs.reduce((a, b) => a > b ? a : b);
      final costEfficiency = maxCost == minCost
          ? 1.0
          : (maxCost - destination.entranceCost!) / (maxCost - minCost);

      return weights.rating * ratingNorm +
          weights.cost * costEfficiency +
          weights.crowd * crowdScore +
          weights.accessibility * accessibilityNorm;
    }

    final remainingSum = weights.rating + weights.crowd + weights.accessibility;
    if (remainingSum <= 0) return 0;
    final ratingW = weights.rating / remainingSum;
    final crowdW = weights.crowd / remainingSum;
    final accessibilityW = weights.accessibility / remainingSum;
    return ratingW * ratingNorm + crowdW * crowdScore + accessibilityW * accessibilityNorm;
  }

  ComparisonDestination? get bestPick {
    if (destinations.isEmpty) return null;
    var best = destinations.first;
    var bestScore = _compositeScore(best);
    for (final destination in destinations.skip(1)) {
      final score = _compositeScore(destination);
      if (score > bestScore) {
        best = destination;
        bestScore = score;
      }
    }
    return best;
  }

  Future<double?> distanceFromUser(ComparisonDestination destination) async {
    final point = await _currentLocation();
    if (point == null) return null;
    return legDistanceKm(point, destination.location);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/comparison_controller_test.dart`
Expected: PASS (12 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/controller/comparison_controller.dart test/comparison_controller_test.dart
git commit -m "feat(destination-comparison): add ComparisonController with Best Pick scoring"
```

---

### Task 6: `ComparisonController` — follow-up actions

**Files:**
- Modify: `lib/features/destination_exploration/controller/comparison_controller.dart`
- Modify: `test/comparison_controller_test.dart`

**Interfaces:**
- Consumes: `FavouriteDestinationsStore` (Task 4); `ItineraryPlannerController`,
  `Destination`, `DestinationCategory` (existing, `itinerary_planning` and
  `shared/models/destination.dart`); `share_plus`'s `Share`.
- Produces (added to `ComparisonController`): `addBestPickToItinerary(ItineraryPlannerController)`,
  `saveToFavourites(ComparisonDestination)`, `buildShareSummary()`, `shareComparison()`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/comparison_controller_test.dart — add to the existing file
// (add these imports near the top if not already present)
// import 'package:collab/features/destination_exploration/model/favourite_destinations_store.dart';
// import 'package:collab/features/itinerary_planning/controller/itinerary_planner_controller.dart';
// import 'package:collab/features/itinerary_planning/model/itinerary_repository.dart';
// import 'package:collab/shared/models/destination.dart' as shared;
// import 'package:collab/shared/models/hidden_gem.dart' show HiddenGem;

// addDestination() fires an un-awaited background gem-preview lookup through
// the real ItineraryRepository, which would hit Supabase (uninitialized in a
// plain unit test) — inject a fake so that background call resolves cleanly
// instead of risking an unhandled-exception warning from the test runner.
class _FakeItineraryRepository extends ItineraryRepository {
  @override
  Future<List<HiddenGem>> gemsNearDestinations(
    List<shared.Destination> destinations, {
    double radiusKm = 3,
    Set<HiddenGemCategory> categories = const {},
  }) async =>
      const [];
}

void main() {
  // ... existing groups stay ...

  group('ComparisonController follow-up actions', () {
    setUp(() {
      FavouriteDestinationsStore.instance.clearForTesting();
    });

    test('addBestPickToItinerary adds the Best Pick to the itinerary controller', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b', avgRating: 4.9)]));
      await controller.loadComparison(['a', 'b']);
      final itineraryController =
          ItineraryPlannerController(repository: _FakeItineraryRepository());

      await controller.addBestPickToItinerary(itineraryController);

      expect(itineraryController.selectedDestinations.map((d) => d.id), contains('b'));
    });

    test('saveToFavourites works on any compared destination, not just Best Pick', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b', avgRating: 4.9)]));
      await controller.loadComparison(['a', 'b']);

      controller.saveToFavourites(controller.destinations.first); // 'a', not the Best Pick

      expect(FavouriteDestinationsStore.instance.favourites.map((d) => d.id), contains('a'));
    });

    test('buildShareSummary names every destination and calls out the Best Pick', () async {
      final controller =
          ComparisonController(repository: _FakeComparisonRepository([_dest('a'), _dest('b', avgRating: 4.9)]));
      await controller.loadComparison(['a', 'b']);

      final summary = controller.buildShareSummary();

      expect(summary, contains('a'));
      expect(summary, contains('b'));
      expect(summary, contains('Best Pick: b'));
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/comparison_controller_test.dart`
Expected: FAIL — the three new methods don't exist yet (compile error).

- [ ] **Step 3: Add the follow-up actions**

```dart
// lib/features/destination_exploration/controller/comparison_controller.dart
// Add these imports at the top:
// import 'package:share_plus/share_plus.dart';
// import '../../../shared/models/destination.dart' as shared;
// import '../../../shared/models/hidden_gem.dart' show HiddenGemCategory;
// import '../../itinerary_planning/controller/itinerary_planner_controller.dart';
// import '../model/favourite_destinations_store.dart';

// Add inside the ComparisonController class, after distanceFromUser:

  Future<void> addBestPickToItinerary(ItineraryPlannerController itineraryController) async {
    final pick = bestPick;
    if (pick == null) return;
    itineraryController.addDestination(shared.Destination(
      id: pick.id,
      name: pick.name,
      city: pick.city,
      category: _representativeCategory(pick.category),
      location: pick.location,
    ));
  }

  void saveToFavourites(ComparisonDestination destination) {
    FavouriteDestinationsStore.instance.add(destination);
  }

  String buildShareSummary() {
    final buffer = StringBuffer()..writeln('Comparing ${destinations.length} destinations:');
    for (final destination in destinations) {
      buffer.writeln(
        '- ${destination.name} (${destination.avgRating.toStringAsFixed(1)}★, '
        'Hidden Gem ${destination.hiddenGemScore.toStringAsFixed(2)})',
      );
    }
    final pick = bestPick;
    if (pick != null) buffer.writeln('Best Pick: ${pick.name}');
    return buffer.toString();
  }

  Future<void> shareComparison() async {
    try {
      shareError = null;
      await Share.share(buildShareSummary());
    } catch (_) {
      shareError = "Couldn't share the comparison right now.";
    }
    notifyListeners();
  }

// Add this top-level function at the end of the file (outside the class):

/// A representative [shared.DestinationCategory] for a [HiddenGemCategory] —
/// lossy (several raw categories bucket into one HiddenGemCategory) but
/// good enough for the itinerary integration, which only needs *a*
/// reasonable category for display, not the original raw value.
shared.DestinationCategory _representativeCategory(HiddenGemCategory category) {
  switch (category) {
    case HiddenGemCategory.food:
      return shared.DestinationCategory.restaurant;
    case HiddenGemCategory.culture:
      return shared.DestinationCategory.heritageSite;
    case HiddenGemCategory.nature:
      return shared.DestinationCategory.park;
    case HiddenGemCategory.viewpoint:
      return shared.DestinationCategory.viewpoint;
    case HiddenGemCategory.craft:
      return shared.DestinationCategory.craft;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/comparison_controller_test.dart`
Expected: PASS (15 tests — 12 existing + 3 new).

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — every test across Features 1–3 passes.

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze`
Expected: no new errors or warnings.

- [ ] **Step 7: Commit**

```bash
git add lib/features/destination_exploration/controller/comparison_controller.dart test/comparison_controller_test.dart
git commit -m "feat(destination-comparison): add Add to Itinerary, Save to Favourites, Share Comparison"
```

---

## Self-Review Notes

**Spec coverage:**
- FR3.1 (select 2–3 via checkboxes) — Task 3 (`selectedForComparison`/`toggleComparisonSelection`),
  Task 2 (search as a second entry point).
- FR3.2 (side-by-side data) — Task 1/5 (`ComparisonDestination`, `loadComparison`).
- FR3.3 (required fields incl. Hidden Gem Score) — Task 1 (`ComparisonDestination.hiddenGemScore`,
  all required fields present).
- FR3.4 (optional fields, "Not available" fallback) — Task 1 (nullable fields map straight
  through; a future View renders null as "Not available").
- FR3.5–FR3.8 (Best Pick formula, weighting, highlight) — Task 5.
- FR3.6 (distance excluded from scoring, reference only) — Task 5
  (`distanceFromUser` is never read by `_compositeScore`).
- FR3.7 (adjustable weighting) — Task 5 (`setWeights`).
- FR3.9–FR3.11 (three follow-up actions) — Task 6.
- Use case A1 (adjust weights, recalculate) — Task 5 (`bestPick` is a getter, recomputed on
  every access — no stale cache to invalidate).
- Use case A2 (missing cost fallback) — Task 5's renormalization branch.
- Use case A3 (favourite a non-Best-Pick destination) — Task 6 test.
- Use case E1 (wrong selection count) — Task 5 (`loadComparison` guard).
- Use case E3 (share failure) — Task 6 (`shareComparison`'s try/catch).

**Placeholder scan:** no TBD/TODO, no undefined references — checked.

**Type consistency:** `ComparisonDestination`, `PriorityWeights`, and `ComparisonController`'s
member names match across Tasks 1, 5, and 6 exactly as declared — checked.
