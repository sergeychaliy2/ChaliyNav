import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../models/geo_point.dart';
import '../models/poi_category.dart';
import '../models/poi_icon_library.dart';
import '../models/point_of_interest.dart';
import '../models/route_path.dart';
import '../models/track.dart';
import 'gpx_service.dart';

/// Parse GeoJSON FeatureCollection from a file — typical QGIS export.
///
/// Supports geometry types:
///   - Point              → POI
///   - LineString         → RoutePath (no timestamps) OR Track if `when` attr
///   - Polygon / MultiPolygon → flattened into RoutePaths (outer ring)
///   - MultiPoint/MultiLineString — flattened
class GeoJsonService {
  GeoJsonService._();

  static Future<GpxImportResult> parseFile(File file) async {
    final raw = await file.readAsString();
    return parse(raw);
  }

  static GpxImportResult parse(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! Map || data['type'] != 'FeatureCollection') {
      throw const FormatException(
        'Ожидается GeoJSON FeatureCollection (QGIS: Layer → Export → GeoJSON)',
      );
    }

    final features = (data['features'] as List?) ?? const [];
    final tracks = <Track>[];
    final points = <PointOfInterest>[];
    final routes = <RoutePath>[];

    for (final raw in features) {
      if (raw is! Map) continue;
      final geom = raw['geometry'];
      if (geom is! Map) continue;
      final type = geom['type'] as String?;
      final coords = geom['coordinates'];
      final props = (raw['properties'] as Map?)?.cast<String, dynamic>() ??
          const {};
      final name = _pickName(props);
      final desc = (props['description'] ?? props['desc'] ?? '').toString();

      switch (type) {
        case 'Point':
          final c = _toCoord(coords);
          if (c == null) break;
          points.add(_toPoi(name, desc, c));
          break;

        case 'MultiPoint':
          if (coords is! List) break;
          for (final c in coords) {
            final g = _toCoord(c);
            if (g != null) points.add(_toPoi(name, desc, g));
          }
          break;

        case 'LineString':
          final line = _toLine(coords);
          if (line.length >= 2) {
            routes.add(_toRoute(name, desc, line));
          }
          break;

        case 'MultiLineString':
          if (coords is! List) break;
          for (final line in coords) {
            final l = _toLine(line);
            if (l.length >= 2) routes.add(_toRoute(name, desc, l));
          }
          break;

        case 'Polygon':
          if (coords is! List || coords.isEmpty) break;
          final outer = _toLine(coords.first);
          if (outer.length >= 3) {
            routes.add(_toRoute(name, desc, outer));
          }
          break;

        case 'MultiPolygon':
          if (coords is! List) break;
          for (final poly in coords) {
            if (poly is! List || poly.isEmpty) continue;
            final outer = _toLine(poly.first);
            if (outer.length >= 3) {
              routes.add(_toRoute(name, desc, outer));
            }
          }
          break;

        default:
          break;
      }
    }

    return GpxImportResult(tracks: tracks, points: points, routes: routes);
  }

  static String _pickName(Map<String, dynamic> props) {
    for (final key in const ['name', 'Name', 'NAME', 'title', 'label']) {
      final v = props[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return 'GeoJSON';
  }

  static LatLng? _toLatLng(dynamic c) {
    if (c is! List || c.length < 2) return null;
    final lon = (c[0] as num?)?.toDouble();
    final lat = (c[1] as num?)?.toDouble();
    if (lon == null || lat == null) return null;
    return LatLng(lat, lon);
  }

  static GeoPoint? _toCoord(dynamic c) {
    final ll = _toLatLng(c);
    if (ll == null) return null;
    double? alt;
    if (c is List && c.length >= 3 && c[2] is num) {
      alt = (c[2] as num).toDouble();
    }
    return GeoPoint(lat: ll.latitude, lng: ll.longitude, altitude: alt);
  }

  static List<GeoPoint> _toLine(dynamic coords) {
    if (coords is! List) return const [];
    final out = <GeoPoint>[];
    for (final c in coords) {
      final g = _toCoord(c);
      if (g != null) out.add(g);
    }
    return out;
  }

  static PointOfInterest _toPoi(String name, String desc, GeoPoint c) {
    return PointOfInterest(
      id: const Uuid().v4(),
      title: name,
      coord: c,
      iconId: PoiIconLibrary.defaultFor(PoiCategory.other).id,
      createdAt: DateTime.now(),
      note: desc,
    );
  }

  static RoutePath _toRoute(String name, String desc, List<GeoPoint> line) {
    return RoutePath(
      id: const Uuid().v4(),
      title: name,
      points: line,
      createdAt: DateTime.now(),
      note: desc,
      source: RouteSource.gpxImport,
    );
  }
}

/// Helper — if the GeoJSON turned out to be more "track-like" (many dense
/// points along a path), convert a RoutePath back into a Track. Used for
/// heuristic import UI decisions down the line.
Track trackFromRoute(RoutePath r) {
  final dist = _lineLength(r.points);
  final now = DateTime.now();
  final colorIdx = r.id.hashCode % AppColors.trackColors.length;
  return Track(
    id: r.id,
    title: r.title,
    points: r.points,
    startedAt: now,
    finishedAt: now,
    colorValue: AppColors.trackColors[colorIdx.abs()].toARGB32(),
    distanceM: dist,
  );
}

double _lineLength(List<GeoPoint> pts) {
  if (pts.length < 2) return 0;
  const r = 6371000.0;
  double total = 0;
  for (var i = 1; i < pts.length; i++) {
    total += _hav(pts[i - 1], pts[i], r);
  }
  return total;
}

double _hav(GeoPoint a, GeoPoint b, double r) {
  final dLat = (b.lat - a.lat) * math.pi / 180.0;
  final dLng = (b.lng - a.lng) * math.pi / 180.0;
  final la1 = a.lat * math.pi / 180.0;
  final la2 = b.lat * math.pi / 180.0;
  final sdLat = math.sin(dLat / 2);
  final sdLng = math.sin(dLng / 2);
  final h = sdLat * sdLat + sdLng * sdLng * math.cos(la1) * math.cos(la2);
  return 2 * r * math.asin(math.sqrt(h));
}
