import 'package:collab/features/travel_prep/model/eco_partner.dart';
import 'package:collab/features/travel_prep/model/eco_partner_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Wikimedia exact match adds attributed image and preserves existing',
    () async {
      final dio = Dio();
      String? requestedTitles;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host == 'en.wikipedia.org') {
              requestedTitles = '${options.queryParameters['titles']}';
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'query': {
                      'pages': [
                        {
                          'title': 'Central Market Kuala Lumpur',
                          'pageimage': 'Central_Market_KL.jpg',
                          'thumbnail': {
                            'source':
                                'https://upload.wikimedia.org/central-market.jpg',
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
                        'title': 'File:Central_Market_KL.jpg',
                        'imageinfo': [
                          {
                            'descriptionurl':
                                'https://commons.wikimedia.org/wiki/File:Central_Market_KL.jpg',
                            'extmetadata': {
                              'Artist': {
                                'value': '<b>Example Photographer</b>',
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
      final existing = _partner(
        id: 'existing',
        name: 'Existing Hotel',
        category: EcoPartnerCategory.stay,
        imageUrl: 'https://hotel.example.com/photo.jpg',
      );
      final missing = _partner(
        id: 'market',
        name: 'Central Market Kuala Lumpur',
        category: EcoPartnerCategory.dining,
      );

      final result = await WikimediaPartnerImageSource(
        dio: dio,
      ).enrich([existing, missing]);

      expect(requestedTitles, 'Central Market Kuala Lumpur');
      expect(result.first.imageUrl, existing.imageUrl);
      expect(
        result.last.imageUrl,
        'https://upload.wikimedia.org/central-market.jpg',
      );
      expect(result.last.imageSourceName, contains('Example Photographer'));
      expect(result.last.imageSourceName, contains('CC BY-SA 4.0'));
      expect(result.last.imageSourceName, contains('Wikimedia Commons'));
    },
  );

  test('Wikimedia rejects approximate pages and incomplete attribution', () async {
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
                        'title': 'Different Restaurant',
                        'pageimage': 'Different.jpg',
                        'thumbnail': {
                          'source':
                              'https://upload.wikimedia.org/different.jpg',
                        },
                      },
                      {
                        'title': 'Missing Licence Cafe',
                        'pageimage': 'Missing_Licence.jpg',
                        'thumbnail': {
                          'source':
                              'https://upload.wikimedia.org/missing-licence.jpg',
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
                      'title': 'File:Missing_Licence.jpg',
                      'imageinfo': [
                        {
                          'descriptionurl':
                              'https://commons.wikimedia.org/wiki/File:Missing_Licence.jpg',
                          'extmetadata': {
                            'Artist': {'value': 'Example'},
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

    final result = await WikimediaPartnerImageSource(dio: dio).enrich([
      _partner(
        id: 'cafe',
        name: 'Small Local Cafe',
        category: EcoPartnerCategory.dining,
      ),
      _partner(
        id: 'missing-license',
        name: 'Missing Licence Cafe',
        category: EcoPartnerCategory.dining,
      ),
    ]);

    expect(result.map((partner) => partner.imageUrl), everyElement(isNull));
  });

  test(
    'composite prefers Wikimedia and uses Mapillary only for gaps',
    () async {
      final wikimedia = _CallbackImageSource(
        (partners) async => [
          for (final partner in partners)
            partner.id == 'wiki'
                ? partner.withImage(
                    url: 'https://upload.wikimedia.org/wiki.jpg',
                    imageSourceName: 'Wikimedia Commons',
                    imageSourceUrl:
                        'https://commons.wikimedia.org/wiki/File:Wiki.jpg',
                  )
                : partner,
        ],
      );
      final mapillary = _CallbackImageSource(
        (partners) async => [
          for (final partner in partners)
            partner.imageUrl == null
                ? partner.withImage(
                    url: 'https://images.mapillary.com/fallback.jpg',
                    imageSourceName: 'Mapillary',
                    imageSourceUrl: 'https://mapillary.com/fallback',
                  )
                : partner,
        ],
      );
      final source = WikimediaFirstPartnerImageSource(
        wikimedia: wikimedia,
        mapillary: mapillary,
      );

      final result = await source.enrich([
        _partner(
          id: 'wiki',
          name: 'Wiki Partner',
          category: EcoPartnerCategory.dining,
        ),
        _partner(
          id: 'fallback',
          name: 'Fallback Partner',
          category: EcoPartnerCategory.transport,
        ),
      ]);

      expect(result.first.imageUrl, contains('wikimedia'));
      expect(result.last.imageUrl, contains('mapillary'));
      expect(mapillary.lastInput?.first.imageUrl, contains('wikimedia'));
    },
  );

  test('composite still uses Mapillary when Wikimedia fails', () async {
    final source = WikimediaFirstPartnerImageSource(
      wikimedia: _CallbackImageSource((_) async => throw StateError('offline')),
      mapillary: _CallbackImageSource(
        (partners) async => [
          for (final partner in partners)
            partner.withImage(
              url: 'https://images.mapillary.com/fallback.jpg',
              imageSourceName: 'Mapillary',
              imageSourceUrl: 'https://mapillary.com/fallback',
            ),
        ],
      ),
    );

    final result = await source.enrich([
      _partner(
        id: 'fallback',
        name: 'Fallback Partner',
        category: EcoPartnerCategory.dining,
      ),
    ]);

    expect(result.single.imageUrl, contains('mapillary'));
  });
}

EcoPartner _partner({
  required String id,
  required String name,
  required EcoPartnerCategory category,
  String? imageUrl,
}) => EcoPartner(
  id: id,
  name: name,
  category: category,
  subtype: 'Test',
  latitude: 3.139,
  longitude: 101.687,
  address: 'Kuala Lumpur',
  sustainabilityLabel: 'Verified test partner',
  evidence: 'Test evidence',
  sourceName: 'Test',
  sourceUrl: 'https://example.com',
  lastUpdated: DateTime(2026),
  imageUrl: imageUrl,
);

class _CallbackImageSource implements EcoPartnerImageSource {
  _CallbackImageSource(this.callback);

  final Future<List<EcoPartner>> Function(List<EcoPartner>) callback;
  List<EcoPartner>? lastInput;

  @override
  Future<List<EcoPartner>> enrich(List<EcoPartner> partners) {
    lastInput = partners;
    return callback(partners);
  }
}
