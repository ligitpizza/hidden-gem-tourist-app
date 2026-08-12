// lib/features/destination_exploration/model/rating_tag_style.dart

enum RatingTagTone { positive, caution }

const _cautionTags = {
  'steep terrain',
  'many stairs',
  'crowded',
  'slippery when wet',
  'uneven terrain',
  'narrow pathway',
  'muddy when wet',
  'wheelchair-unfriendly',
  'stroller-unfriendly',
};

/// Classifies a KeywordTaggingEngine tag into a display tone — caution
/// tags (hazards/friction/negated accessibility) render differently from
/// accessibility-positive ones. Pure and static: the keyword map itself is
/// fixed, so no new backend field is needed for this.
RatingTagTone toneFor(String tag) =>
    _cautionTags.contains(tag) ? RatingTagTone.caution : RatingTagTone.positive;
