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
