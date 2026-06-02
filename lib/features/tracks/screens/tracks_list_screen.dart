import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/route_path.dart';
import '../../../shared/models/track.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/routes_provider.dart';
import '../../../shared/providers/tracks_provider.dart';
import '../../../shared/providers/zones_provider.dart';

enum _Tab { tracks, routes, zones }

class TracksListScreen extends ConsumerStatefulWidget {
  const TracksListScreen({super.key});

  @override
  ConsumerState<TracksListScreen> createState() => _TracksListScreenState();
}

class _TracksListScreenState extends ConsumerState<TracksListScreen> {
  _Tab _tab = _Tab.tracks;

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(tracksProvider).valueOrNull ?? const [];
    final routes = ref.watch(routesProvider).valueOrNull ?? const [];
    final zones = ref.watch(zonesProvider).valueOrNull ?? const [];
    final rec = ref.watch(trackRecordingProvider);
    final l10n = AppStrings.of(context);

    final isTracks = _tab == _Tab.tracks;
    final isRoutes = _tab == _Tab.routes;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: isTracks
            ? l10n.tracksTab
            : (isRoutes ? l10n.routesTab : l10n.zonesTab),
        subtitle: isTracks
            ? (tracks.isEmpty
                ? null
                : '${tracks.length} ${l10n.tracksRecordedSuffix}')
            : isRoutes
                ? (routes.isEmpty
                    ? null
                    : '${routes.length} ${l10n.tracksCountShort}')
                : (zones.isEmpty
                    ? null
                    : '${zones.length} ${l10n.tracksCountShort}'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings/data'),
            icon: Icon(PhosphorIconsDuotone.swap,
                color: AppColors.textPrimary),
            tooltip: l10n.tracksImportExportTooltip,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 64),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _SegmentedTabs(
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              tracksCount: tracks.length,
              routesCount: routes.length,
              zonesCount: zones.length,
            ),
          ),
          if (rec.isRecording)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                borderColor: Color(rec.colorValue).withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(rec.colorValue),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(duration: 700.ms),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.tracksRecordingPrefix}: ${rec.title}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${Formatters.distance(rec.distanceM)} · ${Formatters.duration(rec.elapsed)} · ${rec.points.length} ${l10n.tracksPointsShort}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final track = ref
                            .read(trackRecordingProvider.notifier)
                            .stopAndBuild();
                        if (track.points.length >= 2) {
                          ref.read(tracksProvider.notifier).add(track);
                        }
                      },
                      child: Text(l10n.commonStop),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: isTracks
                ? _tracksList(tracks)
                : isRoutes
                    ? _routesList(routes)
                    : _zonesList(zones),
          ),
        ],
      ),
    );
  }

  Widget _zonesList(List<Zone> zones) {
    final l10n = AppStrings.of(context);
    if (zones.isEmpty) {
      return EmptyState(
        icon: const Icon(PhosphorIconsDuotone.polygon),
        title: l10n.zonesEmptyTitle2,
        description: l10n.zonesEmptyDesc2,
        actionLabel: l10n.tracksToMap,
        onAction: () => context.go('/map'),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: zones.length,
      itemBuilder: (ctx, i) {
        final z = zones[i];
        return GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          onTap: () => context.push('/tracks/zones/${z.id}'),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: z.color.withValues(alpha: 0.22),
                  border: Border.all(
                    color: z.color.withValues(alpha: 0.6),
                  ),
                ),
                child: Icon(
                  z.kind == ZoneKind.area
                      ? PhosphorIconsDuotone.polygon
                      : PhosphorIconsDuotone.ruler,
                  color: z.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      z.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      z.note.isNotEmpty
                          ? z.note
                          : (z.kind == ZoneKind.area
                              ? l10n.zoneKindArea
                              : l10n.zoneKindDistance),
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (z.kind == ZoneKind.area)
                          _Stat(
                            icon: PhosphorIconsDuotone.polygon,
                            value: _formatArea(z.areaM2),
                          )
                        else
                          _Stat(
                            icon: PhosphorIconsDuotone.ruler,
                            value: Formatters.distance(z.distanceM),
                          ),
                        const SizedBox(width: 14),
                        _Stat(
                          icon: PhosphorIconsDuotone.dotsThreeOutline,
                          value: '${z.vertices.length}',
                        ),
                        const SizedBox(width: 14),
                        _Stat(
                          icon: PhosphorIconsDuotone.clock,
                          value: Formatters.dateTime(z.createdAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        );
      },
    );
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

  Widget _tracksList(List<Track> tracks) {
    final l10n = AppStrings.of(context);
    if (tracks.isEmpty) {
      return EmptyState(
        icon: const Icon(PhosphorIconsDuotone.path),
        title: l10n.tracksEmptyTitle2,
        description: l10n.tracksEmptyDesc2,
        actionLabel: l10n.tracksToMap,
        onAction: () => context.go('/map'),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: tracks.length,
      itemBuilder: (ctx, i) {
        final t = tracks[i];
        return GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          onTap: () => context.push('/tracks/${t.id}'),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: t.color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: t.color.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.dateTime(t.startedAt),
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Stat(
                          icon: PhosphorIconsDuotone.ruler,
                          value: Formatters.distance(t.distanceM),
                        ),
                        const SizedBox(width: 14),
                        _Stat(
                          icon: PhosphorIconsDuotone.clock,
                          value: Formatters.duration(t.duration),
                        ),
                        const SizedBox(width: 14),
                        _Stat(
                          icon: PhosphorIconsDuotone.gauge,
                          value: Formatters.speed(t.avgSpeedMps),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                PhosphorIconsRegular.caretRight,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ],
          ),
        ).animate().fadeIn(
              duration: 260.ms,
              delay: ((i * 40).clamp(0, 400)).ms,
            );
      },
    );
  }

  Widget _routesList(List<RoutePath> routes) {
    final l10n = AppStrings.of(context);
    if (routes.isEmpty) {
      return EmptyState(
        icon: const Icon(PhosphorIconsDuotone.arrowBendUpRight),
        title: l10n.routesEmptyTitle,
        description: l10n.routesEmptyDesc,
        actionLabel: l10n.routesImportGpx,
        onAction: () => context.push('/settings/data'),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: routes.length,
      itemBuilder: (ctx, i) {
        final r = routes[i];
        return GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          onTap: () {},
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentAmber.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppColors.accentAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  _sourceIcon(r.source),
                  color: AppColors.accentAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.waypointCount} ${l10n.tracksPointsShort} · ${Formatters.dateTime(r.createdAt)}',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsRegular.caretRight,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ],
          ),
        ).animate().fadeIn(
              duration: 260.ms,
              delay: ((i * 40).clamp(0, 400)).ms,
            );
      },
    );
  }

  IconData _sourceIcon(RouteSource s) => switch (s) {
        RouteSource.manual => PhosphorIconsDuotone.handPointing,
        RouteSource.gpxImport => PhosphorIconsDuotone.fileArrowDown,
        RouteSource.builtFromPoints => PhosphorIconsDuotone.mapPin,
      };
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.value,
    required this.onChanged,
    required this.tracksCount,
    required this.routesCount,
    required this.zonesCount,
  });

  final _Tab value;
  final ValueChanged<_Tab> onChanged;
  final int tracksCount;
  final int routesCount;
  final int zonesCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          _segment(
            label: l10n.tracksTab,
            count: tracksCount,
            selected: value == _Tab.tracks,
            onTap: () => onChanged(_Tab.tracks),
          ),
          _segment(
            label: l10n.routesTab,
            count: routesCount,
            selected: value == _Tab.routes,
            onTap: () => onChanged(_Tab.routes),
          ),
          _segment(
            label: l10n.zonesTab,
            count: zonesCount,
            selected: value == _Tab.zones,
            onTap: () => onChanged(_Tab.zones),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryGlow
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryGlow.withValues(alpha: 0.2)
                      : AppColors.glassFillStrong,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected
                        ? AppColors.primaryGlow
                        : AppColors.textTertiary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textTertiary, size: 13),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
