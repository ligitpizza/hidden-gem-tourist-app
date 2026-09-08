/// A single cheer on a friend's check-in — one row per (reactor, check-in)
/// pair, enforced by a unique constraint so the same person can't stack
/// multiple reactions on the same check-in.
class ReactionModel {
  final String id;
  final String reactorId;
  final String checkInId;
  final DateTime createdAt;

  ReactionModel({
    required this.id,
    required this.reactorId,
    required this.checkInId,
    required this.createdAt,
  });

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    return ReactionModel(
      id: json['id'] as String,
      reactorId: json['reactor_id'] as String,
      checkInId: json['check_in_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
