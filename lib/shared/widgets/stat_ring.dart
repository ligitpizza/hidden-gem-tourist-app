import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Shared wording for the "States + Territories" ring's info tooltip, so
/// the Dashboard and a friend's profile preview never drift out of sync
/// on how they explain the 16 figure.
const statesAndTerritoriesTooltip =
    'Counts all 13 Malaysian states plus 3 federal territories: '
    'Kuala Lumpur, Putrajaya, and Labuan.';

/// Ring progress indicator with a value/target readout in the centre —
/// used for "states explored" and "badges earned" on the dashboard.
class StatRing extends StatelessWidget {
  const StatRing({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    this.size = 96,
    this.strokeWidth = 8,
    this.tooltip,
  });

  final String label;
  final int current;
  final int target;
  final double size;
  final double strokeWidth;

  /// Optional explanation shown via a small info icon beside the label —
  /// e.g. clarifying that "States + Territories" counts 3 federal
  /// territories alongside the 13 states. Long-press on touch devices,
  /// hover on desktop/web.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ratio = target == 0 ? 0.0 : (current / target).clamp(0, 1).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: strokeWidth,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.of(context).outlineVariant,
                  color: AppColors.of(context).primary,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$current',
                    style: AppTypography.headlineMd.copyWith(fontSize: size / 3.6),
                  ),
                  Text('of $target', style: AppTypography.bodySm.copyWith(fontSize: size / 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.labelMd.copyWith(letterSpacing: 0),
            ),
            if (tooltip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.of(context).onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
