import 'dart:convert';

import 'package:collab/features/travel_assistant/model/packing_location_source.dart';
import 'package:collab/features/travel_assistant/model/travel_assistant_cover_image.dart';
import 'package:collab/shared/models/destination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('curated cover takes priority over cache and Wikimedia', () async {
    final cache = _MemoryCoverCache()..image = _cachedCover;
    final wikimedia = _FakeWikimediaSource(_wikiCover);
    final resolver = TravelAssistantCoverImageResolver(
      curated: const _FakeCuratedSource(_curatedCover),
      wikimedia: wikimedia,
      cache: cache,
    );

    expect(await resolver.resolve(_location), same(_curatedCover));
    expect(cache.reads, 0);
    expect(wikimedia.calls, 0);
  });

  test('cached Wikimedia cover avoids another network lookup', () async {
    final cache = _MemoryCoverCache()..image = _cachedCover;
    final wikimedia = _FakeWikimediaSource(_wikiCover);
    final resolver = TravelAssistantCoverImageResolver(
      curated: const _FakeCuratedSource(null),
      wikimedia: wikimedia,
      cache: cache,
    );

    expect(await resolver.resolve(_location), same(_cachedCover));
    expect(wikimedia.calls, 0);
  });

  test('Wikimedia fallback is cached after a successful lookup', () async {
    final cache = _MemoryCoverCache();
    final resolver = TravelAssistantCoverImageResolver(
      curated: const _FakeCuratedSource(null),
      wikimedia: _FakeWikimediaSource(_wikiCover),
      cache: cache,
    );

    expect(await resolver.resolve(_location), same(_wikiCover));
    expect(cache.image, same(_wikiCover));
    expect(cache.writes, 1);
  });

  test('Mapillary street imagery is rejected as a trusted cover', () async {
    final source = SupabaseTravelAssistantCuratedCoverSource(
      client: SupabaseClient('https://example.supabase.co', 'test-key'),
    );
    const mapillaryLocation = PackingLocationOption(
      id: 'eco:1',
      label: 'Eco Cafe',
      subtitle: 'Saved Eco Partner',
      latitude: 3.14,
      longitude: 101.69,
      categories: {DestinationCategory.restaurant},
      trustedImageUrl: 'https://images.example.com/street.jpg',
      trustedImageAttribution: 'Nearby street-level image · Mapillary',
      trustedImageSourceUrl: 'https://www.mapillary.com/app/?pKey=1',
    );

    expect(await source.resolve(mapillaryLocation), isNull);
  });

  test('non-Mapillary saved partner image remains eligible', () async {
    final source = SupabaseTravelAssistantCuratedCoverSource(
      client: SupabaseClient('https://example.supabase.co', 'test-key'),
    );
    const partnerLocation = PackingLocationOption(
      id: 'eco:2',
      label: 'Eco Hotel',
      subtitle: 'Saved Eco Partner',
      latitude: 3.14,
      longitude: 101.69,
      categories: {DestinationCategory.attraction},
      trustedImageUrl: 'https://hotel.example.com/cover.jpg',
      trustedImageAttribution: 'Eco Hotel',
      trustedImageSourceUrl: 'https://hotel.example.com',
    );

    final result = await source.resolve(partnerLocation);
    expect(result?.imageUrl, 'https://hotel.example.com/cover.jpg');
    expect(result?.source, TravelAssistantCoverSource.curated);
  });

  test('Wikimedia exact page image includes author and licence', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host == 'en.wikipedia.org') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'query': {
                    'pages': [
                      {
                        'title': 'Kota Kinabalu',
                        'pageimage': 'Kota_Kinabalu.jpg',
                        'fullurl':
                            'https://en.wikipedia.org/wiki/Kota_Kinabalu',
                        'thumbnail': {
                          'source':
                              'https://upload.wikimedia.org/kota-kinabalu.jpg',
                        },
                      },
                    ],
                  },
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'query': {
                  'pages': [
                    {
                      'title': 'File:Kota_Kinabalu.jpg',
                      'imageinfo': [
                        {
                          'descriptionurl':
                              'https://commons.wikimedia.org/wiki/File:Kota_Kinabalu.jpg',
                          'extmetadata': {
                            'Artist': {
                              'value':
                                  '<a href="/wiki/User:Example">Example</a>',
                            },
                            'LicenseShortName': {'value': 'CC BY-SA 4.0'},
                          },
                        },
                      ],
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );
    final source = WikimediaTravelAssistantCoverSource(dio: dio);

    final result = await source.resolve(_location);

    expect(result?.imageUrl, 'https://upload.wikimedia.org/kota-kinabalu.jpg');
    expect(result?.attribution, 'Photo: Example · CC BY-SA 4.0');
    expect(
      result?.attributionUrl,
      'https://commons.wikimedia.org/wiki/File:Kota_Kinabalu.jpg',
    );
  });

  test('Wikimedia non-exact page is not used as a cover', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'query': {
                'pages': [
                  {
                    'title': 'Kinabalu Park',
                    'pageimage': 'Park.jpg',
                    'thumbnail': {
                      'source': 'https://upload.wikimedia.org/park.jpg',
                    },
                  },
                ],
              },
            },
          ),
        ),
      ),
    );

    expect(
      await WikimediaTravelAssistantCoverSource(dio: dio).resolve(_location),
      isNull,
    );
  });

  test('shared preferences cache expires stale cover metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = SharedPreferencesTravelAssistantCoverCache(
      ttl: Duration.zero,
    );
    await cache.write(_location.id, _wikiCover);

    expect(await cache.read(_location.id), isNull);
  });

  test('legacy cover cache keys migrate to Travel Assistant', () async {
    for (final legacyKey in [
      'travel_prep_cover_v1_${_location.id}',
      'smart_assistant_cover_v1_${_location.id}',
    ]) {
      SharedPreferences.setMockInitialValues({
        legacyKey: jsonEncode({
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'image': _wikiCover.toJson(),
        }),
      });
      final cache = SharedPreferencesTravelAssistantCoverCache();

      expect(await cache.read(_location.id), isNotNull);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(legacyKey), isNull);
      expect(
        preferences.getString('travel_assistant_cover_v1_${_location.id}'),
        isNotNull,
      );
    }
  });
}

const _location = PackingLocationOption(
  id: 'itinerary:1',
  label: 'Kota Kinabalu',
  subtitle: 'Saved itinerary',
  latitude: 5.98,
  longitude: 116.07,
  categories: {DestinationCategory.attraction},
  lookupName: 'Kota Kinabalu',
);

const _curatedCover = TravelAssistantCoverImage(
  imageUrl: 'https://example.com/curated.jpg',
  attribution: 'Destination photo',
  source: TravelAssistantCoverSource.curated,
);

const _cachedCover = TravelAssistantCoverImage(
  imageUrl: 'https://example.com/cached.jpg',
  attribution: 'Photo: Cached · CC BY 4.0',
  source: TravelAssistantCoverSource.wikipedia,
);

const _wikiCover = TravelAssistantCoverImage(
  imageUrl: 'https://example.com/wiki.jpg',
  attribution: 'Photo: Example · CC BY-SA 4.0',
  attributionUrl: 'https://commons.wikimedia.org/example',
  source: TravelAssistantCoverSource.wikipedia,
);

class _FakeCuratedSource implements TravelAssistantCuratedCoverSourceContract {
  const _FakeCuratedSource(this.image);

  final TravelAssistantCoverImage? image;

  @override
  Future<TravelAssistantCoverImage?> resolve(
    PackingLocationOption location,
  ) async => image;
}

class _FakeWikimediaSource
    implements TravelAssistantWikimediaCoverSourceContract {
  _FakeWikimediaSource(this.image);

  final TravelAssistantCoverImage? image;
  int calls = 0;

  @override
  Future<TravelAssistantCoverImage?> resolve(
    PackingLocationOption location,
  ) async {
    calls++;
    return image;
  }
}

class _MemoryCoverCache implements TravelAssistantCoverCacheContract {
  TravelAssistantCoverImage? image;
  int reads = 0;
  int writes = 0;

  @override
  Future<TravelAssistantCoverImage?> read(String locationId) async {
    reads++;
    return image;
  }

  @override
  Future<void> write(String locationId, TravelAssistantCoverImage image) async {
    writes++;
    this.image = image;
  }
}
