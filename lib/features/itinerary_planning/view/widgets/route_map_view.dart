import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapMarkerSpec {
  final LatLng point;
  final Color color;
  final IconData icon;

  const MapMarkerSpec({
    required this.point,
    required this.color,
    this.icon = Icons.location_on,
  });
}

class MapPolylineSpec {
  final List<LatLng> points;
  final Color color;
  final bool dashed;

  const MapPolylineSpec({
    required this.points,
    required this.color,
    this.dashed = false,
  });
}

/// Thin wrapper around [FlutterMap] used for both the small route previews
/// (page 1 / page 3) and the interactive route map (page 2).
class RouteMapView extends StatelessWidget {
  final List<MapMarkerSpec> markers;
  final List<MapPolylineSpec> polylines;
  final bool interactive;
  final double height;
  final BorderRadius borderRadius;

  const RouteMapView({
    super.key,
    required this.markers,
    this.polylines = const [],
    this.interactive = false,
    this.height = 220,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  static const _defaultCenter = LatLng(3.1390, 101.6869);

  LatLng get _center {
    if (markers.isEmpty) return _defaultCenter;
    final avgLat = markers.map((m) => m.point.latitude).reduce((a, b) => a + b) / markers.length;
    final avgLng = markers.map((m) => m.point.longitude).reduce((a, b) => a + b) / markers.length;
    return LatLng(avgLat, avgLng);
  }

  double get _zoom {
    if (markers.length < 2) return 13;
    final lats = markers.map((m) => m.point.latitude);
    final lngs = markers.map((m) => m.point.longitude);
    final spread = (lats.reduce(max) - lats.reduce(min)) + (lngs.reduce(max) - lngs.reduce(min));
    if (spread > 0.3) return 10;
    if (spread > 0.1) return 11.5;
    return 13;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        child: IgnorePointer(
          ignoring: !interactive,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              interactionOptions: InteractionOptions(
                flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.collab',
              ),
              if (polylines.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final p in polylines)
                      Polyline(
                        points: p.points,
                        color: p.color,
                        strokeWidth: 4,
                        pattern: p.dashed
                            ? StrokePattern.dashed(segments: <double>[10.0, 8.0])
                            : const StrokePattern.solid(),
                      ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final m in markers)
                    Marker(
                      point: m.point,
                      width: 34,
                      height: 34,
                      child: Icon(m.icon, color: m.color, size: 30),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
