import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tile_cache_store.dart';

/// Live state of a manual "download this area" job, watched by the map HUD.
@immutable
class AreaDownloadState {
  const AreaDownloadState({this.active = false, this.done = 0, this.total = 0});

  final bool active;
  final int done;
  final int total;

  double get progress => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  AreaDownloadState copyWith({bool? active, int? done, int? total}) =>
      AreaDownloadState(
        active: active ?? this.active,
        done: done ?? this.done,
        total: total ?? this.total,
      );
}

final areaDownloadProvider =
    NotifierProvider<AreaDownloader, AreaDownloadState>(AreaDownloader.new);

/// Manual, user-initiated "save this area offline" downloader.
///
/// Unlike a per-pan auto-prefetch (which got the app IP-blocked by OSM),
/// this only runs when the user taps "Download area" and confirms. It
/// writes straight into [TileCacheStore] — the SAME store the base map
/// reads — keyed per style URL, so afterwards the user just switches
/// schema/satellite/hybrid as usual and the cached tiles appear offline.
/// No separate layer is created.
///
/// It only fetches tiles that are MISSING from the cache (incremental: a
/// second download over an overlapping area grabs just the gaps), is gentle
/// on tile servers (low concurrency + subdomain rotation + identifiable
/// UA), and is cancellable mid-run.
class AreaDownloader extends Notifier<AreaDownloadState> {
  @override
  AreaDownloadState build() => const AreaDownloadState();

  // Higher than the old auto-prefetch (which had to be timid): this only
  // runs on an explicit tap. Subdomain rotation spreads OSM across a/b/c
  // (~3 per host), and CDN sources (Esri satellite, CARTO) handle this
  // easily. The semaphore guards only the network fetch — writes are
  // batched separately — so the slots churn at network speed.
  static const _concurrency = 8;

  /// Tiles persisted per SQLite transaction. One commit per chunk instead
  /// of one per tile is the big win for download speed.
  static const _chunkSize = 64;

  bool _cancelled = false;
  bool _running = false;
  int _subdomainCursor = 0;

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.bytes,
      headers: {
        'User-Agent':
            'ChaliyNav/1.0 (offline field-gis app; +https://github.com)',
        'Referer': 'https://chaliy.nav/',
        'Accept': 'image/*,*/*;q=0.8',
      },
      validateStatus: (code) => code != null && code > 0,
    ),
  );

  bool get isRunning => _running;

  /// How many tiles a download with these parameters would actually fetch
  /// (i.e. tiles not already in the cache). Used by the confirm sheet to
  /// show "N new tiles" and to disable the button when nothing is missing.
  Future<int> countMissing({
    required List<String> sources,
    required double north,
    required double south,
    required double west,
    required double east,
    required int minZoom,
    required int maxZoom,
  }) async {
    var count = 0;
    for (final src in sources.toSet()) {
      for (var z = minZoom; z <= maxZoom; z++) {
        final (loX, hiX, loY, hiY) = _tileRange(north, south, west, east, z);
        final have = await TileCacheStore.instance
            .existingKeys(src, z, loX, hiX, loY, hiY);
        count += (hiX - loX + 1) * (hiY - loY + 1) - have.length;
      }
    }
    return count;
  }

  /// Download every missing tile for [sources] over the rectangle across
  /// [minZoom]..[maxZoom] into [TileCacheStore]. No-op if one is already
  /// running. Progress streams through [areaDownloadProvider].
  Future<void> download({
    required List<String> sources,
    required double north,
    required double south,
    required double west,
    required double east,
    required int minZoom,
    required int maxZoom,
  }) async {
    if (_running) return;
    _running = true;
    _cancelled = false;
    try {
      final srcs = sources.toSet().toList();

      // Build the missing-tile work list.
      final missing = <_Tile>[];
      for (final src in srcs) {
        for (var z = minZoom; z <= maxZoom; z++) {
          if (_cancelled) return;
          final (loX, hiX, loY, hiY) = _tileRange(north, south, west, east, z);
          final have = await TileCacheStore.instance
              .existingKeys(src, z, loX, hiX, loY, hiY);
          for (var x = loX; x <= hiX; x++) {
            for (var y = loY; y <= hiY; y++) {
              if (!have.contains('${x}_$y')) missing.add(_Tile(src, z, x, y));
            }
          }
        }
      }
      if (missing.isEmpty || _cancelled) return;

      state = AreaDownloadState(active: true, done: 0, total: missing.length);

      var done = 0;
      // Process in chunks: fetch a chunk concurrently (network only), then
      // persist the whole chunk in a single transaction.
      for (var i = 0; i < missing.length; i += _chunkSize) {
        if (_cancelled) break;
        final end = math.min(i + _chunkSize, missing.length);
        final chunk = missing.sublist(i, end);

        final fetched =
            <({String source, int z, int x, int y, Uint8List bytes})>[];
        final futures = <Future<void>>[];
        final sem = _Semaphore(_concurrency);
        for (final t in chunk) {
          if (_cancelled) break;
          await sem.acquire();
          if (_cancelled) {
            sem.release();
            break;
          }
          futures.add(() async {
            try {
              final bytes = await _fetch(t);
              if (bytes != null && bytes.isNotEmpty) {
                fetched
                    .add((source: t.source, z: t.z, x: t.x, y: t.y, bytes: bytes));
              }
            } finally {
              sem.release();
            }
          }());
        }
        await Future.wait(futures);

        // One transaction for the whole chunk — the speed win.
        await TileCacheStore.instance.putBatch(fetched);

        done += chunk.length;
        state = state.copyWith(done: done);
      }
    } finally {
      _running = false;
      state = const AreaDownloadState();
    }
  }

  void cancel() => _cancelled = true;

  /// Fetch a single tile over the network. Returns the bytes, or null on any
  /// error or a non-2xx response (so an OSM "blocked" page is never cached
  /// and can't end up shown offline). The caller batches the writes.
  Future<Uint8List?> _fetch(_Tile t) async {
    try {
      final url = _rewriteUrl(t.source)
          .replaceAll('{z}', '${t.z}')
          .replaceAll('{x}', '${t.x}')
          .replaceAll('{y}', '${t.y}');
      final res = await _dio.get<Uint8List>(url);
      final code = res.statusCode ?? 0;
      final bytes = res.data;
      if (code >= 200 && code < 300 && bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
    } catch (_) {
      // Best effort — a failed tile is simply left out; live browsing or a
      // later re-download can fill it.
    }
    return null;
  }

  /// OSM / OpenTopoMap throttle the bare host — spread across the a./b./c.
  /// subdomain pool (same as DownloadManager).
  String _rewriteUrl(String template) {
    final letter = ['a', 'b', 'c'][_subdomainCursor];
    _subdomainCursor = (_subdomainCursor + 1) % 3;
    if (template.contains('://tile.openstreetmap.org/')) {
      return template.replaceFirst(
          '://tile.openstreetmap.org/', '://$letter.tile.openstreetmap.org/');
    }
    if (template.contains('://tile.opentopomap.org/')) {
      return template.replaceFirst(
          '://tile.opentopomap.org/', '://$letter.tile.opentopomap.org/');
    }
    return template;
  }

  /// Inclusive XYZ tile-index rectangle (loX,hiX,loY,hiY) covering the
  /// lat/lng box at zoom [z].
  static (int, int, int, int) _tileRange(
      double north, double south, double west, double east, int z) {
    final (minX, minY) = _lngLatToTile(north, west, z);
    final (maxX, maxY) = _lngLatToTile(south, east, z);
    return (
      math.min(minX, maxX),
      math.max(minX, maxX),
      math.min(minY, maxY),
      math.max(minY, maxY),
    );
  }

  // Web-Mercator lat/lng → XYZ tile index (standard slippy, y from north) —
  // matches the keys flutter_map (and the base layer's cache) use.
  static (int, int) _lngLatToTile(double lat, double lng, int z) {
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

class _Tile {
  const _Tile(this.source, this.z, this.x, this.y);
  final String source;
  final int z, x, y;
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
    if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
  }
}
