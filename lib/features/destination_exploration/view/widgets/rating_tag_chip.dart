// lib/features/destination_exploration/view/widgets/rating_tag_chip.dart
import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../model/rating_tag_style.dart';

/// A single generated-tag chip, color-coded by [toneFor] — shared by the
/// ratings section, the submit-rating form, and the review-published
/// confirmation so all three render tags identically.
class RatingTagChip extends StatelessWidget {
  const RatingTagChip({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(tag);
    final background =
        tone == RatingTagTone.caution ? AppColors.errorContainer : AppColors.secondaryContainer;
    final foreground = tone == RatingTagTone.caution
        ? AppColors.onErrorContainer
        : AppColors.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(tag, style: AppTypography.labelSm.copyWith(color: foreground)),
    );
  }
}
