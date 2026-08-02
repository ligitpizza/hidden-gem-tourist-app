/// How long the traveller intends the whole trip to run for.
enum VisitDurationOption { oneDay, threeDays, sevenDays, custom }

/// Assumed active touring hours per day, used to convert a day count into a
/// time budget for the feasibility check.
const int activeHoursPerDay = 9;

extension VisitDurationOptionX on VisitDurationOption {
  String get label {
    switch (this) {
      case VisitDurationOption.oneDay:
        return '1 Day';
      case VisitDurationOption.threeDays:
        return '3 Days';
      case VisitDurationOption.sevenDays:
        return '7 Days';
      case VisitDurationOption.custom:
        return 'Custom';
    }
  }

  /// Number of days this option represents. [customDays] is required (and
  /// used) only when this option is [VisitDurationOption.custom].
  int days({int? customDays}) {
    switch (this) {
      case VisitDurationOption.oneDay:
        return 1;
      case VisitDurationOption.threeDays:
        return 3;
      case VisitDurationOption.sevenDays:
        return 7;
      case VisitDurationOption.custom:
        return (customDays ?? 1).clamp(1, 60);
    }
  }

  /// Total minutes budgeted across the whole itinerary for this option.
  int totalMinutes({int? customDays}) => days(customDays: customDays) * activeHoursPerDay * 60;
}
