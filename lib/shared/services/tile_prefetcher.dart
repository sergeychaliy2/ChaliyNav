import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tile_cache_store.dart';

/// Live state of the background tile prefetch, watched by the map HUD so
/// the user can see (and that data is being used) when an area is being
/// saved for offline.
@immutable
class TilePrefetchState {
  const TilePrefetchState({
    this.active = false,
    this.done = 0,
    this.total = 0,
  });

  /// A prefetch run is currently downloading.
  final bool active;

  /// Tiles fetched so far in the current run.
  final int done;

  /// Tiles that needed fetching in the current run (missing from cache).
  final int total;

  double get progress => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  TilePrefetchState copyWith({bool? active, int? done, int? total}) =>
      TilePrefetchState(
        active: active ?? this.active,
        done: done ?? this.done,
        total: total ?? this.total,
      );
}

final tilePrefetchProvider =
    NotifierProvider<TilePrefetcher, TilePrefetchState>(TilePrefetcher.new);

/// Background "download what I'm looking at" service.
///
/// Given a geographic rectangle (the current map viewport) and a zoom
/// range, it downloads every *missing* tile in that box across those zooms
/// into [TileCacheStore] — the same store the base map reads from — so the
/// area later works offline at full detail instead of a blurry upscale.
///
/// It is deliberately gentle on public tile servers (low concurrency +
/// OSM-style subdomain rotation, mirroring [DownloadManager]) and caps how
/// much a single run will fetch so one pan can't kick off a huge download.
class TilePrefetcher extends Notifier<TilePrefetchState> {
  @override
  TilePrefetchState build() => const TilePrefetchState();

  // Gentle on tile servers — same rationale as DownloadManager.
  static const _concurrency = 3;

  // Safety ceiling per run: if the requested box+zooms would need more than
  // this many *new* tiles, the deepest zoom levels are dropped until it
  // fits. Stops a single viewport at z19 from queuing thousands of tiles.
  static const _maxTilesPerRun = 1800;

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

  /// The latest requested area. Set on every [request]; the running loop
  /// picks it up and a *newer* request supersedes an in-flight one (so we
  /// don't waste bandwidth finishing a box the user already panned away
  /// from). Single active loop — no overlapping downloads.
  _PrefetchReq? _pending;
  bool _running = false;

  /// Queue (or replace) a prefetch of one or more [sources] (URL templates,
  /// e.g. several base-map styles) over the rectangle across
  /// [minZoom]..[maxZoom]. Returns immediately; progress flows through
  /// [tilePrefetchProvider]. Cheap to call repeatedly — already-cached
  /// tiles are skipped, so re-requesting an overlapping area is mostly a
  /// few index lookups. Duplicate source URLs are collapsed (satellite and
  /// hybrid share the same Esri endpoint).
  void request({
    required List<String> sources,
    required double north,
    required double south,
    required double west,
    required double east,
    required int minZoom,
    required int maxZoom,
  }) {
    final deduped = sources.toSet().toList();
    if (deduped.isEmpty) return;
    final lo = minZoom.clamp(3, 19);
    final hi = maxZoom.clamp(3, 19);
    _pending = _PrefetchReq(
      sources: deduped,
      north: north,
      south: south,
      west: west,
      east: east,
      minZoom: math.min(lo, hi),
      maxZoom: math.max(lo, hi),
    );
    if (_running) return;
    _running = true;
    // ignore: unawaited_futures
    _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final req = _pending!;
        _pending = null;
        await _run(req);
      }
    } finally {
      _running = false;
      state = const TilePrefetchState();
    }
  }

  Future<void> _run(_PrefetchReq req) async {
    // Collect missing tiles across every requested source and zoom,
    // dropping the deepest zooms if we blow the per-run cap. Deepest-first
    // drop keeps the cheap wide-area low zooms across all styles.
    final missing = <_Tile>[];
    var maxZoom = req.maxZoom;
    while (maxZoom >= req.minZoom) {
      missing.clear();
      for (final src in req.sources) {
        for (var z = req.minZoom; z <= maxZoom; z++) {
          // A newer viewport arrived — abandon this stale run immediately.
          if (_pending != null) return;
          final (minX, minY) = _lngLatToTile(req.north, req.west, z);
          final (maxX, maxY) = _lngLatToTile(req.south, req.east, z);
          final loX = math.min(minX, maxX);
          final hiX = math.max(minX, maxX);
          final loY = math.min(minY, maxY);
          final hiY = math.max(minY, maxY);
          final have = await TileCacheStore.instance
              .existingKeys(src, z, loX, hiX, loY, hiY);
          for (var x = loX; x <= hiX; x++) {
            for (var y = loY; y <= hiY; y++) {
              if (!have.contains('${x}_$y')) missing.add(_Tile(src, z, x, y));
            }
          }
        }
      }
      if (missing.length <= _maxTilesPerRun) break;
      maxZoom--; // too big — drop the deepest level and recount
    }

    if (missing.isEmpty) {
      state = const TilePrefetchState();
      return;
    }

    state = TilePrefetchState(active: true, done: 0, total: missing.length);

    var done = 0;
    final futures = <Future<void>>[];
    final sem = _Semaphore(_concurrency);
    for (final t in missing) {
      if (_pending != null) break; // superseded mid-run
      await sem.acquire();
      if (_pending != null) {
        sem.release();
        break;
      }
      final fut = _fetchAndStore(t).then((_) {
        done++;
        // Throttle state updates — every 8 tiles is enough for a bar.
        if (done % 8 == 0 || done == missing.length) {
          state = state.copyWith(done: done);
        }
      }).whenComplete(sem.release);
      futures.add(fut);
    }
    await Future.wait(futures);
    // _drain() resets state to idle when the queue empties.
  }

  Future<void> _fetchAndStore(_Tile t) async {
    try {
      final url = _rewriteUrl(t.source)
          .replaceAll('{z}', '${t.z}')
          .replaceAll('{x}', '${t.x}')
          .replaceAll('{y}', '${t.y}');
      final res = await _dio.get<Uint8List>(url);
      final code = res.statusCode ?? 0;
      final bytes = res.data;
      if (code >= 200 && code < 300 && bytes != null && bytes.isNotEmpty) {
        await TileCacheStore.instance.put(t.source, t.z, t.x, t.y, bytes);
      }
    } catch (_) {
      // Best effort — a failed tile is simply left for live browsing to
      // fetch later. Never throw from a prefetch.
    }
  }

  /// OSM / OpenTopoMap throttle bulk traffic to the bare host — spread it
  /// across the a./b./c. subdomain pool (same as DownloadManager).
  String _rewriteUrl(String template) {
    final cursor = _subdomainCursor;
    _subdomainCursor = (_subdomainCursor + 1) % 3;
    final letter = ['a', 'b', 'c'][cursor];
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

  // Web-Mercator lat/lng → XYZ tile index (standard slippy, y from north).
  // Matches the keys flutter_map uses, so prefetched tiles are read back by
  // the live base layer without any TMS flip.
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

class _PrefetchReq {
  const _PrefetchReq({
    required this.sources,
    required this.north,
    required this.south,
    required this.west,
    required this.east,
    required this.minZoom,
    required this.maxZoom,
  });
  final List<String> sources;
  final double north, south, west, east;
  final int minZoom, maxZoom;
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
