import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Glassmorphism card — frosted surface with border + blur.
/// Use as a container throughout the app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.blur = 20,
    this.strong = false,
    this.onTap,
    this.borderColor,
    this.fillColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final bool strong;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? fillColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final border = borderColor ??
        (strong ? AppColors.glassBorderStrong : AppColors.glassBorder);
    final fill = fillColor ??
        (strong ? AppColors.glassFillStrong : AppColors.glassFill);

    // Inner content — uses `child` as leaf.
    Widget content = Container(
      decoration: BoxDecoration(
        color: gradient == null ? fill : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: border, width: 1),
      ),
      padding: padding,
      child: child,
    );

    // Wrap content in InkWell BELOW it so interactive children (buttons,
    // TextField, etc.) receive taps first — InkWell only fires for taps
    // on empty areas of the card. (Previously an overlaid InkWell absorbed
    // every tap and broke nested buttons like "Скачать для offline".)
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: AppColors.primaryGlow.withValues(alpha: 0.12),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: content,
        ),
      );
    }

    Widget clipped = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    if (margin != null) {
      clipped = Padding(padding: margin!, child: clipped);
    }

    return clipped;
  }
}
