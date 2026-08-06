import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../features/gamification_journal/model/badge_model.dart';
import '../../features/gamification_journal/model/user_badge_model.dart';

/// Icon shown per badge — mapped by id since the mock catalogue only
/// carries an `iconFilename` string with no real asset behind it yet.
IconData iconForBadge(BadgeModel badge) {
  switch (badge.id) {
    case 'b001':
      return Icons.flag_outlined;
    case 'b002':
      return Icons.explore_outlined;
    case 'b003':
      return Icons.park_outlined;
    case 'b004':
      return Icons.temple_buddhist_outlined;
    case 'b005':
      return Icons.ramen_dining_outlined;
    case 'b006':
      return Icons.map_outlined;
    case 'b007':
    case 'b008':
      return Icons.quiz_outlined;
    default:
      return Icons.emoji_events_outlined;
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
          color: isUnlocked ? AppColors.surfaceContainerLow : AppColors.surfaceContainer,
          border: Border.all(
            color: isUnlocked
                ? AppColors.outlineVariant
                : AppColors.outlineVariant.withValues(alpha: 0.5),
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
                color: isUnlocked ? AppColors.secondaryContainer : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnlocked ? iconForBadge(badge) : Icons.lock_outline,
                size: 17,
                color: isUnlocked ? AppColors.onSecondaryContainer : AppColors.outline,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 10.5),
            ),
            if (!isUnlocked && progress != null) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: progress!.ratio,
                  minHeight: 4,
                  backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.4),
                  color: AppColors.primary,
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
