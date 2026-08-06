# Destination Exploration — Feature 4: Crowd-Sourced Difficulty & Accessibility Ratings

Status: Approved
Date: 2026-08-06
Revised: 2026-08-06 — after reviewing the prepared UI: badges now display on a real
Destination Detail page (not Feature 1's popup), and a minimal points/badge-unlock system is
added on rating submission (see Decisions, Data, Repository, Controller).

## Context

Fourth and last of the four Destination Exploration module features, built one at a time.
This spec covers **Feature 4 only** (FR4.1–FR4.6, NFR6, NFR7, NFR9, NFR13) and the "Submit
Difficulty & Accessibility Rating" use case. It builds on Feature 1's `destinations` table
(see `2026-08-06-destination-exploration-map-design.md`). None of Features 1–4 are
implemented yet (specs/plans only).

Source requirements: FR4.1–FR4.6, NFR6, NFR7, NFR9, NFR13, and the "Submit Difficulty &
Accessibility Rating" use case (basic flow, A1, E1/E2/E3), as supplied by the user on
2026-08-06.

## Decisions made during brainstorming

- **Check-in gap**: the use case's precondition ("a verified check-in") has no existing
  implementation anywhere in the codebase — `gamification_journal` (the likely eventual home
  for a full check-in/journal experience) is still an empty scaffold. This spec builds a
  **minimal, standalone check-in gate** scoped to this module only (a join table recording
  that a user visited a destination) — just enough to satisfy E2 ("blocks access to the
  rating form" without one).
- **Badge display location (revised)**: the prepared UI shows a full **Destination Detail
  page** (photo, description, badge chips, a paginated community reviews list, a "Write a
  Review" entry point) — not Feature 1's compact popup. The user confirmed this page's design
  already exists (it's what was pasted). This spec adds the repository support a detail page
  needs (rating summary **and** individual paginated reviews — see Repository), documented as
  a contract for that page, without building the page itself (View scope, unchanged, is still
  Model + Controller only).
- **Points/badges (revised, in scope now)**: the prepared UI shows real points ("+15 Trail
  Points") and a badge unlock ("Pathfinder") immediately after a rating is submitted. The user
  asked for a **minimal** points/badge system now, scoped tightly to this one flow — a running
  points total and a single "Pathfinder" badge type, unlocked once per region on a user's
  first rating contribution there. This is **not** the full `gamification_journal` system
  (no streaks, no badge catalog beyond Pathfinder, no separate points economy elsewhere in the
  app) — see Points & badges below.
- **Tag editing**: considered live tag preview + a manual "+ Add Tag" option (seen in the
  prepared UI) but declined — tags stay auto-generated only, computed once at submission time,
  matching the original design. The UI's manual-add affordance is not wired to real behavior
  when this is built.
- **View scope**: Model + Controller only, matching Feature 3's choice. No check-in button,
  rating form, badge UI, or detail page is built now.
- **Keyword tagging**: a small, fixed, deterministic keyword→tag map (NFR9 — "deterministic
  and auditable... upgrade path to NLP-based classification" later, not now), following the
  same pure/static classification style already used by `OverpassEcoSource.classifyDiet` in
  `lib/features/travel_prep/model/eco_partner_repository.dart`.
- **Small-sample skew (NFR7) and moderation (NFR13)**: both explicitly out of scope — the
  spec itself marks these as identified, currently-unmitigated risks, not requirements to
  solve here.

## Architecture

```
lib/features/destination_exploration/
  model/
    check_in_repository.dart            # new
    destination_rating_repository.dart  # new
    rating_summary.dart                 # new (+ TagFrequency)
    keyword_tagging_engine.dart         # new
    difficulty_bucket.dart              # new enum
    user_progress_repository.dart       # new — points + badge awarding
  controller/
    rating_controller.dart              # new
```

## Data

New migration:

```sql
create table public.destination_checkins (
  user_id uuid not null references auth.users(id),
  destination_id uuid not null references public.destinations(id),
  checked_in_at timestamptz not null default now(),
  primary key (user_id, destination_id)
);

alter table public.destination_checkins enable row level security;

create policy "Users manage their own check-ins" on public.destination_checkins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.destination_ratings (
  id uuid primary key default gen_random_uuid(),
  destination_id uuid not null references public.destinations(id),
  user_id uuid not null references auth.users(id),
  difficulty_score int not null check (difficulty_score between 1 and 5),
  review_text text not null default '',
  generated_tags text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.destination_ratings enable row level security;

create policy "Public read access" on public.destination_ratings
  for select using (true);

create policy "Users insert their own ratings" on public.destination_ratings
  for insert with check (auth.uid() = user_id);

create table public.user_trail_points (
  user_id uuid primary key references auth.users(id),
  total_points integer not null default 0
);

alter table public.user_trail_points enable row level security;

create policy "Users manage their own points" on public.user_trail_points
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.user_badges (
  user_id uuid not null references auth.users(id),
  badge_id text not null,
  region text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, badge_id, region)
);

alter table public.user_badges enable row level security;

create policy "Users manage their own badges" on public.user_badges
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

`region` is `destinations.city` (the column Feature 3 adds) — no new region/geography concept
introduced. `badge_id` is a plain text identifier; only one value, `'pathfinder'`, is defined
by this spec.

## Model

- `DifficultyBucket` — enum `easy, moderate, hard`.
- `TagFrequency` — `{String tag, double percentage}` (0–100, share of a destination's ratings
  that generated this tag) — matches the prepared UI's "Shaded Trail 84%" style display
  (FR4.5, revised from a plain tag list).
- `RatingSummary` — `{DifficultyBucket difficultyBucket, double avgDifficulty, int ratingCount, List<TagFrequency> topTags}`.
- `DestinationReview` (new, also in `rating_summary.dart`) — `{String reviewText, int difficultyScore, List<String> generatedTags, DateTime createdAt}`, one row of `destination_ratings`, for the Destination Detail page's review list.
- `KeywordTaggingEngine` (pure/static, mirroring `OverpassEcoSource.classifyDiet`'s style):
  `static List<String> tagsFor(String reviewText)` — case-insensitive substring match against
  a fixed keyword→tag map:

  | keyword contains | tag |
  |---|---|
  | `wheelchair` | wheelchair-friendly |
  | `stroller` | stroller-friendly |
  | `steep` | steep terrain |
  | `stairs` | many stairs |
  | `parking` | parking available |
  | `crowded` | crowded |
  | `family` or `kids` | family-friendly |
  | `shade` | shaded |
  | `slippery` | slippery when wet |

  Multiple keyword matches in one review produce multiple tags (deduplicated). No match →
  `[]`. Negated phrasing (e.g. "not wheelchair friendly" still producing "wheelchair-friendly")
  is an accepted limitation of a deterministic keyword pipeline (E1) — not handled specially.
- Difficulty bucketing (pure function): `avgDifficulty <= 2.0` → `easy`, `<= 3.5` →
  `moderate`, else `hard` (FR4.4).

## Repository

- `CheckInRepository`:
  - `Future<bool> isCheckedIn(String destinationId)` — scoped to
    `Supabase.instance.client.auth.currentUser` (throws `AuthException` if signed out, same
    pattern as `emergency_contact_repository.dart`).
  - `Future<void> checkIn(String destinationId)` — upserts into `destination_checkins`
    (idempotent — checking in twice is a no-op, not an error).
- `DestinationRatingRepository`:
  - `Future<void> submitRating({required String destinationId, required int difficultyScore, required String reviewText})`
    — computes `generated_tags` via `KeywordTaggingEngine.tagsFor(reviewText)` and inserts the
    row (FR4.2, FR4.3).
  - `Future<RatingSummary> fetchRatingSummary(String destinationId)` — fetches all ratings for
    a destination, averages `difficulty_score` into a bucket, and counts `generated_tags`
    frequency across all rows to compute each tag's `percentage` (occurrences ÷ `ratingCount`
    × 100), keeping the top 5 (ties broken by tag insertion/discovery order) as `topTags`
    (FR4.4, FR4.5).
  - `Future<List<DestinationReview>> fetchReviews(String destinationId, {int limit = 20, int offset = 0})`
    (new — for the Destination Detail page's paginated review list) — returns raw rows
    (reviewer display handled by whatever the eventual View joins in; this method returns
    `{reviewText, difficultyScore, generatedTags, createdAt}` per row), newest first.
- `UserProgressRepository` (new):
  - `Future<int> awardPoints(int amount)` — upserts `user_trail_points`, incrementing
    `total_points` by `amount`, returns the new total.
  - `Future<bool> awardPathfinderBadgeIfNew(String region)` — inserts
    `(user_id, 'pathfinder', region)` into `user_badges` if it doesn't already exist; returns
    `true` if this call newly unlocked it, `false` if the user already had it for that region.

## Controller

`RatingController extends ChangeNotifier`:
- `bool isCheckedIn`, `bool isSubmitting`, `String? error` (distinguishes a
  "verified check-in required" message from a submission failure).
- `int? pointsAwarded`, `bool pathfinderBadgeUnlocked` — set after a successful submission, so
  the View can show "+15 Trail Points... unlocked the Pathfinder badge" (only when `true` —
  most submissions after the user's first in a region won't unlock it again).
- `Future<void> checkIn(String destinationId)` — sets `isCheckedIn = true` on success.
- `Future<void> submitRating({required String destinationId, required String region, required int difficultyScore, required String reviewText})`
  (signature gains `region`, needed for the badge check) — if `!isCheckedIn`, sets
  `error = 'A verified check-in is required to submit a rating.'` and returns immediately (E2)
  without calling the repository. Otherwise: submits the rating, refreshes the destination's
  `RatingSummary`, then calls `UserProgressRepository.awardPoints(15)` (the flat per-
  contribution amount shown in the prepared UI) and `awardPathfinderBadgeIfNew(region)`,
  setting `pointsAwarded`/`pathfinderBadgeUnlocked` from their results. A failure in the
  points/badge step does **not** roll back the rating submission itself — the rating is the
  primary action; points/badges are a bonus that degrades gracefully (the rating's `error`
  stays `null`, only `pointsAwarded` stays `null` if that step failed).
- Skipping the rating prompt (A1) needs no controller method — if `submitRating` is simply
  never called, no rating record is created.

## Destination Detail page contract (documented, not built)

When the Destination Detail page (already designed — see the revised Badge display location
decision) is built, it should call `fetchRatingSummary` for the difficulty bucket + up to 5
tag badges (with a persistent **"Community-reported, unverified"** disclaimer next to them,
NFR6) and `fetchReviews` (paginated) for the individual community reviews list, with a "Write
a Review" entry point that opens the rating form (gated the same way — via
`RatingController.isCheckedIn`). Not implemented in this spec.

## Error handling

- E1 (ambiguous/negated review text): accepted limitation of the deterministic keyword
  pipeline, not handled — documented above.
- E2 (no verified check-in): `RatingController.submitRating` blocks and sets `error` before
  any repository call.
- E3 (low-quality/joke submissions persist): explicitly out of scope — NFR13 already flags
  the lack of moderation tooling as a known future gap, not something this spec solves.

## Testing

Pure-logic unit tests (no network, no widget pump):
- `KeywordTaggingEngine.tagsFor`: each keyword individually, multiple matches in one review
  (deduplicated), case-insensitivity, no match → `[]`.
- Difficulty bucketing: boundary values (2.0, 2.01, 3.5, 3.51).
- Rating aggregation (top-5 tag frequency counting including percentages, including a tie).
- `RatingController.submitRating`: blocked with the check-in error when `isCheckedIn` is
  false; succeeds and refreshes the summary when true; sets `pointsAwarded`/
  `pathfinderBadgeUnlocked` from a fake `UserProgressRepository`'s results (including the
  "already unlocked, second contribution in the same region" → `pathfinderBadgeUnlocked = false` case).
- `RatingController.checkIn`: flips `isCheckedIn` to true.

## Out of scope (this spec)

- Moderation/flagging tooling (NFR13 — explicit future gap).
- The check-in button, rating form, badge UI, and Destination Detail page themselves.
- Negation-aware or NLP-based tagging (NFR9 explicitly defers this to a later upgrade).
- Live tag preview and manual tag addition — declined, see Decisions.
- The broader `gamification_journal` experience — streaks, a badge catalog beyond
  `'pathfinder'`, or any points economy outside this one submit-rating flow. This spec's
  points/badge hook is deliberately narrow (one action, one badge type).
- Persisting rating-form draft state across refresh — not mentioned in the source
  requirements for this feature.
