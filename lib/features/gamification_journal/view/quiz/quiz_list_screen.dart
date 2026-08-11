import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/quiz_controller.dart';
import '../../model/destination_model.dart';
import '../../model/quiz_attempt_model.dart';
import '../checkin/destination_detail_screen.dart';

/// Browse + history only — taking a quiz always happens inline on that
/// destination's own Destination Detail page now (see
/// destination_detail_screen.dart), so a row here just jumps you there.
class QuizListScreen extends StatelessWidget {
  const QuizListScreen({super.key});

  QuizAttemptModel? _bestAttemptFor(
    String destinationId,
    List<QuizAttemptModel> history,
  ) {
    final attemptsForDestination = history.where(
      (a) => a.destinationId == destinationId,
    );
    if (attemptsForDestination.isEmpty) return null;
    return attemptsForDestination.firstWhere(
      (a) => a.passed,
      orElse: () => attemptsForDestination.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkInController = context.watch<CheckInController>();
    final quizController = context.watch<QuizController>();

    // Only destinations the Traveler has actually checked into get a quiz,
    // matching the doc's "questions based on user checked-in hotspots" rule.
    final visitedDestinationIds = checkInController.history
        .map((c) => c.destinationId)
        .toSet();
    final visited = checkInController.destinations
        .where((d) => visitedDestinationIds.contains(d.id))
        .toList();

    return Scaffold(
      appBar: const AppHeader.pushed(title: 'Quizzes'),
      body: checkInController.destinations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : visited.isEmpty
          ? const _NoCheckInsYet()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Your destinations', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                const SizedBox(height: 10),
                for (final destination in visited)
                  _QuizListTile(
                    destination: destination,
                    attempt: _bestAttemptFor(destination.id, quizController.attemptHistory),
                  ),
              ],
            ),
    );
  }
}

class _QuizListTile extends StatelessWidget {
  const _QuizListTile({required this.destination, required this.attempt});

  final DestinationModel destination;
  final QuizAttemptModel? attempt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.of(context).outlineVariant),
      ),
      // A ListTile paints its own background/ink splashes on the nearest
      // Material ancestor — without this transparent Material in between,
      // it reaches past this Container's own background color and Flutter
      // throws on every build.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DestinationDetailScreen(destination: destination),
            ),
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.of(context).primaryContainerTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.quiz_outlined, color: AppColors.of(context).primaryContainer),
          ),
          title: Text(destination.name, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            attempt == null
                ? 'Not attempted'
                : attempt!.passed
                ? 'Passed · ${attempt!.scorePercentage.toStringAsFixed(0)}%'
                : 'Try again · ${attempt!.scorePercentage.toStringAsFixed(0)}%',
            style: AppTypography.bodySm.copyWith(
              color: attempt?.passed == true ? AppColors.of(context).primaryContainer : AppColors.of(context).onSurfaceVariant,
              fontWeight: attempt?.passed == true ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: Icon(Icons.chevron_right, color: AppColors.of(context).outline),
        ),
      ),
    );
  }
}

class _NoCheckInsYet extends StatelessWidget {
  const _NoCheckInsYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 48, color: AppColors.of(context).primaryContainer),
            const SizedBox(height: 12),
            Text('No quizzes yet', style: AppTypography.headlineSm),
            const SizedBox(height: 6),
            Text(
              'Unlock more quizzes by checking in to more spots.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
