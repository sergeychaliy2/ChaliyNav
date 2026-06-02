import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/models/map_preset.dart';
import '../../../shared/services/download_manager.dart';

/// Download-area configurator. User sees the bounding box that will be
/// downloaded, the estimated tile count, and picks a zoom range.
class DownloadAreaSheet extends ConsumerStatefulWidget {
  const DownloadAreaSheet({
    super.key,
    required this.mapController,
    this.preset,
  });

  final MapController mapController;

  /// When opened from a Regions-RU preset card, the preset seeds the bbox
  /// and layer. Otherwise the user's current viewport is used.
  final MapPreset? preset;

  @override
  ConsumerState<DownloadAreaSheet> createState() => _DownloadAreaSheetState();
}

class _DownloadAreaSheetState extends ConsumerState<DownloadAreaSheet> {
  late int _minZoom;
  late int _maxZoom;
  late double _n;
  late double _s;
  late double _w;
  late double _e;
  late String _tileUrl;
  late String _name;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    if (preset != null && preset.region != null) {
      final r = preset.region!;
      _n = r.northLat;
      _s = r.southLat;
      _w = r.westLng;
      _e = r.eastLng;
      _minZoom = r.recommendedMinZoom;
      _maxZoom = r.recommendedMaxZoom;
      _tileUrl = preset.source;
      _name = preset.name;
    } else {
      // Fallback to current map viewport.
      try {
        final b = widget.mapController.camera.visibleBounds;
        _n = b.north;
        _s = b.south;
        _w = b.west;
        _e = b.east;
        _minZoom = widget.mapController.camera.zoom.floor().clamp(1, 14);
        _maxZoom = (_minZoom + 3).clamp(1, 16);
      } catch (_) {
        _n = 56.0;
        _s = 55.0;
        _w = 37.0;
        _e = 38.0;
        _minZoom = 10;
        _maxZoom = 13;
      }
      _tileUrl = BaseMapStyle.schema.tileUrl;
      _name = 'Область (${DateTime.now().day}/${DateTime.now().month})';
    }
  }

  int get _estimated => DownloadManager.countTiles(
        northLat: _n,
        southLat: _s,
        westLng: _w,
        eastLng: _e,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
      );

  double get _estimatedMb => _estimated * 15 / 1024; // ~15 KB per tile

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: media.viewInsets.bottom + media.padding.bottom + 20,
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
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(PhosphorIconsDuotone.cloudArrowDown,
                  color: AppColors.primaryGlow, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.preset == null
                ? 'Будет скачана область, которую вы сейчас видите на карте.'
                : widget.preset!.description.isNotEmpty
                    ? widget.preset!.description
                    : 'Регион РФ — подготовленные границы.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Text(
                  'Диапазон зума: $_minZoom – $_maxZoom',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primaryGlow,
                    inactiveTrackColor: AppColors.glassBorderStrong,
                    thumbColor: Colors.white,
                    overlayColor:
                        AppColors.primary.withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: RangeSlider(
                    values: RangeValues(
                      _minZoom.toDouble(),
                      _maxZoom.toDouble(),
                    ),
                    min: 1,
                    max: 17,
                    divisions: 16,
                    onChanged: (v) => setState(() {
                      _minZoom = v.start.round();
                      _maxZoom = v.end.round();
                    }),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        icon: PhosphorIconsDuotone.squaresFour,
                        label: 'Тайлов',
                        value: _formatInt(_estimated),
                      ),
                    ),
                    Container(
                        width: 1, height: 28, color: AppColors.divider),
                    Expanded(
                      child: _stat(
                        icon: PhosphorIconsDuotone.database,
                        label: 'Размер ~',
                        value: _formatSize(_estimatedMb),
                      ),
                    ),
                  ],
                ),
                if (_estimated > 10000) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Внимание: крупная загрузка. Убедитесь, что есть Wi-Fi и место на диске.',
                    style: TextStyle(
                      color: AppColors.accentAmber,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: 'Отмена',
                  variant: GlassButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                  expanded: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GlassButton(
                  label: _estimated > 0 ? 'Скачать' : 'Пусто',
                  icon: Icon(PhosphorIconsBold.download),
                  onPressed: _estimated > 0 ? _start : null,
                  expanded: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    // Capture live references BEFORE we pop the sheet — once the sheet's
    // widget is disposed, `context` is defunct and both the snackbar
    // messenger and the GoRouter lookup would fail silently. This is
    // why the "Загрузки" button in the snackbar didn't navigate: the
    // old `context.push(...)` used a disposed context.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    await ref.read(downloadManagerProvider.notifier).enqueue(
          name: _name,
          tileUrlTemplate: _tileUrl,
          northLat: _n,
          southLat: _s,
          westLng: _w,
          eastLng: _e,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          presetId: widget.preset?.id,
        );
    if (!mounted) return;
    // Signal "started" to the caller so it can dismiss the import layer
    // sheet and the user sees the map + download mini-indicator.
    Navigator.of(context).pop(true);

    messenger?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_download, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Загрузка «$_name» началась')),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Загрузки',
          textColor: Colors.white,
          // `router` is a singleton captured above — always valid.
          // Use .go() to switch branches (Settings tab) cleanly.
          onPressed: () => router.go('/settings/downloads'),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
        ),
      ],
    );
  }

  String _formatInt(int n) {
    final s = '$n';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatSize(double mb) {
    if (mb < 1) return '${(mb * 1024).round()} КБ';
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} МБ';
    return '${(mb / 1024).toStringAsFixed(2)} ГБ';
  }
}
