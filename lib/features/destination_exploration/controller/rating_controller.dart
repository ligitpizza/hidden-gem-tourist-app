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
    try {
      await _checkInRepository.checkIn(destinationId);
      isCheckedIn = true;
    } catch (_) {
      error = "Couldn't check you in right now.";
    }
    notifyListeners();
  }

  /// Hydrates [isCheckedIn] from a previous session's check-in, if any.
  /// Meant to be called by the View on page load. Failures are silent —
  /// [isCheckedIn] simply stays false, same as an unchecked-in user.
  Future<void> loadCheckInStatus(String destinationId) async {
    try {
      isCheckedIn = await _checkInRepository.isCheckedIn(destinationId);
      notifyListeners();
    } catch (_) {
      // Leave isCheckedIn as false; don't crash a background hydration call.
    }
  }

  /// Blocks with [error] set if [isCheckedIn] is false (E2), without calling
  /// any repository. Otherwise submits the rating, refreshes [summary], then
  /// awards points/a badge — a failure in that last step does not roll back
  /// the already-successful rating submission (it degrades gracefully:
  /// [pointsAwarded] stays null, [error] stays null).
  ///
  /// Reentrancy guard: overlapping calls return immediately as no-op to prevent
  /// duplicate submissions (e.g. user double-tapping submit button).
  Future<void> submitRating({
    required String destinationId,
    required String region,
    required int difficultyScore,
    required String reviewText,
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
