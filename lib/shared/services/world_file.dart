import 'dart:io';
import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../models/map_layer.dart';

/// Half-circumference of the EPSG:3857 Mercator projection, in metres.
/// Equals π * a where a = 6378137 (WGS84 semi-major). Used to convert
/// Web Mercator metres ↔ WGS84 degrees.
const double _mercatorHalf = 20037508.342789244;
const double _mercatorR = 6378137.0;

/// World file — ESRI/GDAL raster georeferencing sidecar.
///
/// Comes in two flavours:
///
///  * **Plain text (`.tfw` / `.jgw` / `.pgw`)** — 6 lines of doubles in
///    the canonical order: A, D, B, E, C, F (pixel size X, skew Y,
///    skew X, pixel size Y (usually negative), upper-left X, upper-left Y).
///
///  * **XML (`.tfwx` / `.jgwx` / `.pgwx`)** — ArcGIS "Spatial Reference"
///    XML that wraps the same 6 numbers plus projection metadata.
///    We ignore the projection (see `_looksLikeGeographic`) and just pull
///    the numbers.
///
/// The parser assumes WGS84 (EPSG:4326) coordinates. If the file uses a
/// projected CRS (UTM, Gauss-Krüger, etc) the numbers will be metres and
/// out of valid lat/lng range — we detect that and surface a clear error
/// message so the user knows what's wrong.
class WorldFile {
  const WorldFile({
    required this.pixelSizeX,
    required this.rotationY,
    required this.rotationX,
    required this.pixelSizeY,
    required this.originX,
    required this.originY,
  });

  /// A — x-direction pixel size (degrees per pixel for WGS84).
  final double pixelSizeX;

  /// D — skew factor, y-direction (usually 0).
  final double rotationY;

  /// B — skew factor, x-direction (usually 0).
  final double rotationX;

  /// E — y-direction pixel size. Conventionally **negative** (images go
  /// top-to-bottom; latitude decreases as we go down).
  final double pixelSizeY;

  /// C — x-coordinate (longitude in WGS84) of the **center** of the
  /// upper-left pixel.
  final double originX;

  /// F — y-coordinate (latitude in WGS84) of the **center** of the
  /// upper-left pixel.
  final double originY;

  /// Compute geographic bbox given the image's pixel dimensions.
  /// Corrects the half-pixel offset (origin is *center* of pixel) so
  /// the resulting bbox hugs the image edges, not centres.
  LayerBounds boundsFor({required int widthPx, required int heightPx}) {
    // Upper-left corner, accounting for center-of-pixel origin convention.
    final ulX = originX - pixelSizeX / 2;
    final ulY = originY - pixelSizeY / 2;
    final lrX = ulX + pixelSizeX * widthPx;
    final lrY = ulY + pixelSizeY * heightPx;

    return LayerBounds(
      northLat: ulY > lrY ? ulY : lrY,
      southLat: ulY < lrY ? ulY : lrY,
      westLng: ulX < lrX ? ulX : lrX,
      eastLng: ulX > lrX ? ulX : lrX,
    );
  }

  /// Sanity check: do the origin coords look like WGS84 degrees?
  /// Lat in [-90, 90], lng in [-180, 180]. Projected metres (e.g.
  /// UTM's 500000+) will fail this and the caller should reject the file.
  bool get looksLikeGeographic =>
      originX.abs() <= 180 && originY.abs() <= 90;

  /// Does the world file look like EPSG:3857 (Web Mercator) metres?
  /// QGIS almost always emits this when the project CRS is OSM-style
  /// Pseudo-Mercator, which is the default for online basemaps. The
  /// valid range is ±20,037,508 m for both axes; anything else (UTM
  /// eastings, Gauss-Krüger prefixed zones, etc.) falls through.
  bool get looksLikeWebMercator =>
      !looksLikeGeographic &&
      originX.abs() <= _mercatorHalf &&
      originY.abs() <= _mercatorHalf;

  /// Compute geographic bbox from a world file expressed in EPSG:3857
  /// metres. We convert the top-left and bottom-right corners through
  /// the Mercator equations to WGS84 degrees and use those as the
  /// bbox. Mid-image pixels end up slightly off (Mercator stretches
  /// poleward while our storage is a simple lat/lng rectangle), but
  /// the distortion is negligible for single-sheet scans and makes
  /// the "default QGIS export" path just work instead of hitting the
  /// old "UTM error" dead end.
  LayerBounds boundsForWebMercator({
    required int widthPx,
    required int heightPx,
  }) {
    final ulX = originX - pixelSizeX / 2;
    final ulY = originY - pixelSizeY / 2;
    final lrX = ulX + pixelSizeX * widthPx;
    final lrY = ulY + pixelSizeY * heightPx;

    final ulLng = _mercToLng(ulX);
    final ulLat = _mercToLat(ulY);
    final lrLng = _mercToLng(lrX);
    final lrLat = _mercToLat(lrY);

    return LayerBounds(
      northLat: ulLat > lrLat ? ulLat : lrLat,
      southLat: ulLat < lrLat ? ulLat : lrLat,
      westLng: ulLng < lrLng ? ulLng : lrLng,
      eastLng: ulLng > lrLng ? ulLng : lrLng,
    );
  }

  /// Best-effort geographic bbox. Tries WGS84 first, then EPSG:3857.
  /// Returns null if neither projection yields sane coords.
  LayerBounds? boundsForRasterAutoDetect({
    required int widthPx,
    required int heightPx,
  }) {
    if (looksLikeGeographic) {
      return boundsFor(widthPx: widthPx, heightPx: heightPx);
    }
    if (looksLikeWebMercator) {
      return boundsForWebMercator(widthPx: widthPx, heightPx: heightPx);
    }
    return null;
  }

  static double _mercToLng(double x) => x / _mercatorHalf * 180.0;

  static double _mercToLat(double y) {
    // lat = atan(sinh(y / R)) in radians, then → degrees.
    final n = y / _mercatorR;
    // sinh(n) — dart:math has no sinh, but (e^n - e^-n) / 2 is fine.
    final sinhN = (math.exp(n) - math.exp(-n)) / 2.0;
    return math.atan(sinhN) * 180.0 / math.pi;
  }

  // --- Parsers ---

  /// Try parsing a file as either plain-text or XML world file. Returns
  /// null if neither format recognizes it.
  static Future<WorldFile?> parse(File file) async {
    final text = await file.readAsString();
    return _tryParsePlain(text) ?? _tryParseXml(text);
  }

  /// Classic 6-line text: A\nD\nB\nE\nC\nF. Whitespace tolerant.
  ///
  /// Handles both US ("0.5") and European ("0,5") decimal conventions.
  /// Russian QGIS / GDAL builds sometimes honour the system locale and
  /// emit commas; `double.parse` rejects those, so we normalise first.
  static WorldFile? _tryParsePlain(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 6) return null;
    try {
      return WorldFile(
        pixelSizeX: _parseLocaleDouble(lines[0]),
        rotationY: _parseLocaleDouble(lines[1]),
        rotationX: _parseLocaleDouble(lines[2]),
        pixelSizeY: _parseLocaleDouble(lines[3]),
        originX: _parseLocaleDouble(lines[4]),
        originY: _parseLocaleDouble(lines[5]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse a double accepting both "0.5" (US) and "0,5" (European
  /// locale) decimal separators. Throws [FormatException] on bad input
  /// so callers can guard the whole 6-line parse with a single try.
  static double _parseLocaleDouble(String s) {
    final direct = double.tryParse(s);
    if (direct != null) return direct;
    // Substitute comma → dot and retry. We don't support comma as a
    // thousands separator because world files never use one.
    final swapped = double.tryParse(s.replaceAll(',', '.'));
    if (swapped != null) return swapped;
    throw FormatException('not a double: $s');
  }

  /// ArcGIS "tfwx" XML wrapper. Looks something like:
  /// <PAMDataset><GeoTransform> 37.5, 0.0001, 0, 57.2, 0, -0.0001 </GeoTransform></PAMDataset>
  /// or an ESRI SpatialReference XML with PixelXSize / PixelYSize /
  /// ULX / ULY elements. We try both.
  static WorldFile? _tryParseXml(String text) {
    if (!text.trimLeft().startsWith('<')) return null;
    try {
      final doc = XmlDocument.parse(text);

      // Variant A: <GeoTransform>ulX, sizeX, rotY, ulY, rotX, sizeY</GeoTransform>
      //            (GDAL's convention: C, A, D, F, B, E)
      //
      // GDAL writes commas, but hand-authored or older exports
      // sometimes use whitespace. Split on either. The file is
      // rejected quietly (returns null) if there aren't six numbers
      // — the caller then moves on to the next sidecar candidate.
      final gt = doc.findAllElements('GeoTransform').firstOrNull?.innerText;
      if (gt != null && gt.trim().isNotEmpty) {
        // GeoTransform uses commas as delimiters, so locale-comma
        // decimals would be ambiguous here — GDAL always writes dots.
        // Split on [, ] only and parse straight.
        final nums = gt
            .split(RegExp(r'[,\s]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map(double.tryParse)
            .whereType<double>()
            .toList();
        if (nums.length >= 6) {
          return WorldFile(
            originX: nums[0],
            pixelSizeX: nums[1],
            rotationY: nums[2],
            originY: nums[3],
            rotationX: nums[4],
            pixelSizeY: nums[5],
          );
        }
      }

      // Variant B: element-per-number. Covers a handful of well-
      // documented XML wrappers:
      //   * ESRI "SpatialReference" with PixelXSize / PixelYSize /
      //     ULX / ULY
      //   * GDAL PAM with XDim / YDim / XMin / YMax / Left / Top
      //   * ArcGIS "ExtendedWorldFile" with PixelScaleX / TiePointX / …
      //   * ArcView-era tags XSize / YSize / XCoordinate / YCoordinate
      //
      // Single-letter aliases (A/E/C/F from the canonical world-file
      // convention) are intentionally excluded — those element names
      // collide with unrelated XML (SRS transformation parameters,
      // etc.) and would false-match.
      double? pick(Iterable<String> names) {
        for (final n in names) {
          final el = doc.findAllElements(n).firstOrNull;
          if (el != null) {
            final raw = el.innerText.trim();
            final v = double.tryParse(raw) ??
                double.tryParse(raw.replaceAll(',', '.'));
            if (v != null) return v;
          }
        }
        return null;
      }

      final pxX = pick([
        'PixelXSize', 'XDim', 'PixelScaleX', 'XSize', 'XStep',
      ]);
      final pxY = pick([
        'PixelYSize', 'YDim', 'PixelScaleY', 'YSize', 'YStep',
      ]);
      final ulX = pick([
        'ULX', 'XMin', 'Left', 'TiePointX', 'XCoordinate',
        'TopLeftX', 'UpperLeftX',
      ]);
      final ulY = pick([
        'ULY', 'YMax', 'Top', 'TiePointY', 'YCoordinate',
        'TopLeftY', 'UpperLeftY',
      ]);
      final rotY = pick(['XRotation', 'RotationY']) ?? 0.0;
      final rotX = pick(['YRotation', 'RotationX']) ?? 0.0;
      if (pxX != null && pxY != null && ulX != null && ulY != null) {
        return WorldFile(
          pixelSizeX: pxX,
          rotationY: rotY,
          rotationX: rotX,
          // Enforce top-down convention: pixelSizeY is conventionally
          // negative since image Y grows downward while latitude
          // grows upward.
          pixelSizeY: pxY < 0 ? pxY : -pxY,
          originX: ulX,
          originY: ulY,
        );
      }
    } catch (_) {
      // Malformed XML — fall through.
    }
    return null;
  }

  /// Human-readable one-liner describing what's in a sidecar file
  /// that failed to parse — primarily the XML root element name, or
  /// the first line of a text file. Used by the UI to surface a hint
  /// like "не смог разобрать `<SpatialReferencePAM>`" so the user
  /// knows the format isn't just "broken", it's a specific flavour
  /// we don't support yet.
  static Future<String?> describeSidecarShape(File f) async {
    try {
      final text = await f.readAsString();
      final trimmed = text.trimLeft();
      if (trimmed.startsWith('<')) {
        try {
          final doc = XmlDocument.parse(text);
          final root = doc.rootElement.name.qualified;
          // Peek at direct child element names for a richer hint.
          final children = doc.rootElement.childElements
              .take(4)
              .map((e) => e.name.qualified)
              .toList();
          return children.isEmpty
              ? '<$root>'
              : '<$root> → ${children.join(', ')}';
        } catch (_) {
          // Malformed XML — fall through to text preview.
        }
      }
      final firstLine = text.split(RegExp(r'[\r\n]+')).firstOrNull?.trim() ?? '';
      if (firstLine.isEmpty) return null;
      return firstLine.length > 80
          ? '"${firstLine.substring(0, 80)}…"'
          : '"$firstLine"';
    } catch (_) {
      return null;
    }
  }

  /// Try every standard sidecar extension next to a raster: .tfw/.tfwx
  /// for TIFF, .jgw/.jgwx for JPEG, .pgw for PNG, the GDAL shortcut
  /// `<name>.wld`, and finally GDAL's PAM metadata sidecar
  /// `<fullname>.aux.xml` which often carries a `<GeoTransform>` when
  /// QGIS / ArcGIS Pro emit it. First parsed result wins.
  static Future<WorldFile?> findSidecar(String rasterPath) async {
    final dir = File(rasterPath).parent;
    final base = rasterPath.split(RegExp(r'[/\\]')).last;
    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    final candidates = <String>[
      '$stem.tfwx',
      '$stem.tfw',
      '$stem.jgwx',
      '$stem.jgw',
      '$stem.pgw',
      '$stem.wld',
      // GDAL PAM — note this is full-filename + .aux.xml (e.g.
      // `Prigorodnoe.tif.aux.xml`, NOT `Prigorodnoe.aux.xml`).
      '$base.aux.xml',
      // Case-insensitive fallbacks.
      '$stem.TFW',
      '$stem.TFWX',
      '$stem.JGW',
      '$stem.JGWX',
      '$stem.PGW',
      '$stem.WLD',
    ];
    for (final name in candidates) {
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      if (await f.exists()) {
        final parsed = await WorldFile.parse(f);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
