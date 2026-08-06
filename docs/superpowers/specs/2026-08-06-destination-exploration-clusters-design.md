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
  user-facing distinction is needed. The View still gets a real trigger control (per Feature
  1's "build a working View now" decision) — it just becomes a persistent map button instead
  of a popup button; the exact drawer/speed-dial multi-action styling shown in the prepared UI
  is a View-layer detail worked out in the implementation plan, not this spec.
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
- `Future<MapDestination?> nearestDestination(LatLng point)` (new) — used to auto-resolve a
  cluster anchor from the user's current GPS location when no destination was explicitly
  selected (see the revised Trigger point decision). Queries `destinations` in a small
  expanding bounding box around `point` (starting at ~5km, doubling up to ~40km, so a sparse
  area doesn't require scanning the whole table) and returns the closest row, or `null` if
  none is found even at the widest box.

## Distance calculation (new)

A standalone `legDistanceKm(LatLng a, LatLng b)` helper (thin wrapper around `latlong2`'s
`Distance().as(LengthUnit.Kilometer, a, b)`, the same class `ItineraryRepository` already
uses) computes the distance for each consecutive pair in `[origin, ...clusterStops]`, and
their sum is the trail's total distance — both shown in the prepared UI's cluster card
("1.2km away", "5.2km total").

## Controller additions

`DestinationMapController` gains:
- `MapDestination? clusterAnchor` — the resolved anchor (either the destination that was
  explicitly selected, or the GPS-nearest one), shown in the UI as "Selected Anchor".
- `List<MapDestination> clusterStops` — ordered nearby destinations (empty = no active
  cluster), **not** including the anchor itself.
- `List<LatLng> get clusterPolyline` — `[clusterAnchor.location, ...clusterStops.map((d) => d.location)]` when a cluster is active, else `[]`.
- `List<double> get legDistancesKm` — `legDistanceKm` between each consecutive pair in the
  polyline above (length = `clusterStops.length`).
- `double get totalDistanceKm` — sum of `legDistancesKm`.
- `bool isLoadingCluster`
- `String? clusterMessage` — user-facing text when there's nothing to show (E1) or the load
  failed; `null` when a cluster is successfully showing or no cluster has been requested.
- `Future<void> viewThemedCluster({MapDestination? origin})` (signature revised — `origin` is
  now optional) — if `origin` is given, uses it directly as `clusterAnchor`; if omitted, calls
  `Geolocator.getCurrentPosition()` (same direct-call pattern as Feature 3's distance-from-user
  and `eco_partner_screen.dart`) and resolves the anchor via `nearestDestination`. If location
  can't be determined (permission denied, no GPS fix) and no `origin` was given, sets
  `clusterMessage = "Couldn't determine your location to find a themed trail."` and returns.
  Once an anchor is resolved: calls `nearbyByCategory`, then `orderByNearestNeighbor`; on
  success with results, sets `clusterStops` and clears `clusterMessage`; on success with zero
  results, sets `clusterMessage = 'No themed cluster available nearby.'` (E1); on a thrown
  error, sets `clusterMessage = "Couldn't load a themed cluster right now."`.
- `void clearCluster()` — resets `clusterAnchor`, `clusterStops`, `clusterMessage`,
  `isLoadingCluster` to their empty/false state.

`selectDestination`/`clearSelection` (from Feature 1) are unchanged; closing or changing the
popup does **not** automatically clear an active cluster — only `clearCluster()` (the banner's
close button) or requesting a new cluster for a different origin (A1) does.

## View additions

- `DestinationMapScreen` gains a persistent "View Themed Trail" control (per the revised
  Trigger point decision — a map-corner button rather than a popup button) that calls
  `controller.viewThemedCluster(origin: controller.selectedDestination)` — passing the
  currently-selected destination if the user tapped one first, or omitting it (falling back to
  GPS-nearest) otherwise. The exact drawer/multi-action styling from the prepared UI is an
  implementation-plan detail, not specified further here.
- The map gains a `PolylineLayer`, rendered only when `controller.clusterPolyline` is
  non-empty, styled distinctly from anything resembling a real route (dashed stroke, a color
  not used by any marker category) — satisfying NFR4.
- A card/banner overlays the map whenever a cluster is active or `clusterMessage` is set:
  - Active cluster: the anchor and each `clusterStops` entry, numbered, each showing its
    `legDistancesKm` entry ("Xkm away") and `totalDistanceKm` ("Xkm total"), plus the fixed
    disclaimer text **"Suggested path only — not a navigable route"** (FR2.4, NFR4, wording
    matched to the prepared UI) and a close (✕) button calling `clearCluster()`.
  - `clusterMessage` set (E1, no-location, or load failure): the message text, with the same
    close button (also calling `clearCluster()`).
- Selecting a different destination and requesting its cluster (A1) simply calls
  `viewThemedCluster` again — the controller overwrites `clusterAnchor`/`clusterStops`/
  `clusterMessage`, so the View doesn't need special-case logic for "switching" clusters.

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
- `legDistanceKm`/total distance: known coordinate pairs with a known expected distance
  (`closeTo` assertion, same pattern as the existing `EcoPartnerRepository.distanceKm` test).
- Controller: `viewThemedCluster` with an explicit `origin` (populates `clusterAnchor`/
  `clusterStops`, clears `clusterMessage`); with no `origin` and a fake repository/location
  source, resolving the anchor via `nearestDestination`; zero-results (sets the "no cluster
  available" message); a failed/denied location lookup with no `origin` (sets the "couldn't
  determine your location" message); repository failure (sets the "couldn't load" message);
  and `clearCluster` resetting all fields including `clusterAnchor`.

Visual verification (polyline styling, banner, popup button) via a manual browser/emulator
run once wired up, per Feature 1's same approach — no `flutter_map` widget tests.

## Out of scope (this spec)

- Persisting cluster state across page refresh (NFR10 — explicitly optional/gap per spec).
- Features 3–4 (comparison, crowd-sourced ratings) — separate specs.
- Real routing/navigable directions for the polyline — it's a straight-line approximation
  only, by design (constraint carried over from the use case).
