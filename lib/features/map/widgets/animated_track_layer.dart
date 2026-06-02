import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Fancy live-recording track layer:
///   - Wide soft glow underneath the path
///   - Main polyline on top
///   - Pulsing head marker at the last point
class AnimatedRecordingTrack extends StatelessWidget {
  const AnimatedRecordingTrack({
    super.key,
    required this.points,
    required this.color,
    required this.width,
  });

  final List<LatLng> points;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      if (points.isEmpty) return const SizedBox.shrink();
      return MarkerLayer(
        markers: [
          Marker(
            point: points.last,
            width: 36,
            height: 36,
            child: _PulsingHead(color: color),
          ),
        ],
      );
    }

    return Stack(
      children: [
        // Outer soft glow
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: color.withValues(alpha: 0.22),
              strokeWidth: width * 2.6,
            ),
          ],
        ),
        // Main stroke
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              color: color,
              strokeWidth: width,
              borderColor: Colors.black.withValues(alpha: 0.45),
              borderStrokeWidth: 1.4,
            ),
          ],
        ),
        // Animated leading head marker
        MarkerLayer(
          markers: [
            Marker(
              point: points.last,
              width: 44,
              height: 44,
              child: _PulsingHead(color: color),
            ),
          ],
        ),
      ],
    );
  }
}

class _PulsingHead extends StatefulWidget {
  const _PulsingHead({required this.color});
  final Color color;

  @override
  State<_PulsingHead> createState() => _PulsingHeadState();
}

class _PulsingHeadState extends State<_PulsingHead>
    with TickerProviderStateMixin {
  late final AnimationController _ring;
  late final AnimationController _core;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _core = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ring.dispose();
    _core.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ring, _core]),
      builder: (_, __) {
        final t = _ring.value;
        final scale = 1 + t * 2.5; // 1 → 3.5
        final ringOpacity = (1 - t).clamp(0.0, 1.0) * 0.55;
        final coreScale = 0.9 + _core.value * 0.22;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: ringOpacity),
                    width: 2,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: coreScale,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.9),
                      blurRadius: 14,
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Layer for saved / historical tracks with subtle glow (no animation).
class StaticTrackGlow extends StatelessWidget {
  const StaticTrackGlow({
    super.key,
    required this.points,
    required this.color,
    required this.width,
  });

  final List<LatLng> points;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return Stack(
      children: [
        PolylineLayer(polylines: [
          Polyline(
            points: points,
            color: color.withValues(alpha: 0.2),
            strokeWidth: width * 2.4,
          ),
        ]),
        PolylineLayer(polylines: [
          Polyline(
            points: points,
            color: color,
            strokeWidth: width,
            borderColor: Colors.black.withValues(alpha: 0.35),
            borderStrokeWidth: 1,
          ),
        ]),
      ],
    );
  }
}
