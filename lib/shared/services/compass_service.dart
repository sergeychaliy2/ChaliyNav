import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/geo_point.dart';

/// Emits the device's magnetic heading in degrees (0 = North, 90 = East).
/// Null while the sensor isn't yet available (or on devices without a compass).
final compassHeadingProvider = StreamProvider.autoDispose<double?>((ref) {
  final stream = FlutterCompass.events;
  if (stream == null) {
    return const Stream<double?>.empty();
  }
  return stream.map((event) => event.heading);
});

/// Computes great-circle distance and initial bearing between two points.
class Geo {
  Geo._();

  static const double earthRadiusM = 6371000.0;

  /// Haversine distance in meters.
  static double distance(GeoPoint a, GeoPoint b) {
    final dLat = _deg(b.lat - a.lat);
    final dLng = _deg(b.lng - a.lng);
    final la1 = _deg(a.lat);
    final la2 = _deg(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(la1) * math.cos(la2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h));
  }

  /// Initial bearing (forward azimuth) from [a] to [b] in degrees (0-360, 0 = N).
  static double bearing(GeoPoint a, GeoPoint b) {
    final la1 = _deg(a.lat);
    final la2 = _deg(b.lat);
    final dLng = _deg(b.lng - a.lng);
    final y = math.sin(dLng) * math.cos(la2);
    final x = math.cos(la1) * math.sin(la2) -
        math.sin(la1) * math.cos(la2) * math.cos(dLng);
    final brng = _toDeg(math.atan2(y, x));
    return (brng + 360) % 360;
  }

  /// Returns the bearing in the compass-aware frame: relative to the heading
  /// the user is pointing their device. Useful for arrow rotation.
  static double relativeBearing(double targetBearingDeg, double deviceHeadingDeg) {
    return ((targetBearingDeg - deviceHeadingDeg) + 360) % 360;
  }

  /// Compass cardinal letter for a bearing (С / СВ / В / ЮВ / Ю / ЮЗ / З / СЗ).
  static String cardinal(double bearingDeg) {
    const labels = ['С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ'];
    final idx = ((bearingDeg + 22.5) ~/ 45) % 8;
    return labels[idx];
  }

  static double _deg(double d) => d * math.pi / 180.0;
  static double _toDeg(double r) => r * 180.0 / math.pi;
}
