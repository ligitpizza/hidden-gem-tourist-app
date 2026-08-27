import 'package:flutter/material.dart';

import '../../../../shared/models/destination.dart';
import '../../model/hidden_gem_feed_item.dart';

IconData iconForHiddenGemCategory(DestinationCategory category) {
  switch (category) {
    case DestinationCategory.attraction:
      return Icons.explore_outlined;
    case DestinationCategory.heritageSite:
      return Icons.account_balance_outlined;
    case DestinationCategory.museum:
      return Icons.museum_outlined;
    case DestinationCategory.viewpoint:
      return Icons.landscape_outlined;
    case DestinationCategory.park:
      return Icons.park_outlined;
    case DestinationCategory.beach:
      return Icons.beach_access_outlined;
    case DestinationCategory.waterfall:
      return Icons.water_outlined;
    case DestinationCategory.cafe:
      return Icons.local_cafe_outlined;
    case DestinationCategory.restaurant:
      return Icons.restaurant_outlined;
    case DestinationCategory.craft:
      return Icons.brush_outlined;
    case DestinationCategory.art:
      return Icons.palette_outlined;
    case DestinationCategory.island:
      return Icons.deck_outlined;
    case DestinationCategory.mountain:
      return Icons.terrain_outlined;
    case DestinationCategory.themePark:
      return Icons.attractions_outlined;
    case DestinationCategory.mall:
      return Icons.storefront_outlined;
  }
}

/// One row on a ranked hidden-gem list (used by both the "View All Top
/// Matches" and "Trending Now" list screens).
class HiddenGemListTile extends StatelessWidget {
  final HiddenGemFeedItem item;
  final VoidCallback onTap;

  const HiddenGemListTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(iconForHiddenGemCategory(item.category), color: colorScheme.onPrimaryContainer),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${item.category.label} • ${item.location}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${item.personalizedPercent}%', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (item.isTrending)
              Text(
                '+${item.trendPercent}%',
                style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}
