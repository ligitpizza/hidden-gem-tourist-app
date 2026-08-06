// lib/features/destination_exploration/view/destination_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../controller/destination_map_controller.dart';
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

    return FlutterMap(
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
                  point: destination.location,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      controller.selectDestination(destination.id);
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => DestinationPopupSheet(destination: destination),
                      ).whenComplete(controller.clearSelection);
                    },
                    child: Icon(
                      categoryIcon(destination.category),
                      color: categoryColor(destination.category),
                      size: 32,
                    ),
                  ),
                ),
            ],
            builder: (context, markers) => CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '${markers.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
