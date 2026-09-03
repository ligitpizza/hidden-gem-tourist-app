import 'package:collab/features/travel_assistant/model/packing_checklist.dart';
import 'package:collab/features/travel_assistant/model/packing_weather_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 3);

  test('aggregates only the requested trip days', () async {
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          final daily = '${options.queryParameters['daily']}';
          if (daily == 'uv_index_max') {
            expect(options.queryParameters['forecast_days'], 7);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'daily': {
                    'time': [
                      '2026-09-03',
                      '2026-09-04',
                      '2026-09-05',
                      '2026-09-06',
                      '2026-09-07',
                    ],
                    'uv_index_max': [3, 4, 7, 9, 10],
                  },
                },
              ),
            );
            return;
          }
          expect(
            daily,
            'temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max',
          );
          expect(options.queryParameters['forecast_days'], 16);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'daily': {
                  'time': [
                    '2026-09-03',
                    '2026-09-04',
                    '2026-09-05',
                    '2026-09-06',
                    '2026-09-07',
                  ],
                  'temperature_2m_max': [29, 30, 31, 34, 35],
                  'temperature_2m_min': [25, 24, 22, 23, 21],
                  'precipitation_probability_max': [10, 20, 45, 80, 90],
                },
              },
            ),
          );
        },
      ),
    );

    final result = await PackingWeatherService(dio: dio, now: () => today)
        .getForecast(
          latitude: 3.139,
          longitude: 101.687,
          dates: PackingTripDateRange(
            start: DateTime(2026, 9, 5),
            end: DateTime(2026, 9, 6),
          ),
        );

    expect(result.status, PackingForecastStatus.available);
    expect(result.coverageStart, DateTime(2026, 9, 5));
    expect(result.coverageEnd, DateTime(2026, 9, 6));
    expect(result.summary?.maximumTemperature, 34);
    expect(result.summary?.minimumTemperature, 22);
    expect(result.summary?.rainProbability, 80);
    expect(result.summary?.uvIndex, 9);
    expect(requests, 2);
  });

  test('keeps the core forecast when the shorter UV request fails', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.queryParameters['daily'] == 'uv_index_max') {
            handler.reject(
              DioException(requestOptions: options, message: 'UV unavailable'),
            );
            return;
          }
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'daily': {
                  'time': ['2026-09-05'],
                  'temperature_2m_max': [32],
                  'temperature_2m_min': [24],
                  'precipitation_probability_max': [60],
                },
              },
            ),
          );
        },
      ),
    );

    final result = await PackingWeatherService(dio: dio, now: () => today)
        .getForecast(
          latitude: 3.139,
          longitude: 101.687,
          dates: PackingTripDateRange(
            start: DateTime(2026, 9, 5),
            end: DateTime(2026, 9, 5),
          ),
        );

    expect(result.status, PackingForecastStatus.available);
    expect(result.summary?.maximumTemperature, 32);
    expect(result.summary?.rainProbability, 60);
    expect(result.summary?.uvIndex, isNull);
  });

  test(
    'labels a hotel range with only some forecast days as partial',
    () async {
      final dio = _respondingDio(
        dates: List.generate(
          9,
          (index) => '2026-09-${(10 + index).toString().padLeft(2, '0')}',
        ),
      );

      final result = await PackingWeatherService(dio: dio, now: () => today)
          .getForecast(
            latitude: 3.139,
            longitude: 101.687,
            dates: PackingTripDateRange(
              start: DateTime(2026, 9, 10),
              end: DateTime(2026, 9, 25),
            ),
          );

      expect(result.status, PackingForecastStatus.partial);
      expect(result.coverageStart, DateTime(2026, 9, 10));
      expect(result.coverageEnd, DateTime(2026, 9, 18));
    },
  );

  test('does not turn unavailable rain and UV variables into zero', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'daily': {
                'time': ['2026-09-05'],
                'temperature_2m_max': [30],
                'temperature_2m_min': [24],
                'precipitation_probability_max': [null],
              },
            },
          ),
        ),
      ),
    );

    final result = await PackingWeatherService(dio: dio, now: () => today)
        .getForecast(
          latitude: 3.139,
          longitude: 101.687,
          dates: PackingTripDateRange(
            start: DateTime(2026, 9, 5),
            end: DateTime(2026, 9, 5),
          ),
        );

    expect(result.status, PackingForecastStatus.available);
    expect(result.summary?.rainProbability, isNull);
    expect(result.summary?.uvIndex, isNull);
  });

  test('future and expired trips do not make an API request', () async {
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.reject(
            DioException(requestOptions: options, message: 'Unexpected call'),
          );
        },
      ),
    );
    final service = PackingWeatherService(dio: dio, now: () => today);

    final future = await service.getForecast(
      latitude: 3.139,
      longitude: 101.687,
      dates: PackingTripDateRange(
        start: DateTime(2026, 10, 20),
        end: DateTime(2026, 10, 22),
      ),
    );
    final expired = await service.getForecast(
      latitude: 3.139,
      longitude: 101.687,
      dates: PackingTripDateRange(
        start: DateTime(2026, 8, 20),
        end: DateTime(2026, 8, 22),
      ),
    );

    expect(future.status, PackingForecastStatus.notYetAvailable);
    expect(future.availableFrom, DateTime(2026, 10, 5));
    expect(expired.status, PackingForecastStatus.expired);
    expect(requests, 0);
  });

  test(
    'malformed and failed responses have a retryable failed state',
    () async {
      final malformed = Dio();
      malformed.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'daily': <String, dynamic>{}},
            ),
          ),
        ),
      );
      final failing = Dio();
      failing.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(requestOptions: options, message: 'Offline'),
          ),
        ),
      );
      final dates = PackingTripDateRange(
        start: DateTime(2026, 9, 5),
        end: DateTime(2026, 9, 5),
      );

      final malformedResult = await PackingWeatherService(
        dio: malformed,
        now: () => today,
      ).getForecast(latitude: 3, longitude: 101, dates: dates);
      final failedResult = await PackingWeatherService(
        dio: failing,
        now: () => today,
      ).getForecast(latitude: 3, longitude: 101, dates: dates);

      expect(malformedResult.status, PackingForecastStatus.failed);
      expect(failedResult.status, PackingForecastStatus.failed);
    },
  );
}

Dio _respondingDio({required List<String> dates}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'daily': {
              'time': dates,
              'temperature_2m_max': List.filled(dates.length, 32),
              'temperature_2m_min': List.filled(dates.length, 24),
              'precipitation_probability_max': List.filled(dates.length, 50),
              'uv_index_max': List.filled(dates.length, 7),
            },
          },
        ),
      ),
    ),
  );
  return dio;
}
