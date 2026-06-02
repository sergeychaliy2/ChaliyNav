import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/providers/layers_provider.dart';

/// In-memory selection of the "focus" layer — the one whose opacity the user
/// is currently tuning via the on-map vertical slider. `null` = no slider shown.
final focusedLayerIdProvider = StateProvider<String?>((_) => null);

/// Vertical opacity slider stuck to the right edge of the map.
/// Appears only when [focusedLayerIdProvider] is non-null and points to a
/// visible layer. User drags → layer opacity updates in real time → user
/// visually sees the underlying layer fade in/out.
class ActiveLayerSlider extends ConsumerWidget {
  const ActiveLayerSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(focusedLayerIdProvider);
    if (id == null) return const SizedBox.shrink();

    final layers = ref.watch(layersProvider).valueOrNull ?? const <MapLayer>[];
    final layer = layers.firstWhere(
      (l) => l.id == id,
      orElse: () => const MapLayer(
        id: '',
        name: '',
        type: MapLayerType.tileUrl,
        source: '',
      ),
    );
    if (layer.id.isEmpty) {
      // Layer deleted — close slider.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(focusedLayerIdProvider.notifier).state = null,
      );
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.bgDeepest.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGlow.withValues(alpha: 0.25),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsDuotone.stack,
                  color: AppColors.primaryGlow, size: 18),
              const SizedBox(height: 4),
              Text(
                '${(layer.opacity * 100).round()}%',
                style: TextStyle(
                  color: AppColors.primaryGlow,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 200,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primaryGlow,
                      inactiveTrackColor: AppColors.glassBorderStrong,
                      thumbColor: Colors.white,
                      overlayColor:
                          AppColors.primary.withValues(alpha: 0.2),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: layer.opacity,
                      onChanged: (v) => ref
                          .read(layersProvider.notifier)
                          .setOpacity(layer.id, v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxWidth: 60),
                child: Text(
                  layer.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () =>
                    ref.read(focusedLayerIdProvider.notifier).state = null,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(PhosphorIconsBold.x,
                      color: AppColors.textTertiary, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
