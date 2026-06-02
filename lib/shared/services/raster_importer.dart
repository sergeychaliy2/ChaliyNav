import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/map_layer.dart';
import 'jnx_reader.dart';
import 'world_file.dart';

/// High-level import of geo-referenced raster files (`.tif`, `.tiff`,
/// `.jpg`, `.jpeg`, `.png`) with a matching world-file sidecar
/// (`.tfw/.tfwx/.jgwx/.pgw/.wld`).
///
/// What happens when the user picks a file:
///
///  1. We sniff the extension to decide which decoder to invoke.
///  2. We look for a sidecar world-file next to the raster.
///  3. We compute the geographic bounding box from the world-file plus
///     the raster's pixel dimensions.
///  4. If the raster needs transcoding (TIFF → PNG because Flutter's
///     built-in image decoders don't speak TIFF), we decode it via the
///     `image` package and re-save as PNG in the app's private
///     `layers/` directory.
///  5. We emit a [MapLayer] of type `imageOverlay` with those bounds.
///     It's ready to be dropped into `layersProvider` and will render
///     through the existing `OverlayImageLayer` path in
///     `UserLayersStack`.
///
/// For files WITHOUT a world-file, we fall back to copying the raster
/// into the private dir and returning a result with null bounds — the
/// caller should then redirect the user to the 2-point GeoreferenceScreen
/// to attach coordinates manually.
class RasterImportResult {
  const RasterImportResult({
    required this.layer,
    required this.kind,
    this.warning,
  });

  final MapLayer layer;
  final RasterImportKind kind;

  /// Non-null if the import produced a usable layer but the user should
  /// still see a cautionary message (e.g. "coords look suspicious — is
  /// this UTM?"). Shown as a SnackBar by the caller.
  final String? warning;
}

enum RasterImportKind {
  /// World-file found + parsed + raster decoded → fully automatic layer.
  georeferencedRaster,

  /// No world-file sidecar — raster saved but the user still needs to
  /// open GeoreferenceScreen and click two corners.
  ungeoreferenced,
}

class RasterImporter {
  RasterImporter._();

  /// Anything we're willing to attempt.
  static const supportedExtensions = <String>{
    '.tif',
    '.tiff',
    '.jpg',
    '.jpeg',
    '.png',
    '.jnx',
  };

  static bool canHandle(String path) {
    final ext = p.extension(path).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// Extensions recognised as world-file sidecars when matching picks
  /// by filename stem. `.xml` is included only so we can match
  /// `<raster>.aux.xml` (GDAL PAM) — the caller filters further.
  static const sidecarExtensions = <String>{
    '.tfw', '.tfwx', '.jgw', '.jgwx', '.pgw', '.wld',
  };

  /// From a set of paths the user multi-selected, pull out the
  /// raster and any matching sidecar, then — if they live in
  /// different directories — copy both side-by-side into a temp
  /// staging dir. Returns the path at which [importFile] should be
  /// invoked (either the original raster path when no staging is
  /// needed, or the staged copy).
  ///
  /// This is what makes georeferenced maps "just work" on Android:
  /// `file_picker` there copies each selected entry into its own
  /// private cache, so the `.tfw` sitting next to a `.tif` on disk
  /// never crosses the sandbox. We reunite them ourselves.
  static Future<
      ({
        String rasterPath,
        bool sidecarMatched,
        List<String> sidecarPaths,
      })?> stageSelection(
    Iterable<String> pickedPaths,
  ) async {
    // Find raster (first wins — a sensible raster pick is exactly one
    // image anyway).
    String? rasterPath;
    for (final f in pickedPaths) {
      if (canHandle(f)) {
        rasterPath = f;
        break;
      }
    }
    if (rasterPath == null) return null;

    final rasterStem = p.basenameWithoutExtension(rasterPath);
    final rasterFull = p.basename(rasterPath);

    // Collect EVERY matching sidecar in the selection — the user may
    // have picked both a "real" world file (.jgwx / .tfw / …) AND a
    // GDAL PAM metadata file (.aux.xml). The PAM file often contains
    // only SRS + statistics and NO GeoTransform, so if we stage only
    // the first hit we could end up with an unparseable aux.xml and
    // fall through to the manual-placement fallback. Stage all of
    // them so `findSidecar` picks the first that actually parses,
    // in its canonical priority order.
    final sidecarPaths = <String>[];
    for (final f in pickedPaths) {
      if (f == rasterPath) continue;
      final fStem = p.basenameWithoutExtension(f);
      final fExt = p.extension(f).toLowerCase();
      final fBase = p.basename(f).toLowerCase();
      final stemMatches = fStem == rasterStem || fStem == rasterFull;
      final isAuxXml = fBase == '${rasterFull.toLowerCase()}.aux.xml';
      if ((stemMatches && sidecarExtensions.contains(fExt)) || isAuxXml) {
        sidecarPaths.add(f);
      }
    }

    if (sidecarPaths.isEmpty) {
      return (
        rasterPath: rasterPath,
        sidecarMatched: false,
        sidecarPaths: const <String>[],
      );
    }

    // Fast path: every sidecar already lives next to the raster.
    // Skip staging so we don't needlessly copy large rasters.
    final rasterDir = File(rasterPath).parent.path;
    final allNextToRaster = sidecarPaths.every(
      (s) => File(s).parent.path == rasterDir,
    );
    if (allNextToRaster) {
      return (
        rasterPath: rasterPath,
        sidecarMatched: true,
        sidecarPaths: sidecarPaths,
      );
    }

    // Staging path: copy the raster + every matching sidecar into a
    // fresh temp dir so they share a common parent and `findSidecar`
    // can locate them by filename.
    final tmpRoot = await getTemporaryDirectory();
    final staging = Directory(p.join(
      tmpRoot.path,
      'georef_${DateTime.now().microsecondsSinceEpoch}',
    ));
    await staging.create(recursive: true);
    final stagedRaster = File(p.join(staging.path, p.basename(rasterPath)));
    await File(rasterPath).copy(stagedRaster.path);
    final stagedSidecarPaths = <String>[];
    for (final s in sidecarPaths) {
      final stagedSidecar = File(p.join(staging.path, p.basename(s)));
      await File(s).copy(stagedSidecar.path);
      stagedSidecarPaths.add(stagedSidecar.path);
    }
    return (
      rasterPath: stagedRaster.path,
      sidecarMatched: true,
      sidecarPaths: stagedSidecarPaths,
    );
  }

  /// Do the full import dance for a user-picked raster. Never throws —
  /// catches all errors and returns a result or throws [RasterImportException]
  /// with a human-readable message the UI can toast.
  static Future<RasterImportResult> importFile(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw const RasterImportException('Файл не найден.');
    }
    final ext = p.extension(sourcePath).toLowerCase();
    if (!supportedExtensions.contains(ext)) {
      throw RasterImportException(
        'Формат $ext не поддерживается. Сконвертируйте в .tif, .jpg, .png или .jnx.',
      );
    }

    // ---- Special case: Garmin JNX ----
    // JNX carries its georeferencing inside the file (per-tile lat/lng
    // bounds) — no sidecar involved. We decode the highest-detail
    // zoom level into a single `img.Image`, stitch all the JPEG tiles
    // onto it, then feed that image through the same slicing pipeline
    // we use for everything else. Bounds come straight from the JNX
    // header.
    if (ext == '.jnx') {
      return _importJnx(src, sourcePath);
    }

    // 1. Decode + transcode if needed. TIFF → PNG; JPEG/PNG are copied
    //    as-is when small; large rasters get pre-sliced into a tile
    //    grid (see `_tileThreshold`) so their pieces fit into GPU
    //    textures — otherwise Skia silently down-samples huge images
    //    to ~4096 on most Android phones and the overlay looks blurry
    //    regardless of filter quality.
    final ingest = await _ingestRaster(src, ext);

    // 2. Look for a world-file next to the original. Important to use
    //    the source path (not the saved copy) because we're matching by
    //    filename stem.
    final world = await WorldFile.findSidecar(sourcePath);

    if (world == null) {
      // No sidecar — the user needs to georeference by hand.
      return RasterImportResult(
        layer: MapLayer(
          id: const Uuid().v4(),
          name: p.basenameWithoutExtension(sourcePath),
          type: MapLayerType.imageOverlay,
          source: ingest.path,
          tileGrid: ingest.tileGrid,
          // bounds stays null — GeoreferenceScreen will fill it in.
          description: 'Без привязки — откройте в «Слои → Привязка».',
        ),
        kind: RasterImportKind.ungeoreferenced,
      );
    }

    // 3. Validate: WGS84 or EPSG:3857 (the two CRSes QGIS typically
    //    emits). Anything else — UTM, Gauss-Krüger, local — requires a
    //    reprojection the app doesn't do yet.
    if (!world.looksLikeGeographic && !world.looksLikeWebMercator) {
      throw RasterImportException(
        'Файл привязки содержит координаты ${world.originX.toStringAsFixed(1)}, '
        '${world.originY.toStringAsFixed(1)} — похоже на проекцию UTM или '
        'Гаусс-Крюгера (метры). Приложение понимает WGS84 (EPSG:4326) и '
        'Web Mercator (EPSG:3857). Перепривяжите карту в QGIS: '
        '«Сохранить как → GeoTIFF, EPSG:4326» или «EPSG:3857».',
      );
    }

    // 4. Raster pixel dimensions always come from the ingest result
    //    now — either the header probe (single-file path) or the full
    //    decode we already did when tiling. No extra decode needed.
    final bounds = world.boundsForRasterAutoDetect(
      widthPx: ingest.width,
      heightPx: ingest.height,
    );
    if (bounds == null) {
      throw const RasterImportException(
        'Не удалось вычислить привязку — проверьте, что растр и '
        'world-файл относятся к одной карте.',
      );
    }

    // 5. Sanity check bounds — sometimes a world file is valid-looking
    //    but references the wrong raster (e.g. corrupt pair).
    final latSpan = bounds.northLat - bounds.southLat;
    final lngSpan = bounds.eastLng - bounds.westLng;
    String? warning;
    if (latSpan > 20 || lngSpan > 40) {
      warning =
          'Привязка охватывает $latSpan° широты × $lngSpan° долготы — '
          'очень крупный регион, возможно world-file от другого файла.';
    } else if (world.looksLikeWebMercator) {
      warning =
          'Привязка из Web Mercator (EPSG:3857). На больших сканах '
          'возможна небольшая деформация к краям — если важна '
          'точность, перепривяжите в EPSG:4326.';
    }

    return RasterImportResult(
      layer: MapLayer(
        id: const Uuid().v4(),
        name: p.basenameWithoutExtension(sourcePath),
        type: MapLayerType.imageOverlay,
        source: ingest.path,
        tileGrid: ingest.tileGrid,
        bounds: bounds,
        description:
            'Привязка: ${bounds.northLat.toStringAsFixed(3)}°N '
            '${bounds.westLng.toStringAsFixed(3)}°E — '
            '${bounds.southLat.toStringAsFixed(3)}°N '
            '${bounds.eastLng.toStringAsFixed(3)}°E',
      ),
      kind: RasterImportKind.georeferencedRaster,
      warning: warning,
    );
  }

  /// Slice large rasters at this pixel threshold (per axis). Any raster
  /// whose width or height exceeds this gets pre-sliced into a grid
  /// on disk so each tile is comfortably within the GPU texture
  /// limits of every Android device we care about.
  ///
  /// 2048 is the sweet spot: below `GL_MAX_TEXTURE_SIZE` on every
  /// device (the oldest we target is 4096) while keeping the tile
  /// count manageable for typical forestry / land-use scans.
  static const int _tileThreshold = 2048;

  /// Copy / transcode / slice the raster into the app's private
  /// `layers/` dir. Always returns both an on-disk path and the
  /// raster's pixel dimensions (so the world-file maths can run
  /// without a second decode). When the raster exceeds
  /// [_tileThreshold] on either axis it's sliced into a grid of PNG
  /// tiles and [_IngestResult.tileGrid] is populated; otherwise the
  /// raster is saved as a single file (copy for JPG/PNG, transcode
  /// for TIFF).
  static Future<_IngestResult> _ingestRaster(File src, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final layersDir = Directory(p.join(dir.path, 'layers'));
    if (!await layersDir.exists()) {
      await layersDir.create(recursive: true);
    }
    final uuid = const Uuid().v4();
    final baseName = p
        .basenameWithoutExtension(src.path)
        .replaceAll(RegExp(r'[^\w\-]'), '_');

    // Cheap header probe first — this lets us skip the expensive full
    // decode for small JPG / PNG rasters that don't need tiling.
    // TIFF has no header probe (the codec varies too much to read
    // dimensions from a magic offset reliably), so for TIFF this
    // returns null and we fall through to the full decode below.
    final quickDims = await _probeDimensions(src, ext);

    // Fast path: JPG / PNG small enough to skip the decode entirely.
    if (quickDims != null &&
        quickDims.width <= _tileThreshold &&
        quickDims.height <= _tileThreshold &&
        (ext == '.jpg' || ext == '.jpeg' || ext == '.png')) {
      final dest = File(p.join(layersDir.path, '${uuid}_$baseName$ext'));
      await src.copy(dest.path);
      return _IngestResult(
        path: dest.path,
        width: quickDims.width,
        height: quickDims.height,
      );
    }

    // Everything else involves a full decode — either the raster is
    // TIFF (which Flutter can't render natively, so transcode anyway),
    // or we already know from the header probe it's too big for one
    // GPU texture, or it's TIFF and we don't know its size yet.
    img.Image? decoded;
    try {
      final bytes = await src.readAsBytes();
      decoded = ext == '.tif' || ext == '.tiff'
          ? img.decodeTiff(bytes)
          : img.decodeImage(bytes);
    } catch (e) {
      throw RasterImportException('Не удалось декодировать: $e');
    }
    if (decoded == null) {
      throw const RasterImportException(
        'Файл повреждён или использует неподдерживаемую кодировку.',
      );
    }

    final width = decoded.width;
    final height = decoded.height;

    // Decide tiling based on the DECODED dimensions. The earlier
    // `quickDims`-driven branch was skipped for TIFF (probe returns
    // null), so this is where large TIFFs actually get recognised
    // and sliced. Without this recheck a 12 k × 13 k GeoTIFF
    // previously ended up as one giant PNG — fine on disk but
    // down-sampled to ~4096 on its way to the GPU, which is what
    // the user was seeing as "мыло".
    final needsTiling =
        width > _tileThreshold || height > _tileThreshold;

    if (!needsTiling) {
      // Small TIFF — transcode to a single PNG.
      final png = img.encodePng(decoded);
      final dest = File(p.join(layersDir.path, '${uuid}_$baseName.png'));
      await dest.writeAsBytes(png, flush: true);
      return _IngestResult(path: dest.path, width: width, height: height);
    }

    // Large raster — tile it.
    final grid = await _writeTileGrid(
      srcImage: decoded,
      outDirName: '${uuid}_$baseName.tiled',
      layersDir: layersDir,
    );
    return _IngestResult(
      path: p.join(layersDir.path, '${uuid}_$baseName.tiled'),
      width: width,
      height: height,
      tileGrid: grid,
    );
  }

  /// Walk the decoded image column-by-column and save each tile as a
  /// PNG inside `<layersDir>/<outDirName>/r{row}_c{col}.png`. Last
  /// column / last row may be narrower / shorter than the nominal
  /// `_tileThreshold` — the grid stores the nominal size so the
  /// renderer can reconstruct sub-bounds without reading each tile's
  /// dimensions.
  static Future<LayerTileGrid> _writeTileGrid({
    required img.Image srcImage,
    required String outDirName,
    required Directory layersDir,
  }) async {
    final dir = Directory(p.join(layersDir.path, outDirName));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    final tileSize = _tileThreshold;
    final cols = (srcImage.width / tileSize).ceil();
    final rows = (srcImage.height / tileSize).ceil();

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = c * tileSize;
        final y = r * tileSize;
        final w = math.min(tileSize, srcImage.width - x);
        final h = math.min(tileSize, srcImage.height - y);
        final tile = img.copyCrop(srcImage, x: x, y: y, width: w, height: h);
        final pngBytes = img.encodePng(tile);
        final tileFile = File(p.join(dir.path, 'r${r}_c$c.png'));
        await tileFile.writeAsBytes(pngBytes, flush: true);
      }
    }

    return LayerTileGrid(
      rows: rows,
      cols: cols,
      tileWidth: tileSize,
      tileHeight: tileSize,
      srcWidth: srcImage.width,
      srcHeight: srcImage.height,
    );
  }

  /// Full import pipeline for a Garmin `.jnx` file. Unlike the
  /// JPG/TIF/PNG paths this one does NOT look for a world-file —
  /// coordinates are embedded per tile. We stream each JPEG payload
  /// straight from the source buffer to disk as its own file, build
  /// a [LayerTileMosaic] that pairs each file with its lat/lng
  /// rectangle, and let the overlay renderer compose them at draw
  /// time.
  ///
  /// Critically, this path NEVER materialises a stitched full-scan
  /// canvas. Peak memory is a single JPEG payload (≈ 50 – 200 KB)
  /// plus the file bytes we'd already loaded, which keeps the
  /// importer viable on low-heap Android devices where the previous
  /// "decode-then-stitch-then-tile" strategy crashed with OOM.
  static Future<RasterImportResult> _importJnx(
    File src,
    String sourcePath,
  ) async {
    final JnxPlan? plan;
    try {
      plan = await JnxReader.read(src);
    } on JnxReadException catch (e) {
      throw RasterImportException(e.message);
    } catch (e) {
      throw RasterImportException('Не удалось разобрать JNX: $e');
    }
    if (plan == null) {
      throw const RasterImportException(
        'Файл JNX не содержит тайлов либо повреждён.',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final layersDir = Directory(p.join(dir.path, 'layers'));
    if (!await layersDir.exists()) {
      await layersDir.create(recursive: true);
    }
    final uuid = const Uuid().v4();
    final baseName = p
        .basenameWithoutExtension(src.path)
        .replaceAll(RegExp(r'[^\w\-]'), '_');

    // Dedicated directory for this layer — one JPEG file per tile.
    final layerDir = Directory(
      p.join(layersDir.path, '${uuid}_$baseName.mosaic'),
    );
    if (await layerDir.exists()) {
      await layerDir.delete(recursive: true);
    }
    await layerDir.create(recursive: true);

    final tileEntries = <MosaicTile>[];
    // Tight union of all tile bounds — the JNX header bbox typically
    // reserves extra margin around the actual scan, so using it for
    // the overlay's overall bbox places the corner handles noticeably
    // outside the visible raster. The tile union snaps handles to
    // the real coverage.
    var unionN = -90.0;
    var unionS = 90.0;
    var unionW = 180.0;
    var unionE = -180.0;
    for (var i = 0; i < plan.tiles.length; i++) {
      final tile = plan.tiles[i];
      // `jpegBytesFor` returns a view into the file buffer when the
      // tile already has an SOI marker, or a small prefix+view copy
      // when it doesn't. Either way memory stays bounded per iter.
      final jpeg = plan.jpegBytesFor(tile);
      final fileName = 'tile_$i.jpg';
      final outFile = File(p.join(layerDir.path, fileName));
      await outFile.writeAsBytes(jpeg, flush: true);
      tileEntries.add(MosaicTile(file: fileName, bounds: tile.bounds));
      if (tile.bounds.northLat > unionN) unionN = tile.bounds.northLat;
      if (tile.bounds.southLat < unionS) unionS = tile.bounds.southLat;
      if (tile.bounds.westLng < unionW) unionW = tile.bounds.westLng;
      if (tile.bounds.eastLng > unionE) unionE = tile.bounds.eastLng;
    }

    final bounds = tileEntries.isEmpty
        ? plan.bounds
        : LayerBounds(
            northLat: unionN,
            southLat: unionS,
            westLng: unionW,
            eastLng: unionE,
          );
    final latSpan = bounds.northLat - bounds.southLat;
    final lngSpan = bounds.eastLng - bounds.westLng;
    String? warning;
    if (latSpan > 20 || lngSpan > 40) {
      warning =
          'JNX охватывает $latSpan° × $lngSpan° — очень крупная '
          'область, загрузка может занять время.';
    }

    return RasterImportResult(
      layer: MapLayer(
        id: const Uuid().v4(),
        name: p.basenameWithoutExtension(sourcePath),
        type: MapLayerType.imageOverlay,
        source: layerDir.path,
        tileMosaic: LayerTileMosaic(tiles: tileEntries),
        bounds: bounds,
        description:
            'JNX · ${tileEntries.length} тайлов · '
            '${bounds.northLat.toStringAsFixed(3)}°N '
            '${bounds.westLng.toStringAsFixed(3)}°E — '
            '${bounds.southLat.toStringAsFixed(3)}°N '
            '${bounds.eastLng.toStringAsFixed(3)}°E',
      ),
      kind: RasterImportKind.georeferencedRaster,
      warning: warning,
    );
  }

  /// Probe dimensions without a full decode. Returns null for formats
  /// we don't header-parse (TIFF) — the caller then does a full decode
  /// and reads dimensions from the decoded image.
  static Future<_Dimensions?> _probeDimensions(File src, String ext) async {
    if (ext == '.png') return _pngDimensions(src);
    if (ext == '.jpg' || ext == '.jpeg') return _jpegDimensions(src);
    return null; // TIFF: need full decode anyway.
  }

  /// Read width/height from a raster file WITHOUT decoding the full
  /// pixel buffer. For a 24 MB JPEG the difference is seconds vs.
  /// milliseconds — the old full-decode path is what made the
  /// "Привязать скан" flow feel frozen.
  ///
  /// The parser walks:
  ///   * PNG: first chunk is IHDR with width/height at bytes 16-23.
  ///   * JPEG: SOI + segments until an SOFn marker, which carries
  ///     height @ offset 5 and width @ offset 7 (big-endian 16-bit).
  ///
  /// PNG signature is 8 bytes, then the IHDR chunk starts immediately:
  ///   chunk length (4), chunk type "IHDR" (4), width (4), height (4).
  /// So the first 24 bytes of the file are enough.
  static Future<_Dimensions?> _pngDimensions(File f) async {
    final raf = await f.open();
    try {
      if (raf.lengthSync() < 24) return null;
      final head = await raf.read(24);
      // Verify PNG magic + IHDR signature.
      const pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      for (var i = 0; i < 8; i++) {
        if (head[i] != pngMagic[i]) return null;
      }
      if (head[12] != 0x49 ||
          head[13] != 0x48 ||
          head[14] != 0x44 ||
          head[15] != 0x52) {
        return null; // "IHDR"
      }
      final width = (head[16] << 24) |
          (head[17] << 16) |
          (head[18] << 8) |
          head[19];
      final height = (head[20] << 24) |
          (head[21] << 16) |
          (head[22] << 8) |
          head[23];
      return _Dimensions(width, height);
    } finally {
      await raf.close();
    }
  }

  /// Scan JPEG segments until we hit an SOFn marker (Start Of Frame).
  /// Those carry height @ offset 5 and width @ offset 7 (big-endian).
  /// Skips over APP/COM/quantization segments without reading payload.
  static Future<_Dimensions?> _jpegDimensions(File f) async {
    final raf = await f.open();
    try {
      if (raf.lengthSync() < 4) return null;
      // Check SOI (Start Of Image) marker FFD8.
      final soi = await raf.read(2);
      if (soi[0] != 0xFF || soi[1] != 0xD8) return null;

      while (true) {
        // Marker begins with 0xFF; stuff bytes (extra FFs) may appear.
        final pair = await raf.read(2);
        if (pair.length < 2) return null;
        if (pair[0] != 0xFF) return null;
        var marker = pair[1];
        while (marker == 0xFF) {
          final b = await raf.read(1);
          if (b.isEmpty) return null;
          marker = b[0];
        }
        // SOFn markers: 0xC0..0xCF except 0xC4 (DHT), 0xC8 (JPG ext),
        // 0xCC (DAC). The rest carry width/height in a fixed layout.
        if (marker >= 0xC0 &&
            marker <= 0xCF &&
            marker != 0xC4 &&
            marker != 0xC8 &&
            marker != 0xCC) {
          // segment = length(2) + precision(1) + height(2) + width(2).
          final seg = await raf.read(7);
          if (seg.length < 7) return null;
          final height = (seg[3] << 8) | seg[4];
          final width = (seg[5] << 8) | seg[6];
          return _Dimensions(width, height);
        }
        // SOI/EOI/RSTn markers have no payload — shouldn't hit mid-scan.
        if (marker == 0xD8 || marker == 0xD9 ||
            (marker >= 0xD0 && marker <= 0xD7)) {
          return null;
        }
        // Everything else: read segment length (includes the 2 length
        // bytes themselves) and skip the payload.
        final lenBytes = await raf.read(2);
        if (lenBytes.length < 2) return null;
        final segLen = ((lenBytes[0] << 8) | lenBytes[1]) - 2;
        if (segLen < 0) return null;
        await raf.setPosition(raf.positionSync() + segLen);
      }
    } finally {
      await raf.close();
    }
  }
}

class RasterImportException implements Exception {
  const RasterImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _Dimensions {
  _Dimensions(this.width, this.height);
  final int width;
  final int height;
}

/// Result of [RasterImporter._ingestRaster]. The raster now lives on
/// disk at [path] (file for small rasters, directory of PNG tiles for
/// large ones). [width] and [height] are always the SOURCE pixel
/// dimensions — not tile-local — so downstream world-file math can
/// treat the raster as one logical image regardless of how it was
/// stored. [tileGrid] is non-null iff the raster was sliced.
class _IngestResult {
  const _IngestResult({
    required this.path,
    required this.width,
    required this.height,
    this.tileGrid,
  });
  final String path;
  final int width;
  final int height;
  final LayerTileGrid? tileGrid;
}
