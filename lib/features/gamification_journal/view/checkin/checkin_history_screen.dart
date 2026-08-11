import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/check_in_history_tile.dart';
import '../../controller/checkin_controller.dart';

class CheckInHistoryScreen extends StatelessWidget {
  const CheckInHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checkInController = context.watch<CheckInController>();
    final destinationsById = {
      for (final d in checkInController.destinations) d.id: d,
    };

    return Scaffold(
      appBar: AppHeader.pushed(title: 'Check-in history'),
      body: checkInController.history.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: checkInController.history.length,
              itemBuilder: (context, index) {
                final checkIn = checkInController.history[index];
                return CheckInHistoryTile(
                  checkIn: checkIn,
                  destination: destinationsById[checkIn.destinationId],
                  onToggleHidden: () => context
                      .read<CheckInController>()
                      .setHidden(checkIn.id, !checkIn.isHidden),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 48, color: AppColors.of(context).primaryContainer),
            const SizedBox(height: 12),
            Text('No check-ins yet', style: AppTypography.headlineSm),
            const SizedBox(height: 6),
            Text(
              'Visit a hidden gem and check in to start building your travel history.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
