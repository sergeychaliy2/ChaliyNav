import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/models/poi_category.dart';
import '../../../shared/models/poi_icon_library.dart';
import '../../../shared/models/point_of_interest.dart';
import '../../../shared/models/weather.dart';
import '../../../shared/providers/points_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../widgets/poi_marker.dart';
import '../widgets/voice_memo_recorder.dart';

class NewPointScreen extends ConsumerStatefulWidget {
  const NewPointScreen({super.key, required this.coord, this.editing});

  final GeoPoint coord;

  /// When non-null — editing an existing POI instead of creating a new one.
  final PointOfInterest? editing;

  @override
  ConsumerState<NewPointScreen> createState() => _NewPointScreenState();
}

class _NewPointScreenState extends ConsumerState<NewPointScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late PoiIcon _icon;
  late PoiCategory _category;
  late bool _favorite;
  String? _audioPath;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final src = widget.editing;
    _title = TextEditingController(text: src?.title ?? '');
    _note = TextEditingController(text: src?.note ?? '');
    _favorite = src?.favorite ?? false;
    _audioPath = src?.audioPath;
    _icon = src?.icon ?? PoiIconLibrary.defaultFor(PoiCategory.fishing);
    _category = _icon.category;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() async {
    final l10n = AppStrings.of(context);
    final title = _title.text.trim();
    if (_isEditing) {
      final edited = widget.editing!.copyWith(
        title: title.isEmpty ? _icon.name : title,
        iconId: _icon.id,
        note: _note.text.trim(),
        favorite: _favorite,
        audioPath: _audioPath,
      );
      await ref.read(pointsProvider.notifier).upsert(edited);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${edited.title}» · ${l10n.pointsSaved}'),
          backgroundColor: _icon.color,
        ),
      );
      return;
    }

    // If "capture weather" is on, stamp the point with the (simulated)
    // weather at its location — no network, see WeatherSim.
    final settings = ref.read(settingsProvider).valueOrNull;
    final wx = (settings?.captureWeather ?? false)
        ? WeatherSim.at(widget.coord.lat, widget.coord.lng)
        : null;

    final point = PointOfInterest(
      id: const Uuid().v4(),
      title: title.isEmpty ? _icon.name : title,
      coord: widget.coord,
      iconId: _icon.id,
      createdAt: DateTime.now(),
      note: _note.text.trim(),
      favorite: _favorite,
      audioPath: _audioPath,
      meta: PoiMeta(
        altitude: widget.coord.altitude,
        weather: wx?.condition.label,
        temperature: wx?.tempC,
      ),
    );
    await ref.read(pointsProvider.notifier).add(point);
    if (!mounted) return;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('«${point.title}» · ${l10n.pointsSaved}'),
          ],
        ),
        backgroundColor: _icon.color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: _isEditing ? l10n.newPointEditTitle : l10n.newPointTitle,
        subtitle: Formatters.latLng(widget.coord.lat, widget.coord.lng),
        leading: IconButton(
          icon: Icon(PhosphorIconsBold.x, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _favorite = !_favorite),
            icon: Icon(
              _favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _favorite ? AppColors.accentAmber : AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 80,
          bottom: MediaQuery.of(context).padding.bottom + 120,
          left: 16,
          right: 16,
        ),
        children: [
          // Big preview of selected icon + quick info
          Center(
            child: Column(
              children: [
                Hero(
                  tag: 'poi-preview',
                  child: PoiMarkerIcon(icon: _icon, size: 96),
                ).animate().scale(
                      duration: 300.ms,
                      curve: Curves.easeOutBack,
                      begin: const Offset(0.8, 0.8),
                    ),
                const SizedBox(height: 12),
                Text(
                  _icon.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.poiCategoryLabel(_category.name),
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Title input
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.textT,
                    color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.newPointName,
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                VoiceMemoRecorderButton(
                  existingPath: _audioPath,
                  onRecorded: (path) => setState(() => _audioPath = path),
                  onCleared: () => setState(() => _audioPath = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Note input
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '${l10n.newPointNote}…',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Category selector
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              l10n.newPointCategory.toUpperCase(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in PoiCategory.values) ...[
                  _CategoryButton(
                    category: c,
                    selected: c == _category,
                    onTap: () => setState(() {
                      _category = c;
                      _icon = PoiIconLibrary.defaultFor(c);
                    }),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Icon grid for current category
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              l10n.newPointIcon.toUpperCase(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.all(10),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 82,
              ),
              itemCount: PoiIconLibrary.byCategory(_category).length,
              itemBuilder: (ctx, i) {
                final icon = PoiIconLibrary.byCategory(_category)[i];
                final selected = icon.id == _icon.id;
                return GestureDetector(
                  onTap: () => setState(() => _icon = icon),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: selected
                          ? icon.color.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? icon.color.withValues(alpha: 0.6)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PoiMarkerIcon(icon: icon, size: 38, ring: false),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            icon.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: l10n.commonCancel,
                  variant: GlassButtonVariant.secondary,
                  onPressed: () => context.pop(),
                  expanded: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GlassButton(
                  label: l10n.commonSave,
                  icon: Icon(PhosphorIconsBold.check),
                  onPressed: _save,
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

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final PoiCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.18)
              : AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? category.color.withValues(alpha: 0.6)
                : AppColors.glassBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.icon,
              color: selected ? category.color : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.poiCategoryLabel(category.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
