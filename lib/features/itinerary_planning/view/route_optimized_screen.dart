import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/travel_mode.dart';
import '../../../shared/services/image_export_service.dart';
import '../controller/itinerary_planner_controller.dart';
import '../model/route_path.dart';
import 'itinerary_routes.dart';
import 'widgets/route_map_view.dart';
import 'widgets/stat_card.dart';

/// Near-black — the map's own greens/beiges made a themed path color hard
/// to pick out against the tiles, so the route line always renders in a
/// fixed high-contrast color regardless of theme or which path is selected.
const _mapPathColor = Color(0xFF141414);

class RouteOptimizedScreen extends ConsumerStatefulWidget {
  const RouteOptimizedScreen({super.key});

  @override
  ConsumerState<RouteOptimizedScreen> createState() => _RouteOptimizedScreenState();
}

class _RouteOptimizedScreenState extends ConsumerState<RouteOptimizedScreen> {
  bool _isCapturing = false;

  /// Captures [_ShareableItineraryCard] as a PNG. The card is mounted via a
  /// temporary [OverlayEntry] positioned far outside the visible viewport
  /// instead of `Offstage` — `Offstage` skips painting entirely, so a
  /// `RepaintBoundary` inside one never gets a layer attached and
  /// `toImage()` has nothing to capture. An overlay entry still paints
  /// normally; it's just positioned somewhere the user never scrolls to.
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
            child: _ShareableItineraryCard(controller: controller),
          ),
        ),
      ),
    );

    try {
      overlay.insert(entry);
      // Let the entry actually paint before reading its layer.
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

  Future<void> _downloadAsImage(ItineraryPlannerController controller) async {
    setState(() => _isCapturing = true);
    final bytes = await _captureShareCard(controller);
    if (!mounted) return;
    setState(() => _isCapturing = false);
    if (bytes == null) return;

    try {
      final savedToGallery = await ImageExportService.downloadToGallery(bytes, fileName: 'itinerary');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedToGallery
                ? 'Itinerary image saved to your gallery'
                : 'Gallery saving isn\'t available on this device — use the share sheet to save it.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the image — check gallery permission and try again')),
      );
    }
  }

  Future<void> _shareAsImage(ItineraryPlannerController controller) async {
    setState(() => _isCapturing = true);
    final bytes = await _captureShareCard(controller);
    if (!mounted) return;
    setState(() => _isCapturing = false);
    if (bytes == null) return;

    final file = XFile.fromData(bytes, name: 'itinerary.png', mimeType: 'image/png');
    await Share.shareXFiles(
      [file],
      subject: 'My travel itinerary',
      text: controller.buildShareSummary(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(itineraryPlannerControllerProvider);
    final plan = controller.plan;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        title: const Text('Route Optimized'),
      ),
      body: plan == null
          ? const Center(child: Text('Generate an itinerary first.'))
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  RouteMapView(
                    height: 440,
                    interactive: true,
                    borderRadius: BorderRadius.zero,
                    markers: [
                      for (final destination in plan.destinations)
                        MapMarkerSpec(point: destination.location, color: Theme.of(context).colorScheme.primary),
                      for (final gem in controller.selectedRoutePath!.hiddenGems)
                        MapMarkerSpec(
                          point: gem.location,
                          color: AppTheme.gemGold,
                          icon: Icons.diamond,
                        ),
                    ],
                    polylines: [
                      MapPolylineSpec(
                        points: controller.selectedRoutePath!.polyline,
                        color: _mapPathColor,
                        dashed: !controller.selectedRoutePath!.isRecommended,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        if (!controller.isPlanFeasible) ...[
                          _FeasibilityWarningCard(message: controller.feasibilityMessage!),
                          const SizedBox(height: 14),
                        ],
                        _PathLegend(
                          primary: plan.primaryPath,
                          alternate: plan.alternatePath,
                          selectedId: controller.selectedPathId,
                          onSelect: (id) =>
                              ref.read(itineraryPlannerControllerProvider).selectPath(id),
                        ),
                        const SizedBox(height: 22),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _SectionLabel('Travel Mode'),
                        ),
                        const SizedBox(height: 10),
                        _TravelModeSelector(
                          selected: controller.selectedTravelMode,
                          onSelect: (mode) =>
                              ref.read(itineraryPlannerControllerProvider).selectTravelMode(mode),
                        ),
                        const SizedBox(height: 20),
                        _DiscoveryAlertCard(
                          gemCount: controller.selectedRoutePath!.hiddenGems.length,
                          onTap: () => context.push(ItineraryRoutes.dayTrip),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Distance',
                                value: controller.selectedRoutePath!
                                    .metricsFor(controller.selectedTravelMode)
                                    .formattedDistance,
                                caption: 'Total route length',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                label: 'Estimated Time',
                                value: controller.selectedRoutePath!
                                    .metricsFor(controller.selectedTravelMode)
                                    .formattedDuration,
                                caption: 'Traffic included',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StatCard(
                          label: 'Estimated Cost',
                          value: controller.selectedRoutePath!
                              .metricsFor(controller.selectedTravelMode)
                              .formattedCost,
                          caption: 'Travel + estimated entrance/meal costs',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        const SizedBox(height: 22),
                        _ActionRow(
                          controller: controller,
                          isBusy: _isCapturing,
                          onDownload: () => _downloadAsImage(controller),
                          onShare: () => _shareAsImage(controller),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FeasibilityWarningCard extends StatelessWidget {
  final String message;
  const _FeasibilityWarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: Colors.orange.shade700, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _PathLegend extends StatelessWidget {
  final RoutePath primary;
  final RoutePath alternate;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _PathLegend({
    required this.primary,
    required this.alternate,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LegendEntry(
            label: 'Path A (Selected)',
            color: Theme.of(context).colorScheme.primary,
            dashed: false,
            selected: selectedId == primary.id,
            onTap: () => onSelect(primary.id),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LegendEntry(
            label: 'Path B (Alternative)',
            color: AppTheme.gemGold,
            dashed: true,
            selected: selectedId == alternate.id,
            onTap: () => onSelect(alternate.id),
          ),
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final String label;
  final Color color;
  final bool dashed;
  final bool selected;
  final VoidCallback onTap;

  const _LegendEntry({
    required this.label,
    required this.color,
    required this.dashed,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: dashed
                  ? Row(
                      children: List.generate(
                        3,
                        (_) => Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: color,
                          ),
                        ),
                      ),
                    )
                  : Container(height: 2, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelModeSelector extends StatelessWidget {
  final TravelMode selected;
  final ValueChanged<TravelMode> onSelect;

  const _TravelModeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final mode in TravelMode.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected == mode ? colorScheme.primary : colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == mode ? colorScheme.primary : colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 18,
                      color: selected == mode ? Colors.white : colorScheme.onSurface,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: selected == mode ? Colors.white : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (mode != TravelMode.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _DiscoveryAlertCard extends StatelessWidget {
  final int gemCount;
  final VoidCallback onTap;

  const _DiscoveryAlertCard({required this.gemCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.gemGoldSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
        ),
        child: Row(
          children: [
            Icon(Icons.travel_explore, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discovery Alert',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hidden Gem Count: $gemCount found along this path',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final ItineraryPlannerController controller;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _ActionRow({
    required this.controller,
    required this.isBusy,
    required this.onDownload,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.isSaving
                ? null
                : () async {
                    await controller.saveToAccount();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          controller.saveError ?? 'Itinerary saved to your account',
                        ),
                      ),
                    );
                  },
            icon: controller.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(controller.isSaved ? Icons.bookmark : Icons.bookmark_border, size: 18),
            label: Text(
              controller.isSaving ? 'Saving…' : (controller.isSaved ? 'Saved' : 'Save to Account'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CircleIconButton(
          icon: Icons.download_outlined,
          tooltip: 'Download as image',
          busy: isBusy,
          onPressed: isBusy ? null : onDownload,
        ),
        const SizedBox(width: 10),
        _CircleIconButton(
          icon: Icons.share_outlined,
          tooltip: 'Share',
          busy: isBusy,
          onPressed: isBusy ? null : onShare,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool busy;
  final VoidCallback? onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
              )
            : Icon(icon, size: 20, color: colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

/// The actual content captured for "Download as image" / "Share" — a
/// clean, branded summary card, not a screenshot of the interactive page.
class _ShareableItineraryCard extends StatelessWidget {
  final ItineraryPlannerController controller;
  const _ShareableItineraryCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan!;
    final path = controller.selectedRoutePath!;
    final metrics = path.metricsFor(controller.selectedTravelMode);

    return Material(
      color: AppTheme.primarySeed,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.diamond, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Hidden Gems of Malaysia',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              plan.destinations.map((d) => d.name).join('  →  '),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _CardStat(label: 'Distance', value: metrics.formattedDistance),
                _CardStat(label: 'Time', value: metrics.formattedDuration),
                _CardStat(label: 'Cost', value: metrics.formattedCost),
              ],
            ),
            if (path.hiddenGems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.diamond_outlined, color: Color(0xFFE8D9A0), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${path.hiddenGems.length} hidden gems along this route',
                        style: const TextStyle(color: Color(0xFFE8D9A0), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;
  const _CardStat({required this.label, required this.value});

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
