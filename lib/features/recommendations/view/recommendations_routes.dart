/// Route paths for Module 1 (Hidden Gem Recommendations) drill-down
/// screens — reached from the Assistant tab, not their own bottom-nav tab.
class RecommendationsRoutes {
  RecommendationsRoutes._();

  static const travelStyle = '/recommendations/travel-style';
  static const travelPulse = '/recommendations/travel-pulse';

  /// Pushed with `extra:` set to the [AssistantFeedItem] being inspected.
  static const scoreDetail = '/recommendations/score-detail';
}
