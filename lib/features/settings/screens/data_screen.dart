import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/providers/points_provider.dart';
import '../../../shared/providers/routes_provider.dart';
import '../../../shared/providers/tracks_provider.dart';
import '../../../shared/services/gpx_service.dart';
import '../../../shared/services/import_service.dart';

/// Import / export hub. Reachable from Settings → "Данные".
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

  Future<void> _importFile() async {
    setState(() => _busy = true);
    try {
      // FileType.any instead of custom — some Android OEMs don't expose a
      // MIME for .gpx/.kml, so .custom filter throws "Unsupported filter".
      // We validate the extension ourselves after the user picks a file.
      final res = await FilePicker.platform.pickFiles(type: FileType.any);
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;

      if (!ImportService.isSupported(path)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Поддерживаются только .gpx, .kml, .kmz',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final parsed = await ImportService.importFile(File(path));

      if (parsed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('В файле не найдено треков, точек или маршрутов'),
          ),
        );
        return;
      }

      for (final t in parsed.tracks) {
        await ref.read(tracksProvider.notifier).add(t);
      }
      for (final p in parsed.points) {
        await ref.read(pointsProvider.notifier).add(p);
      }
      for (final r in parsed.routes) {
        await ref.read(routesProvider.notifier).add(r);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Импорт: ${parsed.tracks.length} треков, '
            '${parsed.points.length} точек, '
            '${parsed.routes.length} маршрутов',
          ),
          backgroundColor: AppColors.primary,
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportAll() async {
    setState(() => _busy = true);
    try {
      final tracks = ref.read(tracksProvider).valueOrNull ?? [];
      final points = ref.read(pointsProvider).valueOrNull ?? [];
      final routes = ref.read(routesProvider).valueOrNull ?? [];

      if (tracks.isEmpty && points.isEmpty && routes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нечего экспортировать')),
        );
        return;
      }

      final xml = GpxService.serialize(
        tracks: tracks,
        points: points,
        routes: routes,
      );
      final file = await GpxService.writeToFile(xml, 'chaliynav_export');

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'ChaliyNav: ${tracks.length} треков · ${points.length} точек · ${routes.length} маршрутов',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка экспорта: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPoints() async {
    setState(() => _busy = true);
    try {
      final points = ref.read(pointsProvider).valueOrNull ?? [];
      if (points.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Точек ещё нет')),
        );
        return;
      }
      final xml = GpxService.serialize(points: points);
      final file = await GpxService.writeToFile(xml, 'points');
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${points.length} точек',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportTracks() async {
    setState(() => _busy = true);
    try {
      final tracks = ref.read(tracksProvider).valueOrNull ?? [];
      if (tracks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Треков ещё нет')),
        );
        return;
      }
      final xml = GpxService.serialize(tracks: tracks);
      final file = await GpxService.writeToFile(xml, 'tracks');
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${tracks.length} треков',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointsCount = ref.watch(pointsProvider).valueOrNull?.length ?? 0;
    final tracksCount = ref.watch(tracksProvider).valueOrNull?.length ?? 0;
    final routesCount = ref.watch(routesProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Данные',
        subtitle: 'Импорт · Экспорт · Бэкап',
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 80,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 100,
        ),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: PhosphorIconsDuotone.mapPin,
                    label: 'Точек',
                    value: pointsCount,
                    color: AppColors.primaryGlow,
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.divider),
                Expanded(
                  child: _Stat(
                    icon: PhosphorIconsDuotone.path,
                    label: 'Треков',
                    value: tracksCount,
                    color: AppColors.accentCyan,
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.divider),
                Expanded(
                  child: _Stat(
                    icon: PhosphorIconsDuotone.arrowBendUpRight,
                    label: 'Маршрутов',
                    value: routesCount,
                    color: AppColors.accentAmber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('ИМПОРТ'),
          GlassCard(
            onTap: _busy ? null : _importFile,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.fileArrowDown,
                    color: AppColors.primaryGlow, size: 22),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Импорт GPX / KML / KMZ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Google Earth · Google My Maps · Яндекс.Карты · Maps.me · OrganicMaps · Garmin',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight,
                    color: AppColors.textTertiary, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ImportHintCard(),
          const SizedBox(height: 18),
          _sectionTitle('ЭКСПОРТ'),
          GlassCard(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                _ExportRow(
                  icon: PhosphorIconsDuotone.shareNetwork,
                  title: 'Всё в один GPX',
                  subtitle: 'Треки + точки + маршруты',
                  onTap: _busy ? null : _exportAll,
                ),
                const Divider(height: 1),
                _ExportRow(
                  icon: PhosphorIconsDuotone.mapPin,
                  title: 'Только точки',
                  subtitle: '$pointsCount шт.',
                  onTap: _busy ? null : _exportPoints,
                ),
                const Divider(height: 1),
                _ExportRow(
                  icon: PhosphorIconsDuotone.path,
                  title: 'Только треки',
                  subtitle: '$tracksCount шт.',
                  onTap: _busy ? null : _exportTracks,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('БЭКАП'),
          GlassCard(
            onTap: () => context.push('/settings/backup'),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.shieldCheck,
                    color: AppColors.primaryGlow, size: 22),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Зашифрованный бэкап',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'AES-256 + пароль. Точки, треки, маршруты, зоны, слои.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight,
                    color: AppColors.textTertiary, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        t,
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _ImportHintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsDuotone.info,
                  color: AppColors.textTertiary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Как получить файл из ваших карт',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _hint('Google Earth / My Maps', 'Меню слоя → «Экспорт» → KML'),
          _hint('Яндекс.Карты', 'Избранное → поделиться → сохранить как KML'),
          _hint('Maps.me / Organic Maps', 'Закладки → поделиться → KML/KMZ'),
          _hint('Garmin Connect', 'Активность → Экспорт → Original GPX'),
          _hint('Strava', 'Тренировка → «…» → Export GPX'),
        ],
      ),
    );
  }

  Widget _hint(String source, String steps) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$source: ',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: steps),
          ],
        ),
      ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGlow, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.caretRight,
                color: AppColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
