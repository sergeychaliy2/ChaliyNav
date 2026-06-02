import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'geo_point.dart';

/// Recorded movement — a sequence of GPS fixes with aggregate stats.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.points,
    required this.startedAt,
    required this.finishedAt,
    required this.colorValue,
    this.distanceM = 0,
    this.avgSpeedMps = 0,
    this.maxSpeedMps = 0,
    this.ascentM = 0,
    this.descentM = 0,
    this.note = '',
  });

  final String id;
  final String title;
  final List<GeoPoint> points;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int colorValue;
  final double distanceM;
  final double avgSpeedMps;
  final double maxSpeedMps;
  final double ascentM;
  final double descentM;
  final String note;

  Color get color => Color(colorValue);
  Duration get duration => finishedAt.difference(startedAt);
  int get pointCount => points.length;
  bool get isEmpty => points.isEmpty;

  Track copyWith({
    String? title,
    List<GeoPoint>? points,
    DateTime? finishedAt,
    int? colorValue,
    double? distanceM,
    double? avgSpeedMps,
    double? maxSpeedMps,
    double? ascentM,
    double? descentM,
    String? note,
  }) =>
      Track(
        id: id,
        title: title ?? this.title,
        points: points ?? this.points,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        colorValue: colorValue ?? this.colorValue,
        distanceM: distanceM ?? this.distanceM,
        avgSpeedMps: avgSpeedMps ?? this.avgSpeedMps,
        maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
        ascentM: ascentM ?? this.ascentM,
        descentM: descentM ?? this.descentM,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'points': points.map((p) => p.toJson()).toList(),
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt.toIso8601String(),
        'colorValue': colorValue,
        'distanceM': distanceM,
        'avgSpeedMps': avgSpeedMps,
        'maxSpeedMps': maxSpeedMps,
        'ascentM': ascentM,
        'descentM': descentM,
        'note': note,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: j['title'] as String,
        points: (j['points'] as List)
            .cast<Map<String, dynamic>>()
            .map(GeoPoint.fromJson)
            .toList(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        finishedAt: DateTime.parse(j['finishedAt'] as String),
        colorValue: j['colorValue'] as int? ?? AppColors.trackColors.first.toARGB32(),
        distanceM: (j['distanceM'] as num?)?.toDouble() ?? 0,
        avgSpeedMps: (j['avgSpeedMps'] as num?)?.toDouble() ?? 0,
        maxSpeedMps: (j['maxSpeedMps'] as num?)?.toDouble() ?? 0,
        ascentM: (j['ascentM'] as num?)?.toDouble() ?? 0,
        descentM: (j['descentM'] as num?)?.toDouble() ?? 0,
        note: j['note'] as String? ?? '',
      );
}
