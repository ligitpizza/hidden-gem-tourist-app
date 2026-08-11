import 'package:flutter/foundation.dart';

import '../model/badge_model.dart';
import '../model/check_in_model.dart';
import '../model/destination_model.dart';
import '../model/user_badge_model.dart';
import '../services/mock/mock_badge_service.dart';

class BadgeController extends ChangeNotifier {
  BadgeController({required this.userId, MockBadgeService? service})
    : _service = service ?? MockBadgeService();

  final String userId;
  final MockBadgeService _service;

  List<BadgeModel> _allBadges = [];
  List<UserBadgeModel> _userBadges = [];
  List<BadgeProgressModel> _progress = [];

  /// Populated right after evaluateAfterCheckIn()/evaluateAfterQuiz(); the
  /// view watches this to trigger a toast, then should call
  /// clearNewlyEarned().
  List<BadgeModel> newlyEarned = [];

  List<BadgeModel> get allBadges => _allBadges;
  List<UserBadgeModel> get userBadges => _userBadges;
  List<BadgeProgressModel> get progress => _progress;

  bool isUnlocked(String badgeId) =>
      _userBadges.any((ub) => ub.badgeId == badgeId);

  /// Drives the "new badge" mark on the Badges card/tile — true whenever
  /// there's at least one unlocked badge the Tourist hasn't opened the
  /// gallery to see yet.
  bool get hasUnviewedBadges => _userBadges.any((ub) => !ub.acknowledged);

  /// Call when the Badge Gallery is opened so the mark clears.
  Future<void> acknowledgeAll() async {
    if (!hasUnviewedBadges) return;
    await _service.acknowledgeAll(userId);
    _userBadges = await _service.fetchUserBadges(userId);
    notifyListeners();
  }

  Future<void> loadBadges() async {
    _allBadges = await _service.fetchAllBadges();
    _userBadges = await _service.fetchUserBadges(userId);
    notifyListeners();
  }

  /// Call this after CheckInController.checkIn() succeeds, passing the
  /// updated check-in history and a lookup of destinations by id (from
  /// CheckInController.destinations).
  Future<void> evaluateAfterCheckIn({
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    int quizzesCompleted = 0,
    double economicImpactTotalRM = 0,
    int perfectQuizCount = 0,
  }) async {
    newlyEarned = await _service.evaluateAndUnlockBadges(
      userId: userId,
      checkIns: checkIns,
      destinationsById: destinationsById,
      quizzesCompleted: quizzesCompleted,
      economicImpactTotalRM: economicImpactTotalRM,
      perfectQuizCount: perfectQuizCount,
    );
    _userBadges = await _service.fetchUserBadges(userId);
    _progress = await _service.computeProgress(
      userId: userId,
      checkIns: checkIns,
      destinationsById: destinationsById,
      quizzesCompleted: quizzesCompleted,
      economicImpactTotalRM: economicImpactTotalRM,
      perfectQuizCount: perfectQuizCount,
    );
    notifyListeners();
  }

  /// Alias for calling the same evaluation after a quiz is completed,
  /// rather than after a check-in — same underlying logic either way.
  Future<void> evaluateAfterQuiz({
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    required int quizzesCompleted,
    double economicImpactTotalRM = 0,
    int perfectQuizCount = 0,
  }) => evaluateAfterCheckIn(
    checkIns: checkIns,
    destinationsById: destinationsById,
    quizzesCompleted: quizzesCompleted,
    economicImpactTotalRM: economicImpactTotalRM,
    perfectQuizCount: perfectQuizCount,
  );

  void clearNewlyEarned() {
    newlyEarned = [];
    notifyListeners();
  }

  Future<void> setHidden(String badgeId, bool isHidden) async {
    await _service.setHidden(
      userId: userId,
      badgeId: badgeId,
      isHidden: isHidden,
    );
    _userBadges = await _service.fetchUserBadges(userId);
    notifyListeners();
  }

  static const maxPinnedBadges = 3;

  List<BadgeModel> get pinnedBadges {
    final pinnedIds = _userBadges.where((ub) => ub.isPinned).map((ub) => ub.badgeId).toSet();
    return _allBadges.where((b) => pinnedIds.contains(b.id)).toList();
  }

  bool isPinned(String badgeId) =>
      _userBadges.any((ub) => ub.badgeId == badgeId && ub.isPinned);

  /// Toggles whether a badge is featured on the profile share card.
  /// Returns false (no-op) if pinning a 4th badge was rejected, so the
  /// caller can show a "remove one first" message.
  Future<bool> togglePinned(String badgeId) async {
    final currentlyPinned = isPinned(badgeId);
    if (!currentlyPinned && pinnedBadges.length >= maxPinnedBadges) {
      return false;
    }
    await _service.setPinned(
      userId: userId,
      badgeId: badgeId,
      isPinned: !currentlyPinned,
    );
    _userBadges = await _service.fetchUserBadges(userId);
    notifyListeners();
    return true;
  }
}
