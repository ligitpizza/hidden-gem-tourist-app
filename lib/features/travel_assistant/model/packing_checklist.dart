class PackingChecklistItem {
  const PackingChecklistItem({
    required this.id,
    required this.name,
    required this.reason,
  });

  final String id;
  final String name;
  final String reason;
}

class PackingChecklistSection {
  const PackingChecklistSection({required this.name, required this.items});

  final String name;
  final List<PackingChecklistItem> items;
}

class PackingTripDateRange {
  PackingTripDateRange({required DateTime start, required DateTime end})
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError.value(end, 'end', 'must not be before start');
    }
  }

  final DateTime start;
  final DateTime end;

  bool get isSingleDay => start.isAtSameMomentAs(end);
}
