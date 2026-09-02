import 'package:collab/features/travel_assistant/model/eco_partner_routing_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('EcoPartnerRoutingService errors', () {
    test('turns a NoRoute response into a concise message', () async {
      final service = EcoPartnerRoutingService(dio: _failingDio('NoRoute'));

      await expectLater(
        service.drivingRoute(const [
          LatLng(3.14, 101.69),
          LatLng(5.98, 116.07),
        ]),
        throwsA(
          isA<EcoPartnerRouteException>().having(
            (error) => error.message,
            'message',
            'No route is available between your location and this partner.',
          ),
        ),
      );
    });

    test('does not expose Dio internals for invalid requests', () async {
      final service = EcoPartnerRoutingService(
        dio: _failingDio('InvalidQuery'),
      );

      await expectLater(
        service.walkingRoute(const [
          LatLng(3.14, 101.69),
          LatLng(5.98, 116.07),
        ]),
        throwsA(
          isA<EcoPartnerRouteException>()
              .having(
                (error) => error.message,
                'message',
                'The route service could not process this journey.',
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('validateStatus')),
              ),
        ),
      );
    });
  });
}

Dio _failingDio(String code) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 400,
            data: {'code': code, 'message': 'Provider detail'},
          ),
          type: DioExceptionType.badResponse,
          message: 'validateStatus rejected this response',
        ),
      ),
    ),
  );
  return dio;
}
