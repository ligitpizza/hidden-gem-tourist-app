// lib/features/destination_exploration/view/destination_map_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../gamification_journal/controller/checkin_controller.dart';
import '../../gamification_journal/model/destination_model.dart';
import '../../gamification_journal/view/checkin/destination_detail_screen.dart';
import '../controller/destination_map_controller.dart';
import '../model/map_destination.dart';
import 'comparison_routes.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/category_style.dart';
import 'widgets/destination_popup_sheet.dart';

/// Module 2.1's Interactive Destination Map: every destination from the
/// dedicated `destinations` table as a clustered, color-coded marker, with
/// category filters (FR1.3) and a tap-to-view detail popup (FR1.2).
class DestinationMapScreen extends ConsumerWidget {
  const DestinationMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(destinationMapControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _MapModeSwitcher(controller: controller),
            const SizedBox(height: 8),
            const CategoryFilterBar(),
            const SizedBox(height: 8),
            Expanded(child: _MapBody(controller: controller)),
          ],
        ),
      ),
    );
  }
}

/// Header toggle between normal browsing and comparison-selection mode
/// (see [MapViewMode]).
class _MapModeSwitcher extends StatelessWidget {
  const _MapModeSwitcher({required this.controller});

  final DestinationMapController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<MapViewMode>(
        segments: const [
          ButtonSegment(
            value: MapViewMode.explore,
            label: Text('Map View'),
            icon: Icon(Icons.map_outlined),
          ),
          ButtonSegment(
            value: MapViewMode.comparison,
            label: Text('Comparison'),
            icon: Icon(Icons.compare_arrows),
          ),
        ],
        selected: {controller.mode},
        onSelectionChanged: (selection) => controller.setMode(selection.first),
      ),
    );
  }
}

class _MapBody extends StatefulWidget {
  const _MapBody({required this.controller});

  final DestinationMapController controller;

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  DestinationMapController get controller => widget.controller;

  // onMarkerTap (below) is the marker-cluster package's only per-marker
  // gesture hook, and single-tap already opens a blocking modal sheet — so
  // double-tap can't be resolved by Flutter's gesture arena. Instead, a
  // single tap is held for a short window in case a second tap on the same
  // marker follows, in which case it's treated as a double-tap.
  static const _doubleTapWindow = Duration(milliseconds: 300);
  String? _pendingTapId;
  Timer? _tapTimer;

  // The last-tapped destination while in comparison mode, shown as a
  // preview card above the selection summary panel (cleared on mode switch).
  MapDestination? _previewDestination;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleMarkerTap(String id) {
    final matches = controller.filteredDestinations.where((d) => d.id == id);
    if (matches.isEmpty) return;
    final destination = matches.first;

    if (controller.mode == MapViewMode.comparison) {
      setState(() => _previewDestination = destination);
      _toggleComparison(destination.id);
      return;
    }

    if (_pendingTapId == id && _tapTimer != null) {
      _tapTimer!.cancel();
      _tapTimer = null;
      _pendingTapId = null;
      _openDetail(destination);
      return;
    }

    _tapTimer?.cancel();
    _pendingTapId = id;
    _tapTimer = Timer(_doubleTapWindow, () {
      _tapTimer = null;
      _pendingTapId = null;
      _openPopup(destination);
    });
  }

  void _toggleComparison(String id) {
    final added = controller.toggleComparisonSelection(id);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DestinationMapController.comparisonLimitMessage)),
      );
    }
  }

  void _openPopup(MapDestination destination) {
    controller.selectDestination(destination.id);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => DestinationPopupSheet(destination: destination),
    ).whenComplete(controller.clearSelection);
  }

  void _openDetail(MapDestination destination) {
    // The detail screen's badge-progress lookup reads
    // CheckInController.destinations, which is otherwise only populated by
    // visiting the Journal tab — make sure it's loaded so badge matching
    // works when the detail screen is reached from this map instead.
    final checkInController = context.read<CheckInController>();
    if (checkInController.destinations.isEmpty) {
      unawaited(checkInController.loadDestinations());
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(
          destination: DestinationModel.fromMapDestination(destination),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && controller.destinations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('Could not load destinations.'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: controller.retry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(5.4164, 100.3327), // Penang — matches the seeded dataset
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.collab.app',
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                markers: [
                  for (final destination in controller.filteredDestinations)
                    Marker(
                      key: ValueKey(destination.id),
                      point: destination.location,
                      width: 40,
                      height: 40,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            categoryIcon(destination.category),
                            color: categoryColor(destination.category),
                            size: 32,
                          ),
                          if (controller.mode == MapViewMode.comparison &&
                              controller.selectedForComparison.contains(destination.id))
                            const Positioned(
                              right: 0,
                              top: 0,
                              child: Icon(Icons.check_circle, size: 16, color: Colors.green),
                            ),
                        ],
                      ),
                    ),
                ],
                // A per-marker GestureDetector would be nested inside the one
                // MarkerClusterLayerWidget already wraps around each marker
                // child (markerChildBehavior defaults to false), leaving gesture
                // resolution ambiguous. onMarkerTap is the package's purpose-built
                // hook for this instead.
                onMarkerTap: (marker) {
                  final id = (marker.key as ValueKey<String>).value;
                  _handleMarkerTap(id);
                },
                builder: (context, markers) => CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '${markers.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            if (controller.clusterPolyline.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: controller.clusterPolyline,
                    strokeWidth: 4,
                    color: Colors.deepOrange,
                    pattern: StrokePattern.dashed(segments: const [10, 6]),
                  ),
                ],
              ),
          ],
        ),
        if (controller.mode == MapViewMode.explore) ...[
          Positioned(
            right: 16,
            bottom: 16,
            child: _MapActionsFab(controller: controller),
          ),
          if (controller.clusterAnchor != null || controller.clusterMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 84,
              child: _ClusterCard(controller: controller),
            ),
        ],
        if (controller.mode == MapViewMode.comparison)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ComparisonSelectionPanel(
              controller: controller,
              preview: _previewDestination,
            ),
          ),
      ],
    );
  }
}

/// Shown at the bottom of the map while [MapViewMode.comparison] is active:
/// a preview of the last-tapped destination (with an explicit add/remove
/// action) above a running summary of the current selection.
class _ComparisonSelectionPanel extends StatelessWidget {
  const _ComparisonSelectionPanel({required this.controller, required this.preview});

  final DestinationMapController controller;
  final MapDestination? preview;

  @override
  Widget build(BuildContext context) {
    final selectedIds = controller.selectedForComparison;
    final selected =
        controller.destinations.where((d) => selectedIds.contains(d.id)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview != null) ...[
          _ComparisonPreviewCard(destination: preview!, controller: controller),
          const SizedBox(height: 8),
        ],
        if (selected.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SELECT DESTINATIONS',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${selected.length} item${selected.length == 1 ? '' : 's'} selected',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 24.0 + 22.0 * (selected.length - 1),
                        height: 32,
                        child: Stack(
                          children: [
                            for (var i = 0; i < selected.length; i++)
                              Positioned(
                                left: i * 22.0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: categoryColor(selected[i].category),
                                  backgroundImage: selected[i].imageUrls.isNotEmpty
                                      ? NetworkImage(selected[i].imageUrls.first)
                                      : null,
                                  child: selected[i].imageUrls.isEmpty
                                      ? Icon(categoryIcon(selected[i].category),
                                          size: 16, color: Colors.white)
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: selected.length >= 2
                        ? () => context.push(ComparisonRoutes.compare, extra: selectedIds.toList())
                        : null,
                    icon: const Icon(Icons.compare_arrows),
                    label: Text(
                      selected.length < 2
                          ? 'Select at least 2 to compare'
                          : 'Compare ${selected.length} Destination${selected.length == 1 ? '' : 's'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ComparisonPreviewCard extends StatelessWidget {
  const _ComparisonPreviewCard({required this.destination, required this.controller});

  final MapDestination destination;
  final DestinationMapController controller;

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.selectedForComparison.contains(destination.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: destination.imageUrls.isNotEmpty
                  ? Image.network(
                      destination.imageUrls.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: categoryColor(destination.category),
                      child: Icon(categoryIcon(destination.category), color: Colors.white),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(destination.name, style: Theme.of(context).textTheme.titleMedium),
                  Text('${destination.avgRating.toStringAsFixed(1)}★'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                final added = controller.toggleComparisonSelection(destination.id);
                if (!added) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(DestinationMapController.comparisonLimitMessage)),
                  );
                }
              },
              icon: Icon(isSelected ? Icons.check : Icons.add),
              label: Text(isSelected ? 'Added' : 'Add to Compare'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explore mode's map corner action. Destination Comparison used to live
/// here too, but now has its own dedicated mode via [_MapModeSwitcher], so
/// this only needs to trigger the themed trail anymore.
class _MapActionsFab extends StatelessWidget {
  const _MapActionsFab({required this.controller});

  final DestinationMapController controller;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'mapAction_viewThemedTrail',
      onPressed: () => controller.viewThemedCluster(origin: controller.selectedDestination),
      icon: const Icon(Icons.route_outlined),
      label: const Text('View Themed Trail'),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({required this.controller});

  final DestinationMapController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.clusterMessage ?? 'Suggested Trail',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: controller.clearCluster,
                ),
              ],
            ),
            if (controller.clusterAnchor != null) ...[
              Text('${controller.totalDistanceKm.toStringAsFixed(1)}km total'),
              const SizedBox(height: 8),
              Text('1. ${controller.clusterAnchor!.name} • Selected Anchor'),
              for (var i = 0; i < controller.clusterStops.length; i++)
                Text(
                  '${i + 2}. ${controller.clusterStops[i].name} • '
                  '${controller.legDistancesKm[i].toStringAsFixed(1)}km away',
                ),
              const SizedBox(height: 8),
              const Text(
                'Suggested path only — not a navigable route',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
