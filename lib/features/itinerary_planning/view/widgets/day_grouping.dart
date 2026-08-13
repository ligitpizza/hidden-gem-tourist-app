import '../../model/itinerary_stop.dart';

/// A contiguous run of [timeline] stops sharing one [dayIndex].
/// [showHeader] is false when the whole trip fits in a single day, so a
/// lone "Day 1" label doesn't clutter a plan that never needed one.
class DayGroup {
  final int dayIndex;
  final List<ItineraryStop> stops;
  final bool showHeader;

  const DayGroup({required this.dayIndex, required this.stops, required this.showHeader});
}

List<DayGroup> groupStopsByDay(List<ItineraryStop> timeline) {
  if (timeline.isEmpty) return const [];
  final totalDays = timeline.map((s) => s.dayIndex).toSet().length;

  final groups = <DayGroup>[];
  var currentDay = timeline.first.dayIndex;
  var buffer = <ItineraryStop>[];

  void flush() {
    if (buffer.isEmpty) return;
    groups.add(DayGroup(dayIndex: currentDay, stops: List.unmodifiable(buffer), showHeader: totalDays > 1));
    buffer = [];
  }

  for (final stop in timeline) {
    if (stop.dayIndex != currentDay) {
      flush();
      currentDay = stop.dayIndex;
    }
    buffer.add(stop);
  }
  flush();
  return groups;
}
