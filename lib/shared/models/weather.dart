import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';

/// Simulated weather conditions. Fully internal to the app — there is NO
/// network/API behind this (by design: "чисто внутри игры").
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  rain,
  thunderstorm,
  snow,
  fog,
}

extension WeatherConditionX on WeatherCondition {
  String get label => switch (this) {
        WeatherCondition.clear => 'Ясно',
        WeatherCondition.partlyCloudy => 'Перем. облачность',
        WeatherCondition.cloudy => 'Облачно',
        WeatherCondition.rain => 'Дождь',
        WeatherCondition.thunderstorm => 'Гроза',
        WeatherCondition.snow => 'Снег',
        WeatherCondition.fog => 'Туман',
      };

  IconData get icon => switch (this) {
        WeatherCondition.clear => PhosphorIconsDuotone.sun,
        WeatherCondition.partlyCloudy => PhosphorIconsDuotone.cloudSun,
        WeatherCondition.cloudy => PhosphorIconsDuotone.cloud,
        WeatherCondition.rain => PhosphorIconsDuotone.cloudRain,
        WeatherCondition.thunderstorm => PhosphorIconsDuotone.cloudLightning,
        WeatherCondition.snow => PhosphorIconsDuotone.cloudSnow,
        WeatherCondition.fog => PhosphorIconsDuotone.cloudFog,
      };

  /// Accent color for highlighting (region cards, map badges).
  Color get color => switch (this) {
        WeatherCondition.clear => AppColors.accentAmber,
        WeatherCondition.partlyCloudy => AppColors.accentCyan,
        WeatherCondition.cloudy => AppColors.textSecondary,
        WeatherCondition.rain => AppColors.info,
        WeatherCondition.thunderstorm => AppColors.accentViolet,
        WeatherCondition.snow => AppColors.accentCyan,
        WeatherCondition.fog => AppColors.textTertiary,
      };
}

/// A weather sample for a place: condition + temperature + wind.
@immutable
class RegionWeather {
  const RegionWeather({
    required this.condition,
    required this.tempC,
    required this.windKph,
  });

  final WeatherCondition condition;
  final double tempC;
  final double windKph;

  String get tempLabel => '${tempC.round()}°';
  String get summary =>
      '${condition.label} · $tempLabel · ${windKph.round()} км/ч';
}

/// Deterministic, no-network "weather" generator.
///
/// Same (place, time) always yields the same result — so the map never
/// flickers between rebuilds — yet it varies believably by latitude
/// (warmer south, colder north), season (cold January, warm July),
/// continentality (bigger swings inland/east), and the daily cycle, and it
/// "updates" a few times a day. Purely arithmetic; no `Random`, no I/O.
class WeatherSim {
  WeatherSim._();

  static RegionWeather at(double lat, double lng, [DateTime? when]) {
    final now = when ?? DateTime.now();
    final doy = now.difference(DateTime(now.year)).inDays;
    final absLat = lat.abs();

    // Annual mean temperature: ~14 °C around 43°N, dropping north.
    final annualMean = 14.0 - (absLat - 43) * 0.9;
    // Seasonal swing — larger inland (east) and further north.
    final amplitude =
        (10.0 + (absLat - 43) * 0.5 + (lng - 40).abs() * 0.05).clamp(8.0, 26.0);
    // Warmest ~mid-July (doy 196), coldest ~mid-January.
    final seasonal = amplitude * math.cos((doy - 196) / 365.25 * 2 * math.pi);
    // Daily cycle — warmest ~15:00, coldest ~05:00.
    final hourFrac = now.hour + now.minute / 60.0;
    final daily = -4.5 * math.cos((hourFrac - 15) / 24 * 2 * math.pi);
    // Deterministic per-place daily wobble, ±5 °C.
    final noise = (_rand(_seed(lat, lng, doy)) - 0.5) * 10;

    final temp = (annualMean + seasonal + daily + noise).clamp(-50.0, 42.0);

    // Condition — changes every 3 h so the picture evolves through the day.
    final bucket = now.hour ~/ 3;
    final r = _rand(_seed(lat * 1.7, lng * 1.3 + 11, doy * 7 + bucket));
    final cold = temp < 1.0;
    final WeatherCondition cond;
    if (r < 0.34) {
      cond = WeatherCondition.clear;
    } else if (r < 0.55) {
      cond = WeatherCondition.partlyCloudy;
    } else if (r < 0.72) {
      cond = WeatherCondition.cloudy;
    } else if (r < 0.87) {
      cond = cold ? WeatherCondition.snow : WeatherCondition.rain;
    } else if (r < 0.94) {
      cond = cold ? WeatherCondition.snow : WeatherCondition.thunderstorm;
    } else {
      cond = WeatherCondition.fog;
    }

    final wind = 3 + _rand(_seed(lng, lat, bucket + 3)) * 27;
    return RegionWeather(condition: cond, tempC: temp, windKph: wind);
  }

  static int _seed(double lat, double lng, int t) {
    // Quantize to ~0.1° so tiny float differences don't change the result.
    final la = (lat * 10).round();
    final lo = (lng * 10).round();
    return ((la * 73856093) ^ (lo * 19349663) ^ (t * 83492791)) & 0x7fffffff;
  }

  /// Stable pseudo-random in [0, 1) from an integer seed (xorshift scramble).
  static double _rand(int seed) {
    var h = seed & 0x7fffffff;
    h ^= h << 13;
    h &= 0x7fffffff;
    h ^= h >> 17;
    h ^= h << 5;
    h &= 0x7fffffff;
    return h / 0x7fffffff;
  }
}
