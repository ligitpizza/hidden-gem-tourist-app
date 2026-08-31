import '../../../shared/models/destination.dart';

/// One entry in "Recently Viewed" on the Travel Pulse screen — a place the
/// tourist has looked at, with when they last looked at it. Backed by
/// `recently_viewed_places()`, which already dedupes to the most recent
/// view per place.
class RecentlyViewedPlace {
  final String id;
  final String name;
  final DestinationCategory category;
  final String location;
  final DateTime viewedAt;

  const RecentlyViewedPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.viewedAt,
  });

  factory RecentlyViewedPlace.fromRow(Map<String, dynamic> row) {
    return RecentlyViewedPlace(
      id: row['place_id'] as String,
      name: row['name'] as String,
      category: destinationCategoryFromDb(row['category'] as String),
      location: (row['city'] as String?)?.trim().isNotEmpty == true
          ? row['city'] as String
          : (row['state'] as String? ?? ''),
      viewedAt: DateTime.parse(row['viewed_at'] as String),
    );
  }

  /// A short "2h ago" / "Yesterday" / "3 days ago" label, matching the
  /// Travel Pulse mockup's relative-time style.
  String get relativeTimeLabel {
    final diff = DateTime.now().difference(viewedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
