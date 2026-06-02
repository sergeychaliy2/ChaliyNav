import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/providers/navigation_target_provider.dart';
import '../../../shared/services/compass_service.dart';

/// Floating overlay shown only while user has a navigation target.
/// Big directional arrow + distance + azimuth + cardinal + cancel button.
class NavigationHud extends ConsumerWidget {
  const NavigationHud({super.key, required this.currentLocation});

  final GeoPoint? currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(navigationTargetProvider);
    if (target == null) return const SizedBox.shrink();

    final loc = currentLocation;
    final heading = ref.watch(compassHeadingProvider).valueOrNull ?? 0;

    double distance = double.nan;
    double bearing = 0;
    if (loc != null) {
      distance = Geo.distance(loc, target.coord);
      bearing = Geo.bearing(loc, target.coord);
    }
    final relative = Geo.relativeBearing(bearing, heading);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.bgDeepest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: target.icon.color.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: target.icon.color.withValues(alpha: 0.35),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ArrowDial(
                angleDeg: relative,
                color: target.icon.color,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    target.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc == null
                        ? AppStrings.of(context).hudSearchingSignal
                        : '${Formatters.distance(distance)} · ${bearing.toStringAsFixed(0)}° ${Geo.cardinal(bearing)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () =>
                    ref.read(navigationTargetProvider.notifier).state = null,
                icon: Icon(PhosphorIconsBold.x,
                    color: AppColors.textTertiary, size: 16),
                tooltip: AppStrings.of(context).pointsStopNavigation,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.2, end: 0);
  }
}

class _ArrowDial extends StatelessWidget {
  const _ArrowDial({required this.angleDeg, required this.color});

  final double angleDeg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: angleDeg, end: angleDeg),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (ctx, value, _) {
          return Transform.rotate(
            angle: value * math.pi / 180.0,
            child: Icon(
              PhosphorIconsFill.navigationArrow,
              color: color,
              size: 22,
            ),
          );
        },
      ),
    );
  }
}
