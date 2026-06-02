import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/zones_provider.dart';

/// Renders saved zones on the map: polygons (area) + polylines (line)
/// with centroid labels. Hidden zones are filtered out via hiddenZoneIdsProvider.
class ZonesMapLayer extends ConsumerWidget {
  const ZonesMapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider).valueOrNull ?? const <Zone>[];
    final hidden = ref.watch(hiddenZoneIdsProvider);
    final visible = zones.where((z) => !hidden.contains(z.id)).toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        if (visible.any((z) => z.kind == ZoneKind.area))
          PolygonLayer(
            polygons: [
              for (final z in visible)
                if (z.kind == ZoneKind.area && z.vertices.length >= 3)
                  Polygon(
                    points: z.latLngs,
                    color: z.color.withValues(alpha: 0.22),
                    borderColor: z.color,
                    borderStrokeWidth: 2,
                    label: z.name,
                    labelStyle: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                    labelPlacement: PolygonLabelPlacement.polylabel,
                  ),
            ],
          ),
        if (visible.any((z) => z.kind == ZoneKind.line))
          PolylineLayer(
            polylines: [
              for (final z in visible)
                if (z.kind == ZoneKind.line && z.vertices.length >= 2)
                  Polyline(
                    points: z.latLngs,
                    color: z.color,
                    strokeWidth: 3.5,
                    borderColor: Colors.black.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.2,
                  ),
            ],
          ),
      ],
    );
  }
}
