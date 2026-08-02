import '../../../shared/models/destination.dart';
import 'itinerary_stop.dart';
import 'route_path.dart';
import 'visit_duration_option.dart';

/// The full output of "Generate Itinerary": the two candidate paths and the
/// day-trip timeline built from the primary (recommended) path.
class ItineraryPlan {
  final List<Destination> destinations;
  final VisitDurationOption? durationOption;
  final RoutePath primaryPath;
  final RoutePath alternatePath;
  final List<ItineraryStop> timeline;

  /// How long the generated (primary-path) timeline actually takes.
  final int estimatedMinutesNeeded;

  /// The traveller's time budget in minutes, or null if they didn't
  /// allocate a visit duration.
  final int? budgetMinutes;

  const ItineraryPlan({
    required this.destinations,
    required this.durationOption,
    required this.primaryPath,
    required this.alternatePath,
    required this.timeline,
    required this.estimatedMinutesNeeded,
    required this.budgetMinutes,
  });

  RoutePath pathById(String id) => id == primaryPath.id ? primaryPath : alternatePath;

  bool get isFeasible => budgetMinutes == null || estimatedMinutesNeeded <= budgetMinutes!;

  /// Human-readable warning when the generated plan needs more time than
  /// the traveller budgeted, or null if it fits (or no duration was set).
  String? get feasibilityMessage {
    if (isFeasible) return null;
    final neededHours = estimatedMinutesNeeded / 60;
    final budgetHours = budgetMinutes! / 60;
    return 'This route needs about ${neededHours.toStringAsFixed(1)} hr — more than the '
        '${budgetHours.toStringAsFixed(1)} hr you planned for. Consider fewer stops, fewer '
        'hidden gem detours, or a longer duration.';
  }
}
