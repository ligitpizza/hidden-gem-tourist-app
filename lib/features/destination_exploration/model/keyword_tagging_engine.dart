/// Deterministic, rule-based keyword-to-tag pipeline (FR4.3, NFR9 — "not an
/// NLP classifier", auditable/upgradeable later). Mirrors the pure/static
/// classification style of OverpassEcoSource.classifyDiet
/// (lib/features/travel_prep/model/eco_partner_repository.dart). Negated
/// phrasing (e.g. "not wheelchair friendly" still tagging
/// "wheelchair-friendly") is an accepted limitation, not handled specially.
class KeywordTaggingEngine {
  KeywordTaggingEngine._();

  static const Map<String, String> _keywordToTag = {
    'slippery': 'slippery when wet',
    'wheelchair': 'wheelchair-friendly',
    'stroller': 'stroller-friendly',
    'steep': 'steep terrain',
    'stairs': 'many stairs',
    'parking': 'parking available',
    'crowded': 'crowded',
    'family': 'family-friendly',
    'kids': 'family-friendly',
    'shade': 'shaded',
  };

  static List<String> tagsFor(String reviewText) {
    final lower = reviewText.toLowerCase();
    final tags = <String>[];
    for (final entry in _keywordToTag.entries) {
      if (lower.contains(entry.key) && !tags.contains(entry.value)) {
        tags.add(entry.value);
      }
    }
    return tags;
  }
}
