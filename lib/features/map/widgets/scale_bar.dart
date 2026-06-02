import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/theme/app_colors.dart';

/// Lightweight self-drawn scale bar. Works for Web Mercator (the default
/// projection used by flutter_map) and takes latitude distortion into account.
///
/// Place inside FlutterMap's children list OR as a stacked widget that watches
/// the map's MapCamera via MapEventStreamListener. The simpler version below
/// consumes MapCamera from the MapController.
class MapScaleBar extends StatelessWidget {
  const MapScaleBar({
    super.key,
    required this.controller,
    this.width = 150,
  });

  final MapController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: controller.mapEventStream,
      builder: (ctx, _) {
        double zoom;
        double lat;
        try {
          zoom = controller.camera.zoom;
          lat = controller.camera.center.latitude;
        } catch (_) {
          return const SizedBox.shrink();
        }
        return _buildBar(zoom, lat);
      },
    );
  }

  Widget _buildBar(double zoom, double lat) {
    // meters per pixel at given zoom/lat for Web Mercator
    final mpp = _metersPerPixel(zoom, lat);
    // Find a "nice" round distance that fits in the target width.
    final rawMeters = mpp * width;
    final niceMeters = _niceNumber(rawMeters);
    final barPx = niceMeters / mpp;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDistance(niceMeters),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: barPx.clamp(30, width).toDouble(),
                height: 8,
                child: CustomPaint(painter: _ScaleBarPainter()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _metersPerPixel(double zoom, double latDeg) {
    const earthCircumference = 40075016.686; // meters
    final latRad = latDeg * math.pi / 180.0;
    return earthCircumference * math.cos(latRad) / math.pow(2, zoom + 8);
  }

  /// Snap to 1, 2, 2.5, 5, then next order of magnitude.
  static double _niceNumber(double raw) {
    if (raw <= 0) return 1;
    final exp = (math.log(raw) / math.ln10).floor();
    final base = math.pow(10, exp).toDouble();
    final f = raw / base;
    double nice;
    if (f < 1.5) {
      nice = 1;
    } else if (f < 3) {
      nice = 2;
    } else if (f < 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * base;
  }

  static String _formatDistance(double m) {
    if (m < 1) return '${(m * 100).round()} см';
    if (m < 1000) return '${m.round()} м';
    final km = m / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} км';
  }
}

class _ScaleBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // left tick
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), p);
    // right tick
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, size.height), p);
    // horizontal line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
