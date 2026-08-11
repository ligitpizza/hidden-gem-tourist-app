// lib/features/destination_exploration/view/widgets/submit_rating_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/rating_controller.dart';
import '../../model/difficulty_bucket.dart';
import '../../model/keyword_tagging_engine.dart';
import 'rating_tag_chip.dart';
import 'review_published_screen.dart';

/// Feature 4's rating submission form — pushed from RatingsSection's
/// "Write a Review". Expects a RatingController to already be provided
/// above it in the tree (see RatingsSection._openWriteReview).
class SubmitRatingScreen extends StatefulWidget {
  const SubmitRatingScreen({
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
  State<SubmitRatingScreen> createState() => _SubmitRatingScreenState();
}

class _SubmitRatingScreenState extends State<SubmitRatingScreen> {
  int _difficultyScore = 3;
  final _reviewController = TextEditingController();
  List<String> _liveTags = const [];

  @override
  void initState() {
    super.initState();
    _reviewController.addListener(_onReviewTextChanged);
  }

  void _onReviewTextChanged() {
    setState(() => _liveTags = KeywordTaggingEngine.tagsFor(_reviewController.text));
  }

  @override
  void dispose() {
    _reviewController.removeListener(_onReviewTextChanged);
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = context.read<RatingController>();
    await controller.submitRating(
      destinationId: widget.destinationId,
      region: widget.region,
      difficultyScore: _difficultyScore,
      reviewText: _reviewController.text,
      isCheckedIn: widget.isCheckedIn,
    );

    if (!mounted) return;

    if (controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.error!)));
      return;
    }

    final reviewText = _reviewController.text;
    final tags = _liveTags;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<RatingController>.value(
          value: controller,
          child: ReviewPublishedScreen(
            destinationName: widget.destinationName,
            reviewText: reviewText,
            tags: tags,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RatingController>();
    final bucketLabel = difficultyBucketFor(_difficultyScore.toDouble()).label;

    return Scaffold(
      appBar: AppBar(title: const Text('Write a Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: AppColors.of(context).onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  'CHECK-IN COMPLETE',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.of(context).onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.destinationName, style: AppTypography.headlineLgMobile),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(widget.destinationImageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Share your experience to help other explorers navigate this hidden gem. '
              'Your contributions keep the Field Journal accurate.',
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.of(context).outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Difficulty', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          bucketLabel,
                          style:
                              AppTypography.labelMd.copyWith(color: AppColors.of(context).onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _difficultyScore.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (v) => setState(() => _difficultyScore = v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Easy', style: AppTypography.labelSm),
                      Text('Moderate', style: AppTypography.labelSm),
                      Text('Hard', style: AppTypography.labelSm),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Your Experience', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLength: 500,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What was the path like? Any accessibility notes?',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.of(context).onPrimaryContainer),
                const SizedBox(width: 6),
                Text('Auto-generated Tags', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _liveTags) RatingTagChip(tag: tag),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '+ Add Tag',
                    style: AppTypography.labelSm.copyWith(color: AppColors.of(context).outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tags are extracted from your review text automatically.',
              style: AppTypography.labelSm.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.of(context).surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 17, color: AppColors.of(context).onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Disclaimer: This is crowd-sourced data. Field Journal does not guarantee '
                      'the current safety or accessibility of paths. Always exercise caution and '
                      'follow local safety signs.',
                      style: AppTypography.bodySm,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isSubmitting ? null : _submit,
                child: Text(controller.isSubmitting ? 'Submitting…' : 'Submit Contribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
