import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              if (icon != null) ...[
                const Spacer(),
                Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
