import 'package:flutter/foundation.dart';

import '../model/cultural_fact_model.dart';
import '../model/quiz_attempt_model.dart';
import '../model/quiz_question_model.dart';
import '../services/mock/mock_quiz_service.dart';

enum QuizStatus { idle, loading, inProgress, submitted, error }

class QuizController extends ChangeNotifier {
  QuizController({required this.userId, MockQuizService? service})
    : _service = service ?? MockQuizService();

  final String userId;
  final MockQuizService _service;

  List<QuizQuestionModel> currentQuestions = [];
  List<QuizAttemptModel> attemptHistory = [];
  QuizAttemptModel? lastAttempt;
  CulturalFactModel? dailyFact;
  int completedQuizCount = 0;

  QuizStatus status = QuizStatus.idle;
  String? errorMessage;

  Future<void> loadDailyFact() async {
    dailyFact = await _service.fetchDailyFact();
    notifyListeners();
  }

  Future<void> loadHistory() async {
    attemptHistory = await _service.fetchAttemptHistory(userId);
    completedQuizCount = await _service.countCompletedQuizzes(userId);
    notifyListeners();
  }

  Future<void> startQuiz(String destinationId, {int questionCount = 5}) async {
    status = QuizStatus.loading;
    notifyListeners();

    currentQuestions = await _service.fetchQuizForDestination(
      destinationId,
      count: questionCount,
    );
    lastAttempt = null;
    status = QuizStatus.inProgress;
    notifyListeners();
  }

  Future<QuizAttemptModel> submitAnswers({
    required String destinationId,
    required List<int> selectedOptionIndexes,
  }) async {
    status = QuizStatus.loading;
    notifyListeners();

    try {
      final attempt = await _service.submitAttempt(
        userId: userId,
        destinationId: destinationId,
        questions: currentQuestions,
        selectedOptionIndexes: selectedOptionIndexes,
      );

      lastAttempt = attempt;
      status = QuizStatus.submitted;
      await loadHistory();
      return attempt;
    } catch (_) {
      status = QuizStatus.error;
      errorMessage = 'Could not submit your answers. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  /// Call after a failed attempt to fetch a fresh, reshuffled set of
  /// questions for the same destination, matching the doc's reattempt rule.
  Future<void> retryQuiz(String destinationId, {int questionCount = 5}) =>
      startQuiz(destinationId, questionCount: questionCount);
}
