import 'package:dio/dio.dart';

import 'packing_checklist.dart';

enum PackingForecastStatus {
  needsDates,
  loading,
  available,
  partial,
  notYetAvailable,
  expired,
  failed,
}

enum PackingWeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown;

  static PackingWeatherCondition fromWmoCode(int code) => switch (code) {
    0 || 1 => PackingWeatherCondition.clear,
    2 => PackingWeatherCondition.partlyCloudy,
    3 => PackingWeatherCondition.cloudy,
    45 || 48 => PackingWeatherCondition.fog,
    51 || 53 || 55 || 56 || 57 => PackingWeatherCondition.drizzle,
    61 ||
    63 ||
    65 ||
    66 ||
    67 ||
    80 ||
    81 ||
    82 => PackingWeatherCondition.rain,
    71 || 73 || 75 || 77 || 85 || 86 => PackingWeatherCondition.snow,
    95 || 96 || 99 => PackingWeatherCondition.thunderstorm,
    _ => PackingWeatherCondition.unknown,
  };

  String? get label => switch (this) {
    PackingWeatherCondition.clear => 'Clear',
    PackingWeatherCondition.partlyCloudy => 'Partly cloudy',
    PackingWeatherCondition.cloudy => 'Cloudy',
    PackingWeatherCondition.fog => 'Foggy',
    PackingWeatherCondition.drizzle => 'Drizzle',
    PackingWeatherCondition.rain => 'Rain',
    PackingWeatherCondition.snow => 'Snow',
    PackingWeatherCondition.thunderstorm => 'Thunderstorms',
    PackingWeatherCondition.unknown => null,
  };
}

class PackingWeatherSummary {
  const PackingWeatherSummary({
    required this.maximumTemperature,
    required this.minimumTemperature,
    this.condition,
    this.rainProbability,
    this.uvIndex,
  });

  final double maximumTemperature;
  final double minimumTemperature;
  final PackingWeatherCondition? condition;
  final double? rainProbability;
  final double? uvIndex;

  String get shortDescription {
    final minimum = minimumTemperature.round();
    final maximum = maximumTemperature.round();
    final parts = <String>[];
    final conditionLabel = condition?.label;
    if (conditionLabel != null) parts.add(conditionLabel);
    parts.add(minimum == maximum ? '$maximum°C' : '$minimum–$maximum°C');
    if (rainProbability case final rain?) {
      parts.add('Rain up to ${rain.round()}%');
    }
    if (uvIndex case final uv?) parts.add('UV ${uv.toStringAsFixed(1)}');
    return parts.join(' · ');
  }
}

class PackingForecastResult {
  const PackingForecastResult({
    required this.status,
    this.summary,
    this.coverageStart,
    this.coverageEnd,
    this.availableFrom,
  });

  const PackingForecastResult.needsDates()
    : this(status: PackingForecastStatus.needsDates);

  const PackingForecastResult.loading()
    : this(status: PackingForecastStatus.loading);

  const PackingForecastResult.failed()
    : this(status: PackingForecastStatus.failed);

  final PackingForecastStatus status;
  final PackingWeatherSummary? summary;
  final DateTime? coverageStart;
  final DateTime? coverageEnd;
  final DateTime? availableFrom;

  bool get hasForecast =>
      status == PackingForecastStatus.available ||
      status == PackingForecastStatus.partial;
}

class PackingWeatherService {
  PackingWeatherService({Dio? dio, DateTime Function()? now})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          ),
      _now = now ?? DateTime.now;

  static const forecastDays = 16;
  static const uvForecastDays = 7;

  final Dio _dio;
  final DateTime Function() _now;

  Future<PackingForecastResult> getForecast({
    required double latitude,
    required double longitude,
    required PackingTripDateRange dates,
  }) async {
    final today = _dateOnly(_now());
    if (dates.end.isBefore(today)) {
      return const PackingForecastResult(status: PackingForecastStatus.expired);
    }

    final horizonEnd = today.add(const Duration(days: forecastDays - 1));
    if (dates.start.isAfter(horizonEnd)) {
      return PackingForecastResult(
        status: PackingForecastStatus.notYetAvailable,
        availableFrom: dates.start.subtract(
          const Duration(days: PackingWeatherService.forecastDays - 1),
        ),
      );
    }

    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return const PackingForecastResult.failed();
    }

    try {
      final responses = await Future.wait<Object?>([
        _dio.get<Map<String, dynamic>>(
          'https://api.open-meteo.com/v1/forecast',
          queryParameters: {
            'latitude': latitude,
            'longitude': longitude,
            'daily':
                'temperature_2m_max,temperature_2m_min,'
                'precipitation_probability_max,weather_code',
            'timezone': 'auto',
            'forecast_days': forecastDays,
          },
        ),
        _loadUvByDate(latitude: latitude, longitude: longitude),
      ]);
      final response = responses[0] as Response<Map<String, dynamic>>;
      final uvByDate = responses[1] as Map<DateTime, double>;
      final daily = response.data?['daily'];
      if (daily is! Map) return const PackingForecastResult.failed();

      final times = daily['time'];
      if (times is! List) return const PackingForecastResult.failed();

      final coveredDates = <DateTime>[];
      final maxima = <double>[];
      final minima = <double>[];
      final rain = <double>[];
      final uv = <double>[];
      final conditions = <PackingWeatherCondition>[];

      for (var index = 0; index < times.length; index++) {
        final parsed = DateTime.tryParse('${times[index]}');
        if (parsed == null) continue;
        final day = _dateOnly(parsed);
        if (day.isBefore(today) ||
            day.isBefore(dates.start) ||
            day.isAfter(dates.end)) {
          continue;
        }

        final maximum = _numberAt(daily['temperature_2m_max'], index);
        final minimum = _numberAt(daily['temperature_2m_min'], index);
        if (maximum == null || minimum == null) continue;

        coveredDates.add(day);
        maxima.add(maximum);
        minima.add(minimum);
        final rainValue = _numberAt(
          daily['precipitation_probability_max'],
          index,
        );
        final uvValue = uvByDate[day];
        final weatherCode = _numberAt(daily['weather_code'], index)?.round();
        if (rainValue != null) rain.add(rainValue);
        if (uvValue != null) uv.add(uvValue);
        if (weatherCode != null) {
          conditions.add(PackingWeatherCondition.fromWmoCode(weatherCode));
        }
      }

      if (coveredDates.isEmpty) {
        return const PackingForecastResult.failed();
      }

      coveredDates.sort();
      final coverageStart = coveredDates.first;
      final coverageEnd = coveredDates.last;
      final requestedDayCount = dates.end.difference(dates.start).inDays + 1;
      final isComplete =
          coverageStart == dates.start &&
          coverageEnd == dates.end &&
          coveredDates.length == requestedDayCount;

      return PackingForecastResult(
        status: isComplete
            ? PackingForecastStatus.available
            : PackingForecastStatus.partial,
        summary: PackingWeatherSummary(
          maximumTemperature: _maximum(maxima),
          minimumTemperature: _minimum(minima),
          condition: _representativeCondition(conditions),
          rainProbability: rain.isEmpty ? null : _maximum(rain),
          uvIndex: uv.isEmpty ? null : _maximum(uv),
        ),
        coverageStart: coverageStart,
        coverageEnd: coverageEnd,
      );
    } catch (_) {
      return const PackingForecastResult.failed();
    }
  }

  Future<Map<DateTime, double>> _loadUvByDate({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'daily': 'uv_index_max',
          'timezone': 'auto',
          'forecast_days': uvForecastDays,
        },
      );
      final daily = response.data?['daily'];
      if (daily is! Map) return const <DateTime, double>{};
      final times = daily['time'];
      if (times is! List) return const <DateTime, double>{};
      final values = <DateTime, double>{};
      for (var index = 0; index < times.length; index++) {
        final date = DateTime.tryParse('${times[index]}');
        final uv = _numberAt(daily['uv_index_max'], index);
        if (date != null && uv != null) values[_dateOnly(date)] = uv;
      }
      return values;
    } catch (_) {
      // Temperature and rain still produce a useful forecast when the
      // shorter-horizon UV feed is temporarily unavailable.
      return const <DateTime, double>{};
    }
  }

  static double? _numberAt(dynamic values, int index) {
    if (values is! List || index >= values.length) return null;
    final value = values[index];
    return value is num ? value.toDouble() : null;
  }

  static double _maximum(List<double> values) =>
      values.reduce((a, b) => a > b ? a : b);

  static double _minimum(List<double> values) =>
      values.reduce((a, b) => a < b ? a : b);

  static PackingWeatherCondition? _representativeCondition(
    List<PackingWeatherCondition> conditions,
  ) {
    final known = conditions
        .where((condition) => condition != PackingWeatherCondition.unknown)
        .toList();
    if (known.isEmpty) {
      return conditions.isEmpty ? null : PackingWeatherCondition.unknown;
    }

    final counts = <PackingWeatherCondition, int>{};
    for (final condition in known) {
      counts.update(condition, (count) => count + 1, ifAbsent: () => 1);
    }

    var selected = known.first;
    var selectedCount = counts[selected]!;
    for (final condition in known.skip(1)) {
      final count = counts[condition]!;
      if (count > selectedCount) {
        selected = condition;
        selectedCount = count;
      }
    }
    return selected;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
