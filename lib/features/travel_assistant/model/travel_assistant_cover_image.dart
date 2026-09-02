import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'packing_location_source.dart';

enum TravelAssistantCoverSource { curated, wikipedia }

class TravelAssistantCoverImage {
  const TravelAssistantCoverImage({
    required this.imageUrl,
    required this.attribution,
    required this.source,
    this.attributionUrl,
  });

  final String imageUrl;
  final String attribution;
  final String? attributionUrl;
  final TravelAssistantCoverSource source;

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'attribution': attribution,
    'attributionUrl': attributionUrl,
    'source': source.name,
  };

  static TravelAssistantCoverImage? fromJson(Map<String, dynamic> json) {
    final imageUrl = '${json['imageUrl'] ?? ''}'.trim();
    final attribution = '${json['attribution'] ?? ''}'.trim();
    final sourceName = '${json['source'] ?? ''}';
    if (imageUrl.isEmpty || attribution.isEmpty) return null;
    final source = TravelAssistantCoverSource.values
        .where((value) => value.name == sourceName)
        .firstOrNull;
    if (source == null) return null;
    final attributionUrl = '${json['attributionUrl'] ?? ''}'.trim();
    return TravelAssistantCoverImage(
      imageUrl: imageUrl,
      attribution: attribution,
      attributionUrl: attributionUrl.isEmpty ? null : attributionUrl,
      source: source,
    );
  }
}

abstract interface class TravelAssistantCoverImageResolverContract {
  Future<TravelAssistantCoverImage?> resolve(PackingLocationOption location);
}

abstract interface class TravelAssistantCuratedCoverSourceContract {
  Future<TravelAssistantCoverImage?> resolve(PackingLocationOption location);
}

abstract interface class TravelAssistantWikimediaCoverSourceContract {
  Future<TravelAssistantCoverImage?> resolve(PackingLocationOption location);
}

abstract interface class TravelAssistantCoverCacheContract {
  Future<TravelAssistantCoverImage?> read(String locationId);

  Future<void> write(String locationId, TravelAssistantCoverImage image);
}

class TravelAssistantCoverImageResolver
    implements TravelAssistantCoverImageResolverContract {
  TravelAssistantCoverImageResolver({
    TravelAssistantCuratedCoverSourceContract? curated,
    TravelAssistantWikimediaCoverSourceContract? wikimedia,
    TravelAssistantCoverCacheContract? cache,
  }) : _curated = curated ?? SupabaseTravelAssistantCuratedCoverSource(),
       _wikimedia = wikimedia ?? WikimediaTravelAssistantCoverSource(),
       _cache = cache ?? SharedPreferencesTravelAssistantCoverCache();

  final TravelAssistantCuratedCoverSourceContract _curated;
  final TravelAssistantWikimediaCoverSourceContract _wikimedia;
  final TravelAssistantCoverCacheContract _cache;

  @override
  Future<TravelAssistantCoverImage?> resolve(
    PackingLocationOption location,
  ) async {
    try {
      final curated = await _curated.resolve(location);
      if (curated != null) return curated;
    } catch (_) {}

    try {
      final cached = await _cache.read(location.id);
      if (cached != null) return cached;
    } catch (_) {}

    try {
      final image = await _wikimedia.resolve(location);
      if (image == null) return null;
      await _cache.write(location.id, image);
      return image;
    } catch (_) {
      return null;
    }
  }
}

class SupabaseTravelAssistantCuratedCoverSource
    implements TravelAssistantCuratedCoverSourceContract {
  SupabaseTravelAssistantCuratedCoverSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<TravelAssistantCoverImage?> resolve(
    PackingLocationOption location,
  ) async {
    final destinationId = location.destinationId?.trim() ?? '';
    if (destinationId.isNotEmpty) {
      try {
        final row = await _client
            .from('destinations')
            .select('images')
            .eq('id', destinationId)
            .maybeSingle();
        final images = row?['images'];
        if (images is List) {
          final imageUrl = images
              .whereType<String>()
              .map((value) => value.trim())
              .where(_isWebUrl)
              .firstOrNull;
          if (imageUrl != null) {
            return TravelAssistantCoverImage(
              imageUrl: imageUrl,
              attribution: 'Destination photo',
              source: TravelAssistantCoverSource.curated,
            );
          }
        }
      } catch (_) {}
    }

    final trustedUrl = location.trustedImageUrl?.trim() ?? '';
    if (!_isWebUrl(trustedUrl) || _isMapillary(location)) return null;
    final attribution = location.trustedImageAttribution?.trim();
    final attributionUrl = location.trustedImageSourceUrl?.trim();
    return TravelAssistantCoverImage(
      imageUrl: trustedUrl,
      attribution: attribution?.isNotEmpty == true
          ? attribution!
          : 'Destination photo',
      attributionUrl: _isWebUrl(attributionUrl ?? '') ? attributionUrl : null,
      source: TravelAssistantCoverSource.curated,
    );
  }

  static bool _isMapillary(PackingLocationOption location) => [
    location.trustedImageUrl,
    location.trustedImageAttribution,
    location.trustedImageSourceUrl,
  ].whereType<String>().join(' ').toLowerCase().contains('mapillary');
}

class WikimediaTravelAssistantCoverSource
    implements TravelAssistantWikimediaCoverSourceContract {
  WikimediaTravelAssistantCoverSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              headers: const {
                'User-Agent':
                    'HiddenGemTouristApp/1.0 '
                    '(https://github.com/ligitpizza/hidden-gem-tourist-app; travel prep covers)',
              },
            ),
          );

  final Dio _dio;

  @override
  Future<TravelAssistantCoverImage?> resolve(
    PackingLocationOption location,
  ) async {
    final lookupName = location.coverLookupName.trim();
    if (lookupName.isEmpty) return null;
    final pageResponse = await _dio.get<dynamic>(
      'https://en.wikipedia.org/w/api.php',
      queryParameters: {
        'action': 'query',
        'format': 'json',
        'formatversion': 2,
        'redirects': 1,
        'titles': lookupName,
        'prop': 'pageimages|info',
        'piprop': 'thumbnail|name',
        'pithumbsize': 1200,
        'inprop': 'url',
        'origin': '*',
      },
    );
    final pages = _pagesFrom(pageResponse.data);
    final normalizedLookup = _normalize(lookupName);
    final page = pages
        .where(
          (value) =>
              value['missing'] != true &&
              _normalize('${value['title'] ?? ''}') == normalizedLookup,
        )
        .firstOrNull;
    if (page == null) return null;
    final thumbnail = page['thumbnail'];
    final thumbnailUrl = thumbnail is Map
        ? '${thumbnail['source'] ?? ''}'.trim()
        : '';
    final imageTitle = '${page['pageimage'] ?? ''}'.trim();
    if (!_isWebUrl(thumbnailUrl) || imageTitle.isEmpty) return null;

    final commonsResponse = await _dio.get<dynamic>(
      'https://commons.wikimedia.org/w/api.php',
      queryParameters: {
        'action': 'query',
        'format': 'json',
        'formatversion': 2,
        'titles': imageTitle.startsWith('File:')
            ? imageTitle
            : 'File:$imageTitle',
        'prop': 'imageinfo',
        'iiprop': 'url|extmetadata',
        'origin': '*',
      },
    );
    final commonsPage = _pagesFrom(commonsResponse.data).firstOrNull;
    final imageInfoValues = commonsPage?['imageinfo'];
    if (imageInfoValues is! List || imageInfoValues.isEmpty) return null;
    final imageInfo = imageInfoValues.first;
    if (imageInfo is! Map) return null;
    final metadata = imageInfo['extmetadata'];
    if (metadata is! Map) return null;
    final artist = _metadataValue(metadata, 'Artist');
    final license = _metadataValue(metadata, 'LicenseShortName');
    if (artist.isEmpty || license.isEmpty) return null;
    final descriptionUrl = '${imageInfo['descriptionurl'] ?? ''}'.trim();
    final pageUrl = '${page['fullurl'] ?? ''}'.trim();
    return TravelAssistantCoverImage(
      imageUrl: thumbnailUrl,
      attribution: 'Photo: $artist · $license',
      attributionUrl: _isWebUrl(descriptionUrl)
          ? descriptionUrl
          : _isWebUrl(pageUrl)
          ? pageUrl
          : null,
      source: TravelAssistantCoverSource.wikipedia,
    );
  }

  static List<Map<String, dynamic>> _pagesFrom(dynamic payload) {
    if (payload is! Map) return const [];
    final query = payload['query'];
    if (query is! Map) return const [];
    final pages = query['pages'];
    if (pages is! List) return const [];
    return pages
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList();
  }

  static String _metadataValue(Map<dynamic, dynamic> metadata, String key) {
    final value = metadata[key];
    if (value is! Map) return '';
    return _plainText('${value['value'] ?? ''}');
  }

  static String _plainText(String value) => value
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

class SharedPreferencesTravelAssistantCoverCache
    implements TravelAssistantCoverCacheContract {
  SharedPreferencesTravelAssistantCoverCache({
    Future<SharedPreferences> Function()? preferences,
    this.ttl = const Duration(days: 7),
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;
  final Duration ttl;

  String _key(String locationId) => 'travel_assistant_cover_v1_$locationId';
  List<String> _legacyKeys(String locationId) => [
    'travel_prep_cover_v1_$locationId',
    'smart_assistant_cover_v1_$locationId',
  ];

  @override
  Future<TravelAssistantCoverImage?> read(String locationId) async {
    final preferences = await _preferences();
    final key = _key(locationId);
    var sourceKey = key;
    var encoded = preferences.getString(key);
    if (encoded == null) {
      for (final legacyKey in _legacyKeys(locationId)) {
        encoded = preferences.getString(legacyKey);
        if (encoded == null) continue;
        sourceKey = legacyKey;
        await preferences.setString(key, encoded);
        await preferences.remove(legacyKey);
        sourceKey = key;
        break;
      }
    }
    if (encoded == null) return null;
    try {
      final value = (jsonDecode(encoded) as Map).cast<String, dynamic>();
      final savedAt = DateTime.tryParse('${value['savedAt'] ?? ''}');
      if (savedAt == null || DateTime.now().difference(savedAt) > ttl) {
        await preferences.remove(sourceKey);
        return null;
      }
      final image = value['image'];
      return image is Map
          ? TravelAssistantCoverImage.fromJson(image.cast<String, dynamic>())
          : null;
    } catch (_) {
      await preferences.remove(sourceKey);
      return null;
    }
  }

  @override
  Future<void> write(String locationId, TravelAssistantCoverImage image) async {
    final preferences = await _preferences();
    await preferences.setString(
      _key(locationId),
      jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'image': image.toJson(),
      }),
    );
  }
}

bool _isWebUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}
