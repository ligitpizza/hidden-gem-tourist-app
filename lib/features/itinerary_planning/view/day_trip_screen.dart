import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../controller/itinerary_planner_controller.dart';
import '../model/itinerary_stop.dart';
import 'widgets/badge_pill.dart';
import 'widgets/day_grouping.dart';
import 'widgets/route_map_view.dart';

class DayTripScreen extends ConsumerStatefulWidget {
  const DayTripScreen({super.key});

  @override
  ConsumerState<DayTripScreen> createState() => _DayTripScreenState();
}

class _DayTripScreenState extends ConsumerState<DayTripScreen> {
  bool _isExporting = false;

  /// Same technique as Route Optimized's share/download: mount the card via
  /// a temporary [OverlayEntry] positioned outside the visible viewport
  /// (not `Offstage`, which skips painting entirely and leaves the
  /// `RepaintBoundary` with no layer to capture).
  Future<Uint8List?> _captureShareCard(ItineraryPlannerController controller) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -4000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: boundaryKey,
            child: _ShareableDayTripCard(controller: controller),
          ),
        ),
      ),
    );

    try {
      overlay.insert(entry);
      await WidgetsBinding.instance.endOfFrame;

      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  Future<void> _exportAsImage(ItineraryPlannerController controller) async {
    setState(() => _isExporting = true);
    final bytes = await _captureShareCard(controller);
    if (!mounted) return;
    setState(() => _isExporting = false);
    if (bytes == null) return;

    final file = XFile.fromData(bytes, name: 'day_trip.png', mimeType: 'image/png');
    await Share.shareXFiles(
      [file],
      subject: 'My Day Trip',
      text: controller.buildShareSummary(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  for (final day in groupStopsByDay(controller.timeline)) ...[
                    if (day.dayIndex > 0) const SizedBox(height: 8),
                    if (day.showHeader) ...[
                      _DayHeader(dayIndex: day.dayIndex),
                      const SizedBox(height: 12),
                    ],
                    for (var i = 0; i < day.stops.length; i++)
                      _TimelineEntry(
                        stop: day.stops[i],
                        isLast: i == day.stops.length - 1,
                      ),
                  ],
                ],
              ),
            ),
      floatingActionButton: plan == null
          ? null
          : FloatingActionButton.extended(
              icon: _isExporting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.ios_share, size: 18),
              label: const Text('Export Itinerary'),
              onPressed: _isExporting ? null : () => _exportAsImage(controller),
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

class _DayHeader extends StatelessWidget {
  final int dayIndex;
  const _DayHeader({required this.dayIndex});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'DAY ${dayIndex + 1}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
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

/// The actual content captured for "Export Itinerary" — branded summary
/// stats up top (same shape as Route Optimized's share card) followed by
/// the full stop-by-stop timeline, so the exported image is a genuinely
/// standalone itinerary someone can read without the app.
class _ShareableDayTripCard extends StatelessWidget {
  final ItineraryPlannerController controller;
  const _ShareableDayTripCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan!;
    final path = controller.selectedRoutePath!;
    final metrics = path.metricsFor(controller.selectedTravelMode);

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header / summary (matches the Route Optimized share card) ---
            Container(
              width: double.infinity,
              color: AppTheme.primarySeed,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.diamond, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Hidden Gems of Malaysia',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Day Trip',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.destinations.map((d) => d.name).join('  →  '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _HeaderStat(label: 'Distance', value: metrics.formattedDistance),
                      _HeaderStat(label: 'Time', value: metrics.formattedDuration),
                      _HeaderStat(label: 'Cost', value: metrics.formattedCost),
                    ],
                  ),
                ],
              ),
            ),
            // --- Timeline (matches "Your Day Trip" page below the map) -------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final day in groupStopsByDay(plan.timeline)) ...[
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A simplified, non-interactive rendering of a timeline stop for the
/// exported image — same information as [_TimelineEntry] on the live page,
/// without the map-marker travel icon row (kept compact for the export).
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
