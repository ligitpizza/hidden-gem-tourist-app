import 'package:flutter/material.dart';

import '../../model/map_destination.dart';
import 'category_style.dart';

/// Marker-tap detail popup (FR1.2). flutter_map has no built-in popup
/// widget, so this is shown via `showModalBottomSheet`. Kept compact
/// (NFR3): name, category, description, and images or a placeholder (E2)
/// — nothing else.
class DestinationPopupSheet extends StatelessWidget {
  const DestinationPopupSheet({super.key, required this.destination});

  final MapDestination destination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(destination.category), color: categoryColor(destination.category)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(destination.name, style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (destination.imageUrls.isEmpty)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: destination.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    destination.imageUrls[index],
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(destination.description),
        ],
      ),
    );
  }
}
