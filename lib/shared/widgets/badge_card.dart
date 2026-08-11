import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../features/gamification_journal/model/badge_model.dart';
import '../../features/gamification_journal/model/user_badge_model.dart';

/// Icon shown per badge — derived from `criteriaType` (and `targetValue`
/// for category/state-specific badges) rather than a fixed per-id switch,
/// since the catalogue now comes from Supabase and its ids aren't known
/// at compile time.
IconData iconForBadge(BadgeModel badge) {
  switch (badge.criteriaType) {
    case BadgeCriteriaType.totalCheckIns:
      if (badge.threshold >= 40) return Icons.military_tech_outlined;
      if (badge.threshold >= 10) return Icons.explore_outlined;
      return Icons.flag_outlined;
    case BadgeCriteriaType.categoryCount:
      switch (badge.targetValue) {
        case 'Nature':
          return Icons.park_outlined;
        case 'Food':
          return Icons.ramen_dining_outlined;
        case 'Culture':
          return Icons.temple_buddhist_outlined;
        default:
          return Icons.category_outlined;
      }
    case BadgeCriteriaType.stateVisit:
      return Icons.map_outlined;
    case BadgeCriteriaType.quizzesCompleted:
      if (badge.threshold >= 15) return Icons.school_outlined;
      return Icons.quiz_outlined;
    case BadgeCriteriaType.economicImpactRM:
      return Icons.volunteer_activism_outlined;
    case BadgeCriteriaType.quizPerfectScore:
      return Icons.grade_outlined;
  }
}

class BadgeCard extends StatelessWidget {
  const BadgeCard({
    super.key,
    required this.badge,
    required this.isUnlocked,
    this.progress,
    this.onTap,
  });

  final BadgeModel badge;
  final bool isUnlocked;

  /// Only relevant when locked — drives the "3 of 5" progress bar.
  final BadgeProgressModel? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked ? AppColors.of(context).surfaceContainerLow : AppColors.of(context).surfaceContainer,
          border: Border.all(
            color: isUnlocked
                ? AppColors.of(context).outlineVariant
                : AppColors.of(context).outlineVariant.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isUnlocked ? AppColors.of(context).secondaryContainer : AppColors.of(context).surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnlocked ? iconForBadge(badge) : Icons.lock_outline,
                size: 17,
                color: isUnlocked ? AppColors.of(context).onSecondaryContainer : AppColors.of(context).outline,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(color: AppColors.of(context).onSurface, fontWeight: FontWeight.w700, fontSize: 10.5),
            ),
            if (!isUnlocked && progress != null) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: progress!.ratio,
                  minHeight: 4,
                  backgroundColor: AppColors.of(context).outlineVariant.withValues(alpha: 0.4),
                  color: AppColors.of(context).primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${progress!.current} of ${progress!.target}',
                style: AppTypography.labelSm.copyWith(fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
