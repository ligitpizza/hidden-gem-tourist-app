import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/journal_controller.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/journal_card.dart';
import 'journal_detail_screen.dart';

/// The Journal tab's root screen — wraps [JournalTimelineBody] in a
/// Scaffold with its own app bar and a "check in to start an entry" FAB.
class JournalTimelineScreen extends StatelessWidget {
  const JournalTimelineScreen({super.key, this.isTabRoot = true});

  /// Tab roots use [AppHeader.tabRoot] (no back button, since there's
  /// nothing to pop to); set false if this is ever pushed on top of
  /// something instead.
  final bool isTabRoot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isTabRoot
          ? const AppHeader.tabRoot(title: 'Journal')
          : const AppHeader.pushed(title: 'Journal'),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Check in somewhere to start a new entry',
        onPressed: () => GoRouter.of(context).go('/explore'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<JournalController>().loadEntries(),
        color: AppColors.of(context).primary,
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: JournalTimelineBody(),
        ),
      ),
    );
  }
}

/// The scrollable content of the journal timeline — a header, then every
/// entry as a connected timeline row. No Scaffold/AppBar/scrolling of its
/// own, so it can be embedded inside another scrollable screen (Profile)
/// as easily as it can be wrapped standalone (see [JournalTimelineScreen]).
class JournalTimelineBody extends StatelessWidget {
  const JournalTimelineBody({super.key, this.showHeading = true});

  /// Set to false when the embedding screen already has its own "Journal"
  /// section heading, so the two don't repeat.
  final bool showHeading;

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

    if (entries.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            'Journal Timeline',
            style: AppTypography.headlineLg.copyWith(fontSize: 28, color: AppColors.of(context).primaryContainer),
          ),
          const SizedBox(height: 6),
          Text(
            "Your curated journey through the wild and the local communities you've supported.",
            style: AppTypography.bodyMd.copyWith(color: AppColors.of(context).onSurfaceVariant),
          ),
          const SizedBox(height: 24),
        ],
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            showConnector: i != entries.length - 1,
            child: JournalCard(
              entry: entries[i],
              destination: destinationsById[entries[i].destinationId],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JournalDetailScreen(
                      entry: entries[i],
                      destination: destinationsById[entries[i].destinationId],
                    ),
                  ),
                );
              },
              onDelete: () => _confirmDelete(context, entries[i].id),
            ),
          ),
      ],
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
        padding: const EdgeInsets.all(32),
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
