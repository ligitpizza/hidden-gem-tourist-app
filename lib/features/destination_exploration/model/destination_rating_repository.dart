import 'package:supabase_flutter/supabase_flutter.dart';

import 'keyword_tagging_engine.dart';
import 'rating_summary.dart';

/// Rating submission and aggregation for Feature 4. Submission computes
/// generated_tags via KeywordTaggingEngine (FR4.2, FR4.3); aggregation is
/// delegated to the pure summarizeRatings function above so it's testable
/// without a network call.
class DestinationRatingRepository {
  Future<void> submitRating({
    required String destinationId,
    required int difficultyScore,
    required String reviewText,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('A signed-in user is required.');
    }

    final tags = KeywordTaggingEngine.tagsFor(reviewText);
    await Supabase.instance.client.from('destination_ratings').insert({
      'destination_id': destinationId,
      'user_id': userId,
      'difficulty_score': difficultyScore,
      'review_text': reviewText,
      'generated_tags': tags,
    });
  }

  Future<RatingSummary> fetchRatingSummary(String destinationId) async {
    final rows = await Supabase.instance.client
        .from('destination_ratings')
        .select()
        .eq('destination_id', destinationId);

    final ratings = rows
        .map((row) => (
              difficultyScore: (row['difficulty_score'] as num).toInt(),
              tags: ((row['generated_tags'] as List?)?.whereType<String>().toList()) ??
                  const <String>[],
            ))
        .toList();

    return summarizeRatings(ratings);
  }

  /// Writes the aggregated rating results back onto the `destinations` row's
  /// `difficulty_level`/`accessibility_tags` columns (reserved for this by
  /// Feature 3's migration) so Feature 3's comparison table stops showing
  /// permanently-null difficulty/accessibility for rated destinations.
  Future<void> updateDestinationAggregates(String destinationId, RatingSummary summary) async {
    await Supabase.instance.client.from('destinations').update({
      'difficulty_level': summary.difficultyBucket.name,
      'accessibility_tags': summary.topTags.map((t) => t.tag).toList(),
    }).eq('id', destinationId);
  }

  Future<List<DestinationReview>> fetchReviews(
    String destinationId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await Supabase.instance.client
        .from('destination_ratings')
        .select()
        .eq('destination_id', destinationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows
        .map((row) => DestinationReview(
              reviewText: row['review_text'] as String,
              difficultyScore: (row['difficulty_score'] as num).toInt(),
              generatedTags:
                  ((row['generated_tags'] as List?)?.whereType<String>().toList()) ?? const [],
              createdAt: DateTime.parse(row['created_at'] as String),
            ))
        .toList();
  }
}
