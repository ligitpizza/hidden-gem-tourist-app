import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/journal_controller.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/journal_card.dart';
import 'journal_detail_screen.dart';

class JournalTimelineScreen extends StatelessWidget {
  const JournalTimelineScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, String entryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete journal entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.of(context).error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<JournalController>().deleteEntry(entryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journalController = context.watch<JournalController>();
    final checkInController = context.watch<CheckInController>();
    final destinationsById = {
      for (final d in checkInController.destinations) d.id: d,
    };
    final entries = journalController.entries;

    return Scaffold(
      appBar: const AppHeader.pushed(title: 'Journal'),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Check in somewhere to start a new entry',
        onPressed: () => GoRouter.of(context).go('/explore'),
        child: const Icon(Icons.add),
      ),
      body: entries.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journal Timeline',
                          style: AppTypography.headlineLg.copyWith(fontSize: 28, color: AppColors.of(context).primaryContainer),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Your curated journey through the wild and the local communities you've supported.",
                          style: AppTypography.bodyMd.copyWith(color: AppColors.of(context).onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                final entry = entries[index - 1];
                final isLast = index - 1 == entries.length - 1;
                return _TimelineRow(
                  showConnector: !isLast,
                  child: JournalCard(
                    entry: entry,
                    destination: destinationsById[entry.destinationId],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JournalDetailScreen(
                            entry: entry,
                            destination: destinationsById[entry.destinationId],
                          ),
                        ),
                      );
                    },
                    onDelete: () => _confirmDelete(context, entry.id),
                  ),
                );
              },
            ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.child, required this.showConnector});

  final Widget child;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surfaceContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.of(context).outlineVariant),
                  ),
                  child: Icon(Icons.calendar_today, size: 14, color: AppColors.of(context).primaryContainer),
                ),
                if (showConnector)
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 2,
                        child: CustomPaint(
                          painter: _DashedLinePainter(color: AppColors.of(context).outlineVariant),
                          size: const Size(2, double.infinity),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: AppColors.of(context).primaryContainer),
            const SizedBox(height: 12),
            Text('Your journal is empty', style: AppTypography.headlineSm),
            const SizedBox(height: 6),
            Text(
              'Check in at a destination to start your travel diary.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
