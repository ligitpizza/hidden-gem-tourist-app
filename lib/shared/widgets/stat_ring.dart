import 'package:flutter/material.dart';

import '../../config/theme.dart';

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
  });

  final String label;
  final int current;
  final int target;
  final double size;
  final double strokeWidth;

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
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelMd.copyWith(letterSpacing: 0),
        ),
      ],
    );
  }
}
