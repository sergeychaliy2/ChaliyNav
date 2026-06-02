import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/providers/layers_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/services/layers_service.dart';
import '../screens/georeference_screen.dart';
import 'import_layer_sheet.dart';

/// Bottom sheet with base-map selector + user layers stack (opacity + visibility).
class LayersSheet extends ConsumerWidget {
  const LayersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final layers = ref.watch(layersProvider).valueOrNull ?? const [];
    final l10n = AppStrings.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    PhosphorIconsDuotone.stack,
                    color: AppColors.primaryGlow,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.layersSheetTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                l10n.mapBaseMapTitle,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BaseMapStyle.values.map((style) {
                    final selected = settings?.baseMapStyle == style;
                    return _BaseMapChip(
                      label: l10n.baseMapLabel(style.name),
                      selected: selected,
                      onTap: () => ref.read(settingsProvider.notifier).mutate(
                            (s) => s.copyWith(baseMapStyle: style),
                          ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    l10n.mapUserLayersTitle,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _AddLayerButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ImportLayerSheet(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (layers.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsDuotone.fileArrowUp,
                        color: AppColors.textTertiary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.mapAddLayerHint,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...layers.map((l) => _LayerRow(layer: l)),
            ],
          ),
        );
      },
    );
  }
}

class _BaseMapChip extends StatelessWidget {
  const _BaseMapChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.glassFill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? AppColors.primaryGlow.withValues(alpha: 0.6)
                : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryGlow : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _AddLayerButton extends StatelessWidget {
  const _AddLayerButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.glassBorderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsBold.plus,
                color: AppColors.primaryGlow, size: 14),
            const SizedBox(width: 6),
            Text(
              'Добавить',
              style: TextStyle(
                color: AppColors.primaryGlow,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerRow extends ConsumerWidget {
  const _LayerRow({required this.layer});
  final MapLayer layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(layersProvider.notifier);
    // MBTiles layers show a small "OFFLINE" tag and a different icon
    // so the user can see at a glance which entries are local files
    // vs. live tile URLs.
    final isOffline = layer.type == MapLayerType.mbtiles;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isOffline
                      ? PhosphorIconsDuotone.database
                      : PhosphorIconsDuotone.mapTrifold,
                  color: isOffline
                      ? AppColors.success
                      : AppColors.primaryGlow,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              layer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isOffline) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OFFLINE',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${layer.type.name} · ${(layer.opacity * 100).round()}%',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Image overlays get an "edit" button — reopens the
                // georeference screen with this layer preloaded so the
                // user can tweak bounds/rotation later without having
                // to re-pick the image.
                if (layer.type == MapLayerType.imageOverlay &&
                    layer.bounds != null)
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GeoreferenceScreen(editing: layer),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    icon: Icon(PhosphorIconsDuotone.pencilSimple,
                        color: AppColors.primaryGlow, size: 18),
                    tooltip: 'Изменить привязку',
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  onPressed: () => _confirmDelete(context, ref, notifier),
                  icon: Icon(PhosphorIconsDuotone.trash,
                      color: AppColors.error, size: 18),
                  tooltip: 'Удалить слой',
                  visualDensity: VisualDensity.compact,
                ),
                Switch(
                  value: layer.visible,
                  onChanged: (v) => notifier.setVisible(layer.id, v),
                ),
              ],
            ),
            Slider(
              value: layer.opacity,
              onChanged: (v) => notifier.setOpacity(layer.id, v),
              activeColor: AppColors.primaryGlow,
              inactiveColor: AppColors.glassBorderStrong,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LayersNotifier notifier,
  ) async {
    final isOffline = layer.type == MapLayerType.mbtiles;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Удалить «${layer.name}»?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          isOffline
              ? 'Локальный .mbtiles файл со всеми тайлами будет удалён. '
                  'Действие нельзя отменить.'
              : 'Слой будет удалён из списка. Это действие не влияет '
                  'на базовую карту.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // For MBTiles layers, also delete the backing file so we reclaim
    // disk space. The download task (if any) stays in Downloads screen
    // as a historical record — user can delete it there too.
    if (isOffline) {
      // Drop the cached SQLite handle first so our subsequent delete()
      // isn't fighting with the open file descriptor.
      LayersService.invalidateMbtilesCache(layer.source);
      try {
        final f = File(layer.source);
        if (await f.exists()) await f.delete();
      } catch (_) {/* best effort */}
    }
    await notifier.remove(layer.id);
  }
}
