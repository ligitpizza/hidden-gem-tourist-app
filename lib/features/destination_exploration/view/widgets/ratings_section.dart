// lib/features/destination_exploration/view/widgets/ratings_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/rating_controller.dart';
import '../../model/difficulty_bucket.dart';
import '../../model/rating_summary.dart';
import 'rating_tag_chip.dart';
import 'submit_rating_screen.dart';

/// Feature 4's "Ratings & Accessibility" section, embedded into
/// gamification_journal's DestinationDetailScreen (see the View design
/// spec's "Entry point" decision) rather than living on its own page.
class RatingsSection extends StatefulWidget {
  const RatingsSection({
    super.key,
    required this.destinationId,
    required this.destinationName,
    required this.destinationImageUrl,
    required this.region,
    required this.isCheckedIn,
  });

  final String destinationId;
  final String destinationName;
  final String destinationImageUrl;
  final String region;
  final bool isCheckedIn;

  @override
  State<RatingsSection> createState() => _RatingsSectionState();
}

class _RatingsSectionState extends State<RatingsSection> {
  late final RatingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RatingController()
      ..loadSummary(widget.destinationId)
      ..loadReviews(widget.destinationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openWriteReview(BuildContext context) async {
    if (!widget.isCheckedIn) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<RatingController>.value(
          value: _controller,
          child: SubmitRatingScreen(
            destinationId: widget.destinationId,
            destinationName: widget.destinationName,
            destinationImageUrl: widget.destinationImageUrl,
            region: widget.region,
            isCheckedIn: widget.isCheckedIn,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RatingController>.value(
      value: _controller,
      child: Consumer<RatingController>(
        builder: (context, controller, _) => _RatingsSectionBody(
          controller: controller,
          isCheckedIn: widget.isCheckedIn,
          destinationId: widget.destinationId,
          onWriteReview: () => _openWriteReview(context),
        ),
      ),
    );
  }
}

class _RatingsSectionBody extends StatelessWidget {
  const _RatingsSectionBody({
    required this.controller,
    required this.isCheckedIn,
    required this.destinationId,
    required this.onWriteReview,
  });

  final RatingController controller;
  final bool isCheckedIn;
  final String destinationId;
  final VoidCallback onWriteReview;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Difficulty & Accessibility', style: AppTypography.headlineSm),
        const SizedBox(height: 10),
        if (summary == null || summary.ratingCount == 0)
          Text('Be the first to review this destination.', style: AppTypography.bodySm)
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in summary.topTags) RatingTagChip(tag: tag.tag)],
          ),
          const SizedBox(height: 8),
          Text(
            'Community-reported, unverified',
            style: AppTypography.labelSm.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Text('Community Reviews', style: AppTypography.headlineSm)),
            TextButton(
              onPressed: isCheckedIn ? onWriteReview : null,
              child: const Text('Write a Review'),
            ),
          ],
        ),
        Text(
          summary == null
              ? 'Loading reviews…'
              : 'Based on ${summary.ratingCount} review${summary.ratingCount == 1 ? '' : 's'} from fellow explorers',
          style: AppTypography.bodySm,
        ),
        if (!isCheckedIn) ...[
          const SizedBox(height: 4),
          Text(
            'Check in above to write a review',
            style: AppTypography.labelSm.copyWith(color: AppColors.outline),
          ),
        ],
        const SizedBox(height: 12),
        for (final review in controller.reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReviewCard(review: review),
          ),
        if (controller.hasMoreReviews)
          Center(
            child: TextButton(
              onPressed: controller.isLoadingReviews
                  ? null
                  : () => controller.loadReviews(destinationId, loadMore: true),
              child: Text(
                controller.isLoadingReviews
                    ? 'Loading…'
                    : 'Read All ${summary?.ratingCount ?? ''} Reviews'.trim(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final DestinationReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: Icon(Icons.person_outline, size: 16, color: AppColors.outline),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Community Member', style: AppTypography.labelMd),
                    Text(relativeTime(review.createdAt), style: AppTypography.labelSm),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainerTint,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  difficultyBucketFor(review.difficultyScore.toDouble()).label,
                  style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${review.reviewText}"',
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
          ),
          if (review.generatedTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in review.generatedTags) RatingTagChip(tag: tag)],
            ),
          ],
        ],
      ),
    );
  }
}

/// Coarse, human-friendly relative time for review timestamps (e.g. "2d
/// ago") — display-only, no need to match any particular locale library.
String relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w ago';
  final months = (diff.inDays / 30).floor();
  return '${months}mo ago';
}
