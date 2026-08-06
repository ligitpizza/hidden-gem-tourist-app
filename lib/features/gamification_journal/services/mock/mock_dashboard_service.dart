import '../../model/badge_model.dart';
import '../../model/check_in_model.dart';
import '../../model/destination_model.dart';
import '../../model/journal_entry_model.dart';
import '../../model/user_badge_model.dart';
import '../../model/user_stats_model.dart';

/// Phase 1 mock implementation of the personal statistics dashboard.
///
/// computeStats() is a pure aggregation over data already held by
/// CheckInController, BadgeController, and JournalController. In Phase 2
/// this becomes a single query against a Supabase database view instead
/// of client-side aggregation, but the returned UserStatsModel shape
/// stays the same so DashboardController and its views don't change.
class MockDashboardService {
  Future<UserStatsModel> computeStats({
    required List<CheckInModel> checkIns,
    required Map<String, DestinationModel> destinationsById,
    required List<UserBadgeModel> userBadges,
    required List<BadgeModel> allBadges,
    required List<JournalEntryModel> journalEntries,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final statesExplored = checkIns
        .map((c) => destinationsById[c.destinationId]?.state)
        .whereType<String>()
        .toSet()
        .length;

    final categoryBreakdown = <String, int>{};
    for (final checkIn in checkIns) {
      final category = destinationsById[checkIn.destinationId]?.category;
      if (category == null) continue;
      categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
    }

    final economicImpactByOption = <LocalSupportOption, double>{
      for (final option in LocalSupportOption.values) option: 0,
    };

    // Each entry now logs an exact amount per category, so this is a
    // direct sum — no more splitting a single total evenly.
    for (final entry in journalEntries) {
      for (final MapEntry(key: option, value: amount)
          in entry.spendingByCategory.entries) {
        if (amount <= 0) continue;
        economicImpactByOption[option] =
            (economicImpactByOption[option] ?? 0) + amount;
      }
    }

    final totalImpact = economicImpactByOption.values.fold<double>(
      0,
      (a, b) => a + b,
    );

    final breakdown =
        economicImpactByOption.entries
            .where((e) => e.value > 0)
            .map(
              (e) => EconomicImpactSlice(
                option: e.key,
                amountRM: e.value,
                percentageOfTotal: totalImpact == 0
                    ? 0
                    : (e.value / totalImpact) * 100,
              ),
            )
            .toList()
          ..sort((a, b) => b.amountRM.compareTo(a.amountRM));

    return UserStatsModel(
      totalCheckIns: checkIns.length,
      statesExplored: statesExplored,
      totalMalaysianRegions: 13,
      badgesEarned: userBadges.length,
      badgesAvailable: allBadges.length,
      categoryBreakdown: categoryBreakdown,
      economicImpactTotalRM: totalImpact,
      economicImpactBreakdown: breakdown,
    );
  }
}
