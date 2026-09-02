/// Deterministic, rule-based keyword-to-tag pipeline (FR4.3, NFR9 — "not an
/// NLP classifier", auditable/upgradeable later). Mirrors the pure/static
/// classification style of OverpassEcoSource.classifyDiet
/// (lib/features/travel_prep/model/eco_partner_repository.dart).
///
/// A keyword preceded *or followed* by a negation cue within a few words
/// ("unable to use wheelchair", "no parking", "wheelchair accessibility is
/// not good") is not tagged with its positive meaning — a small,
/// deterministic word-window check in both directions, not real negation
/// scope parsing. It won't catch every phrasing (e.g. a negation more than
/// [_negationWindowWords] words away in either direction). For keywords
/// whose [_KeywordRule]
/// defines a [_KeywordRule.negatedTag] (currently wheelchair/stroller), a
/// negated mention tags that explicit opposite instead of just being
/// dropped — e.g. "unable to use wheelchair" tags "wheelchair-unfriendly".
/// A keyword mentioned both negated and plainly elsewhere in the same
/// review tags both the positive and negative tag (an honest reflection of
/// a mixed review), since each occurrence is judged independently.
class KeywordTaggingEngine {
  KeywordTaggingEngine._();

  static const Map<String, _KeywordRule> _keywordToTag = {
    'slippery': _KeywordRule('slippery when wet'),
    'wheelchair': _KeywordRule('wheelchair-friendly', negatedTag: 'wheelchair-unfriendly'),
    'stroller': _KeywordRule('stroller-friendly', negatedTag: 'stroller-unfriendly'),
    'steep': _KeywordRule('steep terrain'),
    'stairs': _KeywordRule('many stairs'),
    'parking': _KeywordRule('parking available'),
    'crowded': _KeywordRule('crowded'),
    'family': _KeywordRule('family-friendly'),
    'kids': _KeywordRule('family-friendly'),
    'shade': _KeywordRule('shaded'),
    'ramp': _KeywordRule('ramp available'),
    'handrail': _KeywordRule('handrail available'),
    'railing': _KeywordRule('handrail available'),
    'uneven': _KeywordRule('uneven terrain'),
    'narrow': _KeywordRule('narrow pathway'),
    'muddy': _KeywordRule('muddy when wet'),
    'toilet': _KeywordRule('restroom available'),
    'restroom': _KeywordRule('restroom available'),
    'bench': _KeywordRule('seating available'),
    'seating': _KeywordRule('seating available'),
    'signpost': _KeywordRule('well signposted'),
    'signage': _KeywordRule('well signposted'),
    'elderly': _KeywordRule('elderly-friendly'),
    'senior': _KeywordRule('elderly-friendly'),
    'pet': _KeywordRule('pet-friendly'),
    'dog': _KeywordRule('pet-friendly'),
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
      final rule = entry.value;
      if (!tags.contains(rule.tag) && _hasMatch(lower, entry.key, negated: false)) {
        tags.add(rule.tag);
      }
      final negatedTag = rule.negatedTag;
      if (negatedTag != null &&
          !tags.contains(negatedTag) &&
          _hasMatch(lower, entry.key, negated: true)) {
        tags.add(negatedTag);
      }
    }
    return tags;
  }

  /// True if [keyword] occurs in [lower] at least once whose negation state
  /// (preceded by a negation cue within [_negationWindowWords] words, or
  /// not) matches [negated].
  static bool _hasMatch(String lower, String keyword, {required bool negated}) {
    var searchStart = 0;
    while (true) {
      final index = lower.indexOf(keyword, searchStart);
      if (index == -1) return false;
      if (_isNegated(lower, index, keyword.length) == negated) return true;
      searchStart = index + keyword.length;
    }
  }

  /// Checks both directions: a negation cue shortly *before* the keyword
  /// ("unable to use wheelchair") and shortly *after* it ("wheelchair
  /// accessibility is not good") both count — the cue can modify the
  /// keyword from either side depending on phrasing.
  static bool _isNegated(String lower, int keywordIndex, int keywordLength) {
    return _hasNegationCueBefore(lower, keywordIndex) ||
        _hasNegationCueAfter(lower, keywordIndex + keywordLength);
  }

  static bool _hasNegationCueBefore(String lower, int keywordIndex) {
    final before = lower.substring(0, keywordIndex).trim();
    if (before.isEmpty) return false;

    final words = before.split(RegExp(r'\s+'));
    final window =
        words.length <= _negationWindowWords ? words : words.sublist(words.length - _negationWindowWords);
    return _negationCues.any(window.join(' ').contains);
  }

  static bool _hasNegationCueAfter(String lower, int afterKeywordIndex) {
    final after = lower.substring(afterKeywordIndex).trim();
    if (after.isEmpty) return false;

    final words = after.split(RegExp(r'\s+'));
    final window = words.length <= _negationWindowWords ? words : words.sublist(0, _negationWindowWords);
    return _negationCues.any(window.join(' ').contains);
  }
}

class _KeywordRule {
  const _KeywordRule(this.tag, {this.negatedTag});

  final String tag;
  final String? negatedTag;
}
