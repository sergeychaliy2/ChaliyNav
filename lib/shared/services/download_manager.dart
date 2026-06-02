import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/download_task.dart';
import '../models/map_layer.dart';
import '../providers/layers_provider.dart';
import 'layers_service.dart';

/// Central registry of active and finished downloads. UI watches this.
final downloadManagerProvider =
    NotifierProvider<DownloadManager, List<DownloadTask>>(
  DownloadManager.new,
);

/// Offline tile downloader.
///
/// Plan:
///  1. Compute all tile coordinates inside a bbox at zooms [minZ..maxZ].
///  2. Open (or create) a sqlite file in MBTiles schema.
///  3. For each tile — download via dio, write the PNG blob into the DB.
///  4. Update progress via Riverpod state.
///
/// Simple, concurrent up to [_concurrency] requests. Caller can cancel.
class DownloadManager extends Notifier<List<DownloadTask>> {
  @override
  List<DownloadTask> build() => const [];

  // Lower concurrency (was 6) to be gentler on public tile servers —
  // OSM rate-limits aggressive clients, returning 429/403 for bulk
  // downloads from one IP. 3 is the sweet spot: tiles still stream
  // fast but we stay under the per-client limit.
  static const _concurrency = 3;

  // Round-robin index for OSM-style subdomain rotation (see _rewriteUrl).
  int _subdomainCursor = 0;

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.bytes,
      headers: {
        // OSM's tile usage policy requires a unique, identifiable UA.
        'User-Agent':
            'ChaliyNav/1.0 (offline field-gis app; +https://github.com)',
        // Some tile servers (retromap.ru, OWM) gate on Referer.
        'Referer': 'https://chaliy.nav/',
        'Accept': 'image/*,*/*;q=0.8',
      },
      // Don't throw on 4xx — we read statusCode below and count failures.
      validateStatus: (code) => code != null && code > 0,
    ),
  );

  final Map<String, _Cancel> _cancellations = {};

  /// Queue a new download for the given tile URL + bbox + zoom range.
  /// Returns the created task immediately; progress streams through state.
  Future<DownloadTask> enqueue({
    required String name,
    required String tileUrlTemplate,
    required double northLat,
    required double southLat,
    required double westLng,
    required double eastLng,
    required int minZoom,
    required int maxZoom,
    String? presetId,
  }) async {
    final total = countTiles(
      northLat: northLat,
      southLat: southLat,
      westLng: westLng,
      eastLng: eastLng,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    final task = DownloadTask(
      id: const Uuid().v4(),
      name: name,
      tileUrlTemplate: tileUrlTemplate,
      northLat: northLat,
      southLat: southLat,
      westLng: westLng,
      eastLng: eastLng,
      minZoom: minZoom,
      maxZoom: maxZoom,
      totalTiles: total,
      createdAt: DateTime.now(),
      presetId: presetId,
    );
    state = [...state, task];
    // Fire and forget — keeps UI responsive.
    // ignore: unawaited_futures
    _run(task);
    return task;
  }

  void cancel(String id) {
    _cancellations[id]?.cancelled = true;
    _update(id, (t) => t.copyWith(status: DownloadStatus.cancelled));
  }

  /// Fully remove a task: stop if running, delete the .mbtiles file, drop
  /// the linked user-layer entry, and remove from the queue list.
  Future<void> deleteTask(String id) async {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null) return;

    // Stop any active download first.
    _cancellations[id]?.cancelled = true;
    _cancellations.remove(id);

    // Delete the MBTiles file on disk (even for partial downloads).
    // First invalidate the shared provider cache so we're not fighting
    // an open SQLite handle when we try to unlink the file.
    final filePath = task.outputPath ?? await _dbPathFor(task);
    LayersService.invalidateMbtilesCache(filePath);
    try {
      final f = File(filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort — proceed to remove the state entry regardless.
    }

    // Remove the corresponding user layer (online or offline both live
    // under preset_<id> when sourced from a preset card).
    final layerId = task.presetId != null ? 'preset_${task.presetId}' : id;
    try {
      await ref.read(layersProvider.notifier).remove(layerId);
    } catch (_) {}

    // Finally drop the task from the state list.
    state = state.where((t) => t.id != id).toList();
  }

  /// Re-run a failed/cancelled/paused task, reusing the existing MBTiles
  /// file. `_downloadTile` checks the DB first and skips already-stored
  /// tiles, so a resume is idempotent and only fetches what's missing.
  Future<void> resume(String id) async {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null) return;
    // Only makes sense for non-running tasks.
    if (task.status == DownloadStatus.running ||
        task.status == DownloadStatus.queued) return;
    _update(id, (t) => t.copyWith(status: DownloadStatus.queued, error: null));
    // ignore: unawaited_futures
    _run(task);
  }

  /// Estimate how many tiles would be downloaded — used by the UI before
  /// starting, so the user can decide on the zoom range.
  static int countTiles({
    required double northLat,
    required double southLat,
    required double westLng,
    required double eastLng,
    required int minZoom,
    required int maxZoom,
  }) {
    int sum = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final (minX, minY) = _latLngToTile(northLat, westLng, z);
      final (maxX, maxY) = _latLngToTile(southLat, eastLng, z);
      final w = (maxX - minX).abs() + 1;
      final h = (maxY - minY).abs() + 1;
      sum += w * h;
    }
    return sum;
  }

  // === internal ===

  Future<void> _run(DownloadTask task) async {
    _update(task.id, (t) => t.copyWith(status: DownloadStatus.running));
    final cancel = _Cancel();
    _cancellations[task.id] = cancel;

    try {
      final path = await _openDb(task);
      final db = await openDatabase(path);
      await _initMbtiles(db, task);

      // Seed `done` from whatever is already in the MBTiles so a
      // resumed task doesn't re-count existing rows as new work.
      int done = await _existingTileCount(db);
      int failed = 0;
      String? firstErr;
      final futures = <Future<void>>[];
      final sem = _Semaphore(_concurrency);
      // Push initial count to the UI so a resumed task starts at the
      // already-stored percentage, not 0%.
      _update(task.id, (t) => t.copyWith(downloadedTiles: done));

      outer:
      for (var z = task.minZoom; z <= task.maxZoom; z++) {
        if (cancel.cancelled) break;
        final (minX, minY) = _latLngToTile(task.northLat, task.westLng, z);
        final (maxX, maxY) = _latLngToTile(task.southLat, task.eastLng, z);
        for (var x = math.min(minX, maxX); x <= math.max(minX, maxX); x++) {
          if (cancel.cancelled) break outer;
          for (var y = math.min(minY, maxY); y <= math.max(minY, maxY); y++) {
            if (cancel.cancelled) break outer;
            await sem.acquire();
            // Short-circuit: if the first ~20 attempts all failed and
            // we didn't already have partial progress from a prior run,
            // the endpoint is clearly rate-limiting or unreachable.
            // Stop firing requests and mark as PAUSED (not failed) so
            // the user can hit Resume when internet is back.
            if (failed >= 20 && done == 0) {
              sem.release();
              break outer;
            }
            final fut = _downloadTile(db, task, z, x, y).then((outcome) {
              if (outcome == _TileOutcome.downloaded) {
                done++;
              } else if (outcome == _TileOutcome.alreadyExists) {
                // Skipped — already in DB from a previous run. Not new
                // work, but also not a failure.
              } else {
                failed++;
              }
              if ((done + failed) % 10 == 0 ||
                  done == task.totalTiles) {
                _update(
                  task.id,
                  (t) => t.copyWith(downloadedTiles: done),
                );
              }
            }).catchError((e) {
              failed++;
              firstErr ??= e.toString();
            }).whenComplete(sem.release);
            futures.add(fut);
          }
        }
      }

      await Future.wait(futures);
      await db.close();

      if (cancel.cancelled) {
        _update(task.id, (t) => t.copyWith(status: DownloadStatus.cancelled));
        return;
      }

      // Short-circuited before any success — treat as paused so user can
      // retry, not as permanent failure. Preserves the partial mbtiles
      // file on disk for future resume.
      if (done == 0 && failed > 0) {
        _update(
          task.id,
          (t) => t.copyWith(
            status: DownloadStatus.paused,
            outputPath: path,
            error: firstErr != null
                ? 'Сервер отклонил загрузку: $firstErr. '
                    'Возможно ваш провайдер блокирует хост — попробуйте '
                    'с VPN и нажмите «Возобновить».'
                : 'Нет соединения с tile-сервером. Проверьте интернет '
                    'и нажмите «Возобновить».',
          ),
        );
        return;
      }

      // Completed (or stopped before reaching 100% but with some tiles
      // downloaded — still a working partial map).
      final isComplete = done + failed >= task.totalTiles;
      _update(
        task.id,
        (t) => t.copyWith(
          status: isComplete
              ? DownloadStatus.completed
              : DownloadStatus.paused,
          downloadedTiles: done,
          outputPath: path,
          error: isComplete
              ? (failed > 0 ? '$failed тайлов пропущено' : null)
              : 'Скачивание прервано. Нажмите «Возобновить» чтобы '
                  'докачать недостающие тайлы.',
        ),
      );

      // Only register a usable layer once the download is actually
      // complete. A paused/partial MBTiles stays on disk (so Resume
      // can pick up where we stopped), but is NOT exposed to the map —
      // addresses "почему я могу включить слой после неполной загрузки".
      if (!isComplete) return;

      // Register as user layer. Use preset_<id> when we came from a
      // preset card so the download REPLACES the online version in the
      // layer list (online → offline migration — one entry per preset).
      // Use `upsert` so re-downloading the same preset doesn't stack
      // duplicates.
      final layerId = task.presetId != null
          ? 'preset_${task.presetId}'
          : task.id;
      await ref.read(layersProvider.notifier).upsert(
            MapLayer(
              id: layerId,
              name: task.name,
              type: MapLayerType.mbtiles,
              source: path,
              description: 'Offline · ${task.minZoom}-${task.maxZoom} z',
              maxZoom: task.maxZoom.toDouble(),
              minZoom: task.minZoom.toDouble(),
            ),
          );
    } catch (e) {
      _update(
        task.id,
        (t) => t.copyWith(
          status: DownloadStatus.paused,
          error: 'Сбой: ${e.toString()}. Нажмите «Возобновить».',
        ),
      );
    } finally {
      _cancellations.remove(task.id);
    }
  }

  /// Count how many tiles are already stored — used on resume so the
  /// progress bar doesn't reset to 0.
  Future<int> _existingTileCount(Database db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM tiles');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Compute the path without creating the folder, for delete().
  Future<String> _dbPathFor(DownloadTask task) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'offline', '${task.id}.mbtiles');
  }

  Future<String> _openDb(DownloadTask task) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'offline'));
    if (!await folder.exists()) await folder.create(recursive: true);
    return p.join(folder.path, '${task.id}.mbtiles');
  }

  Future<void> _initMbtiles(Database db, DownloadTask task) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS metadata (name TEXT, value TEXT)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tiles (
        zoom_level INTEGER,
        tile_column INTEGER,
        tile_row INTEGER,
        tile_data BLOB,
        PRIMARY KEY (zoom_level, tile_column, tile_row)
      )
    ''');
    await db.insert('metadata', {'name': 'name', 'value': task.name},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('metadata', {'name': 'format', 'value': 'png'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('metadata', {
      'name': 'bounds',
      'value':
          '${task.westLng},${task.southLat},${task.eastLng},${task.northLat}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('metadata',
        {'name': 'minzoom', 'value': task.minZoom.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('metadata',
        {'name': 'maxzoom', 'value': task.maxZoom.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Fetch a single tile and store it.
  /// Returns:
  ///  - [_TileOutcome.alreadyExists] — the tile was already in the DB
  ///    (from a previous partial run). Skipped, no network hit.
  ///  - [_TileOutcome.downloaded]    — successfully fetched and stored.
  ///  - [_TileOutcome.empty]         — server returned empty body.
  /// Throws on HTTP errors so the caller can count them as failures.
  Future<_TileOutcome> _downloadTile(
    Database db,
    DownloadTask task,
    int z,
    int x,
    int y,
  ) async {
    final tmsY = ((1 << z) - 1) - y;

    // Skip if the tile is already stored — this makes resume fast and
    // idempotent. Only NEW tiles hit the network.
    final exists = await db.rawQuery(
      'SELECT 1 FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=? LIMIT 1',
      [z, x, tmsY],
    );
    if (exists.isNotEmpty) return _TileOutcome.alreadyExists;

    final url = _rewriteUrl(task.tileUrlTemplate)
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');

    final res = await _dio.get<Uint8List>(url);
    // OSM returns 429/403 as plaintext body when rate-limiting. Treat
    // any non-2xx as a failure so the short-circuit in _run() fires.
    final code = res.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'HTTP $code',
      );
    }
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return _TileOutcome.empty;

    await db.insert(
      'tiles',
      {
        'zoom_level': z,
        'tile_column': x,
        'tile_row': tmsY,
        'tile_data': bytes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return _TileOutcome.downloaded;
  }

  /// OSM (and a few other public servers) distribute load across
  /// subdomains a./b./c. — but the built-in presets use the bare
  /// `tile.openstreetmap.org` host, which the operators will throttle
  /// hard under bulk. Rewriting to the subdomain pool lets us slip
  /// under the per-host rate limit.
  String _rewriteUrl(String template) {
    final cursor = _subdomainCursor;
    _subdomainCursor = (_subdomainCursor + 1) % 3;
    final letter = ['a', 'b', 'c'][cursor];
    // `tile.openstreetmap.org` → `a.tile.openstreetmap.org`
    if (template.contains('://tile.openstreetmap.org/')) {
      return template.replaceFirst(
        '://tile.openstreetmap.org/',
        '://$letter.tile.openstreetmap.org/',
      );
    }
    // `tile.opentopomap.org` → `a.tile.opentopomap.org`
    if (template.contains('://tile.opentopomap.org/')) {
      return template.replaceFirst(
        '://tile.opentopomap.org/',
        '://$letter.tile.opentopomap.org/',
      );
    }
    return template;
  }

  void _update(String id, DownloadTask Function(DownloadTask) mutate) {
    state = [
      for (final t in state)
        if (t.id == id) mutate(t) else t,
    ];
  }

  // === tile math (Web Mercator) ===

  static (int, int) _latLngToTile(double lat, double lng, int z) {
    final latRad = lat * math.pi / 180.0;
    final n = 1 << z;
    final x = ((lng + 180) / 360 * n).floor();
    final y = ((1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            n)
        .floor();
    return (x.clamp(0, n - 1), y.clamp(0, n - 1));
  }
}

enum _TileOutcome {
  downloaded,
  alreadyExists,
  empty,
}

class _Cancel {
  bool cancelled = false;
}

class _Semaphore {
  _Semaphore(this._max);
  final int _max;
  int _active = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    if (_active < _max) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
    _active++;
  }

  void release() {
    _active--;
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }
}
