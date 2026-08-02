/// Distance/time/cost estimate for a route under a single travel mode.
class RouteMetrics {
  final double distanceKm;
  final int durationMinutes;
  final double costMyr;

  const RouteMetrics({
    required this.distanceKm,
    required this.durationMinutes,
    required this.costMyr,
  });

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }

  String get formattedCost => 'RM ${costMyr.toStringAsFixed(2)}';
}
