import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../shared/providers/location_provider.dart';
import '../../../shared/services/compass_service.dart';
import '../widgets/compass_rose.dart';

/// Full-screen compass view — big rose, live numerical heading and
/// cardinal direction, plus a panel of supporting GPS data the user
/// might want to copy down (coordinates, altitude, accuracy, speed).
///
/// Reachable from the speed/accuracy HUD pill: tapping the compass
/// pill on the map screen pushes this. Heading is the same magnetic
/// reading the rest of the app already uses (via
/// [compassHeadingProvider]) so nothing on screen ever drifts out of
/// sync with the map's track-up rotation.
class CompassScreen extends ConsumerWidget {
  const CompassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(compassHeadingProvider).valueOrNull;
    final loc = ref.watch(locationStreamProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Компас',
        subtitle: heading == null
            ? 'Сенсор недоступен'
            : 'Магнитное направление',
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 80,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          child: Column(
            children: [
              // --- Compass rose ---
              Expanded(
                flex: 5,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: heading == null
                        ? const _NoCompass()
                        : CompassRose(headingDeg: heading),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // --- Numeric readout ---
              if (heading != null)
                _HeadingReadout(headingDeg: heading)
              else
                Text(
                  'На устройстве нет магнитного компаса\n'
                  'или сенсор отключён в системных настройках.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: 18),
              // --- GPS data panel ---
              Expanded(
                flex: 4,
                child: _GpsDataPanel(
                  lat: loc?.lat,
                  lng: loc?.lng,
                  altitude: loc?.altitude,
                  accuracy: loc?.accuracy,
                  speed: loc?.speed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadingReadout extends StatelessWidget {
  const _HeadingReadout({required this.headingDeg});
  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    final cardinal = _cardinal(headingDeg);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${headingDeg.round()}°',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 56,
            fontWeight: FontWeight.w300,
            letterSpacing: -2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          cardinal,
          style: TextStyle(
            color: AppColors.primaryGlow,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  static String _cardinal(double deg) {
    const labels = [
      'СЕВЕР',
      'СЕВЕРО-ВОСТОК',
      'ВОСТОК',
      'ЮГО-ВОСТОК',
      'ЮГ',
      'ЮГО-ЗАПАД',
      'ЗАПАД',
      'СЕВЕРО-ЗАПАД',
    ];
    final idx = ((deg + 22.5) ~/ 45) % 8;
    return labels[idx];
  }
}

class _GpsDataPanel extends StatelessWidget {
  const _GpsDataPanel({
    this.lat,
    this.lng,
    this.altitude,
    this.accuracy,
    this.speed,
  });

  final double? lat;
  final double? lng;
  final double? altitude;
  final double? accuracy;
  final double? speed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GPS-ДАННЫЕ',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _row(
                      icon: PhosphorIconsDuotone.crosshair,
                      label: 'Широта',
                      value: lat == null
                          ? '—'
                          : '${lat!.toStringAsFixed(5)}°',
                    ),
                    _row(
                      icon: PhosphorIconsDuotone.crosshair,
                      label: 'Долгота',
                      value: lng == null
                          ? '—'
                          : '${lng!.toStringAsFixed(5)}°',
                    ),
                    _row(
                      icon: PhosphorIconsDuotone.mountains,
                      label: 'Высота',
                      value: altitude == null
                          ? '—'
                          : '${altitude!.round()} м',
                    ),
                    _row(
                      icon: PhosphorIconsDuotone.crosshairSimple,
                      label: 'Точность',
                      value: accuracy == null
                          ? '—'
                          : Formatters.accuracy(accuracy!),
                    ),
                    _row(
                      icon: PhosphorIconsDuotone.gauge,
                      label: 'Скорость',
                      value: Formatters.speed(speed ?? 0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primaryGlow, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoCompass extends StatelessWidget {
  const _NoCompass();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsDuotone.compass,
            size: 96,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 14),
          Text(
            'Нет данных компаса',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
