import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/compass_service.dart';

/// Yandex-style user position marker:
///   - Pulsing translucent accuracy halo
///   - Central blue dot with white stroke
///   - Heading cone — translucent gradient sector in the direction the
///     phone is pointing. Rotates live with the device compass.
class UserLocationMarker extends ConsumerWidget {
  const UserLocationMarker({super.key, this.size = 80});

  /// Total widget size (cone included). Dot is proportional.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(compassHeadingProvider).valueOrNull;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (heading != null)
            // Smoothly animate rotation to avoid jitter on noisy readings.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: heading, end: heading),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (_, value, __) => Transform.rotate(
                angle: value * math.pi / 180.0,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _HeadingConePainter(),
                ),
              ),
            ),
          const _PulsingDot(),
        ],
      ),
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    // 55° wide cone, pointing "up" (north-aligned before rotation).
    const sweepDeg = 55.0;
    const sweepRad = sweepDeg * math.pi / 180.0;
    const startRad = -math.pi / 2 - sweepRad / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = RadialGradient(
      colors: [
        AppColors.primaryBright.withValues(alpha: 0.6),
        AppColors.primaryGlow.withValues(alpha: 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, startRad, sweepRad, false)
      ..close();
    canvas.drawPath(path, paint);

    // Subtle outline to read clearly on any map background.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.primaryGlow.withValues(alpha: 0.35);
    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(covariant _HeadingConePainter oldDelegate) => false;
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28 + 20 * t,
              height: 28 + 20 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGlow.withValues(alpha: 0.4 * (1 - t)),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBright,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBright.withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
