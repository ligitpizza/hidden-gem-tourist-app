import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../features/gamification_journal/model/check_in_model.dart';
import '../../features/gamification_journal/model/destination_model.dart';

class CheckInHistoryTile extends StatelessWidget {
  const CheckInHistoryTile({
    super.key,
    required this.checkIn,
    required this.destination,
    required this.onToggleHidden,
    this.onTap,
  });

  final CheckInModel checkIn;
  final DestinationModel? destination;
  final VoidCallback onToggleHidden;
  final VoidCallback? onTap;

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    if (isToday) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: checkIn.isHidden ? 0.5 : 1,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.of(context).surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.of(context).outlineVariant),
        ),
        // A ListTile paints its own background/ink splashes on the
        // *nearest* Material ancestor — without this transparent Material
        // in between, it reaches past this Container's own background
        // color and Flutter throws on every build.
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            onTap: onTap,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.of(context).primaryContainerTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.location_on, color: AppColors.of(context).primaryContainer),
            ),
            title: Text(
              destination?.name ?? 'Unknown destination',
              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${destination?.state ?? ''} · ${_formatDate(checkIn.timestamp)}',
              style: AppTypography.bodySm,
            ),
            trailing: IconButton(
              icon: Icon(
                checkIn.isHidden ? Icons.visibility_off : Icons.visibility,
                color: AppColors.of(context).onSurfaceVariant,
              ),
              tooltip: checkIn.isHidden ? 'Unhide' : 'Hide',
              onPressed: onToggleHidden,
            ),
          ),
        ),
      ),
    );
  }
}
