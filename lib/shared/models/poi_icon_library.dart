import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'poi_category.dart';

// Material fallbacks used for POIs where Phosphor has no equivalent glyph.
const IconData _mdParking = Icons.local_parking;

/// Built-in icon library. For species where Phosphor only has a generic
/// "fish" / "pawPrint", we differentiate via distinct tint colors so the
/// user can still tell them apart on the map until custom SVG packs land.
class PoiIconLibrary {
  PoiIconLibrary._();

  // Distinct species tints. Pure colors intentionally — these need to be
  // identifiable on satellite + dark schema alike.
  static const _pike = Color(0xFF84CC16); // olive green
  static const _perch = Color(0xFFEF4444); // red-orange (Russian okun' stripes)
  static const _carp = Color(0xFFF59E0B); // gold
  static const _pikeperch = Color(0xFF06B6D4); // teal-cyan
  static const _catfish = Color(0xFF6B7280); // slate grey
  static const _bream = Color(0xFFE0E7FF); // silver-blue
  static const _trout = Color(0xFFEC4899); // pink (rainbow trout)

  static const _boar = Color(0xFF78350F); // dark brown
  static const _elk = Color(0xFF92400E); // burnt sienna
  static const _deer = Color(0xFFD97706); // warm orange
  static const _bear = Color(0xFF1F2937); // almost black
  static const _fox = Color(0xFFEA580C); // orange
  static const _hare = Color(0xFFFBBF24); // amber-yellow
  static const _duck = Color(0xFF14B8A6); // teal

  static const _porcini = Color(0xFFA16207); // warm brown
  static const _chanterelle = Color(0xFFF59E0B); // golden
  static const _blueberry = Color(0xFF3B82F6); // blueberry blue
  static const _cranberry = Color(0xFFDC2626); // cranberry red

  static const List<PoiIcon> _icons = [
    // === Рыбалка ===
    PoiIcon(
      id: 'fish_generic',
      name: 'Рыба',
      category: PoiCategory.fishing,
      fallbackIcon: PhosphorIconsDuotone.fish,
    ),
    PoiIcon(
      id: 'fish_pike',
      name: 'Щука',
      category: PoiCategory.fishing,
      svgAsset: 'assets/icons/fish/pike.svg',
      fallbackIcon: PhosphorIconsFill.fish,
      tintColor: _pike,
    ),
    PoiIcon(
      id: 'fish_perch',
      name: 'Окунь',
      category: PoiCategory.fishing,
      svgAsset: 'assets/icons/fish/perch.svg',
      fallbackIcon: PhosphorIconsFill.fish,
      tintColor: _perch,
    ),
    PoiIcon(
      id: 'fish_carp',
      name: 'Карп',
      category: PoiCategory.fishing,
      svgAsset: 'assets/icons/fish/carp.svg',
      fallbackIcon: PhosphorIconsFill.fishSimple,
      tintColor: _carp,
    ),
    PoiIcon(
      id: 'fish_pikeperch',
      name: 'Судак',
      category: PoiCategory.fishing,
      svgAsset: 'assets/icons/fish/pikeperch.svg',
      fallbackIcon: PhosphorIconsFill.fish,
      tintColor: _pikeperch,
    ),
    PoiIcon(
      id: 'fish_catfish',
      name: 'Сом',
      category: PoiCategory.fishing,
      svgAsset: 'assets/icons/fish/catfish.svg',
      fallbackIcon: PhosphorIconsFill.fishSimple,
      tintColor: _catfish,
    ),
    PoiIcon(
      id: 'fish_bream',
      name: 'Лещ',
      category: PoiCategory.fishing,
      svgAsset: 'assets/icons/fish/bream.svg',
      fallbackIcon: PhosphorIconsDuotone.fishSimple,
      tintColor: _bream,
    ),
    PoiIcon(
      id: 'fish_trout',
      name: 'Форель',
      category: PoiCategory.fishing,
      svgAsset: 'assets/icons/fish/trout.svg',
      fallbackIcon: PhosphorIconsFill.fish,
      tintColor: _trout,
    ),
    PoiIcon(
      id: 'fishing_spot',
      name: 'Заброс',
      category: PoiCategory.fishing,
      fallbackIcon: PhosphorIconsDuotone.target,
    ),
    PoiIcon(
      id: 'fishing_anchor',
      name: 'Якорь',
      category: PoiCategory.fishing,
      fallbackIcon: PhosphorIconsDuotone.anchor,
    ),
    PoiIcon(
      id: 'fishing_depth',
      name: 'Глубина',
      category: PoiCategory.fishing,
      fallbackIcon: PhosphorIconsDuotone.waves,
    ),

    // === Охота ===
    PoiIcon(
      id: 'game_tracks',
      name: 'Следы',
      category: PoiCategory.hunting,
      fallbackIcon: PhosphorIconsDuotone.pawPrint,
    ),
    PoiIcon(
      id: 'game_boar',
      name: 'Кабан',
      category: PoiCategory.hunting,
      svgAsset: 'assets/icons/game/boar.svg',
      fallbackIcon: PhosphorIconsFill.pawPrint,
      tintColor: _boar,
    ),
    PoiIcon(
      id: 'game_elk',
      name: 'Лось',
      category: PoiCategory.hunting,
      svgAsset: 'assets/icons/game/elk.svg',
      fallbackIcon: PhosphorIconsFill.pawPrint,
      tintColor: _elk,
    ),
    PoiIcon(
      id: 'game_deer',
      name: 'Олень',
      category: PoiCategory.hunting,
      svgAsset: 'assets/icons/game/deer.svg',
      fallbackIcon: PhosphorIconsFill.pawPrint,
      tintColor: _deer,
    ),
    PoiIcon(
      id: 'game_bear',
      name: 'Медведь',
      category: PoiCategory.hunting,
      svgAsset: 'assets/icons/game/bear.svg',
      fallbackIcon: PhosphorIconsFill.pawPrint,
      tintColor: _bear,
    ),
    PoiIcon(
      id: 'game_fox',
      name: 'Лиса',
      category: PoiCategory.hunting,
      svgAsset: 'assets/icons/game/fox.svg',
      fallbackIcon: PhosphorIconsFill.pawPrint,
      tintColor: _fox,
    ),
    PoiIcon(
      id: 'game_hare',
      name: 'Заяц',
      category: PoiCategory.hunting,
      svgAsset: 'assets/icons/game/hare.svg',
      fallbackIcon: PhosphorIconsFill.pawPrint,
      tintColor: _hare,
    ),
    PoiIcon(
      id: 'game_duck',
      name: 'Утка',
      category: PoiCategory.hunting,
      svgAsset: 'assets/icons/game/duck.svg',
      fallbackIcon: PhosphorIconsFill.bird,
      tintColor: _duck,
    ),
    PoiIcon(
      id: 'game_blind',
      name: 'Засидка',
      category: PoiCategory.hunting,
      fallbackIcon: PhosphorIconsDuotone.binoculars,
    ),
    PoiIcon(
      id: 'game_feeder',
      name: 'Кормушка',
      category: PoiCategory.hunting,
      fallbackIcon: PhosphorIconsDuotone.bowlFood,
    ),

    // === Туризм ===
    PoiIcon(
      id: 'tour_camp',
      name: 'Стоянка',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.tent,
    ),
    PoiIcon(
      id: 'tour_fire',
      name: 'Костёр',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.campfire,
    ),
    PoiIcon(
      id: 'tour_spring',
      name: 'Родник',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.drop,
    ),
    PoiIcon(
      id: 'tour_peak',
      name: 'Вершина',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.mountains,
    ),
    PoiIcon(
      id: 'tour_cave',
      name: 'Пещера',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.cube,
    ),
    PoiIcon(
      id: 'tour_viewpoint',
      name: 'Смотровая',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.binoculars,
    ),
    PoiIcon(
      id: 'tour_trail',
      name: 'Тропа',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.footprints,
    ),
    PoiIcon(
      id: 'tour_bridge',
      name: 'Брод',
      category: PoiCategory.tourism,
      fallbackIcon: PhosphorIconsDuotone.bridge,
    ),

    // === Грибы и ягоды ===
    PoiIcon(
      id: 'mush_generic',
      name: 'Грибы',
      category: PoiCategory.mushrooms,
      svgAsset: 'assets/icons/mushrooms/mushroom.svg',
      fallbackIcon: PhosphorIconsDuotone.plant,
    ),
    PoiIcon(
      id: 'mush_porcini',
      name: 'Белый',
      category: PoiCategory.mushrooms,
      svgAsset: 'assets/icons/mushrooms/porcini.svg',
      fallbackIcon: PhosphorIconsFill.plant,
      tintColor: _porcini,
    ),
    PoiIcon(
      id: 'mush_chanterelle',
      name: 'Лисички',
      category: PoiCategory.mushrooms,
      svgAsset: 'assets/icons/mushrooms/chanterelle.svg',
      fallbackIcon: PhosphorIconsFill.plant,
      tintColor: _chanterelle,
    ),
    PoiIcon(
      id: 'berry_blueberry',
      name: 'Черника',
      category: PoiCategory.mushrooms,
      fallbackIcon: PhosphorIconsFill.circlesThreePlus,
      tintColor: _blueberry,
    ),
    PoiIcon(
      id: 'berry_cranberry',
      name: 'Клюква',
      category: PoiCategory.mushrooms,
      fallbackIcon: PhosphorIconsFill.circlesThreePlus,
      tintColor: _cranberry,
    ),

    // === Поиск / кладоискательство ===
    PoiIcon(
      id: 'treas_find',
      name: 'Находка',
      category: PoiCategory.treasure,
      fallbackIcon: PhosphorIconsDuotone.treasureChest,
    ),
    PoiIcon(
      id: 'treas_promising',
      name: 'Перспектива',
      category: PoiCategory.treasure,
      fallbackIcon: PhosphorIconsDuotone.magnifyingGlass,
    ),
    PoiIcon(
      id: 'treas_coin',
      name: 'Монета',
      category: PoiCategory.treasure,
      fallbackIcon: PhosphorIconsDuotone.coin,
    ),
    PoiIcon(
      id: 'treas_signal',
      name: 'Сигнал',
      category: PoiCategory.treasure,
      fallbackIcon: PhosphorIconsDuotone.waveSine,
    ),
    PoiIcon(
      id: 'treas_village',
      name: 'Урочище',
      category: PoiCategory.treasure,
      fallbackIcon: PhosphorIconsDuotone.barn,
    ),

    // === Инфраструктура ===
    PoiIcon(
      id: 'infra_car',
      name: 'Машина',
      category: PoiCategory.infra,
      fallbackIcon: PhosphorIconsDuotone.carProfile,
    ),
    PoiIcon(
      id: 'infra_home',
      name: 'База',
      category: PoiCategory.infra,
      fallbackIcon: PhosphorIconsDuotone.house,
    ),
    PoiIcon(
      id: 'infra_gas',
      name: 'АЗС',
      category: PoiCategory.infra,
      fallbackIcon: PhosphorIconsDuotone.gasPump,
    ),
    PoiIcon(
      id: 'infra_shop',
      name: 'Магазин',
      category: PoiCategory.infra,
      fallbackIcon: PhosphorIconsDuotone.storefront,
    ),
    PoiIcon(
      id: 'infra_parking',
      name: 'Парковка',
      category: PoiCategory.infra,
      fallbackIcon: _mdParking,
    ),

    // === Опасности ===
    PoiIcon(
      id: 'danger_cliff',
      name: 'Обрыв',
      category: PoiCategory.danger,
      fallbackIcon: PhosphorIconsDuotone.warningOctagon,
    ),
    PoiIcon(
      id: 'danger_swamp',
      name: 'Болото',
      category: PoiCategory.danger,
      fallbackIcon: PhosphorIconsDuotone.waves,
    ),
    PoiIcon(
      id: 'danger_predator',
      name: 'Хищник',
      category: PoiCategory.danger,
      fallbackIcon: PhosphorIconsDuotone.warning,
    ),
    PoiIcon(
      id: 'danger_restricted',
      name: 'Запрет',
      category: PoiCategory.danger,
      fallbackIcon: PhosphorIconsDuotone.prohibit,
    ),

    // === Прочее ===
    PoiIcon(
      id: 'other_pin',
      name: 'Метка',
      category: PoiCategory.other,
      fallbackIcon: PhosphorIconsDuotone.mapPin,
    ),
    PoiIcon(
      id: 'other_star',
      name: 'Избранное',
      category: PoiCategory.other,
      fallbackIcon: PhosphorIconsDuotone.star,
    ),
    PoiIcon(
      id: 'other_photo',
      name: 'Фото',
      category: PoiCategory.other,
      fallbackIcon: PhosphorIconsDuotone.camera,
    ),
    PoiIcon(
      id: 'other_note',
      name: 'Заметка',
      category: PoiCategory.other,
      fallbackIcon: PhosphorIconsDuotone.note,
    ),
  ];

  static List<PoiIcon> get all => _icons;

  static List<PoiIcon> byCategory(PoiCategory category) =>
      _icons.where((i) => i.category == category).toList();

  static PoiIcon byId(String id) => _icons.firstWhere(
        (i) => i.id == id,
        orElse: () => _icons.firstWhere((i) => i.id == 'other_pin'),
      );

  static PoiIcon defaultFor(PoiCategory category) => byCategory(category).first;
}
