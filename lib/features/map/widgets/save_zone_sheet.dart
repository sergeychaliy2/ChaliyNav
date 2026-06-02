import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/measure_provider.dart';
import '../../../shared/providers/zones_provider.dart';

/// Bottom sheet for saving the current measurement (polygon or polyline)
/// as a named Zone (квартал / угодье / аквазона).
class SaveZoneSheet extends ConsumerStatefulWidget {
  const SaveZoneSheet({super.key});

  @override
  ConsumerState<SaveZoneSheet> createState() => _SaveZoneSheetState();
}

class _SaveZoneSheetState extends ConsumerState<SaveZoneSheet> {
  final _name = TextEditingController();
  ZonePurpose _purpose = ZonePurpose.custom;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    final existingName = ref.read(measureProvider).editingZoneName;
    if (existingName != null && existingName.isNotEmpty) {
      _name.text = existingName;
    }
    _prefilled = true;
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(measureProvider);
    final isArea = m.mode == MeasureMode.area && m.points.length >= 3;
    final isLine = m.mode == MeasureMode.distance && m.points.length >= 2;
    final l10n = AppStrings.of(context);

    if (!isArea && !isLine) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            l10n.measureAreaHint,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        // Clear both the soft keyboard and the bottom nav / system insets.
        bottom: media.viewInsets.bottom + media.padding.bottom + 24,
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
              Icon(
                isArea
                    ? PhosphorIconsDuotone.polygon
                    : PhosphorIconsDuotone.ruler,
                color: AppColors.primaryGlow,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.isEditing ? l10n.commonEdit : l10n.saveZoneTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (m.isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    l10n.commonEdit.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accentAmber,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isArea
                ? '${l10n.measureArea}: ${_formatArea(m.areaM2)} · '
                    '${l10n.measurePerimeter}: ${Formatters.distance(m.totalDistanceM)} · '
                    '${m.points.length} ${l10n.tracksPointsShort}'
                : '${l10n.measureDistance}: ${Formatters.distance(m.totalDistanceM)} · '
                    '${m.points.length} ${l10n.tracksPointsShort}',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: l10n.saveZoneName,
              hintText: l10n.saveZoneNameHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.saveZoneType.toUpperCase(),
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in ZonePurpose.values)
                GestureDetector(
                  onTap: () => setState(() => _purpose = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _purpose == p
                          ? p.color.withValues(alpha: 0.2)
                          : AppColors.glassFill,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _purpose == p
                            ? p.color.withValues(alpha: 0.6)
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.zonePurposeLabel(p.name),
                          style: TextStyle(
                            color: _purpose == p
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: _purpose == p
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: l10n.commonCancel,
                  variant: GlassButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                  expanded: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GlassButton(
                  label: l10n.commonSave,
                  icon: Icon(PhosphorIconsBold.check),
                  onPressed: () => _save(m),
                  expanded: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(MeasureState m) async {
    final l10n = AppStrings.of(context);
    final fallbackName = m.mode == MeasureMode.area
        ? l10n.zoneKindArea
        : l10n.zoneKindDistance;
    final name =
        _name.text.trim().isEmpty ? fallbackName : _name.text.trim();

    // Keep original id when editing; generate fresh otherwise.
    final id = m.isEditing ? m.editingZoneId! : const Uuid().v4();
    final zone = Zone(
      id: id,
      name: name,
      kind: m.mode == MeasureMode.area ? ZoneKind.area : ZoneKind.line,
      vertices: m.points
          .map((p) => ZoneVertex(lat: p.latitude, lng: p.longitude))
          .toList(),
      createdAt: DateTime.now(),
      colorValue: _purpose.color.toARGB32(),
      areaM2: m.areaM2,
      perimeterM: m.mode == MeasureMode.area ? m.totalDistanceM : 0,
      distanceM: m.mode == MeasureMode.distance ? m.totalDistanceM : 0,
      note: l10n.zonePurposeLabel(_purpose.name),
    );
    await ref.read(zonesProvider.notifier).upsert(zone);
    if (!mounted) return;
    Navigator.of(context).pop();
    ref.read(measureProvider.notifier).turnOff();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${zone.name}» · ${l10n.pointsSaved}'),
        backgroundColor: _purpose.color,
      ),
    );
  }

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

/// Reusable card that can be shown above MapScreen when a zone is saved.
class ZonePill extends StatelessWidget {
  const ZonePill({
    super.key,
    required this.zone,
    this.onTap,
  });

  final Zone zone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: zone.color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            zone.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// --- helpers exported here so the sheet stays self-contained ---
LatLng latLngFrom(ZoneVertex v) => LatLng(v.lat, v.lng);
