import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

import '../../itinerary_planning/model/nominatim_geocoding_service.dart';
import 'eco_partner.dart';

abstract interface class EcoHotelSource {
  Future<List<EcoPartner>> nearby(
    EcoDestination destination, {
    double? radiusKm,
  });
}

abstract interface class EcoMapSource {
  Future<List<EcoPartner>> nearby(
    EcoDestination destination, {
    double? radiusKm,
  });
}

abstract interface class EcoTransitSource {
  Future<List<EcoPartner>> nearby(
    EcoDestination destination, {
    double? radiusKm,
  });
}

abstract interface class EcoPartnerImageSource {
  Future<List<EcoPartner>> enrich(List<EcoPartner> partners);
}

class EcoPartnerRepository {
  EcoPartnerRepository({
    EcoHotelSource? hotels,
    EcoMapSource? map,
    EcoTransitSource? transit,
    EcoPartnerImageSource? images,
    NominatimGeocodingService? geocoder,
  }) : _hotels = hotels ?? SupabaseEcoHotelSource(),
       _map = map ?? OverpassEcoSource(),
       _transit = transit ?? SupabaseGtfsSource(),
       _images = images ?? MapillaryPartnerImageSource(),
       _geocoder = geocoder ?? NominatimGeocodingService();

  final EcoHotelSource _hotels;
  final EcoMapSource _map;
  final EcoTransitSource _transit;
  final EcoPartnerImageSource _images;
  final NominatimGeocodingService _geocoder;
  final Map<String, ({DateTime at, EcoPartnerSearchResult value})> _cache = {};
  static const geocodingTimeout = Duration(seconds: 8);

  Future<EcoPartnerSearchResult> searchDestination(
    String query, {
    bool refresh = false,
    double? radiusKm = 10,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) throw const EcoSearchException('Enter a destination.');
    final matches = await _geocoder.search(clean).timeout(geocodingTimeout);
    if (matches.isEmpty) {
      throw const EcoSearchException('Destination not found in Malaysia.');
    }
    final first = matches.first;
    return searchCoordinates(
      EcoDestination(
        [first.name, first.city].where((e) => e.trim().isNotEmpty).join(', '),
        first.location.latitude,
        first.location.longitude,
      ),
      refresh: refresh,
      radiusKm: radiusKm,
    );
  }

  Future<EcoPartnerSearchResult> searchCoordinates(
    EcoDestination destination, {
    bool refresh = false,
    double? radiusKm = 10,
  }) async {
    final key =
        '${destination.latitude.toStringAsFixed(3)}:${destination.longitude.toStringAsFixed(3)}:${radiusKm ?? 'my'}';
    final cached = _cache[key];
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
      return cached.value;
    }

    final warnings = <String>[];
    Future<List<EcoPartner>> protect(
      String name,
      Future<List<EcoPartner>> future, {
      required Duration timeout,
    }) async {
      try {
        return await future.timeout(timeout);
      } on EcoProviderException catch (error) {
        warnings.add(error.message);
        return const [];
      } catch (_) {
        warnings.add('$name is temporarily unavailable.');
        return const [];
      }
    }

    final groups = await Future.wait([
      protect(
        'GSTC hotel data',
        _hotels.nearby(destination, radiusKm: radiusKm),
        timeout: const Duration(seconds: 7),
      ),
      protect(
        'OpenStreetMap dining and EV data',
        _map.nearby(destination, radiusKm: radiusKm),
        timeout: const Duration(seconds: 9),
      ),
      protect(
        'Public transport data',
        _transit.nearby(destination, radiusKm: radiusKm),
        timeout: const Duration(seconds: 7),
      ),
    ]);
    final partners =
        groups
            .expand((e) => e)
            .map(
              (e) => e.withDistance(
                distanceKm(
                  destination.latitude,
                  destination.longitude,
                  e.latitude,
                  e.longitude,
                ),
              ),
            )
            .where((e) => radiusKm == null || e.distanceKm <= radiusKm)
            .toList()
          ..sort(_rank);
    List<EcoPartner> enriched = partners;
    try {
      enriched = await _images
          .enrich(partners)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Imagery is optional; recommendation data must still be displayed.
    }
    final result = EcoPartnerSearchResult(
      destination: destination,
      partners: enriched,
      warnings: warnings,
    );
    _cache[key] = (at: DateTime.now(), value: result);
    return result;
  }

  static int _rank(EcoPartner a, EcoPartner b) {
    int score(EcoPartner p) {
      if (p.gstcVerified) return 100;
      if (p.veganClassification == 'Vegan') return 90;
      if (const ['MRT', 'LRT', 'Monorail', 'KTM'].contains(p.subtype))
        return 85;
      if (p.subtype == 'EV charging') return 80;
      if (p.veganClassification == 'Vegetarian') return 75;
      if (p.subtype == 'Bus') return 70;
      return 50;
    }

    final relevance = score(b).compareTo(score(a));
    return relevance != 0 ? relevance : a.distanceKm.compareTo(b.distanceKm);
  }

  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    double rad(double value) => value * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}

class EcoSearchException implements Exception {
  const EcoSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

class EcoProviderException implements Exception {
  const EcoProviderException(this.message);
  final String message;
}

class MapillaryPartnerImageSource implements EcoPartnerImageSource {
  MapillaryPartnerImageSource({Dio? dio, String? accessToken})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 4),
            ),
          ),
      _accessToken =
          accessToken ?? const String.fromEnvironment('MAPILLARY_ACCESS_TOKEN');

  final Dio _dio;
  final String _accessToken;

  @override
  Future<List<EcoPartner>> enrich(List<EcoPartner> partners) async {
    if (_accessToken.trim().isEmpty) return partners;
    final candidates = <EcoPartner>[
      ...partners
          .where(
            (partner) =>
                partner.category == EcoPartnerCategory.dining &&
                partner.imageUrl == null,
          )
          .take(12),
      ...partners
          .where(
            (partner) =>
                partner.category == EcoPartnerCategory.transport &&
                partner.imageUrl == null,
          )
          .take(12),
    ];
    if (candidates.isEmpty) return partners;
    final images = await Future.wait(candidates.map(_nearestImage));
    final replacements = <String, EcoPartner>{};
    for (var index = 0; index < candidates.length; index++) {
      final image = images[index];
      if (image != null) replacements[candidates[index].id] = image;
    }
    return partners
        .map((partner) => replacements[partner.id] ?? partner)
        .toList();
  }

  Future<EcoPartner?> _nearestImage(EcoPartner partner) async {
    const radiusKm = .1;
    final box = _box(partner.latitude, partner.longitude, radiusKm);
    try {
      final response = await _dio.get<dynamic>(
        'https://graph.mapillary.com/images',
        queryParameters: {
          'bbox': '${box.$3},${box.$1},${box.$4},${box.$2}',
          'fields': 'id,geometry,captured_at,thumb_1024_url',
          'limit': 10,
        },
        options: Options(headers: {'Authorization': 'OAuth $_accessToken'}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final rows = (data['data'] as List? ?? const [])
          .whereType<Map<String, dynamic>>();
      Map<String, dynamic>? best;
      var bestDistance = double.infinity;
      for (final row in rows) {
        final coordinates =
            ((row['geometry'] as Map?)?['coordinates'] as List?);
        if (coordinates == null || coordinates.length < 2) continue;
        final longitude = _nullableNumber(coordinates[0]);
        final latitude = _nullableNumber(coordinates[1]);
        if (latitude == null || longitude == null) continue;
        final distance = EcoPartnerRepository.distanceKm(
          partner.latitude,
          partner.longitude,
          latitude,
          longitude,
        );
        if (distance < bestDistance) {
          bestDistance = distance;
          best = row;
        }
      }
      if (best == null || bestDistance > radiusKm) return null;
      final thumbnail = '${best['thumb_1024_url'] ?? ''}';
      final imageId = '${best['id'] ?? ''}';
      if (thumbnail.isEmpty || imageId.isEmpty) return null;
      final captured = best['captured_at'];
      return partner.withImage(
        url: thumbnail,
        imageSourceName: 'Nearby street-level image · Mapillary',
        imageSourceUrl:
            'https://www.mapillary.com/app/?pKey=$imageId&focus=photo',
        capturedAt: captured is num
            ? DateTime.fromMillisecondsSinceEpoch(captured.toInt())
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class SupabaseEcoHotelSource implements EcoHotelSource {
  SupabaseEcoHotelSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<List<EcoPartner>> nearby(EcoDestination d, {double? radiusKm}) async {
    dynamic rows;
    try {
      if (radiusKm == null) {
        rows = await _client
            .from('eco_hotels')
            .select()
            .limit(500)
            .timeout(const Duration(seconds: 6));
      } else {
        final box = _box(d.latitude, d.longitude, radiusKm);
        rows = await _client
            .from('eco_hotels')
            .select()
            .gte('latitude', box.$1)
            .lte('latitude', box.$2)
            .gte('longitude', box.$3)
            .lte('longitude', box.$4)
            .timeout(const Duration(seconds: 6));
      }
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        throw const EcoProviderException(
          'Hotel recommendations are not configured yet. Apply the Eco Partner Supabase migration.',
        );
      }
      rethrow;
    }
    return (rows as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      final verifiedAt = DateTime.tryParse(
        '${row['certification_verified_at'] ?? ''}',
      );
      final expiresAt = DateTime.tryParse(
        '${row['certification_expires_at'] ?? ''}',
      );
      final evidenceUrl = '${row['certification_evidence_url'] ?? ''}'.trim();
      final verified =
          row['gstc_certified'] == true &&
          verifiedAt != null &&
          evidenceUrl.isNotEmpty &&
          (expiresAt == null || expiresAt.isAfter(DateTime.now()));
      return EcoPartner(
        id: 'hotel:${row['id']}',
        name: '${row['name']}',
        category: EcoPartnerCategory.stay,
        subtype: 'Hotel',
        latitude: _number(row['latitude']),
        longitude: _number(row['longitude']),
        address: '${row['address'] ?? ''}',
        sustainabilityLabel: verified
            ? 'GSTC verified'
            : 'Certification not verified',
        evidence: verified
            ? '${row['certification_body'] ?? 'GSTC-recognised certification'}'
            : 'No current complete GSTC evidence',
        sourceName: 'Curated GSTC records',
        sourceUrl: evidenceUrl,
        lastUpdated:
            DateTime.tryParse('${row['updated_at'] ?? ''}') ?? DateTime.now(),
        priceBand: row['price_band'] as String?,
        website: row['website_url'] as String?,
        imageUrl: row['image_url'] as String?,
        gstcVerified: verified,
      );
    }).toList();
  }
}

class SupabaseGtfsSource implements EcoTransitSource {
  SupabaseGtfsSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  @override
  Future<List<EcoPartner>> nearby(EcoDestination d, {double? radiusKm}) async {
    dynamic rows;
    try {
      if (radiusKm == null) {
        rows = await _client
            .from('gtfs_stops')
            .select('*, gtfs_stop_routes(gtfs_routes(*))')
            .limit(500)
            .timeout(const Duration(seconds: 6));
      } else {
        final box = _box(d.latitude, d.longitude, radiusKm);
        rows = await _client
            .from('gtfs_stops')
            .select('*, gtfs_stop_routes(gtfs_routes(*))')
            .gte('latitude', box.$1)
            .lte('latitude', box.$2)
            .gte('longitude', box.$3)
            .lte('longitude', box.$4)
            .limit(200)
            .timeout(const Duration(seconds: 6));
      }
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        throw const EcoProviderException(
          'Public transport recommendations are not configured yet. Apply the migration and run the GTFS sync.',
        );
      }
      rethrow;
    }
    return (rows as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      final joins = (row['gtfs_stop_routes'] as List? ?? const []);
      final routes = joins
          .map((j) => (j as Map<String, dynamic>)['gtfs_routes'])
          .whereType<Map<String, dynamic>>()
          .toList();
      final names = routes
          .map((r) => '${r['short_name'] ?? r['long_name'] ?? ''}'.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      final modes = routes.map((r) => '${r['mode'] ?? 'Bus'}').toList();
      final mode = _preferredMode(modes);
      return EcoPartner(
        id: 'stop:${row['id']}',
        name: '${row['name']}',
        category: EcoPartnerCategory.transport,
        subtype: mode,
        latitude: _number(row['latitude']),
        longitude: _number(row['longitude']),
        address: '${row['address'] ?? ''}',
        sustainabilityLabel: '$mode public transport',
        evidence: names.isEmpty
            ? 'Official GTFS stop'
            : 'Routes: ${names.join(', ')}',
        sourceName: '${row['source_name'] ?? 'Official Malaysia GTFS'}',
        sourceUrl:
            '${row['source_url'] ?? 'https://developer.data.gov.my/realtime-api/gtfs-static'}',
        lastUpdated:
            DateTime.tryParse('${row['updated_at'] ?? ''}') ?? DateTime.now(),
        routeNames: names,
      );
    }).toList();
  }
}

class OverpassEcoSource implements EcoMapSource {
  OverpassEcoSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 6),
              sendTimeout: const Duration(seconds: 4),
              headers: const {'User-Agent': 'HiddenGemTouristAppFYP/1.0'},
            ),
          );
  final Dio _dio;
  @override
  Future<List<EcoPartner>> nearby(EcoDestination d, {double? radiusKm}) async {
    try {
      final fallback = await _nominatimFallback(d, radiusKm);
      if (fallback.isNotEmpty) return fallback;
    } catch (_) {
      // Continue to the exhaustive Overpass queries below.
    }
    final around = ((radiusKm ?? 150) * 1000).round();
    final area = radiusKm == null
        ? 'area["ISO3166-1"="MY"][admin_level=2]->.searchArea;'
        : '';
    final scope = radiusKm == null
        ? '(area.searchArea)'
        : '(around:$around,${d.latitude},${d.longitude})';
    final queries = [
      '''[out:json][timeout:10];$area(
nwr$scope[amenity~"restaurant|cafe"][diet:vegan];
nwr$scope[amenity~"restaurant|cafe"][diet:vegetarian];
);out center tags 75;''',
      '''[out:json][timeout:10];$area(
nwr$scope[amenity=charging_station];
);out center tags 75;''',
      '''[out:json][timeout:10];$area(
nwr$scope[amenity=bus_station];
nwr$scope[public_transport=station];
nwr$scope[railway~"station|halt|tram_stop"];
);out center tags 100;''',
    ];
    var failures = 0;
    final groups = await Future.wait(
      List.generate(queries.length, (index) async {
        try {
          return await _request(queries[index], index);
        } catch (_) {
          failures++;
          return const <Map<String, dynamic>>[];
        }
      }),
    );
    final overpass = groups
        .expand((group) => group)
        .map(mapElement)
        .whereType<EcoPartner>();
    final combined = <String, EcoPartner>{
      for (final partner in overpass) partner.id: partner,
    };
    if (combined.isEmpty && failures == queries.length) {
      throw const EcoProviderException(
        'OpenStreetMap dining and EV data is temporarily unavailable.',
      );
    }
    return combined.values.toList();
  }

  Future<List<EcoPartner>> _nominatimFallback(
    EcoDestination d,
    double? radiusKm,
  ) async {
    final box = radiusKm == null
        ? (0.8, 7.5, 99.6, 119.3)
        : _box(d.latitude, d.longitude, radiusKm);
    final viewbox = '${box.$3},${box.$2},${box.$4},${box.$1}';
    final results = <EcoPartner>[];
    const queries = [
      'charging station',
      'vegan restaurant',
      'vegetarian restaurant',
    ];
    for (var index = 0; index < queries.length; index++) {
      final query = queries[index];
      final response = await _dio.get<dynamic>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'countrycodes': 'my',
          'bounded': 1,
          'viewbox': viewbox,
          'extratags': 1,
          'addressdetails': 1,
          'limit': 30,
        },
      );
      final rows = response.data is List ? response.data as List : const [];
      for (final raw in rows.whereType<Map<String, dynamic>>()) {
        final partner = _mapNominatim(raw);
        if (partner != null) results.add(partner);
      }
      // Nominatim's public usage policy requires requests to be spaced out.
      if (index < queries.length - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return <String, EcoPartner>{
      for (final partner in results) partner.id: partner,
    }.values.toList();
  }

  static EcoPartner? _mapNominatim(Map<String, dynamic> row) {
    final lat = _nullableNumber(row['lat']);
    final lon = _nullableNumber(row['lon']);
    if (lat == null || lon == null) return null;
    final extras =
        (row['extratags'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final osmType = '${row['osm_type'] ?? 'node'}'.toLowerCase();
    final osmId = '${row['osm_id']}';
    final type = '${row['type'] ?? ''}'.toLowerCase();
    final category = '${row['category'] ?? ''}'.toLowerCase();
    final name =
        '${row['name'] ?? row['display_name'] ?? 'OpenStreetMap place'}';
    final sourceUrl = 'https://www.openstreetmap.org/$osmType/$osmId';
    if (type == 'charging_station') {
      return EcoPartner(
        id: 'osm:$osmType:$osmId',
        name: name,
        category: EcoPartnerCategory.transport,
        subtype: 'EV charging',
        latitude: lat,
        longitude: lon,
        address: '${row['display_name'] ?? ''}',
        sustainabilityLabel: 'EV charging infrastructure',
        evidence: 'Charging station mapped in OpenStreetMap.',
        sourceName: 'OpenStreetMap via Nominatim',
        sourceUrl: sourceUrl,
        lastUpdated: DateTime.now(),
        imageUrl: _osmImageUrl(extras),
        chargerDetails: ['operator', 'capacity', 'access']
            .where((key) => '${extras[key] ?? ''}'.isNotEmpty)
            .map((key) => '$key: ${extras[key]}')
            .join(' · '),
      );
    }
    final diet = classifyDiet(extras);
    if (diet != null) {
      return EcoPartner(
        id: 'osm:$osmType:$osmId',
        name: name,
        category: EcoPartnerCategory.dining,
        subtype: type == 'cafe' ? 'Cafe' : 'Restaurant',
        latitude: lat,
        longitude: lon,
        address: '${row['display_name'] ?? ''}',
        sustainabilityLabel: diet,
        evidence: 'Classification comes from explicit OpenStreetMap diet tags.',
        sourceName: 'OpenStreetMap via Nominatim',
        sourceUrl: sourceUrl,
        lastUpdated: DateTime.now(),
        imageUrl: _osmImageUrl(extras),
        veganClassification: diet,
      );
    }
    if (category == 'railway' ||
        const ['station', 'halt', 'tram_stop'].contains(type)) {
      return EcoPartner(
        id: 'osm:$osmType:$osmId',
        name: name,
        category: EcoPartnerCategory.transport,
        subtype: type == 'tram_stop' ? 'Light rail' : 'Rail',
        latitude: lat,
        longitude: lon,
        address: '${row['display_name'] ?? ''}',
        sustainabilityLabel: 'Rail public transport',
        evidence: 'Rail station mapped in OpenStreetMap.',
        sourceName: 'OpenStreetMap via Nominatim',
        sourceUrl: sourceUrl,
        lastUpdated: DateTime.now(),
        imageUrl: _osmImageUrl(extras),
      );
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _request(String query, int offset) async {
    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];
    final completer = Completer<List<Map<String, dynamic>>>();
    var failures = 0;
    for (var attempt = 0; attempt < endpoints.length; attempt++) {
      final endpoint = endpoints[(offset + attempt) % endpoints.length];
      _dio
          .get<dynamic>(endpoint, queryParameters: {'data': query})
          .then((response) {
            if (completer.isCompleted) return;
            final data = response.data;
            if (data is Map<String, dynamic>) {
              completer.complete(
                ((data['elements'] as List?) ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .toList(),
              );
            } else if (++failures == endpoints.length) {
              completer.completeError(
                const EcoProviderException('OpenStreetMap request failed.'),
              );
            }
          })
          .catchError((Object _) {
            if (!completer.isCompleted && ++failures == endpoints.length) {
              completer.completeError(
                const EcoProviderException('OpenStreetMap request failed.'),
              );
            }
          });
    }
    return completer.future;
  }

  static EcoPartner? mapElement(Map<String, dynamic> element) {
    final tags =
        (element['tags'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final center = (element['center'] as Map?)?.cast<String, dynamic>();
    final lat = _nullableNumber(element['lat'] ?? center?['lat']);
    final lon = _nullableNumber(element['lon'] ?? center?['lon']);
    if (lat == null || lon == null) return null;
    final type = '${element['type']}';
    final id = '${element['id']}';
    final updated = DateTime.now();
    if (tags['amenity'] == 'charging_station') {
      final details = ['operator', 'access', 'capacity']
          .where((k) => '${tags[k] ?? ''}'.isNotEmpty)
          .map((k) => '$k: ${tags[k]}')
          .toList();
      final sockets = tags.entries
          .where((e) => e.key.startsWith('socket:'))
          .map((e) => '${e.key.substring(7)}: ${e.value}');
      return EcoPartner(
        id: 'osm:$type:$id',
        name: '${tags['name'] ?? tags['operator'] ?? 'EV charging station'}',
        category: EcoPartnerCategory.transport,
        subtype: 'EV charging',
        latitude: lat,
        longitude: lon,
        address: _osmAddress(tags),
        sustainabilityLabel: 'EV charging infrastructure',
        evidence: 'Mapped charging station; no emissions claim is implied.',
        sourceName: 'OpenStreetMap',
        sourceUrl: 'https://www.openstreetmap.org/$type/$id',
        lastUpdated: updated,
        imageUrl: _osmImageUrl(tags),
        chargerDetails: [...details, ...sockets].join(' · '),
      );
    }
    if (tags['highway'] == 'bus_stop' ||
        tags['amenity'] == 'bus_station' ||
        tags['public_transport'] != null ||
        tags['railway'] != null) {
      final railway = '${tags['railway'] ?? ''}'.toLowerCase();
      final station = '${tags['station'] ?? ''}'.toLowerCase();
      final name = '${tags['name'] ?? ''}'.toLowerCase();
      final subtype =
          tags['highway'] == 'bus_stop' || tags['amenity'] == 'bus_station'
          ? 'Bus'
          : station == 'monorail' || name.contains('monorail')
          ? 'Monorail'
          : railway == 'tram_stop'
          ? 'Light rail'
          : 'Rail';
      return EcoPartner(
        id: 'osm:$type:$id',
        name:
            '${tags['name'] ?? (subtype == 'Bus' ? 'Bus stop' : 'Rail station')}',
        category: EcoPartnerCategory.transport,
        subtype: subtype,
        latitude: lat,
        longitude: lon,
        address: _osmAddress(tags),
        sustainabilityLabel: '$subtype public transport',
        evidence:
            'Nearby public transport infrastructure mapped in OpenStreetMap.',
        sourceName: 'OpenStreetMap',
        sourceUrl: 'https://www.openstreetmap.org/$type/$id',
        lastUpdated: updated,
        imageUrl: _osmImageUrl(tags),
        routeNames: '${tags['route_ref'] ?? tags['ref'] ?? ''}'
            .split(';')
            .where((value) => value.trim().isNotEmpty)
            .toList(),
      );
    }
    final classification = classifyDiet(tags);
    if (classification == null) return null;
    return EcoPartner(
      id: 'osm:$type:$id',
      name: '${tags['name'] ?? 'Unnamed ${tags['amenity'] ?? 'dining venue'}'}',
      category: EcoPartnerCategory.dining,
      subtype: '${tags['amenity'] == 'cafe' ? 'Cafe' : 'Restaurant'}',
      latitude: lat,
      longitude: lon,
      address: _osmAddress(tags),
      sustainabilityLabel: classification,
      evidence: 'Classification comes only from explicit OSM diet tags.',
      sourceName: 'OpenStreetMap',
      sourceUrl: 'https://www.openstreetmap.org/$type/$id',
      lastUpdated: updated,
      website: tags['website'] as String?,
      imageUrl: _osmImageUrl(tags),
      veganClassification: classification,
    );
  }

  static String? classifyDiet(Map<String, dynamic> tags) {
    final vegan = '${tags['diet:vegan'] ?? ''}'.toLowerCase();
    final vegetarian = '${tags['diet:vegetarian'] ?? ''}'.toLowerCase();
    if (vegan == 'only') return 'Vegan';
    if (vegetarian == 'only') return 'Vegetarian';
    if (vegan == 'yes' || vegetarian == 'yes') return 'Veg Options';
    return null;
  }
}

(double, double, double, double) _box(double lat, double lon, double radiusKm) {
  final latDelta = radiusKm / 111.0;
  final lonDelta =
      radiusKm /
      (111.0 * math.cos(lat * math.pi / 180).abs().clamp(.1, 1)).toDouble();
  return (lat - latDelta, lat + latDelta, lon - lonDelta, lon + lonDelta);
}

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.parse('$value');
double? _nullableNumber(dynamic value) =>
    value == null ? null : double.tryParse('$value');
String? _osmImageUrl(Map<String, dynamic> tags) {
  final direct = '${tags['image'] ?? ''}'.trim();
  final directUri = Uri.tryParse(direct);
  if (directUri != null &&
      (directUri.scheme == 'https' || directUri.scheme == 'http')) {
    return directUri.toString();
  }
  final commons = '${tags['wikimedia_commons'] ?? ''}'.trim();
  if (commons.toLowerCase().startsWith('file:') && commons.length > 5) {
    return Uri.https(
      'commons.wikimedia.org',
      '/wiki/Special:Redirect/file/${commons.substring(5)}',
    ).toString();
  }
  return null;
}

String _osmAddress(Map<String, dynamic> tags) => [
  tags['addr:housenumber'],
  tags['addr:street'],
  tags['addr:city'],
].where((e) => e != null && '$e'.isNotEmpty).join(', ');
String _preferredMode(List<String> modes) {
  for (final mode in const ['MRT', 'LRT', 'Monorail', 'KTM', 'Rail', 'Bus']) {
    if (modes.any((e) => e.toLowerCase() == mode.toLowerCase())) return mode;
  }
  return modes.isEmpty ? 'Public transport' : modes.first;
}
