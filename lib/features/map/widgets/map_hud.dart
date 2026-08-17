import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/services/compass_service.dart';
import 'compass_rose.dart';

/// Top-left speed/accuracy/compass pills.
class MapTopHud extends ConsumerWidget {
  const MapTopHud({
    super.key,
    required this.location,
    required this.showSpeed,
    required this.showAccuracy,
    required this.showCompass,
    this.compassExpanded = false,
    this.onCompassTap,
  });

  final GeoPoint? location;
  final bool showSpeed;
  final bool showAccuracy;
  final bool showCompass;
  final bool compassExpanded;
  final VoidCallback? onCompassTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Compass pill is independent of GPS — it can show even when
    // we're still hunting for a fix (magnetic sensor is always
    // available). The HUD row only ever holds the COMPACT pill;
    // the expanded variant lives in its own fixed-position card
    // (`CompassExpandedBadge`) outside of this row, so a long
    // numeric value never shoves the speed/accuracy capsules around
    // and the badge stays visible on the same spot regardless of
    // how many other pills are turned on.
    final headingPill = (showCompass && !compassExpanded)
        ? _CompassPill(onTap: onCompassTap)
        : null;

    if (location == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _glassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsDuotone.crosshair,
                  color: AppColors.textTertiary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  AppStrings.of(context).hudSearchingSignal,
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (headingPill != null) ...[
            const SizedBox(width: 8),
            headingPill,
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSpeed)
          _glassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsDuotone.gauge,
                  color: AppColors.primaryGlow,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  Formatters.speed(location!.speed ?? 0),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        if (showSpeed && showAccuracy) const SizedBox(width: 8),
        if (showAccuracy)
          _glassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsDuotone.crosshairSimple,
                  color: AppColors.accentCyan,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  Formatters.accuracy(location!.accuracy),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        if (headingPill != null) ...[
          if (showSpeed || showAccuracy) const SizedBox(width: 8),
          headingPill,
        ],
      ],
    );
  }

  static Widget _glassPillTappable({
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: _glassPill(child: child),
      ),
    );
  }

  static Widget _glassPill({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Compact compass pill matching the speed/accuracy ones — the
/// little glass capsule shows the device's current magnetic heading
/// (e.g. "127° ЮВ") and pushes a full-screen compass screen on tap.
/// Subscribes directly to [compassHeadingProvider] so it doesn't
/// rebuild the rest of the HUD when the sensor ticks.
class _CompassPill extends ConsumerWidget {
  const _CompassPill({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(compassHeadingProvider).valueOrNull;
    final cardinal = heading == null ? '—' : _cardinal(heading);
    final value = heading == null ? '—°' : '${heading.round()}°';
    // Each text occupies a fixed-width slot — wide enough for the
    // longest possible value ("-179", "СЗ") — so single- and three-
    // digit values render at the same overall pill width. Without
    // these the pill grew / shrank as the user rotated and visibly
    // jittered the speed/accuracy capsules next to it.
    return MapTopHud._glassPillTappable(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsDuotone.compass,
            color: AppColors.accentRose,
            size: 14,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 38,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 20,
            child: Text(
              cardinal,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _cardinal(double deg) {
    const labels = ['С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ'];
    final idx = ((deg + 22.5) ~/ 45) % 8;
    return labels[idx];
  }
}

/// Standalone fixed-size compass card. Sits in its own corner of
/// the map (placed via [Positioned] from `map_screen.dart`) rather
/// than inside the HUD pill row — when many other HUD pills are
/// active the inline pill got squeezed off-screen, and varying digit
/// counts ("88°" vs "-112°") made it visibly resize between updates.
/// A fixed 124×134 card removes both problems.
class CompassExpandedBadge extends ConsumerWidget {
  const CompassExpandedBadge({super.key, this.onTap});
  final VoidCallback? onTap;

  /// Width / height of the badge. Public so callers (the map screen)
  /// can place it without duplicating the constants.
  static const double width = 124;
  static const double height = 134;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(compassHeadingProvider).valueOrNull;
    final cardinal = heading == null ? '—' : _cardinal(heading);
    final value = heading == null ? '—°' : '${heading.round()}°';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: width,
              height: height,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgDeep.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top row: icon + degrees + cardinal. Each text is
                  // wrapped in a fixed-width SizedBox so a 4-char
                  // value like "-179" doesn't push neighbours and
                  // shift the whole row's centre.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIconsDuotone.compass,
                        color: AppColors.accentRose,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 44,
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 22,
                        child: Text(
                          cardinal,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Spinning rose — same renderer as the full screen
                  // (just at compact tick density), so the badge
                  // looks like a miniature of what tap opens.
                  if (heading != null)
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: CompassRose(
                        headingDeg: heading,
                        showPointer: false,
                        tickStyle: CompassRoseTickStyle.compact,
                      ),
                    )
                  else
                    const SizedBox(height: 86),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _cardinal(double deg) {
    const labels = ['С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ'];
    final idx = ((deg + 22.5) ~/ 45) % 8;
    return labels[idx];
  }
}

/// Bottom-right floating actions column.
class MapActionsColumn extends StatelessWidget {
  const MapActionsColumn({
    super.key,
    required this.onLayers,
    required this.onDownloadArea,
    required this.onWeather,
    required this.weatherActive,
    required this.onCenter,
    required this.onRecord,
    required this.onAddPoint,
    required this.onMeasure,
    required this.isRecording,
    required this.measureActive,
    required this.followMode,
  });

  final VoidCallback onLayers;
  final VoidCallback onDownloadArea;
  final VoidCallback onWeather;
  final bool weatherActive;
  final VoidCallback onCenter;
  final VoidCallback onRecord;
  final VoidCallback onAddPoint;
  final VoidCallback onMeasure;
  final bool isRecording;
  final bool measureActive;
  final int followMode; // 0=none, 1=follow, 2=follow+heading

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final (centerIcon, centerColor) = switch (followMode) {
      1 => (PhosphorIconsFill.navigationArrow, AppColors.primaryGlow),
      2 => (PhosphorIconsFill.compass, AppColors.accentCyan),
      _ => (PhosphorIconsDuotone.navigationArrow, AppColors.textPrimary),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionBtn(
          icon: PhosphorIconsDuotone.stack,
          onTap: onLayers,
          tooltip: s.mapLayers,
        ),
        const SizedBox(height: 10),
        _ActionBtn(
          icon: PhosphorIconsDuotone.downloadSimple,
          onTap: onDownloadArea,
          tooltip: s.mapDownloadArea,
        ),
        const SizedBox(height: 10),
        _ActionBtn(
          icon: PhosphorIconsDuotone.cloudSun,
          onTap: onWeather,
          tooltip: s.mapWeather,
          active: weatherActive,
          activeColor: AppColors.accentAmber,
        ),
        const SizedBox(height: 10),
        _ActionBtn(
          icon: PhosphorIconsDuotone.ruler,
          onTap: onMeasure,
          tooltip: s.mapMeasure,
          active: measureActive,
          activeColor: AppColors.accentCyan,
        ),
        const SizedBox(height: 10),
        _ActionBtn(
          icon: centerIcon,
          onTap: onCenter,
          tooltip: s.mapCenter,
          active: followMode != 0,
          activeColor: centerColor,
        ),
        const SizedBox(height: 10),
        _ActionBtn(
          icon: isRecording
              ? PhosphorIconsFill.stopCircle
              : PhosphorIconsDuotone.record,
          onTap: onRecord,
          tooltip: isRecording ? s.mapRecordStop : s.mapRecord,
          active: isRecording,
          activeColor: AppColors.accentRose,
        ),
        const SizedBox(height: 10),
        _ActionBtn(
          icon: PhosphorIconsFill.mapPin,
          onTap: onAddPoint,
          tooltip: s.mapNewPoint,
          primary: true,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.primary = false,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool primary;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? AppColors.primaryBright
        : AppColors.bgElevated.withValues(alpha: 0.85);
    final iconColor = primary
        ? Colors.white
        : active
            ? (activeColor ?? AppColors.accentRose)
            : AppColors.textPrimary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppColors.glassBorder,
                  ),
                  boxShadow: primary
                      ? [
                          BoxShadow(
                            color: AppColors.primaryBright
                                .withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-center recording indicator (live distance + duration + Stop).
class RecordingBadge extends StatelessWidget {
  const RecordingBadge({
    super.key,
    required this.distanceM,
    required this.elapsed,
    required this.color,
    this.onStop,
  });

  final double distanceM;
  final Duration elapsed;
  final Color color;

  /// If provided, renders a compact Stop button at the trailing edge.
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 10, onStop == null ? 18 : 4, 10),
          decoration: BoxDecoration(
            color: AppColors.bgDeepest.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pulse(color: color),
              const SizedBox(width: 10),
              Text(
                AppStrings.of(context).hudRecordingBadge,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 14, color: AppColors.glassBorder),
              const SizedBox(width: 14),
              Text(
                Formatters.distance(distanceM),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Text('·',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              const SizedBox(width: 10),
              Text(
                Formatters.duration(elapsed),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (onStop != null) ...[
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onStop,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentRose.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.accentRose.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsFill.stopCircle,
                              color: AppColors.accentRose, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.of(context).commonStop,
                            style: const TextStyle(
                              color: AppColors.accentRose,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.color});
  final Color color;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6 + 0.4 * _c.value),
              blurRadius: 6 + 8 * _c.value,
              spreadRadius: 1 + 2 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}
