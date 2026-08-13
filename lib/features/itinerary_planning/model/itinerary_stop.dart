/// How a timeline stop should be flagged in the UI.
enum StopBadge { selected, recommended, localGem, mealBreak }

extension StopBadgeX on StopBadge {
  String get label {
    switch (this) {
      case StopBadge.selected:
        return 'SELECTED';
      case StopBadge.recommended:
        return 'RECOMMENDED';
      case StopBadge.localGem:
        return 'LOCAL GEM';
      case StopBadge.mealBreak:
        return 'BREAK';
    }
  }
}

/// A single entry in the day-trip timeline (page 3): either one of the
/// traveller's chosen destinations, a hidden gem inserted along the way, or
/// a scheduled meal break. [dayIndex] (0-based) groups stops when the trip
/// spans more than one day.
class ItineraryStop {
  final String time;
  final String title;
  final String description;
  final String? meta;
  final StopBadge badge;
  final bool isMainDestination;
  final int imagePlaceholderCount;
  final String? travelToNext;
  final int dayIndex;

  const ItineraryStop({
    required this.time,
    required this.title,
    required this.description,
    this.meta,
    required this.badge,
    required this.isMainDestination,
    this.imagePlaceholderCount = 0,
    this.travelToNext,
    this.dayIndex = 0,
  });

  ItineraryStop copyWith({String? travelToNext}) {
    return ItineraryStop(
      time: time,
      title: title,
      description: description,
      meta: meta,
      badge: badge,
      isMainDestination: isMainDestination,
      imagePlaceholderCount: imagePlaceholderCount,
      travelToNext: travelToNext ?? this.travelToNext,
      dayIndex: dayIndex,
    );
  }
}
