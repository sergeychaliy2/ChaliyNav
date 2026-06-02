import 'map_layer.dart';
import 'rf_regions.dart';

/// Curated map source catalogued in the app so users can add it with one tap.
class MapPreset {
  const MapPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.source,
    this.description = '',
    this.attribution = '',
    this.maxZoom = 19,
    this.minZoom = 0,
    this.isOverlay = false,
    this.defaultOpacity = 1.0,
    this.region,
  });

  final String id;
  final String name;
  final MapPresetCategory category;
  final MapLayerType type;
  final String source;
  final String description;
  final String attribution;
  final double maxZoom;
  final double minZoom;
  final bool isOverlay;
  final double defaultOpacity;

  /// Optional geographic region — used by the offline downloader to pre-fill
  /// the bounding box. If null, the user picks the current viewport.
  final PresetRegion? region;

  MapLayer toLayer({required String layerId}) => MapLayer(
        id: layerId,
        name: name,
        type: type,
        source: source,
        opacity: defaultOpacity,
        visible: true,
        description: description,
        attribution: attribution,
        maxZoom: maxZoom,
        minZoom: minZoom,
      );
}

enum MapPresetCategory {
  topographic,
  satellite,
  historical,
  nautical,
  fishing,
  weather,
  regionsRu,
  other;

  String get label => switch (this) {
        MapPresetCategory.topographic => 'Топография',
        MapPresetCategory.satellite => 'Спутник',
        MapPresetCategory.historical => 'Исторические',
        MapPresetCategory.nautical => 'Морские и глубины',
        MapPresetCategory.fishing => 'Рыболовные',
        MapPresetCategory.weather => 'Погода',
        MapPresetCategory.regionsRu => 'Регионы РФ (offline)',
        MapPresetCategory.other => 'Прочее',
      };
}

/// Named geographic region — used by RF offline-download presets.
class PresetRegion {
  const PresetRegion({
    required this.northLat,
    required this.southLat,
    required this.westLng,
    required this.eastLng,
    this.recommendedMinZoom = 9,
    this.recommendedMaxZoom = 14,
  });

  final double northLat;
  final double southLat;
  final double westLng;
  final double eastLng;
  final int recommendedMinZoom;
  final int recommendedMaxZoom;
}

class MapPresetLibrary {
  MapPresetLibrary._();

  /// Built-in presets. RF regions are injected via [RfRegions] to keep this
  /// file readable — see `rf_regions.dart`.
  static List<MapPreset> get all => [..._builtIn];

  static const List<MapPreset> _builtIn = [
    // === Topographic ===
    MapPreset(
      id: 'opentopomap',
      name: 'OpenTopoMap',
      category: MapPresetCategory.topographic,
      type: MapLayerType.tileUrl,
      source: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
      description: 'Общественная топографическая карта на базе OSM + SRTM.',
      attribution: '© OpenTopoMap, © OSM, SRTM',
      maxZoom: 17,
    ),
    MapPreset(
      id: 'cyclosm',
      name: 'CyclOSM',
      category: MapPresetCategory.topographic,
      type: MapLayerType.tileUrl,
      source: 'https://a.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
      description: 'Велосипедная и пешеходная карта с рельефом.',
      attribution: '© CyclOSM, © OSM',
      maxZoom: 18,
    ),

    // === Satellite ===
    MapPreset(
      id: 'esri_imagery',
      name: 'Esri World Imagery',
      category: MapPresetCategory.satellite,
      type: MapLayerType.tileUrl,
      source:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      description: 'Высокое разрешение от Esri / Maxar.',
      attribution: '© Esri, Maxar',
      maxZoom: 19,
    ),
    MapPreset(
      id: 'esri_streets',
      name: 'Esri Hybrid Labels',
      category: MapPresetCategory.satellite,
      type: MapLayerType.tileUrl,
      source:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
      description: 'Надписи и границы поверх спутника.',
      attribution: '© Esri',
      maxZoom: 19,
      isOverlay: true,
      defaultOpacity: 0.85,
    ),

    // === Nautical / Bathymetry (fishing-useful) ===
    MapPreset(
      id: 'openseamap',
      name: 'OpenSeaMap (морская)',
      category: MapPresetCategory.nautical,
      type: MapLayerType.tileUrl,
      source: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
      description:
          'Морские буи, фарватеры, ограничения. Накладывать поверх базовой карты.',
      attribution: '© OpenSeaMap',
      maxZoom: 18,
      isOverlay: true,
      defaultOpacity: 0.95,
    ),
    MapPreset(
      id: 'gebco',
      name: 'GEBCO Batimetry',
      category: MapPresetCategory.nautical,
      type: MapLayerType.tileUrl,
      source:
          'https://tiles.emodnet-bathymetry.eu/2020/baselayer/web_mercator/{z}/{x}/{y}.png',
      description:
          'Карта глубин (батиметрия) EMODnet — моря Европы и мирового океана. Для рыбалки на большой воде.',
      attribution: '© EMODnet Bathymetry, © GEBCO',
      maxZoom: 12,
      isOverlay: true,
      defaultOpacity: 0.75,
    ),
    // Removed: EMODnet изобаты (URL discontinued, returns HTTP 400).
    // Removed: NOAA Nautical (US server frequently times out from RU ISPs).
    // To get contour/nautical overlays, use the GEBCO preset below or
    // import a .mbtiles from Navionics/Humminbird.

    // === Карты глубин озёр РФ — инструкция ===
    MapPreset(
      id: 'ru_lakes_depth_guide',
      name: 'Глубины Ладоги / Онеги / Байкала',
      category: MapPresetCategory.nautical,
      type: MapLayerType.tileUrl,
      // Using the base OSM as a safe fallback source. Users don't add this —
      // they tap it to read the instruction below and then use "Привязать
      // скан" to load a real bathymetry PDF/PNG.
      source: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      description:
          'Открытых XYZ-тайлов с глубинами крупных озёр РФ не существует. '
          'Способы получить: 1) скачать PDF-атлас глубин (Росгидромет, rib.ru, '
          'nortfolio.com) → конвертировать в PNG → Слои → «Привязка» привязать '
          'по 2 углам. 2) Импортировать .mbtiles из Lowrance/Humminbird (если '
          'у вас уже есть с эхолота). 3) GEBCO покрывает крупные водоёмы на '
          'низком зуме (до z=10).',
      attribution: 'Инструкция',
    ),

    // === Fishing ===
    MapPreset(
      id: 'opensnowmap',
      name: 'OpenSnowMap (зимние)',
      category: MapPresetCategory.fishing,
      type: MapLayerType.tileUrl,
      source: 'https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png',
      description: 'Лыжные трассы и зимние маршруты.',
      attribution: '© OpenSnowMap',
      maxZoom: 18,
      isOverlay: true,
      defaultOpacity: 0.9,
    ),

    // === Weather overlays ===
    MapPreset(
      id: 'owm_clouds',
      name: 'Облака (OWM)',
      category: MapPresetCategory.weather,
      type: MapLayerType.tileUrl,
      source:
          'https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=YOUR_OWM_KEY',
      description: 'Требует API-ключ OpenWeatherMap. Замените в настройках.',
      attribution: '© OpenWeatherMap',
      isOverlay: true,
      defaultOpacity: 0.6,
    ),
    MapPreset(
      id: 'owm_precipitation',
      name: 'Осадки (OWM)',
      category: MapPresetCategory.weather,
      type: MapLayerType.tileUrl,
      source:
          'https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid=YOUR_OWM_KEY',
      description: 'Слой осадков OpenWeatherMap. Нужен API-ключ.',
      attribution: '© OpenWeatherMap',
      isOverlay: true,
      defaultOpacity: 0.6,
    ),

    // === Historical (Russian-specific) ===
    MapPreset(
      id: 'shubert_3verst',
      name: 'Трёхверстовка Шуберта (1860-е)',
      category: MapPresetCategory.historical,
      type: MapLayerType.tileUrl,
      source: 'https://mapy.retromap.ru/081860_shubert_3/{z}/{x}/{y}.png',
      description:
          'Военно-топографическая карта Российской империи. Уникальна для поиска урочищ, старых деревень.',
      attribution: '© Retromap.ru',
      maxZoom: 13,
      minZoom: 7,
    ),
    MapPreset(
      id: 'rkka_1941',
      name: 'РККА 1941 (Запад СССР)',
      category: MapPresetCategory.historical,
      type: MapLayerType.tileUrl,
      source: 'https://mapy.retromap.ru/031941_rkka/{z}/{x}/{y}.png',
      description: 'Карты Генштаба РККА. Западные регионы СССР.',
      attribution: '© Retromap.ru',
      maxZoom: 12,
      minZoom: 6,
    ),
    MapPreset(
      id: 'genshtab_1970',
      name: 'Генштаб 1:200 000',
      category: MapPresetCategory.historical,
      type: MapLayerType.tileUrl,
      source: 'https://mapy.retromap.ru/1420n_genshtab_200k/{z}/{x}/{y}.png',
      description: 'Советский Генштаб, топокарты среднего масштаба.',
      attribution: '© Retromap.ru',
      maxZoom: 13,
      minZoom: 5,
    ),
    MapPreset(
      id: 'mende_1862',
      name: 'Карта Менде (1860-е)',
      category: MapPresetCategory.historical,
      type: MapLayerType.tileUrl,
      source: 'https://mapy.retromap.ru/101862_mende_1verst/{z}/{x}/{y}.png',
      description: 'Одноверстовая карта Менде для поиска староверских поселений.',
      attribution: '© Retromap.ru',
      maxZoom: 13,
      minZoom: 8,
    ),

    // === Карты глубин водных ресурсов РФ ===
    // (Удалён: GEBCO WMS preset — WMS-формат с {bbox-epsg-3857} не
    //  поддерживается flutter_map TileLayer. Вместо него работают
    //  EMODnet Bathymetry и Esri Ocean ниже.)
    MapPreset(
      id: 'ocean_base',
      name: 'Esri Ocean Basemap',
      category: MapPresetCategory.nautical,
      type: MapLayerType.tileUrl,
      source:
          'https://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}',
      description:
          'Рельеф морского дна — бровки, ямы, впадины. Отлично для донной ловли.',
      attribution: '© Esri, GEBCO, NOAA',
      maxZoom: 13,
    ),
    MapPreset(
      id: 'ocean_ref',
      name: 'Esri Ocean — подписи',
      category: MapPresetCategory.nautical,
      type: MapLayerType.tileUrl,
      source:
          'https://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Reference/MapServer/tile/{z}/{y}/{x}',
      description:
          'Подписи глубин и названия подводных объектов поверх Ocean Basemap.',
      attribution: '© Esri',
      maxZoom: 13,
      isOverlay: true,
      defaultOpacity: 0.9,
    ),

    // (Регионы РФ: полный каталог из ~75 пресетов живёт в rf_regions.dart
    //  и инжектится через MapPresetLibrary.byCategory(regionsRu).)
  ];

  static List<MapPreset> byCategory(MapPresetCategory c) {
    if (c == MapPresetCategory.regionsRu) {
      // Inject the full RF regions catalogue + hand-picked water bodies.
      final extra = _builtIn.where((p) => p.category == c).toList();
      return [...extra, ...RfRegions.all()];
    }
    return all.where((p) => p.category == c).toList();
  }

  /// Global search across every preset, including RF regions.
  static List<MapPreset> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    final built = _builtIn.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q));
    final rf = RfRegions.search(q);
    return [...built, ...rf];
  }
}
