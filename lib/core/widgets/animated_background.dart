import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Subtle animated aurora-like gradient background for splash / empty states.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, this.child, this.intensity = 1.0});

  final Widget? child;
  final double intensity;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 2 * math.pi;
        return Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: Stack(
            children: [
              _Blob(
                left: 120 + 60 * math.cos(t),
                top: 80 + 40 * math.sin(t),
                color: AppColors.primary.withValues(alpha: 0.25 * widget.intensity),
                size: 280,
              ),
              _Blob(
                right: 40 + 50 * math.sin(t * 0.8),
                top: 200 + 70 * math.cos(t * 0.8),
                color: AppColors.accentCyan.withValues(alpha: 0.12 * widget.intensity),
                size: 220,
              ),
              _Blob(
                left: 60 + 40 * math.cos(t * 1.2),
                bottom: 120 + 60 * math.sin(t * 1.2),
                color: AppColors.primaryGlow.withValues(alpha: 0.15 * widget.intensity),
                size: 260,
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.color,
    required this.size,
  });

  final double? left, right, top, bottom;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
