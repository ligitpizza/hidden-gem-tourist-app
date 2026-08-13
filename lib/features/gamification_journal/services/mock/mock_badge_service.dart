import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/badge_model.dart';
import '../../model/check_in_model.dart';
import '../../model/destination_model.dart';
import '../../model/user_badge_model.dart';

/// The badge catalogue is shared reference content, loaded from the real
/// Supabase `journal_badges` table and cached in memory (same pattern as
/// MockCheckInService's destination cache), unless pre-seeded via the
/// constructor (used by tests to avoid a real Supabase call).
///
/// Which badges a *user* has earned is backed by the real
/// `journal_user_badges` table (see
/// supabase/migrations/20260813120000_journal_real_activity_and_friends.sql)
/// — a friend's accepted friendship grants them read access there, which is
/// what makes the Friends activity feed and the badge-share-card feature
/// possible. [seedUserBadges] — even an empty list — switches earned-badge
/// storage to a plain in-memory store for tests, same switch [seedCatalogue]
/// already does for the catalogue.
///
/// evaluateAndUnlockBadges() stands in for the Supabase trigger described
/// in the doc: "PostgreSQL database triggers automatically recalculate
/// user milestones upon successful check-ins." In Phase 2 this becomes a
/// realtime listener on the EarnedBadges table instead of a manual call.
class MockBadgeService {
  MockBadgeService({
    List<BadgeModel>? seedCatalogue,
    List<UserBadgeModel>? seedUserBadges,
  }) : catalogue = seedCatalogue ?? [],
       _catalogueLoaded = seedCatalogue != null,
       // A defensive growable copy — callers (tests) may pass a `const
       // []`, which this service then needs to append to.
       _userBadges = List.of(seedUserBadges ?? []),
       _useMockStorage = seedUserBadges != null;

  final List<UserBadgeModel> _userBadges;
  final bool _useMockStorage;

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
    if (_useMockStorage) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _userBadges.where((ub) => ub.userId == userId).toList();
    }
    final rows = await Supabase.instance.client
        .from('journal_user_badges')
        .select()
        .eq('user_id', userId);
    return rows.map((r) => UserBadgeModel.fromJson(r)).toList();
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
    final earnedIds = (await fetchUserBadges(userId)).map((ub) => ub.badgeId).toSet();

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
    final earnedIds = (await fetchUserBadges(userId)).map((ub) => ub.badgeId).toSet();

    final newlyEarned = <BadgeModel>[];
    final newlyEarnedRows = <UserBadgeModel>[];

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
        newlyEarned.add(badge);
        newlyEarnedRows.add(
          UserBadgeModel(userId: userId, badgeId: badge.id, earnedAt: DateTime.now()),
        );
      }
    }

    if (newlyEarnedRows.isEmpty) return newlyEarned;

    if (_useMockStorage) {
      _userBadges.addAll(newlyEarnedRows);
    } else {
      await Supabase.instance.client
          .from('journal_user_badges')
          .insert(newlyEarnedRows.map((ub) => ub.toJson()).toList());
    }

    return newlyEarned;
  }

  Future<void> setHidden({
    required String userId,
    required String badgeId,
    required bool isHidden,
  }) async {
    if (_useMockStorage) {
      final index = _userBadges.indexWhere(
        (ub) => ub.userId == userId && ub.badgeId == badgeId,
      );
      if (index == -1) return;
      _userBadges[index] = _userBadges[index].copyWith(isHidden: isHidden);
      return;
    }
    await Supabase.instance.client
        .from('journal_user_badges')
        .update({'is_hidden': isHidden})
        .eq('user_id', userId)
        .eq('badge_id', badgeId);
  }

  Future<void> setPinned({
    required String userId,
    required String badgeId,
    required bool isPinned,
  }) async {
    if (_useMockStorage) {
      final index = _userBadges.indexWhere(
        (ub) => ub.userId == userId && ub.badgeId == badgeId,
      );
      if (index == -1) return;
      _userBadges[index] = _userBadges[index].copyWith(isPinned: isPinned);
      return;
    }
    await Supabase.instance.client
        .from('journal_user_badges')
        .update({'is_pinned': isPinned})
        .eq('user_id', userId)
        .eq('badge_id', badgeId);
  }

  /// Marks every currently-earned badge as seen — called when the Tourist
  /// opens the Badge Gallery, clearing the "new badge" mark.
  Future<void> acknowledgeAll(String userId) async {
    if (_useMockStorage) {
      for (var i = 0; i < _userBadges.length; i++) {
        if (_userBadges[i].userId == userId && !_userBadges[i].acknowledged) {
          _userBadges[i] = _userBadges[i].copyWith(acknowledged: true);
        }
      }
      return;
    }
    await Supabase.instance.client
        .from('journal_user_badges')
        .update({'acknowledged': true})
        .eq('user_id', userId)
        .eq('acknowledged', false);
  }
}
