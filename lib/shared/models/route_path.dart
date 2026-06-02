import 'geo_point.dart';

/// Planned route — can be imported from GPX or built from POIs.
class RoutePath {
  const RoutePath({
    required this.id,
    required this.title,
    required this.points,
    required this.createdAt,
    this.note = '',
    this.source = RouteSource.manual,
  });

  final String id;
  final String title;
  final List<GeoPoint> points;
  final DateTime createdAt;
  final String note;
  final RouteSource source;

  int get waypointCount => points.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'points': points.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'source': source.name,
      };

  factory RoutePath.fromJson(Map<String, dynamic> j) => RoutePath(
        id: j['id'] as String,
        title: j['title'] as String,
        points: (j['points'] as List)
            .cast<Map<String, dynamic>>()
            .map(GeoPoint.fromJson)
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        note: j['note'] as String? ?? '',
        source: RouteSource.values.firstWhere(
          (s) => s.name == j['source'],
          orElse: () => RouteSource.manual,
        ),
      );
}

enum RouteSource {
  manual,
  gpxImport,
  builtFromPoints,
}
