import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/cultural_fact_model.dart';
import '../../model/quiz_attempt_model.dart';
import '../../model/quiz_question_model.dart';

/// Backs the cultural quiz challenge against Supabase.
///
/// Questions and cultural facts are shared reference content, so they're
/// loaded from the real `journal_quiz_questions` / `journal_cultural_facts`
/// tables and cached in memory (same pattern as MockCheckInService's
/// destination cache). Attempts are written to `journal_quiz_attempts` so
/// they (and the badge progress derived from them) survive an app restart.
/// Tests bypass Supabase entirely by passing [seedAttempts] — even an
/// empty list — which switches attempt storage to a plain in-memory store
/// instead, same as [MockCheckInService]'s seedCheckIns.
class MockQuizService {
  MockQuizService({List<QuizAttemptModel>? seedAttempts})
    : _attempts = List.of(seedAttempts ?? []),
      _useMockStorage = seedAttempts != null;

  static const double passThresholdPercent = 60;

  final List<QuizAttemptModel> _attempts;
  final bool _useMockStorage;
  int _idCounter = 0;

  final Random _random = Random();

  List<QuizQuestionModel> _questionBank = [];
  bool _questionBankLoaded = false;

  List<CulturalFactModel> _culturalFacts = [];
  bool _culturalFactsLoaded = false;

  Future<void> _ensureQuestionBankLoaded() async {
    if (_questionBankLoaded) return;
    try {
      final rows = await Supabase.instance.client.from('journal_quiz_questions').select();
      _questionBank = rows.map((row) => QuizQuestionModel.fromJson(row)).toList();
      _questionBankLoaded = true;
    } catch (_) {
      // Leave empty and _questionBankLoaded false so a later call retries.
    }
  }

  Future<void> _ensureCulturalFactsLoaded() async {
    if (_culturalFactsLoaded) return;
    try {
      final rows = await Supabase.instance.client.from('journal_cultural_facts').select();
      _culturalFacts = rows.map((row) => CulturalFactModel.fromJson(row)).toList();
      _culturalFactsLoaded = true;
    } catch (_) {
      // Leave empty and _culturalFactsLoaded false so a later call retries.
    }
  }

  /// Returns up to [count] random questions for a destination. Order is
  /// reshuffled on every call so reattempts don't repeat the same set.
  Future<List<QuizQuestionModel>> fetchQuizForDestination(
    String destinationId, {
    int count = 5,
  }) async {
    await _ensureQuestionBankLoaded();

    final available = _questionBank.where((q) => q.destinationId == destinationId).toList()
      ..shuffle(_random);

    return available.take(count).toList();
  }

  Future<CulturalFactModel?> fetchDailyFact() async {
    await _ensureCulturalFactsLoaded();
    if (_culturalFacts.isEmpty) return null;
    final dayIndex = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    return _culturalFacts[dayIndex % _culturalFacts.length];
  }

  /// Scores an attempt against the given questions and stores it.
  /// [selectedOptionIndexes] must be the same length and order as [questions].
  Future<QuizAttemptModel> submitAttempt({
    required String userId,
    required String destinationId,
    required List<QuizQuestionModel> questions,
    required List<int> selectedOptionIndexes,
  }) async {
    if (questions.length != selectedOptionIndexes.length) {
      throw ArgumentError('Answers must match the number of questions.');
    }

    var score = 0;
    final answers = <QuizAnswerRecord>[];
    for (var i = 0; i < questions.length; i++) {
      final isCorrect = questions[i].correctOptionIndex == selectedOptionIndexes[i];
      if (isCorrect) score++;
      answers.add(
        QuizAnswerRecord(
          questionText: questions[i].questionText,
          options: questions[i].options,
          correctOptionIndex: questions[i].correctOptionIndex,
          selectedOptionIndex: selectedOptionIndexes[i],
        ),
      );
    }

    final percentage = questions.isEmpty ? 0 : (score / questions.length) * 100;
    final passed = percentage >= passThresholdPercent;

    if (_useMockStorage) {
      final attempt = QuizAttemptModel(
        id: 'a${(_idCounter++).toString().padLeft(4, '0')}',
        userId: userId,
        destinationId: destinationId,
        score: score,
        totalQuestions: questions.length,
        passed: passed,
        attemptedAt: DateTime.now(),
        answers: answers,
      );
      _attempts.add(attempt);
      return attempt;
    }

    final row = await Supabase.instance.client
        .from('journal_quiz_attempts')
        .insert({
          'user_id': userId,
          'destination_id': destinationId,
          'score': score,
          'total_questions': questions.length,
          'passed': passed,
          'answers': answers.map((a) => a.toJson()).toList(),
        })
        .select()
        .single();

    return QuizAttemptModel.fromJson(row);
  }

  Future<List<QuizAttemptModel>> fetchAttemptHistory(String userId) async {
    if (_useMockStorage) {
      return _attempts.where((a) => a.userId == userId).toList()
        ..sort((a, b) => b.attemptedAt.compareTo(a.attemptedAt));
    }

    final rows = await Supabase.instance.client
        .from('journal_quiz_attempts')
        .select()
        .eq('user_id', userId)
        .order('attempted_at', ascending: false);
    return rows.map((r) => QuizAttemptModel.fromJson(r)).toList();
  }

  /// Counts completed quizzes for badge eligibility. Only the first passed
  /// attempt per destination counts, so retrying a failed quiz repeatedly
  /// doesn't inflate the "5 quizzes completed" badge progress.
  Future<int> countCompletedQuizzes(String userId) async {
    if (_useMockStorage) {
      return _attempts
          .where((a) => a.userId == userId && a.passed)
          .map((a) => a.destinationId)
          .toSet()
          .length;
    }

    final rows = await Supabase.instance.client
        .from('journal_quiz_attempts')
        .select('destination_id')
        .eq('user_id', userId)
        .eq('passed', true);
    return rows.map((r) => r['destination_id'] as String).toSet().length;
  }

  /// Counts full-marks attempts (score == totalQuestions) for the
  /// quizPerfectScore badge criteria. Every perfect attempt counts, even
  /// repeats on the same destination, since scoring full marks again is
  /// still a genuine achievement. Compared client-side since PostgREST
  /// can't filter one column against another directly.
  Future<int> countPerfectQuizzes(String userId) async {
    if (_useMockStorage) {
      return _attempts
          .where((a) => a.userId == userId && a.score == a.totalQuestions && a.totalQuestions > 0)
          .length;
    }

    final rows = await Supabase.instance.client
        .from('journal_quiz_attempts')
        .select('score, total_questions')
        .eq('user_id', userId);
    return rows
        .where((r) => (r['total_questions'] as int) > 0 && r['score'] == r['total_questions'])
        .length;
  }
}
