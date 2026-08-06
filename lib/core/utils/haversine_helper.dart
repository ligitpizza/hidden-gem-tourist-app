import 'dart:math';

/// Calculates the great-circle distance between two coordinates in meters.
///
/// This mirrors the Haversine logic the Supabase Postgres function will
/// use server-side in Phase 2, so the check-in behaviour users see in the
/// Phase 1 mock stays consistent once the real backend is wired in.
class HaversineHelper {
  static const double _earthRadiusMeters = 6371000;

  static double distanceInMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);
}
