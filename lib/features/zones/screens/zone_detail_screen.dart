import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/map_focus_provider.dart';
import '../../../shared/providers/measure_provider.dart' hide MeasureMode;
import '../../../shared/providers/measure_provider.dart' as mp;
import '../../../shared/providers/zones_provider.dart';
import '../../../shared/services/cached_tile_provider.dart';

/// Detail view for a saved zone: preview map, per-vertex list, controls.
class ZoneDetailScreen extends ConsumerWidget {
  const ZoneDetailScreen({super.key, required this.zoneId});
  final String zoneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider).valueOrNull ?? const <Zone>[];
    final zone = zones.where((z) => z.id == zoneId).firstOrNull;

    if (zone == null) {
      return Scaffold(
        appBar: GlassAppBar(
          title: 'Зона не найдена',
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(PhosphorIconsBold.arrowLeft),
          ),
        ),
        body: const Center(
          child: Text('Зона была удалена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final bounds = _boundsFor(zone.latLngs);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: zone.name,
        subtitle: zone.note.isNotEmpty ? zone.note : zone.kind.label,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () => _showOnMap(context, ref, bounds),
            icon: Icon(PhosphorIconsDuotone.crosshairSimple,
                color: AppColors.textPrimary),
            tooltip: 'На карте',
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, ref, zone),
            icon: Icon(PhosphorIconsDuotone.trash,
                color: AppColors.textPrimary),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 80,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 120,
        ),
        children: [
          // Preview map
          GlassCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(30),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.chaliy.nav',
                        // Shares the base-map disk cache (same OSM URL),
                        // so this preview also works offline.
                        tileProvider: CachedTileProvider(
                          sourceKey:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                      ),
                      if (zone.kind == ZoneKind.area &&
                          zone.vertices.length >= 3)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: zone.latLngs,
                              color: zone.color.withValues(alpha: 0.28),
                              borderColor: zone.color,
                              borderStrokeWidth: 2.5,
                            ),
                          ],
                        ),
                      if (zone.kind == ZoneKind.line &&
                          zone.vertices.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: zone.latLngs,
                              color: zone.color,
                              strokeWidth: 3.5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (final ll in zone.latLngs)
                            Marker(
                              point: ll,
                              width: 12,
                              height: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: zone.color,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Stats card
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (zone.kind == ZoneKind.area) ...[
                  Expanded(
                    child: _statCol(
                      icon: PhosphorIconsDuotone.polygon,
                      label: 'Площадь',
                      value: _formatArea(zone.areaM2),
                      color: zone.color,
                    ),
                  ),
                  Container(width: 1, height: 34, color: AppColors.divider),
                  Expanded(
                    child: _statCol(
                      icon: PhosphorIconsDuotone.ruler,
                      label: 'Периметр',
                      value: Formatters.distance(zone.perimeterM),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _statCol(
                      icon: PhosphorIconsDuotone.ruler,
                      label: 'Длина',
                      value: Formatters.distance(zone.distanceM),
                      color: zone.color,
                    ),
                  ),
                ],
                Container(width: 1, height: 34, color: AppColors.divider),
                Expanded(
                  child: _statCol(
                    icon: PhosphorIconsDuotone.dotsThreeOutline,
                    label: 'Точек',
                    value: '${zone.vertices.length}',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Edit / delete actions
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: 'Редактировать',
                  icon: Icon(PhosphorIconsDuotone.pencilSimple),
                  onPressed: () => _editZone(context, ref, zone),
                  expanded: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  label: 'Удалить',
                  icon: Icon(PhosphorIconsDuotone.trash),
                  variant: GlassButtonVariant.danger,
                  onPressed: () => _confirmDelete(context, ref, zone),
                  expanded: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Vertex list
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              'ТОЧКИ (${zone.vertices.length})',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (var i = 0; i < zone.vertices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: zone.color,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Точка ${i + 1}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.latLng(
                              zone.vertices[i].lat,
                              zone.vertices[i].lng,
                            ),
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ref.read(mapFocusRequestProvider.notifier).state =
                            FocusRequest(
                          target: LatLng(
                            zone.vertices[i].lat,
                            zone.vertices[i].lng,
                          ),
                          zoom: 18,
                        );
                        context.go('/map');
                      },
                      icon: Icon(PhosphorIconsDuotone.crosshairSimple,
                          color: AppColors.primaryGlow, size: 18),
                      tooltip: 'На карте',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Для редактирования вершин по одной нажмите «Редактировать» — зона откроется в режиме измерения, где каждую точку можно переименовать, переместить или удалить.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
        ),
      ],
    );
  }

  void _showOnMap(BuildContext context, WidgetRef ref, LatLngBounds bounds) {
    ref.read(mapFocusRequestProvider.notifier).state = FocusRequest(
      target: LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      ),
      zoom: 14,
    );
    context.go('/map');
  }

  void _editZone(BuildContext context, WidgetRef ref, Zone zone) {
    // Load into measure tool in "edit" mode — save will overwrite this zone
    // by id, and the SaveZoneSheet will prefill its existing name.
    ref.read(measureProvider.notifier).loadZoneForEdit(
          zoneId: zone.id,
          zoneName: zone.name,
          mode: zone.kind == ZoneKind.area
              ? mp.MeasureMode.area
              : mp.MeasureMode.distance,
          points: zone.latLngs,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Правьте вершины на карте. Кнопка «Сохранить» перезапишет «${zone.name}».',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    context.go('/map');
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Zone zone) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Удалить зону?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '«${zone.name}» будет удалена без возможности восстановления.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(zonesProvider.notifier).remove(zone.id);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  static LatLngBounds _boundsFor(List<LatLng> pts) {
    if (pts.isEmpty) {
      return LatLngBounds(
        const LatLng(55.7, 37.6),
        const LatLng(55.8, 37.7),
      );
    }
    var minLat = pts.first.latitude;
    var maxLat = pts.first.latitude;
    var minLng = pts.first.longitude;
    var maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  static String _formatArea(double m2) {
    if (m2 < 10000) return '${m2.toStringAsFixed(0)} м²';
    if (m2 < 1000000) {
      final ha = m2 / 10000;
      return '${ha.toStringAsFixed(ha < 10 ? 2 : 1)} га';
    }
    final km = m2 / 1000000;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} км²';
  }
}
