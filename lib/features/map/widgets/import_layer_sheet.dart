import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/models/map_preset.dart';
import '../../../shared/models/weather.dart';
import '../../../shared/providers/layers_provider.dart';
import '../../../shared/services/download_manager.dart';
import '../../../shared/services/layers_service.dart';
import '../../../shared/services/raster_importer.dart';
import '../screens/georeference_screen.dart';
import 'download_area_sheet.dart';
import 'weather_map_layer.dart';

/// Full-screen sheet for adding a new map layer: file import, XYZ URL, or preset.
class ImportLayerSheet extends ConsumerStatefulWidget {
  const ImportLayerSheet({super.key});

  @override
  ConsumerState<ImportLayerSheet> createState() => _ImportLayerSheetState();
}

class _ImportLayerSheetState extends ConsumerState<ImportLayerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _urlCtrl = TextEditingController();
  final _urlNameCtrl = TextEditingController();
  final _catalogSearch = TextEditingController();
  MapPresetCategory? _selectedCategory;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _urlCtrl.dispose();
    _urlNameCtrl.dispose();
    _catalogSearch.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _importing = true);
    try {
      // Multi-select so the user can grab a raster together with its
      // world-file sidecar in one shot (required on Android — see the
      // long comment in GeoreferenceScreen._pick).
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (res == null || res.files.isEmpty) return;

      final pickedPaths = [
        for (final f in res.files)
          if (f.path != null) f.path!,
      ];

      // Tile-pack takes precedence if there's one in the selection —
      // those are single files and never need sidecars.
      const tilePackSupported = ['.mbtiles', '.sqlitedb', '.ozf2', '.zmp'];
      final tilePackPath = pickedPaths.firstWhere(
        (p) => tilePackSupported.any(p.toLowerCase().endsWith),
        orElse: () => '',
      );

      if (tilePackPath.isEmpty &&
          !pickedPaths.any(RasterImporter.canHandle)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Поддерживаются: .mbtiles, .sqlitedb, .ozf2, .zmp, '
              '.tif / .tiff, .jpg, .png. Для TIFF/JPEG выделяйте '
              'растр вместе с файлом привязки (.tfw / .tfwx / .jgwx).',
            ),
            duration: Duration(seconds: 7),
          ),
        );
        return;
      }

      // Raster (.tif/.jpg/.png) — try to build a georeferenced
      // imageOverlay automatically using any sidecar world file.
      if (tilePackPath.isEmpty) {
        final staged = await RasterImporter.stageSelection(pickedPaths);
        if (staged == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Выберите растровый файл: .tif, .tiff, .jpg, .jpeg или .png.',
              ),
            ),
          );
          return;
        }
        final rasterName = p.basename(staged.rasterPath);
        final result = await RasterImporter.importFile(staged.rasterPath);
        await ref.read(layersProvider.notifier).add(result.layer);
        if (!mounted) return;
        Navigator.of(context).pop();
        final m = ScaffoldMessenger.of(context);
        if (result.kind == RasterImportKind.ungeoreferenced) {
          m.showSnackBar(
            SnackBar(
              content: Text(
                !staged.sidecarMatched
                    ? '«$rasterName» добавлен без привязки — вы не '
                        'выделили файл привязки (.tfw / .tfwx / .jgw / '
                        '.jgwx / .aux.xml). Повторите импорт с обоими '
                        'файлами, либо привяжите вручную через «Слои → + → Привязка».'
                    : '«$rasterName» добавлен без привязки. '
                        'Откройте «Слои → + → Привязка» чтобы указать 2 угла.',
              ),
              duration: const Duration(seconds: 7),
            ),
          );
        } else {
          m.showSnackBar(
            SnackBar(
              content: Text(
                result.warning ??
                    'Слой «$rasterName» добавлен с привязкой.',
              ),
              backgroundColor: result.warning == null
                  ? AppColors.success
                  : AppColors.accentAmber,
              duration: Duration(
                  seconds: result.warning == null ? 3 : 6),
            ),
          );
        }
        return;
      }

      // Tile-pack (.mbtiles etc) — existing pipeline.
      final tilePackName = p.basename(tilePackPath);
      final destPath = await LayersService.importFile(tilePackPath);
      final type = LayersService.detectType(destPath);

      await ref.read(layersProvider.notifier).add(
            MapLayer(
              id: const Uuid().v4(),
              name: tilePackName,
              type: type,
              source: destPath,
              opacity: 1.0,
              description: 'Импортирован из $tilePackName',
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Слой «$tilePackName» добавлен')),
      );
    } on RasterImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка импорта: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _addUrl() async {
    final url = _urlCtrl.text.trim();
    final name = _urlNameCtrl.text.trim();
    if (url.isEmpty || !url.contains('{z}')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL должен содержать {z}/{x}/{y}'),
        ),
      );
      return;
    }
    await ref.read(layersProvider.notifier).add(
          MapLayer(
            id: const Uuid().v4(),
            name: name.isEmpty ? 'Пользовательский слой' : name,
            type: MapLayerType.tileUrl,
            source: url,
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addPreset(MapPreset preset) async {
    // Use a DETERMINISTIC id (preset_<id>) so re-adding the same preset
    // doesn't stack duplicates in the layer list, and the download flow
    // can clean it up when migrating online → offline.
    await ref.read(layersProvider.notifier).upsert(
          preset.toLayer(layerId: 'preset_${preset.id}'),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Добавлен «${preset.name}»')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(PhosphorIconsBold.x),
        ),
        title: const Text('Добавить слой'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primaryGlow,
          labelColor: AppColors.primaryGlow,
          unselectedLabelColor: AppColors.textTertiary,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: const [
            Tab(text: 'Каталог'),
            Tab(text: 'Из файла'),
            Tab(text: 'По ссылке'),
            Tab(text: 'Привязка'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _presetsTab(),
          _fileTab(),
          _urlTab(),
          _georefTab(),
        ],
      ),
    );
  }

  Widget _presetsTab() {
    final categories = MapPresetCategory.values;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final query = _catalogSearch.text.trim();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.magnifyingGlass,
                    color: AppColors.textTertiary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _catalogSearch,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Поиск карты',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (query.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _catalogSearch.clear();
                      setState(() {});
                    },
                    icon: Icon(PhosphorIconsBold.x,
                        color: AppColors.textTertiary, size: 14),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
        _categoryFilterBar(categories),
        Expanded(
          child: query.isNotEmpty
              ? _searchResults(query, safeBottom)
              : _groupedCatalog(categories, safeBottom),
        ),
      ],
    );
  }

  Widget _categoryFilterBar(List<MapPresetCategory> categories) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          _CategoryFilterChip(
            label: 'Все',
            icon: PhosphorIconsDuotone.squaresFour,
            color: AppColors.primaryGlow,
            selected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          for (final cat in categories)
            if (MapPresetLibrary.byCategory(cat).isNotEmpty)
              _CategoryFilterChip(
                label: cat.label,
                icon: _categoryIcon(cat),
                color: _categoryColor(cat),
                selected: _selectedCategory == cat,
                onTap: () => setState(() {
                  _selectedCategory =
                      _selectedCategory == cat ? null : cat;
                }),
              ),
        ],
      ),
    );
  }

  Widget _searchResults(String query, double safeBottom) {
    final results = MapPresetLibrary.search(query);
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsDuotone.magnifyingGlass,
                  color: AppColors.textTertiary, size: 40),
              const SizedBox(height: 12),
              Text(
                'Ничего не найдено',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Попробуйте «Волга», «Байкал», «глубины», «Карелия», «Петербург»…',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 120 + safeBottom),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'НАЙДЕНО: ${results.length}',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...results.map(_presetCard),
      ],
    );
  }

  Widget _groupedCatalog(
      List<MapPresetCategory> categories, double safeBottom) {
    // Honour category chip selection.
    if (_selectedCategory != null) {
      final list = MapPresetLibrary.byCategory(_selectedCategory!);
      if (list.isEmpty) {
        return Center(
          child: Text(
            'В этой категории пока нет карт',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        );
      }
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 120 + safeBottom),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '${_selectedCategory!.label.toUpperCase()} · ${list.length}',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...list.map(_presetCard),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 120 + safeBottom),
      children: [
        for (final cat in categories) ...[
          if (MapPresetLibrary.byCategory(cat).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
              child: Text(
                cat.label.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...MapPresetLibrary.byCategory(cat).map(
              (preset) => _presetCard(preset),
            ),
          ],
        ],
      ],
    );
  }

  Widget _presetCard(MapPreset preset) {
    final hasRegion = preset.region != null;
    final downloadStatus = _findDownloadStatus(preset);
    // Region presets get a (simulated) weather highlight: the card accent
    // and a temperature badge reflect the current weather at the region's
    // centre. Purely internal — no network.
    final r = preset.region;
    final weather = r == null
        ? null
        : WeatherSim.at(
            (r.northLat + r.southLat) / 2, (r.westLng + r.eastLng) / 2);
    final accent = weather?.condition.color ?? _categoryColor(preset.category);
    // Is this preset already present as an online layer?
    // (Added via the "+" button below — NOT via a bare card tap like before,
    // which caused phantom layers to linger after a download was cancelled.)
    final existingLayerIds =
        ref.watch(layersProvider).valueOrNull?.map((l) => l.id).toSet() ??
            const <String>{};
    final alreadyAdded = existingLayerIds.contains('preset_${preset.id}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // No onTap here — tapping the card body does NOTHING. Actions below
      // are explicit buttons so nothing gets added to the layer list
      // accidentally.
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.3),
                        accent.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    _categoryIcon(preset.category),
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preset.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (preset.isOverlay)
                            _tag('OVERLAY', AppColors.accent),
                          if (alreadyAdded)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _tag('В СЛОЯХ', AppColors.success),
                            ),
                          if (hasRegion && downloadStatus == null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _tag('OFFLINE', AppColors.primaryGlow),
                            ),
                        ],
                      ),
                      if (preset.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          preset.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (weather != null) ...[
                  const SizedBox(width: 8),
                  WeatherBadge(weather: weather, dense: true),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Online-only add/remove toggle.
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (alreadyAdded) {
                        await ref
                            .read(layersProvider.notifier)
                            .remove('preset_${preset.id}');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Удалён «${preset.name}»'),
                          ),
                        );
                      } else {
                        _addPreset(preset);
                      }
                    },
                    icon: Icon(
                      alreadyAdded
                          ? PhosphorIconsBold.check
                          : PhosphorIconsBold.plus,
                      size: 16,
                    ),
                    label: Text(alreadyAdded ? 'В слоях' : 'Добавить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: alreadyAdded
                          ? AppColors.success
                          : AppColors.primaryGlow,
                      side: BorderSide(
                        color: (alreadyAdded
                                ? AppColors.success
                                : AppColors.primaryGlow)
                            .withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                if (hasRegion) const SizedBox(width: 8),
                if (hasRegion)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: downloadStatus != null &&
                              (downloadStatus.status ==
                                      DownloadStatus.running ||
                                  downloadStatus.status ==
                                      DownloadStatus.queued)
                          ? null
                          : () => _startDownload(preset),
                      icon: Icon(PhosphorIconsDuotone.cloudArrowDown,
                          size: 16),
                      label: const Text('Offline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGlow,
                        side: BorderSide(
                          color: AppColors.primaryGlow.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
            if (downloadStatus != null) ...[
              const SizedBox(height: 10),
              _DownloadStatusRow(
                task: downloadStatus,
                onCancel: downloadStatus.status == DownloadStatus.running ||
                        downloadStatus.status == DownloadStatus.queued
                    ? () => ref
                        .read(downloadManagerProvider.notifier)
                        .cancel(downloadStatus.id)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns the most relevant download task for this preset:
  ///   completed > running > queued > failed > cancelled.
  DownloadTask? _findDownloadStatus(MapPreset preset) {
    final all = ref.watch(downloadManagerProvider);
    final matching = all.where((t) => t.presetId == preset.id).toList();
    if (matching.isEmpty) return null;
    // Preferred status order.
    const order = [
      DownloadStatus.running,
      DownloadStatus.queued,
      DownloadStatus.completed,
      DownloadStatus.paused,
      DownloadStatus.failed,
      DownloadStatus.cancelled,
    ];
    for (final s in order) {
      final hit = matching.where((t) => t.status == s).firstOrNull;
      if (hit != null) return hit;
    }
    return matching.first;
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _startDownload(MapPreset preset) async {
    final started = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DownloadAreaSheet(
        mapController: MapController(),
        preset: preset,
      ),
    );
    // If the user actually started a download, close the whole "Add layer"
    // screen too — otherwise the import UI covers the download indicator.
    if (started == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _fileTab() {
    // Scrollable + bottom padding that clears the main-shell nav bar
    // (~120 px) PLUS the system SafeArea inset. Without this the
    // "Выбрать файл" CTA hides behind the Карта/Точки/Треки/Настройки
    // strip on short screens and the user can't scroll to reach it.
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 120 + safeBottom),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsDuotone.fileArrowUp,
                        color: AppColors.primaryGlow, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Импорт файла карты',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Поддерживаются:\n'
                  '• .mbtiles — готовые offline-тайлы\n'
                  '• .tif / .tiff + .tfw / .tfwx — GeoTIFF с привязкой\n'
                  '• .jpg / .jpeg + .jgw / .jgwx — JPEG с привязкой\n'
                  '• .png + .pgw — PNG с привязкой\n'
                  '• .jnx — Garmin BirdsEye (v3, координаты внутри)\n'
                  '• .tif / .jpg / .png без привязки — откроется экран '
                  'ручной привязки по 2 углам\n\n'
                  '⚡ В диалоге выбора выделяйте растр ВМЕСТЕ с '
                  'основным файлом привязки (.tfw / .tfwx для TIFF, '
                  '.jgw / .jgwx для JPEG, .pgw для PNG). Без него '
                  'Android не передаст сайдкар приложению и слой '
                  'ляжет мимо координат. Файл .aux.xml в пару НЕ '
                  'подходит — в нём обычно только статистика, без '
                  'координат. Для .jnx сайдкар не нужен — координаты '
                  'лежат в самом файле.\n\n'
                  'Координаты должны быть в WGS84 (градусы). UTM / '
                  'Гаусс-Крюгер потребуют перепривязки в QGIS.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                GlassButton(
                  expanded: true,
                  label: _importing ? 'Копирование…' : 'Выбрать файл',
                  icon: Icon(PhosphorIconsDuotone.folderOpen),
                  onPressed: _importing ? null : _pickFile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Файлы копируются в хранилище приложения и работают offline.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _georefTab() {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 120 + safeBottom),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsDuotone.cornersOut,
                        color: AppColors.primaryGlow, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Привязка скана карты',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Возьмите скан бумажной карты (или PNG/JPG-экспорт из QGIS) и привяжите его к 2 углам — '
                  'северо-западному и юго-восточному. Карта будет наложена на базовый слой с настраиваемой прозрачностью.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                GlassButton(
                  expanded: true,
                  label: 'Начать привязку',
                  icon: Icon(PhosphorIconsDuotone.image),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // `rootNavigator: true` pushes above the main tab
                    // shell, so the bottom nav bar (Карта / Точки /
                    // Треки / Настройки) doesn't clip our control
                    // panel — the user was seeing the Bottom sliders
                    // disappear under the tab strip.
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const GeoreferenceScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsDuotone.info,
                        color: AppColors.accentAmber, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Экспорт из QGIS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Для точечных слоёв (рыболовные места, POI): Layer → Export → Save Features As… → GeoJSON, затем импортируйте через «Из файла».',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Для растровых карт (GeoTIFF): Processing → «Generate XYZ tiles (MBTiles)» → получите .mbtiles, импортируйте как offline-слой.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Для бумажных карт и сканов: экспортируйте PNG/JPG и используйте «Привязка» выше.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _urlTab() {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 120 + safeBottom),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsDuotone.link,
                        color: AppColors.primaryGlow, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'XYZ / TMS URL',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Подставьте {z}, {x}, {y} — эти плейсхолдеры Flutter заменит на координаты тайла.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlNameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    hintText: 'Мой любимый сервер',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'URL шаблон',
                    hintText: 'https://tile.example.com/{z}/{x}/{y}.png',
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 16),
                GlassButton(
                  expanded: true,
                  label: 'Добавить',
                  icon: Icon(PhosphorIconsBold.plus),
                  onPressed: _addUrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(MapPresetCategory c) => switch (c) {
        MapPresetCategory.topographic => AppColors.primaryGlow,
        MapPresetCategory.satellite => AppColors.accentCyan,
        MapPresetCategory.historical => AppColors.accentAmber,
        MapPresetCategory.nautical => AppColors.info,
        MapPresetCategory.fishing => AppColors.accentRose,
        MapPresetCategory.weather => AppColors.accentViolet,
        MapPresetCategory.regionsRu => AppColors.primaryGlow,
        MapPresetCategory.other => AppColors.textSecondary,
      };

  IconData _categoryIcon(MapPresetCategory c) => switch (c) {
        MapPresetCategory.topographic => PhosphorIconsDuotone.mountains,
        MapPresetCategory.satellite => PhosphorIconsDuotone.globe,
        MapPresetCategory.historical => PhosphorIconsDuotone.scroll,
        MapPresetCategory.nautical => PhosphorIconsDuotone.anchor,
        MapPresetCategory.fishing => PhosphorIconsDuotone.fish,
        MapPresetCategory.weather => PhosphorIconsDuotone.cloudRain,
        MapPresetCategory.regionsRu => PhosphorIconsDuotone.flag,
        MapPresetCategory.other => PhosphorIconsDuotone.mapTrifold,
      };
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.22)
                  : AppColors.glassFill,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.6)
                    : AppColors.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: selected ? color : AppColors.textSecondary,
                    size: 15),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadStatusRow extends StatelessWidget {
  const _DownloadStatusRow({required this.task, this.onCancel});
  final DownloadTask task;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _styleFor(task.status);
    final pct = (task.progress * 100).round();
    final isActive = task.status == DownloadStatus.running ||
        task.status == DownloadStatus.queued;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              if (isActive)
                Text(
                  '$pct% · ${task.downloadedTiles}/${task.totalTiles}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else if (task.status == DownloadStatus.completed)
                Text(
                  '${task.totalTiles} тайлов',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              if (onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(PhosphorIconsBold.x,
                      color: AppColors.textTertiary, size: 12),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 22, minHeight: 22),
                ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: task.progress,
                backgroundColor: AppColors.glassFillStrong,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  (String, Color, IconData) _styleFor(DownloadStatus s) {
    return switch (s) {
      DownloadStatus.queued => (
          'В ОЧЕРЕДИ',
          AppColors.textSecondary,
          PhosphorIconsDuotone.clock,
        ),
      DownloadStatus.running => (
          'СКАЧИВАЕТСЯ',
          AppColors.primaryGlow,
          PhosphorIconsDuotone.cloudArrowDown,
        ),
      DownloadStatus.paused => (
          'ПАУЗА',
          AppColors.accentAmber,
          PhosphorIconsDuotone.pauseCircle,
        ),
      DownloadStatus.completed => (
          'СКАЧАНО',
          AppColors.success,
          PhosphorIconsDuotone.checkCircle,
        ),
      DownloadStatus.failed => (
          'ОШИБКА',
          AppColors.error,
          PhosphorIconsDuotone.warningCircle,
        ),
      DownloadStatus.cancelled => (
          'ОТМЕНЕНО',
          AppColors.textTertiary,
          PhosphorIconsDuotone.prohibit,
        ),
    };
  }
}
