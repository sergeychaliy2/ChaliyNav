import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/providers/layers_provider.dart';
import 'active_layer_slider.dart';
import 'import_layer_sheet.dart';

/// Horizontal glass bar at the top of the map with a chip per user layer —
/// one tap toggles visibility, long-press opens opacity slider. Appears only
/// when the user actually has some layers; otherwise hidden.
class QuickLayersBar extends ConsumerWidget {
  const QuickLayersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(layersProvider).valueOrNull ?? const <MapLayer>[];
    if (layers.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, minHeight: 36),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final l in layers) ...[
                    _LayerChip(layer: l),
                    const SizedBox(width: 6),
                  ],
                  _AddButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerChip extends ConsumerWidget {
  const _LayerChip({required this.layer});
  final MapLayer layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(focusedLayerIdProvider) == layer.id;
    return GestureDetector(
      onTap: () {
        // Tap on an already-visible layer focuses it (shows side slider).
        // Tap on an invisible/other-focus layer toggles visibility.
        if (layer.visible && !focused) {
          ref.read(focusedLayerIdProvider.notifier).state = layer.id;
          return;
        }
        if (focused) {
          // Toggle off the side slider.
          ref.read(focusedLayerIdProvider.notifier).state = null;
          return;
        }
        ref.read(layersProvider.notifier).setVisible(layer.id, !layer.visible);
      },
      onLongPress: () => _openOpacity(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: focused
              ? AppColors.primaryGlow.withValues(alpha: 0.25)
              : layer.visible
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.glassFill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: focused
                ? AppColors.primaryGlow
                : layer.visible
                    ? AppColors.primaryGlow.withValues(alpha: 0.5)
                    : AppColors.glassBorder,
            width: focused ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              layer.visible
                  ? PhosphorIconsDuotone.eye
                  : PhosphorIconsDuotone.eyeSlash,
              color: layer.visible
                  ? AppColors.primaryGlow
                  : AppColors.textTertiary,
              size: 13,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                layer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: layer.visible
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight:
                      layer.visible ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (layer.visible && layer.opacity < 0.99) ...[
              const SizedBox(width: 6),
              Text(
                '${(layer.opacity * 100).round()}%',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openOpacity(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OpacitySheet(layer: layer),
    );
  }
}

class _OpacitySheet extends ConsumerStatefulWidget {
  const _OpacitySheet({required this.layer});
  final MapLayer layer;

  @override
  ConsumerState<_OpacitySheet> createState() => _OpacitySheetState();
}

class _OpacitySheetState extends ConsumerState<_OpacitySheet> {
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _opacity = widget.layer.opacity;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(PhosphorIconsDuotone.stack,
                  color: AppColors.primaryGlow, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.layer.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(_opacity * 100).round()}%',
                style: TextStyle(
                  color: AppColors.primaryGlow,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Прозрачность',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryGlow,
              inactiveTrackColor: AppColors.glassBorderStrong,
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: _opacity,
              onChanged: (v) {
                setState(() => _opacity = v);
                ref
                    .read(layersProvider.notifier)
                    .setOpacity(widget.layer.id, v);
              },
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ref.read(layersProvider.notifier).remove(widget.layer.id);
              Navigator.of(context).pop();
            },
            icon: Icon(PhosphorIconsDuotone.trash),
            label: const Text('Удалить слой'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ImportLayerSheet(),
            fullscreenDialog: true,
          ),
        );
      },
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.3),
          border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.5)),
        ),
        child: Icon(PhosphorIconsBold.plus,
            color: AppColors.primaryGlow, size: 14),
      ),
    );
  }
}
