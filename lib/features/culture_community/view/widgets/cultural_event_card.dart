import 'package:flutter/material.dart';

import '../../model/cultural_event.dart';

class CulturalEventCard extends StatelessWidget {
  const CulturalEventCard({super.key, required this.event});

  final CulturalEvent event;

  Color _categoryColor(BuildContext context) {
    switch (event.category) {
      case CulturalEventCategory.festival:
        return Colors.deepOrange;
      case CulturalEventCategory.culturalShow:
        return Colors.deepPurple;
      case CulturalEventCategory.communityActivity:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _categoryIcon() {
    switch (event.category) {
      case CulturalEventCategory.festival:
        return Icons.celebration_outlined;
      case CulturalEventCategory.culturalShow:
        return Icons.theater_comedy_outlined;
      case CulturalEventCategory.communityActivity:
        return Icons.groups_outlined;
    }
  }

  String _dateLabel(BuildContext context) {
    final local = event.startAt.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date • $time';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categoryColor = _categoryColor(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventImage(imageUrl: event.imageUrl, icon: _categoryIcon()),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(
                      icon: _categoryIcon(),
                      label: event.category.label,
                      foreground: categoryColor,
                      background: categoryColor.withValues(alpha: 0.12),
                    ),
                    if (event.isFeatured)
                      _Tag(
                        icon: Icons.star_outline_rounded,
                        label: 'Featured',
                        foreground: colors.primary,
                        background: colors.primaryContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                _InfoRow(icon: Icons.calendar_month_outlined, text: _dateLabel(context)),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: '${event.venueName}, ${event.state}',
                ),
                const SizedBox(height: 12),
                Text(
                  event.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.imageUrl, required this.icon});

  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return _fallback(context);

    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 150,
      width: double.infinity,
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, size: 48, color: colors.primary),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
