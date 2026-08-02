import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controller/itinerary_planner_controller.dart';
import '../model/itinerary_stop.dart';
import 'widgets/badge_pill.dart';
import 'widgets/route_map_view.dart';

class DayTripScreen extends ConsumerWidget {
  const DayTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(itineraryPlannerControllerProvider);
    final plan = controller.plan;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        title: const Text('Your Day Trip'),
      ),
      body: plan == null
          ? const Center(child: Text('Generate an itinerary first.'))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  if (controller.otherPathId != null)
                    _AlternateRouteBanner(
                      onTap: () {
                        ref
                            .read(itineraryPlannerControllerProvider)
                            .selectPath(controller.otherPathId!);
                        if (context.canPop()) context.pop();
                      },
                    ),
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      RouteMapView(
                        height: 160,
                        markers: [
                          for (final destination in plan.destinations)
                            MapMarkerSpec(
                              point: destination.location,
                              color: colorScheme.primary,
                            ),
                          for (final gem in controller.selectedRoutePath?.hiddenGems ?? const [])
                            MapMarkerSpec(
                              point: gem.location,
                              color: const Color(0xFFC9A227),
                              icon: Icons.diamond,
                            ),
                        ],
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'MAP VIEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < controller.timeline.length; i++)
                    _TimelineEntry(
                      stop: controller.timeline[i],
                      isLast: i == controller.timeline.length - 1,
                    ),
                ],
              ),
            ),
      floatingActionButton: plan == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Export Itinerary'),
              onPressed: () async {
                await controller.exportTimelineAsPdf();
              },
            ),
    );
  }
}

class _AlternateRouteBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AlternateRouteBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alt_route, size: 18),
          SizedBox(width: 8),
          Text('Alternate Route Available', style: TextStyle(fontWeight: FontWeight.w600)),
          Spacer(),
          Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ItineraryStop stop;
  final bool isLast;

  const _TimelineEntry({required this.stop, required this.isLast});

  Color _dotColor(ColorScheme colorScheme) {
    if (stop.isMainDestination) return colorScheme.primary;
    return const Color(0xFFC9A227);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dotColor = _dotColor(colorScheme);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stop.isMainDestination ? dotColor : Colors.white,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: colorScheme.outlineVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              stop.time,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            BadgePill(badge: stop.badge),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stop.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (stop.meta != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            stop.meta!,
                            style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          stop.description,
                          style: TextStyle(fontSize: 12.5, color: colorScheme.onSurface),
                        ),
                        if (stop.imagePlaceholderCount > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (var i = 0; i < stop.imagePlaceholderCount; i++)
                                Padding(
                                  padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                                  child: Container(
                                    width: 64,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (stop.travelToNext != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            stop.travelToNext!,
                            style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
