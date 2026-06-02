import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/tracks_provider.dart';
import '../../../shared/providers/visible_tracks_provider.dart';

/// Renders saved tracks as polylines on the main map. Only tracks whose IDs
/// are in [visibleTracksProvider] are drawn — toggled on/off from
/// TrackDetailScreen's "Show on map" action. Mirrors the ZonesMapLayer
/// pattern.
class TracksMapLayer extends ConsumerWidget {
  const TracksMapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleIds = ref.watch(visibleTracksProvider);
    if (visibleIds.isEmpty) return const SizedBox.shrink();
    final all = ref.watch(tracksProvider).valueOrNull ?? const [];
    final visible = all.where((t) => visibleIds.contains(t.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        // Soft glow underlay.
        PolylineLayer(
          polylines: [
            for (final t in visible)
              if (t.points.length >= 2)
                Polyline(
                  points: t.points.map((p) => p.latLng).toList(),
                  color: t.color.withValues(alpha: 0.25),
                  strokeWidth: 10,
                ),
          ],
        ),
        // Main line.
        PolylineLayer(
          polylines: [
            for (final t in visible)
              if (t.points.length >= 2)
                Polyline(
                  points: t.points.map((p) => p.latLng).toList(),
                  color: t.color,
                  strokeWidth: 4,
                ),
          ],
        ),
      ],
    );
  }
}
