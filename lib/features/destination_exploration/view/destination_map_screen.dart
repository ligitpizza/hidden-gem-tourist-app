// lib/features/destination_exploration/view/destination_map_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/hidden_gem.dart';
import '../../gamification_journal/controller/checkin_controller.dart';
import '../../gamification_journal/model/destination_model.dart';
import '../../gamification_journal/view/checkin/destination_detail_screen.dart';
import '../../itinerary_planning/controller/itinerary_planner_controller.dart';
import '../../itinerary_planning/model/itinerary_stop.dart' show StopBadge;
import '../../itinerary_planning/view/itinerary_routes.dart';
import '../../itinerary_planning/view/widgets/badge_pill.dart';
import '../controller/destination_map_controller.dart';
import '../model/map_destination.dart';
import 'comparison_routes.dart';
import 'destination_search_screen.dart';
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _MapModeSwitcher(controller: controller)),
                  const SizedBox(width: 8),
                  const CategoryFilterBar(),
                ],
              ),
            ),
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
    return SegmentedButton<MapViewMode>(
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

  final MapController _mapController = MapController();

  Future<void> _viewThemedTrail() async {
    await controller.viewThemedCluster(origin: controller.selectedDestination);
    final anchor = controller.clusterAnchor;
    if (anchor != null) {
      _mapController.move(anchor.location, 14);
    }
  }

  void _zoomIn() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + 1);
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom - 1);
  }

  Future<void> _locateMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to locate you on the map.'),
            ),
          );
        }
        return;
      }
      final position =
          await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
      final point = LatLng(position.latitude, position.longitude);
      controller.setUserLocation(point);
      _mapController.move(point, 15);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't determine your location right now.")),
        );
      }
    }
  }

  void _handleMarkerTap(String id) {
    final matches = controller.filteredDestinations.where((d) => d.id == id);
    if (matches.isEmpty) return;
    final destination = matches.first;

    if (controller.mode == MapViewMode.comparison) {
      _toggleComparison(destination.id);
      return;
    }

    _openPopup(destination);
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

  /// Opens a single destination's detail page directly — used by the
  /// themed trail card's tappable stop rows, which aren't behind a popup
  /// sheet so there's nothing to pop first (contrast with
  /// DestinationPopupSheet's own View Details, which closes itself first).
  void _openStopDetail(MapDestination destination) {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(
          destination: resolved ?? DestinationModel.fromMapDestination(destination),
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
          mapController: _mapController,
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
                // A clustered bubble routes taps through the package's own
                // onClusterTap (just zooms in) instead of onMarkerTap below,
                // so a destination inside an unspread cluster can't be
                // selected until you zoom in past it — same as tapping any
                // cluster to explore it normally. (A per-mode radius was
                // tried here to disable clustering entirely in Comparison
                // mode, but MarkerClusterLayerOptions rebuilds its whole
                // cluster tree from scratch on every rebuild — i.e. on every
                // selection toggle — and radius 1 is the most expensive
                // shape for that tree to recompute, which introduced visible
                // lag. Kept constant instead.)
                maxClusterRadius: 45,
                markers: [
                  for (final destination in controller.filteredDestinations)
                    Marker(
                      key: ValueKey(destination.id),
                      point: destination.location,
                      width: 44,
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // A solid colored pin (white ring + shadow) reads
                          // clearly against any map tile color; the old bare
                          // colored icon blended into busy OSM tiles.
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: categoryColor(destination.category),
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              categoryIcon(destination.category),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          if (controller.mode == MapViewMode.comparison &&
                              controller.selectedForComparison.contains(destination.id))
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                              ),
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
            // "You are here" — set by the locate-me control and by View
            // Themed Trail when it resolves current location. Kept out of
            // the clustered destination layer so it never merges into a
            // cluster bubble.
            if (controller.userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: controller.userLocation!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (controller.mode == MapViewMode.explore) ...[
          // Hidden while the trail card is already showing — re-offering
          // the same trigger next to its own result is redundant clutter.
          if (controller.clusterAnchor == null && controller.clusterMessage == null)
            Positioned(
              right: 16,
              bottom: 16,
              child: _MapActionsFab(onPressed: _viewThemedTrail),
            ),
          if (controller.clusterAnchor != null || controller.clusterMessage != null)
            // A drag-up-to-expand bottom sheet rather than a fixed-height
            // card: the fixed card was both fighting the zoom/locate
            // control column for the same top-right space (previously
            // patched by insetting its right edge — cramped enough to
            // overflow a row by 12px) and had no way to show more than a
            // couple of stops without scrolling inside a capped box. A
            // sheet starts small (clear of the zoom controls entirely),
            // and the traveller can drag it up to see the whole trail.
            DraggableScrollableSheet(
              initialChildSize: 0.32,
              minChildSize: 0.16,
              maxChildSize: 0.92,
              builder: (context, scrollController) => _ClusterCard(
                controller: controller,
                onStopTap: _openStopDetail,
                scrollController: scrollController,
              ),
            ),
        ],
        if (controller.mode == MapViewMode.comparison)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ComparisonSelectionPanel(controller: controller),
          ),
        Positioned(
          right: 16,
          top: 16,
          child: _MapZoomControls(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onLocateMe: _locateMe,
            onSearch: controller.mode == MapViewMode.comparison
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
                    )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Right-side zoom/locate controls, visible in both map modes. Search sits
/// below locate-me and only appears in Comparison mode — it's an alternate
/// way to pick destinations for comparison, not a general map action.
class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocateMe,
    required this.onSearch,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocateMe;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(icon: Icons.add, tooltip: 'Zoom in', onPressed: onZoomIn),
        const SizedBox(height: 8),
        _MapControlButton(icon: Icons.remove, tooltip: 'Zoom out', onPressed: onZoomOut),
        const SizedBox(height: 16),
        _MapControlButton(icon: Icons.my_location, tooltip: 'My location', onPressed: onLocateMe),
        if (onSearch != null) ...[
          const SizedBox(height: 16),
          _MapControlButton(
            icon: Icons.search,
            tooltip: 'Search destinations to compare',
            onPressed: onSearch!,
          ),
        ],
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

/// Shown at the bottom of the map while [MapViewMode.comparison] is active:
/// tapping a marker directly toggles it in/out of the selection (see
/// [_MapBodyState._handleMarkerTap]) — this is just the running summary of
/// whatever's currently selected, with the button to go compare them.
class _ComparisonSelectionPanel extends StatelessWidget {
  const _ComparisonSelectionPanel({required this.controller});

  final DestinationMapController controller;

  @override
  Widget build(BuildContext context) {
    final selectedIds = controller.selectedForComparison;
    final selected =
        controller.destinations.where((d) => selectedIds.contains(d.id)).toList();

    // Gated on the selection Set directly (the source of truth updated
    // synchronously by toggleComparisonSelection) rather than the
    // destinations-join above, so the card can never lag behind a tap.
    if (selectedIds.isEmpty) return const SizedBox.shrink();

    return Card(
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
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear selected destinations',
                  onPressed: controller.clearComparisonSelection,
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
    );
  }
}

/// Explore mode's map corner action. Destination Comparison used to live
/// here too, but now has its own dedicated mode via [_MapModeSwitcher], so
/// this only needs to trigger the themed trail anymore.
class _MapActionsFab extends StatelessWidget {
  const _MapActionsFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'mapAction_viewThemedTrail',
      onPressed: onPressed,
      icon: const Icon(Icons.route_outlined),
      label: const Text('View Themed Trail'),
    );
  }
}

/// A trail-flavored word per category, used for the cluster badge/title
/// ("Heritage Cluster" / "Heritage Trail" for culture, etc.) — purely a
/// display label, doesn't change what [HiddenGemCategory] means anywhere
/// else.
String _trailFlavor(HiddenGemCategory category) => switch (category) {
      HiddenGemCategory.culture => 'Heritage',
      HiddenGemCategory.nature => 'Nature',
      HiddenGemCategory.food => 'Culinary',
      HiddenGemCategory.viewpoint => 'Scenic',
      HiddenGemCategory.craft => 'Artisan',
    };

/// First sentence of a destination's description, capped to a short
/// highlight line for the trail stop list — the data has no dedicated
/// "highlight" field, so this is the closest approximation without
/// inventing content.
String _shortHighlight(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return '';
  final firstSentence = trimmed.split(RegExp(r'(?<=[.!?])\s')).first;
  if (firstSentence.length <= 42) return firstSentence;
  return '${firstSentence.substring(0, 42).trimRight()}…';
}

/// h:mm AM/PM, matching the Day Trip screen's stop-time formatting.
String _formatTrailTime(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// No real routing API backs this trail, so drive time is a rough estimate
/// off straight-line distance — same formula already used for the
/// comparison screen's drive-time captions.
int _estimateTrailDriveMinutes(double km) => (km / 35 * 60).round();

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({
    required this.controller,
    required this.onStopTap,
    required this.scrollController,
  });

  final DestinationMapController controller;
  final ValueChanged<MapDestination> onStopTap;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final anchor = controller.clusterAnchor;
    final colorScheme = Theme.of(context).colorScheme;

    if (anchor == null) {
      // Loading/error/empty states — no trail data to show yet.
      return _DrawerSurface(
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            const _DragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.clusterMessage ?? 'Suggested Trail',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: controller.clearCluster),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final flavor = _trailFlavor(anchor.category);
    final legs = controller.legDistancesKm;

    // Arrival time per stop: the anchor is "now" (the user's current
    // position/time); each following stop's time is the previous arrival
    // plus that leg's estimated drive time.
    final arrivalTimes = <DateTime>[DateTime.now()];
    for (final legKm in legs) {
      arrivalTimes.add(arrivalTimes.last.add(Duration(minutes: _estimateTrailDriveMinutes(legKm))));
    }

    final stops = [anchor, ...controller.clusterStops];

    // A drag-up-to-expand sheet (see DraggableScrollableSheet in
    // destination_map_screen.dart's build) rather than a height-capped
    // card — everything lives in one ListView bound to the sheet's own
    // scrollController, so dragging the handle resizes the sheet and, once
    // fully expanded, scrolling takes over to reach stops further down.
    return _DrawerSurface(
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          const _DragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$flavor Trail',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${controller.totalDistanceKm.toStringAsFixed(1)}km total',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: controller.clearCluster,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              children: [
                for (var i = 0; i < stops.length; i++)
                  _TrailTimelineEntry(
                    isAnchor: i == 0,
                    isLast: i == stops.length - 1,
                    time: _formatTrailTime(arrivalTimes[i]),
                    title: stops[i].name,
                    meta: stops[i].category.label,
                    description: i == 0
                        ? 'Starting point of your journey.'
                        : _shortHighlight(stops[i].description),
                    travelToNext: i < legs.length
                        ? '~${_estimateTrailDriveMinutes(legs[i])} min drive'
                        : null,
                    onTap: () => onStopTap(stops[i]),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final itineraryController = ProviderScope.containerOf(context, listen: false)
                      .read(itineraryPlannerControllerProvider);
                  final added = controller.addTrailToItinerary(itineraryController);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added == 0
                            ? 'This trail is already in your itinerary'
                            : 'Added $added stop${added == 1 ? '' : 's'} to your itinerary',
                      ),
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () => context.push(ItineraryRoutes.planRoute),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.card_travel),
                label: const Text('Add Trail to Itinerary'),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  'Suggested path only — not a navigable route',
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-top, elevated backing for the drawer's content — visually
/// separates it from the map without a full opaque Card, matching the
/// bottom-sheet convention (see day_trip_screen.dart's map/legend cards for
/// the same rounded-corner language elsewhere in this module).
class _DrawerSurface extends StatelessWidget {
  const _DrawerSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// The visual affordance signalling the sheet can be dragged — purely
/// decorative (DraggableScrollableSheet's drag handling comes from the
/// scrollable content itself), but without it nothing here reads as
/// draggable at a glance.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// One trail stop in the timeline, matching the Day Trip screen's
/// dot-and-line + card visual pattern (see day_trip_screen.dart's
/// `_TimelineEntry`), so a themed trail and a planned itinerary read as the
/// same kind of thing.
class _TrailTimelineEntry extends StatelessWidget {
  const _TrailTimelineEntry({
    required this.isAnchor,
    required this.isLast,
    required this.time,
    required this.title,
    required this.meta,
    required this.description,
    required this.travelToNext,
    required this.onTap,
  });

  final bool isAnchor;
  final bool isLast;
  final String time;
  final String title;
  final String meta;
  final String description;
  final String? travelToNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dotColor = isAnchor ? AppTheme.primarySeed : AppTheme.gemGold;

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
                    color: isAnchor ? dotColor : Colors.white,
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
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTap,
                    child: Container(
                      width: double.infinity,
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
                                time,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              BadgePill(badge: isAnchor ? StopBadge.selected : StopBadge.localGem),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: TextStyle(fontSize: 12.5, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (travelToNext != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            travelToNext!,
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
