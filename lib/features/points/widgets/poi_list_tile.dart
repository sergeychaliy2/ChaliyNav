import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/point_of_interest.dart';
import '../../../shared/providers/map_focus_provider.dart';
import 'poi_marker.dart';

class PoiListTile extends ConsumerWidget {
  const PoiListTile({
    super.key,
    required this.point,
    this.onTap,
    this.onLongPress,
  });

  final PointOfInterest point;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppStrings.of(context);
    return GlassCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          PoiMarkerIcon(icon: point.icon, size: 48, ring: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        point.title.isEmpty
                            ? l10n.pointsDefaultName
                            : point.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (point.favorite)
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.accentAmber,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: point.category.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        l10n.poiCategoryLabel(point.category.name),
                        style: TextStyle(
                          color: point.category.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        Formatters.dateTime(point.createdAt),
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (point.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    point.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (point.photos.isNotEmpty || point.audioPath != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (point.photos.isNotEmpty) ...[
                        Icon(
                          Icons.photo_outlined,
                          color: AppColors.textTertiary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${point.photos.length}',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (point.audioPath != null) ...[
                        Icon(
                          Icons.mic_outlined,
                          color: AppColors.textTertiary,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          // "Show on map" quick action — fires a focus request and navigates.
          InkWell(
            onTap: () {
              ref.read(mapFocusRequestProvider.notifier).state = FocusRequest(
                target: LatLng(point.coord.lat, point.coord.lng),
                zoom: 17,
              );
              context.go('/map');
            },
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassFillStrong,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(
                PhosphorIconsDuotone.crosshairSimple,
                color: AppColors.primaryGlow,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
