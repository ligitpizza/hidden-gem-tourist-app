# Destination Exploration — Feature 2: Themed Destination Clusters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Themed Destination Clusters (FR2.1–FR2.4, NFR2, NFR4) by extending Feature 1's
`DestinationExplorationRepository`, `DestinationMapController`, and `DestinationMapScreen` —
no new files, no new controller class.

**Architecture:** A nearest-neighbour cluster query against the same `destinations` table,
triggered either from an explicitly-selected marker or auto-resolved from the user's current
GPS location, drawn as a dashed polyline + info card on Feature 1's existing map.

**Tech Stack:** Same as Feature 1 (Flutter, `flutter_map`, `flutter_riverpod`,
`supabase_flutter`, `latlong2`) plus `geolocator` (already a dependency, not yet used by
Feature 1's files).

**Prerequisite:** This plan assumes Feature 1's plan
(`docs/superpowers/plans/2026-08-06-destination-exploration-map.md`) has already been
executed — `DestinationExplorationRepository`, `MapDestination`, `DestinationMapController`,
and `DestinationMapScreen` all exist as that plan built them.

## Global Constraints

- Reads the same `destinations` table Feature 1 creates — no new migration.
- Category matching is by `HiddenGemCategory` (the bucketed enum on `MapDestination`), not the
  raw DB `category` string — computed in-memory after a bounding-box fetch, same two-stage
  pattern `ItineraryRepository._scoredPlacesInBounds` already uses (NFR2: bbox keeps fetched
  rows minimal, not a full-table scan).
- Cluster radius defaults to 12km, capped at 8 stops beyond the anchor — named constants, not
  magic numbers.
- The polyline is a straight-line approximation only — must be visually and textually
  distinguished from a real route (dashed stroke + a fixed disclaimer string), never implying
  real navigation (NFR4, FR2.4).
- `Geolocator` is called directly (no shared location service exists in this codebase — same
  direct-call convention as `lib/features/travel_assistant/view/eco_partner_screen.dart`), but
  wrapped behind an injectable seam on the controller so it's unit-testable without a real GPS
  fix.

---

## File Structure

```
lib/features/destination_exploration/
  model/
    destination_exploration_repository.dart   # Task 1 (modify)
  controller/
    destination_map_controller.dart           # Task 2 (modify)
  view/
    destination_map_screen.dart               # Task 3 (modify)
test/
  destination_map_repository_test.dart          # Task 1 (modify — add cluster tests)
  destination_map_controller_test.dart          # Task 2 (modify — add cluster tests)
```

---

### Task 1: Repository additions (cluster query, ordering, distance)

**Files:**
- Modify: `lib/features/destination_exploration/model/destination_exploration_repository.dart`
- Modify: `test/destination_map_repository_test.dart`

**Interfaces:**
- Consumes: `MapDestination`, `DestinationExplorationRepository.mapRow` (Feature 1, existing).
- Produces (all new, added to the same file):
  - `double legDistanceKm(LatLng a, LatLng b)` — top-level function.
  - `List<MapDestination> orderByNearestNeighbor(MapDestination origin, List<MapDestination> candidates)` — top-level function.
  - `DestinationExplorationRepository.nearbyByCategory({required MapDestination origin, double radiusKm = DestinationExplorationRepository.clusterRadiusKm, int maxStops = DestinationExplorationRepository.clusterMaxStops})`
  - `DestinationExplorationRepository.nearestDestination(LatLng point)`
  - `static const double DestinationExplorationRepository.clusterRadiusKm = 12`
  - `static const int DestinationExplorationRepository.clusterMaxStops = 8`

- [ ] **Step 1: Write the failing tests**

```dart
// test/destination_map_repository_test.dart — add to the existing file
// (add these imports near the top if not already present)
// import 'package:latlong2/latlong.dart';
// import 'package:collab/features/destination_exploration/model/map_destination.dart';

void main() {
  // ... existing group('DestinationExplorationRepository.mapRow', ...) stays ...

  group('legDistanceKm', () {
    test('computes a known distance', () {
      // Kuala Lumpur city centre to Batu Caves, ~11.5km apart.
      final km = legDistanceKm(
        const LatLng(3.1390, 101.6869),
        const LatLng(3.2379, 101.6840),
      );
      expect(km, closeTo(11.5, 1.0));
    });

    test('is zero for the same point', () {
      const point = LatLng(5.4164, 100.3327);
      expect(legDistanceKm(point, point), closeTo(0, 0.001));
    });
  });

  group('orderByNearestNeighbor', () {
    const origin = MapDestination(
      id: 'origin',
      name: 'Origin',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 0),
    );
    const near = MapDestination(
      id: 'near',
      name: 'Near',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 1),
    );
    const far = MapDestination(
      id: 'far',
      name: 'Far',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 5),
    );
    const mid = MapDestination(
      id: 'mid',
      name: 'Mid',
      description: '',
      category: HiddenGemCategory.culture,
      location: LatLng(0, 3),
    );

    test('returns an empty list for no candidates', () {
      expect(orderByNearestNeighbor(origin, const []), isEmpty);
    });

    test('returns the single candidate unchanged', () {
      expect(orderByNearestNeighbor(origin, [near]), [near]);
    });

    test('greedily visits closest-first from a scrambled input', () {
      final ordered = orderByNearestNeighbor(origin, [far, near, mid]);
      expect(ordered, [near, mid, far]);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/destination_map_repository_test.dart`
Expected: FAIL — `legDistanceKm`/`orderByNearestNeighbor` don't exist yet (compile error).

- [ ] **Step 3: Add the repository code**

```dart
// lib/features/destination_exploration/model/destination_exploration_repository.dart
// Add these imports at the top, alongside the existing ones:
// import 'dart:math';

// Add these top-level functions (outside the class, same file):

/// Great-circle distance between two points, in kilometres.
double legDistanceKm(LatLng a, LatLng b) {
  const distance = Distance();
  return distance.as(LengthUnit.Kilometer, a, b);
}

/// Greedy nearest-neighbour visiting order starting from [origin]: repeatedly
/// picks the closest not-yet-visited candidate to the last-placed stop.
List<MapDestination> orderByNearestNeighbor(
  MapDestination origin,
  List<MapDestination> candidates,
) {
  final remaining = List<MapDestination>.from(candidates);
  final ordered = <MapDestination>[];
  var current = origin.location;

  while (remaining.isNotEmpty) {
    remaining.sort(
      (a, b) => legDistanceKm(current, a.location).compareTo(legDistanceKm(current, b.location)),
    );
    final next = remaining.removeAt(0);
    ordered.add(next);
    current = next.location;
  }

  return ordered;
}

// Add these members inside the DestinationExplorationRepository class, alongside
// the existing mapRow/loadDestinations:

  static const double clusterRadiusKm = 12;
  static const int clusterMaxStops = 8;

  /// Same-category destinations near [origin], closest-first, within
  /// [radiusKm] and capped at [maxStops] — the visiting order (nearest-
  /// neighbour) is computed separately by [orderByNearestNeighbor].
  Future<List<MapDestination>> nearbyByCategory({
    required MapDestination origin,
    double radiusKm = clusterRadiusKm,
    int maxStops = clusterMaxStops,
  }) async {
    final bufferDeg = radiusKm / 111.0;
    final lat = origin.location.latitude;
    final lng = origin.location.longitude;

    final rows = await Supabase.instance.client
        .from('destinations')
        .select()
        .gte('latitude', lat - bufferDeg)
        .lte('latitude', lat + bufferDeg)
        .gte('longitude', lng - bufferDeg)
        .lte('longitude', lng + bufferDeg);

    final candidates = rows
        .map(mapRow)
        .where((d) => d.id != origin.id && d.category == origin.category)
        .where((d) => legDistanceKm(origin.location, d.location) <= radiusKm)
        .toList()
      ..sort(
        (a, b) => legDistanceKm(origin.location, a.location)
            .compareTo(legDistanceKm(origin.location, b.location)),
      );

    return candidates.take(maxStops).toList();
  }

  /// The closest destination (any category) to [point], searching an
  /// expanding radius so a sparse area doesn't require scanning the whole
  /// table. Returns null if nothing is found even at the widest radius.
  Future<MapDestination?> nearestDestination(LatLng point) async {
    for (final radiusKm in const [5.0, 10.0, 20.0, 40.0]) {
      final bufferDeg = radiusKm / 111.0;
      final rows = await Supabase.instance.client
          .from('destinations')
          .select()
          .gte('latitude', point.latitude - bufferDeg)
          .lte('latitude', point.latitude + bufferDeg)
          .gte('longitude', point.longitude - bufferDeg)
          .lte('longitude', point.longitude + bufferDeg);

      if (rows.isEmpty) continue;

      final candidates = rows.map(mapRow).toList()
        ..sort(
          (a, b) =>
              legDistanceKm(point, a.location).compareTo(legDistanceKm(point, b.location)),
        );
      return candidates.first;
    }
    return null;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/destination_map_repository_test.dart`
Expected: PASS (10 tests — 5 existing + 5 new).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/model/destination_exploration_repository.dart test/destination_map_repository_test.dart
git commit -m "feat(destination-clusters): add nearbyByCategory, nearestDestination, orderByNearestNeighbor"
```

---

### Task 2: Controller additions (cluster state)

**Files:**
- Modify: `lib/features/destination_exploration/controller/destination_map_controller.dart`
- Modify: `test/destination_map_controller_test.dart`

**Interfaces:**
- Consumes: `legDistanceKm`, `orderByNearestNeighbor`, `nearbyByCategory`, `nearestDestination` (Task 1).
- Produces (added to `DestinationMapController`):
  - Constructor gains an optional `Future<LatLng?> Function()? currentLocation` parameter
    (defaults to a real `Geolocator`-backed implementation) — the testability seam.
  - `MapDestination? clusterAnchor`
  - `List<MapDestination> clusterStops`
  - `List<LatLng> get clusterPolyline`
  - `List<double> get legDistancesKm`
  - `double get totalDistanceKm`
  - `bool isLoadingCluster`
  - `String? clusterMessage`
  - `Future<void> viewThemedCluster({MapDestination? origin})`
  - `void clearCluster()`

- [ ] **Step 1: Write the failing tests**

```dart
// test/destination_map_controller_test.dart — add to the existing file
// (add these imports near the top if not already present)
// import 'package:collab/features/destination_exploration/model/destination_exploration_repository.dart'
//     show legDistanceKm; // orderByNearestNeighbor etc. already covered elsewhere

// Extend the existing _FakeRepository with cluster support, or add a second fake:
class _ClusterFakeRepository extends DestinationExplorationRepository {
  _ClusterFakeRepository({
    this.nearbyResult = const [],
    this.nearestResult,
    this.throwOnNearby = false,
  });
  final List<MapDestination> nearbyResult;
  final MapDestination? nearestResult;
  final bool throwOnNearby;

  @override
  Future<List<MapDestination>> loadDestinations() async => const [];

  @override
  Future<List<MapDestination>> nearbyByCategory({
    required MapDestination origin,
    double radiusKm = DestinationExplorationRepository.clusterRadiusKm,
    int maxStops = DestinationExplorationRepository.clusterMaxStops,
  }) async {
    if (throwOnNearby) throw Exception('network error');
    return nearbyResult;
  }

  @override
  Future<MapDestination?> nearestDestination(LatLng point) async => nearestResult;
}

const _anchor = MapDestination(
  id: 'anchor',
  name: 'Anchor',
  description: '',
  category: HiddenGemCategory.nature,
  location: LatLng(5.4, 100.3),
);
const _stop1 = MapDestination(
  id: 'stop1',
  name: 'Stop 1',
  description: '',
  category: HiddenGemCategory.nature,
  location: LatLng(5.41, 100.31),
);

void main() {
  // ... existing group('DestinationMapController', ...) stays ...

  group('DestinationMapController cluster', () {
    test('viewThemedCluster with an explicit origin populates the cluster', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1]),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.clusterAnchor, _anchor);
      expect(controller.clusterStops, [_stop1]);
      expect(controller.clusterMessage, isNull);
      expect(controller.clusterPolyline, [_anchor.location, _stop1.location]);
    });

    test('viewThemedCluster with no origin resolves the anchor from location', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1], nearestResult: _anchor),
        currentLocation: () async => const LatLng(5.4, 100.3),
      );

      await controller.viewThemedCluster();

      expect(controller.clusterAnchor, _anchor);
      expect(controller.clusterStops, [_stop1]);
    });

    test('sets a message when location cannot be determined and no origin is given', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(),
        currentLocation: () async => null,
      );

      await controller.viewThemedCluster();

      expect(controller.clusterMessage, "Couldn't determine your location to find a themed trail.");
      expect(controller.clusterAnchor, isNull);
    });

    test('sets a "no cluster available" message on zero results', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: const []),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.clusterMessage, 'No themed cluster available nearby.');
      expect(controller.clusterStops, isEmpty);
    });

    test('sets a failure message when the repository throws', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(throwOnNearby: true),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.clusterMessage, "Couldn't load a themed cluster right now.");
    });

    test('legDistancesKm and totalDistanceKm reflect the polyline', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1]),
      );

      await controller.viewThemedCluster(origin: _anchor);

      expect(controller.legDistancesKm, hasLength(1));
      expect(controller.legDistancesKm.first, closeTo(legDistanceKm(_anchor.location, _stop1.location), 0.001));
      expect(controller.totalDistanceKm, closeTo(controller.legDistancesKm.first, 0.001));
    });

    test('clearCluster resets all cluster fields', () async {
      final controller = DestinationMapController(
        repository: _ClusterFakeRepository(nearbyResult: [_stop1]),
      );
      await controller.viewThemedCluster(origin: _anchor);

      controller.clearCluster();

      expect(controller.clusterAnchor, isNull);
      expect(controller.clusterStops, isEmpty);
      expect(controller.clusterMessage, isNull);
      expect(controller.isLoadingCluster, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/destination_map_controller_test.dart`
Expected: FAIL — `clusterAnchor`/`viewThemedCluster`/etc. don't exist yet (compile error).

- [ ] **Step 3: Add the controller code**

```dart
// lib/features/destination_exploration/controller/destination_map_controller.dart
// Add these imports at the top, alongside the existing ones:
// import 'package:geolocator/geolocator.dart';
// import 'package:latlong2/latlong.dart';

// Change the constructor to accept the location seam:
  DestinationMapController({
    DestinationExplorationRepository? repository,
    Future<LatLng?> Function()? currentLocation,
  })  : _repository = repository ?? DestinationExplorationRepository(),
        _currentLocation = currentLocation ?? _defaultCurrentLocation {
    loadDestinations();
  }

  final DestinationExplorationRepository _repository;
  final Future<LatLng?> Function() _currentLocation;

  static Future<LatLng?> _defaultCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

// Add these members alongside the existing selection state:

  MapDestination? clusterAnchor;
  List<MapDestination> clusterStops = const [];
  bool isLoadingCluster = false;
  String? clusterMessage;

  List<LatLng> get clusterPolyline {
    final anchor = clusterAnchor;
    if (anchor == null) return const [];
    return [anchor.location, ...clusterStops.map((d) => d.location)];
  }

  List<double> get legDistancesKm {
    final points = clusterPolyline;
    if (points.length < 2) return const [];
    return [
      for (var i = 0; i < points.length - 1; i++) legDistanceKm(points[i], points[i + 1]),
    ];
  }

  double get totalDistanceKm => legDistancesKm.fold(0.0, (sum, d) => sum + d);

  Future<void> viewThemedCluster({MapDestination? origin}) async {
    isLoadingCluster = true;
    clusterMessage = null;
    notifyListeners();

    try {
      final anchor = origin ?? await _resolveAnchorFromLocation();
      if (anchor == null) {
        clusterAnchor = null;
        clusterStops = const [];
        clusterMessage = "Couldn't determine your location to find a themed trail.";
        isLoadingCluster = false;
        notifyListeners();
        return;
      }

      final candidates = await _repository.nearbyByCategory(origin: anchor);
      clusterAnchor = anchor;
      clusterStops = orderByNearestNeighbor(anchor, candidates);
      clusterMessage = clusterStops.isEmpty ? 'No themed cluster available nearby.' : null;
    } catch (_) {
      clusterAnchor = null;
      clusterStops = const [];
      clusterMessage = "Couldn't load a themed cluster right now.";
    }

    isLoadingCluster = false;
    notifyListeners();
  }

  Future<MapDestination?> _resolveAnchorFromLocation() async {
    final point = await _currentLocation();
    if (point == null) return null;
    return _repository.nearestDestination(point);
  }

  void clearCluster() {
    clusterAnchor = null;
    clusterStops = const [];
    clusterMessage = null;
    isLoadingCluster = false;
    notifyListeners();
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/destination_map_controller_test.dart`
Expected: PASS (15 tests — 8 existing + 7 new).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/controller/destination_map_controller.dart test/destination_map_controller_test.dart
git commit -m "feat(destination-clusters): add cluster state to DestinationMapController"
```

---

### Task 3: View additions (polyline, trigger button, cluster card)

**Files:**
- Modify: `lib/features/destination_exploration/view/destination_map_screen.dart`

**Interfaces:**
- Consumes: `clusterAnchor`, `clusterStops`, `clusterPolyline`, `legDistancesKm`,
  `totalDistanceKm`, `clusterMessage`, `viewThemedCluster`, `clearCluster`,
  `selectedDestination` (all from Task 2 / Feature 1).

No automated test — same rationale as Feature 1's screen task (heavy `flutter_map` widget
tests, out of scope). Verified manually in Step 3.

- [ ] **Step 1: Add the polyline layer and cluster card**

```dart
// lib/features/destination_exploration/view/destination_map_screen.dart
// Add this import at the top:
// import 'package:flutter_map/flutter_map.dart' show PolylineLayer, Polyline; // already imports flutter_map

// Inside FlutterMap's `children` list, after the MarkerClusterLayerWidget, add:
        if (controller.clusterPolyline.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: controller.clusterPolyline,
                strokeWidth: 4,
                color: Colors.deepOrange,
                pattern: const StrokePattern.dashed(segments: [10, 6]),
              ),
            ],
          ),

// Change _MapBody's build method to wrap the existing `return FlutterMap(...)` in a Stack so
// the cluster card/banner can overlay the map. The existing map-loading/error branches above
// stay unchanged (they still return early before this point); only the final success-path
// return changes from:
//
//   return FlutterMap(...);
//
// to:

    return Stack(
      children: [
        FlutterMap(
          // ...unchanged MapOptions/children from Step 1 above and Feature 1's Task 6...
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () =>
                controller.viewThemedCluster(origin: controller.selectedDestination),
            icon: const Icon(Icons.route_outlined),
            label: const Text('View Themed Trail'),
          ),
        ),
        if (controller.clusterAnchor != null || controller.clusterMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 84,
            child: _ClusterCard(controller: controller),
          ),
      ],
    );
```

- [ ] **Step 2: Add the `_ClusterCard` widget**

```dart
// Add to the same file (lib/features/destination_exploration/view/destination_map_screen.dart):

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({required this.controller});

  final DestinationMapController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.clusterMessage ?? 'Suggested Trail',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: controller.clearCluster,
                ),
              ],
            ),
            if (controller.clusterAnchor != null) ...[
              Text('${controller.totalDistanceKm.toStringAsFixed(1)}km total'),
              const SizedBox(height: 8),
              Text('1. ${controller.clusterAnchor!.name} • Selected Anchor'),
              for (var i = 0; i < controller.clusterStops.length; i++)
                Text(
                  '${i + 2}. ${controller.clusterStops[i].name} • '
                  '${controller.legDistancesKm[i].toStringAsFixed(1)}km away',
                ),
              const SizedBox(height: 8),
              const Text(
                'Suggested path only — not a navigable route',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify manually in the browser**

Run: `flutter analyze` — expect no new errors.

Start the app, open the Map tab, and confirm:
- The "View Themed Trail" button is visible in the bottom-right corner.
- Tapping a marker then the button draws a dashed polyline from that marker through its
  cluster, and the card lists the anchor + each stop with distances and the "Suggested path
  only" disclaimer.
- Tapping the button with no marker selected falls back to resolving the anchor from the
  browser's geolocation (grant location permission when prompted).
- Tapping the card's close (✕) button clears the polyline and card.

- [ ] **Step 4: Commit**

```bash
git add lib/features/destination_exploration/view/destination_map_screen.dart
git commit -m "feat(destination-clusters): add polyline, trigger button, and cluster card to the map screen"
```

---

## Self-Review Notes

**Spec coverage:**
- FR2.1 (query nearby same-category destinations within a radius) — Task 1 `nearbyByCategory`.
- FR2.2 (nearest-neighbour ordering) — Task 1 `orderByNearestNeighbor`.
- FR2.3 (connected polyline overlay) — Task 3 `PolylineLayer`.
- FR2.4 (labelled "suggested cluster", not verified) — Task 3 `_ClusterCard`'s disclaimer text.
- NFR2 (minimal fetched rows) — Task 1's bounding-box queries.
- NFR4 (visually/textually distinct from a real route) — Task 3's dashed stroke + disclaimer.
- Use case A1 (switching anchor) — `viewThemedCluster` overwrites state each call, no
  special-case code needed (Task 2).
- Use case A2 (re-cluster on zoom/pan) — no app code needed; `flutter_map` redraws the
  polyline layer automatically as the map moves.
- Use case E1 (nothing nearby) — Task 2's zero-results branch.
- Use case E2 (sparse results) — implicit, shorter `clusterStops`/`legDistancesKm`.
- Revised trigger (persistent button + GPS fallback) — Task 2's optional `origin` param and
  `_resolveAnchorFromLocation`; Task 3's always-visible FAB.
- Revised per-stop/total distances — Task 2's `legDistancesKm`/`totalDistanceKm`, rendered in
  Task 3's card.

**Placeholder scan:** no TBD/TODO, no undefined references — checked.

**Type consistency:** `clusterAnchor`, `clusterStops`, `clusterPolyline`, `legDistancesKm`,
`totalDistanceKm`, `clusterMessage`, `isLoadingCluster`, `viewThemedCluster({MapDestination? origin})`,
`clearCluster()` are used identically across Tasks 2 and 3 — checked.
