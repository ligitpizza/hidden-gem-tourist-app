import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/check_in_button.dart';
import '../../../destination_exploration/view/widgets/ratings_section.dart';
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
      case BadgeCriteriaType.quizPerfectScore:
        return quizContext;
      case BadgeCriteriaType.economicImpactRM:
        return false;
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
    BadgeCriteriaType.quizPerfectScore =>
      'Score full marks on $remaining more quiz${remaining == 1 ? '' : 'zes'} to achieve ${badge.name}',
    BadgeCriteriaType.economicImpactRM =>
      'Log RM$remaining more in local spending to achieve ${badge.name}',
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
      economicImpactTotalRM: journalController.entries.fold<double>(
        0,
        (sum, e) => sum + e.totalSpendingRM,
      ),
    );

    if (!mounted) return;

    if (badgeController.newlyEarned.isNotEmpty) {
      for (final badge in badgeController.newlyEarned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.of(context).primaryContainer,
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
            backgroundColor: AppColors.of(context).surfaceContainerHigh,
            content: Text(progressMessage, style: TextStyle(color: AppColors.of(context).onSurface)),
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
    final journalController = context.read<JournalController>();

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
      economicImpactTotalRM: journalController.entries.fold<double>(
        0,
        (sum, e) => sum + e.totalSpendingRM,
      ),
      perfectQuizCount: quizController.perfectQuizCount,
    );

    final newlyEarned = List.of(badgeController.newlyEarned);
    badgeController.clearNewlyEarned();

    if (!mounted) return;

    if (newlyEarned.isNotEmpty) {
      for (final badge in newlyEarned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.of(context).primaryContainer,
            content: Text('Badge unlocked: ${badge.name}'),
          ),
        );
      }
    } else {
      final progressMessage = _nearestBadgeProgressMessage(badgeController, quizContext: true);
      if (progressMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.of(context).surfaceContainerHigh,
            content: Text(progressMessage, style: TextStyle(color: AppColors.of(context).onSurface)),
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
    //
    // Uses the "search" endpoint (drops a pin at the exact coordinate)
    // rather than "dir" (routes from the Tourist's current location) —
    // the dir endpoint was landing people in the wrong general area
    // whenever the browser/OS couldn't resolve a precise starting point,
    // and a route/duration estimate isn't the point here anyway. Both are
    // free, documented URL schemes — no Google Maps API key needed.
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${widget.destination.latitude},${widget.destination.longitude}',
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
                  Icon(Icons.check_circle, size: 16, color: AppColors.of(context).onPrimaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    "You're checked in — journal draft created",
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.of(context).onPrimaryContainer,
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
            const Divider(height: 40),
            RatingsSection(
              destinationId: destination.id,
              destinationName: destination.name,
              destinationImageUrl: destination.imageUrl,
              region: destination.state,
              isCheckedIn: isCheckedIn,
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
        color: AppColors.of(context).surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.of(context).outlineVariant, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.of(context).surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: Icon(Icons.lock_outline, size: 17, color: AppColors.of(context).outline),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination quiz', style: AppTypography.headlineSm.copyWith(fontSize: 14.5)),
                Text('5 questions · check in to unlock', style: AppTypography.bodySm.copyWith(color: AppColors.of(context).outline)),
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
        color: AppColors.of(context).primaryContainerTint,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.of(context).primaryContainer),
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
        color: AppColors.of(context).primaryContainerTint,
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
                  color: AppColors.of(context).primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Icon(Icons.quiz_outlined, size: 17, color: AppColors.of(context).onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destination quiz', style: AppTypography.headlineSm.copyWith(fontSize: 14.5)),
                    Text(
                      'Question ${currentIndex + 1} of ${questions.length}',
                      style: AppTypography.bodySm.copyWith(color: AppColors.of(context).onPrimaryContainer, fontWeight: FontWeight.w600),
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
                          ? AppColors.of(context).primary
                          : i == currentIndex
                          ? AppColors.of(context).onPrimaryContainer
                          : AppColors.of(context).outlineVariant,
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
          color: selected ? AppColors.of(context).surfaceContainerLowest : AppColors.of(context).surfaceContainerLowest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.of(context).primary : AppColors.of(context).outlineVariant,
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
                color: selected ? AppColors.of(context).primary : Colors.transparent,
                border: Border.all(color: selected ? AppColors.of(context).primary : AppColors.of(context).outline, width: 1.5),
              ),
              child: selected
                  ? Icon(Icons.circle, size: 8, color: AppColors.of(context).onPrimary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.of(context).onSurface,
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
        color: AppColors.of(context).primaryContainerTint,
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
                decoration: BoxDecoration(
                  color: AppColors.of(context).secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  attempt.passed ? Icons.emoji_events : Icons.replay_circle_filled,
                  color: AppColors.of(context).onSecondaryContainer,
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
                  color: AppColors.of(context).secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, size: 14, color: AppColors.of(context).onSecondaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      'Badge unlocked — ${badge.name}',
                      style: AppTypography.labelSm.copyWith(color: AppColors.of(context).onSecondaryContainer),
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
                color: AppColors.of(context).surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.of(context).outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 17, color: AppColors.of(context).onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CULTURAL FACT OF THE DAY',
                          style: AppTypography.labelSm.copyWith(color: AppColors.of(context).onSecondaryContainer, fontSize: 10),
                        ),
                        const SizedBox(height: 3),
                        Text(dailyFact!.factText, style: AppTypography.bodySm.copyWith(color: AppColors.of(context).onSurface)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (attempt.answers.isNotEmpty) ...[
            const SizedBox(height: 14),
            _AnswerReview(answers: attempt.answers),
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

/// Collapsible per-question breakdown so a Tourist can see exactly which
/// answers were wrong and what the correct option actually was, instead of
/// just a final score.
class _AnswerReview extends StatefulWidget {
  const _AnswerReview({required this.answers});

  final List<QuizAnswerRecord> answers;

  @override
  State<_AnswerReview> createState() => _AnswerReviewState();
}

class _AnswerReviewState extends State<_AnswerReview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.fact_check_outlined, size: 17, color: colors.primaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review your answers',
                    style: AppTypography.labelMd.copyWith(color: colors.primaryContainer),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: colors.primaryContainer,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < widget.answers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AnswerReviewCard(index: i + 1, answer: widget.answers[i]),
            ),
        ],
      ],
    );
  }
}

class _AnswerReviewCard extends StatelessWidget {
  const _AnswerReviewCard({required this.index, required this.answer});

  final int index;
  final QuizAnswerRecord answer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: answer.isCorrect ? colors.outlineVariant : colors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                answer.isCorrect ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: answer.isCorrect ? colors.primaryContainer : colors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q$index. ${answer.questionText}',
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < answer.options.length; i++)
            _AnswerOptionRow(
              text: answer.options[i],
              isCorrectOption: i == answer.correctOptionIndex,
              isUserChoice: i == answer.selectedOptionIndex,
            ),
        ],
      ),
    );
  }
}

class _AnswerOptionRow extends StatelessWidget {
  const _AnswerOptionRow({
    required this.text,
    required this.isCorrectOption,
    required this.isUserChoice,
  });

  final String text;
  final bool isCorrectOption;
  final bool isUserChoice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Correct option always shown in green; the user's own wrong pick (if
    // different) is called out in red so both "what you picked" and "what
    // was right" are visible at a glance.
    final Color? tint = isCorrectOption
        ? colors.primaryContainer
        : (isUserChoice ? colors.error : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrectOption
                ? Icons.check
                : (isUserChoice ? Icons.close : Icons.circle_outlined),
            size: 14,
            color: tint ?? colors.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySm.copyWith(
                color: tint ?? colors.onSurfaceVariant,
                fontWeight: (isCorrectOption || isUserChoice) ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
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
      color: AppColors.of(context).primaryContainerTint,
      child: Center(
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.of(context).primaryContainer),
              )
            : Icon(Icons.image_outlined, size: 48, color: AppColors.of(context).primaryContainer),
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
        color: AppColors.of(context).primaryContainerTint,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.of(context).primaryContainer)),
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
        color: AppColors.of(context).surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.of(context).outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.of(context).onPrimaryContainer),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppTypography.labelSm.copyWith(fontSize: 10.5)),
                const SizedBox(height: 3),
                Text(value, style: AppTypography.bodySm.copyWith(color: AppColors.of(context).onSurface)),
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
        color: AppColors.of(context).surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.of(context).outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.of(context).surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.map_outlined, color: AppColors.of(context).primaryContainer),
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
                  style: AppTypography.bodySm.copyWith(color: AppColors.of(context).onSurface),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onGetDirections,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: AppTypography.labelSm,
                    side: BorderSide(color: AppColors.of(context).outline, width: 1.5),
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
