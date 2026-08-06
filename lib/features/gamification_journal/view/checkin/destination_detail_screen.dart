import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/check_in_button.dart';
import '../../controller/badge_controller.dart';
import '../../controller/checkin_controller.dart';
import '../../controller/journal_controller.dart';
import '../../controller/quiz_controller.dart';
import '../../model/badge_model.dart';
import '../../model/cultural_fact_model.dart';
import '../../model/destination_model.dart';
import '../../model/quiz_attempt_model.dart';
import '../../model/quiz_question_model.dart';
import '../../model/user_badge_model.dart';

/// When no badge was newly unlocked, nudge the traveler toward whichever
/// locked badge is actually relevant to what they just did — the
/// destination's category/state for a check-in, or the quiz-completion
/// badge for a quiz submission — not just whichever badge is globally
/// closest (which could reference an unrelated spot). Returns null if
/// nothing relevant is still in progress.
String? _nearestBadgeProgressMessage(
  BadgeController badgeController, {
  DestinationModel? relevantDestination,
  bool quizContext = false,
}) {
  final badgesById = {for (final b in badgeController.allBadges) b.id: b};

  bool isRelevant(BadgeModel badge) {
    switch (badge.criteriaType) {
      case BadgeCriteriaType.totalCheckIns:
        return relevantDestination != null;
      case BadgeCriteriaType.categoryCount:
        return relevantDestination != null && badge.targetValue == relevantDestination.category;
      case BadgeCriteriaType.stateVisit:
        return relevantDestination != null && badge.targetValue == relevantDestination.state;
      case BadgeCriteriaType.quizzesCompleted:
        return quizContext;
    }
  }

  BadgeProgressModel? closest;
  var closestRemaining = 1 << 30;
  for (final p in badgeController.progress) {
    final badge = badgesById[p.badgeId];
    if (badge == null || !isRelevant(badge)) continue;
    final remaining = p.target - p.current;
    if (remaining <= 0) continue;
    if (remaining < closestRemaining) {
      closest = p;
      closestRemaining = remaining;
    }
  }
  if (closest == null) return null;

  final badge = badgesById[closest.badgeId];
  if (badge == null) return null;

  final remaining = closest.target - closest.current;
  final spot = remaining == 1 ? 'spot' : 'spots';
  return switch (badge.criteriaType) {
    BadgeCriteriaType.totalCheckIns =>
      'Check in at $remaining more $spot to achieve ${badge.name}',
    BadgeCriteriaType.categoryCount =>
      'Explore $remaining more ${badge.targetValue} $spot to achieve ${badge.name}',
    BadgeCriteriaType.stateVisit =>
      'Visit $remaining more $spot in ${badge.targetValue} to achieve ${badge.name}',
    BadgeCriteriaType.quizzesCompleted =>
      'Complete $remaining more quiz${remaining == 1 ? '' : 'zes'} to achieve ${badge.name}',
  };
}

/// The destination's own page — and, since a quiz can only be taken for a
/// destination you've checked into, this is also where the quiz lives now:
/// pinned to the top, above the destination's own content, in three states
/// (locked → active → result). The cultural fact of the day only appears
/// once the quiz has been submitted.
class DestinationDetailScreen extends StatefulWidget {
  const DestinationDetailScreen({super.key, required this.destination});

  final DestinationModel destination;

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  List<int?> _selectedAnswers = [];
  int _currentQuestionIndex = 0;
  bool _quizLoading = false;
  QuizAttemptModel? _completedAttempt;
  List<BadgeModel> _quizBadgesEarned = [];

  // CheckInController.status/errorMessage are shared across the whole app
  // (one controller instance), so they'd otherwise still read "success" —
  // or a stale cooldown countdown — after navigating from a different
  // destination. Mirror them into screen-local state, reset to idle on
  // every fresh visit, and only update it from this screen's own attempts.
  CheckInStatus _checkInStatus = CheckInStatus.idle;
  String? _checkInErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initQuizIfNeeded());
  }

  bool get _isCheckedIn => context
      .read<CheckInController>()
      .history
      .any((c) => c.destinationId == widget.destination.id);

  Future<void> _initQuizIfNeeded() async {
    if (!mounted) return;
    final quizController = context.read<QuizController>();
    final priorAttempt = quizController.attemptHistory
        .where((a) => a.destinationId == widget.destination.id)
        .fold<QuizAttemptModel?>(null, (latest, a) {
          if (latest == null || a.attemptedAt.isAfter(latest.attemptedAt)) return a;
          return latest;
        });

    if (priorAttempt != null) {
      setState(() => _completedAttempt = priorAttempt);
    } else if (_isCheckedIn) {
      await _startQuiz();
    }
  }

  Future<void> _startQuiz() async {
    if (!mounted) return;
    setState(() => _quizLoading = true);
    final quizController = context.read<QuizController>();
    await quizController.startQuiz(widget.destination.id);
    if (!mounted) return;
    setState(() {
      _selectedAnswers = List<int?>.filled(quizController.currentQuestions.length, null);
      _currentQuestionIndex = 0;
      _quizLoading = false;
    });
  }

  /// Runs the check-in, then feeds the result into Journal (auto-draft),
  /// Badges (unlock evaluation), and starts the destination's quiz.
  Future<void> _handleCheckIn() async {
    final checkInController = context.read<CheckInController>();
    final journalController = context.read<JournalController>();
    final badgeController = context.read<BadgeController>();

    await checkInController.checkIn(
      destinationId: widget.destination.id,
      // TODO(phase1): swap for a real geolocator reading once GPS is wired
      // in. Using the destination's own coordinates here lets the UI flow
      // be tested end-to-end before device location is available.
      userLat: widget.destination.latitude,
      userLng: widget.destination.longitude,
    );

    if (!mounted) return;
    setState(() {
      _checkInStatus = checkInController.status;
      _checkInErrorMessage = checkInController.errorMessage;
    });

    if (checkInController.status != CheckInStatus.success) return;

    final newCheckIn = checkInController.history.first;
    await journalController.createFromCheckIn(newCheckIn);

    final destinationsById = {
      for (final d in checkInController.destinations) d.id: d,
    };
    await badgeController.evaluateAfterCheckIn(
      checkIns: checkInController.history,
      destinationsById: destinationsById,
    );

    if (!mounted) return;

    if (badgeController.newlyEarned.isNotEmpty) {
      for (final badge in badgeController.newlyEarned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryContainer,
            content: Text('Badge unlocked: ${badge.name}'),
          ),
        );
      }
    } else {
      final progressMessage = _nearestBadgeProgressMessage(
        badgeController,
        relevantDestination: widget.destination,
      );
      if (progressMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceContainerHigh,
            content: Text(progressMessage, style: const TextStyle(color: AppColors.onSurface)),
          ),
        );
      }
    }
    badgeController.clearNewlyEarned();

    await _startQuiz();
  }

  void _selectAnswer(int optionIndex) {
    setState(() => _selectedAnswers[_currentQuestionIndex] = optionIndex);
  }

  Future<void> _nextOrSubmit() async {
    final quizController = context.read<QuizController>();
    if (_currentQuestionIndex < quizController.currentQuestions.length - 1) {
      setState(() => _currentQuestionIndex++);
      return;
    }

    if (_selectedAnswers.any((a) => a == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer every question before submitting.')),
      );
      return;
    }

    setState(() => _quizLoading = true);
    final checkInController = context.read<CheckInController>();
    final badgeController = context.read<BadgeController>();

    final attempt = await quizController.submitAnswers(
      destinationId: widget.destination.id,
      selectedOptionIndexes: _selectedAnswers.cast<int>(),
    );

    final destinationsById = {
      for (final d in checkInController.destinations) d.id: d,
    };
    await badgeController.evaluateAfterQuiz(
      checkIns: checkInController.history,
      destinationsById: destinationsById,
      quizzesCompleted: quizController.completedQuizCount,
    );

    final newlyEarned = List.of(badgeController.newlyEarned);
    badgeController.clearNewlyEarned();

    if (!mounted) return;

    if (newlyEarned.isNotEmpty) {
      for (final badge in newlyEarned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryContainer,
            content: Text('Badge unlocked: ${badge.name}'),
          ),
        );
      }
    } else {
      final progressMessage = _nearestBadgeProgressMessage(badgeController, quizContext: true);
      if (progressMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceContainerHigh,
            content: Text(progressMessage, style: const TextStyle(color: AppColors.onSurface)),
          ),
        );
      }
    }

    setState(() {
      _completedAttempt = attempt;
      _quizBadgesEarned = newlyEarned;
      _quizLoading = false;
    });
  }

  /// Reshuffled retry after a failed attempt — same rule as the standalone
  /// quiz flow this replaced (UC-05a).
  Future<void> _retryQuiz() async {
    setState(() {
      _completedAttempt = null;
      _quizBadgesEarned = [];
    });
    await _startQuiz();
  }

  Future<void> _openDirections() async {
    // Google Maps rather than OSM here specifically — read-only external
    // link a user taps to navigate, not an embedded map/SDK, so it's fine
    // alongside the OSM-based in-app map (see PROJECT_CONTEXT.md §2).
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${widget.destination.latitude},${widget.destination.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final checkInController = context.watch<CheckInController>();
    final quizController = context.watch<QuizController>();
    final isCheckedIn = checkInController.history.any(
      (c) => c.destinationId == destination.id,
    );

    return Scaffold(
      appBar: AppHeader.pushed(title: destination.name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QuizCard(
              isCheckedIn: isCheckedIn,
              loading: _quizLoading,
              completedAttempt: _completedAttempt,
              badgesEarned: _quizBadgesEarned,
              dailyFact: quizController.dailyFact,
              currentQuestions: quizController.currentQuestions,
              currentQuestionIndex: _currentQuestionIndex,
              selectedAnswers: _selectedAnswers,
              onSelectAnswer: _selectAnswer,
              onNextOrSubmit: _nextOrSubmit,
              onRetry: _retryQuiz,
            ),
            if (isCheckedIn && _completedAttempt == null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: AppColors.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    "You're checked in — journal draft created",
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  destination.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _ImagePlaceholder(loading: true);
                  },
                  errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(loading: false),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _CategoryChip(label: destination.category),
                const SizedBox(width: 8),
                Text(destination.state, style: AppTypography.bodySm),
              ],
            ),
            const SizedBox(height: 8),
            Text(destination.name, style: AppTypography.headlineLgMobile),
            const SizedBox(height: 8),
            Text(destination.description, style: AppTypography.bodyMd),

            const Divider(height: 40),

            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Check-in radius',
              value:
                  'Within ${destination.checkInRadiusMeters.toStringAsFixed(0)}m of the marked location · resets every 24 hours',
            ),
            const SizedBox(height: 10),
            _LocationRow(destination: destination, onGetDirections: _openDirections),

            const SizedBox(height: 22),
            CheckInButtonWidget(
              status: _checkInStatus,
              errorMessage: _checkInErrorMessage,
              onPressed: _handleCheckIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.isCheckedIn,
    required this.loading,
    required this.completedAttempt,
    required this.badgesEarned,
    required this.dailyFact,
    required this.currentQuestions,
    required this.currentQuestionIndex,
    required this.selectedAnswers,
    required this.onSelectAnswer,
    required this.onNextOrSubmit,
    required this.onRetry,
  });

  final bool isCheckedIn;
  final bool loading;
  final QuizAttemptModel? completedAttempt;
  final List<BadgeModel> badgesEarned;
  final CulturalFactModel? dailyFact;
  final List<QuizQuestionModel> currentQuestions;
  final int currentQuestionIndex;
  final List<int?> selectedAnswers;
  final ValueChanged<int> onSelectAnswer;
  final VoidCallback onNextOrSubmit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (completedAttempt != null) {
      return _ResultCard(
        attempt: completedAttempt!,
        badgesEarned: badgesEarned,
        dailyFact: dailyFact,
        onRetry: onRetry,
      );
    }
    if (!isCheckedIn) {
      return const _LockedCard();
    }
    // QuizController is a single shared instance — its currentQuestions
    // can transiently reflect a different destination (or an in-flight
    // reshuffle) for a frame or two around the async startQuiz() call.
    // Only render the active quiz once this screen's own selectedAnswers
    // list has actually been resized to match, or currentIndex/answers
    // indexing below can hit a RangeError on an effectively-empty list.
    if (loading || currentQuestions.isEmpty || selectedAnswers.length != currentQuestions.length) {
      return const _LoadingCard();
    }
    return _ActiveCard(
      questions: currentQuestions,
      currentIndex: currentQuestionIndex,
      selectedAnswers: selectedAnswers,
      onSelectAnswer: onSelectAnswer,
      onNextOrSubmit: onNextOrSubmit,
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineVariant, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: const Icon(Icons.lock_outline, size: 17, color: AppColors.outline),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination quiz', style: AppTypography.headlineSm.copyWith(fontSize: 14.5)),
                Text('5 questions · check in to unlock', style: AppTypography.bodySm.copyWith(color: AppColors.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainerTint,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: const Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryContainer),
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.questions,
    required this.currentIndex,
    required this.selectedAnswers,
    required this.onSelectAnswer,
    required this.onNextOrSubmit,
  });

  final List<QuizQuestionModel> questions;
  final int currentIndex;
  final List<int?> selectedAnswers;
  final ValueChanged<int> onSelectAnswer;
  final VoidCallback onNextOrSubmit;

  @override
  Widget build(BuildContext context) {
    final question = questions[currentIndex];
    final isLast = currentIndex == questions.length - 1;
    final hasAnswer = selectedAnswers[currentIndex] != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainerTint,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: const Icon(Icons.quiz_outlined, size: 17, color: AppColors.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destination quiz', style: AppTypography.headlineSm.copyWith(fontSize: 14.5)),
                    Text(
                      'Question ${currentIndex + 1} of ${questions.length}',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onPrimaryContainer, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < questions.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < currentIndex
                          ? AppColors.primary
                          : i == currentIndex
                          ? AppColors.onPrimaryContainer
                          : AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            question.questionText,
            style: AppTypography.headlineSm.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _QuizOption(
                label: question.options[i],
                selected: selectedAnswers[currentIndex] == i,
                onTap: () => onSelectAnswer(i),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasAnswer ? onNextOrSubmit : null,
              child: Text(isLast ? 'Submit answers' : 'Next question'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(color: selected ? AppColors.primary : AppColors.outline, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.circle, size: 8, color: AppColors.onPrimary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.attempt,
    required this.badgesEarned,
    required this.dailyFact,
    required this.onRetry,
  });

  final QuizAttemptModel attempt;
  final List<BadgeModel> badgesEarned;
  final CulturalFactModel? dailyFact;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainerTint,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  attempt.passed ? Icons.emoji_events : Icons.replay_circle_filled,
                  color: AppColors.onSecondaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attempt.passed
                          ? 'Quiz passed — ${attempt.score} of ${attempt.totalQuestions}'
                          : 'Not quite there — ${attempt.score} of ${attempt.totalQuestions}',
                      style: AppTypography.headlineSm.copyWith(fontSize: 15),
                    ),
                    Text(
                      '${attempt.scorePercentage.toStringAsFixed(0)}% correct',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (badgesEarned.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final badge in badgesEarned)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 14, color: AppColors.onSecondaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      'Badge unlocked — ${badge.name}',
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
          ],
          if (dailyFact != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 17, color: AppColors.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CULTURAL FACT OF THE DAY',
                          style: AppTypography.labelSm.copyWith(color: AppColors.onSecondaryContainer, fontSize: 10),
                        ),
                        const SizedBox(height: 3),
                        Text(dailyFact!.factText, style: AppTypography.bodySm.copyWith(color: AppColors.onSurface)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!attempt.passed) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryContainerTint,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryContainer),
              )
            : const Icon(Icons.image_outlined, size: 48, color: AppColors.primaryContainer),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainerTint,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.onPrimaryContainer),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppTypography.labelSm.copyWith(fontSize: 10.5)),
                const SizedBox(height: 3),
                Text(value, style: AppTypography.bodySm.copyWith(color: AppColors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.destination, required this.onGetDirections});

  final DestinationModel destination;
  final VoidCallback onGetDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.map_outlined, color: AppColors.primaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOCATION', style: AppTypography.labelSm.copyWith(fontSize: 10.5)),
                const SizedBox(height: 3),
                Text(
                  "${destination.latitude.toStringAsFixed(4)}° N, ${destination.longitude.toStringAsFixed(4)}° E · ${destination.state}",
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onGetDirections,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: AppTypography.labelSm,
                    side: const BorderSide(color: AppColors.outline, width: 1.5),
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 15),
                  label: const Text('Get directions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
