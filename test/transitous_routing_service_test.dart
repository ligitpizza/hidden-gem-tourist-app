import 'package:collab/features/itinerary_planning/model/transitous_routing_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const from = LatLng(5.64, 100.49);
  const to = LatLng(5.66, 100.51);

  test(
    'reports missing live coverage without denying the listed route',
    () async {
      final service = TransitousRoutingService(
        dio: _respondingDio({'itineraries': <dynamic>[]}),
      );

      await expectLater(
        service.planOrThrow(from, to),
        throwsA(
          isA<TransitRouteException>()
              .having(
                (error) => error.failure,
                'failure',
                TransitRouteFailure.noCoverage,
              )
              .having(
                (error) => error.message,
                'message',
                contains('listed route may still serve this stop'),
              ),
        ),
      );
    },
  );

  test('reports connectivity separately from missing coverage', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
    );
    final service = TransitousRoutingService(dio: dio);

    await expectLater(
      service.planOrThrow(from, to),
      throwsA(
        isA<TransitRouteException>()
            .having(
              (error) => error.failure,
              'failure',
              TransitRouteFailure.connection,
            )
            .having(
              (error) => error.message,
              'message',
              contains('Could not reach the in-app transit planner'),
            ),
      ),
    );
    expect(await service.plan(from, to), isNull);
  });

  test('selects an itinerary that uses the requested route', () async {
    final service = TransitousRoutingService(
      dio: _respondingDio({
        'itineraries': [
          _itinerary('T10', duration: 1200),
          _itinerary('K52', duration: 1800),
        ],
      }),
    );

    final route = await service.planOrThrow(
      from,
      to,
      preferredRouteNames: const ['K52', 'Sungai Petani - Pantai Merdeka'],
      preferredRouteLabel: 'Sungai Petani - Pantai Merdeka (K52)',
    );

    expect(route.durationMinutes, 30);
    expect(route.legs.single.routeName, 'K52');
  });

  test('rejects live itineraries that do not use the selected route', () async {
    final service = TransitousRoutingService(
      dio: _respondingDio({
        'itineraries': [_itinerary('T10', duration: 1200)],
      }),
    );

    await expectLater(
      service.planOrThrow(
        from,
        to,
        preferredRouteNames: const ['K52'],
        preferredRouteLabel: 'K52',
      ),
      throwsA(
        isA<TransitRouteException>()
            .having(
              (error) => error.failure,
              'failure',
              TransitRouteFailure.noCoverage,
            )
            .having((error) => error.message, 'message', contains('using K52')),
      ),
    );
  });
}

Map<String, dynamic> _itinerary(String routeName, {required int duration}) => {
  'duration': duration,
  'transfers': 0,
  'legs': [
    {
      'mode': 'BUS',
      'from': {'name': 'Origin stop', 'lat': 5.64, 'lon': 100.49},
      'to': {'name': 'Destination stop', 'lat': 5.66, 'lon': 100.51},
      'duration': duration,
      'distance': 2500,
      'routeShortName': routeName,
    },
  ],
};

Dio _respondingDio(Map<String, dynamic> data) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: data,
        ),
      ),
    ),
  );
  return dio;
}
