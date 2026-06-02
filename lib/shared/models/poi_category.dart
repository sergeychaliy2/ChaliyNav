import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';

/// Top-level POI categories. Broad audience: fishing, hunting, tourism,
/// mushrooms/berries, treasure hunting, infrastructure, dangers, other.
enum PoiCategory {
  fishing,
  hunting,
  tourism,
  mushrooms,
  treasure,
  infra,
  danger,
  other;

  String get label => switch (this) {
        PoiCategory.fishing => 'Рыбалка',
        PoiCategory.hunting => 'Охота',
        PoiCategory.tourism => 'Туризм',
        PoiCategory.mushrooms => 'Грибы и ягоды',
        PoiCategory.treasure => 'Поиск',
        PoiCategory.infra => 'Инфраструктура',
        PoiCategory.danger => 'Опасности',
        PoiCategory.other => 'Прочее',
      };

  Color get color => switch (this) {
        PoiCategory.fishing => AppColors.poiFishing,
        PoiCategory.hunting => AppColors.poiHunting,
        PoiCategory.tourism => AppColors.poiTourism,
        PoiCategory.mushrooms => AppColors.poiMushrooms,
        PoiCategory.treasure => AppColors.poiTreasure,
        PoiCategory.infra => AppColors.poiInfra,
        PoiCategory.danger => AppColors.poiDanger,
        PoiCategory.other => AppColors.poiOther,
      };

  /// Fallback Phosphor icon shown until custom SVG packs are loaded.
  IconData get icon => switch (this) {
        PoiCategory.fishing => PhosphorIconsDuotone.fish,
        PoiCategory.hunting => PhosphorIconsDuotone.pawPrint,
        PoiCategory.tourism => PhosphorIconsDuotone.tent,
        PoiCategory.mushrooms => PhosphorIconsDuotone.plant,
        PoiCategory.treasure => PhosphorIconsDuotone.treasureChest,
        PoiCategory.infra => PhosphorIconsDuotone.house,
        PoiCategory.danger => PhosphorIconsDuotone.warning,
        PoiCategory.other => PhosphorIconsDuotone.mapPin,
      };
}

/// Concrete icon variant inside a category (e.g. "Pike" inside Fishing).
/// Uses SVG asset path when available, otherwise falls back to Phosphor icon.
class PoiIcon {
  const PoiIcon({
    required this.id,
    required this.name,
    required this.category,
    this.svgAsset,
    this.fallbackIcon,
    this.tintColor,
  });

  final String id;
  final String name;
  final PoiCategory category;
  final String? svgAsset;
  final IconData? fallbackIcon;
  final Color? tintColor;

  Color get color => tintColor ?? category.color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        if (svgAsset != null) 'svg': svgAsset,
        if (tintColor != null) 'tint': tintColor!.toARGB32(),
      };

  factory PoiIcon.fromJson(Map<String, dynamic> j) => PoiIcon(
        id: j['id'] as String,
        name: j['name'] as String,
        category: PoiCategory.values.firstWhere(
          (c) => c.name == j['category'],
          orElse: () => PoiCategory.other,
        ),
        svgAsset: j['svg'] as String?,
        tintColor: j['tint'] == null ? null : Color(j['tint'] as int),
      );
}
