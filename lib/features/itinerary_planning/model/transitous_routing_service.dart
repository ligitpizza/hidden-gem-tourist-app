import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// A real point-to-point public transit trip (bus/rail + connecting walks).
class TransitRoute {
  final double distanceKm;
  final int durationMinutes;
  final int transfers;

  const TransitRoute({
    required this.distanceKm,
    required this.durationMinutes,
    required this.transfers,
  });
}

/// Client for Transitous (transitous.org) — a free, keyless public transit
/// routing API run as a nonprofit aggregator of open GTFS feeds (built on
/// the MOTIS engine). It has real Rapid Penang bus schedule coverage, so
/// "public transport" estimates can be genuine bus itineraries instead of a
/// flat-speed guess. No API key or billing, same free/community-hosted
/// arrangement as the OSRM routing server this app already uses.
class TransitousRoutingService {
  TransitousRoutingService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;
  static const _distance = Distance();

  static const _baseUrl = 'https://api.transitous.org/api/v1/plan';

  /// Returns the fastest real transit itinerary between [from] and [to], or
  /// null if the request fails or no transit connection exists for that
  /// pair (e.g. a stop too far from any bus route).
  Future<TransitRoute?> plan(LatLng from, LatLng to) async {
    try {
      final response = await _dio.get<dynamic>(
        _baseUrl,
        queryParameters: {
          'fromPlace': '${from.latitude},${from.longitude}',
          'toPlace': '${to.latitude},${to.longitude}',
          'numItineraries': 1,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final itineraries = data['itineraries'] as List?;
      if (itineraries == null || itineraries.isEmpty) return null;

      final itinerary = itineraries.first as Map<String, dynamic>;
      final durationSeconds = (itinerary['duration'] as num).toDouble();
      final transfers = (itinerary['transfers'] as num?)?.toInt() ?? 0;
      final legs = (itinerary['legs'] as List?) ?? const [];

      var distanceMeters = 0.0;
      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final legDistance = legMap['distance'] as num?;
        if (legDistance != null) {
          // Present on walking legs.
          distanceMeters += legDistance.toDouble();
          continue;
        }
        // Bus/rail legs don't carry a flat distance field — approximate
        // from their endpoints with a small detour factor, since a real bus
        // route isn't a straight line.
        final legFrom = legMap['from'] as Map<String, dynamic>;
        final legTo = legMap['to'] as Map<String, dynamic>;
        distanceMeters += _distance.as(
              LengthUnit.Meter,
              LatLng((legFrom['lat'] as num).toDouble(), (legFrom['lon'] as num).toDouble()),
              LatLng((legTo['lat'] as num).toDouble(), (legTo['lon'] as num).toDouble()),
            ) *
            1.3;
      }

      return TransitRoute(
        distanceKm: distanceMeters / 1000,
        durationMinutes: (durationSeconds / 60).round(),
        transfers: transfers,
      );
    } catch (_) {
      return null;
    }
  }
}
