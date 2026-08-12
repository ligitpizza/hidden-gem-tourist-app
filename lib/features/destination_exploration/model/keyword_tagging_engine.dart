/// Deterministic, rule-based keyword-to-tag pipeline (FR4.3, NFR9 — "not an
/// NLP classifier", auditable/upgradeable later). Mirrors the pure/static
/// classification style of OverpassEcoSource.classifyDiet
/// (lib/features/travel_prep/model/eco_partner_repository.dart).
///
/// A keyword preceded by a negation cue within a few words ("unable to use
/// wheelchair", "no parking") is not tagged — a small, deterministic
/// word-window check, not real negation scope parsing. It won't catch every
/// phrasing (e.g. a negation more than [_negationWindowWords] words earlier),
/// and a keyword mentioned both negated and plainly elsewhere in the same
/// review still tags normally on its clean occurrence.
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

  static const List<String> _negationCues = [
    'not',
    'no',
    'without',
    "isn't",
    "aren't",
    "doesn't",
    "don't",
    'cannot',
    "can't",
    'unable',
    'lack of',
    'lacking',
    'never',
  ];

  static const int _negationWindowWords = 4;

  static List<String> tagsFor(String reviewText) {
    final lower = reviewText.toLowerCase();
    final tags = <String>[];
    for (final entry in _keywordToTag.entries) {
      if (tags.contains(entry.value)) continue;
      if (_hasUnnegatedMatch(lower, entry.key)) {
        tags.add(entry.value);
      }
    }
    return tags;
  }

  /// True if [keyword] occurs in [lower] at least once without a negation
  /// cue immediately before it.
  static bool _hasUnnegatedMatch(String lower, String keyword) {
    var searchStart = 0;
    while (true) {
      final index = lower.indexOf(keyword, searchStart);
      if (index == -1) return false;
      if (!_isNegated(lower, index)) return true;
      searchStart = index + keyword.length;
    }
  }

  static bool _isNegated(String lower, int keywordIndex) {
    final before = lower.substring(0, keywordIndex).trim();
    if (before.isEmpty) return false;

    final words = before.split(RegExp(r'\s+'));
    final window =
        words.length <= _negationWindowWords ? words : words.sublist(words.length - _negationWindowWords);
    final windowText = window.join(' ');

    return _negationCues.any(windowText.contains);
  }
}
