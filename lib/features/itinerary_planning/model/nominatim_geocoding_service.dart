import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/destination.dart';

/// Client for Nominatim (nominatim.openstreetmap.org) — OpenStreetMap's
/// free, keyless geocoder. Lets a traveller search for *any* real-world
/// place, not just ones already recorded in the curated `places` database;
/// hidden gems are still sourced from that curated dataset separately,
/// along whichever route this produces.
///
/// Usage policy: max ~1 request/second, and a descriptive User-Agent is
/// required — both honoured here. This is only called as a fallback when
/// the database search finds nothing, so it stays naturally low-volume.
class NominatimGeocodingService {
  NominatimGeocodingService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'User-Agent':
                    'HiddenGemTouristAppFYP/1.0 (student project, itinerary search)',
              },
            ),
          );

  final Dio _dio;
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<Destination>> search(String query) async {
    try {
      var response = await _dio.get<dynamic>(
        _baseUrl,
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 8,
          'countrycodes': 'my',
        },
      );

      var data = response.data;
      if (data is List &&
          data.isEmpty &&
          !query.toLowerCase().contains('malaysia')) {
        // Nominatim sometimes requires the country in the free-text query for
        // named businesses even when countrycodes is supplied separately.
        await Future<void>.delayed(const Duration(seconds: 1));
        response = await _dio.get<dynamic>(
          _baseUrl,
          queryParameters: {
            'q': '$query, Malaysia',
            'format': 'jsonv2',
            'addressdetails': 1,
            'limit': 8,
            'countrycodes': 'my',
          },
        );
        data = response.data;
      }
      final words = query.trim().split(RegExp(r'\s+'));
      if (data is List && data.isEmpty && words.length >= 3) {
        await Future<void>.delayed(const Duration(seconds: 1));
        response = await _dio.get<dynamic>(
          _baseUrl,
          queryParameters: {
            'q': '${words.take(words.length - 1).join(' ')}, Malaysia',
            'format': 'jsonv2',
            'addressdetails': 1,
            'limit': 8,
            'countrycodes': 'my',
          },
        );
        data = response.data;
      }
      if (data is! List) return const [];

      return data
          .map((row) => _destinationFromResult(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Destination _destinationFromResult(Map<String, dynamic> row) {
    final address = row['address'] as Map<String, dynamic>? ?? const {};
    final city =
        (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['county'])
            as String? ??
        (address['state'] as String?) ??
        '';
    final name = (row['name'] as String?)?.trim();
    final displayName = row['display_name'] as String? ?? 'Unknown place';

    return Destination(
      id: 'osm_place_${row['place_id']}',
      name: (name != null && name.isNotEmpty)
          ? name
          : displayName.split(',').first,
      city: city,
      category: _categoryFromOsmTags(
        category: row['category'] as String?,
        type: row['type'] as String?,
      ),
      location: LatLng(
        double.parse(row['lat'] as String),
        double.parse(row['lon'] as String),
      ),
    );
  }

  /// Loose mapping from OSM's `category`/`type` tags (an open vocabulary) to
  /// the app's fixed [DestinationCategory] set — good enough to pick a
  /// sensible icon/label, not meant to be exhaustive.
  DestinationCategory _categoryFromOsmTags({String? category, String? type}) {
    switch (type) {
      case 'restaurant':
      case 'fast_food':
        return DestinationCategory.restaurant;
      case 'cafe':
        return DestinationCategory.cafe;
      case 'museum':
        return DestinationCategory.museum;
      case 'viewpoint':
        return DestinationCategory.viewpoint;
      case 'park':
        return DestinationCategory.park;
      case 'beach':
        return DestinationCategory.beach;
      case 'waterfall':
        return DestinationCategory.waterfall;
      case 'place_of_worship':
      case 'religious':
      case 'memorial':
      case 'monument':
        return DestinationCategory.heritageSite;
      case 'artwork':
        return DestinationCategory.art;
    }
    switch (category) {
      case 'historic':
        return DestinationCategory.heritageSite;
      case 'natural':
        return DestinationCategory.park;
      case 'shop':
        return DestinationCategory.craft;
      case 'tourism':
        return DestinationCategory.attraction;
    }
    return DestinationCategory.attraction;
  }
}
