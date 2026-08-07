# Destination Exploration — Feature 4 View: Ratings & Accessibility UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the missing View layer for Feature 4 (Crowd-Sourced Difficulty & Accessibility
Ratings) — a check-in-gated rating form, a review-published confirmation, and a community
reviews section — and wire it into the app by embedding it in the existing double-tap
destination detail screen.

**Architecture:** `RatingController` is rewritten to drop its own check-in tracking (the merged
screen already has one) and gains summary/review-loading methods it never had. Three new
widgets — an embedded section, a full-screen rating form, and a full-screen confirmation — are
added to `destination_exploration/view/widgets/`, then composed into
`gamification_journal`'s `DestinationDetailScreen`.

**Tech Stack:** Same as the rest of the module (Flutter, `package:provider` for the
screen-scoped `RatingController`, `supabase_flutter` already wrapped by the existing
repositories — no new dependencies).

## Global Constraints

- Rating submission is gated by `CheckInController.history` (the check-in already on
  `DestinationDetailScreen`), passed into `RatingController.submitRating` as `isCheckedIn` — not
  by Feature 4's own `destination_checkins` table/`CheckInRepository`, which is deleted.
- `RatingController.submitRating` must still call
  `DestinationRatingRepository.updateDestinationAggregates` after a successful submission
  (existing behavior, not part of this plan's scope to change) and must still degrade
  gracefully on a points/badge award failure without rolling back the rating.
- No widget tests are added — consistent with Features 1–3's views, verified via
  `flutter analyze` and manual smoke test only.
- All new UI reuses `AppColors`/`AppTypography`/`AppRadius` from `lib/config/theme.dart` (the
  design tokens `DestinationDetailScreen` and its subwidgets already use), for visual
  consistency with the screen these widgets are embedded into.
- Region for the once-per-region Pathfinder badge is `DestinationModel.state` — no new field.

## File Structure

```
lib/features/destination_exploration/
  controller/
    rating_controller.dart                # Task 2 (rewrite)
  model/
    check_in_repository.dart              # Task 2 (delete)
    rating_tag_style.dart                 # Task 1 (new)
  view/widgets/
    rating_tag_chip.dart                  # Task 3 (new)
    ratings_section.dart                  # Task 3 (new)
    submit_rating_screen.dart             # Task 4 (new)
    review_published_screen.dart          # Task 5 (new)
lib/features/gamification_journal/
  view/checkin/destination_detail_screen.dart   # Task 6 (edit)
test/
  rating_tag_style_test.dart              # Task 1 (new)
  rating_controller_test.dart             # Task 2 (rewrite)
```

---

### Task 1: `RatingTagTone` classifier

**Files:**
- Create: `lib/features/destination_exploration/model/rating_tag_style.dart`
- Test: `test/rating_tag_style_test.dart`

**Interfaces:**
- Consumes: nothing (pure, no dependencies on other Feature 4 files).
- Produces: `enum RatingTagTone { positive, caution }`, `RatingTagTone toneFor(String tag)` —
  used by Task 3's `RatingTagChip`.

- [ ] **Step 1: Write the failing test**

```dart
// test/rating_tag_style_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/rating_tag_style.dart';

void main() {
  group('toneFor', () {
    test('classifies caution tags', () {
      expect(toneFor('steep terrain'), RatingTagTone.caution);
      expect(toneFor('many stairs'), RatingTagTone.caution);
      expect(toneFor('crowded'), RatingTagTone.caution);
      expect(toneFor('slippery when wet'), RatingTagTone.caution);
    });

    test('classifies positive tags', () {
      expect(toneFor('wheelchair-friendly'), RatingTagTone.positive);
      expect(toneFor('stroller-friendly'), RatingTagTone.positive);
      expect(toneFor('parking available'), RatingTagTone.positive);
      expect(toneFor('family-friendly'), RatingTagTone.positive);
      expect(toneFor('shaded'), RatingTagTone.positive);
    });

    test('unknown tags default to positive', () {
      expect(toneFor('something new'), RatingTagTone.positive);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/rating_tag_style_test.dart`
Expected: FAIL — `rating_tag_style.dart` doesn't exist yet (compile error).

- [ ] **Step 3: Write `rating_tag_style.dart`**

```dart
// lib/features/destination_exploration/model/rating_tag_style.dart

enum RatingTagTone { positive, caution }

const _cautionTags = {
  'steep terrain',
  'many stairs',
  'crowded',
  'slippery when wet',
};

/// Classifies a KeywordTaggingEngine tag into a display tone — caution
/// tags (hazards/friction) render differently from accessibility-positive
/// ones. Pure and static: the keyword map itself is fixed (10 entries), so
/// no new backend field is needed for this.
RatingTagTone toneFor(String tag) =>
    _cautionTags.contains(tag) ? RatingTagTone.caution : RatingTagTone.positive;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/rating_tag_style_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/destination_exploration/model/rating_tag_style.dart test/rating_tag_style_test.dart
git commit -m "feat(destination-ratings): add RatingTagTone tag classifier"
```

---

### Task 2: Rewrite `RatingController`, delete `CheckInRepository`

**Files:**
- Modify: `lib/features/destination_exploration/controller/rating_controller.dart`
- Delete: `lib/features/destination_exploration/model/check_in_repository.dart`
- Modify: `test/rating_controller_test.dart`

**Interfaces:**
- Consumes: `DestinationRatingRepository` (`submitRating`, `fetchRatingSummary`, `fetchReviews`,
  `updateDestinationAggregates` — all already exist, unchanged), `UserProgressRepository`
  (unchanged), `RatingSummary`/`DestinationReview` (unchanged).
- Produces: `class RatingController extends ChangeNotifier` with `isLoadingSummary`,
  `isLoadingReviews`, `isSubmitting`, `error`, `pointsAwarded`, `pathfinderBadgeUnlocked`,
  `summary` (`RatingSummary?`), `reviews` (`List<DestinationReview>`), `hasMoreReviews` (`bool`),
  `static const int pointsPerContribution = 15`, `static const int reviewsPageSize = 20`,
  `Future<void> loadSummary(String destinationId)`,
  `Future<void> loadReviews(String destinationId, {bool loadMore = false})`,
  `Future<void> submitRating({required String destinationId, required String region, required int difficultyScore, required String reviewText, required bool isCheckedIn})`.
  No more `checkIn()`, no more `isCheckedIn` field, no more `CheckInRepository` constructor
  param — used by Tasks 3–5.

- [ ] **Step 1: Replace the test file**

```dart
// test/rating_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/controller/rating_controller.dart';
import 'package:collab/features/destination_exploration/model/destination_rating_repository.dart';
import 'package:collab/features/destination_exploration/model/difficulty_bucket.dart';
import 'package:collab/features/destination_exploration/model/rating_summary.dart';
import 'package:collab/features/destination_exploration/model/user_progress_repository.dart';

class _FakeRatingRepository extends DestinationRatingRepository {
  _FakeRatingRepository({
    this.throwOnSubmit = false,
    this.summaryResult,
    this.reviewsResult = const [],
  });
  final bool throwOnSubmit;
  final RatingSummary? summaryResult;
  final List<DestinationReview> reviewsResult;
  int submitCallCount = 0;

  @override
  Future<void> submitRating({
    required String destinationId,
    required int difficultyScore,
    required String reviewText,
  }) async {
    submitCallCount++;
    if (throwOnSubmit) throw Exception('network error');
  }

  @override
  Future<RatingSummary> fetchRatingSummary(String destinationId) async =>
      summaryResult ??
      const RatingSummary(
        difficultyBucket: DifficultyBucket.easy,
        avgDifficulty: 0,
        ratingCount: 0,
        topTags: [],
      );

  @override
  Future<List<DestinationReview>> fetchReviews(
    String destinationId, {
    int limit = 20,
    int offset = 0,
  }) async {
    if (offset >= reviewsResult.length) return const [];
    final end = (offset + limit).clamp(0, reviewsResult.length);
    return reviewsResult.sublist(offset, end);
  }

  @override
  Future<void> updateDestinationAggregates(String destinationId, RatingSummary summary) async {}
}

class _FakeProgressRepository extends UserProgressRepository {
  _FakeProgressRepository({this.points = 15, this.badgeUnlocked = true, this.throwOnAward = false});
  final int points;
  final bool badgeUnlocked;
  final bool throwOnAward;

  @override
  Future<int> awardPoints(int amount) async {
    if (throwOnAward) throw Exception('network error');
    return points;
  }

  @override
  Future<bool> awardPathfinderBadgeIfNew(String region) async {
    if (throwOnAward) throw Exception('network error');
    return badgeUnlocked;
  }
}

DestinationReview _review(String text) => DestinationReview(
      reviewText: text,
      difficultyScore: 3,
      generatedTags: const [],
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('RatingController.submitRating', () {
    test('blocks with an error when isCheckedIn is false', () async {
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(),
        progressRepository: _FakeProgressRepository(),
      );

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: false,
      );

      expect(controller.error, 'A verified check-in is required to submit a rating.');
    });

    test('does not call the repository when isCheckedIn is false', () async {
      final ratingRepo = _FakeRatingRepository();
      final controller = RatingController(
        ratingRepository: ratingRepo,
        progressRepository: _FakeProgressRepository(),
      );

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: false,
      );

      expect(ratingRepo.submitCallCount, 0);
    });

    test('succeeds, refreshes summary/reviews, and awards points/badge when checked in', () async {
      const summary = RatingSummary(
        difficultyBucket: DifficultyBucket.moderate,
        avgDifficulty: 3.0,
        ratingCount: 1,
        topTags: [],
      );
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(
          summaryResult: summary,
          reviewsResult: [_review('Nice place')],
        ),
        progressRepository: _FakeProgressRepository(points: 15, badgeUnlocked: true),
      );

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: true,
      );

      expect(controller.error, isNull);
      expect(controller.summary, summary);
      expect(controller.reviews, hasLength(1));
      expect(controller.pointsAwarded, 15);
      expect(controller.pathfinderBadgeUnlocked, isTrue);
    });

    test('a second contribution in the same region does not re-unlock the badge', () async {
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(),
        progressRepository: _FakeProgressRepository(badgeUnlocked: false),
      );

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: true,
      );

      expect(controller.pathfinderBadgeUnlocked, isFalse);
    });

    test('a points/badge failure does not roll back the rating submission', () async {
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(),
        progressRepository: _FakeProgressRepository(throwOnAward: true),
      );

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: true,
      );

      expect(controller.error, isNull);
      expect(controller.pointsAwarded, isNull);
      expect(controller.pathfinderBadgeUnlocked, isFalse);
    });

    test('a rating submission failure sets error and does not award points', () async {
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(throwOnSubmit: true),
        progressRepository: _FakeProgressRepository(),
      );

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: true,
      );

      expect(controller.error, isNotNull);
      expect(controller.pointsAwarded, isNull);
    });

    test('overlapping submitRating calls are a no-op after the first', () async {
      final ratingRepo = _FakeRatingRepository();
      final controller = RatingController(
        ratingRepository: ratingRepo,
        progressRepository: _FakeProgressRepository(),
      );

      final call1 = controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: true,
      );
      final call2 = controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
        isCheckedIn: true,
      );

      await call1;
      await call2;

      expect(ratingRepo.submitCallCount, 1);
    });
  });

  group('RatingController.loadSummary', () {
    test('populates summary from the repository', () async {
      const summary = RatingSummary(
        difficultyBucket: DifficultyBucket.hard,
        avgDifficulty: 4.2,
        ratingCount: 5,
        topTags: [],
      );
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(summaryResult: summary),
        progressRepository: _FakeProgressRepository(),
      );

      await controller.loadSummary('d1');

      expect(controller.summary, summary);
      expect(controller.isLoadingSummary, isFalse);
    });
  });

  group('RatingController.loadReviews', () {
    test('populates reviews from the first page', () async {
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(
          reviewsResult: [_review('a'), _review('b')],
        ),
        progressRepository: _FakeProgressRepository(),
      );

      await controller.loadReviews('d1');

      expect(controller.reviews.map((r) => r.reviewText), ['a', 'b']);
      expect(controller.isLoadingReviews, isFalse);
    });

    test('loadMore appends to the existing list using an offset', () async {
      final controller = RatingController(
        ratingRepository: _FakeRatingRepository(
          reviewsResult: List.generate(25, (i) => _review('review $i')),
        ),
        progressRepository: _FakeProgressRepository(),
      );

      await controller.loadReviews('d1');
      expect(controller.reviews, hasLength(20));
      expect(controller.hasMoreReviews, isTrue);

      await controller.loadReviews('d1', loadMore: true);
      expect(controller.reviews, hasLength(25));
      expect(controller.hasMoreReviews, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/rating_controller_test.dart`
Expected: FAIL — compile errors (`RatingController` still requires `checkInRepository`,
`submitRating` doesn't accept `isCheckedIn`, `loadSummary`/`loadReviews` don't exist).

- [ ] **Step 3: Rewrite `rating_controller.dart`**

```dart
// lib/features/destination_exploration/controller/rating_controller.dart
import 'package:flutter/foundation.dart';

import '../model/destination_rating_repository.dart';
import '../model/rating_summary.dart';
import '../model/user_progress_repository.dart';

/// Business logic for check-in-gated rating submission (Feature 4). Kept as
/// a plain ChangeNotifier per the module's MVC convention.
///
/// Check-in state is NOT tracked here — rating submission is gated by
/// whatever check-in already exists on the screen this is embedded in (see
/// the View design spec's "Check-in gate" decision), passed into
/// [submitRating] as [isCheckedIn] rather than owned by this controller.
class RatingController extends ChangeNotifier {
  RatingController({
    DestinationRatingRepository? ratingRepository,
    UserProgressRepository? progressRepository,
  })  : _ratingRepository = ratingRepository ?? DestinationRatingRepository(),
        _progressRepository = progressRepository ?? UserProgressRepository();

  final DestinationRatingRepository _ratingRepository;
  final UserProgressRepository _progressRepository;

  static const int pointsPerContribution = 15;
  static const int reviewsPageSize = 20;

  bool isLoadingSummary = false;
  bool isLoadingReviews = false;
  bool isSubmitting = false;
  String? error;
  int? pointsAwarded;
  bool pathfinderBadgeUnlocked = false;
  RatingSummary? summary;
  List<DestinationReview> reviews = const [];
  bool hasMoreReviews = true;

  Future<void> loadSummary(String destinationId) async {
    isLoadingSummary = true;
    notifyListeners();
    try {
      summary = await _ratingRepository.fetchRatingSummary(destinationId);
    } catch (_) {
      // Leave summary as-is — the View shows an empty state either way, no
      // separate error surface needed for a read.
    }
    isLoadingSummary = false;
    notifyListeners();
  }

  Future<void> loadReviews(String destinationId, {bool loadMore = false}) async {
    isLoadingReviews = true;
    notifyListeners();
    try {
      final offset = loadMore ? reviews.length : 0;
      final result = await _ratingRepository.fetchReviews(
        destinationId,
        limit: reviewsPageSize,
        offset: offset,
      );
      reviews = loadMore ? [...reviews, ...result] : result;
      hasMoreReviews = result.length == reviewsPageSize;
    } catch (_) {
      if (!loadMore) reviews = const [];
      hasMoreReviews = false;
    }
    isLoadingReviews = false;
    notifyListeners();
  }

  /// Blocks with [error] set if [isCheckedIn] is false (E2), without calling
  /// any repository. Otherwise submits the rating, refreshes [summary] and
  /// [reviews], writes back the destination's aggregate difficulty/tags,
  /// then awards points/a badge — a failure in that last step does not roll
  /// back the already-successful rating submission (it degrades gracefully:
  /// [pointsAwarded] stays null, [error] stays null).
  ///
  /// Reentrancy guard: overlapping calls return immediately as no-op to
  /// prevent duplicate submissions (e.g. user double-tapping submit).
  Future<void> submitRating({
    required String destinationId,
    required String region,
    required int difficultyScore,
    required String reviewText,
    required bool isCheckedIn,
  }) async {
    if (isSubmitting) return;

    if (!isCheckedIn) {
      error = 'A verified check-in is required to submit a rating.';
      notifyListeners();
      return;
    }

    isSubmitting = true;
    error = null;
    pointsAwarded = null;
    pathfinderBadgeUnlocked = false;
    notifyListeners();

    try {
      await _ratingRepository.submitRating(
        destinationId: destinationId,
        difficultyScore: difficultyScore,
        reviewText: reviewText,
      );
      summary = await _ratingRepository.fetchRatingSummary(destinationId);
      reviews = await _ratingRepository.fetchReviews(destinationId, limit: reviewsPageSize);
      hasMoreReviews = reviews.length == reviewsPageSize;
    } catch (_) {
      error = "Couldn't submit your rating right now.";
      isSubmitting = false;
      notifyListeners();
      return;
    }

    try {
      await _ratingRepository.updateDestinationAggregates(destinationId, summary!);
    } catch (_) {
      // Degrades gracefully — the rating itself already succeeded; a failure
      // here just means the comparison table stays stale until next time.
    }

    try {
      pointsAwarded = await _progressRepository.awardPoints(pointsPerContribution);
      pathfinderBadgeUnlocked = await _progressRepository.awardPathfinderBadgeIfNew(region);
    } catch (_) {
      pointsAwarded = null;
      pathfinderBadgeUnlocked = false;
    }

    isSubmitting = false;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Delete `check_in_repository.dart`**

```bash
git rm lib/features/destination_exploration/model/check_in_repository.dart
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/rating_controller_test.dart`
Expected: PASS (11 tests).

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze lib/features/destination_exploration/controller/rating_controller.dart test/rating_controller_test.dart`
Expected: no errors (no remaining references to the deleted `CheckInRepository`).

- [ ] **Step 7: Commit**

```bash
git add lib/features/destination_exploration/controller/rating_controller.dart test/rating_controller_test.dart
git commit -m "refactor(destination-ratings): gate RatingController on caller-supplied check-in state, add summary/review loading"
```

---

### Task 3: `RatingTagChip` and `RatingsSection`

**Files:**
- Create: `lib/features/destination_exploration/view/widgets/rating_tag_chip.dart`
- Create: `lib/features/destination_exploration/view/widgets/ratings_section.dart`

**Interfaces:**
- Consumes: `RatingController` (Task 2), `toneFor`/`RatingTagTone` (Task 1),
  `DifficultyBucket`/`difficultyBucketFor`/`DifficultyBucketX.label` (existing),
  `RatingSummary`/`TagFrequency`/`DestinationReview` (existing), `SubmitRatingScreen` (Task 4 —
  forward reference; Task 3 is implemented before Task 4 exists, so this file's import is added
  now and will resolve once Task 4 lands. `flutter analyze` for this task alone will report an
  unresolved import until Task 4 is done — expected, not a blocker for these two steps).
- Produces: `class RatingTagChip extends StatelessWidget` with `{required String tag}`;
  `class RatingsSection extends StatefulWidget` with
  `{required String destinationId, required String destinationName, required String destinationImageUrl, required String region, required bool isCheckedIn}`;
  top-level `String relativeTime(DateTime dt)` — used by Task 6.

- [ ] **Step 1: Write `rating_tag_chip.dart`**

```dart
// lib/features/destination_exploration/view/widgets/rating_tag_chip.dart
import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../model/rating_tag_style.dart';

/// A single generated-tag chip, color-coded by [toneFor] — shared by the
/// ratings section, the submit-rating form, and the review-published
/// confirmation so all three render tags identically.
class RatingTagChip extends StatelessWidget {
  const RatingTagChip({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(tag);
    final background =
        tone == RatingTagTone.caution ? AppColors.errorContainer : AppColors.secondaryContainer;
    final foreground = tone == RatingTagTone.caution
        ? AppColors.onErrorContainer
        : AppColors.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(tag, style: AppTypography.labelSm.copyWith(color: foreground)),
    );
  }
}
```

- [ ] **Step 2: Write `ratings_section.dart`**

```dart
// lib/features/destination_exploration/view/widgets/ratings_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/rating_controller.dart';
import '../../model/difficulty_bucket.dart';
import '../../model/rating_summary.dart';
import 'rating_tag_chip.dart';
import 'submit_rating_screen.dart';

/// Feature 4's "Ratings & Accessibility" section, embedded into
/// gamification_journal's DestinationDetailScreen (see the View design
/// spec's "Entry point" decision) rather than living on its own page.
class RatingsSection extends StatefulWidget {
  const RatingsSection({
    super.key,
    required this.destinationId,
    required this.destinationName,
    required this.destinationImageUrl,
    required this.region,
    required this.isCheckedIn,
  });

  final String destinationId;
  final String destinationName;
  final String destinationImageUrl;
  final String region;
  final bool isCheckedIn;

  @override
  State<RatingsSection> createState() => _RatingsSectionState();
}

class _RatingsSectionState extends State<RatingsSection> {
  late final RatingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RatingController()
      ..loadSummary(widget.destinationId)
      ..loadReviews(widget.destinationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openWriteReview(BuildContext context) async {
    if (!widget.isCheckedIn) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<RatingController>.value(
          value: _controller,
          child: SubmitRatingScreen(
            destinationId: widget.destinationId,
            destinationName: widget.destinationName,
            destinationImageUrl: widget.destinationImageUrl,
            region: widget.region,
            isCheckedIn: widget.isCheckedIn,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RatingController>.value(
      value: _controller,
      child: Consumer<RatingController>(
        builder: (context, controller, _) => _RatingsSectionBody(
          controller: controller,
          isCheckedIn: widget.isCheckedIn,
          destinationId: widget.destinationId,
          onWriteReview: () => _openWriteReview(context),
        ),
      ),
    );
  }
}

class _RatingsSectionBody extends StatelessWidget {
  const _RatingsSectionBody({
    required this.controller,
    required this.isCheckedIn,
    required this.destinationId,
    required this.onWriteReview,
  });

  final RatingController controller;
  final bool isCheckedIn;
  final String destinationId;
  final VoidCallback onWriteReview;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Difficulty & Accessibility', style: AppTypography.headlineSm),
        const SizedBox(height: 10),
        if (summary == null || summary.ratingCount == 0)
          Text('Be the first to review this destination.', style: AppTypography.bodySm)
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in summary.topTags) RatingTagChip(tag: tag.tag)],
          ),
          const SizedBox(height: 8),
          Text(
            'Community-reported, unverified',
            style: AppTypography.labelSm.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Text('Community Reviews', style: AppTypography.headlineSm)),
            TextButton(
              onPressed: isCheckedIn ? onWriteReview : null,
              child: const Text('Write a Review'),
            ),
          ],
        ),
        Text(
          summary == null
              ? 'Loading reviews…'
              : 'Based on ${summary.ratingCount} review${summary.ratingCount == 1 ? '' : 's'} from fellow explorers',
          style: AppTypography.bodySm,
        ),
        if (!isCheckedIn) ...[
          const SizedBox(height: 4),
          Text(
            'Check in above to write a review',
            style: AppTypography.labelSm.copyWith(color: AppColors.outline),
          ),
        ],
        const SizedBox(height: 12),
        for (final review in controller.reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReviewCard(review: review),
          ),
        if (controller.hasMoreReviews)
          Center(
            child: TextButton(
              onPressed: controller.isLoadingReviews
                  ? null
                  : () => controller.loadReviews(destinationId, loadMore: true),
              child: Text(
                controller.isLoadingReviews
                    ? 'Loading…'
                    : 'Read All ${summary?.ratingCount ?? ''} Reviews'.trim(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final DestinationReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: Icon(Icons.person_outline, size: 16, color: AppColors.outline),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Community Member', style: AppTypography.labelMd),
                    Text(relativeTime(review.createdAt), style: AppTypography.labelSm),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainerTint,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  difficultyBucketFor(review.difficultyScore.toDouble()).label,
                  style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${review.reviewText}"',
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
          ),
          if (review.generatedTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in review.generatedTags) RatingTagChip(tag: tag)],
            ),
          ],
        ],
      ),
    );
  }
}

/// Coarse, human-friendly relative time for review timestamps (e.g. "2d
/// ago") — display-only, no need to match any particular locale library.
String relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w ago';
  final months = (diff.inDays / 30).floor();
  return '${months}mo ago';
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/destination_exploration/view/widgets/rating_tag_chip.dart lib/features/destination_exploration/view/widgets/ratings_section.dart
git commit -m "feat(destination-ratings): add RatingTagChip and the embedded RatingsSection"
```

(`flutter analyze` is deferred to Task 4's step, once `submit_rating_screen.dart` exists and
the forward-referenced import resolves.)

---

### Task 4: `SubmitRatingScreen`

**Files:**
- Create: `lib/features/destination_exploration/view/widgets/submit_rating_screen.dart`

**Interfaces:**
- Consumes: `RatingController` (Task 2, read via `package:provider` — expects one already
  provided above it in the tree, see Task 3's `_openWriteReview`), `KeywordTaggingEngine`
  (existing), `difficultyBucketFor`/`DifficultyBucketX.label` (existing), `RatingTagChip`
  (Task 3), `ReviewPublishedScreen` (Task 5 — forward reference, same as Task 3/4).
- Produces: `class SubmitRatingScreen extends StatefulWidget` with
  `{required String destinationId, required String destinationName, required String destinationImageUrl, required String region, required bool isCheckedIn}`
  — used by Task 3.

- [ ] **Step 1: Write `submit_rating_screen.dart`**

```dart
// lib/features/destination_exploration/view/widgets/submit_rating_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/rating_controller.dart';
import '../../model/difficulty_bucket.dart';
import '../../model/keyword_tagging_engine.dart';
import 'rating_tag_chip.dart';
import 'review_published_screen.dart';

/// Feature 4's rating submission form — pushed from RatingsSection's
/// "Write a Review". Expects a RatingController to already be provided
/// above it in the tree (see RatingsSection._openWriteReview).
class SubmitRatingScreen extends StatefulWidget {
  const SubmitRatingScreen({
    super.key,
    required this.destinationId,
    required this.destinationName,
    required this.destinationImageUrl,
    required this.region,
    required this.isCheckedIn,
  });

  final String destinationId;
  final String destinationName;
  final String destinationImageUrl;
  final String region;
  final bool isCheckedIn;

  @override
  State<SubmitRatingScreen> createState() => _SubmitRatingScreenState();
}

class _SubmitRatingScreenState extends State<SubmitRatingScreen> {
  int _difficultyScore = 3;
  final _reviewController = TextEditingController();
  List<String> _liveTags = const [];

  @override
  void initState() {
    super.initState();
    _reviewController.addListener(_onReviewTextChanged);
  }

  void _onReviewTextChanged() {
    setState(() => _liveTags = KeywordTaggingEngine.tagsFor(_reviewController.text));
  }

  @override
  void dispose() {
    _reviewController.removeListener(_onReviewTextChanged);
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = context.read<RatingController>();
    await controller.submitRating(
      destinationId: widget.destinationId,
      region: widget.region,
      difficultyScore: _difficultyScore,
      reviewText: _reviewController.text,
      isCheckedIn: widget.isCheckedIn,
    );

    if (!mounted) return;

    if (controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.error!)));
      return;
    }

    final reviewText = _reviewController.text;
    final tags = _liveTags;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<RatingController>.value(
          value: controller,
          child: ReviewPublishedScreen(
            destinationName: widget.destinationName,
            reviewText: reviewText,
            tags: tags,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RatingController>();
    final bucketLabel = difficultyBucketFor(_difficultyScore.toDouble()).label;

    return Scaffold(
      appBar: AppBar(title: const Text('Write a Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  'CHECK-IN COMPLETE',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.destinationName, style: AppTypography.headlineLgMobile),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(widget.destinationImageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Share your experience to help other explorers navigate this hidden gem. '
              'Your contributions keep the Field Journal accurate.',
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Difficulty', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          bucketLabel,
                          style:
                              AppTypography.labelMd.copyWith(color: AppColors.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _difficultyScore.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (v) => setState(() => _difficultyScore = v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Easy', style: AppTypography.labelSm),
                      Text('Moderate', style: AppTypography.labelSm),
                      Text('Hard', style: AppTypography.labelSm),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Your Experience', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLength: 500,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What was the path like? Any accessibility notes?',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: AppColors.onPrimaryContainer),
                const SizedBox(width: 6),
                Text('Auto-generated Tags', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _liveTags) RatingTagChip(tag: tag),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '+ Add Tag',
                    style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tags are extracted from your review text automatically.',
              style: AppTypography.labelSm.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 17, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Disclaimer: This is crowd-sourced data. Field Journal does not guarantee '
                      'the current safety or accessibility of paths. Always exercise caution and '
                      'follow local safety signs.',
                      style: AppTypography.bodySm,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isSubmitting ? null : _submit,
                child: Text(controller.isSubmitting ? 'Submitting…' : 'Submit Contribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/destination_exploration/view/widgets/submit_rating_screen.dart
git commit -m "feat(destination-ratings): add SubmitRatingScreen with live tag preview"
```

(Analysis deferred to Task 5, once `review_published_screen.dart` exists.)

---

### Task 5: `ReviewPublishedScreen`

**Files:**
- Create: `lib/features/destination_exploration/view/widgets/review_published_screen.dart`

**Interfaces:**
- Consumes: `RatingController` (Task 2, read via provider — same instance `SubmitRatingScreen`
  re-provided in Task 4's `_submit`), `RatingTagChip` (Task 3).
- Produces: `class ReviewPublishedScreen extends StatelessWidget` with
  `{required String destinationName, required String reviewText, required List<String> tags}`
  — used by Task 4.

- [ ] **Step 1: Write `review_published_screen.dart`**

```dart
// lib/features/destination_exploration/view/widgets/review_published_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/rating_controller.dart';
import 'rating_tag_chip.dart';

/// Confirmation screen shown after a successful rating submission —
/// replaces SubmitRatingScreen in the nav stack (see
/// SubmitRatingScreen._submit), so "Return to Map" only needs a single pop
/// back to the destination detail screen.
class ReviewPublishedScreen extends StatelessWidget {
  const ReviewPublishedScreen({
    super.key,
    required this.destinationName,
    required this.reviewText,
    required this.tags,
  });

  final String destinationName;
  final String reviewText;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RatingController>();
    final summary = controller.summary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.onPrimaryContainer, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for your contribution',
                style: AppTypography.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Your update helps the community navigate $destinationName safely.',
                style: AppTypography.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You reviewed $destinationName', style: AppTypography.labelMd),
                    Text('Community Member · Just now', style: AppTypography.labelSm),
                    const SizedBox(height: 10),
                    Text(
                      '"$reviewText"',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'AUTO-GENERATED TAGS',
                        style: AppTypography.labelSm.copyWith(fontSize: 10.5),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final tag in tags) RatingTagChip(tag: tag)],
                      ),
                    ],
                  ],
                ),
              ),
              if (summary != null && summary.ratingCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Community Consensus', style: AppTypography.labelMd),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Aggregated Difficulty', style: AppTypography.bodySm),
                          Text(summary.difficultyBucket.label, style: AppTypography.labelMd),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: (summary.avgDifficulty / 5).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          valueColor: const AlwaysStoppedAnimation(AppColors.secondaryContainer),
                        ),
                      ),
                      if (summary.topTags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'TOP COMMUNITY TAGS',
                          style: AppTypography.labelSm.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in summary.topTags)
                              RatingTagChip(tag: '${tag.tag} ${tag.percentage.round()}%'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${RatingController.pointsPerContribution} Trail Points',
                            style:
                                AppTypography.labelMd.copyWith(color: AppColors.onPrimaryContainer),
                          ),
                          if (controller.pathfinderBadgeUnlocked)
                            Text(
                              "You've unlocked the 'Pathfinder' badge for this region.",
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.onPrimaryContainer),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return to Map'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run static analysis on all of Tasks 3–5**

Run: `flutter analyze lib/features/destination_exploration/view/widgets/rating_tag_chip.dart lib/features/destination_exploration/view/widgets/ratings_section.dart lib/features/destination_exploration/view/widgets/submit_rating_screen.dart lib/features/destination_exploration/view/widgets/review_published_screen.dart`
Expected: no errors (the forward references from Tasks 3–4 now resolve).

- [ ] **Step 3: Commit**

```bash
git add lib/features/destination_exploration/view/widgets/review_published_screen.dart
git commit -m "feat(destination-ratings): add ReviewPublishedScreen with points/badge display"
```

---

### Task 6: Embed `RatingsSection` into `DestinationDetailScreen`

**Files:**
- Modify: `lib/features/gamification_journal/view/checkin/destination_detail_screen.dart`

**Interfaces:**
- Consumes: `RatingsSection` (Task 3).

- [ ] **Step 1: Add the import**

In `lib/features/gamification_journal/view/checkin/destination_detail_screen.dart`, add this
import alongside the existing ones (after the `url_launcher` import, before the local
`config`/`shared` imports, matching the file's existing import ordering):

```dart
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/check_in_button.dart';
import '../../../destination_exploration/view/widgets/ratings_section.dart';
import '../../controller/badge_controller.dart';
```

(This inserts one new line — `import '../../../destination_exploration/view/widgets/ratings_section.dart';`
— between the existing `check_in_button.dart` and `badge_controller.dart` imports, alphabetically
consistent with the rest of the block.)

- [ ] **Step 2: Embed the section after the check-in button**

Find this block near the end of `build()`:

```dart
            const SizedBox(height: 22),
            CheckInButtonWidget(
              status: _checkInStatus,
              errorMessage: _checkInErrorMessage,
              onPressed: _handleCheckIn,
            ),
          ],
        ),
      ),
    );
  }
}
```

Replace it with:

```dart
            const SizedBox(height: 22),
            CheckInButtonWidget(
              status: _checkInStatus,
              errorMessage: _checkInErrorMessage,
              onPressed: _handleCheckIn,
            ),
            const Divider(height: 40),
            RatingsSection(
              destinationId: destination.id,
              destinationName: destination.name,
              destinationImageUrl: destination.imageUrl,
              region: destination.state,
              isCheckedIn: isCheckedIn,
            ),
          ],
        ),
      ),
    );
  }
}
```

(`destination` and `isCheckedIn` are both already local variables in `build()` — no new state
needed.)

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze lib/features/gamification_journal/view/checkin/destination_detail_screen.dart`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/gamification_journal/view/checkin/destination_detail_screen.dart
git commit -m "feat(destination-ratings): embed RatingsSection into the destination detail screen"
```

---

### Task 7: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: PASS — every test across all modules, including the rewritten
`rating_controller_test.dart` and new `rating_tag_style_test.dart`.

- [ ] **Step 2: Run static analysis on the whole project**

Run: `flutter analyze`
Expected: no new errors or warnings beyond whatever pre-existing `info`-level lints already
exist elsewhere in the codebase (unrelated to this plan).

- [ ] **Step 3: Report the operational follow-up**

Confirm with the user whether `supabase/migrations/202608060003_destination_ratings.sql` (creates
`destination_ratings`, `user_trail_points`, `user_badges`, `destination_checkins`) has been
applied to the live Supabase project. If not, rating submission will fail with "Couldn't submit
your rating right now" (caught gracefully, no crash) until it's applied via the Supabase
Dashboard SQL Editor — same process used for Feature 1's `destinations` table migration earlier
in this project.

---

## Self-Review Notes

**Spec coverage:** every section of `2026-08-07-destination-exploration-ratings-view-design.md`
maps to a task — entry point/merge (Task 6), check-in gate (Task 2), rating form + live tag
preview (Task 4), tag color-coding (Task 1), reviewer identity (Task 3's `_ReviewCard`),
"Read All Reviews" in-place pagination (Task 3), region source (Task 6), points/badge display
(Task 5), operational migration flag (Task 7).

**Placeholder scan:** no TBD/TODO, no undefined references — checked. The two forward
references (Task 3 → Task 4's `SubmitRatingScreen`, Task 4 → Task 5's `ReviewPublishedScreen`)
are explicitly called out with expected-to-fail analysis until the later task lands, not left
ambiguous.

**Type consistency:** `RatingController`'s field/method names (`isLoadingSummary`,
`isLoadingReviews`, `isSubmitting`, `error`, `pointsAwarded`, `pathfinderBadgeUnlocked`,
`summary`, `reviews`, `hasMoreReviews`, `loadSummary`, `loadReviews`, `submitRating`) match
identically across Tasks 2–6. `RatingsSection`/`SubmitRatingScreen`/`ReviewPublishedScreen`
constructor parameter names match at each call site — checked.
