import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/poi_category.dart';

/// Unified POI icon renderer: SVG asset when present, Phosphor fallback otherwise.
class PoiMarkerIcon extends StatelessWidget {
  const PoiMarkerIcon({
    super.key,
    required this.icon,
    this.size = 36,
    this.ring = true,
  });

  final PoiIcon icon;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final color = icon.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.9),
            color.withValues(alpha: 0.6),
          ],
        ),
        border: ring
            ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: _renderGlyph(size * 0.55),
      ),
    );
  }

  Widget _renderGlyph(double glyphSize) {
    if (icon.svgAsset != null) {
      return SvgPicture.asset(
        icon.svgAsset!,
        width: glyphSize,
        height: glyphSize,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        placeholderBuilder: (_) =>
            Icon(icon.fallbackIcon ?? icon.category.icon,
                color: Colors.white, size: glyphSize),
      );
    }
    return Icon(
      icon.fallbackIcon ?? icon.category.icon,
      color: Colors.white,
      size: glyphSize,
    );
  }
}

/// Map marker: pin shape + small "title" badge above it. Label shown only
/// when the pin is above a zoom threshold (handled by caller via [showLabel]).
class PoiMarkerPin extends StatelessWidget {
  const PoiMarkerPin({
    super.key,
    required this.icon,
    this.size = 44,
    this.label,
    this.showLabel = false,
  });

  final PoiIcon icon;
  final double size;
  final String? label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel && label != null && label!.trim().isNotEmpty)
          _MarkerLabel(text: label!, color: icon.color),
        SizedBox(
          width: size,
          height: size * 1.25,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                bottom: 0,
                child: Container(
                  width: 4,
                  height: size * 0.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [icon.color, icon.color.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: size * 0.3,
                child: Container(
                  width: size * 0.5,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.shadowSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              PoiMarkerIcon(icon: icon, size: size),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarkerLabel extends StatelessWidget {
  const _MarkerLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(maxWidth: 120),
      decoration: BoxDecoration(
        color: AppColors.bgDeepest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 3),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Cluster bubble — shown in place of many overlapping markers.
class PoiClusterBadge extends StatelessWidget {
  const PoiClusterBadge({
    super.key,
    required this.count,
    required this.color,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = _sizeFor(count);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  double _sizeFor(int c) {
    if (c < 10) return 36;
    if (c < 50) return 42;
    if (c < 100) return 48;
    return 54;
  }
}
