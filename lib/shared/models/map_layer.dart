/// A raster / vector map source with alpha transparency.
/// Multiple layers can be stacked on top of the base tile layer.
class MapLayer {
  const MapLayer({
    required this.id,
    required this.name,
    required this.type,
    required this.source,
    this.opacity = 1.0,
    this.visible = true,
    this.description,
    this.attribution,
    this.maxZoom = 19,
    this.minZoom = 0,
    this.bounds,
    this.tileGrid,
    this.tileMosaic,
  });

  final String id;
  final String name;
  final MapLayerType type;

  /// XYZ URL template, absolute file path (for mbtiles/sqlitedb/ozf2/zmp), or
  /// for imageOverlay: either a single-file path OR a directory path
  /// containing pre-cut tiles (see [tileGrid]).
  final String source;
  final double opacity;
  final bool visible;
  final String? description;
  final String? attribution;
  final double maxZoom;
  final double minZoom;

  /// For [MapLayerType.imageOverlay]: geographic bounds of the image.
  final LayerBounds? bounds;

  /// Non-null when the raster was sliced into a grid of tiles at import
  /// time to dodge Android's `GL_MAX_TEXTURE_SIZE` (commonly 4096).
  /// When set, [source] points at the tile directory rather than a
  /// single image file, and the renderer walks the grid producing one
  /// overlay per tile at its sub-bounds.
  final LayerTileGrid? tileGrid;

  /// Non-null for "mosaic" overlays where each tile has its own
  /// explicit geographic bounds — used for Garmin JNX files, whose
  /// tile layout is driven by the source format's per-tile lat/lng
  /// metadata rather than a regular pixel-grid split. Mutually
  /// exclusive with [tileGrid]; when set, [source] points at the
  /// directory holding all the tile files referenced from
  /// [LayerTileMosaic.tiles].
  final LayerTileMosaic? tileMosaic;

  MapLayer copyWith({
    String? name,
    double? opacity,
    bool? visible,
    String? description,
    String? attribution,
    double? maxZoom,
    double? minZoom,
    LayerBounds? bounds,
    LayerTileGrid? tileGrid,
    LayerTileMosaic? tileMosaic,
  }) =>
      MapLayer(
        id: id,
        name: name ?? this.name,
        type: type,
        source: source,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        description: description ?? this.description,
        attribution: attribution ?? this.attribution,
        maxZoom: maxZoom ?? this.maxZoom,
        minZoom: minZoom ?? this.minZoom,
        bounds: bounds ?? this.bounds,
        tileGrid: tileGrid ?? this.tileGrid,
        tileMosaic: tileMosaic ?? this.tileMosaic,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'source': source,
        'opacity': opacity,
        'visible': visible,
        if (description != null) 'description': description,
        if (attribution != null) 'attribution': attribution,
        'maxZoom': maxZoom,
        'minZoom': minZoom,
        if (bounds != null) 'bounds': bounds!.toJson(),
        if (tileGrid != null) 'tileGrid': tileGrid!.toJson(),
        if (tileMosaic != null) 'tileMosaic': tileMosaic!.toJson(),
      };

  factory MapLayer.fromJson(Map<String, dynamic> j) => MapLayer(
        id: j['id'] as String,
        name: j['name'] as String,
        type: MapLayerType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => MapLayerType.tileUrl,
        ),
        source: j['source'] as String,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1.0,
        visible: j['visible'] as bool? ?? true,
        description: j['description'] as String?,
        attribution: j['attribution'] as String?,
        maxZoom: (j['maxZoom'] as num?)?.toDouble() ?? 19,
        minZoom: (j['minZoom'] as num?)?.toDouble() ?? 0,
        bounds: j['bounds'] == null
            ? null
            : LayerBounds.fromJson(j['bounds'] as Map<String, dynamic>),
        tileGrid: j['tileGrid'] == null
            ? null
            : LayerTileGrid.fromJson(j['tileGrid'] as Map<String, dynamic>),
        tileMosaic: j['tileMosaic'] == null
            ? null
            : LayerTileMosaic.fromJson(j['tileMosaic'] as Map<String, dynamic>),
      );
}

/// Collection of per-tile overlays where each tile has its own
/// explicit geographic bounds. Used by Garmin JNX (and any other
/// "mosaic"-style format) to avoid stitching a whole scan into a
/// single in-memory image at import time — that quickly blows past
/// Android's low-heap devices (~256 MB). Each tile lives as its own
/// file inside the layer source directory.
class LayerTileMosaic {
  const LayerTileMosaic({required this.tiles});

  final List<MosaicTile> tiles;

  Map<String, dynamic> toJson() => {
        'tiles': [for (final t in tiles) t.toJson()],
      };

  factory LayerTileMosaic.fromJson(Map<String, dynamic> j) => LayerTileMosaic(
        tiles: (j['tiles'] as List)
            .cast<Map<String, dynamic>>()
            .map(MosaicTile.fromJson)
            .toList(),
      );
}

/// One tile in a [LayerTileMosaic]: a filename (relative to the
/// layer's source directory) plus the geographic rectangle the tile
/// covers. No rotation — mosaic tiles are axis-aligned; if you need
/// rotation, wrap the whole mosaic at render time.
class MosaicTile {
  const MosaicTile({required this.file, required this.bounds});

  final String file;
  final LayerBounds bounds;

  Map<String, dynamic> toJson() => {
        'f': file,
        'b': bounds.toJson(),
      };

  factory MosaicTile.fromJson(Map<String, dynamic> j) => MosaicTile(
        file: j['f'] as String,
        bounds: LayerBounds.fromJson(j['b'] as Map<String, dynamic>),
      );
}

/// Describes a pre-sliced tile grid for a large raster overlay.
///
/// Tiles live inside the layer's [MapLayer.source] directory and
/// follow a fixed naming scheme: `r{row}_c{col}.png`. Rows go
/// top-to-bottom (0 = northernmost in image pixel space), columns
/// left-to-right (0 = westernmost). [tileWidth] / [tileHeight] are
/// the NOMINAL tile dimensions; the last column and last row may be
/// smaller (remainder crops). [srcWidth] / [srcHeight] carry the
/// source raster's exact pixel dimensions so callers can compute each
/// tile's geographic sub-bounds as a fraction of the overall layer
/// bounds.
class LayerTileGrid {
  const LayerTileGrid({
    required this.rows,
    required this.cols,
    required this.tileWidth,
    required this.tileHeight,
    required this.srcWidth,
    required this.srcHeight,
  });

  final int rows;
  final int cols;
  final int tileWidth;
  final int tileHeight;
  final int srcWidth;
  final int srcHeight;

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'tw': tileWidth,
        'th': tileHeight,
        'sw': srcWidth,
        'sh': srcHeight,
      };

  factory LayerTileGrid.fromJson(Map<String, dynamic> j) => LayerTileGrid(
        rows: j['rows'] as int,
        cols: j['cols'] as int,
        tileWidth: j['tw'] as int,
        tileHeight: j['th'] as int,
        srcWidth: j['sw'] as int,
        srcHeight: j['sh'] as int,
      );
}

/// Geographic rectangle: NW and SE corners, plus an optional rotation
/// around the rectangle's center (clockwise, degrees).
///
/// For existing data with no rotation field in SharedPreferences,
/// `rotationDeg` falls back to 0 — full backwards compatibility.
class LayerBounds {
  const LayerBounds({
    required this.northLat,
    required this.southLat,
    required this.westLng,
    required this.eastLng,
    this.rotationDeg = 0,
  });

  final double northLat;
  final double southLat;
  final double westLng;
  final double eastLng;

  /// Clockwise rotation of the raster around its geographic center,
  /// in degrees. 0 = axis-aligned (north up).
  final double rotationDeg;

  double get centerLat => (northLat + southLat) / 2;
  double get centerLng => (eastLng + westLng) / 2;
  double get widthDeg => eastLng - westLng;
  double get heightDeg => northLat - southLat;

  LayerBounds copyWith({
    double? northLat,
    double? southLat,
    double? westLng,
    double? eastLng,
    double? rotationDeg,
  }) =>
      LayerBounds(
        northLat: northLat ?? this.northLat,
        southLat: southLat ?? this.southLat,
        westLng: westLng ?? this.westLng,
        eastLng: eastLng ?? this.eastLng,
        rotationDeg: rotationDeg ?? this.rotationDeg,
      );

  Map<String, dynamic> toJson() => {
        'n': northLat,
        's': southLat,
        'w': westLng,
        'e': eastLng,
        if (rotationDeg != 0) 'r': rotationDeg,
      };

  factory LayerBounds.fromJson(Map<String, dynamic> j) => LayerBounds(
        northLat: (j['n'] as num).toDouble(),
        southLat: (j['s'] as num).toDouble(),
        westLng: (j['w'] as num).toDouble(),
        eastLng: (j['e'] as num).toDouble(),
        rotationDeg: (j['r'] as num?)?.toDouble() ?? 0,
      );
}

enum MapLayerType {
  tileUrl, // XYZ/WMTS tile URL
  mbtiles, // local .mbtiles file
  sqlitedb, // SAS.Planet .sqlitedb
  ozf2, // OziExplorer .ozf2 (Phase 3)
  zmp, // Global Mapper .zmp (Phase 3)
  wms, // WMS service
  imageOverlay, // georeferenced scan / raster image with 2-point bounds
  vector, // vector tiles / GeoJSON (future)
}

extension MapLayerTypeX on MapLayerType {
  String get label => switch (this) {
        MapLayerType.tileUrl => 'XYZ URL',
        MapLayerType.mbtiles => 'MBTiles',
        MapLayerType.sqlitedb => 'SAS Planet',
        MapLayerType.ozf2 => 'OziExplorer',
        MapLayerType.zmp => 'Global Mapper',
        MapLayerType.wms => 'WMS',
        MapLayerType.imageOverlay => 'Скан карты',
        MapLayerType.vector => 'Вектор',
      };
}

enum BaseMapStyle {
  schema,
  satellite,
  hybrid,
  terrain,
  dark,
}

extension BaseMapStyleX on BaseMapStyle {
  String get label => switch (this) {
        BaseMapStyle.schema => 'Карта',
        BaseMapStyle.satellite => 'Спутник',
        BaseMapStyle.hybrid => 'Гибрид',
        BaseMapStyle.terrain => 'Рельеф',
        BaseMapStyle.dark => 'Тёмная',
      };

  String get tileUrl => switch (this) {
        BaseMapStyle.schema =>
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        BaseMapStyle.satellite =>
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        BaseMapStyle.hybrid =>
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        BaseMapStyle.terrain =>
          'https://tile.opentopomap.org/{z}/{x}/{y}.png',
        // CartoDB Dark Matter is open and key-less — works from RU without a
        // Stadia account (which requires an API key).
        BaseMapStyle.dark =>
          'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      };

  String get attribution => switch (this) {
        BaseMapStyle.schema => '© OpenStreetMap',
        BaseMapStyle.satellite ||
        BaseMapStyle.hybrid =>
          '© Esri, Maxar',
        BaseMapStyle.terrain => '© OpenTopoMap, © OSM',
        BaseMapStyle.dark => '© CARTO, © OSM',
      };
}
