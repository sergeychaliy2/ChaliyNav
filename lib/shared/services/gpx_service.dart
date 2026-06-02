import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../../core/theme/app_colors.dart';
import '../models/geo_point.dart';
import '../models/poi_category.dart';
import '../models/poi_icon_library.dart';
import '../models/point_of_interest.dart';
import '../models/route_path.dart';
import '../models/track.dart';

/// Parse and emit GPX 1.1 files. Supports:
///   - Tracks (<trk><trkseg><trkpt/>)
///   - Waypoints (<wpt/>) — mapped to POIs
///   - Routes (<rte><rtept/>)
class GpxService {
  GpxService._();

  /// Parse a GPX string. Returns tracks / points / routes for the caller to
  /// persist into repositories.
  static GpxImportResult parse(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final root = doc.rootElement;
    if (root.localName.toLowerCase() != 'gpx') {
      throw const FormatException('Файл не содержит <gpx>');
    }

    final tracks = <Track>[];
    final points = <PointOfInterest>[];
    final routes = <RoutePath>[];

    for (final wpt in root.findElements('wpt')) {
      final lat = _attr(wpt, 'lat');
      final lon = _attr(wpt, 'lon');
      if (lat == null || lon == null) continue;
      final name = wpt.getElement('name')?.innerText.trim() ?? 'Точка';
      final desc = wpt.getElement('desc')?.innerText.trim() ?? '';
      final ele = double.tryParse(wpt.getElement('ele')?.innerText ?? '');
      final timeStr = wpt.getElement('time')?.innerText;
      final created = timeStr != null ? DateTime.tryParse(timeStr) : null;
      points.add(
        PointOfInterest(
          id: const Uuid().v4(),
          title: name,
          note: desc,
          coord: GeoPoint(
            lat: double.parse(lat),
            lng: double.parse(lon),
            altitude: ele,
            timestamp: created,
          ),
          iconId: PoiIconLibrary.defaultFor(PoiCategory.other).id,
          createdAt: created ?? DateTime.now(),
        ),
      );
    }

    for (final trk in root.findElements('trk')) {
      final name = trk.getElement('name')?.innerText.trim() ?? 'Импорт GPX';
      final geoPoints = <GeoPoint>[];
      DateTime? first;
      DateTime? last;
      for (final seg in trk.findElements('trkseg')) {
        for (final pt in seg.findElements('trkpt')) {
          final lat = _attr(pt, 'lat');
          final lon = _attr(pt, 'lon');
          if (lat == null || lon == null) continue;
          final ele = double.tryParse(pt.getElement('ele')?.innerText ?? '');
          final timeStr = pt.getElement('time')?.innerText;
          final ts = timeStr != null ? DateTime.tryParse(timeStr) : null;
          first ??= ts;
          if (ts != null) last = ts;
          geoPoints.add(
            GeoPoint(
              lat: double.parse(lat),
              lng: double.parse(lon),
              altitude: ele,
              timestamp: ts,
            ),
          );
        }
      }
      if (geoPoints.length < 2) continue;

      final started = first ?? DateTime.now();
      final finished = last ?? DateTime.now();
      final colorIdx = tracks.length % AppColors.trackColors.length;
      final dist = _totalDistance(geoPoints);
      final durSec = finished.difference(started).inSeconds.clamp(1, 1 << 30);

      tracks.add(
        Track(
          id: const Uuid().v4(),
          title: name,
          points: geoPoints,
          startedAt: started,
          finishedAt: finished,
          colorValue: AppColors.trackColors[colorIdx].toARGB32(),
          distanceM: dist,
          avgSpeedMps: dist / durSec,
        ),
      );
    }

    for (final rte in root.findElements('rte')) {
      final name = rte.getElement('name')?.innerText.trim() ?? 'Маршрут GPX';
      final waypoints = <GeoPoint>[];
      for (final pt in rte.findElements('rtept')) {
        final lat = _attr(pt, 'lat');
        final lon = _attr(pt, 'lon');
        if (lat == null || lon == null) continue;
        waypoints.add(GeoPoint(lat: double.parse(lat), lng: double.parse(lon)));
      }
      if (waypoints.length < 2) continue;
      routes.add(
        RoutePath(
          id: const Uuid().v4(),
          title: name,
          points: waypoints,
          createdAt: DateTime.now(),
          source: RouteSource.gpxImport,
        ),
      );
    }

    return GpxImportResult(tracks: tracks, points: points, routes: routes);
  }

  /// Serialize a collection to GPX 1.1.
  static String serialize({
    List<Track> tracks = const [],
    List<PointOfInterest> points = const [],
    List<RoutePath> routes = const [],
  }) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element('gpx', nest: () {
      b.attribute('version', '1.1');
      b.attribute('creator', 'ChaliyNav');
      b.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');

      for (final p in points) {
        b.element('wpt', nest: () {
          b.attribute('lat', p.coord.lat.toStringAsFixed(7));
          b.attribute('lon', p.coord.lng.toStringAsFixed(7));
          if (p.coord.altitude != null) {
            b.element('ele', nest: p.coord.altitude!.toStringAsFixed(2));
          }
          b.element('time', nest: p.createdAt.toUtc().toIso8601String());
          b.element('name', nest: p.title);
          if (p.note.isNotEmpty) b.element('desc', nest: p.note);
          b.element('sym', nest: p.icon.name);
        });
      }

      for (final t in tracks) {
        b.element('trk', nest: () {
          b.element('name', nest: t.title);
          if (t.note.isNotEmpty) b.element('desc', nest: t.note);
          b.element('trkseg', nest: () {
            for (final g in t.points) {
              b.element('trkpt', nest: () {
                b.attribute('lat', g.lat.toStringAsFixed(7));
                b.attribute('lon', g.lng.toStringAsFixed(7));
                if (g.altitude != null) {
                  b.element('ele', nest: g.altitude!.toStringAsFixed(2));
                }
                if (g.timestamp != null) {
                  b.element('time',
                      nest: g.timestamp!.toUtc().toIso8601String());
                }
              });
            }
          });
        });
      }

      for (final r in routes) {
        b.element('rte', nest: () {
          b.element('name', nest: r.title);
          for (final g in r.points) {
            b.element('rtept', nest: () {
              b.attribute('lat', g.lat.toStringAsFixed(7));
              b.attribute('lon', g.lng.toStringAsFixed(7));
              if (g.altitude != null) {
                b.element('ele', nest: g.altitude!.toStringAsFixed(2));
              }
            });
          }
        });
      }
    });
    return b.buildDocument().toXmlString(pretty: true);
  }

  /// Write GPX to a shareable file and return its path.
  static Future<File> writeToFile(String xml, String baseName) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exports'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final safe = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9а-яА-Я\-_]'), '_');
    final file = File(p.join(
      exportsDir.path,
      '${safe}_${DateTime.now().millisecondsSinceEpoch}.gpx',
    ));
    await file.writeAsString(xml);
    return file;
  }

  static String? _attr(XmlElement e, String name) {
    final a = e.getAttribute(name);
    return a?.isEmpty == true ? null : a;
  }

  static double _totalDistance(List<GeoPoint> pts) {
    if (pts.length < 2) return 0;
    double total = 0;
    for (var i = 1; i < pts.length; i++) {
      total += _haversine(pts[i - 1], pts[i]);
    }
    return total;
  }

  static double _haversine(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = _deg(b.lat - a.lat);
    final dLng = _deg(b.lng - a.lng);
    final la1 = _deg(a.lat);
    final la2 = _deg(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(la1) * math.cos(la2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _deg(double d) => d * math.pi / 180.0;
}

/// Result container for GPX import.
class GpxImportResult {
  const GpxImportResult({
    required this.tracks,
    required this.points,
    required this.routes,
  });

  final List<Track> tracks;
  final List<PointOfInterest> points;
  final List<RoutePath> routes;

  bool get isEmpty => tracks.isEmpty && points.isEmpty && routes.isEmpty;
  int get totalItems => tracks.length + points.length + routes.length;
}
