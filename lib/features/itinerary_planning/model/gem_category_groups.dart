import '../../../shared/models/destination.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../../shared/services/hidden_gem_scoring.dart';

/// Every specific [DestinationCategory] grouped under the broad "vibe"
/// bucket it scores into ([HiddenGemScoring.categoryFromDb]) — the single
/// source of truth for how the 5 broad groups relate to the 15 specific
/// place types, so the "Interested Hidden Gem Categories" picker's group
/// chips (bulk-select all members) never drift out of sync with actual gem
/// scoring/filtering.
final Map<HiddenGemCategory, List<DestinationCategory>> gemCategoryGroups = {
  for (final group in HiddenGemCategory.values)
    group: [
      for (final specific in DestinationCategory.values)
        if (HiddenGemScoring.categoryFromDb(specific.dbValue) == group) specific,
    ],
};
