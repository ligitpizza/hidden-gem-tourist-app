# Destination Exploration — Feature 4: Crowd-Sourced Difficulty & Accessibility Ratings

Status: Approved
Date: 2026-08-06

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
  rating form" without one). It is explicitly **not** the full gamification/journal system
  (no points, streaks, or badges) — that remains `gamification_journal`'s job later.
- **Badge display location**: FR4.5's "destination page" doesn't exist yet — only Feature 1's
  compact map popup. Badges are designed as a contract for that popup sheet to consume later
  (documented below), not built as part of this spec.
- **View scope**: Model + Controller only, matching Feature 3's choice. No check-in button,
  rating form, or badge UI is built now.
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
    rating_summary.dart                 # new
    keyword_tagging_engine.dart         # new
    difficulty_bucket.dart              # new enum
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
```

## Model

- `DifficultyBucket` — enum `easy, moderate, hard`.
- `RatingSummary` — `{DifficultyBucket difficultyBucket, double avgDifficulty, int ratingCount, List<String> topTags}`.
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
    frequency across all rows to pick the top 5 (ties broken by tag insertion/discovery order)
    as `topTags` (FR4.4, FR4.5).

## Controller

`RatingController extends ChangeNotifier`:
- `bool isCheckedIn`, `bool isSubmitting`, `String? error` (distinguishes a
  "verified check-in required" message from a submission failure).
- `Future<void> checkIn(String destinationId)` — sets `isCheckedIn = true` on success.
- `Future<void> submitRating({required String destinationId, required int difficultyScore, required String reviewText})`
  — if `!isCheckedIn`, sets `error = 'A verified check-in is required to submit a rating.'`
  and returns immediately (E2) without calling the repository; otherwise submits and refreshes
  the destination's `RatingSummary`.
- Skipping the rating prompt (A1) needs no controller method — if `submitRating` is simply
  never called, no rating record is created.

## Badge display contract (documented, not built)

When Feature 1's `DestinationPopupSheet` is later extended to show ratings, it should call
`DestinationRatingRepository.fetchRatingSummary` and render the difficulty bucket plus up to 5
tag chips, with a persistent **"Community-reported, unverified"** disclaimer next to them
(NFR6 — these tags are never presented as verified/authoritative). Not implemented in this
spec.

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
- Rating aggregation (top-5 tag frequency counting, including a tie).
- `RatingController.submitRating`: blocked with the check-in error when `isCheckedIn` is
  false; succeeds and refreshes the summary when true.
- `RatingController.checkIn`: flips `isCheckedIn` to true.

## Out of scope (this spec)

- Moderation/flagging tooling (NFR13 — explicit future gap).
- The check-in button, rating form, and badge UI themselves.
- Negation-aware or NLP-based tagging (NFR9 explicitly defers this to a later upgrade).
- The full `gamification_journal` check-in experience (points, streaks, badges) — this
  spec's check-in gate is a minimal, separate mechanism.
- Persisting rating-form draft state across refresh — not mentioned in the source
  requirements for this feature.
