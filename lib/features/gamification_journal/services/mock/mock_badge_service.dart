import '../../model/badge_model.dart';
import '../../model/check_in_model.dart';
import '../../model/destination_model.dart';
import '../../model/user_badge_model.dart';

/// Phase 1 mock implementation of the badge system.
///
/// evaluateAndUnlockBadges() stands in for the Supabase trigger described
/// in the doc: "PostgreSQL database triggers automatically recalculate
/// user milestones upon successful check-ins." In Phase 2 this becomes a
/// realtime listener on the EarnedBadges table instead of a manual call.
class MockBadgeService {
  final List<UserBadgeModel> _userBadges = [];

  final List<BadgeModel> catalogue = [
    BadgeModel(
      id: 'b001',
      name: 'First Steps',
      description: 'Complete your first check-in.',
      iconFilename: 'first_steps.png',
      criteriaType: BadgeCriteriaType.totalCheckIns,
      threshold: 1,
    ),
    BadgeModel(
      id: 'b002',
      name: 'Explorer',
      description: 'Check in at 10 different hidden gems.',
      iconFilename: 'explorer.png',
      criteriaType: BadgeCriteriaType.totalCheckIns,
      threshold: 10,
    ),
    BadgeModel(
      id: 'b003',
      name: 'Nature Lover',
      description: 'Visit 5 nature spots.',
      iconFilename: 'nature_lover.png',
      criteriaType: BadgeCriteriaType.categoryCount,
      threshold: 5,
      targetValue: 'Nature',
    ),
    BadgeModel(
      id: 'b004',
      name: 'Culture Seeker',
      description: 'Visit 3 culture spots.',
      iconFilename: 'culture_seeker.png',
      criteriaType: BadgeCriteriaType.categoryCount,
      threshold: 3,
      targetValue: 'Culture',
    ),
    BadgeModel(
      id: 'b005',
      name: 'Foodie Trail',
      description: 'Visit 3 food destinations.',
      iconFilename: 'foodie_trail.png',
      criteriaType: BadgeCriteriaType.categoryCount,
      threshold: 3,
      targetValue: 'Food',
    ),
    BadgeModel(
      id: 'b006',
      name: 'Perak Wanderer',
      description: 'Check in at 3 destinations in Perak.',
      iconFilename: 'perak_wanderer.png',
      criteriaType: BadgeCriteriaType.stateVisit,
      threshold: 3,
      targetValue: 'Perak',
    ),
    BadgeModel(
      id: 'b007',
      name: 'Quiz Beginner',
      description: 'Complete 5 cultural quizzes.',
      iconFilename: 'quiz_beginner.png',
      criteriaType: BadgeCriteriaType.quizzesCompleted,
      threshold: 5,
    ),
    BadgeModel(
      id: 'b008',
      name: 'Quiz Intermediate',
      description: 'Complete 15 cultural quizzes.',
      iconFilename: 'quiz_intermediate.png',
      criteriaType: BadgeCriteriaType.quizzesCompleted,
      threshold: 15,
    ),
  ];

  Future<List<BadgeModel>> fetchAllBadges() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return catalogue;
  }

  Future<List<UserBadgeModel>> fetchUserBadges(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _userBadges.where((ub) => ub.userId == userId).toList();
  }

  /// Counts how many check-ins (or quizzes) satisfy a badge's criteria.
  int _countForCriteria(
    BadgeModel badge,
    List<CheckInModel> checkIns,
    Map<String, DestinationModel> destinationsById,
    int quizzesCompleted,
  ) {
    switch (badge.criteriaType) {
      case BadgeCriteriaType.totalCheckIns:
        return checkIns.length;
      case BadgeCriteriaType.categoryCount:
        return checkIns
            .where(
              (c) =>
                  destinationsById[c.destinationId]?.category ==
                  badge.targetValue,
            )
            .length;
      case BadgeCriteriaType.stateVisit:
        return checkIns
            .where(
              (c) =>
                  destinationsById[c.destinationId]?.state == badge.targetValue,
            )
            .length;
      case BadgeCriteriaType.quizzesCompleted:
        return quizzesCompleted;
    }
  }

  /// Returns progress for every locked badge, e.g. "3 of 5 spots visited".
  Future<List<BadgeProgressModel>> computeProgress({
    required String userId,
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    int quizzesCompleted = 0,
  }) async {
    final earnedIds = _userBadges
        .where((ub) => ub.userId == userId)
        .map((ub) => ub.badgeId)
        .toSet();

    return catalogue
        .where((b) => !earnedIds.contains(b.id))
        .map(
          (b) => BadgeProgressModel(
            badgeId: b.id,
            current: _countForCriteria(
              b,
              checkIns,
              destinationsById,
              quizzesCompleted,
            ),
            target: b.threshold,
          ),
        )
        .toList();
  }

  /// Re-evaluates all badges after a check-in and unlocks any that now
  /// qualify. Returns only the newly earned badges so the caller can show
  /// a toast notification, matching the "instant toast" behaviour in the doc.
  Future<List<BadgeModel>> evaluateAndUnlockBadges({
    required String userId,
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    int quizzesCompleted = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final earnedIds = _userBadges
        .where((ub) => ub.userId == userId)
        .map((ub) => ub.badgeId)
        .toSet();

    final newlyEarned = <BadgeModel>[];

    for (final badge in catalogue) {
      if (earnedIds.contains(badge.id)) continue;
      final count = _countForCriteria(
        badge,
        checkIns,
        destinationsById,
        quizzesCompleted,
      );
      if (count >= badge.threshold) {
        _userBadges.add(
          UserBadgeModel(
            userId: userId,
            badgeId: badge.id,
            earnedAt: DateTime.now(),
          ),
        );
        newlyEarned.add(badge);
      }
    }

    return newlyEarned;
  }

  Future<void> setHidden({
    required String userId,
    required String badgeId,
    required bool isHidden,
  }) async {
    final index = _userBadges.indexWhere(
      (ub) => ub.userId == userId && ub.badgeId == badgeId,
    );
    if (index == -1) return;
    _userBadges[index] = _userBadges[index].copyWith(isHidden: isHidden);
  }
}
