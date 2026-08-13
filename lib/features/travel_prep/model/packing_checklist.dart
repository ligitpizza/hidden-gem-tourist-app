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
