# Contributing to Collab

Quick reference for the team on how to set up, branch, and merge work.

## 1. Setup

```
git clone <repo-url>
cd collab
flutter pub get
```

This project uses code generation (Freezed, Drift), so also run:

```
dart run build_runner watch -d
```

Keep that running while you work — it regenerates `*.g.dart` / `*.freezed.dart` files whenever you change a model or Drift table. If you just need a one-time build instead of watch mode:

```
dart run build_runner build -d
```

Open the project in Android Studio (or your IDE of choice) and run on an emulator/device as normal.

## 2. Architecture: MVC

The project follows a plain Model-View-Controller pattern (no Riverpod/provider framework). Each feature module under `lib/features/<module>/` has three folders:

| Folder | Contains |
|---|---|
| `model/` | Data models/entities, repositories, datasources — anything that owns or fetches data |
| `view/` | Screens and widgets — UI only, no business logic |
| `controller/` | Plain Dart classes (e.g. `ChangeNotifier`) that hold state, contain business logic, and mediate between `model/` and `view/`. Views listen to controllers directly. |

`lib/core/` holds cross-cutting infrastructure (database, network, router, theme, constants, errors, utils, shared widgets) and isn't part of the MVC triad.

## 3. Module ownership

Stick to your assigned module unless a change is agreed with the owner:

| Folder | Module |
|---|---|
| `features/hidden_gem_recommendation/` | Module 1 – Hidden Gem Recommendations |
| `features/destination_exploration/` | Module 2 – Destination Exploration |
| `features/itinerary_planning/` | Module 3 – Smart Itinerary Planning |
| `features/culture_community/` | Module 4 – Local Culture & Community |
| `features/travel_assistant/` | Module 5 – Smart Travel Assistant |
| `features/gamification_journal/` | Module 6 – Gamification & Travel Journal |
| `features/auth/`, `core/`, `shared/`, `common_controllers/` | Shared foundation — changes here affect everyone, discuss before editing |

If your module needs a shared model (e.g. `Destination`, `UserProfile`, `Itinerary`) or a shared controller (current user, preferences, location), put it in `lib/shared/models/` or `lib/common_controllers/` and flag it to the team so no one duplicates it.

## 4. Branching

- `main` is always kept working/demoable. Never commit to it directly.
- Branch per feature or task off `main`:
  ```
  git checkout -b feature/<module-name>-<short-description>
  # e.g. feature/hidden-gem-scoring-engine
  ```
- Fixes: `fix/<short-description>`

## 5. Commits

Keep commits small and scoped to one change. Suggested prefix style:

```
feat(hidden_gem_recommendation): add preference scoring controller
fix(itinerary_planning): correct route sequencing edge case
chore(core): update drift schema for checklist table
```

## 6. Pull requests

1. Push your branch and open a PR into `main`.
2. Write a short description of what changed and which module it touches.
3. At least one teammate reviews before merging — mainly checking it doesn't break shared code (`core/`, `shared/`, `common_controllers/`).
4. Prefer squash merge to keep `main` history clean.
5. Run `flutter analyze` and `flutter test` before opening the PR — fix warnings/failures first.

## 7. Before you start a task

- Pull latest `main` and rebase your branch if it's been open a while.
- If your feature depends on a shared model/controller that doesn't exist yet, build against a temporary fake/mock in your own `model/` layer rather than blocking — swap it out once the real one lands.
- If you're touching `core/database/` (Drift schema) or `common_controllers/`, message the team first since it affects multiple modules.

## 8. Code style

- Business logic (scoring formulas, route ordering, etc.) belongs in `controller/`, kept as plain, testable Dart with minimal Flutter imports (a `ChangeNotifier`/`Listenable` is fine; no widget code).
- Views (`view/`) should only read state from and call methods on their controller — no business logic in widgets.
- Run `flutter pub run build_runner build -d` after adding/editing any `@freezed` class or Drift table before committing — generated files should be committed too (check `.gitignore` isn't excluding them if the team has agreed to commit generated code, otherwise regenerate on clone).
