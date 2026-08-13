import 'itinerary_plan.dart';

/// A previously-saved [ItineraryPlan] as returned from the
/// `saved_itineraries` table — the plan itself has no identity or timestamp
/// of its own, so this pairs it with the row's id and save time.
class SavedItinerary {
  final String id;
  final ItineraryPlan plan;
  final DateTime savedAt;

  const SavedItinerary({
    required this.id,
    required this.plan,
    required this.savedAt,
  });
}
