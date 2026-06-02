import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/poi_category.dart';
import '../../../shared/providers/points_provider.dart';
import '../widgets/poi_list_tile.dart';

class PointsListScreen extends ConsumerStatefulWidget {
  const PointsListScreen({super.key});

  @override
  ConsumerState<PointsListScreen> createState() => _PointsListScreenState();
}

class _PointsListScreenState extends ConsumerState<PointsListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(filteredPointsProvider);
    final filter = ref.watch(pointsFilterProvider);
    final total = ref.watch(pointsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: AppStrings.of(context).pointsAll,
        subtitle: total == 0 ? null : '${points.length} / $total',
        actions: [
          IconButton(
            onPressed: () => _showSortSheet(),
            icon: Icon(PhosphorIconsDuotone.funnel,
                color: AppColors.textPrimary),
          ),
          IconButton(
            onPressed: () => setState(() => _searchOpen = !_searchOpen),
            icon: Icon(
              _searchOpen
                  ? PhosphorIconsBold.x
                  : PhosphorIconsDuotone.magnifyingGlass,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => _showExportSheet(),
            icon: Icon(PhosphorIconsDuotone.export,
                color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 64),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _searchOpen ? _searchBar() : const SizedBox.shrink(),
          ),
          _categoryStrip(filter.category),
          Expanded(
            child: points.isEmpty
                ? EmptyState(
                    icon: const Icon(PhosphorIconsDuotone.mapPin),
                    title: total == 0
                        ? AppStrings.of(context).pointsEmptyTitle
                        : AppStrings.of(context).pointsFilterEmpty,
                    description: total == 0
                        ? AppStrings.of(context).pointsEmptyEncourage
                        : AppStrings.of(context).pointsFilterEmptySub,
                    actionLabel:
                        total == 0 ? AppStrings.of(context).pointsOpenMap : null,
                    onAction: total == 0 ? () => context.go('/map') : null,
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 100,
                    ),
                    itemCount: points.length,
                    itemBuilder: (ctx, i) {
                      final p = points[i];
                      return PoiListTile(
                        point: p,
                        onTap: () => context.push('/points/${p.id}'),
                      ).animate().fadeIn(
                            duration: 260.ms,
                            delay: ((i * 30).clamp(0, 400)).ms,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            Icon(
              PhosphorIconsDuotone.magnifyingGlass,
              color: AppColors.textTertiary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: AppStrings.of(context).pointsSearchPlaceholder,
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) {
                  ref.read(pointsFilterProvider.notifier).state =
                      ref.read(pointsFilterProvider).copyWith(query: v);
                },
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                iconSize: 16,
                onPressed: () {
                  _searchCtrl.clear();
                  ref.read(pointsFilterProvider.notifier).state =
                      ref.read(pointsFilterProvider).copyWith(query: '');
                },
                icon: Icon(PhosphorIconsBold.x,
                    color: AppColors.textTertiary, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryStrip(PoiCategory? selected) {
    final l10n = AppStrings.of(context);
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          _CategoryChip(
            icon: PhosphorIconsDuotone.squaresFour,
            label: l10n.catAll,
            selected: selected == null,
            onTap: () {
              ref.read(pointsFilterProvider.notifier).state = ref
                  .read(pointsFilterProvider)
                  .copyWith(clearCategory: true);
            },
          ),
          for (final cat in PoiCategory.values)
            _CategoryChip(
              icon: cat.icon,
              label: l10n.poiCategoryLabel(cat.name),
              color: cat.color,
              selected: selected == cat,
              onTap: () {
                ref.read(pointsFilterProvider.notifier).state =
                    ref.read(pointsFilterProvider).copyWith(category: cat);
              },
            ),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final filter = ref.watch(pointsFilterProvider);
        final l10n = AppStrings.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.glassBorderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.pointsSort,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 10),
                ...PointsSort.values.map((s) => RadioListTile<PointsSort>(
                      value: s,
                      groupValue: filter.sort,
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(pointsFilterProvider.notifier).state =
                              filter.copyWith(sort: v);
                        }
                        Navigator.pop(context);
                      },
                      activeColor: AppColors.primaryGlow,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.pointsSortLabel(s.name),
                          style: const TextStyle(color: AppColors.textPrimary)),
                    )),
                const Divider(),
                SwitchListTile(
                  value: filter.favoritesOnly,
                  onChanged: (v) {
                    ref.read(pointsFilterProvider.notifier).state =
                        filter.copyWith(favoritesOnly: v);
                  },
                  activeColor: AppColors.primaryGlow,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pointsFavoritesOnly,
                      style: const TextStyle(color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExportSheet() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).pointsExportSoon)),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primaryGlow;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? tint.withValues(alpha: 0.2)
                  : AppColors.glassFill,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected
                    ? tint.withValues(alpha: 0.6)
                    : AppColors.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: selected ? tint : AppColors.textSecondary, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? tint : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
