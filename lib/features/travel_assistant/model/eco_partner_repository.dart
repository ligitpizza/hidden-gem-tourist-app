import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'eco_partner.dart';

abstract interface class EcoPartnerRepositoryContract {
  /// Searches Eco Partner names. The query is evaluated by Supabase, never by
  /// a public geocoder.
  Future<EcoPartnerSearchResult> searchByName(
    String query, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  });

  Future<EcoPartnerSearchResult> searchCoordinates(
    EcoDestination destination, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  });

  /// Images are already cached in the catalogue, so this method performs no
  /// network enrichment. It remains part of the contract for UI compatibility.
  Future<EcoPartnerSearchResult> enrichResult(
    EcoPartnerSearchResult value, {
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
  });
}

/// Server-side catalogue operations used by the production controller.
/// Lightweight test repositories can keep implementing the base contract.
abstract interface class EcoPartnerCatalogRepositoryContract {
  Future<EcoPartnerSearchResult> loadHome({
    required EcoDestination destination,
    required EcoPartnerSearchScope scope,
    EcoDestination? distanceOrigin,
  });

  Future<EcoPartnerSearchResult> searchPage({
    required EcoDestination destination,
    required EcoPartnerSearchScope scope,
    EcoDestination? distanceOrigin,
    String? query,
    String? category,
    String sort = 'recommended',
    int limit = 50,
    int offset = 0,
  });

  Future<List<EcoPartner>> suggestions(String query, {int limit = 6});
}

class EcoPartnerRepository
    implements
        EcoPartnerRepositoryContract,
        EcoPartnerCatalogRepositoryContract {
  EcoPartnerRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<EcoPartnerSearchResult> loadHome({
    required EcoDestination destination,
    required EcoPartnerSearchScope scope,
    EcoDestination? distanceOrigin,
  }) async {
    final origin = distanceOrigin;
    try {
      final response = await _client.rpc(
        'eco_partner_home',
        params: {
          'p_state': scope.type == EcoPartnerSearchScopeType.state
              ? scope.state
              : null,
          'p_latitude': origin?.latitude,
          'p_longitude': origin?.longitude,
          'p_radius_km': scope.type == EcoPartnerSearchScopeType.nearby
              ? scope.radiusKm
              : null,
          'p_per_section': 8,
        },
      );
      final sections = (response as Map).cast<String, dynamic>();
      final unique = <String, EcoPartner>{};
      for (final key in const [
        'recommended',
        'hotel',
        'dining',
        'transport',
        'ev',
      ]) {
        for (final raw in sections[key] as List? ?? const []) {
          final partner = _mapRow((raw as Map).cast<String, dynamic>());
          unique.putIfAbsent(partner.id, () => partner);
        }
      }
      return EcoPartnerSearchResult(
        destination: destination,
        partners: unique.values.toList(growable: false),
      );
    } on PostgrestException catch (error) {
      throw _catalogException(error);
    }
  }

  @override
  Future<EcoPartnerSearchResult> searchByName(
    String query, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) {
    final clean = query.trim();
    if (clean.isEmpty) {
      throw const EcoSearchException('Enter an Eco Partner name.');
    }
    return searchPage(
      destination: const EcoDestination(
        'Eco Partner name search',
        4.2105,
        101.9758,
      ),
      scope: const EcoPartnerSearchScope.nationwide(),
      query: clean,
      limit: 500,
    );
  }

  @override
  Future<EcoPartnerSearchResult> searchCoordinates(
    EcoDestination destination, {
    bool refresh = false,
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
    bool includeImages = true,
  }) => searchPage(
    destination: destination,
    scope: scope,
    distanceOrigin: destination,
    limit: 500,
  );

  @override
  Future<EcoPartnerSearchResult> searchPage({
    required EcoDestination destination,
    required EcoPartnerSearchScope scope,
    EcoDestination? distanceOrigin,
    String? query,
    String? category,
    String sort = 'recommended',
    int limit = 50,
    int offset = 0,
  }) async {
    final origin = distanceOrigin;
    final parameters = <String, dynamic>{
      'p_query': _nullableText(query),
      'p_state': scope.type == EcoPartnerSearchScopeType.state
          ? scope.state
          : null,
      'p_category': _nullableText(category),
      'p_latitude': origin?.latitude,
      'p_longitude': origin?.longitude,
      'p_radius_km': scope.type == EcoPartnerSearchScopeType.nearby
          ? scope.radiusKm
          : null,
      'p_sort': sort,
      'p_limit': limit,
      'p_offset': offset,
    };
    try {
      final response = await _client.rpc(
        'search_eco_partners',
        params: parameters,
      );
      final rows = (response as List)
          .map((raw) => (raw as Map).cast<String, dynamic>())
          .toList(growable: false);
      return EcoPartnerSearchResult(
        destination: destination,
        partners: rows.map(_mapRow).toList(growable: false),
        totalCount: rows.isEmpty
            ? 0
            : (rows.first['total_count'] as num?)?.toInt() ?? rows.length,
      );
    } on PostgrestException catch (error) {
      throw _catalogException(error);
    }
  }

  @override
  Future<List<EcoPartner>> suggestions(String query, {int limit = 6}) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];
    final result = await searchPage(
      destination: const EcoDestination('Malaysia', 4.2105, 101.9758),
      scope: const EcoPartnerSearchScope.nationwide(),
      query: clean,
      sort: 'name_asc',
      limit: limit,
    );
    return result.partners;
  }

  @override
  Future<EcoPartnerSearchResult> enrichResult(
    EcoPartnerSearchResult value, {
    EcoPartnerSearchScope scope = const EcoPartnerSearchScope.nearby(10),
  }) async => value;

  EcoPartner _mapRow(Map<String, dynamic> row) {
    final transitRoutes = (row['transit_routes'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (route) => EcoTransitRouteInfo(
            mode: '${route['mode'] ?? 'Transit'}',
            shortName: _nullableText(route['shortName']),
            longName: _nullableText(route['longName']),
          ),
        )
        .toList(growable: false);
    final chargingValue = row['charging_details'];
    final rawImageUrl = _nullableText(row['image_url']);
    final rawImageSourceName = _nullableText(row['image_source_name']);
    final rawImageSourceUrl = _nullableText(row['image_source_url']);
    final legacyMapillary = ecoPartnerImageIsLegacyMapillary(
      imageUrl: rawImageUrl,
      imageSourceName: rawImageSourceName,
      imageSourceUrl: rawImageSourceUrl,
    );
    return EcoPartner(
      id: '${row['id']}',
      name: '${row['name']}',
      category: EcoPartnerCategory.values.firstWhere(
        (value) => value.name == row['category'],
        orElse: () => EcoPartnerCategory.transport,
      ),
      subtype: '${row['subtype'] ?? ''}',
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      address: '${row['address'] ?? ''}',
      state: _nullableText(row['state']),
      distanceKm: (row['distance_km'] as num?)?.toDouble(),
      sustainabilityLabel: '${row['sustainability_label'] ?? ''}',
      evidence: '${row['evidence'] ?? ''}',
      sourceName: '${row['source_name'] ?? ''}',
      sourceUrl: '${row['source_url'] ?? ''}',
      lastUpdated:
          DateTime.tryParse('${row['source_updated_at'] ?? ''}') ??
          DateTime.now(),
      priceBand: _nullableText(row['price_band']),
      website: _nullableText(row['website']),
      imageUrl: _resolveImageUrl(
        ecoPartnerSafeImageValue(
          rawImageUrl,
          isLegacyMapillary: legacyMapillary,
        ),
      ),
      imageSourceName: ecoPartnerSafeImageValue(
        rawImageSourceName,
        isLegacyMapillary: legacyMapillary,
      ),
      imageSourceUrl: ecoPartnerSafeImageValue(
        rawImageSourceUrl,
        isLegacyMapillary: legacyMapillary,
      ),
      imageCapturedAt: legacyMapillary
          ? null
          : DateTime.tryParse('${row['image_captured_at'] ?? ''}'),
      transitRoutes: transitRoutes,
      veganClassification: _nullableText(row['vegan_classification']),
      chargingDetails: chargingValue is Map
          ? EcoChargingDetails.fromJson(chargingValue.cast<String, dynamic>())
          : null,
      gstcVerified: row['gstc_verified'] == true,
    );
  }

  String? _resolveImageUrl(String? value) {
    if (value == null || !value.startsWith('storage://')) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.pathSegments.isEmpty) {
      return null;
    }
    try {
      return _client.storage
          .from(uri.host)
          .getPublicUrl(uri.pathSegments.join('/'));
    } catch (_) {
      return null;
    }
  }

  static String? _nullableText(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
  }

  static EcoSearchException _catalogException(PostgrestException error) {
    if (error.code == '42P01' ||
        error.code == 'PGRST202' ||
        error.code == 'PGRST205') {
      return const EcoSearchException(
        'Eco Partner information is temporarily unavailable. Please try again later.',
      );
    }
    return const EcoSearchException(
      'We couldn’t load Eco Partners. Please check your connection and try again.',
    );
  }

  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
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
