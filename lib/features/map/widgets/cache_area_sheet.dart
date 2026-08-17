import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/services/area_downloader.dart';

/// "Download this area" sheet. The visible viewport is saved straight into
/// the base-map cache for the chosen styles (schema / satellite / hybrid /
/// …) across a zoom range — so afterwards the user just switches style as
/// usual and the area shows offline. No layer is created. Already-cached
/// tiles are skipped, so it only ever downloads the missing parts.
class CacheAreaSheet extends ConsumerStatefulWidget {
  const CacheAreaSheet({
    super.key,
    required this.mapController,
    required this.initialStyle,
  });

  final MapController mapController;
  final BaseMapStyle initialStyle;

  @override
  ConsumerState<CacheAreaSheet> createState() => _CacheAreaSheetState();
}

class _CacheAreaSheetState extends ConsumerState<CacheAreaSheet> {
  late double _n, _s, _w, _e;
  late int _minZoom;
  late int _maxZoom;
  late Set<BaseMapStyle> _styles;

  /// Tiles that would actually be downloaded (missing from cache). Null
  /// while (re)counting.
  int? _missing;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _styles = {widget.initialStyle};
    try {
      final cam = widget.mapController.camera;
      final b = cam.visibleBounds;
      _n = b.north;
      _s = b.south;
      _w = b.west;
      _e = b.east;
      _minZoom = cam.zoom.floor().clamp(3, 15);
      _maxZoom = (_minZoom + 4).clamp(3, 19);
    } catch (_) {
      _n = 56.0;
      _s = 55.0;
      _w = 37.0;
      _e = 38.0;
      _minZoom = 12;
      _maxZoom = 16;
    }
    _recount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// URL templates to fetch for the selected styles. Hybrid pulls both the
  /// imagery and its transparent labels overlay; duplicates collapse
  /// (satellite & hybrid share the imagery URL).
  List<String> get _sources {
    final out = <String>{};
    for (final s in _styles) {
      out.add(s.tileUrl);
      final overlay = s.labelOverlayUrl;
      if (overlay != null) out.add(overlay);
    }
    return out.toList();
  }

  void _recount() {
    _debounce?.cancel();
    setState(() => _missing = null);
    if (_styles.isEmpty) {
      setState(() => _missing = 0);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final n = await ref.read(areaDownloadProvider.notifier).countMissing(
            sources: _sources,
            north: _n,
            south: _s,
            west: _w,
            east: _e,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
          );
      if (!mounted) return;
      setState(() => _missing = n);
    });
  }

  double get _estimatedMb => (_missing ?? 0) * 15 / 1024; // ~15 KB / tile

  void _start() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    ref.read(areaDownloadProvider.notifier).download(
          sources: _sources,
          north: _n,
          south: _s,
          west: _w,
          east: _e,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
        );
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_download, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Скачивание области началось — ${_missing ?? 0} тайлов')),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final counting = _missing == null;
    final nothing = _missing == 0;
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
              Icon(PhosphorIconsDuotone.downloadSimple,
                  color: AppColors.primaryGlow, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Скачать видимую область',
                  style: TextStyle(
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
            'Область сохранится в кеш карты. Потом просто переключайте тип '
            'карты — офлайн покажется сохранённое. Уже скачанное не качается '
            'повторно.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ЧТО СКАЧАТЬ',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final style in BaseMapStyle.values)
                _StyleChip(
                  label: style.label,
                  selected: _styles.contains(style),
                  onTap: () {
                    setState(() {
                      if (_styles.contains(style)) {
                        _styles.remove(style);
                      } else {
                        _styles.add(style);
                      }
                    });
                    _recount();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
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
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: RangeSlider(
                    values: RangeValues(_minZoom.toDouble(), _maxZoom.toDouble()),
                    min: 3,
                    max: 19,
                    divisions: 16,
                    labels: RangeLabels('z$_minZoom', 'z$_maxZoom'),
                    onChanged: (v) => setState(() {
                      _minZoom = v.start.round();
                      _maxZoom = v.end.round();
                    }),
                    onChangeEnd: (_) => _recount(),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        icon: PhosphorIconsDuotone.squaresFour,
                        label: 'Новых тайлов',
                        value: counting ? '…' : _formatInt(_missing!),
                      ),
                    ),
                    Container(width: 1, height: 28, color: AppColors.divider),
                    Expanded(
                      child: _stat(
                        icon: PhosphorIconsDuotone.database,
                        label: 'Размер ~',
                        value: counting ? '…' : _formatSize(_estimatedMb),
                      ),
                    ),
                  ],
                ),
                if (!counting && (_missing ?? 0) > 10000) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Крупная загрузка. Лучше по Wi-Fi и с запасом места. '
                    'Для схемы (OSM) очень большие области могут временно '
                    'блокироваться сервером.',
                    style: TextStyle(color: AppColors.accentAmber, fontSize: 11),
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
                  label: counting
                      ? 'Подсчёт…'
                      : nothing
                          ? 'Всё скачано'
                          : 'Скачать',
                  icon: Icon(PhosphorIconsBold.download),
                  onPressed: (counting || nothing) ? null : _start,
                  expanded: true,
                ),
              ),
            ],
          ),
        ],
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
        Text(label,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
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

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.22)
              : AppColors.glassBorder.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color:
                selected ? AppColors.primaryGlow : AppColors.glassBorderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(PhosphorIconsBold.check,
                  color: AppColors.primaryGlow, size: 13),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
