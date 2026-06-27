import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Persistent, never-evicting disk cache for online raster tiles.
///
/// The base map (OSM / ArcGIS satellite / OpenTopoMap / CartoDB) and any
/// user-added XYZ layer stream tiles from the network. Flutter's built-in
/// [ImageCache] only keeps decoded tiles in RAM — it is cleared on memory
/// pressure and lost on every cold start, so the same area re-downloads
/// each session and shows nothing at all when offline.
///
/// This store writes every successfully fetched tile into a single SQLite
/// file under `<app-documents>/tilecache/tiles.db`. Once a tile has been
/// seen online it is served from disk forever — the field user can open
/// the app with no signal and still see everywhere they have already
/// browsed.
///
/// Design notes:
///  * **No automatic eviction.** Per the product requirement, tiles are
///    kept indefinitely ("загрузили один раз — работает без интернета").
///    The user can wipe the cache manually from Settings → Данные.
///  * **Keyed by `(source, z, x, y)`** where `source` is the layer's URL
///    *template* (with `{s}`/`{x}`… unsubstituted). Keying on the template
///    rather than the resolved URL means subdomain rotation (a./b./c.)
///    never fragments the cache, and styles that share an endpoint
///    (satellite + hybrid both use Esri World_Imagery) automatically share
///    stored tiles.
///  * **Best-effort.** Every method swallows its own errors and degrades
///    to "no cache" so a corrupt DB or a full disk can never break map
///    rendering — a miss simply falls through to the network.
class TileCacheStore {
  TileCacheStore._();

  /// App-wide singleton — one SQLite handle kept warm for the whole
  /// session (matches how [LayersService] keeps MBTiles handles open).
  static final TileCacheStore instance = TileCacheStore._();

  static const _fileName = 'tiles.db';
  static const _folderName = 'tilecache';

  Database? _db;
  Completer<Database>? _opening;

  /// Open (once) and return the shared database. Concurrent callers during
  /// the first open all await the same [Completer] instead of racing to
  /// create the file.
  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final pending = _opening;
    if (pending != null) return pending.future;

    final completer = Completer<Database>();
    _opening = completer;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, _folderName));
      if (!await folder.exists()) await folder.create(recursive: true);
      final path = p.join(folder.path, _fileName);

      final db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE tiles (
              source TEXT NOT NULL,
              z INTEGER NOT NULL,
              x INTEGER NOT NULL,
              y INTEGER NOT NULL,
              bytes BLOB NOT NULL,
              fetched_at INTEGER NOT NULL,
              PRIMARY KEY (source, z, x, y)
            )
          ''');
        },
      );
      // WAL lets tile reads proceed while a write is in flight — important
      // because a fast pan fires dozens of reads + writes at once.
      try {
        await db.execute('PRAGMA journal_mode=WAL');
      } catch (_) {/* not fatal — default rollback journal still works */}

      _db = db;
      completer.complete(db);
      return db;
    } catch (e) {
      // Let the next caller retry the open instead of caching the failure.
      _opening = null;
      completer.completeError(e);
      rethrow;
    }
  }

  /// Return the cached bytes for a tile, or null on miss / any error.
  Future<Uint8List?> get(String source, int z, int x, int y) async {
    try {
      final db = await _open();
      final rows = await db.query(
        'tiles',
        columns: ['bytes'],
        where: 'source = ? AND z = ? AND x = ? AND y = ?',
        whereArgs: [source, z, x, y],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final blob = rows.first['bytes'];
      if (blob is Uint8List) return blob;
      if (blob is List<int>) return Uint8List.fromList(blob);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Return the set of `"x_y"` keys already cached for [source] at zoom [z]
  /// within the tile-index rectangle. Lets the prefetcher skip what it
  /// already has in one query instead of N point lookups.
  Future<Set<String>> existingKeys(
    String source,
    int z,
    int minX,
    int maxX,
    int minY,
    int maxY,
  ) async {
    try {
      final db = await _open();
      final rows = await db.query(
        'tiles',
        columns: ['x', 'y'],
        where: 'source = ? AND z = ? AND x >= ? AND x <= ? AND y >= ? AND y <= ?',
        whereArgs: [source, z, minX, maxX, minY, maxY],
      );
      return {for (final r in rows) '${r['x']}_${r['y']}'};
    } catch (_) {
      return <String>{};
    }
  }

  /// Store a freshly-downloaded tile. Fire-and-forget from the caller's
  /// point of view — failures are swallowed so a write error never blocks
  /// the tile from being displayed.
  Future<void> put(String source, int z, int x, int y, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    try {
      final db = await _open();
      await db.insert(
        'tiles',
        {
          'source': source,
          'z': z,
          'x': x,
          'y': y,
          'bytes': bytes,
          'fetched_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {/* best effort */}
  }

  /// Approximate on-disk size of all cached tiles, in bytes (sum of blob
  /// lengths — close enough for a "Кеш: 42 МБ" readout).
  Future<int> sizeBytes() async {
    try {
      final db = await _open();
      final rows = await db
          .rawQuery('SELECT COALESCE(SUM(LENGTH(bytes)), 0) AS s FROM tiles');
      return Sqflite.firstIntValue(rows) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Number of tiles currently cached.
  Future<int> count() async {
    try {
      final db = await _open();
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM tiles');
      return Sqflite.firstIntValue(rows) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Wipe the whole cache (or just one [source] when provided) and reclaim
  /// the freed disk space. Used by the manual "очистить кеш" action.
  Future<void> clear({String? source}) async {
    try {
      final db = await _open();
      if (source == null) {
        await db.delete('tiles');
      } else {
        await db.delete('tiles', where: 'source = ?', whereArgs: [source]);
      }
      // Shrink the file back down — otherwise the DB keeps its high-water
      // mark and "Кеш: 0 МБ" would still occupy hundreds of MB on disk.
      try {
        await db.execute('VACUUM');
      } catch (_) {/* VACUUM can fail under WAL+open cursors — non-fatal */}
    } catch (_) {/* best effort */}
  }
}
