import 'geo_point.dart';
import 'poi_category.dart';
import 'poi_icon_library.dart';

/// A saved place on the map with photos, audio memo, metadata.
class PointOfInterest {
  const PointOfInterest({
    required this.id,
    required this.title,
    required this.coord,
    required this.iconId,
    required this.createdAt,
    this.note = '',
    this.photos = const [],
    this.audioPath,
    this.favorite = false,
    this.groupId,
    this.meta = const PoiMeta(),
  });

  final String id;
  final String title;
  final GeoPoint coord;
  final String iconId;
  final DateTime createdAt;
  final String note;
  final List<String> photos;
  final String? audioPath;
  final bool favorite;
  final String? groupId;
  final PoiMeta meta;

  PoiIcon get icon => PoiIconLibrary.byId(iconId);
  PoiCategory get category => icon.category;

  PointOfInterest copyWith({
    String? title,
    GeoPoint? coord,
    String? iconId,
    String? note,
    List<String>? photos,
    String? audioPath,
    bool? favorite,
    String? groupId,
    PoiMeta? meta,
  }) =>
      PointOfInterest(
        id: id,
        title: title ?? this.title,
        coord: coord ?? this.coord,
        iconId: iconId ?? this.iconId,
        createdAt: createdAt,
        note: note ?? this.note,
        photos: photos ?? this.photos,
        audioPath: audioPath ?? this.audioPath,
        favorite: favorite ?? this.favorite,
        groupId: groupId ?? this.groupId,
        meta: meta ?? this.meta,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'coord': coord.toJson(),
        'iconId': iconId,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'photos': photos,
        if (audioPath != null) 'audioPath': audioPath,
        'favorite': favorite,
        if (groupId != null) 'groupId': groupId,
        'meta': meta.toJson(),
      };

  factory PointOfInterest.fromJson(Map<String, dynamic> j) => PointOfInterest(
        id: j['id'] as String,
        title: j['title'] as String,
        coord: GeoPoint.fromJson(j['coord'] as Map<String, dynamic>),
        iconId: j['iconId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        note: j['note'] as String? ?? '',
        photos: (j['photos'] as List?)?.cast<String>() ?? const [],
        audioPath: j['audioPath'] as String?,
        favorite: j['favorite'] as bool? ?? false,
        groupId: j['groupId'] as String?,
        meta: j['meta'] == null
            ? const PoiMeta()
            : PoiMeta.fromJson(j['meta'] as Map<String, dynamic>),
      );
}

/// Optional environmental metadata captured at POI creation.
class PoiMeta {
  const PoiMeta({
    this.altitude,
    this.pressure,
    this.weather,
    this.moonPhase,
    this.temperature,
  });

  final double? altitude;
  final double? pressure;
  final String? weather;
  final String? moonPhase;
  final double? temperature;

  Map<String, dynamic> toJson() => {
        if (altitude != null) 'altitude': altitude,
        if (pressure != null) 'pressure': pressure,
        if (weather != null) 'weather': weather,
        if (moonPhase != null) 'moonPhase': moonPhase,
        if (temperature != null) 'temperature': temperature,
      };

  factory PoiMeta.fromJson(Map<String, dynamic> j) => PoiMeta(
        altitude: (j['altitude'] as num?)?.toDouble(),
        pressure: (j['pressure'] as num?)?.toDouble(),
        weather: j['weather'] as String?,
        moonPhase: j['moonPhase'] as String?,
        temperature: (j['temperature'] as num?)?.toDouble(),
      );
}
