import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _date = DateFormat('dd.MM.yyyy');
  static final _dateTime = DateFormat('dd.MM.yyyy HH:mm');
  static final _time = DateFormat('HH:mm:ss');

  static String date(DateTime dt) => _date.format(dt);
  static String dateTime(DateTime dt) => _dateTime.format(dt);
  static String time(DateTime dt) => _time.format(dt);

  /// "12.4 км" / "340 м"
  static String distance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} м';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 2 : 1)} км';
  }

  /// "12.4 км/ч"
  static String speed(double mps) {
    final kmh = mps * 3.6;
    return '${kmh.toStringAsFixed(1)} км/ч';
  }

  /// "2 ч 14 м" / "14 м 22 с"
  static String duration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours} ч ${d.inMinutes.remainder(60)} м';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes} м ${d.inSeconds.remainder(60)} с';
    }
    return '${d.inSeconds} с';
  }

  /// "55.755800, 37.617300"
  static String latLng(double lat, double lng) =>
      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  /// "340 м н.у.м."
  static String altitude(double? m) =>
      m == null ? '—' : '${m.toStringAsFixed(0)} м н.у.м.';

  /// "±5 м"
  static String accuracy(double? m) =>
      m == null ? '—' : '±${m.toStringAsFixed(0)} м';
}
