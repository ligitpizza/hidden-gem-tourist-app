/// Route paths for Module 1 (Hidden Gem Recommendations) screens.
class HiddenGemRecommendationRoutes {
  HiddenGemRecommendationRoutes._();

  /// Mandatory, full-screen setup shown before a tourist without a saved
  /// preference profile reaches the shell (Preference Selection And
  /// Preference Update activity diagram) — lives outside the shell, like
  /// `/login`/`/signup`.
  static const preferenceSetup = '/preferences/setup';

  /// "Refresh Your Interests" — the same screen, reached from inside the
  /// shell to change an existing profile.
  static const travelStyle = '/recommendations/travel-style';

  static const travelPulse = '/recommendations/travel-pulse';

  static const trending = '/recommendations/trending';

  /// "Search For Gem" (UC diagram).
  static const search = '/recommendations/search';

  /// Pushed with `extra:` set to the already-loaded `List<HiddenGemFeedItem>`
  /// from [RecommendationController.topMatches].
  static const topMatchesList = '/recommendations/top-matches';

  /// Pushed with `extra:` set to the [HiddenGemFeedItem] being inspected.
  static const scoreDetail = '/recommendations/score-detail';
}
