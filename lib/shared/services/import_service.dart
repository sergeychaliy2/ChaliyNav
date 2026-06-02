import 'dart:io';

import 'geojson_service.dart';
import 'gpx_service.dart';
import 'kml_service.dart';

/// Unified file-based import. Detects format by extension and delegates
/// to the right parser. Supports:
///   - .gpx   (GPX 1.1 — universal, Garmin, all apps)
///   - .kml   (Google Earth, Google My Maps, Yandex Избранное, Maps.me)
///   - .kmz   (zipped KML)
class ImportService {
  ImportService._();

  static bool isSupported(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.gpx') ||
        lower.endsWith('.kml') ||
        lower.endsWith('.kmz') ||
        lower.endsWith('.geojson') ||
        lower.endsWith('.json');
  }

  static Future<GpxImportResult> importFile(File file) async {
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.gpx')) {
      final content = await file.readAsString();
      return GpxService.parse(content);
    }
    if (lower.endsWith('.kml') || lower.endsWith('.kmz')) {
      return KmlService.parseFile(file);
    }
    if (lower.endsWith('.geojson') || lower.endsWith('.json')) {
      return GeoJsonService.parseFile(file);
    }
    throw FormatException(
      'Неподдерживаемый формат: ${file.path.split('.').last}. '
      'Используйте .gpx, .kml, .kmz или .geojson.',
    );
  }
}
