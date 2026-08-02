import 'itinerary_plan.dart';

/// In-memory holding pen for saved itineraries until a real persistence
/// layer (Drift table / backend) is agreed on for this module.
class SavedItinerariesStore {
  SavedItinerariesStore._internal();

  static final SavedItinerariesStore instance = SavedItinerariesStore._internal();

  final List<ItineraryPlan> _saved = [];

  List<ItineraryPlan> get saved => List.unmodifiable(_saved);

  void save(ItineraryPlan plan) => _saved.add(plan);
}
