import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/providers/navigation_target_provider.dart';
import '../../../shared/providers/points_provider.dart';
import '../../../shared/services/gpx_service.dart';
import '../widgets/poi_marker.dart';

class PointDetailScreen extends ConsumerWidget {
  const PointDetailScreen({super.key, required this.pointId});
  final String pointId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider).valueOrNull ?? const [];
    final point = points.where((p) => p.id == pointId).firstOrNull;
    final l10n = AppStrings.of(context);

    if (point == null) {
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
          child: Text(l10n.pointsDeleted,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: point.title,
        subtitle: l10n.poiCategoryLabel(point.category.name),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(pointsProvider.notifier).toggleFavorite(pointId),
            icon: Icon(
              point.favorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: point.favorite
                  ? AppColors.accentAmber
                  : AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => context.push('/points/${point.id}/edit',
                extra: point),
            icon: Icon(PhosphorIconsDuotone.pencilSimple,
                color: AppColors.textPrimary),
            tooltip: l10n.commonEdit,
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, ref),
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
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          Center(
            child: Column(
              children: [
                Hero(
                  tag: 'poi-preview',
                  child: PoiMarkerIcon(icon: point.icon, size: 104),
                ),
                const SizedBox(height: 14),
                Text(
                  point.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.dateTime(point.createdAt),
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _InfoRow(
                  icon: PhosphorIconsDuotone.crosshair,
                  label: l10n.pointsCoordinates,
                  value: Formatters.latLng(point.coord.lat, point.coord.lng),
                ),
                const Divider(height: 20),
                _InfoRow(
                  icon: PhosphorIconsDuotone.mountains,
                  label: l10n.settingsAltitude,
                  value: Formatters.altitude(point.coord.altitude),
                ),
                const Divider(height: 20),
                _InfoRow(
                  icon: PhosphorIconsDuotone.target,
                  label: l10n.hudAccuracy,
                  value: Formatters.accuracy(point.coord.accuracy),
                ),
              ],
            ),
          ),
          if (point.note.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIconsDuotone.note,
                          color: AppColors.primaryGlow, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l10n.pointsNote,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    point.note,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: l10n.pointsNavigateHere,
                  icon: Icon(PhosphorIconsBold.arrowBendUpRight),
                  onPressed: () {
                    ref.read(navigationTargetProvider.notifier).state = point;
                    context.go('/map');
                  },
                  expanded: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  label: l10n.commonShare,
                  icon: Icon(PhosphorIconsBold.share),
                  variant: GlassButtonVariant.secondary,
                  onPressed: () async {
                    final xml = GpxService.serialize(points: [point]);
                    final file = await GpxService.writeToFile(xml, point.title);
                    final coords =
                        Formatters.latLng(point.coord.lat, point.coord.lng);
                    await Share.shareXFiles(
                      [XFile(file.path)],
                      text: '${point.title} · $coords',
                    );
                  },
                  expanded: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(l10n.pointsDeleteConfirm,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          l10n.zoneDeleteConfirmBody,
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
              ref.read(pointsProvider.notifier).remove(pointId);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
