import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/providers/layers_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/services/raster_importer.dart';
import '../../../shared/services/world_file.dart';
import '../widgets/sharp_overlay_image_layer.dart';

/// Interactive scan-attachment flow.
///
/// What changed vs the old bbox-inputs version:
///   * **Fullscreen modal**: we push it on the root navigator so the
///     bottom tab bar doesn't clip the control panel anymore.
///   * **Auto-place**: picking an image instantly drops it on the map
///     at the current camera, sized to ~40 % of the viewport. No more
///     typing in N/S/W/E coordinates by hand.
///   * **Drag-to-move**: a pan gesture on the image moves its
///     geographic center. Pans OUTSIDE the image still work as normal
///     map panning.
///   * **Pinch-to-scale** via a Size slider in the bottom panel
///     (maintaining aspect ratio), plus ±/rotation sliders.
///   * **Rotation**: the overlay stores a rotation angle and is
///     rendered via `RotatedOverlayImage`.
///   * **Edit mode**: the screen accepts an optional existing layer
///     for re-editing.
///   * **Persisted** in SharedPreferences through the layers repository
///     — rotation survives restarts.
class GeoreferenceScreen extends ConsumerStatefulWidget {
  const GeoreferenceScreen({super.key, this.editing});

  /// When non-null, we open in "edit" mode, preloaded with this layer's
  /// image, bounds and rotation — saving upserts in place.
  final MapLayer? editing;

  @override
  ConsumerState<GeoreferenceScreen> createState() =>
      _GeoreferenceScreenState();
}

class _GeoreferenceScreenState extends ConsumerState<GeoreferenceScreen> {
  final _map = MapController();
  final _name = TextEditingController();

  /// Points at the raster asset on disk — a single file for small
  /// scans, a directory of tiles for large ones. Stays in sync with
  /// [_tileGrid].
  String? _sourcePath;

  /// Non-null when the loaded raster was sliced into a grid of tiles
  /// at import time (to dodge `GL_MAX_TEXTURE_SIZE`). When set, the
  /// preview renders N overlays — one per tile — and [_image] stays
  /// null.
  LayerTileGrid? _tileGrid;

  /// Non-null for JNX / mosaic layers where each tile has its own
  /// explicit bounds. Mutually exclusive with [_tileGrid]. Handles
  /// still work here — drags translate / scale the whole mosaic via
  /// the delta between [_mosaicBase] and the live editable bbox.
  LayerTileMosaic? _tileMosaic;

  /// For mosaic layers, the bbox the mosaic was loaded with —
  /// treated as the "identity" reference. Drags edit the live bbox
  /// (_centerLat etc.) and the renderer remaps each tile's saved
  /// lat/lng bounds through the (base → live) affine transform, so
  /// dragging the centre move handle shifts the whole scan and the
  /// corner handles scale it as a single block. On save the
  /// transform is baked back into the tile list.
  LayerBounds? _mosaicBase;

  /// Single-file representation when the raster fits into one texture.
  /// Null when the layer is tiled.
  File? _image;
  bool _picking = false;

  /// Center of the overlay in geographic coords.
  double _centerLat = 55.7558;
  double _centerLng = 37.6173;

  /// Size of the overlay in **degrees**. We keep width and height
  /// independent so rectangular scans aren't forced into a square,
  /// but the Size slider scales them together (preserves aspect).
  double _widthDeg = 0.05;
  double _heightDeg = 0.05;

  /// Image's pixel aspect ratio (w/h). Used to set _widthDeg /
  /// _heightDeg when a new image is picked — otherwise the overlay
  /// could get stretched.
  double _imageAspect = 1.0;

  /// Clockwise rotation in degrees (0 = north up).
  double _rotation = 0;

  /// Alpha on the map preview. Default 60 % so the user can see the
  /// underlying satellite while lining up.
  double _opacity = 0.6;

  /// Base map under the overlay — satellite-by-default because aerial
  /// imagery is usually best for matching natural features. Switchable
  /// in the UI because "Схема" (OSM) is far better for locating cities
  /// by name, which the user needs when no other landmarks are obvious.
  BaseMapStyle _baseStyle = BaseMapStyle.satellite;

  bool _draggingImage = false;

  /// Controls bottom-panel collapse state. When the user is nudging
  /// the overlay into place they need the map, not the sliders — a
  /// tap on the chevron collapses the panel down to its header.
  bool _panelExpanded = true;

  @override
  void initState() {
    super.initState();
    // Default to whatever the user last chose on the main map — so a
    // "Схема"-preferring user doesn't land on satellite here and have
    // to switch every time they open the picker.
    final mainBase =
        ref.read(settingsProvider).valueOrNull?.baseMapStyle;
    if (mainBase != null) _baseStyle = mainBase;

    final existing = widget.editing;
    if (existing != null) {
      _sourcePath = existing.source;
      _tileGrid = existing.tileGrid;
      _tileMosaic = existing.tileMosaic;
      _mosaicBase = existing.tileMosaic != null ? existing.bounds : null;
      _image = (existing.tileGrid == null && existing.tileMosaic == null)
          ? File(existing.source)
          : null;
      _name.text = existing.name;
      _opacity = existing.opacity;
      final b = existing.bounds;
      if (b != null) {
        _centerLat = (b.northLat + b.southLat) / 2;
        _centerLng = (b.eastLng + b.westLng) / 2;
        _widthDeg = (b.eastLng - b.westLng).abs();
        _heightDeg = (b.northLat - b.southLat).abs();
        _rotation = b.rotationDeg;
      }
      // Tile grids encode exact source dimensions, so we don't need
      // to re-decode to work out the aspect ratio.
      if (_tileGrid != null) {
        _imageAspect = _tileGrid!.srcWidth / _tileGrid!.srcHeight;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _map.move(LatLng(_centerLat, _centerLng),
              _estimateFitZoom(_widthDeg, _heightDeg));
        } catch (_) {}
        if (_image != null) _readImageAspect();
      });
    }
  }

  @override
  void dispose() {
    _map.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _readImageAspect() async {
    final f = _image;
    if (f == null) return;
    try {
      final bytes = await f.readAsBytes();
      final dec = await decodeImageFromList(bytes);
      if (!mounted) return;
      // We need degree-space bounds, but the image's pixel aspect
      // ratio is a METRE ratio (square pixels). At lat 55° 1° lng ≈
      // 0.57 × 1° lat, so to render a 2:1 pixel image correctly we
      // need widthDeg : heightDeg = 2 / cos(lat), not just 2:1. Skip
      // this correction and a square image ends up looking tall.
      final latCos = math.cos(_centerLat * math.pi / 180.0);
      final ratioDeg =
          dec.width / dec.height / (latCos.abs() < 1e-6 ? 1 : latCos);
      setState(() {
        _imageAspect = dec.width / dec.height;
        // Keep roughly the same overall area when rescaling — take
        // geometric mean of current w/h as the base "size" and rebuild
        // from the corrected ratio.
        final avg = math.sqrt(_widthDeg * _heightDeg);
        _widthDeg = avg * math.sqrt(ratioDeg);
        _heightDeg = avg / math.sqrt(ratioDeg);
      });
    } catch (_) {
      // Best effort — non-critical if dimensions don't come through.
    }
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      // Multi-select so the user can pick the raster together with
      // its world-file sidecar (.tfw, .tfwx, .jgw, .jgwx, .pgw, .wld
      // or GDAL's <name>.aux.xml) in a single step.
      //
      // This matters on Android: with Scoped Storage, `file_picker`
      // copies each selected entry into the app's cache — it does NOT
      // bring neighbouring files along. If the user only picks the
      // raster, the .tfw that sits next to it on disk never crosses
      // the sandbox boundary, `findSidecar` finds nothing, and the
      // scan drops into the default "centre of viewport @ 40 %"
      // position (which is exactly the drift the user was seeing).
      //
      // `FileType.any` lets the user tap the sidecar too — Android
      // won't show .tfw files under FileType.custom because it
      // maps extensions to MIME types and .tfw has no standard one.
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (res == null || res.files.isEmpty) return;

      final pickedPaths = [
        for (final f in res.files)
          if (f.path != null) f.path!,
      ];
      final staged = await RasterImporter.stageSelection(pickedPaths);
      if (staged == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Выберите растровый файл: .tif, .tiff, .jpg, .jpeg, .png или .jnx.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
        return;
      }
      final rasterPath = staged.rasterPath;
      final sidecarPresent = staged.sidecarMatched;
      final stagedSidecarPaths = staged.sidecarPaths;

      // Hand the staged raster to the shared importer. It does:
      //   1. Transcodes TIFF → PNG so Flutter's image pipeline can
      //      actually render it (FileImage can't decode TIFF).
      //   2. Copies the asset into the app's private `layers/` dir so
      //      deleting the source later doesn't break the layer.
      //   3. Looks for a sidecar world file next to the raster path
      //      and parses exact geographic bounds.
      final RasterImportResult imported;
      try {
        imported = await RasterImporter.importFile(rasterPath);
      } on RasterImportException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 8),
            ),
          );
        }
        return;
      }

      final importedLayer = imported.layer;
      final exactBounds = importedLayer.bounds;
      final importedTileGrid = importedLayer.tileGrid;
      final importedTileMosaic = importedLayer.tileMosaic;
      // For tiled / mosaic layers `source` is a directory; `_image`
      // stays null and the preview renders through either
      // `buildTiledOverlay` or `buildMosaicOverlay` instead.
      final savedFile = (importedTileGrid == null && importedTileMosaic == null)
          ? File(importedLayer.source)
          : null;

      if (exactBounds != null) {
        // Sidecar was found and validated: snap to exact coords and
        // exact proportion. The world file already accounts for
        // pixel aspect + latitude scale, so no further adjustment is
        // needed — `_readImageAspect` MUST NOT rescale here.
        setState(() {
          _sourcePath = importedLayer.source;
          _tileGrid = importedTileGrid;
          _tileMosaic = importedTileMosaic;
          _mosaicBase =
              importedTileMosaic != null ? exactBounds : null;
          _image = savedFile;
          if (_name.text.isEmpty) {
            _name.text = p.basenameWithoutExtension(rasterPath);
          }
          _centerLat = (exactBounds.northLat + exactBounds.southLat) / 2;
          _centerLng = (exactBounds.eastLng + exactBounds.westLng) / 2;
          _widthDeg = (exactBounds.eastLng - exactBounds.westLng).abs();
          _heightDeg = (exactBounds.northLat - exactBounds.southLat).abs();
          _rotation = exactBounds.rotationDeg;
          if (importedTileGrid != null) {
            _imageAspect =
                importedTileGrid.srcWidth / importedTileGrid.srcHeight;
          }
        });

        // Move the camera to the scan so the user sees their map
        // sitting in place, not somewhere off-screen.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _map.move(
              LatLng(_centerLat, _centerLng),
              _estimateFitZoom(_widthDeg, _heightDeg),
            );
          } catch (_) {}
        });

        // Record pixel aspect for later slider math (without
        // rescaling the bounds we just set from the sidecar).
        // Tiled layers already know their source dimensions from
        // the grid, so the async decode is only needed for the
        // single-file path.
        if (savedFile != null) {
          // ignore: unawaited_futures
          _readPixelAspectOnly();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                imported.warning ??
                    'Привязка подхвачена автоматически из world-файла.',
              ),
              backgroundColor: imported.warning == null
                  ? AppColors.success
                  : AppColors.accentAmber,
              duration: Duration(
                seconds: imported.warning == null ? 3 : 6,
              ),
            ),
          );
        }
      } else {
        // No sidecar — fall back to the old "drop at viewport centre
        // at 40 % size" behaviour. User drags / resizes to align.
        final fit = _computeDefaultSize();
        setState(() {
          _sourcePath = importedLayer.source;
          _tileGrid = importedTileGrid;
          _tileMosaic = importedTileMosaic;
          _image = savedFile;
          if (_name.text.isEmpty) {
            _name.text = p.basenameWithoutExtension(rasterPath);
          }
          _centerLat = fit.centerLat;
          _centerLng = fit.centerLng;
          _widthDeg = fit.widthDeg;
          _heightDeg = fit.heightDeg;
          _rotation = 0;
          if (importedTileGrid != null) {
            _imageAspect =
                importedTileGrid.srcWidth / importedTileGrid.srcHeight;
          }
        });
        if (savedFile != null) {
          // ignore: unawaited_futures
          _readImageAspect();
        }

        // Surface the sidecar's XML root (or first-line) so the user
        // sees WHICH format we couldn't parse. Must happen BEFORE the
        // BuildContext is touched — showSnackBar after an async gap
        // is an analyzer no-no.
        String msg;
        if (!sidecarPresent) {
          msg = 'Файл привязки не выбран. Откройте «Заменить» ещё '
              'раз и отметьте растр ВМЕСТЕ с основным сайдкаром: '
              '.tfw / .tfwx для TIFF, .jgw / .jgwx для JPEG, '
              '.pgw для PNG.';
        } else {
          final shapes = <String>[];
          for (final sp in stagedSidecarPaths) {
            final s = await WorldFile.describeSidecarShape(File(sp));
            if (s != null) shapes.add('${p.basename(sp)}: $s');
          }
          final head = 'Файлы привязки выбраны, но разобрать их не '
              'удалось.';
          final detail = shapes.isEmpty
              ? ''
              : '\n\nЧто увидели: ${shapes.join('; ')}';
          final tail = '\n\nПопробуйте основной сайдкар: '
              '.jgw / .jgwx для JPEG, .tfw / .tfwx для TIFF, '
              '.pgw для PNG (без XML). Если поделитесь этим текстом '
              'с разработчиком — добавим поддержку формата.';
          msg = '$head$detail$tail';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.accentAmber,
              duration: const Duration(seconds: 15),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Lightweight variant of [_readImageAspect] that only records the
  /// pixel aspect ratio into [_imageAspect] for later slider math.
  /// Does NOT touch `_widthDeg` / `_heightDeg` — used when the overlay
  /// has just been positioned by an authoritative world file that
  /// already encodes the correct aspect.
  Future<void> _readPixelAspectOnly() async {
    final f = _image;
    if (f == null) return;
    try {
      final bytes = await f.readAsBytes();
      final dec = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() => _imageAspect = dec.width / dec.height);
    } catch (_) {
      // Non-critical.
    }
  }

  _InitialFit _computeDefaultSize() {
    try {
      final cam = _map.camera;
      final bounds = cam.visibleBounds;
      // Start at 40 % of the viewport — big enough to see, small
      // enough to reposition easily.
      final w = (bounds.east - bounds.west).abs() * 0.4;
      final h = (bounds.north - bounds.south).abs() * 0.4;
      return _InitialFit(
        centerLat: cam.center.latitude,
        centerLng: cam.center.longitude,
        widthDeg: w,
        heightDeg: h,
      );
    } catch (_) {
      return const _InitialFit(
        centerLat: 55.7558,
        centerLng: 37.6173,
        widthDeg: 0.05,
        heightDeg: 0.05,
      );
    }
  }

  double _estimateFitZoom(double widthDeg, double heightDeg) {
    // Crude: fit widthDeg to a 350px-ish area on screen. This gets the
    // preview in the right ballpark so the user isn't lost.
    final span = math.max(widthDeg.abs(), heightDeg.abs());
    if (span <= 0.002) return 16;
    if (span <= 0.01) return 14;
    if (span <= 0.05) return 12;
    if (span <= 0.3) return 10;
    if (span <= 1.0) return 8;
    if (span <= 4.0) return 6;
    return 4;
  }

  /// Build the 4 corner LatLngs that feed RotatedOverlayImage and the
  /// corner handles.
  ///
  /// **Key point**: the rotation MUST happen in metres, not degrees.
  /// At latitude 58° (Великий Новгород) one degree of longitude is
  /// only ~59 km while one degree of latitude is ~111 km — rotating
  /// directly in degree space stretches the rectangle along one axis,
  /// which is why the preview looked "tilted in 3D" at large rotation
  /// angles. Converting to metres gives an equal-scale Cartesian space
  /// where rotation is distortion-free, then we convert back to
  /// lat/lng for flutter_map.
  _Corners _computeCorners() {
    const mPerDegLat = 111320.0;
    final mPerDegLng =
        111320.0 * math.cos(_centerLat * math.pi / 180.0);

    // Unrotated half-sizes in metres.
    final hwM = _widthDeg / 2 * mPerDegLng;
    final hhM = _heightDeg / 2 * mPerDegLat;

    final rad = _rotation * math.pi / 180.0;
    final sinR = math.sin(rad);
    final cosR = math.cos(rad);

    // Rotate a vector in metre space.
    Offset rotM(Offset m) => Offset(
          m.dx * cosR - m.dy * sinR,
          m.dx * sinR + m.dy * cosR,
        );

    final tlM = rotM(Offset(-hwM, hhM));
    final trM = rotM(Offset(hwM, hhM));
    final blM = rotM(Offset(-hwM, -hhM));
    final brM = rotM(Offset(hwM, -hhM));

    // Convert a metre-offset back to a LatLng relative to the centre.
    LatLng toLL(Offset m) => LatLng(
          _centerLat + m.dy / mPerDegLat,
          _centerLng + m.dx / mPerDegLng,
        );

    return _Corners(
      topLeft: toLL(tlM),
      topRight: toLL(trM),
      bottomLeft: toLL(blM),
      bottomRight: toLL(brM),
    );
  }

  /// Convert a screen (pixel) delta into a change in geographic
  /// coordinates, using the current camera's meters-per-pixel AND
  /// current rotation.
  ///
  /// When the user has rotated the base map (e.g. north-east is now
  /// pointing straight up on screen), dragging the finger RIGHT on
  /// screen should move the scan RIGHT on screen — which geographically
  /// is no longer "east" but some other compass direction. Inverse-
  /// rotating the incoming screen delta before converting to geo
  /// deltas makes drag feel natural regardless of map orientation.
  Offset _screenDeltaToGeo(Offset screenDelta) {
    try {
      final cam = _map.camera;
      final zoom = cam.zoom;
      final latRad = _centerLat * math.pi / 180.0;
      // Web-Mercator metres per pixel at current zoom + latitude.
      const earthCircumference = 40075016.686;
      final mpp = earthCircumference * math.cos(latRad) / math.pow(2, zoom + 8);
      const metersPerDegLat = 111320.0;
      final metersPerDegLng = 111320.0 * math.cos(latRad);

      // Inverse-rotate the incoming screen delta so it represents
      // motion in the map's un-rotated (north-up) coordinate system.
      final theta = cam.rotationRad;
      final sinT = math.sin(theta);
      final cosT = math.cos(theta);
      final mapDx = screenDelta.dx * cosT + screenDelta.dy * sinT;
      final mapDy = -screenDelta.dx * sinT + screenDelta.dy * cosT;

      final dLat = -mapDy * mpp / metersPerDegLat;
      final dLng = mapDx * mpp / metersPerDegLng;
      return Offset(dLng, dLat);
    } catch (_) {
      return Offset.zero;
    }
  }

  /// Given a LatLng, return its position in the screen-pixel
  /// coordinate space that a Positioned widget sitting over the map
  /// uses — already rotation-aware.
  ///
  /// We delegate to flutter_map's purpose-built
  /// [MapCamera.latLngToScreenPoint], which rotates in projected-
  /// pixel space around the map centre and subtracts the
  /// NON-rotated pixel origin. A previous hand-rolled version used
  /// `getOffsetFromOrigin`, but that one subtracts the ROTATED
  /// `pixelOrigin = project(center) - size/2`, where `size` is the
  /// larger rotated-bounds buffer. Then rotating manually around
  /// `cam.size/2` stacks a second transform in the wrong frame —
  /// the net effect is a `(size − nonRotatedSize) / 2` drift that
  /// got worse the further you rotated. That's why the corner and
  /// centre handles slid off the overlay as soon as the user
  /// two-finger-rotated the base map.
  Offset? _latLngToScreen(LatLng ll) {
    try {
      final p = _map.camera.latLngToScreenPoint(ll);
      return Offset(p.x, p.y);
    } catch (_) {
      return null;
    }
  }

  /// Re-project every tile in [_tileMosaic] through the affine
  /// transform implied by `(_mosaicBase → live bbox)`. Used at
  /// render time so drags on the bbox handles visually shift /
  /// scale the mosaic, and at save time to bake the new positions
  /// into the stored tile list.
  ///
  /// Translation: the vector from base centre to live centre is
  /// added to every tile's bounds.
  /// Scale: the ratio `live.size / base.size` (independent X / Y)
  /// stretches each tile's bounds relative to the base centre.
  /// Rotation is intentionally NOT applied — mosaic tiles are
  /// axis-aligned by format contract and rotating them would
  /// make the quadrilateral-projection edges jagged.
  LayerTileMosaic _mosaicLive() {
    final mosaic = _tileMosaic!;
    final base = _mosaicBase;
    if (base == null) return mosaic; // no transform yet — render as is.

    final baseCLat = base.centerLat;
    final baseCLng = base.centerLng;
    final scaleLat = base.heightDeg == 0 ? 1.0 : _heightDeg / base.heightDeg;
    final scaleLng = base.widthDeg == 0 ? 1.0 : _widthDeg / base.widthDeg;

    LayerBounds remap(LayerBounds tb) {
      final newCLat = _centerLat + (tb.centerLat - baseCLat) * scaleLat;
      final newCLng = _centerLng + (tb.centerLng - baseCLng) * scaleLng;
      final halfLat = tb.heightDeg / 2 * scaleLat;
      final halfLng = tb.widthDeg / 2 * scaleLng;
      return LayerBounds(
        northLat: newCLat + halfLat,
        southLat: newCLat - halfLat,
        westLng: newCLng - halfLng,
        eastLng: newCLng + halfLng,
      );
    }

    return LayerTileMosaic(
      tiles: [
        for (final t in mosaic.tiles)
          MosaicTile(file: t.file, bounds: remap(t.bounds)),
      ],
    );
  }

  Future<void> _save() async {
    // Either single-file or tiled must be present.
    if (_sourcePath == null) return;
    final b = LayerBounds(
      northLat: _centerLat + _heightDeg / 2,
      southLat: _centerLat - _heightDeg / 2,
      westLng: _centerLng - _widthDeg / 2,
      eastLng: _centerLng + _widthDeg / 2,
      rotationDeg: _rotation,
    );
    // For mosaic layers, bake the live transform into every tile so
    // the saved mosaic is self-consistent — after save, the new
    // bounds ARE the new reference frame (no dual state).
    final savedMosaic =
        _tileMosaic != null ? _mosaicLive() : null;
    final existing = widget.editing;
    final layer = existing != null
        ? existing.copyWith(
            name: _name.text.trim().isEmpty ? existing.name : _name.text.trim(),
            opacity: _opacity,
            bounds: b,
            tileMosaic: savedMosaic,
          )
        : MapLayer(
            id: const Uuid().v4(),
            name: _name.text.trim().isEmpty ? 'Скан карты' : _name.text.trim(),
            type: MapLayerType.imageOverlay,
            source: _sourcePath!,
            tileGrid: _tileGrid,
            tileMosaic: savedMosaic ?? _tileMosaic,
            opacity: _opacity,
            bounds: b,
          );
    await ref.read(layersProvider.notifier).upsert(layer);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing != null
            ? 'Привязка «${layer.name}» обновлена'
            : 'Слой «${layer.name}» добавлен'),
      ),
    );
  }

  void _centerOnViewport() {
    try {
      final cam = _map.camera;
      setState(() {
        _centerLat = cam.center.latitude;
        _centerLng = cam.center.longitude;
      });
    } catch (_) {}
  }

  /// Scale the overlay uniformly based on a drag on one of the four
  /// corner handles. [newCornerScreen] is the finger's current screen
  /// pixel position (already in the rotation-aware Positioned-widget
  /// coordinate space that `latLngToScreenPoint` returns — the same
  /// one the handles themselves are placed in, so the two compare
  /// directly even with the base map rotated).
  void _resizeByCornerDrag(Offset newCornerScreen) {
    try {
      final cam = _map.camera;
      Offset toScreen(LatLng ll) {
        final p = cam.latLngToScreenPoint(ll);
        return Offset(p.x, p.y);
      }

      final centerScreen = toScreen(LatLng(_centerLat, _centerLng));
      final cornerFromCenter = newCornerScreen - centerScreen;

      // Reference half-diagonal: project the current top-right LL
      // corner with the same projection. Using one canonical corner
      // (rather than all four) is fine since scale is uniform.
      final currentCornerScreen = toScreen(
        LatLng(_centerLat + _heightDeg / 2, _centerLng + _widthDeg / 2),
      );
      final currentHalfDiag = (currentCornerScreen - centerScreen).distance;
      if (currentHalfDiag < 1) return; // guard

      final newHalfDiag = cornerFromCenter.distance;
      final scale = newHalfDiag / currentHalfDiag;
      // Clamp to sane range so a shaky finger doesn't send a 1 m scan
      // to cover the whole continent in one frame.
      final clampedScale = scale.clamp(0.2, 5.0);

      setState(() {
        _widthDeg *= clampedScale;
        _heightDeg *= clampedScale;
      });
    } catch (_) {}
  }

  void _fitToViewport() {
    try {
      final cam = _map.camera;
      final bounds = cam.visibleBounds;
      setState(() {
        _centerLat = (bounds.north + bounds.south) / 2;
        _centerLng = (bounds.east + bounds.west) / 2;
        final viewWidth = (bounds.east - bounds.west).abs();
        final latCos = math.cos(_centerLat * math.pi / 180.0);
        // `_imageAspect` is pixel w/h. Corrected for Mercator:
        // widthDeg / heightDeg = pixelAspect / cos(lat).
        final ratioDeg =
            (_imageAspect == 0 ? 1 : _imageAspect) /
                (latCos.abs() < 1e-6 ? 1 : latCos);
        _widthDeg = viewWidth * 0.8;
        _heightDeg = _widthDeg / ratioDeg;
        _rotation = 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final corners = _sourcePath == null ? null : _computeCorners();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // --- Map + overlay ---
          // No IgnorePointer wrap: the map is always live so the user
          // can pan / zoom / rotate / two-finger-anything freely. Our
          // 5 handles (4 corners + centre) use an opaque Listener so
          // they receive their own pointer events without letting them
          // leak to the map — pinches with both fingers on empty map
          // work normally.
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: const MapOptions(
                initialCenter: LatLng(55.7558, 37.6173),
                initialZoom: 10,
              ),
              children: [
                TileLayer(
                  // Keyed by style name so flipping chips forces a
                  // fresh TileLayer (and therefore a fresh fetch)
                  // rather than trying to swap URLs on a live layer.
                  key: ValueKey('georef_base_${_baseStyle.name}'),
                  urlTemplate: _baseStyle.tileUrl,
                  userAgentPackageName: 'com.chaliy.nav',
                ),
                if (_sourcePath != null && corners != null)
                  // Custom overlay layer — the stock flutter_map
                  // `OverlayImageLayer` ignores `filterQuality` on
                  // the inner Image widget, so overlays come out
                  // pre-blurred. Our layer threads the quality all
                  // the way to the Image draw call.
                  //
                  // Three render paths depending on how the layer
                  // was stored:
                  //   * tileMosaic (JNX) — each tile has its own
                  //     explicit bounds; we ignore the editable
                  //     bbox since the source format's positions
                  //     are authoritative.
                  //   * tileGrid — pixel-grid split of a single
                  //     source image; sub-bounds derived from the
                  //     editable bbox.
                  //   * neither — plain single-file overlay bound
                  //     to the three editable corners.
                  SharpOverlayImageLayer(
                    overlays: _tileMosaic != null
                        ? buildMosaicOverlay(
                            // Re-project each saved tile into the
                            // user's current bbox so drag handles
                            // visually move the whole mosaic.
                            mosaic: _mosaicLive(),
                            tileDir: _sourcePath!,
                            opacity: _opacity,
                            filterQuality: FilterQuality.medium,
                          )
                        : _tileGrid != null
                            ? buildTiledOverlay(
                                bounds: LayerBounds(
                                  northLat:
                                      _centerLat + _heightDeg / 2,
                                  southLat:
                                      _centerLat - _heightDeg / 2,
                                  westLng:
                                      _centerLng - _widthDeg / 2,
                                  eastLng:
                                      _centerLng + _widthDeg / 2,
                                  rotationDeg: _rotation,
                                ),
                                grid: _tileGrid!,
                                tileDir: _sourcePath!,
                                opacity: _opacity,
                                filterQuality: FilterQuality.medium,
                              )
                            : [
                                SharpOverlayImage(
                                  topLeftCorner: corners.topLeft,
                                  bottomLeftCorner: corners.bottomLeft,
                                  bottomRightCorner: corners.bottomRight,
                                  opacity: _opacity,
                                  imageProvider: FileImage(_image!),
                                  filterQuality: FilterQuality.medium,
                                ),
                              ],
                  ),
              ],
            ),
          ),

          // (Body-drag catcher removed — the visible centre move
          // handle is the single source of "translate the overlay"
          // gestures. That eliminates gesture-arena conflicts with
          // the base map's pan/pinch/rotate, which were breaking
          // two-finger manipulation of the base map whenever a
          // finger was anywhere inside the scan's bounding box.)

          // Four visible corner handles + one visible centre handle.
          // The wrapper `Positioned.fill` pins these overlays to the
          // full viewport — without it the inner Stack would collapse
          // to zero size and the Positioned handles drift to (0,0).
          //
          // `screenOf` is rotation-aware, so handles stay stuck to
          // the overlay even when the user two-finger-rotates the
          // base map.
          // Handles are shown for every overlay type. For mosaic
          // layers the drag deltas feed into the (base → live)
          // transform that [_buildMosaicOverlays] applies to each
          // tile's stored bounds — so translating the centre shifts
          // the whole scan and scaling the corners scales it as
          // one block.
          if (_sourcePath != null && corners != null)
            Positioned.fill(
              child: _OverlayHandles(
                map: _map,
                corners: corners,
                centerLat: _centerLat,
                centerLng: _centerLng,
                screenOf: _latLngToScreen,
                onResize: _resizeByCornerDrag,
                onMove: (screenDelta) {
                  final geoDelta = _screenDeltaToGeo(screenDelta);
                  setState(() {
                    _centerLng += geoDelta.dx;
                    _centerLat += geoDelta.dy;
                  });
                },
                onDragStart: () =>
                    setState(() => _draggingImage = true),
                onDragEnd: () =>
                    setState(() => _draggingImage = false),
              ),
            ),

          // --- Top app bar ---
          Positioned(
            top: media.padding.top,
            left: 0,
            right: 0,
            child: Container(
              height: 56,
              color: AppColors.bgDeep.withValues(alpha: 0.9),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(PhosphorIconsBold.x,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.editing != null
                          ? 'Изменить привязку'
                          : 'Привязать скан',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _sourcePath != null ? _save : null,
                    child: Text(
                      'Сохранить',
                      style: TextStyle(
                        color: _sourcePath != null
                            ? AppColors.primaryGlow
                            : AppColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Floating base-map picker. Sits below the app bar on
          //     the right edge so the user can flip between satellite
          //     (great for natural features) and schema (much better
          //     for finding cities/roads by name).
          Positioned(
            top: media.padding.top + 60,
            right: 12,
            child: _baseMapPicker(),
          ),

          // --- Bottom control panel. Uses SafeArea so the system nav
          //     bar and any remaining shell UI don't clip it.
          //     Fully collapsible: a chevron in the header toggles
          //     between full (sliders + actions) and compact (just
          //     the pick row + a handle to expand again).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Strong fill = nearly-opaque dark background so
                    // the live map underneath doesn't bleed through
                    // the control text. Previous 0.25-alpha fill was
                    // unreadable against busy maps.
                    Container(
                      decoration: BoxDecoration(
                        color:
                            AppColors.bgDeepest.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.glassBorderStrong,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _pickRow()),
                              const SizedBox(width: 6),
                              // Collapse / expand toggle.
                              IconButton(
                                onPressed: () => setState(
                                    () => _panelExpanded = !_panelExpanded),
                                icon: Icon(
                                  _panelExpanded
                                      ? PhosphorIconsBold.caretDown
                                      : PhosphorIconsBold.caretUp,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                                tooltip: _panelExpanded
                                    ? 'Свернуть'
                                    : 'Развернуть',
                              ),
                            ],
                          ),
                          // AnimatedSize gives a nice roll-up of the
                          // sliders + actions while preserving the
                          // pick row above.
                          AnimatedSize(
                            duration:
                                const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: !_panelExpanded || _sourcePath == null
                                ? const SizedBox(width: double.infinity)
                                : Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      _slidersBlock(),
                                      const SizedBox(height: 6),
                                      _actionsRow(),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Modal "decoding…" overlay shown while the user's file is
          // being copied / transcoded / parsed. Large GeoTIFFs take
          // several seconds to decode and without this veil people
          // assume the app froze.
          if (_picking)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: AppColors.bgDeep.withValues(alpha: 0.72),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeepest.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primaryGlow.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.primaryGlow,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Разбираю скан…',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Декодирование + поиск координат',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Vertical pill of rounded chips, one per base-map style. Current
  /// style is highlighted. Tap = switch instantly (TileLayer key is
  /// tied to style.name, so it rebuilds with a fresh provider).
  Widget _baseMapPicker() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgDeepest.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in BaseMapStyle.values) _baseChip(s),
          ],
        ),
      ),
    );
  }

  Widget _baseChip(BaseMapStyle s) {
    final selected = _baseStyle == s;
    final (icon, short) = switch (s) {
      BaseMapStyle.schema => (PhosphorIconsDuotone.mapTrifold, 'Схема'),
      BaseMapStyle.satellite => (PhosphorIconsDuotone.globe, 'Спутник'),
      BaseMapStyle.hybrid => (PhosphorIconsDuotone.stack, 'Гибрид'),
      BaseMapStyle.terrain => (PhosphorIconsDuotone.mountains, 'Рельеф'),
      BaseMapStyle.dark => (PhosphorIconsDuotone.moon, 'Тёмная'),
    };
    return Tooltip(
      message: short,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _baseStyle = s),
          borderRadius: BorderRadius.circular(100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.primaryGlow.withValues(alpha: 0.22)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? AppColors.primaryGlow.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? AppColors.primaryGlow
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickRow() {
    return Row(
      children: [
        Icon(
          _sourcePath == null
              ? PhosphorIconsDuotone.image
              : PhosphorIconsFill.image,
          color: _sourcePath == null
              ? AppColors.textTertiary
              : AppColors.primaryGlow,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _name,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Название слоя',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Menu button — offers two sources:
        //   * a brand-new file from storage, or
        //   * an already-imported imageOverlay layer to re-edit.
        GlassButton(
          label: _picking
              ? '…'
              : (_sourcePath == null ? 'Выбрать' : 'Заменить'),
          icon: Icon(PhosphorIconsDuotone.folderOpen),
          onPressed: _picking ? null : _openSourcePicker,
          small: true,
        ),
      ],
    );
  }

  Future<void> _openSourcePicker() async {
    // Pull the list of already-imported imageOverlay layers so the
    // user can pick one to re-edit without leaving this screen.
    final all = ref.read(layersProvider).valueOrNull ?? const [];
    final existingOverlays = [
      for (final l in all)
        if (l.type == MapLayerType.imageOverlay) l,
    ];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Откуда взять карту?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(PhosphorIconsDuotone.folderOpen,
                    color: AppColors.primaryGlow),
                title: const Text('Из файла',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text(
                  'JPEG / PNG / TIFF. Чтобы скан встал по координатам '
                  'автоматически — выделите растр ВМЕСТЕ с основным '
                  'файлом привязки: .tfw / .tfwx для TIFF, '
                  '.jgw / .jgwx для JPEG, .pgw для PNG. '
                  '(.aux.xml — запасной вариант, в нём часто нет '
                  'координат, только статистика.)',
                  style: TextStyle(
                      color: AppColors.textTertiary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pick();
                },
              ),
              Divider(color: AppColors.glassBorder, height: 1),
              if (existingOverlays.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Пока нет импортированных скан-слоёв.',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 12),
                  ),
                )
              else ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text(
                    'УЖЕ ИМПОРТИРОВАНЫ',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final l in existingOverlays)
                        ListTile(
                          leading: Icon(PhosphorIconsDuotone.image,
                              color: AppColors.accentCyan),
                          title: Text(
                            l.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            l.bounds == null
                                ? 'Без привязки'
                                : 'Привязан${l.bounds!.rotationDeg != 0 ? " · поворот ${l.bounds!.rotationDeg.toStringAsFixed(0)}°" : ""}',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _loadExisting(l);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _loadExisting(MapLayer l) {
    setState(() {
      _sourcePath = l.source;
      _tileGrid = l.tileGrid;
      _tileMosaic = l.tileMosaic;
      _mosaicBase = l.tileMosaic != null ? l.bounds : null;
      _image = (l.tileGrid == null && l.tileMosaic == null)
          ? File(l.source)
          : null;
      _name.text = l.name;
      _opacity = l.opacity;
      final b = l.bounds;
      if (b != null) {
        _centerLat = (b.northLat + b.southLat) / 2;
        _centerLng = (b.eastLng + b.westLng) / 2;
        _widthDeg = (b.eastLng - b.westLng).abs();
        _heightDeg = (b.northLat - b.southLat).abs();
        _rotation = b.rotationDeg;
      }
      if (l.tileGrid != null) {
        _imageAspect = l.tileGrid!.srcWidth / l.tileGrid!.srcHeight;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _map.move(LatLng(_centerLat, _centerLng),
            _estimateFitZoom(_widthDeg, _heightDeg));
      } catch (_) {}
      if (_image != null) _readImageAspect();
    });
  }

  Widget _slidersBlock() {
    // Slider scale ranges chosen to be "useful" for scans: size from
    // 0.001° (~100 m) to 10° (~1100 km). Rotation -180°…180°. Opacity
    // 10%-100%.
    final size = math.sqrt(_widthDeg * _heightDeg);
    return Column(
      children: [
        _labeledSlider(
          icon: PhosphorIconsDuotone.arrowsOutCardinal,
          label: 'Размер',
          value: _clamp(size, 0.001, 10.0),
          min: 0.001,
          max: 10.0,
          displayedValue: _formatSpan(size),
          onChanged: (v) {
            // Preserve image aspect ratio AND Mercator latitude
            // correction — otherwise a square image goes "wider"
            // as we drag the slider on high-latitude maps.
            final latCos = math.cos(_centerLat * math.pi / 180.0);
            final pixelRatio = _imageAspect == 0 ? 1 : _imageAspect;
            final ratioDeg =
                pixelRatio / (latCos.abs() < 1e-6 ? 1 : latCos);
            setState(() {
              _widthDeg = v * math.sqrt(ratioDeg);
              _heightDeg = v / math.sqrt(ratioDeg);
            });
          },
        ),
        _labeledSlider(
          icon: PhosphorIconsDuotone.arrowClockwise,
          label: 'Поворот',
          value: _rotation,
          min: -180,
          max: 180,
          displayedValue: '${_rotation.toStringAsFixed(0)}°',
          onChanged: (v) => setState(() => _rotation = v),
        ),
        _labeledSlider(
          icon: PhosphorIconsDuotone.sun,
          label: 'Прозрачность',
          value: _opacity,
          min: 0.1,
          max: 1.0,
          displayedValue: '${(_opacity * 100).round()}%',
          onChanged: (v) => setState(() => _opacity = v),
        ),
      ],
    );
  }

  Widget _actionsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _centerOnViewport,
          icon: Icon(PhosphorIconsDuotone.crosshair, size: 14),
          label: const Text('В центр карты'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGlow,
            side: BorderSide(
                color: AppColors.primaryGlow.withValues(alpha: 0.5)),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _fitToViewport,
          icon: Icon(PhosphorIconsDuotone.cornersOut, size: 14),
          label: const Text('По размеру карты'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGlow,
            side: BorderSide(
                color: AppColors.primaryGlow.withValues(alpha: 0.5)),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _rotation = 0),
          icon: Icon(PhosphorIconsDuotone.compass, size: 14),
          label: const Text('Север вверх'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.glassBorderStrong),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
      ],
    );
  }

  Widget _labeledSlider({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayedValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              )),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryGlow,
              inactiveTrackColor: AppColors.glassBorderStrong,
              thumbColor: Colors.white,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _clamp(value, min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            displayedValue,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.primaryGlow,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  String _formatSpan(double deg) {
    // Mix degrees and metres depending on magnitude, for intuition.
    final metres = deg * 111320;
    if (metres < 1000) return '${metres.toStringAsFixed(0)} м';
    if (metres < 100000) return '${(metres / 1000).toStringAsFixed(1)} км';
    return '${deg.toStringAsFixed(2)}°';
  }
}

class _InitialFit {
  const _InitialFit({
    required this.centerLat,
    required this.centerLng,
    required this.widthDeg,
    required this.heightDeg,
  });
  final double centerLat;
  final double centerLng;
  final double widthDeg;
  final double heightDeg;
}

class _Corners {
  const _Corners({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });
  final LatLng topLeft;
  final LatLng topRight;
  final LatLng bottomLeft;
  final LatLng bottomRight;
}

/// Full-screen gesture catcher that selectively eats pan events when
/// they start inside the image's 4-corner polygon. Everything else
/// (zoom, taps, pans outside the image) falls through to FlutterMap.
///
/// We don't use an actual widget positioned over the image because the
/// image is rotated — we'd need a matching-rotation hit area. It's
/// simpler to hit-test the pan start against the image's projected
/// screen coordinates using the camera.
class _ImageDragCatcher extends StatefulWidget {
  const _ImageDragCatcher({
    required this.map,
    required this.corners,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final MapController map;
  final _Corners corners;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_ImageDragCatcher> createState() => _ImageDragCatcherState();
}

class _ImageDragCatcherState extends State<_ImageDragCatcher> {
  int? _activePointer;
  Offset? _lastPos;
  bool _dragLive = false;
  bool _cancelled = false;

  void _finish(int pointer) {
    if (_activePointer != pointer) return;
    if (_dragLive && !_cancelled) widget.onDragEnd();
    _activePointer = null;
    _lastPos = null;
    _dragLive = false;
    _cancelled = false;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Listener(
        // Opaque: we CLAIM pointer events that land on us — so a drag
        // starting inside the image area doesn't also pan the map.
        // Pointer-count check inside _onDown releases to map on
        // multi-touch (second finger → cancel, let map pinch-zoom).
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          // Second pointer? Release control to the map.
          if (_activePointer != null) {
            if (_dragLive) widget.onDragEnd();
            _dragLive = false;
            _cancelled = true;
            return;
          }
          // If the touch didn't start inside the image polygon, we
          // don't "own" the gesture — but we already absorbed it
          // due to `opaque`. To forward it to the map, we'd need a
          // more invasive solution. For now treat taps outside as
          // no-op drags (map pan still works if you swipe starting
          // outside the image, because the AABB hit-test rejects
          // this pointer before we set `_dragLive = true`).
          if (!_isPointerInsideImage(e.localPosition)) {
            _activePointer = e.pointer;
            _lastPos = e.position;
            _cancelled = true; // absorb, but don't act
            return;
          }
          _activePointer = e.pointer;
          _lastPos = e.position;
          _cancelled = false;
          _dragLive = true;
          widget.onDragStart();
        },
        onPointerMove: (e) {
          if (_cancelled) return;
          if (e.pointer != _activePointer) return;
          final delta =
              _lastPos == null ? Offset.zero : e.position - _lastPos!;
          _lastPos = e.position;
          widget.onDragUpdate(delta);
        },
        onPointerUp: (e) => _finish(e.pointer),
        onPointerCancel: (e) => _finish(e.pointer),
      ),
    );
  }

  bool _isPointerInsideImage(Offset localPosition) {
    try {
      final cam = widget.map.camera;
      // flutter_map 7.0: `getOffsetFromOrigin` returns the pixel
      // position of a LatLng relative to the map's viewport origin,
      // which is exactly the coordinate space our GestureDetector's
      // localPosition uses.
      final pts = [
        cam.getOffsetFromOrigin(widget.corners.topLeft),
        cam.getOffsetFromOrigin(widget.corners.topRight),
        cam.getOffsetFromOrigin(widget.corners.bottomRight),
        cam.getOffsetFromOrigin(widget.corners.bottomLeft),
      ];
      // Inset the AABB so corner handles (drawn at each corner with a
      // ~22 px radius) take priority over the body-drag hit-test.
      // Otherwise a drag starting on a handle also matched this
      // widget's polygon hit-test and both would fire.
      double minX = pts[0].dx, maxX = pts[0].dx;
      double minY = pts[0].dy, maxY = pts[0].dy;
      for (final o in pts) {
        if (o.dx < minX) minX = o.dx;
        if (o.dx > maxX) maxX = o.dx;
        if (o.dy < minY) minY = o.dy;
        if (o.dy > maxY) maxY = o.dy;
      }
      final rect = Rect.fromLTRB(minX + 24, minY + 24, maxX - 24, maxY - 24);
      return rect.contains(localPosition);
    } catch (_) {
      return false;
    }
  }
}

/// Composite widget that renders:
///   * 4 corner "resize" handles (icon = diagonal arrows) — drag to
///     scale the overlay uniformly around its geographic centre,
///   * 1 centre "move" handle (icon = 4-way arrows) — drag to
///     translate the overlay, with the finger's delta mapped into
///     lat/lng space via the parent's `_screenDeltaToGeo`.
///
/// All 5 handles stay pinned to the overlay even when the map is
/// panned/zoomed underneath, because their on-screen positions are
/// re-projected from geographic coordinates every rebuild via the
/// map's camera.
///
/// **Layout note**: this widget MUST be rendered inside a
/// `Positioned.fill` so the inner Stack has a full-viewport size —
/// otherwise its Positioned children get laid out against a zero-
/// sized parent and the handles "scatter" on the map (which was the
/// previous bug).
class _OverlayHandles extends StatefulWidget {
  const _OverlayHandles({
    required this.map,
    required this.corners,
    required this.centerLat,
    required this.centerLng,
    required this.screenOf,
    required this.onResize,
    required this.onMove,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final MapController map;
  final _Corners corners;
  final double centerLat;
  final double centerLng;

  /// Injected from the parent so that handle positions use the same
  /// rotation-aware projection as the rest of the screen. Returns
  /// null if the camera isn't attached yet.
  final Offset? Function(LatLng) screenOf;

  /// Called with a finger's current absolute screen position while a
  /// corner handle is being dragged.
  final ValueChanged<Offset> onResize;

  /// Called with the incremental screen delta while the centre
  /// handle is being dragged.
  final ValueChanged<Offset> onMove;

  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  State<_OverlayHandles> createState() => _OverlayHandlesState();
}

class _OverlayHandlesState extends State<_OverlayHandles> {
  StreamSubscription<MapEvent>? _sub;

  @override
  void initState() {
    super.initState();
    // Re-project handle positions on every map camera change. Without
    // this the 4 corner + centre handles would render against a stale
    // camera and "drift" whenever the user zooms / pans / rotates
    // (the overlay itself follows the map internally, but our handle
    // dots live in a separate Stack and need explicit re-layout).
    _sub = widget.map.mapEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cornerPts = <Offset?>[
      widget.screenOf(widget.corners.topLeft),
      widget.screenOf(widget.corners.topRight),
      widget.screenOf(widget.corners.bottomLeft),
      widget.screenOf(widget.corners.bottomRight),
    ];
    final centerPt = widget.screenOf(
      LatLng(widget.centerLat, widget.centerLng),
    );
    if (centerPt == null || cornerPts.any((p) => p == null)) {
      return const SizedBox.shrink();
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Four corner handles.
        for (var i = 0; i < 4; i++)
          Positioned(
            left: cornerPts[i]!.dx - 18,
            top: cornerPts[i]!.dy - 18,
            child: _HandleDot(
              icon: PhosphorIconsFill.arrowsOutSimple,
              onDragStart: widget.onDragStart,
              onDragUpdate: (absoluteScreenPos) =>
                  widget.onResize(absoluteScreenPos),
              onDragEnd: widget.onDragEnd,
              useGlobalPosition: true,
            ),
          ),
        // Centre move handle — bigger, different icon so the user
        // can tell them apart at a glance.
        Positioned(
          left: centerPt.dx - 22,
          top: centerPt.dy - 22,
          child: _HandleDot(
            icon: PhosphorIconsFill.arrowsOutCardinal,
            size: 44,
            // Centre handle uses incremental delta (pan-update)
            // because we want "finger movement" → "overlay
            // translation", not "finger position" → "new location".
            useGlobalPosition: false,
            onDragStart: widget.onDragStart,
            onDragUpdate: (delta) => widget.onMove(delta),
            onDragEnd: widget.onDragEnd,
          ),
        ),
      ],
    );
  }
}

/// A single handle widget. Uses a raw [Listener] (not GestureDetector)
/// so multi-touch gestures don't get hijacked — if a second finger
/// lands on the handle while we're already tracking one, we cancel
/// our drag and release control. This lets the user still pinch-zoom
/// or two-finger-rotate the base map even if one of their fingers
/// brushes a handle.
///
/// Modes:
///   * `useGlobalPosition: true`  — emits absolute screen pixel on
///     each move (for corner resize math),
///   * `useGlobalPosition: false` — emits incremental delta on each
///     move (for translation of the overlay centre).
class _HandleDot extends StatefulWidget {
  const _HandleDot({
    required this.icon,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.size = 36,
    this.useGlobalPosition = true,
  });

  final IconData icon;
  final double size;
  final bool useGlobalPosition;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_HandleDot> createState() => _HandleDotState();
}

class _HandleDotState extends State<_HandleDot> {
  int? _activePointer;
  Offset? _lastPos;
  bool _dragLive = false;
  bool _cancelled = false;

  void _onDown(PointerDownEvent e) {
    if (_activePointer != null) {
      // Second finger on the same handle → release our grip so
      // pinch-zoom / rotation can reach the map. Cancel any active
      // drag cleanly.
      if (_dragLive) widget.onDragEnd();
      _dragLive = false;
      _cancelled = true;
      return;
    }
    _activePointer = e.pointer;
    _lastPos = e.position;
    _cancelled = false;
    _dragLive = true;
    widget.onDragStart();
  }

  void _onMove(PointerMoveEvent e) {
    if (_cancelled) return;
    if (e.pointer != _activePointer) return;
    if (widget.useGlobalPosition) {
      widget.onDragUpdate(e.position);
    } else {
      final delta = _lastPos == null ? Offset.zero : e.position - _lastPos!;
      _lastPos = e.position;
      widget.onDragUpdate(delta);
    }
  }

  void _onUp(PointerUpEvent e) {
    _finish(e.pointer);
  }

  void _onCancel(PointerCancelEvent e) {
    _finish(e.pointer);
  }

  void _finish(int pointer) {
    if (_activePointer != pointer) return;
    if (_dragLive && !_cancelled) {
      widget.onDragEnd();
    }
    _activePointer = null;
    _lastPos = null;
    _dragLive = false;
    _cancelled = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgDeepest.withValues(alpha: 0.85),
          border: Border.all(color: AppColors.primaryGlow, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: AppColors.primaryGlow,
          size: widget.size * 0.45,
        ),
      ),
    );
  }
}
