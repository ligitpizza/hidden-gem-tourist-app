/// One question's outcome within a completed attempt — lets the result
/// screen show exactly which answers were right/wrong and what the
/// correct option was, instead of only a final score.
class QuizAnswerRecord {
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final int selectedOptionIndex;

  QuizAnswerRecord({
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.selectedOptionIndex,
  });

  bool get isCorrect => selectedOptionIndex == correctOptionIndex;

  factory QuizAnswerRecord.fromJson(Map<String, dynamic> json) {
    return QuizAnswerRecord(
      questionText: json['question_text'] as String,
      options: List<String>.from(json['options'] as List),
      correctOptionIndex: json['correct_option_index'] as int,
      selectedOptionIndex: json['selected_option_index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': questionText,
      'options': options,
      'correct_option_index': correctOptionIndex,
      'selected_option_index': selectedOptionIndex,
    };
  }
}

class QuizAttemptModel {
  final String id;
  final String userId;
  final String destinationId;
  final int score;
  final int totalQuestions;
  final bool passed;
  final DateTime attemptedAt;

  /// Per-question detail for the "review your answers" view. Empty for
  /// attempts loaded from a source that doesn't carry it.
  final List<QuizAnswerRecord> answers;

  QuizAttemptModel({
    required this.id,
    required this.userId,
    required this.destinationId,
    required this.score,
    required this.totalQuestions,
    required this.passed,
    required this.attemptedAt,
    this.answers = const [],
  });

  double get scorePercentage =>
      totalQuestions == 0 ? 0 : (score / totalQuestions) * 100;

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    return QuizAttemptModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      destinationId: json['destination_id'] as String,
      score: json['score'] as int,
      totalQuestions: json['total_questions'] as int,
      passed: json['passed'] as bool,
      attemptedAt: DateTime.parse(json['attempted_at'] as String),
      answers: (json['answers'] as List<dynamic>? ?? [])
          .map((a) => QuizAnswerRecord.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'destination_id': destinationId,
      'score': score,
      'total_questions': totalQuestions,
      'passed': passed,
      'attempted_at': attemptedAt.toIso8601String(),
      'answers': answers.map((a) => a.toJson()).toList(),
    };
  }
}
