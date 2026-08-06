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
