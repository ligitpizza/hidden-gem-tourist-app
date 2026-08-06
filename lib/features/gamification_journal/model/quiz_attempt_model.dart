class QuizAttemptModel {
  final String id;
  final String userId;
  final String destinationId;
  final int score;
  final int totalQuestions;
  final bool passed;
  final DateTime attemptedAt;

  QuizAttemptModel({
    required this.id,
    required this.userId,
    required this.destinationId,
    required this.score,
    required this.totalQuestions,
    required this.passed,
    required this.attemptedAt,
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
    };
  }
}
