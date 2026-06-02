import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/map_layer.dart';
import '../../../shared/services/layers_service.dart';
import 'sharp_overlay_image_layer.dart';

/// Resolves user-imported [MapLayer]s into the right flutter_map primitive
/// (TileLayer for XYZ/MBTiles, OverlayImageLayer for georeferenced scans)
/// and stacks them with per-layer opacity.
///
/// Rendering strategy:
///  * tileUrl (online) — only visible ones are mounted; toggling off
///    tears down the widget so we stop hitting the network.
///  * mbtiles (offline) — ALWAYS mounted, opacity-driven visibility.
///    Keeps the [MbTilesTileProvider]'s SQLite handle warm across
///    toggles → instant show/hide instead of 10-15 s reload.
///  * imageOverlay — mounted only when visible.
///
/// The resolution step (`LayersService.buildTileLayer`) is async because
/// it touches the filesystem once per new layer, but we avoid the classic
/// FutureBuilder flicker by caching results in our own State and only
/// re-running when the set of layers actually changes.
class UserLayersStack extends StatefulWidget {
  const UserLayersStack({super.key, required this.layers});

  final List<MapLayer> layers;

  @override
  State<UserLayersStack> createState() => _UserLayersStackState();
}

class _UserLayersStackState extends State<UserLayersStack> {
  /// TileLayer widget cache keyed by layer id — reuses the same Widget
  /// instance across rebuilds so flutter_map doesn't churn its State
  /// (and therefore doesn't dispose MbTilesTileProvider needlessly).
  final _cache = <String, TileLayer?>{};

  /// Resolved layers kept in state directly — NO FutureBuilder, so a
  /// rebuild doesn't briefly replace the stack with an empty one.
  List<_Resolved> _resolvedOnline = const [];
  List<_Resolved> _resolvedOffline = const [];

  /// Snapshot of the layer set that produced `_resolved*`; used to
  /// detect when a real re-resolve is needed (new/removed layers).
  String? _lastResolveSignature;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(covariant UserLayersStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Purge cache for layers that no longer exist so a delete-then-
    // re-import doesn't return the stale Widget.
    final currentIds = {for (final l in widget.layers) l.id};
    _cache.removeWhere((k, _) => !currentIds.contains(k));
    _resolveIfNeeded();
  }

  /// Compose a cheap fingerprint of the layers list — only `id`,
  /// `type` and `source` matter for whether a re-resolve is needed.
  /// Visibility/opacity changes use the cached Widget + new Opacity
  /// wrapper, no resolve required.
  String _signatureOf(List<MapLayer> layers) {
    final b = StringBuffer();
    for (final l in layers) {
      b
        ..write(l.id)
        ..write('|')
        ..write(l.type.name)
        ..write('|')
        ..write(l.source)
        ..write(';');
    }
    return b.toString();
  }

  Future<void> _resolveIfNeeded() async {
    final sig = _signatureOf(widget.layers);
    if (sig == _lastResolveSignature) return;
    _lastResolveSignature = sig;

    final online = <_Resolved>[];
    final offline = <_Resolved>[];
    for (final l in widget.layers) {
      if (l.type == MapLayerType.tileUrl) {
        // Resolved only-when-visible — kept for online to avoid
        // background network traffic on hidden layers.
        online.add(_Resolved(layer: l, tileLayer: await _build(l)));
      } else if (l.type == MapLayerType.mbtiles) {
        offline.add(_Resolved(layer: l, tileLayer: await _build(l)));
      }
      // Image overlays are rebuilt inline in build(), no resolve.
    }

    if (!mounted) return;
    setState(() {
      _resolvedOnline = online;
      _resolvedOffline = offline;
    });
  }

  Future<TileLayer?> _build(MapLayer layer) async {
    if (_cache.containsKey(layer.id)) return _cache[layer.id];
    final tl = await LayersService.buildTileLayer(layer);
    _cache[layer.id] = tl;
    return tl;
  }

  @override
  Widget build(BuildContext context) {
    // Index the live layer list by id so we can look up CURRENT
    // visibility/opacity. Using `r.layer` from the stored _Resolved
    // would be stale — it was captured at resolve time and doesn't
    // update when the user toggles a switch (signature of the set
    // didn't change, so no re-resolve ran).
    final byId = {for (final l in widget.layers) l.id: l};

    final imageLayers = <MapLayer>[
      for (final l in widget.layers)
        if (l.visible &&
            l.type == MapLayerType.imageOverlay &&
            l.bounds != null)
          l,
    ];

    if (_resolvedOnline.isEmpty &&
        _resolvedOffline.isEmpty &&
        imageLayers.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    // Online: only mounted when currently visible. Widget comes out of
    // the tree as soon as the user toggles it off, stopping tile fetches.
    for (final r in _resolvedOnline) {
      if (r.tileLayer == null) continue;
      final live = byId[r.layer.id];
      if (live == null || !live.visible) continue;
      children.add(Opacity(opacity: live.opacity, child: r.tileLayer!));
    }

    // Offline: always mounted. Opacity becomes 0 when hidden, which
    // keeps the SQLite-backed provider alive so the next toggle-on is
    // instant. Visibility/opacity come from the LIVE layer so flipping
    // a switch takes effect on the very next frame.
    for (final r in _resolvedOffline) {
      if (r.tileLayer == null) continue;
      final live = byId[r.layer.id] ?? r.layer;
      children.add(Opacity(
        opacity: live.visible ? live.opacity : 0.0,
        child: r.tileLayer!,
      ));
    }

    if (imageLayers.isNotEmpty) {
      children.add(_imageOverlayLayer(imageLayers));
    }

    return Stack(children: children);
  }

  Widget _imageOverlayLayer(List<MapLayer> imgs) {
    return SharpOverlayImageLayer(
      overlays: [
        for (final l in imgs) ..._overlaysFor(l),
      ],
    );
  }

  /// Expand one MapLayer into the list of SharpOverlayImage instances
  /// that together reproduce the full scan. Returns:
  ///   * one overlay for a single-file layer,
  ///   * N*M overlays for a tiled layer (see [LayerTileGrid]).
  List<SharpOverlayImage> _overlaysFor(MapLayer l) {
    final b = l.bounds!;
    // Bilinear + mipmap (flutter_map's native default). This gave the
    // sharp TIF look the user originally had before the filter
    // detour. Pixels-per-screen-pixel dominates perceived quality —
    // tiling is what actually preserves the resolution that matters.
    const quality = FilterQuality.medium;

    // Mosaic first: per-tile bounds (JNX et al.) are authoritative
    // over any computed layout.
    if (l.tileMosaic != null) {
      return buildMosaicOverlay(
        mosaic: l.tileMosaic!,
        tileDir: l.source,
        opacity: l.opacity,
        filterQuality: quality,
      );
    }

    if (l.tileGrid != null) {
      return buildTiledOverlay(
        bounds: b,
        grid: l.tileGrid!,
        tileDir: l.source,
        opacity: l.opacity,
        filterQuality: quality,
      );
    }

    // Single-file layer — rotate in metre space (distortion-free at
    // non-equator latitudes) to derive the three corner LatLngs.
    const mPerDegLat = 111320.0;
    final mPerDegLng =
        111320.0 * math.cos(b.centerLat * math.pi / 180.0);
    final halfWM = b.widthDeg / 2 * mPerDegLng;
    final halfHM = b.heightDeg / 2 * mPerDegLat;
    final theta = b.rotationDeg * math.pi / 180.0;
    final sinT = math.sin(theta);
    final cosT = math.cos(theta);
    Offset rotateM(Offset m) => Offset(
          m.dx * cosT - m.dy * sinT,
          m.dx * sinT + m.dy * cosT,
        );
    final tlM = rotateM(Offset(-halfWM, halfHM));
    final blM = rotateM(Offset(-halfWM, -halfHM));
    final brM = rotateM(Offset(halfWM, -halfHM));
    LatLng toLL(Offset m) => LatLng(
          b.centerLat + m.dy / mPerDegLat,
          b.centerLng + m.dx / mPerDegLng,
        );
    return [
      SharpOverlayImage(
        topLeftCorner: toLL(tlM),
        bottomLeftCorner: toLL(blM),
        bottomRightCorner: toLL(brM),
        opacity: l.opacity,
        imageProvider: FileImage(File(l.source)),
        filterQuality: quality,
      ),
    ];
  }
}

/// Pairing of a user layer with its resolved flutter_map TileLayer.
/// We keep a reference to the original [layer] so `visible` / `opacity`
/// changes can flow through without touching the provider.
class _Resolved {
  const _Resolved({required this.layer, required this.tileLayer});
  final MapLayer layer;
  final TileLayer? tileLayer;
}
