# Destination Exploration — Feature 3: Attraction Comparison

Status: Approved
Date: 2026-08-06

## Context

Third of the four Destination Exploration module features, built one at a time. This spec
covers **Feature 3 only** (Attraction Comparison, FR3.1–FR3.11, and the "Compare Attractions"
use case). It builds on top of Feature 1 (Interactive Destination Map — see
`2026-08-06-destination-exploration-map-design.md`) and reuses Module 3's existing
`ItineraryPlannerController` for one follow-up action. None of Features 1–3 are implemented
yet (specs/plans only).

Source requirements: FR3.1–FR3.11, and the "Compare Attractions" use case (basic flow,
A1/A2/A3, E1/E2/E3), as supplied by the user on 2026-08-06.

## Decisions made during brainstorming

- **Hidden Gem Score source**: extend Feature 1's `destinations` table with the scoring input
  columns (`uniqueness_score`, `accessibility_score`, `popularity`) rather than querying
  `place_hidden_gem_candidates`. Reuses the existing `HiddenGemScoring.score()` **formula**
  (a pure function with no table dependency) against this module's own standalone data,
  instead of reintroducing a cross-feature data dependency.
- **Selection UI**: destinations are selected for comparison via a toggle added to Feature 1's
  `DestinationPopupSheet` (the map marker popup) — no new list-view screen for selection.
- **View scope**: Model + Controller only for this spec. No comparison screen is built now;
  the user will paste a prepared UI for this feature later, binding to the Controller's
  public API described below.
- **Add to Itinerary**: reuses Module 3's existing `ItineraryPlannerController.addDestination()`
  rather than inventing new itinerary-mutation logic. Requires a `city` column on
  `destinations` (not previously needed by Features 1–2) to construct the shared lean
  `Destination` model that method expects.
- **Save to Favourites persistence**: a new in-memory `FavouriteDestinationsStore` singleton,
  deliberately mirroring `SavedItinerariesStore`'s existing "no real persistence layer yet"
  pattern (`lib/features/itinerary_planning/model/saved_itineraries_store.dart`) rather than
  introducing a new backend table for this spec.
- **Share Comparison**: implemented as a text summary shared via `share_plus`, mirroring
  `ItineraryPlannerController.buildShareSummary()`. An image export (per FR3.11's "image or
  link") needs an actual comparison UI to render and is deferred until the View is built.
- **Difficulty/accessibility optional fields**: added to the `destinations` table now (as
  nullable columns, defaulting to "Not available" per FR3.4) but deliberately left unpopulated
  — Feature 4 (Crowd-Sourced Difficulty & Accessibility Ratings) is what fills them in, once
  that spec/feature exists. No dependency on Feature 4 being built first.

## Architecture

```
lib/features/destination_exploration/
  model/
    destination_exploration_repository.dart   # + fetchForComparison(ids)
    comparison_destination.dart               # new model
    favourite_destinations_store.dart         # new in-memory store
    crowd_level.dart                          # new enum (low/medium/high)
  controller/
    destination_map_controller.dart           # + selection-for-comparison state
    comparison_controller.dart                # new controller
```

Plus one new migration extending `destinations` (below), and one integration point into the
existing `lib/features/itinerary_planning/controller/itinerary_planner_controller.dart`
(consumed, not modified).

## Data

New migration, additive to Feature 1's `destinations` table:

```sql
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
```

`popularity` reuses the existing `GemPopularity` enum / `gemPopularityFromDb()`
(`lib/shared/models/hidden_gem.dart`) — same low/medium/high vocabulary already used by
`place_hidden_gem_candidates`. `crowd_level` uses a new local `CrowdLevel` enum (low/medium/
high) — no existing concept for this anywhere in the codebase.

`difficulty_level`/`accessibility_tags` stay `null` from this migration onward; they exist so
Feature 4 has somewhere to write its aggregated results without a further schema change.

## Model

`ComparisonDestination` (new, separate from Feature 1's lean `MapDestination` — comparison
needs many more fields than a map marker/popup does):

```
id, name, city, category (HiddenGemCategory), location (LatLng),
avgRating, uniquenessScore, accessibilityScore, popularity (GemPopularity),
crowdLevel (CrowdLevel), entranceCost (double?), difficultyLevel (String?),
accessibilityTags (List<String>), visitDurationMinutes (int?), operatingHours (String?)
```

`hiddenGemScore` is **not** a stored field — it's computed on demand via
`HiddenGemScoring.score(avgRating: ..., uniqueness: uniquenessScore, accessibility: accessibilityScore, popularity: popularity)`,
so the formula only ever lives in one place.

## Repository

`DestinationExplorationRepository.fetchForComparison(List<String> ids)` — queries
`destinations` filtered by `id in (...)`, maps each row to a `ComparisonDestination`. A
missing optional column value (null) maps straight to the corresponding nullable/empty Dart
field — no extra fallback logic needed, since `ComparisonDestination`'s consumer already
treats `null`/empty as "Not available" (FR3.4).

## Selection (on `DestinationMapController`, extending Feature 1/2)

- `Set<String> selectedForComparison` — max 3; a 4th `toggleComparisonSelection(id)` call is a
  no-op (no error, just ignored — the cap itself is the guard against E1's "more than 3").
- `bool get canCompare` — true when 2 or 3 are selected.
- `DestinationPopupSheet` gets a "Select for Comparison" toggle button reflecting membership in
  `selectedForComparison`.

## `ComparisonController` (new)

- `ComparisonController({DestinationExplorationRepository? repository})`
- `List<ComparisonDestination> destinations`, `bool isLoading`, `String? selectionError`
- `PriorityWeights weights` — `{double rating, double hiddenGem, double cost}`, default
  `(0.5, 0.3, 0.2)`; `setWeights(...)` normalizes by sum so callers don't need to supply
  values that already total 1.0.
- `Future<void> loadComparison(List<String> ids)` — sets `selectionError` and returns early if
  `ids.length` isn't 2 or 3 (E1); otherwise calls `fetchForComparison`.
- `ComparisonDestination? get bestPick` — the destination with the highest composite score
  (see formula below); `null` if `destinations` is empty.
- `Future<void> addBestPickToItinerary(ItineraryPlannerController itineraryController)` —
  builds a `Destination(id, name, city, category: <mapped>, location)` from `bestPick` and
  calls `itineraryController.addDestination(...)`.
- `void saveToFavourites(ComparisonDestination destination)` — works on any compared
  destination, not just the Best Pick (A3); appends to `FavouriteDestinationsStore.instance`.
- `String buildShareSummary()` — text summary of all compared destinations + Best Pick
  callout.
- `Future<void> shareComparison()` — `Share.share(buildShareSummary())`, wrapped in try/catch;
  failure sets `shareError` (E3).

## Best Pick scoring (FR3.5–FR3.8)

For each compared destination:
- `normalizedRating = avgRating / 5.0`
- `hiddenGem = HiddenGemScoring.score(avgRating: avgRating, uniqueness: uniquenessScore, accessibility: accessibilityScore, popularity: popularity)` (already 0–1)
- If **every** compared destination has a non-null `entranceCost`:
  - `inverseCost = (maxCost == minCost) ? 1.0 : (maxCost - cost) / (maxCost - minCost)`
    (computed across the compared set, not an absolute scale)
  - `compositeScore = weights.rating·normalizedRating + weights.hiddenGem·hiddenGem + weights.cost·inverseCost`
- Otherwise (any destination missing cost — FR3.5/A2): `compositeScore` is **forced** to
  `0.6·normalizedRating + 0.4·hiddenGem`, ignoring `weights` entirely (the fallback ratio is
  fixed by the spec, not user-adjustable).
- `bestPick` = the destination with the highest `compositeScore` (ties broken by input order).
- Distance from the user (via `Geolocator.getCurrentPosition()`, same direct-call pattern as
  `eco_partner_screen.dart` — a denied permission just means distance isn't shown, it doesn't
  block comparison) is displayed as reference info only and never enters `compositeScore`
  (FR3.6).

## Error handling

- E1 (wrong selection count): `selectionError` set by `loadComparison`, comparison not loaded.
- E3 (share failure): `shareError` set, `shareComparison()` can be retried.
- A2 (incomplete cost data): handled by the forced fallback formula above, not an error state.

## Testing

Pure-logic unit tests (no network, no widget pump):
- Best Pick scoring: full-cost-data branch (including an all-equal-cost tie), missing-cost
  fallback branch, weight normalization in `setWeights`.
- `DestinationMapController`: `toggleComparisonSelection` cap-at-3 behavior, `canCompare`.
- `ComparisonController.loadComparison`: rejects 0/1/4+ ids with `selectionError`, accepts 2
  and 3.
- `FavouriteDestinationsStore`: add + list.
- `buildShareSummary()`: contains each destination's name and calls out the Best Pick.

## Out of scope (this spec)

- Feature 4 (crowd-sourced ratings) — separate spec; this spec only reserves the
  `difficulty_level`/`accessibility_tags` columns for it.
- The comparison View itself — Model/Controller only, per decision above.
- A real image export for Share Comparison — text summary only for now.
- Persisting comparison state across page refresh (NFR10 — same "currently a gap" status
  noted in Feature 2's spec).
