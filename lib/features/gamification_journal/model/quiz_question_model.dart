class QuizQuestionModel {
  final String id;
  final String destinationId;
  final String category;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;

  QuizQuestionModel({
    required this.id,
    required this.destinationId,
    required this.category,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      id: json['id'] as String,
      destinationId: json['destination_id'] as String,
      category: json['category'] as String,
      questionText: json['question_text'] as String,
      options: List<String>.from(json['options'] as List),
      correctOptionIndex: json['correct_option_index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination_id': destinationId,
      'category': category,
      'question_text': questionText,
      'options': options,
      'correct_option_index': correctOptionIndex,
    };
  }
}
