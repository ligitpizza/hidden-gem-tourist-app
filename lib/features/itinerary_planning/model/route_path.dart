import 'package:latlong2/latlong.dart';

import '../../../shared/models/hidden_gem.dart';
import '../../../shared/models/travel_mode.dart';
import 'route_metrics.dart';

/// One of the generated candidate routes ("Path A", "Path B", ...) between
/// the traveller's selected destinations.
class RoutePath {
  final String id;
  final String label;
  final bool isRecommended;
  final List<LatLng> polyline;
  final List<HiddenGem> hiddenGems;
  final Map<TravelMode, RouteMetrics> metricsByMode;

  const RoutePath({
    required this.id,
    required this.label,
    required this.isRecommended,
    required this.polyline,
    required this.hiddenGems,
    required this.metricsByMode,
  });

  RouteMetrics metricsFor(TravelMode mode) => metricsByMode[mode]!;
}
