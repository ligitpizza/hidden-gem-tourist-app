# Destination Exploration — Feature 4: Crowd-Sourced Difficulty & Accessibility Ratings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Crowd-Sourced Difficulty & Accessibility Ratings (FR4.1–FR4.6) as Model +
Controller only — a minimal check-in gate, deterministic keyword tagging, rating aggregation,
and a minimal points/badge hook, with no UI.

**Architecture:** A small standalone check-in table gates rating submission; submitted reviews
run through a deterministic keyword→tag pipeline; aggregation is a pure function separated
from its Supabase-calling wrapper (same testability pattern as Features 1–2's repositories).

**Tech Stack:** Same as Features 1–3 (Flutter, `flutter_riverpod`, `supabase_flutter`).

**Prerequisite:** Feature 3's plan already executed — `destinations.city` exists (used as
`region` here).

## Global Constraints

- Rating submission is hard-gated behind `RatingController.isCheckedIn` — no repository call
  happens without it (E2).
- `KeywordTaggingEngine.tagsFor` is deterministic keyword matching only — no NLP, no
  negation-awareness (NFR9, E1 accepted as a known limitation).
- The points/badge system is deliberately narrow: a flat 15 points per rating submission, one
  `'pathfinder'` badge unlocked once per region (`destinations.city`) — not the broader
  `gamification_journal` system.
- A points/badge-awarding failure must never roll back an already-successful rating
  submission — points/badges degrade gracefully.
- No View is built in this plan — every task's deliverable is verified by `flutter test`.

---

## File Structure

```
supabase/migrations/
  202608060003_destination_ratings.sql        # Task 1
lib/features/destination_exploration/
  model/
    keyword_tagging_engine.dart                # Task 1
    difficulty_bucket.dart                      # Task 1
    rating_summary.dart                         # Task 2 (+ TagFrequency, DestinationReview)
    destination_rating_repository.dart          # Task 2
    check_in_repository.dart                    # Task 3
    user_progress_repository.dart               # Task 3
  controller/
    rating_controller.dart                      # Task 4
test/
  keyword_tagging_engine_test.dart               # Task 1
  destination_rating_repository_test.dart        # Task 2
  rating_controller_test.dart                    # Task 4
```

---

### Task 1: Migration, `KeywordTaggingEngine`, `DifficultyBucket`

**Files:**
- Create: `supabase/migrations/202608060003_destination_ratings.sql`
- Create: `lib/features/destination_exploration/model/keyword_tagging_engine.dart`
- Create: `lib/features/destination_exploration/model/difficulty_bucket.dart`
- Test: `test/keyword_tagging_engine_test.dart`

**Interfaces:**
- Produces:
  - `enum DifficultyBucket { easy, moderate, hard }`, `DifficultyBucket difficultyBucketFor(double avgDifficulty)`.
  - `class KeywordTaggingEngine { static List<String> tagsFor(String reviewText); }`.

- [ ] **Step 1: Write the migration**

```sql
-- supabase/migrations/202608060003_destination_ratings.sql
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

Run this migration against the Supabase project, same as prior migrations.

- [ ] **Step 2: Write `DifficultyBucket`**

```dart
// lib/features/destination_exploration/model/difficulty_bucket.dart

enum DifficultyBucket { easy, moderate, hard }

extension DifficultyBucketX on DifficultyBucket {
  String get label {
    switch (this) {
      case DifficultyBucket.easy:
        return 'Easy';
      case DifficultyBucket.moderate:
        return 'Moderate';
      case DifficultyBucket.hard:
        return 'Hard';
    }
  }
}

/// Aggregated 1-5 difficulty scores bucket into a coarse label (FR4.4).
DifficultyBucket difficultyBucketFor(double avgDifficulty) {
  if (avgDifficulty <= 2.0) return DifficultyBucket.easy;
  if (avgDifficulty <= 3.5) return DifficultyBucket.moderate;
  return DifficultyBucket.hard;
}
```

- [ ] **Step 3: Write the failing `KeywordTaggingEngine` tests**

```dart
// test/keyword_tagging_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/difficulty_bucket.dart';
import 'package:collab/features/destination_exploration/model/keyword_tagging_engine.dart';

void main() {
  group('KeywordTaggingEngine.tagsFor', () {
    test('matches each keyword to its tag', () {
      expect(KeywordTaggingEngine.tagsFor('great for wheelchair users'), ['wheelchair-friendly']);
      expect(KeywordTaggingEngine.tagsFor('bring a stroller'), ['stroller-friendly']);
      expect(KeywordTaggingEngine.tagsFor('very steep near the top'), ['steep terrain']);
      expect(KeywordTaggingEngine.tagsFor('lots of stairs'), ['many stairs']);
      expect(KeywordTaggingEngine.tagsFor('free parking available'), ['parking available']);
      expect(KeywordTaggingEngine.tagsFor('gets crowded on weekends'), ['crowded']);
      expect(KeywordTaggingEngine.tagsFor('great for kids'), ['family-friendly']);
      expect(KeywordTaggingEngine.tagsFor('good family spot'), ['family-friendly']);
      expect(KeywordTaggingEngine.tagsFor('lots of shade'), ['shaded']);
      expect(KeywordTaggingEngine.tagsFor('slippery when wet'), ['slippery when wet']);
    });

    test('is case-insensitive', () {
      expect(KeywordTaggingEngine.tagsFor('WHEELCHAIR accessible'), ['wheelchair-friendly']);
    });

    test('produces multiple deduplicated tags from one review', () {
      final tags = KeywordTaggingEngine.tagsFor(
        'The path was a bit slippery but wheelchair-friendly at the base, wheelchair ramps everywhere',
      );
      expect(tags, ['slippery when wet', 'wheelchair-friendly']);
    });

    test('returns an empty list when nothing matches', () {
      expect(KeywordTaggingEngine.tagsFor('Absolutely breathtaking views'), isEmpty);
    });
  });

  group('difficultyBucketFor', () {
    test('boundary values', () {
      expect(difficultyBucketFor(2.0), DifficultyBucket.easy);
      expect(difficultyBucketFor(2.01), DifficultyBucket.moderate);
      expect(difficultyBucketFor(3.5), DifficultyBucket.moderate);
      expect(difficultyBucketFor(3.51), DifficultyBucket.hard);
    });
  });
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `flutter test test/keyword_tagging_engine_test.dart`
Expected: FAIL — `KeywordTaggingEngine`/`difficultyBucketFor` don't exist yet (compile error).

- [ ] **Step 5: Write `KeywordTaggingEngine`**

```dart
// lib/features/destination_exploration/model/keyword_tagging_engine.dart

/// Deterministic, rule-based keyword-to-tag pipeline (FR4.3, NFR9 — "not an
/// NLP classifier", auditable/upgradeable later). Mirrors the pure/static
/// classification style of OverpassEcoSource.classifyDiet
/// (lib/features/travel_assistant/model/eco_partner_repository.dart). Negated
/// phrasing (e.g. "not wheelchair friendly" still tagging
/// "wheelchair-friendly") is an accepted limitation, not handled specially.
class KeywordTaggingEngine {
  KeywordTaggingEngine._();

  static const Map<String, String> _keywordToTag = {
    'wheelchair': 'wheelchair-friendly',
    'stroller': 'stroller-friendly',
    'steep': 'steep terrain',
    'stairs': 'many stairs',
    'parking': 'parking available',
    'crowded': 'crowded',
    'family': 'family-friendly',
    'kids': 'family-friendly',
    'shade': 'shaded',
    'slippery': 'slippery when wet',
  };

  static List<String> tagsFor(String reviewText) {
    final lower = reviewText.toLowerCase();
    final tags = <String>[];
    for (final entry in _keywordToTag.entries) {
      if (lower.contains(entry.key) && !tags.contains(entry.value)) {
        tags.add(entry.value);
      }
    }
    return tags;
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/keyword_tagging_engine_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/202608060003_destination_ratings.sql lib/features/destination_exploration/model/keyword_tagging_engine.dart lib/features/destination_exploration/model/difficulty_bucket.dart test/keyword_tagging_engine_test.dart
git commit -m "feat(destination-ratings): add ratings/points/badges migration, KeywordTaggingEngine, DifficultyBucket"
```

---

### Task 2: Rating models and `DestinationRatingRepository`

**Files:**
- Create: `lib/features/destination_exploration/model/rating_summary.dart`
- Create: `lib/features/destination_exploration/model/destination_rating_repository.dart`
- Test: `test/destination_rating_repository_test.dart`

**Interfaces:**
- Consumes: `DifficultyBucket`, `difficultyBucketFor`, `KeywordTaggingEngine` (Task 1).
- Produces:
  - `class TagFrequency { final String tag; final double percentage; }`
  - `class RatingSummary { final DifficultyBucket difficultyBucket; final double avgDifficulty; final int ratingCount; final List<TagFrequency> topTags; }`
  - `class DestinationReview { final String reviewText; final int difficultyScore; final List<String> generatedTags; final DateTime createdAt; }`
  - `RatingSummary summarizeRatings(List<({int difficultyScore, List<String> tags})> ratings)` (pure, top-level).
  - `class DestinationRatingRepository { submitRating(...), fetchRatingSummary(...), fetchReviews(...); }`

- [ ] **Step 1: Write the models**

```dart
// lib/features/destination_exploration/model/rating_summary.dart
import 'difficulty_bucket.dart';

/// One badge's share of a destination's ratings (FR4.5) — e.g. "Shaded
/// Trail 84%" in the prepared UI.
class TagFrequency {
  final String tag;
  final double percentage;

  const TagFrequency({required this.tag, required this.percentage});

  @override
  bool operator ==(Object other) =>
      other is TagFrequency && other.tag == tag && other.percentage == percentage;

  @override
  int get hashCode => Object.hash(tag, percentage);
}

class RatingSummary {
  final DifficultyBucket difficultyBucket;
  final double avgDifficulty;
  final int ratingCount;
  final List<TagFrequency> topTags;

  const RatingSummary({
    required this.difficultyBucket,
    required this.avgDifficulty,
    required this.ratingCount,
    required this.topTags,
  });

  @override
  bool operator ==(Object other) =>
      other is RatingSummary &&
      other.difficultyBucket == difficultyBucket &&
      other.avgDifficulty == avgDifficulty &&
      other.ratingCount == ratingCount &&
      listsEqual(other.topTags, topTags);

  @override
  int get hashCode => Object.hash(difficultyBucket, avgDifficulty, ratingCount, Object.hashAll(topTags));
}

bool listsEqual(List<TagFrequency> a, List<TagFrequency> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One row of `destination_ratings`, for the Destination Detail page's
/// paginated review list.
class DestinationReview {
  final String reviewText;
  final int difficultyScore;
  final List<String> generatedTags;
  final DateTime createdAt;

  const DestinationReview({
    required this.reviewText,
    required this.difficultyScore,
    required this.generatedTags,
    required this.createdAt,
  });
}

/// Pure aggregation, separated from the Supabase-calling repository method
/// so it's unit-testable without a network call (same split as
/// DestinationExplorationRepository.mapRow in Feature 1).
RatingSummary summarizeRatings(List<({int difficultyScore, List<String> tags})> ratings) {
  if (ratings.isEmpty) {
    return const RatingSummary(
      difficultyBucket: DifficultyBucket.easy,
      avgDifficulty: 0,
      ratingCount: 0,
      topTags: [],
    );
  }

  final avgDifficulty =
      ratings.map((r) => r.difficultyScore).reduce((a, b) => a + b) / ratings.length;

  final tagCounts = <String, int>{};
  for (final rating in ratings) {
    for (final tag in rating.tags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  final sortedTags = tagCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topTags = sortedTags
      .take(5)
      .map((entry) => TagFrequency(
            tag: entry.key,
            percentage: entry.value / ratings.length * 100,
          ))
      .toList();

  return RatingSummary(
    difficultyBucket: difficultyBucketFor(avgDifficulty),
    avgDifficulty: avgDifficulty,
    ratingCount: ratings.length,
    topTags: topTags,
  );
}
```

- [ ] **Step 2: Write the failing repository test**

```dart
// test/destination_rating_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/model/difficulty_bucket.dart';
import 'package:collab/features/destination_exploration/model/rating_summary.dart';

void main() {
  group('summarizeRatings', () {
    test('returns an empty/zeroed summary for no ratings', () {
      final summary = summarizeRatings(const []);

      expect(summary.ratingCount, 0);
      expect(summary.avgDifficulty, 0);
      expect(summary.topTags, isEmpty);
    });

    test('averages difficulty into the correct bucket', () {
      final summary = summarizeRatings(const [
        (difficultyScore: 4, tags: <String>[]),
        (difficultyScore: 4, tags: <String>[]),
      ]);

      expect(summary.avgDifficulty, 4.0);
      expect(summary.difficultyBucket, DifficultyBucket.hard);
      expect(summary.ratingCount, 2);
    });

    test('computes tag percentages and keeps only the top 5, most-frequent first', () {
      final summary = summarizeRatings(const [
        (difficultyScore: 2, tags: ['shaded', 'family-friendly']),
        (difficultyScore: 2, tags: ['shaded']),
        (difficultyScore: 2, tags: ['shaded']),
        (difficultyScore: 2, tags: ['family-friendly']),
      ]);

      expect(summary.topTags.first.tag, 'shaded');
      expect(summary.topTags.first.percentage, closeTo(75, 0.01)); // 3 of 4
      expect(summary.topTags[1].tag, 'family-friendly');
      expect(summary.topTags[1].percentage, closeTo(50, 0.01)); // 2 of 4
    });

    test('a frequency tie keeps insertion/discovery order', () {
      final summary = summarizeRatings(const [
        (difficultyScore: 2, tags: ['alpha']),
        (difficultyScore: 2, tags: ['beta']),
      ]);

      expect(summary.topTags.map((t) => t.tag), ['alpha', 'beta']);
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/destination_rating_repository_test.dart`
Expected: FAIL — `summarizeRatings` doesn't exist yet (compile error).

- [ ] **Step 4: Write `DestinationRatingRepository`**

```dart
// lib/features/destination_exploration/model/destination_rating_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'keyword_tagging_engine.dart';
import 'rating_summary.dart';

/// Rating submission and aggregation for Feature 4. Submission computes
/// generated_tags via KeywordTaggingEngine (FR4.2, FR4.3); aggregation is
/// delegated to the pure summarizeRatings function above so it's testable
/// without a network call.
class DestinationRatingRepository {
  Future<void> submitRating({
    required String destinationId,
    required int difficultyScore,
    required String reviewText,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('A signed-in user is required.');
    }

    final tags = KeywordTaggingEngine.tagsFor(reviewText);
    await Supabase.instance.client.from('destination_ratings').insert({
      'destination_id': destinationId,
      'user_id': userId,
      'difficulty_score': difficultyScore,
      'review_text': reviewText,
      'generated_tags': tags,
    });
  }

  Future<RatingSummary> fetchRatingSummary(String destinationId) async {
    final rows = await Supabase.instance.client
        .from('destination_ratings')
        .select()
        .eq('destination_id', destinationId);

    final ratings = rows
        .map((row) => (
              difficultyScore: (row['difficulty_score'] as num).toInt(),
              tags: ((row['generated_tags'] as List?)?.whereType<String>().toList()) ??
                  const <String>[],
            ))
        .toList();

    return summarizeRatings(ratings);
  }

  Future<List<DestinationReview>> fetchReviews(
    String destinationId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await Supabase.instance.client
        .from('destination_ratings')
        .select()
        .eq('destination_id', destinationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows
        .map((row) => DestinationReview(
              reviewText: row['review_text'] as String,
              difficultyScore: (row['difficulty_score'] as num).toInt(),
              generatedTags:
                  ((row['generated_tags'] as List?)?.whereType<String>().toList()) ?? const [],
              createdAt: DateTime.parse(row['created_at'] as String),
            ))
        .toList();
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/destination_rating_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/destination_exploration/model/rating_summary.dart lib/features/destination_exploration/model/destination_rating_repository.dart test/destination_rating_repository_test.dart
git commit -m "feat(destination-ratings): add RatingSummary/TagFrequency/DestinationReview and DestinationRatingRepository"
```

---

### Task 3: `CheckInRepository` and `UserProgressRepository`

**Files:**
- Create: `lib/features/destination_exploration/model/check_in_repository.dart`
- Create: `lib/features/destination_exploration/model/user_progress_repository.dart`

**Interfaces:**
- Produces:
  - `class CheckInRepository { Future<bool> isCheckedIn(String destinationId); Future<void> checkIn(String destinationId); }`
  - `class UserProgressRepository { Future<int> awardPoints(int amount); Future<bool> awardPathfinderBadgeIfNew(String region); }`

No dedicated unit tests for this task — both classes are thin Supabase wrappers with no pure
logic to isolate (same rationale as Feature 1's `loadDestinations`); they're exercised
indirectly through `RatingController`'s tests in Task 4 via fakes.

- [ ] **Step 1: Write `CheckInRepository`**

```dart
// lib/features/destination_exploration/model/check_in_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal, standalone check-in gate for Feature 4 — not the full
/// gamification_journal check-in experience (see the design spec's
/// Decisions). Scoped to the signed-in user, same pattern as
/// emergency_contact_repository.dart.
class CheckInRepository {
  String get _userId {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw const AuthException('A signed-in user is required.');
    return user.id;
  }

  Future<bool> isCheckedIn(String destinationId) async {
    final rows = await Supabase.instance.client
        .from('destination_checkins')
        .select()
        .eq('user_id', _userId)
        .eq('destination_id', destinationId);
    return rows.isNotEmpty;
  }

  /// Idempotent — checking in twice is a no-op, not an error.
  Future<void> checkIn(String destinationId) async {
    await Supabase.instance.client.from('destination_checkins').upsert({
      'user_id': _userId,
      'destination_id': destinationId,
    });
  }
}
```

- [ ] **Step 2: Write `UserProgressRepository`**

```dart
// lib/features/destination_exploration/model/user_progress_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// A minimal points/badge hook for the rating-submission flow only — not
/// the broader gamification_journal system (see the design spec's
/// Decisions). One badge type ('pathfinder'), unlocked once per region.
class UserProgressRepository {
  String get _userId {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw const AuthException('A signed-in user is required.');
    return user.id;
  }

  Future<int> awardPoints(int amount) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('user_trail_points')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    final newTotal = ((existing?['total_points'] as num?)?.toInt() ?? 0) + amount;
    await client.from('user_trail_points').upsert({
      'user_id': _userId,
      'total_points': newTotal,
    });
    return newTotal;
  }

  Future<bool> awardPathfinderBadgeIfNew(String region) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('user_badges')
        .select()
        .eq('user_id', _userId)
        .eq('badge_id', 'pathfinder')
        .eq('region', region)
        .maybeSingle();

    if (existing != null) return false;

    await client.from('user_badges').insert({
      'user_id': _userId,
      'badge_id': 'pathfinder',
      'region': region,
    });
    return true;
  }
}
```

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`
Expected: no new errors (there are no tests to run for this task).

- [ ] **Step 4: Commit**

```bash
git add lib/features/destination_exploration/model/check_in_repository.dart lib/features/destination_exploration/model/user_progress_repository.dart
git commit -m "feat(destination-ratings): add CheckInRepository and UserProgressRepository"
```

---

### Task 4: `RatingController`

**Files:**
- Create: `lib/features/destination_exploration/controller/rating_controller.dart`
- Test: `test/rating_controller_test.dart`

**Interfaces:**
- Consumes: `CheckInRepository`, `DestinationRatingRepository`, `UserProgressRepository`
  (Tasks 2–3); `RatingSummary` (Task 2).
- Produces: `class RatingController extends ChangeNotifier` with `isCheckedIn`,
  `isSubmitting`, `error`, `pointsAwarded`, `pathfinderBadgeUnlocked`, `summary`,
  `checkIn(String destinationId)`, `submitRating({required destinationId, required region, required difficultyScore, required reviewText})`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/rating_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/features/destination_exploration/controller/rating_controller.dart';
import 'package:collab/features/destination_exploration/model/check_in_repository.dart';
import 'package:collab/features/destination_exploration/model/destination_rating_repository.dart';
import 'package:collab/features/destination_exploration/model/difficulty_bucket.dart';
import 'package:collab/features/destination_exploration/model/rating_summary.dart';
import 'package:collab/features/destination_exploration/model/user_progress_repository.dart';

class _FakeCheckInRepository extends CheckInRepository {
  @override
  Future<void> checkIn(String destinationId) async {}
}

class _FakeRatingRepository extends DestinationRatingRepository {
  _FakeRatingRepository({this.throwOnSubmit = false, this.summaryResult});
  final bool throwOnSubmit;
  final RatingSummary? summaryResult;

  @override
  Future<void> submitRating({
    required String destinationId,
    required int difficultyScore,
    required String reviewText,
  }) async {
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

void main() {
  group('RatingController', () {
    test('submitRating blocks with an error when not checked in', () async {
      final controller = RatingController(
        checkInRepository: _FakeCheckInRepository(),
        ratingRepository: _FakeRatingRepository(),
        progressRepository: _FakeProgressRepository(),
      );

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
      );

      expect(controller.error, 'A verified check-in is required to submit a rating.');
    });

    test('checkIn flips isCheckedIn to true', () async {
      final controller = RatingController(checkInRepository: _FakeCheckInRepository());

      await controller.checkIn('d1');

      expect(controller.isCheckedIn, isTrue);
    });

    test('submitRating succeeds, refreshes the summary, and awards points/badge when checked in', () async {
      const summary = RatingSummary(
        difficultyBucket: DifficultyBucket.moderate,
        avgDifficulty: 3.0,
        ratingCount: 1,
        topTags: [],
      );
      final controller = RatingController(
        checkInRepository: _FakeCheckInRepository(),
        ratingRepository: _FakeRatingRepository(summaryResult: summary),
        progressRepository: _FakeProgressRepository(points: 15, badgeUnlocked: true),
      );
      await controller.checkIn('d1');

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
      );

      expect(controller.error, isNull);
      expect(controller.summary, summary);
      expect(controller.pointsAwarded, 15);
      expect(controller.pathfinderBadgeUnlocked, isTrue);
    });

    test('a second contribution in the same region does not re-unlock the badge', () async {
      final controller = RatingController(
        checkInRepository: _FakeCheckInRepository(),
        ratingRepository: _FakeRatingRepository(),
        progressRepository: _FakeProgressRepository(badgeUnlocked: false),
      );
      await controller.checkIn('d1');

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
      );

      expect(controller.pathfinderBadgeUnlocked, isFalse);
    });

    test('a points/badge failure does not roll back the rating submission', () async {
      final controller = RatingController(
        checkInRepository: _FakeCheckInRepository(),
        ratingRepository: _FakeRatingRepository(),
        progressRepository: _FakeProgressRepository(throwOnAward: true),
      );
      await controller.checkIn('d1');

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
      );

      expect(controller.error, isNull);
      expect(controller.pointsAwarded, isNull);
      expect(controller.pathfinderBadgeUnlocked, isFalse);
    });

    test('a rating submission failure sets error and does not award points', () async {
      final controller = RatingController(
        checkInRepository: _FakeCheckInRepository(),
        ratingRepository: _FakeRatingRepository(throwOnSubmit: true),
        progressRepository: _FakeProgressRepository(),
      );
      await controller.checkIn('d1');

      await controller.submitRating(
        destinationId: 'd1',
        region: 'George Town',
        difficultyScore: 3,
        reviewText: 'Nice place',
      );

      expect(controller.error, isNotNull);
      expect(controller.pointsAwarded, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/rating_controller_test.dart`
Expected: FAIL — `RatingController` doesn't exist yet (compile error).

- [ ] **Step 3: Write `RatingController`**

```dart
// lib/features/destination_exploration/controller/rating_controller.dart
import 'package:flutter/foundation.dart';

import '../model/check_in_repository.dart';
import '../model/destination_rating_repository.dart';
import '../model/rating_summary.dart';
import '../model/user_progress_repository.dart';

/// Business logic for check-in-gated rating submission (Feature 4). Kept as
/// a plain ChangeNotifier per the module's MVC convention.
class RatingController extends ChangeNotifier {
  RatingController({
    CheckInRepository? checkInRepository,
    DestinationRatingRepository? ratingRepository,
    UserProgressRepository? progressRepository,
  })  : _checkInRepository = checkInRepository ?? CheckInRepository(),
        _ratingRepository = ratingRepository ?? DestinationRatingRepository(),
        _progressRepository = progressRepository ?? UserProgressRepository();

  final CheckInRepository _checkInRepository;
  final DestinationRatingRepository _ratingRepository;
  final UserProgressRepository _progressRepository;

  static const int pointsPerContribution = 15;

  bool isCheckedIn = false;
  bool isSubmitting = false;
  String? error;
  int? pointsAwarded;
  bool pathfinderBadgeUnlocked = false;
  RatingSummary? summary;

  Future<void> checkIn(String destinationId) async {
    await _checkInRepository.checkIn(destinationId);
    isCheckedIn = true;
    notifyListeners();
  }

  /// Blocks with [error] set if [isCheckedIn] is false (E2), without calling
  /// any repository. Otherwise submits the rating, refreshes [summary], then
  /// awards points/a badge — a failure in that last step does not roll back
  /// the already-successful rating submission (it degrades gracefully:
  /// [pointsAwarded] stays null, [error] stays null).
  Future<void> submitRating({
    required String destinationId,
    required String region,
    required int difficultyScore,
    required String reviewText,
  }) async {
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
    } catch (_) {
      error = "Couldn't submit your rating right now.";
      isSubmitting = false;
      notifyListeners();
      return;
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

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/rating_controller_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — every test across all four features passes.

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze`
Expected: no new errors or warnings.

- [ ] **Step 7: Commit**

```bash
git add lib/features/destination_exploration/controller/rating_controller.dart test/rating_controller_test.dart
git commit -m "feat(destination-ratings): add RatingController"
```

---

## Self-Review Notes

**Spec coverage:**
- FR4.1 (optional rating form: difficulty slider + free text) — Task 4 `submitRating`'s
  parameters (form itself not built, per View scope decision).
- FR4.2 (stores destination ID, user ID, difficulty, tags, review, timestamp) — Task 2's
  migration + `submitRating` insert.
- FR4.3 (keyword-matching pipeline generates tags) — Task 1 `KeywordTaggingEngine`.
- FR4.4 (aggregate + bucket) — Task 1 `difficultyBucketFor`, Task 2 `summarizeRatings`.
- FR4.5 (top tags as badges) — Task 2 `summarizeRatings`'s `topTags`; Destination Detail page
  contract documented in the spec (not built here).
- FR4.6 (gated behind verified check-in) — Task 4 `submitRating`'s guard.
- Use case A1 (skip prompt) — no controller method needed, documented in spec.
- Use case E1 (ambiguous tagging) — accepted, `KeywordTaggingEngine` test suite documents the
  keyword-only behavior rather than working around it.
- Use case E2 (no check-in) — Task 4's guard clause + test.
- Use case E3 (no moderation) — explicitly out of scope, no code.
- Revised points/badges — Task 3 `UserProgressRepository`, Task 4's award calls + tests
  (including the "already unlocked" and "award failure" cases).
- Revised Destination Detail page support — Task 2's `fetchReviews` + `TagFrequency`
  percentages.

**Placeholder scan:** no TBD/TODO, no undefined references — checked.

**Type consistency:** `RatingSummary`, `TagFrequency`, `DestinationReview`, and
`RatingController`'s member names match identically across Tasks 2 and 4 — checked.
