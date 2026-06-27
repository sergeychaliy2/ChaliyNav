import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/track.dart';
import '../../../shared/providers/map_focus_provider.dart';
import '../../../shared/providers/tracks_provider.dart';
import '../../../shared/providers/visible_tracks_provider.dart';
import '../../../shared/services/cached_tile_provider.dart';
import '../../../shared/services/gpx_service.dart';

/// Detail view for a saved track — mini preview map, stats, actions.
/// Mirrors the ZoneDetailScreen so tracks and zones feel consistent.
class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({super.key, required this.trackId});
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    final tracks = ref.watch(tracksProvider).valueOrNull ?? const <Track>[];
    final track = tracks.where((t) => t.id == trackId).firstOrNull;

    if (track == null) {
      return Scaffold(
        appBar: GlassAppBar(
          title: l10n.commonNotFound,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(PhosphorIconsBold.arrowLeft,
                color: AppColors.textPrimary),
          ),
        ),
        body: Center(
          child: Text(l10n.commonNotFound,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final latLngs = track.points.map((p) => p.latLng).toList();
    final bounds = _boundsFor(latLngs);
    final visibleOnMap =
        ref.watch(visibleTracksProvider).contains(track.id);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: track.title,
        subtitle: Formatters.dateTime(track.startedAt),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: l10n.commonShare,
            onPressed: () => _shareGpx(context, track),
            icon: Icon(PhosphorIconsDuotone.export,
                color: AppColors.textPrimary),
          ),
          IconButton(
            tooltip: l10n.commonDelete,
            onPressed: () => _confirmDelete(context, ref, track),
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
              height: 240,
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
                      if (latLngs.length >= 2) ...[
                        // Soft glow.
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: latLngs,
                              color: track.color.withValues(alpha: 0.3),
                              strokeWidth: 10,
                            ),
                          ],
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: latLngs,
                              color: track.color,
                              strokeWidth: 3.5,
                            ),
                          ],
                        ),
                      ],
                      // Start / finish markers.
                      if (latLngs.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: latLngs.first,
                              width: 16,
                              height: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                            if (latLngs.length > 1)
                              Marker(
                                point: latLngs.last,
                                width: 16,
                                height: 16,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
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

          // Stats row
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _statCol(
                    icon: PhosphorIconsDuotone.ruler,
                    label: l10n.tracksDistance,
                    value: Formatters.distance(track.distanceM),
                    color: track.color,
                  ),
                ),
                Container(width: 1, height: 34, color: AppColors.divider),
                Expanded(
                  child: _statCol(
                    icon: PhosphorIconsDuotone.clock,
                    label: l10n.tracksDuration,
                    value: Formatters.duration(track.duration),
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(width: 1, height: 34, color: AppColors.divider),
                Expanded(
                  child: _statCol(
                    icon: PhosphorIconsDuotone.gauge,
                    label: l10n.hudSpeed,
                    value: Formatters.speed(track.avgSpeedMps),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _statCol(
                    icon: PhosphorIconsDuotone.dotsThreeOutline,
                    label: l10n.tracksPoints,
                    value: '${track.points.length}',
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(width: 1, height: 34, color: AppColors.divider),
                Expanded(
                  child: _statCol(
                    icon: PhosphorIconsDuotone.trendUp,
                    label: 'Max',
                    value: Formatters.speed(track.maxSpeedMps),
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(width: 1, height: 34, color: AppColors.divider),
                Expanded(
                  child: _statCol(
                    icon: PhosphorIconsDuotone.mountains,
                    label: '↑ ${track.ascentM.toStringAsFixed(0)} м',
                    value: '↓ ${track.descentM.toStringAsFixed(0)} м',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Show on map / hide
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: visibleOnMap
                      ? l10n.commonRemove
                      : l10n.pointsShowOnMap,
                  icon: Icon(visibleOnMap
                      ? PhosphorIconsBold.eyeSlash
                      : PhosphorIconsBold.eye),
                  variant: visibleOnMap
                      ? GlassButtonVariant.secondary
                      : GlassButtonVariant.primary,
                  onPressed: () {
                    final n = ref.read(visibleTracksProvider.notifier);
                    if (visibleOnMap) {
                      n.hide(track.id);
                    } else {
                      n.show(track.id);
                      // Also recenter the camera on the track bounds.
                      ref.read(mapFocusRequestProvider.notifier).state =
                          FocusRequest(
                        target: LatLng(
                          (bounds.north + bounds.south) / 2,
                          (bounds.east + bounds.west) / 2,
                        ),
                        zoom: 13,
                      );
                      context.go('/map');
                    }
                  },
                  expanded: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Meta card
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow(
                  icon: PhosphorIconsDuotone.playCircle,
                  label: l10n.pointsCreated,
                  value: Formatters.dateTime(track.startedAt),
                ),
                const SizedBox(height: 8),
                _metaRow(
                  icon: PhosphorIconsDuotone.stopCircle,
                  label: l10n.commonStop,
                  value: Formatters.dateTime(track.finishedAt),
                ),
                if (track.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _metaRow(
                    icon: PhosphorIconsDuotone.note,
                    label: l10n.pointsNote,
                    value: track.note,
                  ),
                ],
              ],
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _metaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _shareGpx(BuildContext context, Track track) async {
    try {
      final xml = GpxService.serialize(tracks: [track]);
      final file = await GpxService.writeToFile(xml, track.title);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${track.title} · ${Formatters.distance(track.distanceM)}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.of(context).commonError}: $e')),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Track track) {
    final l10n = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(l10n.tracksDeleteConfirm,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '«${track.title}» · ${Formatters.distance(track.distanceM)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(tracksProvider.notifier).remove(track.id);
              ref.read(visibleTracksProvider.notifier).hide(track.id);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.commonDelete),
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
}
