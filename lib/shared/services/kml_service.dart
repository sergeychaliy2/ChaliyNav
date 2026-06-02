import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive_io.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../../core/theme/app_colors.dart';
import '../models/geo_point.dart';
import '../models/poi_category.dart';
import '../models/poi_icon_library.dart';
import '../models/point_of_interest.dart';
import '../models/route_path.dart';
import '../models/track.dart';
import 'gpx_service.dart';

/// Parse Google Earth KML / KMZ files.
/// KMZ = ZIP container with a doc.kml inside.
///
/// Sources we explicitly support:
///   - Google My Maps (export → KML)
///   - Google Earth
///   - Yandex.Maps «Избранное» (export → KML)
///   - Maps.me / OrganicMaps bookmarks (.kml / .kmz)
class KmlService {
  KmlService._();

  static Future<GpxImportResult> parseFile(File file) async {
    final path = file.path.toLowerCase();
    if (path.endsWith('.kmz')) {
      return _parseKmz(file);
    }
    final content = await file.readAsString();
    return parseKml(content);
  }

  static Future<GpxImportResult> _parseKmz(File kmz) async {
    final bytes = await kmz.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docFile;
    for (final f in archive) {
      if (f.isFile && f.name.toLowerCase().endsWith('.kml')) {
        docFile = f;
        if (f.name.toLowerCase() == 'doc.kml') break; // prefer doc.kml
      }
    }
    if (docFile == null) {
      throw const FormatException('В KMZ не найдено .kml');
    }
    final content = String.fromCharCodes(docFile.content as List<int>);
    return parseKml(content);
  }

  static GpxImportResult parseKml(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final root = doc.rootElement;
    if (root.localName.toLowerCase() != 'kml') {
      throw const FormatException('Файл не содержит <kml>');
    }

    final tracks = <Track>[];
    final points = <PointOfInterest>[];
    final routes = <RoutePath>[];

    // Recursively walk Placemarks (may be nested inside <Folder> / <Document>).
    for (final pm in root.findAllElements('Placemark')) {
      final name =
          pm.getElement('name')?.innerText.trim() ?? 'Без названия';
      final desc = pm.getElement('description')?.innerText.trim() ?? '';
      final whenStr =
          pm.getElement('TimeStamp')?.getElement('when')?.innerText;
      final when = whenStr != null ? DateTime.tryParse(whenStr) : null;

      // Point placemark → POI
      final pointEl = pm.getElement('Point');
      if (pointEl != null) {
        final coord = _parseCoord(pointEl.getElement('coordinates')?.innerText);
        if (coord != null) {
          points.add(
            PointOfInterest(
              id: const Uuid().v4(),
              title: name,
              note: desc,
              coord: GeoPoint(
                lat: coord.lat,
                lng: coord.lng,
                altitude: coord.altitude,
                timestamp: when,
              ),
              iconId: PoiIconLibrary.defaultFor(PoiCategory.other).id,
              createdAt: when ?? DateTime.now(),
            ),
          );
          continue;
        }
      }

      // LineString → treat as track (path with geometry but no per-point timestamps)
      // or as route (if no track semantics).
      final line = pm.getElement('LineString');
      if (line != null) {
        final pts = _parseCoords(line.getElement('coordinates')?.innerText);
        if (pts.length < 2) continue;
        // Treat as route by default — no timing in KML LineString.
        routes.add(
          RoutePath(
            id: const Uuid().v4(),
            title: name,
            points: pts,
            createdAt: when ?? DateTime.now(),
            note: desc,
            source: RouteSource.gpxImport,
          ),
        );
        continue;
      }

      // gx:Track (Google Earth extended track with times)
      final gxTrack = pm.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'Track' || e.localName == 'MultiTrack')
          .firstOrNull;
      if (gxTrack != null) {
        final when = gxTrack.descendants
            .whereType<XmlElement>()
            .where((e) => e.localName == 'when')
            .map((e) => DateTime.tryParse(e.innerText))
            .toList();
        final coords = gxTrack.descendants
            .whereType<XmlElement>()
            .where((e) => e.localName == 'coord')
            .map((e) => _parseGxCoord(e.innerText))
            .whereType<_Coord>()
            .toList();
        if (coords.length >= 2) {
          final geoPts = <GeoPoint>[];
          for (var i = 0; i < coords.length; i++) {
            geoPts.add(GeoPoint(
              lat: coords[i].lat,
              lng: coords[i].lng,
              altitude: coords[i].altitude,
              timestamp: i < when.length ? when[i] : null,
            ));
          }
          final first = geoPts.first.timestamp ?? DateTime.now();
          final last = geoPts.last.timestamp ?? first;
          final dist = _totalDistance(geoPts);
          final dur = last.difference(first).inSeconds.clamp(1, 1 << 30);
          final colorIdx = tracks.length % AppColors.trackColors.length;
          tracks.add(
            Track(
              id: const Uuid().v4(),
              title: name,
              points: geoPts,
              startedAt: first,
              finishedAt: last,
              colorValue: AppColors.trackColors[colorIdx].toARGB32(),
              distanceM: dist,
              avgSpeedMps: dist / dur,
              note: desc,
            ),
          );
        }
      }

      // MultiGeometry — flatten into multiple routes for simplicity
      final multi = pm.getElement('MultiGeometry');
      if (multi != null) {
        for (final inner in multi.findElements('LineString')) {
          final pts = _parseCoords(inner.getElement('coordinates')?.innerText);
          if (pts.length >= 2) {
            routes.add(
              RoutePath(
                id: const Uuid().v4(),
                title: name,
                points: pts,
                createdAt: when ?? DateTime.now(),
                note: desc,
                source: RouteSource.gpxImport,
              ),
            );
          }
        }
      }
    }

    return GpxImportResult(tracks: tracks, points: points, routes: routes);
  }

  static _Coord? _parseCoord(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return _parseLonLatAlt(trimmed);
  }

  static List<GeoPoint> _parseCoords(String? raw) {
    if (raw == null) return const [];
    final tokens = raw.trim().split(RegExp(r'\s+'));
    final out = <GeoPoint>[];
    for (final token in tokens) {
      if (token.trim().isEmpty) continue;
      final c = _parseLonLatAlt(token);
      if (c != null) {
        out.add(GeoPoint(lat: c.lat, lng: c.lng, altitude: c.altitude));
      }
    }
    return out;
  }

  /// KML coord format: "lon,lat[,alt]"
  static _Coord? _parseLonLatAlt(String token) {
    final parts = token.split(',');
    if (parts.length < 2) return null;
    final lon = double.tryParse(parts[0].trim());
    final lat = double.tryParse(parts[1].trim());
    if (lon == null || lat == null) return null;
    final alt = parts.length >= 3 ? double.tryParse(parts[2].trim()) : null;
    return _Coord(lat: lat, lng: lon, altitude: alt);
  }

  /// gx:coord format: "lon lat alt" (space separated)
  static _Coord? _parseGxCoord(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final lon = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lon == null || lat == null) return null;
    final alt = parts.length >= 3 ? double.tryParse(parts[2]) : null;
    return _Coord(lat: lat, lng: lon, altitude: alt);
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
    final dLat = (b.lat - a.lat) * math.pi / 180.0;
    final dLng = (b.lng - a.lng) * math.pi / 180.0;
    final la1 = a.lat * math.pi / 180.0;
    final la2 = b.lat * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(la1) * math.cos(la2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}

class _Coord {
  const _Coord({required this.lat, required this.lng, this.altitude});
  final double lat;
  final double lng;
  final double? altitude;
}
