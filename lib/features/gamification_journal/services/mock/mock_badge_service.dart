import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/badge_model.dart';
import '../../model/check_in_model.dart';
import '../../model/destination_model.dart';
import '../../model/user_badge_model.dart';

/// Phase 1 mock implementation of the badge system.
///
/// The badge catalogue is shared reference content, so it's loaded from
/// the real Supabase `journal_badges` table and cached in memory (same
/// pattern as MockCheckInService's destination cache), unless pre-seeded
/// via the constructor (used by tests to avoid a real Supabase call).
///
/// evaluateAndUnlockBadges() stands in for the Supabase trigger described
/// in the doc: "PostgreSQL database triggers automatically recalculate
/// user milestones upon successful check-ins." In Phase 2 this becomes a
/// realtime listener on the EarnedBadges table instead of a manual call.
class MockBadgeService {
  MockBadgeService({List<BadgeModel>? seedCatalogue})
      : catalogue = seedCatalogue ?? [],
        _catalogueLoaded = seedCatalogue != null;

  final List<UserBadgeModel> _userBadges = [];

  List<BadgeModel> catalogue;
  bool _catalogueLoaded;

  Future<void> _ensureCatalogueLoaded() async {
    if (_catalogueLoaded) return;
    try {
      final rows = await Supabase.instance.client.from('journal_badges').select();
      catalogue = rows.map((row) => BadgeModel.fromJson(row)).toList();
      _catalogueLoaded = true;
    } catch (_) {
      // Leave catalogue empty and _catalogueLoaded false so a later call
      // can retry instead of permanently caching a failure.
    }
  }

  Future<List<BadgeModel>> fetchAllBadges() async {
    await _ensureCatalogueLoaded();
    return catalogue;
  }

  Future<List<UserBadgeModel>> fetchUserBadges(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _userBadges.where((ub) => ub.userId == userId).toList();
  }

  /// Counts how many check-ins (or quizzes, or RM) satisfy a badge's criteria.
  int _countForCriteria(
    BadgeModel badge,
    List<CheckInModel> checkIns,
    Map<String, DestinationModel> destinationsById,
    int quizzesCompleted,
    double economicImpactTotalRM,
    int perfectQuizCount,
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
      case BadgeCriteriaType.economicImpactRM:
        return economicImpactTotalRM.floor();
      case BadgeCriteriaType.quizPerfectScore:
        return perfectQuizCount;
    }
  }

  /// Returns progress for every locked badge, e.g. "3 of 5 spots visited".
  Future<List<BadgeProgressModel>> computeProgress({
    required String userId,
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    int quizzesCompleted = 0,
    double economicImpactTotalRM = 0,
    int perfectQuizCount = 0,
  }) async {
    await _ensureCatalogueLoaded();

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
              economicImpactTotalRM,
              perfectQuizCount,
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
    double economicImpactTotalRM = 0,
    int perfectQuizCount = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _ensureCatalogueLoaded();

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
        economicImpactTotalRM,
        perfectQuizCount,
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
