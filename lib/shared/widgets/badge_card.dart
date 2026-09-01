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
    this.isHidden = false,
    this.isPinned = false,
    this.onTap,
  });

  final BadgeModel badge;
  final bool isUnlocked;

  /// Only relevant when locked — drives the "3 of 5" progress bar.
  final BadgeProgressModel? progress;

  /// Hidden from friends/share previews — still fully unlocked, just
  /// dimmed here with a small eye-off marker so it reads as "unlocked but
  /// hidden" rather than being mistaken for a locked badge.
  final bool isHidden;

  /// Chosen as one of the (max 3) badges featured on the profile share
  /// card — marked with a star so it's obvious at a glance which ones
  /// are currently selected.
  final bool isPinned;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isUnlocked ? colors.surfaceContainerLow : colors.surfaceContainer,
        border: Border.all(
          color: isUnlocked ? colors.outlineVariant : colors.outlineVariant.withValues(alpha: 0.5),
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
              color: isUnlocked ? colors.secondaryContainer : colors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? iconForBadge(badge) : Icons.lock_outline,
              size: 17,
              color: isUnlocked ? colors.onSecondaryContainer : colors.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm.copyWith(color: colors.onSurface, fontWeight: FontWeight.w700, fontSize: 10.5),
          ),
          if (!isUnlocked && progress != null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress!.ratio,
                minHeight: 4,
                backgroundColor: colors.outlineVariant.withValues(alpha: 0.4),
                color: colors.primary,
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
    );

    final showHiddenMarker = isUnlocked && isHidden;
    final showPinnedMarker = isUnlocked && isPinned;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        children: [
          showHiddenMarker ? Opacity(opacity: 0.5, child: content) : content,
          if (showPinnedMarker)
            Positioned(
              top: 4,
              left: 4,
              child: _CornerMarker(icon: Icons.star, color: colors.primary),
            ),
          if (showHiddenMarker)
            Positioned(
              top: 4,
              right: 4,
              child: _CornerMarker(icon: Icons.visibility_off, color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  const _CornerMarker({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.of(context).outlineVariant),
      ),
      child: Icon(icon, size: 11, color: color),
    );
  }
}
