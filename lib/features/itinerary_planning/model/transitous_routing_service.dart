import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class TransitRoute {
  const TransitRoute({
    required this.distanceKm,
    required this.durationMinutes,
    required this.transfers,
    this.legs = const [],
    this.polyline = const [],
  });
  final double distanceKm;
  final int durationMinutes;
  final int transfers;
  final List<TransitLeg> legs;
  final List<LatLng> polyline;
}

class TransitLeg {
  const TransitLeg({
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.from,
    required this.to,
    required this.durationMinutes,
    required this.polyline,
    this.routeName,
    this.agencyName,
    this.headsign,
  });
  final String mode;
  final String fromName;
  final String toName;
  final LatLng from;
  final LatLng to;
  final int durationMinutes;
  final List<LatLng> polyline;
  final String? routeName;
  final String? agencyName;
  final String? headsign;
}

enum TransitRouteFailure { noCoverage, connection, service }

class TransitRouteException implements Exception {
  const TransitRouteException(this.failure, this.message);

  final TransitRouteFailure failure;
  final String message;

  @override
  String toString() => message;
}

/// Client for the free, keyless Transitous public-transport routing API.
class TransitousRoutingService {
  TransitousRoutingService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
  final Dio _dio;
  static const _distance = Distance();
  static const _baseUrl = 'https://api.transitous.org/api/v1/plan';

  /// Returns null when live transit planning is unavailable so itinerary
  /// estimates can continue using their existing fallback.
  Future<TransitRoute?> plan(LatLng from, LatLng to) async {
    try {
      return await planOrThrow(from, to);
    } on TransitRouteException {
      return null;
    }
  }

  /// Plans a journey and preserves a user-facing reason when it fails.
  /// Detail screens use this method so a network problem is not presented as
  /// if the stop has no transit service.
  Future<TransitRoute> planOrThrow(
    LatLng from,
    LatLng to, {
    Iterable<String> preferredRouteNames = const [],
    String? preferredRouteLabel,
  }) async {
    final requestedRouteNames = preferredRouteNames
        .map(_normalizeRouteName)
        .where((name) => name.isNotEmpty)
        .toSet();
    dynamic data;
    try {
      final response = await _dio.get<dynamic>(
        _baseUrl,
        queryParameters: {
          'fromPlace': '${from.latitude},${from.longitude}',
          'toPlace': '${to.latitude},${to.longitude}',
          'numItineraries': requestedRouteNames.isEmpty ? 1 : 5,
        },
      );
      data = response.data;
    } on DioException catch (error) {
      throw TransitRouteException(
        error.response == null
            ? TransitRouteFailure.connection
            : TransitRouteFailure.service,
        _messageForFailure(error),
      );
    }

    try {
      if (data is! Map<String, dynamic>) {
        throw const TransitRouteException(
          TransitRouteFailure.service,
          'The in-app transit planner returned an unexpected response. Please retry.',
        );
      }
      final itineraries = data['itineraries'] as List?;
      if (itineraries == null || itineraries.isEmpty) {
        throw const TransitRouteException(
          TransitRouteFailure.noCoverage,
          'Live transit directions are not available for this journey. The listed route may still serve this stop.',
        );
      }
      final candidateItineraries = itineraries
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      final itinerary = requestedRouteNames.isEmpty
          ? candidateItineraries.first
          : candidateItineraries.cast<Map<String, dynamic>?>().firstWhere(
              (value) =>
                  value != null &&
                  _itineraryUsesRoute(value, requestedRouteNames),
              orElse: () => null,
            );
      if (itinerary == null) {
        final route = preferredRouteLabel?.trim();
        throw TransitRouteException(
          TransitRouteFailure.noCoverage,
          route == null || route.isEmpty
              ? 'No live in-app itinerary using the selected route is available from your current location right now.'
              : 'No live in-app itinerary using $route is available from your current location right now. The route may still serve this stop on its published schedule.',
        );
      }
      final rawLegs = (itinerary['legs'] as List?) ?? const [];
      final parsedLegs = <TransitLeg>[];
      final routePolyline = <LatLng>[];
      var distanceMeters = 0.0;
      for (final rawLeg in rawLegs) {
        final leg = rawLeg as Map<String, dynamic>;
        final legFrom = leg['from'] as Map<String, dynamic>;
        final legTo = leg['to'] as Map<String, dynamic>;
        final fromPoint = _point(legFrom);
        final toPoint = _point(legTo);
        final legDistance = leg['distance'] as num?;
        distanceMeters +=
            legDistance?.toDouble() ??
            _distance.as(LengthUnit.Meter, fromPoint, toPoint) * 1.3;
        final geometry = leg['legGeometry'] as Map<String, dynamic>?;
        final encoded = geometry?['points'] as String?;
        final precision = (geometry?['precision'] as num?)?.toInt() ?? 5;
        final points = encoded == null
            ? <LatLng>[fromPoint, toPoint]
            : _decodePolyline(encoded, precision);
        routePolyline.addAll(
          routePolyline.isNotEmpty && points.isNotEmpty
              ? points.skip(1)
              : points,
        );
        parsedLegs.add(
          TransitLeg(
            mode: '${leg['mode'] ?? 'TRANSIT'}',
            fromName: '${legFrom['name'] ?? 'Start'}',
            toName: '${legTo['name'] ?? 'Destination'}',
            from: fromPoint,
            to: toPoint,
            durationMinutes: ((leg['duration'] as num) / 60).round(),
            polyline: points,
            routeName: _text(leg['routeShortName'] ?? leg['displayName']),
            agencyName: _text(leg['agencyName']),
            headsign: _text(leg['headsign']),
          ),
        );
      }
      return TransitRoute(
        distanceKm: distanceMeters / 1000,
        durationMinutes: ((itinerary['duration'] as num) / 60).round(),
        transfers: (itinerary['transfers'] as num?)?.toInt() ?? 0,
        legs: parsedLegs,
        polyline: routePolyline,
      );
    } on TransitRouteException {
      rethrow;
    } catch (_) {
      throw const TransitRouteException(
        TransitRouteFailure.service,
        'The in-app transit planner returned an unexpected response. Please retry.',
      );
    }
  }

  static String _messageForFailure(DioException error) {
    if (error.response != null) {
      return 'The in-app transit planner is temporarily unavailable. Please retry.';
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The in-app transit planner timed out. Please retry.',
      _ =>
        'Could not reach the in-app transit planner. Check your connection and retry.',
    };
  }

  static bool _itineraryUsesRoute(
    Map<String, dynamic> itinerary,
    Set<String> requestedNames,
  ) {
    final legs = (itinerary['legs'] as List?)?.whereType<Map>() ?? const [];
    for (final leg in legs) {
      for (final key in const [
        'routeShortName',
        'routeLongName',
        'displayName',
      ]) {
        final candidate = _normalizeRouteName('${leg[key] ?? ''}');
        if (candidate.isEmpty) continue;
        for (final requested in requestedNames) {
          if (candidate == requested ||
              ' $candidate '.contains(' $requested ') ||
              ' $requested '.contains(' $candidate ')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static String _normalizeRouteName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static LatLng _point(Map<String, dynamic> value) => LatLng(
    (value['lat'] as num).toDouble(),
    (value['lon'] as num).toDouble(),
  );
  static String? _text(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }

  static List<LatLng> _decodePolyline(String encoded, int precision) {
    final factor = _pow10(precision);
    final points = <LatLng>[];
    var index = 0, latitude = 0, longitude = 0;
    while (index < encoded.length) {
      final lat = _decodeValue(encoded, index);
      index = lat.$2;
      latitude += lat.$1;
      final lon = _decodeValue(encoded, index);
      index = lon.$2;
      longitude += lon.$1;
      points.add(LatLng(latitude / factor, longitude / factor));
    }
    return points;
  }

  static (int, int) _decodeValue(String encoded, int start) {
    var index = start, result = 0, shift = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    return ((result & 1) == 1 ? ~(result >> 1) : result >> 1, index);
  }

  static double _pow10(int precision) {
    var value = 1.0;
    for (var index = 0; index < precision; index++) {
      value *= 10;
    }
    return value;
  }
}
