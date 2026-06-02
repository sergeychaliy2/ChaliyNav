import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';

/// Named polygon / polyline saved by the user from the measurement tool.
/// Examples: лесной квартал, охотничье угодье, аквазона, поле для грибов.
class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.kind,
    required this.vertices,
    required this.createdAt,
    required this.colorValue,
    this.note = '',
    this.areaM2 = 0,
    this.perimeterM = 0,
    this.distanceM = 0,
  });

  final String id;
  final String name;
  final ZoneKind kind;

  /// For [ZoneKind.area] — polygon vertices (closed implicitly by renderer).
  /// For [ZoneKind.line] — polyline vertices.
  final List<ZoneVertex> vertices;
  final DateTime createdAt;
  final int colorValue;
  final String note;
  final double areaM2;
  final double perimeterM;
  final double distanceM;

  Color get color => Color(colorValue);
  List<LatLng> get latLngs =>
      vertices.map((v) => LatLng(v.lat, v.lng)).toList();

  Zone copyWith({
    String? name,
    String? note,
    int? colorValue,
  }) =>
      Zone(
        id: id,
        name: name ?? this.name,
        kind: kind,
        vertices: vertices,
        createdAt: createdAt,
        colorValue: colorValue ?? this.colorValue,
        note: note ?? this.note,
        areaM2: areaM2,
        perimeterM: perimeterM,
        distanceM: distanceM,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'vertices': vertices.map((v) => v.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'colorValue': colorValue,
        'note': note,
        'areaM2': areaM2,
        'perimeterM': perimeterM,
        'distanceM': distanceM,
      };

  factory Zone.fromJson(Map<String, dynamic> j) => Zone(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: ZoneKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => ZoneKind.area,
        ),
        vertices: (j['vertices'] as List)
            .cast<Map<String, dynamic>>()
            .map(ZoneVertex.fromJson)
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        colorValue: (j['colorValue'] as num?)?.toInt() ??
            AppColors.accentAmber.toARGB32(),
        note: j['note'] as String? ?? '',
        areaM2: (j['areaM2'] as num?)?.toDouble() ?? 0,
        perimeterM: (j['perimeterM'] as num?)?.toDouble() ?? 0,
        distanceM: (j['distanceM'] as num?)?.toDouble() ?? 0,
      );
}

class ZoneVertex {
  const ZoneVertex({required this.lat, required this.lng});

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory ZoneVertex.fromJson(Map<String, dynamic> j) => ZoneVertex(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

enum ZoneKind {
  area, // polygon — лесной квартал, охотничье угодье, aqua-зона
  line, // polyline — маршрут обхода, граница, промер
}

extension ZoneKindX on ZoneKind {
  String get label => switch (this) {
        ZoneKind.area => 'Угодье',
        ZoneKind.line => 'Линия',
      };

  String get iconLabel => switch (this) {
        ZoneKind.area => 'Площадь',
        ZoneKind.line => 'Расстояние',
      };
}

/// Presets for common zone purposes.
enum ZonePurpose {
  hunting, // охотничье угодье
  forestry, // лесной квартал
  aqua, // аквазона рыбалки
  berry, // грибное место / ягодник
  danger, // запретная зона
  custom;

  String get label => switch (this) {
        ZonePurpose.hunting => 'Охотничье угодье',
        ZonePurpose.forestry => 'Лесной квартал',
        ZonePurpose.aqua => 'Аквазона',
        ZonePurpose.berry => 'Грибное место',
        ZonePurpose.danger => 'Запретная зона',
        ZonePurpose.custom => 'Моя зона',
      };

  Color get color => switch (this) {
        ZonePurpose.hunting => const Color(0xFFEF4444),
        ZonePurpose.forestry => const Color(0xFF22C55E),
        ZonePurpose.aqua => const Color(0xFF22D3EE),
        ZonePurpose.berry => const Color(0xFFF97316),
        ZonePurpose.danger => const Color(0xFFDC2626),
        ZonePurpose.custom => const Color(0xFFFBBF24),
      };
}
