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
  }) async {
    newlyEarned = await _service.evaluateAndUnlockBadges(
      userId: userId,
      checkIns: checkIns,
      destinationsById: destinationsById,
      quizzesCompleted: quizzesCompleted,
    );
    _userBadges = await _service.fetchUserBadges(userId);
    _progress = await _service.computeProgress(
      userId: userId,
      checkIns: checkIns,
      destinationsById: destinationsById,
      quizzesCompleted: quizzesCompleted,
    );
    notifyListeners();
  }

  /// Alias for calling the same evaluation after a quiz is completed,
  /// rather than after a check-in — same underlying logic either way.
  Future<void> evaluateAfterQuiz({
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    required int quizzesCompleted,
  }) => evaluateAfterCheckIn(
    checkIns: checkIns,
    destinationsById: destinationsById,
    quizzesCompleted: quizzesCompleted,
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
}
