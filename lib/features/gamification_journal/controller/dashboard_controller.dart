import 'package:flutter/foundation.dart';

import '../model/badge_model.dart';
import '../model/check_in_model.dart';
import '../model/destination_model.dart';
import '../model/journal_entry_model.dart';
import '../model/user_badge_model.dart';
import '../model/user_stats_model.dart';
import '../services/mock/mock_dashboard_service.dart';

enum DashboardStatus { idle, loading, error }

/// Unlike the other controllers, DashboardController doesn't own its data —
/// it reads the current snapshot from CheckInController, BadgeController,
/// and JournalController and asks the service to aggregate it. Call
/// refresh() whenever the dashboard screen becomes visible, or after any
/// check-in completes if you want live numbers.
class DashboardController extends ChangeNotifier {
  DashboardController({MockDashboardService? service})
    : _service = service ?? MockDashboardService();

  final MockDashboardService _service;

  UserStatsModel stats = UserStatsModel.empty();
  DashboardStatus status = DashboardStatus.idle;
  String? errorMessage;

  Future<void> refresh({
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    required List<UserBadgeModel> userBadges,
    required List<BadgeModel> allBadges,
    required List<JournalEntryModel> journalEntries,
  }) async {
    status = DashboardStatus.loading;
    notifyListeners();

    try {
      stats = await _service.computeStats(
        checkIns: checkIns,
        destinationsById: destinationsById,
        userBadges: userBadges,
        allBadges: allBadges,
        journalEntries: journalEntries,
      );
      status = DashboardStatus.idle;
    } catch (_) {
      status = DashboardStatus.error;
      errorMessage = 'Could not load your stats. Please try again.';
    }

    notifyListeners();
  }
}
