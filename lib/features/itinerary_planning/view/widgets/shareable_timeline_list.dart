import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../model/itinerary_stop.dart';
import 'day_grouping.dart';

/// The day-grouped stop-by-stop list rendered into exported itinerary
/// images — shared between Route Optimized's and Day Trip's shareable
/// cards so both exports show the same destinations/timeline, not just a
/// route summary.
class ShareableTimelineList extends StatelessWidget {
  final List<ItineraryStop> timeline;
  const ShareableTimelineList({super.key, required this.timeline});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final day in groupStopsByDay(timeline)) ...[
          if (day.showHeader) ...[
            if (day.dayIndex > 0) const SizedBox(height: 12),
            Text(
              'DAY ${day.dayIndex + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primarySeed,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (var i = 0; i < day.stops.length; i++)
            _ShareableTimelineRow(
              stop: day.stops[i],
              isLast: i == day.stops.length - 1,
            ),
        ],
      ],
    );
  }
}

/// A simplified, non-interactive rendering of a timeline stop for exported
/// images — same information as the live day-trip page's timeline entry,
/// without the map-marker travel icon row (kept compact for export).
class _ShareableTimelineRow extends StatelessWidget {
  final ItineraryStop stop;
  final bool isLast;
  const _ShareableTimelineRow({required this.stop, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final dotColor = stop.isMainDestination ? AppTheme.primarySeed : AppTheme.gemGold;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stop.isMainDestination ? dotColor : Colors.white,
              border: Border.all(color: dotColor, width: 2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stop.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stop.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (stop.meta != null)
                  Text(
                    stop.meta!,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
