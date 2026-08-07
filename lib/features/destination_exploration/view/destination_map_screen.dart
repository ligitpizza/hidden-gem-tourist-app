// lib/features/destination_exploration/view/destination_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../controller/destination_map_controller.dart';
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
            const CategoryFilterBar(),
            const SizedBox(height: 8),
            Expanded(child: _MapBody(controller: controller)),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.controller});

  final DestinationMapController controller;

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
                      child: Icon(
                        categoryIcon(destination.category),
                        color: categoryColor(destination.category),
                        size: 32,
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
                  final matches =
                      controller.filteredDestinations.where((d) => d.id == id);
                  if (matches.isEmpty) return;
                  final destination = matches.first;

                  controller.selectDestination(destination.id);
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => DestinationPopupSheet(destination: destination),
                  ).whenComplete(controller.clearSelection);
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
    );
  }
}

/// A "+" speed-dial FAB hosting the map's associated actions (View Themed
/// Trail, Destination Comparison) — replaces the single always-visible
/// "View Themed Trail" button so the map corner can host more than one
/// action without cluttering the screen by default.
class _MapActionsFab extends StatefulWidget {
  const _MapActionsFab({required this.controller});

  final DestinationMapController controller;

  @override
  State<_MapActionsFab> createState() => _MapActionsFabState();
}

class _MapActionsFabState extends State<_MapActionsFab> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _viewThemedTrail() {
    setState(() => _expanded = false);
    widget.controller.viewThemedCluster(origin: widget.controller.selectedDestination);
  }

  void _compareDestinations() {
    setState(() => _expanded = false);
    if (widget.controller.canCompare) {
      context.push(
        ComparisonRoutes.compare,
        extra: widget.controller.selectedForComparison.toList(),
      );
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Select 2-3 destinations to compare')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) ...[
          FloatingActionButton.extended(
            heroTag: 'mapAction_viewThemedTrail',
            onPressed: _viewThemedTrail,
            icon: const Icon(Icons.route_outlined),
            label: const Text('View Themed Trail'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'mapAction_destinationComparison',
            onPressed: _compareDestinations,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Destination Comparison'),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: 'mapAction_toggle',
          onPressed: _toggle,
          child: Icon(_expanded ? Icons.close : Icons.add),
        ),
      ],
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
