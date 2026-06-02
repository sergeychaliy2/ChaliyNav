import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;

import '../../../shared/models/map_layer.dart';

/// Drop-in replacement for flutter_map's `OverlayImageLayer` that lets
/// callers pick the `FilterQuality` that actually reaches the inner
/// `Image` widget.
///
/// Why we need this: flutter_map 7.0.2's `BaseOverlayImage.build()`
/// hard-codes `Image(...)` without a `filterQuality` argument, so the
/// image always renders with Flutter's default `FilterQuality.medium`
/// (bilinear). That turns discrete land-use / forestry classification
/// scans into a smeared mess the moment the user zooms past the
/// source resolution. The `filterQuality` parameter on
/// `RotatedOverlayImage` attaches only to the outer `Transform`,
/// which cannot reverse the damage already done at the Image draw
/// step.
///
/// We replicate the camera-projection + transform math verbatim from
/// flutter_map's `RotatedOverlayImage._render` but construct the
/// `Image` ourselves with the caller-supplied quality.
class SharpOverlayImageLayer extends StatelessWidget {
  const SharpOverlayImageLayer({
    super.key,
    required this.overlays,
  });

  final List<SharpOverlayImage> overlays;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    // Reproduce flutter_map's internal `MobileLayerTransformer` (it's
    // library-private, so we can't import it). Fills the full camera
    // size and applies the base-map rotation around the viewport
    // centre, so our absolute-pixel Positioned children stay glued to
    // geography when the user two-finger-rotates the map.
    return OverflowBox(
      minWidth: camera.size.x,
      maxWidth: camera.size.x,
      minHeight: camera.size.y,
      maxHeight: camera.size.y,
      child: Transform.rotate(
        angle: camera.rotationRad,
        child: Stack(
          children: [
            for (final o in overlays) o._build(camera: camera),
          ],
        ),
      ),
    );
  }
}

/// Sharp counterpart to `RotatedOverlayImage`. Three corner points
/// (top-left, bottom-left, bottom-right) drive an affine transform;
/// the top-right is derived. `filterQuality` is respected both by the
/// inner `Image` (so pixels stay crisp during scale) and by the outer
/// `Transform` (so the matrix application doesn't re-blur them).
class SharpOverlayImage {
  const SharpOverlayImage({
    required this.topLeftCorner,
    required this.bottomLeftCorner,
    required this.bottomRightCorner,
    required this.imageProvider,
    this.opacity = 1.0,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.none,
  });

  final LatLng topLeftCorner;
  final LatLng bottomLeftCorner;
  final LatLng bottomRightCorner;
  final ImageProvider imageProvider;
  final double opacity;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;

  Widget _build({required MapCamera camera}) {
    // Project the three given corners into pixel space, then derive
    // the fourth (top-right) via vector arithmetic.
    final pxTopLeft = camera.project(topLeftCorner) - camera.pixelOrigin;
    final pxBottomRight =
        camera.project(bottomRightCorner) - camera.pixelOrigin;
    final pxBottomLeft = camera.project(bottomLeftCorner) - camera.pixelOrigin;
    final pxTopRight = pxTopLeft - pxBottomLeft + pxBottomRight;

    // Axis-aligned bounding box that encloses the quadrilateral.
    final bounds = Bounds<double>(pxTopLeft, pxBottomRight)
        .extend(pxTopRight)
        .extend(pxBottomLeft);

    // Basis vectors of the image's coordinate system within the AABB.
    final vectorX = (pxTopRight - pxTopLeft) / bounds.size.x;
    final vectorY = (pxBottomLeft - pxTopLeft) / bounds.size.y;
    final offset = pxTopLeft - bounds.topLeft;

    final a = vectorX.x;
    final b = vectorX.y;
    final c = vectorY.x;
    final d = vectorY.y;
    final tx = offset.x;
    final ty = offset.y;

    return Positioned(
      left: bounds.topLeft.x,
      top: bounds.topLeft.y,
      width: bounds.size.x,
      height: bounds.size.y,
      child: Transform(
        transform: Matrix4(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1),
        // INTENTIONALLY NOT setting `filterQuality` on the Transform.
        //
        // A non-null value here forces Flutter to rasterize the child
        // into an offscreen layer via `saveLayer`, sized to the
        // child's layout bounds. For a deeply-zoomed overlay on a
        // large scan, those bounds exceed Android's
        // `GL_MAX_TEXTURE_SIZE` (commonly 4096 on mid-range phones)
        // — Skia then has to down-sample the intermediate bitmap,
        // which is the "мыло" the user saw at any zoom level.
        //
        // Without the saveLayer the transform is applied directly by
        // the RenderTransform and the full native resolution of the
        // source image flows through to the draw call unmodified.
        // Rotation aliasing is the trade-off, but the overwhelmingly
        // common case — axis-aligned bbox from a world file — has
        // zero rotation and therefore zero artefacts.
        child: Image(
          image: imageProvider,
          fit: BoxFit.fill,
          // Multiply the RGB by the requested opacity. Matches how
          // flutter_map's own OverlayImage composites.
          color: Color.fromRGBO(255, 255, 255, opacity),
          colorBlendMode: BlendMode.modulate,
          gaplessPlayback: gaplessPlayback,
          // This is the filter that actually samples source pixels
          // when the Image widget draws into the canvas at its
          // layout size. Setting it here (which stock flutter_map
          // does NOT) is why overlays in this app stay crisp.
          filterQuality: filterQuality,
        ),
      ),
    );
  }
}

/// Builds a list of [SharpOverlayImage]s that together render the
/// entire tiled raster, each piece covering its own sub-rectangle of
/// the layer's geographic bounds.
///
/// This is the payoff half of the tile-based overlay feature: the
/// import side sliced an N×M-MP scan into 2048×2048 pieces to stay
/// under Android's `GL_MAX_TEXTURE_SIZE`; here at render time we
/// position each piece so that together they reproduce the original
/// scan at full native resolution, with no silent down-sampling by
/// Skia on its way to the GPU.
///
/// Because rotation is applied uniformly to the layer bounds, every
/// tile is rotated by the same angle about the same geographic
/// centre — not its own centre. We compute each tile's rotated
/// corner triple in metre-space and convert back to lat/lng, exactly
/// as the unrotated quadrilateral case would, just around a specific
/// sub-rectangle.
///
/// `opacity` and `filterQuality` are uniform across tiles so the
/// whole overlay behaves as one logical image.
List<SharpOverlayImage> buildTiledOverlay({
  required LayerBounds bounds,
  required LayerTileGrid grid,
  required String tileDir,
  double opacity = 1.0,
  FilterQuality filterQuality = FilterQuality.medium,
}) {
  final out = <SharpOverlayImage>[];

  // Work in metre-space around the layer centre so rotation doesn't
  // distort when latitude ≠ 0. Identical approach to user_layers_stack
  // for the non-tiled case.
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * math.cos(bounds.centerLat * math.pi / 180.0);

  final halfWM = bounds.widthDeg / 2 * mPerDegLng;
  final halfHM = bounds.heightDeg / 2 * mPerDegLat;

  final theta = bounds.rotationDeg * math.pi / 180.0;
  final sinT = math.sin(theta);
  final cosT = math.cos(theta);
  Offset rotM(Offset m) => Offset(
        m.dx * cosT - m.dy * sinT,
        m.dx * sinT + m.dy * cosT,
      );

  LatLng toLL(Offset m) => LatLng(
        bounds.centerLat + m.dy / mPerDegLat,
        bounds.centerLng + m.dx / mPerDegLng,
      );

  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      // Tile pixel extent inside the source image. Last column /
      // row may be narrower / shorter than the nominal tile size.
      final x0 = c * grid.tileWidth;
      final y0 = r * grid.tileHeight;
      final x1 = math.min(x0 + grid.tileWidth, grid.srcWidth);
      final y1 = math.min(y0 + grid.tileHeight, grid.srcHeight);

      // Normalised fraction of the source image each tile covers
      // (0.0 at left/top, 1.0 at right/bottom).
      final fx0 = x0 / grid.srcWidth;
      final fy0 = y0 / grid.srcHeight;
      final fx1 = x1 / grid.srcWidth;
      final fy1 = y1 / grid.srcHeight;

      // Convert fractions to metre-space offsets from the layer
      // centre, then rotate and add to centre to get geographic
      // corners.
      double metresX(double fx) => (fx - 0.5) * 2 * halfWM;
      double metresY(double fy) =>
          (0.5 - fy) * 2 * halfHM; // image y-down vs lat y-up

      final tlM = rotM(Offset(metresX(fx0), metresY(fy0)));
      final blM = rotM(Offset(metresX(fx0), metresY(fy1)));
      final brM = rotM(Offset(metresX(fx1), metresY(fy1)));

      out.add(SharpOverlayImage(
        topLeftCorner: toLL(tlM),
        bottomLeftCorner: toLL(blM),
        bottomRightCorner: toLL(brM),
        imageProvider: FileImage(File(p.join(tileDir, 'r${r}_c$c.png'))),
        opacity: opacity,
        filterQuality: filterQuality,
      ));
    }
  }

  return out;
}

/// Build one [SharpOverlayImage] per tile in a [LayerTileMosaic].
/// Each tile gets its own lat/lng rectangle straight from the
/// manifest — unlike [buildTiledOverlay] we don't derive sub-bounds
/// from a parent rectangle, because mosaic tiles (Garmin JNX etc.)
/// aren't necessarily a perfect subdivision of the layer's bbox.
///
/// Mosaic overlays are always axis-aligned; rotation is intentionally
/// NOT supported here. If the underlying format represents tiles
/// with independent bounds they're authoritative — overriding with
/// a user-edited rotation would desynchronise tile placement.
List<SharpOverlayImage> buildMosaicOverlay({
  required LayerTileMosaic mosaic,
  required String tileDir,
  double opacity = 1.0,
  FilterQuality filterQuality = FilterQuality.medium,
}) {
  return [
    for (final t in mosaic.tiles)
      SharpOverlayImage(
        topLeftCorner: LatLng(t.bounds.northLat, t.bounds.westLng),
        bottomLeftCorner: LatLng(t.bounds.southLat, t.bounds.westLng),
        bottomRightCorner: LatLng(t.bounds.southLat, t.bounds.eastLng),
        imageProvider: FileImage(File(p.join(tileDir, t.file))),
        opacity: opacity,
        filterQuality: filterQuality,
      ),
  ];
}
