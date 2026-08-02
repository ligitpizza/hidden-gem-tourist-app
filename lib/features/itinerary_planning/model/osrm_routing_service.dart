import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// A single routed path (road or footpath) returned by OSRM: real geometry
/// plus its total distance and duration.
class OsrmRoute {
  final List<LatLng> polyline;
  final double distanceKm;
  final int durationMinutes;

  const OsrmRoute({
    required this.polyline,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class OsrmException implements Exception {
  final String message;
  const OsrmException(this.message);

  @override
  String toString() => 'OsrmException: $message';
}

/// Client for the free, keyless OSRM routing service hosted by OpenStreetMap
/// Germany (routing.openstreetmap.de). It serves separate car and foot
/// profiles with real road/footpath geometry — no API key or billing.
///
/// This is community infrastructure meant for development/demo-scale
/// traffic, not production load; a self-hosted OSRM instance would be the
/// next step if this module ever needs to handle real user volume.
class OsrmRoutingService {
  OsrmRoutingService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  static const _carBaseUrl = 'https://routing.openstreetmap.de/routed-car/route/v1/driving';
  static const _footBaseUrl = 'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

  /// Real driving route(s) between consecutive waypoints. Pass exactly 2
  /// waypoints with [alternatives] true to get a second, genuinely different
  /// route for that leg — OSRM only computes alternatives for single-leg
  /// (2-point) requests, not full multi-stop chains.
  Future<List<OsrmRoute>> drivingRoute(
    List<LatLng> waypoints, {
    bool alternatives = false,
  }) {
    return _route(_carBaseUrl, waypoints, alternatives: alternatives);
  }

  /// Real walking route along footpaths (not just roads) between waypoints.
  Future<OsrmRoute> walkingRoute(List<LatLng> waypoints) async {
    final routes = await _route(_footBaseUrl, waypoints);
    return routes.first;
  }

  Future<List<OsrmRoute>> _route(
    String baseUrl,
    List<LatLng> waypoints, {
    bool alternatives = false,
  }) async {
    if (waypoints.length < 2) {
      throw const OsrmException('Need at least 2 waypoints to route.');
    }
    final coords = waypoints
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');

    late Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '$baseUrl/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          if (alternatives) 'alternatives': 'true',
        },
      );
    } on DioException catch (e) {
      throw OsrmException('OSRM request failed: ${e.message}');
    }

    final data = response.data;
    if (data is! Map<String, dynamic> || data['code'] != 'Ok') {
      throw OsrmException('OSRM returned an unexpected response: ${response.data}');
    }

    final routes = data['routes'] as List;
    return routes.map((r) {
      final coordinates = ((r as Map<String, dynamic>)['geometry']['coordinates'] as List)
          .map((c) => LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return OsrmRoute(
        polyline: coordinates,
        distanceKm: (r['distance'] as num) / 1000,
        durationMinutes: ((r['duration'] as num) / 60).round(),
      );
    }).toList();
  }
}
