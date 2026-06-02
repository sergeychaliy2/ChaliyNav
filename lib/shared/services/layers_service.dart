import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/map_layer.dart';

/// Resolves a MapLayer into a runtime TileProvider usable by flutter_map.
/// Handles XYZ URLs (network) and MBTiles (local file).
class LayersService {
  LayersService._();

  /// Global cache of MBTiles providers keyed by file path.
  ///
  /// Without this, every toggle-off / toggle-on of an MBTiles layer
  /// disposed the underlying [MbTilesTileProvider], which closed its
  /// SQLite connection — so the next toggle-on had to reopen the file,
  /// warm the page cache and re-index, taking ~10-15 seconds on a
  /// 100 MB offline pack. By keeping a singleton provider per file we
  /// keep the DB open for the lifetime of the app and toggling becomes
  /// instant.
  static final Map<String, MbTilesTileProvider> _mbtilesCache = {};

  /// Build a [TileLayer] for a given [MapLayer]. Returns null for types that
  /// are not implemented yet (ozf2, zmp, vector).
  static Future<TileLayer?> buildTileLayer(MapLayer layer) async {
    switch (layer.type) {
      case MapLayerType.tileUrl:
        return TileLayer(
          urlTemplate: layer.source,
          userAgentPackageName: 'com.chaliy.nav',
          maxNativeZoom: layer.maxZoom.round(),
        );

      case MapLayerType.mbtiles:
        final file = File(layer.source);
        if (!await file.exists()) {
          // File is gone — invalidate a stale cache entry if any.
          _mbtilesCache.remove(layer.source);
          return null;
        }
        final provider = _mbtilesCache.putIfAbsent(
          layer.source,
          () => MbTilesTileProvider.fromPath(path: file.path),
        );
        return TileLayer(
          tileProvider: provider,
          maxNativeZoom: layer.maxZoom.round(),
          userAgentPackageName: 'com.chaliy.nav',
        );

      case MapLayerType.sqlitedb:
      case MapLayerType.wms:
      case MapLayerType.ozf2:
      case MapLayerType.zmp:
      case MapLayerType.vector:
      case MapLayerType.imageOverlay:
        // imageOverlay is rendered via OverlayImageLayer, not TileLayer.
        return null;
    }
  }

  /// Drop a cached MBTiles provider — call when the underlying file is
  /// being deleted (so subsequent reads don't use a dangling handle).
  static void invalidateMbtilesCache(String sourcePath) {
    _mbtilesCache.remove(sourcePath);
  }

  /// Copy a picked file into the app's private storage so it survives after
  /// the user deletes the original. Returns the destination path.
  static Future<String> importFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final layersDir = Directory(p.join(dir.path, 'layers'));
    if (!await layersDir.exists()) {
      await layersDir.create(recursive: true);
    }
    final fileName = p.basename(sourcePath);
    final dest = File(p.join(layersDir.path, '${const Uuid().v4()}_$fileName'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  /// Sniff a file path / URL and pick the most likely MapLayerType.
  static MapLayerType detectType(String pathOrUrl) {
    final lower = pathOrUrl.toLowerCase();
    if (lower.endsWith('.mbtiles')) return MapLayerType.mbtiles;
    if (lower.endsWith('.sqlitedb')) return MapLayerType.sqlitedb;
    if (lower.endsWith('.ozf2')) return MapLayerType.ozf2;
    if (lower.endsWith('.zmp')) return MapLayerType.zmp;
    if (lower.startsWith('http')) return MapLayerType.tileUrl;
    return MapLayerType.tileUrl;
  }
}
