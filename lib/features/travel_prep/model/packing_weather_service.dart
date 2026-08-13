import 'package:dio/dio.dart';

class PackingWeatherSummary {
  const PackingWeatherSummary({
    required this.maximumTemperature,
    required this.minimumTemperature,
    required this.rainProbability,
    required this.uvIndex,
  });

  final double maximumTemperature;
  final double minimumTemperature;
  final double rainProbability;
  final double uvIndex;

  String get shortDescription {
    if (rainProbability >= 40) return '${rainProbability.round()}% rain';
    if (uvIndex >= 6) return 'High UV ${uvIndex.toStringAsFixed(1)}';
    return '${maximumTemperature.round()}°C forecast';
  }
}

class PackingWeatherService {
  PackingWeatherService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
            ),
          );

  final Dio _dio;

  Future<PackingWeatherSummary?> getForecast({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'daily':
              'temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max',
          'timezone': 'auto',
          'forecast_days': 7,
        },
      );
      final daily = response.data?['daily'];
      if (daily is! Map) return null;
      final maxima = _numbers(daily['temperature_2m_max']);
      final minima = _numbers(daily['temperature_2m_min']);
      final rain = _numbers(daily['precipitation_probability_max']);
      final uv = _numbers(daily['uv_index_max']);
      if (maxima.isEmpty || minima.isEmpty) return null;
      return PackingWeatherSummary(
        maximumTemperature: maxima.reduce((a, b) => a > b ? a : b),
        minimumTemperature: minima.reduce((a, b) => a < b ? a : b),
        rainProbability: rain.isEmpty
            ? 0
            : rain.reduce((a, b) => a > b ? a : b),
        uvIndex: uv.isEmpty ? 0 : uv.reduce((a, b) => a > b ? a : b),
      );
    } catch (_) {
      return null;
    }
  }

  static List<double> _numbers(dynamic values) => values is List
      ? values.whereType<num>().map((value) => value.toDouble()).toList()
      : const [];
}
