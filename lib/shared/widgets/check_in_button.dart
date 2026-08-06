import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../features/gamification_journal/controller/checkin_controller.dart';

/// A single button whose appearance reflects CheckInStatus, so every
/// screen with a check-in action (destination detail, map popup, etc.)
/// shows consistent idle/loading/success/error states.
class CheckInButtonWidget extends StatelessWidget {
  const CheckInButtonWidget({
    super.key,
    required this.status,
    required this.onPressed,
    this.errorMessage,
  });

  final CheckInStatus status;
  final VoidCallback onPressed;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final isLoading = status == CheckInStatus.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 18),
                    SizedBox(width: 8),
                    Text('Check In Here'),
                  ],
                ),
        ),
        if (status == CheckInStatus.error && errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 15, color: AppColors.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (status == CheckInStatus.success) ...[
          const SizedBox(height: 8),
          Text(
            "You're checked in!",
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
