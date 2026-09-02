import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class EcoPartnerRoute {
  const EcoPartnerRoute({
    required this.polyline,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LatLng> polyline;
  final double distanceKm;
  final int durationMinutes;
}

class EcoPartnerRouteException implements Exception {
  const EcoPartnerRouteException(this.message);
  final String message;
}

class EcoPartnerRoutingService {
  EcoPartnerRoutingService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  Future<EcoPartnerRoute> drivingRoute(List<LatLng> waypoints) => _route(
    'https://routing.openstreetmap.de/routed-car/route/v1/driving',
    waypoints,
  );

  Future<EcoPartnerRoute> walkingRoute(List<LatLng> waypoints) => _route(
    'https://routing.openstreetmap.de/routed-foot/route/v1/foot',
    waypoints,
  );

  Future<EcoPartnerRoute> _route(String baseUrl, List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      throw const EcoPartnerRouteException(
        'Need at least two locations to calculate a route.',
      );
    }
    final coordinates = waypoints
        .map(
          (point) =>
              '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    dynamic data;
    try {
      final response = await _dio.get<dynamic>(
        '$baseUrl/$coordinates',
        queryParameters: const {'overview': 'full', 'geometries': 'geojson'},
      );
      data = response.data;
    } on DioException catch (error) {
      throw EcoPartnerRouteException(_messageForFailure(error));
    }
    if (data is! Map<String, dynamic> || data['code'] != 'Ok') {
      throw EcoPartnerRouteException(_messageForResponse(data));
    }
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw const EcoPartnerRouteException(
        'No route is available between your location and this partner.',
      );
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final polyline = (geometry['coordinates'] as List)
        .map(
          (value) => LatLng(
            ((value as List)[1] as num).toDouble(),
            (value[0] as num).toDouble(),
          ),
        )
        .toList();
    return EcoPartnerRoute(
      polyline: polyline,
      distanceKm: (route['distance'] as num) / 1000,
      durationMinutes: ((route['duration'] as num) / 60).round(),
    );
  }

  static String _messageForFailure(DioException error) {
    if (error.response != null) {
      return _messageForResponse(error.response!.data);
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The route service timed out. Please try again.',
      _ =>
        'Could not reach the route service. Check your connection and retry.',
    };
  }

  static String _messageForResponse(dynamic data) {
    if (data is Map) {
      return switch ('${data['code'] ?? ''}') {
        'NoRoute' =>
          'No route is available between your location and this partner.',
        'NoSegment' =>
          'A nearby road or path could not be found for one of the locations.',
        'TooBig' => 'This journey is too long for the route service.',
        'InvalidUrl' ||
        'InvalidService' ||
        'InvalidVersion' ||
        'InvalidOptions' ||
        'InvalidQuery' ||
        'InvalidValue' => 'The route service could not process this journey.',
        _ => 'The route service is temporarily unavailable. Please retry.',
      };
    }
    return 'The route service is temporarily unavailable. Please retry.';
  }
}
