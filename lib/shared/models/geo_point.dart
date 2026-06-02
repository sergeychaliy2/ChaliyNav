import 'package:latlong2/latlong.dart';

/// Single recorded GPS fix — used inside tracks and as coord for POIs.
class GeoPoint {
  const GeoPoint({
    required this.lat,
    required this.lng,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.timestamp,
  });

  final double lat;
  final double lng;
  final double? altitude;
  final double? accuracy;
  final double? speed; // m/s
  final double? heading; // degrees, 0=N
  final DateTime? timestamp;

  LatLng get latLng => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (altitude != null) 'alt': altitude,
        if (accuracy != null) 'acc': accuracy,
        if (speed != null) 'spd': speed,
        if (heading != null) 'hdg': heading,
        if (timestamp != null) 'ts': timestamp!.toIso8601String(),
      };

  factory GeoPoint.fromJson(Map<String, dynamic> j) => GeoPoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        altitude: (j['alt'] as num?)?.toDouble(),
        accuracy: (j['acc'] as num?)?.toDouble(),
        speed: (j['spd'] as num?)?.toDouble(),
        heading: (j['hdg'] as num?)?.toDouble(),
        timestamp: j['ts'] == null ? null : DateTime.parse(j['ts'] as String),
      );

  GeoPoint copyWith({
    double? lat,
    double? lng,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
  }) =>
      GeoPoint(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        altitude: altitude ?? this.altitude,
        accuracy: accuracy ?? this.accuracy,
        speed: speed ?? this.speed,
        heading: heading ?? this.heading,
        timestamp: timestamp ?? this.timestamp,
      );
}
