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
