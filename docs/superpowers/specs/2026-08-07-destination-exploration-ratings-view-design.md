# Destination Exploration — Feature 4 View: Ratings & Accessibility UI

Status: Approved
Date: 2026-08-07

## Context

Feature 4 (Crowd-Sourced Difficulty & Accessibility Ratings) was built Model + Controller only
(see `2026-08-06-destination-exploration-ratings-design.md`) — `RatingController`,
`DestinationRatingRepository`, `CheckInRepository`, `UserProgressRepository`,
`KeywordTaggingEngine`, `DifficultyBucket`/`RatingSummary` all exist and are tested, but no
screen was ever built. The user could not find the feature anywhere in the app because there
was nothing to find — no check-in-gated rating form, no reviews list, no points/badge display.

This spec covers building that missing View layer and wiring it into the app, based on three
reference screenshots the user supplied (submit-rating screen, review-published screen,
destination detail community-reviews section).

## Decisions made during brainstorming

- **Entry point**: merge into the *existing* double-tap destination detail screen
  (`gamification_journal`'s `DestinationDetailScreen`, reached from the interactive map) as a
  new "Ratings & Accessibility" section, rather than building a separate
  `destination_exploration` detail page or replacing double-tap's target. Chosen over keeping
  Feature 4 fully separate.
- **Check-in gate**: rating submission is gated by the *existing* check-in already on that
  screen (`CheckInController.history`), not Feature 4's own standalone `destination_checkins`
  table. One check-in system, one Check-In button, visible on one screen. This means
  `RatingController` no longer needs `CheckInRepository`, `checkIn()`, or its own `isCheckedIn`
  tracking — `submitRating` takes `isCheckedIn` as a parameter instead, sourced from
  `CheckInController`. `check_in_repository.dart` is deleted as now-dead code; the
  `destination_checkins` table it used stays in the already-written migration file (harmless if
  unused) but nothing references it from Dart anymore.
- **Rating form presentation**: two dedicated full screens (Submit Rating → Review Published),
  not a modal bottom sheet — matches the two-screen flow in the reference screenshots and gives
  the badge/points unlock its own moment.
- **Live tag preview**: `KeywordTaggingEngine.tagsFor(reviewText)` is pure and instant, so the
  submit screen recomputes and displays tag chips live as the user types, matching the
  screenshot. This is a narrow reversal of the original spec's "no live tag preview" decision —
  the manual "+ Add Tag" affordance next to it stays visually present but inert (not wired to
  real behavior), per the original spec's unchanged decision on that point.
- **Tag chip color-coding**: the fixed 10-entry keyword→tag map splits into two fixed sets —
  accessibility-positive (`wheelchair-friendly`, `stroller-friendly`, `parking available`,
  `family-friendly`, `shaded`) shown in one chip style, and caution tags (`steep terrain`,
  `many stairs`, `crowded`, `slippery when wet`) in another — computed from a static
  classifier, no new backend field.
- **Reviewer identity**: the schema has no display-name/avatar/profile table and no per-review
  star rating (only `difficulty_score` 1–5). Review cards show a generic "Community Member" +
  relative time instead of fabricating identity/rating data the app doesn't have.
- **"Read All N Reviews"**: expands the same paginated list in place (via `fetchReviews`'s
  existing `limit`/`offset`), not a fourth screen.
- **Region**: `submitRating`'s `region` parameter (keys the once-per-region Pathfinder badge)
  uses `DestinationModel.state`, already on screen (currently a constant `'Penang'` from the
  prior session's `DestinationModel.fromMapDestination` conversion) — no new field.
- **Operational note**: the `202608060003_destination_ratings.sql` migration
  (`destination_ratings`, `user_trail_points`, `user_badges`) may not yet be applied to the
  live Supabase project — Feature 4 was never exercised end-to-end. Submission will fail
  gracefully (generic error, no crash) until it's confirmed applied.

## Architecture

```
lib/features/destination_exploration/
  controller/
    rating_controller.dart               # REWRITE — drop check-in tracking, add
                                          # loadSummary/loadReviews, submitRating gains
                                          # isCheckedIn param
  model/
    check_in_repository.dart             # DELETE — unused after the check-in-gate decision
    rating_tag_style.dart                # NEW — pure tag -> {positive, caution} classifier
  view/
    widgets/
      ratings_section.dart               # NEW — embedded section for DestinationDetailScreen
      submit_rating_screen.dart          # NEW — full-screen rating form
      review_published_screen.dart       # NEW — confirmation screen
lib/features/gamification_journal/
  view/checkin/destination_detail_screen.dart   # EDIT — embed RatingsSection
test/
  rating_controller_test.dart            # REWRITE to match new controller shape
  rating_tag_style_test.dart             # NEW
```

## Controller (revised)

`RatingController extends ChangeNotifier`:
- Constructor drops `checkInRepository`; keeps `ratingRepository`/`progressRepository`
  (both optional, defaulting to real implementations, same DI pattern as before).
- State: `isLoadingSummary`, `isLoadingReviews`, `isSubmitting`, `error`, `pointsAwarded`,
  `pathfinderBadgeUnlocked`, `summary` (`RatingSummary?`), `reviews` (`List<DestinationReview>`),
  `hasMoreReviews` (`bool`).
- `Future<void> loadSummary(String destinationId)` — calls `fetchRatingSummary`, sets `summary`.
- `Future<void> loadReviews(String destinationId, {bool loadMore = false})` — calls
  `fetchReviews` with an offset derived from `reviews.length` when `loadMore` is true (else
  offset 0, replacing `reviews`); sets `hasMoreReviews = result.length == limit`.
- `Future<void> submitRating({required String destinationId, required String region, required int difficultyScore, required String reviewText, required bool isCheckedIn})`
  — if `!isCheckedIn`, sets the same E2 error as before and returns without calling any
  repository. Otherwise: submit → refresh `summary` → refresh `reviews` (`loadMore: false`) →
  award points/badge (unchanged degrade-gracefully behavior). Reentrancy guard unchanged.

## Views

### `RatingsSection` (embedded widget)

Constructor: `{required String destinationId, required String region, required bool isCheckedIn}`.
Owns its own `RatingController` (via `package:provider`'s `ChangeNotifierProvider`, same
screen-scoped pattern as `ComparisonController`), calling `loadSummary` + `loadReviews` on
init.

Layout, top to bottom:
1. Top-tag badge chips (`summary.topTags`, no percentages) using the tag color classifier, with
   the "Community-reported, unverified" disclaimer beneath (short form — the long disclaimer
   text lives on the submit screen).
2. "Community Reviews" header, "Based on N reviews" subtext (`summary.ratingCount`), and a
   "Write a Review" link — enabled only when `isCheckedIn`, otherwise shown de-emphasized with
   a "Check in above to write a review" hint. Pushes `SubmitRatingScreen` with the *same*
   controller instance (via `ChangeNotifierProvider.value` in the pushed route) so a
   successful submission's refreshed `summary`/`reviews` are already in place when the user
   returns.
3. Up to 3 review cards (generic "Community Member" + relative time, difficulty bucket chip,
   review text, generated tag chips) from `reviews`.
4. "Read All N Reviews" button — calls `loadReviews(loadMore: true)`, appending to the same
   list; hidden once `hasMoreReviews` is false.

Empty state (no ratings yet): a short "Be the first to review this destination" message instead
of the reviews list, no top-tag chips.

### `SubmitRatingScreen`

Constructor: `{required String destinationId, required String destinationName, required String destinationImageUrl, required String region, required bool isCheckedIn, required RatingController controller}`.

- "Check-In Complete" badge + destination name + photo (reuses data already on hand, no fetch).
- Difficulty card: `Slider` bound to a local `int` (1–5, default 3), Easy/Moderate/Hard labels
  under it, a pill showing the bucket label for the current value (via `difficultyBucketFor`
  applied to the raw int, treated as a single-sample average for display purposes only — the
  real bucket is always server-aggregated).
- "Your Experience" `TextField` (multiline, `maxLength: 500`).
- "Auto-generated Tags": `KeywordTaggingEngine.tagsFor(controller.text)` recomputed on every
  change, rendered as color-coded chips, plus a static inert "+ Add Tag" chip.
- Disclaimer container with the screenshot's exact copy.
- "Submit Contribution" button — disabled while `controller.isSubmitting`; calls
  `ratingController.submitRating(..., isCheckedIn: isCheckedIn)`. On success
  (`error == null`), `Navigator.pushReplacement` to `ReviewPublishedScreen` (passing the same
  controller + submitted review text + tags for the echo card). On error, SnackBar with
  `controller.error`, form stays populated.

### `ReviewPublishedScreen`

Constructor: `{required String destinationName, required String reviewText, required List<String> tags, required RatingController controller}`.

- Checkmark + "Thank you for your contribution" + destination name.
- Echo card: "Community Member · Just now", quoted `reviewText`, the same tag chips.
- "Community Consensus": difficulty bar from `controller.summary!.difficultyBucket`/
  `avgDifficulty`, top tags with percentages from `controller.summary!.topTags`.
- Points/badge box: "+15 Trail Points" (from `RatingController.pointsPerContribution`,
  always shown since submission already succeeded); "unlocked the Pathfinder badge" line only
  when `controller.pathfinderBadgeUnlocked`.
- "Return to Map" — `Navigator.pop` back to `DestinationDetailScreen` (single pop, since this
  screen replaced the submit screen rather than stacking on top of it).

## Tag color classifier

`rating_tag_style.dart` — pure, no I/O:

```dart
enum RatingTagTone { positive, caution }

const _cautionTags = {'steep terrain', 'many stairs', 'crowded', 'slippery when wet'};

RatingTagTone toneFor(String tag) =>
    _cautionTags.contains(tag) ? RatingTagTone.caution : RatingTagTone.positive;
```

## Error handling

Unchanged from the backend spec: E2 (no check-in) blocks before any repository call; a
submission failure surfaces a retryable error and leaves the form populated; a points/badge
award failure degrades silently (rating stays committed, `pointsAwarded` stays null). No new
error cases introduced by the View.

## Testing

- `rating_controller_test.dart` rewritten for the new shape: `submitRating` blocked when
  `isCheckedIn: false` is passed (no repository call); succeeds and refreshes
  `summary`/`reviews` when `true`; points/badge award success, failure-degrades-gracefully, and
  already-unlocked-badge cases (same coverage as before, adapted to the new signature);
  `loadSummary`/`loadReviews` populate state from a fake repository, including the
  `loadMore`/offset/`hasMoreReviews` behavior.
- `rating_tag_style_test.dart`: each of the 4 caution tags classifies as `caution`, each of the
  other 6 as `positive`.
- No widget tests — consistent with how Features 1–3's views were verified (`flutter analyze` +
  manual smoke test), no widget test suite exists elsewhere in this module.

## Out of scope

- Wiring "+ Add Tag" to real tag editing (still declined, per the original spec).
- Real reviewer identity/avatars/per-review star ratings (no profile system exists).
- A dedicated "all reviews" screen (handled as in-place pagination instead).
- Moderation/flagging tooling (NFR13 — unchanged, still a known future gap).
- Confirming/applying the `202608060003_destination_ratings.sql` migration — flagged as a
  manual follow-up, not part of this implementation.
