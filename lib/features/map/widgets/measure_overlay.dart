import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../shared/providers/measure_provider.dart';
import 'save_zone_sheet.dart';

/// Convert pixel delta to lat/lng delta using Web-Mercator meters-per-pixel
/// at a given zoom / latitude. More stable than camera.pointToLatLng because
/// it doesn't need the widget's RenderBox origin.
LatLng _shiftLatLng(LatLng from, Offset pixelDelta, double zoom) {
  const earthCircumference = 40075016.686;
  final latRad = from.latitude * math.pi / 180.0;
  final mpp = earthCircumference * math.cos(latRad) / math.pow(2, zoom + 8);
  const metersPerDegLat = 111320.0;
  final metersPerDegLng = 111320.0 * math.cos(latRad);
  // Screen-y grows downward, latitude grows upward → negate dy.
  final dLat = -pixelDelta.dy * mpp / metersPerDegLat;
  final dLng = pixelDelta.dx * mpp / metersPerDegLng;
  return LatLng(from.latitude + dLat, from.longitude + dLng);
}

/// FlutterMap layer that renders the measurement polyline/polygon + vertex
/// dots. Each vertex is tap/drag-aware (see [_VertexMarker]).
class MeasureMapLayer extends ConsumerWidget {
  const MeasureMapLayer({
    super.key,
    required this.mapController,
  });

  final MapController mapController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(measureProvider);
    if (!m.isActive) return const SizedBox.shrink();
    final color = m.mode == MeasureMode.area
        ? AppColors.accentAmber
        : AppColors.accentCyan;

    final polylinePoints = m.mode == MeasureMode.area && m.points.length >= 3
        ? [...m.points, m.points.first]
        : m.points;

    return Stack(
      children: [
        if (m.mode == MeasureMode.area && m.points.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: m.points,
                color: color.withValues(alpha: 0.18),
                borderColor: color,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (polylinePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                color: color,
                strokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [12, 8]),
              ),
            ],
          ),
        if (m.points.isNotEmpty)
          MarkerLayer(
            markers: [
              for (var i = 0; i < m.points.length; i++)
                Marker(
                  point: m.points[i],
                  width: 120,
                  height: 34,
                  alignment: Alignment.center,
                  child: _VertexMarker(
                    index: i,
                    color: color,
                    name: m.names[i],
                    mapController: mapController,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _VertexMarker extends ConsumerStatefulWidget {
  const _VertexMarker({
    required this.index,
    required this.color,
    required this.name,
    required this.mapController,
  });

  final int index;
  final Color color;
  final String? name;
  final MapController mapController;

  @override
  ConsumerState<_VertexMarker> createState() => _VertexMarkerState();
}

class _VertexMarkerState extends ConsumerState<_VertexMarker> {
  bool _dragging = false;
  Offset? _longPressAnchor;

  void _onPanUpdate(DragUpdateDetails d) {
    final state = ref.read(measureProvider);
    if (widget.index >= state.points.length) return;
    double zoom;
    try {
      zoom = widget.mapController.camera.zoom;
    } catch (_) {
      return;
    }
    final cur = state.points[widget.index];
    final next = _shiftLatLng(cur, d.delta, zoom);
    ref.read(measureProvider.notifier).updatePoint(widget.index, next);
  }

  @override
  Widget build(BuildContext context) {
    final hasName = widget.name != null && widget.name!.trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openVertexSheet(context),
      onLongPressStart: (_) {
        _longPressAnchor = Offset.zero;
        setState(() => _dragging = true);
      },
      onLongPressMoveUpdate: (d) {
        final state = ref.read(measureProvider);
        if (widget.index >= state.points.length) return;
        double zoom;
        try {
          zoom = widget.mapController.camera.zoom;
        } catch (_) {
          return;
        }
        final cur = state.points[widget.index];
        // localOffsetFromOrigin is the cumulative delta since long-press start.
        // We only want the instantaneous motion, so use offsetFromOrigin delta
        // against the last-applied value by updating the anchor each tick.
        final anchor = _longPressAnchor ?? d.localOffsetFromOrigin;
        final delta = d.localOffsetFromOrigin - anchor;
        if (delta == Offset.zero) return;
        _longPressAnchor = d.localOffsetFromOrigin;
        final next = _shiftLatLng(cur, delta, zoom);
        ref.read(measureProvider.notifier).updatePoint(widget.index, next);
      },
      onLongPressEnd: (_) {
        _longPressAnchor = null;
        setState(() => _dragging = false);
      },
      onPanStart: (_) => setState(() => _dragging = true),
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) => setState(() => _dragging = false),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasName && !_dragging)
            Positioned(
              top: -2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                constraints: const BoxConstraints(maxWidth: 110),
                decoration: BoxDecoration(
                  color: AppColors.bgDeepest.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  widget.name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Positioned(
            top: hasName ? 14 : null,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              scale: _dragging ? 1.35 : 1.0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: _dragging ? 12 : 6,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openVertexSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VertexSheet(
        index: widget.index,
        color: widget.color,
      ),
    );
  }
}

class _VertexSheet extends ConsumerStatefulWidget {
  const _VertexSheet({required this.index, required this.color});
  final int index;
  final Color color;

  @override
  ConsumerState<_VertexSheet> createState() => _VertexSheetState();
}

class _VertexSheetState extends ConsumerState<_VertexSheet> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final current = ref.read(measureProvider).names[widget.index] ?? '';
    _name = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
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
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${AppStrings.of(context).pointsDefaultName} ${widget.index + 1}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.of(context).measureHint,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: AppStrings.of(context).newPointName,
              hintText: AppStrings.of(context).saveZoneNameHint,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: AppStrings.of(context).commonDelete,
                  icon: Icon(PhosphorIconsBold.trash),
                  variant: GlassButtonVariant.danger,
                  onPressed: () {
                    ref
                        .read(measureProvider.notifier)
                        .removePoint(widget.index);
                    Navigator.of(context).pop();
                  },
                  expanded: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GlassButton(
                  label: AppStrings.of(context).commonSave,
                  icon: Icon(PhosphorIconsBold.check),
                  onPressed: () {
                    ref
                        .read(measureProvider.notifier)
                        .setName(widget.index, _name.text);
                    Navigator.of(context).pop();
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
}

/// Floating panel shown at the top of the map while measuring.
class MeasurePanel extends ConsumerWidget {
  const MeasurePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(measureProvider);
    if (!m.isActive) return const SizedBox.shrink();
    final l10n = AppStrings.of(context);

    final isArea = m.mode == MeasureMode.area;
    final color = isArea ? AppColors.accentAmber : AppColors.accentCyan;
    final distance = Formatters.distance(m.totalDistanceM);
    final areaText = _formatArea(m.areaM2);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.bgDeepest.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isArea
                    ? PhosphorIconsDuotone.polygon
                    : PhosphorIconsDuotone.ruler,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArea ? l10n.measureArea : l10n.measureDistance,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isArea ? areaText : distance,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (isArea && m.points.length >= 2)
                    Text(
                      '${l10n.measurePerimeter}: $distance',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: AppColors.glassBorder),
              const SizedBox(width: 4),
              _iconButton(
                PhosphorIconsDuotone.floppyDisk,
                l10n.measureSaveAsZone,
                _canSave(m)
                    ? () => showModalBottomSheet(
                          context: context,
                          backgroundColor: AppColors.bgSurface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24)),
                          ),
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const SaveZoneSheet(),
                        )
                    : null,
                highlight: true,
              ),
              _iconButton(
                PhosphorIconsDuotone.arrowUUpLeft,
                l10n.commonBack,
                m.points.isEmpty
                    ? null
                    : () => ref.read(measureProvider.notifier).undo(),
              ),
              _iconButton(
                PhosphorIconsDuotone.trash,
                l10n.measureClear,
                m.points.isEmpty
                    ? null
                    : () => ref.read(measureProvider.notifier).clear(),
              ),
              _iconButton(
                PhosphorIconsBold.x,
                l10n.measureExit,
                () => ref.read(measureProvider.notifier).turnOff(),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.15, end: 0);
  }

  Widget _iconButton(
    IconData icon,
    String tip,
    VoidCallback? onPressed, {
    bool highlight = false,
  }) {
    final color = onPressed == null
        ? AppColors.textDisabled
        : (highlight ? AppColors.primaryGlow : AppColors.textPrimary);
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: color,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  bool _canSave(MeasureState m) =>
      (m.mode == MeasureMode.area && m.points.length >= 3) ||
      (m.mode == MeasureMode.distance && m.points.length >= 2);

  String _formatArea(double m2) {
    if (m2 < 10000) return '${m2.toStringAsFixed(0)} м²';
    if (m2 < 1000000) {
      final ha = m2 / 10000;
      return '${ha.toStringAsFixed(ha < 10 ? 2 : 1)} га';
    }
    final km = m2 / 1000000;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} км²';
  }
}
