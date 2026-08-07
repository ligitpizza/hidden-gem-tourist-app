// lib/features/destination_exploration/view/widgets/review_published_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/rating_controller.dart';
import '../../model/difficulty_bucket.dart';
import 'rating_tag_chip.dart';

/// Confirmation screen shown after a successful rating submission —
/// replaces SubmitRatingScreen in the nav stack (see
/// SubmitRatingScreen._submit), so "Return to Map" only needs a single pop
/// back to the destination detail screen.
class ReviewPublishedScreen extends StatelessWidget {
  const ReviewPublishedScreen({
    super.key,
    required this.destinationName,
    required this.reviewText,
    required this.tags,
  });

  final String destinationName;
  final String reviewText;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RatingController>();
    final summary = controller.summary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.onPrimaryContainer, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for your contribution',
                style: AppTypography.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Your update helps the community navigate $destinationName safely.',
                style: AppTypography.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You reviewed $destinationName', style: AppTypography.labelMd),
                    Text('Community Member · Just now', style: AppTypography.labelSm),
                    const SizedBox(height: 10),
                    Text(
                      '"$reviewText"',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'AUTO-GENERATED TAGS',
                        style: AppTypography.labelSm.copyWith(fontSize: 10.5),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final tag in tags) RatingTagChip(tag: tag)],
                      ),
                    ],
                  ],
                ),
              ),
              if (summary != null && summary.ratingCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Community Consensus', style: AppTypography.labelMd),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Aggregated Difficulty', style: AppTypography.bodySm),
                          Text(summary.difficultyBucket.label, style: AppTypography.labelMd),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: (summary.avgDifficulty / 5).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          valueColor: const AlwaysStoppedAnimation(AppColors.secondaryContainer),
                        ),
                      ),
                      if (summary.topTags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'TOP COMMUNITY TAGS',
                          style: AppTypography.labelSm.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in summary.topTags)
                              RatingTagChip(tag: '${tag.tag} ${tag.percentage.round()}%'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${RatingController.pointsPerContribution} Trail Points',
                            style:
                                AppTypography.labelMd.copyWith(color: AppColors.onPrimaryContainer),
                          ),
                          if (controller.pathfinderBadgeUnlocked)
                            Text(
                              "You've unlocked the 'Pathfinder' badge for this region.",
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.onPrimaryContainer),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return to Map'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
