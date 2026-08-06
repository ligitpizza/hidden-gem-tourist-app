# Destination Exploration — Feature 2: Themed Destination Clusters

Status: Approved
Date: 2026-08-06
Revised: 2026-08-06 — after reviewing the prepared UI: trigger changed from a popup button to
a persistent map control that can auto-resolve the anchor from the user's current location
(see Decisions and Controller additions); per-stop and total trail distances added.

## Context

Second of the four Destination Exploration module features, built one at a time. This spec
covers **Feature 2 only** (Themed Destination Clusters, FR2.1–FR2.4, NFR2, NFR4, NFR10) and
builds directly on top of Feature 1 (Interactive Destination Map — see
`2026-08-06-destination-exploration-map-design.md`), which is spec'd and planned but not yet
implemented.

Source requirements: FR2.1–FR2.4, NFR2, NFR4, NFR10, and the "View Themed Destination
Cluster" use case (basic flow, A1, E1/E2), as supplied by the user on 2026-08-06.

## Decisions made during brainstorming

- **Not standalone — extends Feature 1**: unlike Feature 1 (which was revised to be fully
  standalone, with its own dedicated `destinations` table), Feature 2 explicitly reuses
  Feature 1's map, data, and controller rather than building a parallel screen. It reads from
  the same `destinations` table Feature 1 introduces.
- **Trigger point (revised)**: the prepared UI shows "View Themed Trail" as a persistent
  control on the map itself (reached via a "+" drawer/speed-dial button in the map's bottom
  corner that also hosts other map-associated actions, e.g. comparison) — not a button inside
  the popup sheet as originally designed. Per the user: the feature "cluster[s] same
  destination category and based on user current location to gather nearby destinations that
  share the same category within a radius." So `viewThemedCluster` now supports **both**: an
  explicit origin (if the user had already tapped/selected a marker) or, when none is
  selected, auto-resolving the anchor as the destination nearest the user's current GPS
  location — see Controller additions below. The prepared UI's cluster card labels the anchor
  "Selected Anchor" regardless of which path picked it (user tap or GPS-nearest), so no
  user-facing distinction is needed. The drawer/speed-dial UI pattern itself is a View-layer
  detail, not built in this spec (no View is being built for the trigger button beyond what's
  already planned for Feature 1's screen) — noted here so the eventual View task knows the
  target interaction.
- **State ownership**: cluster state (origin, ordered nearby stops, polyline, status message)
  is added directly to Feature 1's `DestinationMapController` rather than a separate
  controller — one map, one controller, one source of truth.
- **Radius default**: 12km (within the spec's suggested 10–15km range), expressed as a
  named constant so it's a one-line change later.
- **Cluster size cap**: 8 additional stops beyond the origin (9 total), to keep the polyline
  and the underlying query bounded (NFR2) and the map readable.
- **Persistence (NFR10)**: out of scope. The spec itself marks this "ideally... currently a
  gap" — not a hard requirement. Cluster state resets on navigation away from the map screen.

## Architecture

Extends Feature 1's files — no new screen, no new controller class:

```
model/
  destination_exploration_repository.dart   # + nearbyByCategory(), orderByNearestNeighbor()
controller/
  destination_map_controller.dart           # + cluster state/methods
view/
  destination_map_screen.dart               # + PolylineLayer + "suggested cluster" banner
  widgets/
    destination_popup_sheet.dart            # + "View Themed Cluster" button
```

## Data

No new table or migration. Reads the same `destinations` table Feature 1 creates, filtered by
category and a lat/lng bounding box (same technique already used elsewhere in the codebase,
e.g. `ItineraryRepository`'s corridor search) so only relevant rows are fetched (NFR2) —
not the whole table.

## Repository additions

`DestinationExplorationRepository`:

- `Future<List<MapDestination>> nearbyByCategory({required MapDestination origin, double radiusKm = _clusterRadiusKm, int maxStops = _clusterMaxStops})`
  — queries `destinations` inside a bounding box around `origin.location`, filtered to
  `origin.category`, excluding `origin.id`, then keeps only rows within the real great-circle
  `radiusKm` (bbox is an approximation; the precise filter is a second, in-memory step — same
  two-stage pattern as `ItineraryRepository._scoredPlacesInBounds`), capped to `maxStops`
  results, closest-first is not required at this stage since ordering happens next.
- `orderByNearestNeighbor(MapDestination origin, List<MapDestination> candidates)` — a pure,
  standalone function (not a repository method, so it's trivially unit-testable): greedy
  nearest-neighbor starting from `origin` — repeatedly picks the closest unvisited candidate
  to the last-placed stop, appending until none remain (FR2.2). Ties broken by candidate order
  (stable, no special tie-breaking logic needed).

## Controller additions

`DestinationMapController` gains:
- `List<MapDestination> clusterStops` — ordered nearby destinations (empty = no active
  cluster).
- `List<LatLng> get clusterPolyline` — `[selectedDestination.location, ...clusterStops.map((d) => d.location)]` when a cluster is active, else `[]`.
- `bool isLoadingCluster`
- `String? clusterMessage` — user-facing text when there's nothing to show (E1) or the load
  failed; `null` when a cluster is successfully showing or no cluster has been requested.
- `Future<void> viewThemedCluster(MapDestination origin)` — calls `nearbyByCategory`, then
  `orderByNearestNeighbor`; on success with results, sets `clusterStops` and clears
  `clusterMessage`; on success with zero results, sets `clusterMessage = 'No themed cluster available nearby.'` (E1); on a thrown error, sets `clusterMessage = "Couldn't load a themed cluster right now."`.
- `void clearCluster()` — resets `clusterStops`, `clusterMessage`, `isLoadingCluster` to their
  empty/false state.

`selectDestination`/`clearSelection` (from Feature 1) are unchanged; closing or changing the
popup does **not** automatically clear an active cluster — only `clearCluster()` (the banner's
close button) or requesting a new cluster for a different origin (A1) does.

## View additions

- `DestinationPopupSheet` gains a "View Themed Cluster" button (uses `categoryColor`/
  `categoryIcon` styling already established in Feature 1) that calls
  `controller.viewThemedCluster(destination)`.
- `DestinationMapScreen`'s map gains a `PolylineLayer`, rendered only when
  `controller.clusterPolyline` is non-empty, styled distinctly from anything resembling a
  real route (dashed stroke, a color not used by any marker category) — satisfying NFR4.
- A small dismissible banner overlays the map whenever a cluster is active or
  `clusterMessage` is set:
  - Active cluster: text **"Suggested cluster — not a verified route"** (FR2.4, NFR4) with a
    close (✕) button calling `clearCluster()`.
  - `clusterMessage` set (E1 or load failure): the message text, with the same close button
    (also calling `clearCluster()`).
- Selecting a different destination and requesting its cluster (A1) simply calls
  `viewThemedCluster` again — the controller overwrites `clusterStops`/`clusterMessage`, so
  the View doesn't need special-case logic for "switching" clusters.

## Error handling

- E1 (no other same-category destinations within radius): `clusterMessage` is set instead of
  drawing an empty/single-point polyline; no crash, no misleading empty line.
- E2 (sparse data, fewer than the cap): handled implicitly — the polyline and stop list are
  simply shorter; no special-casing needed.
- Repository/network failure: caught in the controller (same defensive pattern as Feature 1's
  `loadDestinations`), surfaced via `clusterMessage`.

## Testing

Pure-logic unit tests (no network, no widget pump):
- `orderByNearestNeighbor`: empty candidate list, single candidate, multiple candidates in a
  scrambled input order (asserting the greedy nearest-first output), a tie case.
- The bbox + category + exclude-origin + precise-radius filtering logic in
  `nearbyByCategory` (the same style of pure/testable split used for
  `DestinationExplorationRepository.mapRow` in Feature 1 — the query itself needs Supabase,
  but the row-filtering/shaping logic around it doesn't).
- Controller: `viewThemedCluster` success (populates `clusterStops`, clears
  `clusterMessage`), zero-results (sets the "no cluster available" message), failure (sets
  the "couldn't load" message), and `clearCluster` resetting all three fields.

Visual verification (polyline styling, banner, popup button) via a manual browser/emulator
run once wired up, per Feature 1's same approach — no `flutter_map` widget tests.

## Out of scope (this spec)

- Persisting cluster state across page refresh (NFR10 — explicitly optional/gap per spec).
- Features 3–4 (comparison, crowd-sourced ratings) — separate specs.
- Real routing/navigable directions for the polyline — it's a straight-line approximation
  only, by design (constraint carried over from the use case).
