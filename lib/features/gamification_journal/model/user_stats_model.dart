import 'journal_entry_model.dart';

/// One slice of the "Local Economy Support Tracker" pie chart.
class EconomicImpactSlice {
  final LocalSupportOption option;
  final double amountRM;
  final double percentageOfTotal;

  EconomicImpactSlice({
    required this.option,
    required this.amountRM,
    required this.percentageOfTotal,
  });
}

class UserStatsModel {
  final int totalCheckIns;
  final int statesExplored;
  final int totalMalaysianRegions;
  final int badgesEarned;
  final int badgesAvailable;

  /// e.g. {"Nature": 4, "Food": 2, "Culture": 1}
  final Map<String, int> categoryBreakdown;

  final double economicImpactTotalRM;
  final List<EconomicImpactSlice> economicImpactBreakdown;

  UserStatsModel({
    required this.totalCheckIns,
    required this.statesExplored,
    required this.totalMalaysianRegions,
    required this.badgesEarned,
    required this.badgesAvailable,
    required this.categoryBreakdown,
    required this.economicImpactTotalRM,
    required this.economicImpactBreakdown,
  });

  factory UserStatsModel.empty() {
    return UserStatsModel(
      totalCheckIns: 0,
      statesExplored: 0,
      // Malaysia has 13 states (federal territories aren't counted here).
      totalMalaysianRegions: 13,
      badgesEarned: 0,
      badgesAvailable: 0,
      categoryBreakdown: const {},
      economicImpactTotalRM: 0,
      economicImpactBreakdown: const [],
    );
  }
}
