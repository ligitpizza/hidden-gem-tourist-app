# Destination Exploration — Feature 1: Interactive Destination Map

Status: Approved
Date: 2026-08-06

## Context

The "Destination exploration module" use-case diagram covers four features: Interactive
Destination Map, Themed Destination Clusters, Attraction Comparison, and Crowd-Sourced
Difficulty & Accessibility Ratings. These are being designed and built one at a time. This
spec covers **Feature 1 only** (Interactive Destination Map, FR1.1–FR1.5, NFR1, NFR3, NFR11).

Source requirements: FR1.1–FR1.5, NFR1, NFR3, NFR11, and the "View Interactive Destination
Map" use case (basic flow, A1/A2, E1/E2), as supplied by the user on 2026-08-06.

## Decisions made during brainstorming

- **Scope**: build one feature at a time. This spec is Feature 1. Features 2–4 are separate,
  later specs.
- **Code location**: `lib/features/destination_exploration/{model,controller,view}` (already
  scaffolded, empty). `lib/features/map/view/map_screen.dart` is a separate, older placeholder
  for the same screen — left untouched and unused; not deleted.
- **Pattern**: MVC, matching the existing convention (e.g. `itinerary_planning`): Controllers
  are plain `ChangeNotifier`s exposed via a Riverpod `ChangeNotifierProvider`; Models are data
  classes plus a Repository that talks to Supabase.
- **Data source**: reuse the existing `place_hidden_gem_candidates` Supabase table (already
  has name, category, lat/lng, avg_rating, uniqueness/accessibility scores, popularity,
  description) rather than creating a new `destinations` table. Avoids duplicate data and
  keeps Hidden Gem scoring consistent across the app.
- **Category scheme**: reuse the existing 5-bucket `HiddenGemCategory` enum (food, culture,
  nature, viewpoint, craft) and `HiddenGemScoring.categoryFromDb` mapping — already used by
  scoring, the Assistant feed, and itinerary planning — instead of introducing a second,
  spec-literal 4-category (nature/food/culture/heritage) scheme that could drift out of sync.
- **View**: build a working View now (not just Model/Controller), so the feature is testable
  end-to-end. The user will separately paste prepared UI for this and the other 3 features;
  when that arrives it replaces these view files. The Controller's public API is the contract
  the pasted UI needs to bind to.
- **Router wiring**: swap the bottom-nav "Map" tab's route in `core/router/app_router.dart`
  from `MapScreen()` to the new `DestinationMapScreen()`. This is the one existing file this
  work touches, and it's a one-line builder swap (import + route target), not a rewrite.

## Architecture

New files only, under `lib/features/destination_exploration/`:

```
model/
  map_destination.dart                      # data class for map markers/popups
  destination_exploration_repository.dart   # Supabase query + row mapping
controller/
  destination_map_controller.dart           # ChangeNotifier + Riverpod provider
view/
  destination_map_screen.dart               # flutter_map + clustering + filters
  widgets/
    destination_popup_sheet.dart            # marker-tap detail popup
    category_filter_bar.dart                # filter chip row
```

Plus: `core/router/app_router.dart` — `ShellRoutes.map` route builder points at
`DestinationMapScreen()` instead of `MapScreen()`.

New dependency: `flutter_map_marker_cluster: ^1.4.0` (compatible with the pinned
`flutter_map: ^7.0.2`; later majors of the cluster package require `flutter_map ^8.x`, which
this project isn't on).

## Model

`MapDestination` — a new, standalone class, **not** a reuse of the shared lean `Destination`
model (`lib/shared/models/destination.dart`) used by itinerary planning. Keeping it separate
avoids touching that shared file (used elsewhere with different required fields) and avoids
coupling the two features' data shapes.

Fields: `id, name, description, category (HiddenGemCategory), location (LatLng), avgRating,
imageUrls (List<String>)`.

`DestinationExplorationRepository.loadDestinations()`:
- Queries `place_hidden_gem_candidates`, all rows (this screen shows the whole map, not a
  radius-bounded subset).
- Maps each row's raw `category` string through `HiddenGemScoring.categoryFromDb` for
  consistent coloring/filtering with the rest of the app.
- `images` column missing/null/empty → `imageUrls = []` (popup shows a placeholder — see
  Error Handling / E2).
- Query throwing (network, Supabase unreachable) → returns `[]`; the controller surfaces this
  as a load error (see E1), following the same defensive try/catch pattern used by
  `ItineraryRepository` and `AssistantFeedRepository`.
- The row→`MapDestination` mapping is a separate, pure function so it can be unit tested
  without a network call.

## Controller

`DestinationMapController extends ChangeNotifier`, exposed via
`destinationMapControllerProvider` (`ChangeNotifierProvider`).

State:
- `destinations: List<MapDestination>` — all loaded destinations.
- `isLoading: bool`
- `hasError: bool`
- `selectedCategories: Set<HiddenGemCategory>` — empty set means "show all" (A1).
- `filteredDestinations` (getter) — `destinations` filtered by `selectedCategories` when
  non-empty, else all.
- `selectedDestination: MapDestination?` — drives the open popup sheet.

Methods:
- `loadDestinations()` — called on construction; sets `isLoading`/`hasError` around the
  repository call.
- `retry()` — re-runs `loadDestinations()`.
- `toggleCategory(HiddenGemCategory)` — adds/removes from `selectedCategories`.
- `clearFilters()` — empties `selectedCategories`.
- `selectDestination(String id)` / `clearSelection()`.

## View

`DestinationMapScreen`:
- `flutter_map` with OpenStreetMap tiles (NFR11 — no billed tile provider).
- Markers built from `filteredDestinations`, colored by `HiddenGemCategory`, wrapped in
  `flutter_map_marker_cluster`'s cluster layer. Clustering is proximity-based (markers close
  together on screen cluster), which is what actually produces an uncluttered map at higher
  destination counts (FR1.4/NFR1) — not a manual "count > 30" toggle.
- Tapping a marker calls `selectDestination`; a `showModalBottomSheet` (via
  `destination_popup_sheet.dart`) renders name, description, and images (or a placeholder
  icon if `imageUrls` is empty) — flutter_map has no built-in popup widget, so a bottom sheet
  is the standard pattern here (FR1.2, E2). Kept compact per NFR3.
- `category_filter_bar.dart`: a horizontal row of `FilterChip`s, one per `HiddenGemCategory`,
  bound to `toggleCategory`/`selectedCategories` (FR1.3, A1).
- Re-zooming/panning re-clusters dynamically — handled by the cluster layer itself (A2), no
  extra code needed.

## Error handling

- Load failure (E1): empty map + an inline error banner with a retry action bound to
  `controller.retry()`.
- Missing images (E2): placeholder icon in the popup sheet instead of an image carousel.

## Testing

Pure-logic unit tests (no network, no widget pump):
- Repository's row → `MapDestination` mapping function (including the missing-images and
  unknown-category-string cases).
- Controller: `toggleCategory`/`clearFilters` semantics, `filteredDestinations` computation,
  `selectDestination`/`clearSelection`.

The visual/clustering/popup behavior is verified by running the app (browser/emulator) once
wired into the router, per the project's usual UI verification process — not via
`flutter_map` widget tests, which are heavy (require network tiles).

## Out of scope (this spec)

- Features 2–4 (themed clusters, comparison, crowd-sourced ratings) — separate specs.
- The check-in system Feature 4 depends on — doesn't exist in the codebase yet; not needed
  for Feature 1.
- A dedicated `destinations` table — deliberately not created; see Decisions.
- The user's separately-prepared UI for this feature — will replace the `view/` files built
  here once pasted in; the Controller's public API above is the contract it binds to.
