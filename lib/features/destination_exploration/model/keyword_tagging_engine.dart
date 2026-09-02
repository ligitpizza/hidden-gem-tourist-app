/// Deterministic, rule-based keyword-to-tag pipeline (FR4.3, NFR9 — "not an
/// NLP classifier", auditable/upgradeable later). Mirrors the pure/static
/// classification style of OverpassEcoSource.classifyDiet
/// (lib/features/travel_prep/model/eco_partner_repository.dart).
///
/// A keyword preceded *or followed* by a negation cue within a few words
/// ("unable to use wheelchair", "no parking", "wheelchair accessibility is
/// not good", "poor wheelchair access", "wasn't wheelchair friendly") is
/// not tagged with its positive meaning — a small, deterministic
/// word-window check in both directions, not real negation scope parsing.
/// Cues are matched as whole words (via [_negationWords]/
/// [_hasContractedNegationWord]) or, for multi-word phrases
/// ([_negationPhrases]), as a substring — never a bare substring on a
/// single word, so "enough"/"narrow" don't false-positive just for
/// containing "no". It still won't catch every phrasing (e.g. a negation
/// more than [_negationWindowWords] words away in either direction, or a
/// negation word not in [_negationWords]/[_negationPhrases] — this is a
/// curated list, not exhaustive English negation). For keywords whose
/// [_KeywordRule] defines a [_KeywordRule.negatedTag] (currently
/// wheelchair/stroller), a negated mention tags that explicit opposite
/// instead of just being dropped — e.g. "unable to use wheelchair" tags
/// "wheelchair-unfriendly". A keyword mentioned both negated and plainly
/// elsewhere in the same review tags both the positive and negative tag
/// (an honest reflection of a mixed review), since each occurrence is
/// judged independently.
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

  // Single-word cues — matched as whole words against the window, never as
  // a bare substring (a naive `.contains('no')` would false-positive on
  // "enough" or "info"). Any contraction ending in "n't" (isn't, aren't,
  // doesn't, wasn't, weren't, hasn't, haven't, hadn't, won't, wouldn't,
  // shouldn't, couldn't, can't, mustn't, needn't, ain't, ...) is caught
  // generically by [_hasContractedNegationWord] instead of being
  // enumerated here — one rule instead of a dozen near-identical entries.
  static const Set<String> _negationWords = {
    'not',
    'no',
    'without',
    'cannot',
    'unable',
    'lacking',
    'never',
    'none',
    'nothing',
    'neither',
    'nowhere',
    'zero',
    'hardly',
    'barely',
    'scarcely',
    'poor',
    'poorly',
    'bad',
    'terrible',
    'awful',
    'insufficient',
    'missing',
    'absent',
    'limited',
  };

  // Multi-word cues can't be matched as a single token, so these stay as
  // substring checks against the window text — short enough phrases that
  // an accidental match inside an unrelated word is effectively impossible.
  static const List<String> _negationPhrases = ['lack of', 'far from'];

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
    return _windowHasNegationCue(window);
  }

  static bool _hasNegationCueAfter(String lower, int afterKeywordIndex) {
    final after = lower.substring(afterKeywordIndex).trim();
    if (after.isEmpty) return false;

    final words = after.split(RegExp(r'\s+'));
    final window = words.length <= _negationWindowWords ? words : words.sublist(0, _negationWindowWords);
    return _windowHasNegationCue(window);
  }

  static bool _windowHasNegationCue(List<String> window) {
    // Trailing punctuation ("stroller." / "friendly,") would otherwise
    // stop a whole-word match on a cue that's followed by a comma/period.
    final normalized = window.map((w) => w.replaceAll(RegExp(r"[^\w']"), '')).toList();

    if (normalized.any((w) => _negationWords.contains(w) || _hasContractedNegationWord(w))) {
      return true;
    }
    return _negationPhrases.any(normalized.join(' ').contains);
  }

  /// True for any contraction ending in "n't" (isn't, doesn't, wasn't,
  /// hasn't, won't, couldn't, ...) — see [_negationWords]'s doc comment.
  static bool _hasContractedNegationWord(String word) => word.endsWith("n't");
}

class _KeywordRule {
  const _KeywordRule(this.tag, {this.negatedTag});

  final String tag;
  final String? negatedTag;
}
