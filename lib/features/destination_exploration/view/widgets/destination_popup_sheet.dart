import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../gamification_journal/controller/checkin_controller.dart';
import '../../../gamification_journal/model/destination_model.dart';
import '../../../gamification_journal/view/checkin/destination_detail_screen.dart';
import '../../model/map_destination.dart';
import 'category_style.dart';

/// Marker-tap detail popup (FR1.2), shown only in Explore mode — Comparison
/// mode's marker tap toggles selection directly instead (see
/// DestinationMapScreen). flutter_map has no built-in popup widget, so this
/// is shown via `showModalBottomSheet`. Kept compact (NFR3): name, category,
/// description, a tappable image (or placeholder, E2), and a "View Details"
/// button — both open the full destination detail page, since a custom
/// double-tap-on-marker gesture proved unreliable on real touchscreens.
class DestinationPopupSheet extends StatelessWidget {
  const DestinationPopupSheet({super.key, required this.destination});

  final MapDestination destination;

  void _openDetail(BuildContext context) {
    // The detail screen's badge-progress lookup reads
    // CheckInController.destinations, which is otherwise only populated by
    // visiting the Journal tab — make sure it's loaded so badge matching
    // works when the detail screen is reached from this map instead.
    final checkInController = context.read<CheckInController>();
    if (checkInController.destinations.isEmpty) {
      unawaited(checkInController.loadDestinations().catchError((_) {}));
    }

    // Prefer the already-loaded DestinationModel (correct real state,
    // resolved via the destinations table's city column) over
    // fromMapDestination()'s bare conversion, which has no city to work
    // from and silently defaults to 'Penang' for every destination.
    DestinationModel? resolved;
    for (final d in checkInController.destinations) {
      if (d.id == destination.id) {
        resolved = d;
        break;
      }
    }

    final navigator = Navigator.of(context);
    navigator.pop(); // close this popup sheet first
    navigator.push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(
          destination: resolved ?? DestinationModel.fromMapDestination(destination),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (destination.imageUrls.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey),
        ),
      );
    }

    // A single image previously sat in a horizontally-scrolling list sized
    // to its own 160px tile, leaving a large blank gap on the right since
    // nothing else was there to scroll to — stretch it to fill the width
    // instead. Multiple images keep the horizontal strip, where that
    // fixed tile width is what makes scrolling between them make sense.
    if (destination.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          destination.imageUrls.first,
          width: double.infinity,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped in a scroll view (paired with isScrollControlled: true on the
    // showModalBottomSheet call) so a long description grows the sheet up
    // to the screen height and then scrolls, instead of overflowing past
    // the bottom of a fixed-height sheet.
    return SingleChildScrollView(
      child: Padding(
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
            GestureDetector(
              onTap: () => _openDetail(context),
              child: _buildImage(context),
            ),
            const SizedBox(height: 12),
            Text(destination.description),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openDetail(context),
              icon: const Icon(Icons.info_outline),
              label: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }
}
