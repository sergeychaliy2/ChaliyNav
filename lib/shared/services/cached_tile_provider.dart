import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'tile_cache_store.dart';

/// A [TileProvider] that transparently persists every tile it fetches.
///
/// Drop-in replacement for flutter_map's [NetworkTileProvider] on any
/// online (XYZ) layer. For each tile it:
///   1. tries [TileCacheStore] on disk — instant, works fully offline;
///   2. on a miss, downloads over HTTP, displays it, and writes the bytes
///      back to the cache for next time.
///
/// The cache key is [sourceKey] (the layer's URL *template*) plus the tile
/// coordinates, so subdomain rotation and styles that share an endpoint do
/// not duplicate storage. See [TileCacheStore] for the persistence policy.
class CachedTileProvider extends TileProvider {
  CachedTileProvider({required this.sourceKey, super.headers});

  /// Stable identifier for the tile source — the URL template string.
  /// Tiles from the same template share one cache namespace.
  final String sourceKey;

  /// One HTTP client shared by every provider, kept open for the whole app
  /// lifetime.
  ///
  /// flutter_map disposes a [TileProvider] whenever its [TileLayer] leaves
  /// the tree — which happens routinely when a user toggles an XYZ overlay
  /// off ([UserLayersStack] removes the widget). Since that widget (and its
  /// provider) is reused on re-show, a per-provider client would be closed
  /// on the first hide and then fail every fetch afterwards. A shared,
  /// never-closed client sidesteps that entirely.
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.bytes,
      // Read the body for any status so we can distinguish a real tile from
      // a 4xx/5xx error page ourselves.
      validateStatus: (code) => code != null && code > 0,
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _CachedTileImageProvider(
        url: getTileUrl(coordinates, options),
        sourceKey: sourceKey,
        z: coordinates.z,
        x: coordinates.x,
        y: coordinates.y,
        headers: headers,
        dio: _dio,
      );

  // No dispose() override: the shared [_dio] intentionally outlives any
  // single provider instance (see above).
}

/// [ImageProvider] backing [CachedTileProvider]. Equality is by [url] only
/// (like flutter_map's network provider) so identical tiles share one entry
/// in the in-memory [ImageCache].
@immutable
class _CachedTileImageProvider extends ImageProvider<_CachedTileImageProvider> {
  const _CachedTileImageProvider({
    required this.url,
    required this.sourceKey,
    required this.z,
    required this.x,
    required this.y,
    required this.headers,
    required this.dio,
  });

  final String url;
  final String sourceKey;
  final int z;
  final int x;
  final int y;
  final Map<String, String> headers;
  final Dio dio;

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      MultiFrameImageStreamCompleter(
        codec: _load(key, decode),
        scale: 1,
        debugLabel: url,
        informationCollector: () => [
          DiagnosticsProperty('Tile URL', url),
          DiagnosticsProperty('Cache source', sourceKey),
          DiagnosticsProperty('Coords', 'z$z/$x/$y'),
        ],
      );

  Future<Codec> _load(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      // 1) Disk cache — the offline-first path.
      final cached = await TileCacheStore.instance.get(sourceKey, z, x, y);
      if (cached != null && cached.isNotEmpty) {
        return decode(await ImmutableBuffer.fromUint8List(cached));
      }

      // 2) Network — fetch, then persist for next time.
      final bytes = await _fetch();
      // Fire-and-forget write — never let a slow disk hold up display.
      unawaited(TileCacheStore.instance.put(sourceKey, z, x, y, bytes));
      return decode(await ImmutableBuffer.fromUint8List(bytes));
    } catch (err) {
      // Evict so flutter_map will retry the tile on the next pan instead of
      // pinning a permanent failure (same behaviour as the stock provider).
      scheduleMicrotask(
        () => PaintingBinding.instance.imageCache.evict(key),
      );
      rethrow;
    }
  }

  /// Download the tile, with one quick retry for flaky field connectivity.
  /// Throws on a non-2xx status or empty body so [_load] can evict + retry.
  Future<Uint8List> _fetch() async {
    Object? lastErr;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await dio.get<Uint8List>(
          url,
          options: Options(headers: headers, responseType: ResponseType.bytes),
        );
        final code = res.statusCode ?? 0;
        final data = res.data;
        if (code >= 200 && code < 300 && data != null && data.isNotEmpty) {
          return data;
        }
        lastErr = DioException(
          requestOptions: res.requestOptions,
          response: res,
          message: 'HTTP $code',
        );
      } on DioException catch (e) {
        lastErr = e;
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    throw lastErr ?? Exception('Tile fetch failed: $url');
  }

  @override
  SynchronousFuture<_CachedTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CachedTileImageProvider && url == other.url);

  @override
  int get hashCode => url.hashCode;
}
