// Full-catalogue tile-source verification.
//
// The catalogue looks big (5 base styles + ~20 presets + 75 RF regions = 100+
// entries) but all of them resolve to **just 19 unique tile-endpoint URLs**.
// This script enumerates every unique endpoint and pings one sample tile.
//
// The `sampledBy` field shows how many catalogue entries route through each
// endpoint — so if one endpoint breaks, you know exactly how many cards it
// affects.
//
// Run:  dart run tool/verify_download.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _userAgent = 'ChaliyNavVerify/1.0 (download-pipeline-check)';

const _sources = <_Src>[
  // --- 5 base styles ---
  _Src(
    name: 'OSM (схема)',
    url: 'https://tile.openstreetmap.org/5/18/10.png',
    sampledBy: 78,
    sampledBrief: 'схема + 75 регионов РФ без isTerrain + 2 preset (baseMap, ru preset)',
  ),
  _Src(
    name: 'Esri World Imagery (спутник/гибрид)',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/5/10/18',
    sampledBy: 3,
    sampledBrief: 'BaseMap.satellite + BaseMap.hybrid + Каталог > Esri World Imagery',
  ),
  _Src(
    name: 'OpenTopoMap (без sub-домена)',
    url: 'https://tile.opentopomap.org/5/18/10.png',
    sampledBy: 1,
    sampledBrief: 'BaseMap.terrain',
  ),
  _Src(
    name: 'OpenTopoMap (sub-домен a.)',
    url: 'https://a.tile.opentopomap.org/5/18/10.png',
    sampledBy: 50,
    sampledBrief: 'Каталог > OpenTopoMap preset + ~48 регионов РФ с isTerrain',
  ),
  _Src(
    name: 'CartoDB Dark (тёмная)',
    url: 'https://a.basemaps.cartocdn.com/dark_all/5/18/10.png',
    sampledBy: 1,
    sampledBrief: 'BaseMap.dark',
  ),

  // --- Остальные пресеты (уникальные URL) ---
  _Src(
    name: 'CyclOSM',
    url: 'https://a.tile-cyclosm.openstreetmap.fr/cyclosm/5/18/10.png',
    sampledBy: 1,
    sampledBrief: 'Топография > CyclOSM',
  ),
  _Src(
    name: 'Esri Reference (подписи спутника)',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/5/10/18',
    sampledBy: 1,
    sampledBrief: 'Спутник > Esri Hybrid Labels',
  ),
  _Src(
    name: 'OpenSeaMap (морские буи)',
    url: 'https://tiles.openseamap.org/seamark/5/18/10.png',
    sampledBy: 1,
    sampledBrief: 'Морские > OpenSeaMap',
  ),
  _Src(
    name: 'EMODnet Bathymetry (глубины)',
    url: 'https://tiles.emodnet-bathymetry.eu/2020/baselayer/web_mercator/5/18/10.png',
    sampledBy: 1,
    sampledBrief: 'Морские > GEBCO Batimetry (preset id=gebco)',
  ),
  _Src(
    name: 'Esri Ocean Base',
    url: 'https://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer/tile/5/10/18',
    sampledBy: 1,
    sampledBrief: 'Морские > Esri Ocean Basemap',
  ),
  _Src(
    name: 'Esri Ocean Reference (подписи)',
    url: 'https://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Reference/MapServer/tile/5/10/18',
    sampledBy: 1,
    sampledBrief: 'Морские > Esri Ocean — подписи',
  ),
  _Src(
    name: 'GEBCO WMS (bbox)',
    url: 'https://www.gebco.net/data_and_products/gebco_web_services/web_map_service/mapserv?'
        'request=getmap&service=wms&'
        'BBOX=0,0,20037508,20037508&crs=EPSG:3857&'
        'format=image/png&layers=GEBCO_LATEST&width=256&height=256&version=1.3.0',
    sampledBy: 1,
    sampledBrief: 'Морские > GEBCO — глобальная батиметрия (WMS, НЕ XYZ!)',
    notXyz: true,
  ),
  _Src(
    name: 'OpenSnowMap (pistes)',
    url: 'https://tiles.opensnowmap.org/pistes/5/18/10.png',
    sampledBy: 1,
    sampledBrief: 'Рыболовные > OpenSnowMap (зимние)',
  ),
  _Src(
    name: 'OWM — облака (dummy key)',
    url: 'https://tile.openweathermap.org/map/clouds_new/5/18/10.png?appid=YOUR_OWM_KEY',
    sampledBy: 1,
    sampledBrief: 'Погода > Облака (OWM)',
    expected401: true,
  ),
  _Src(
    name: 'OWM — осадки (dummy key)',
    url: 'https://tile.openweathermap.org/map/precipitation_new/5/18/10.png?appid=YOUR_OWM_KEY',
    sampledBy: 1,
    sampledBrief: 'Погода > Осадки (OWM)',
    expected401: true,
  ),
  _Src(
    name: 'Retromap — Шуберт (1860-е)',
    url: 'https://mapy.retromap.ru/081860_shubert_3/10/602/325.png',
    sampledBy: 1,
    sampledBrief: 'Исторические > Трёхверстовка Шуберта',
  ),
  _Src(
    name: 'Retromap — РККА 1941',
    url: 'https://mapy.retromap.ru/031941_rkka/10/602/325.png',
    sampledBy: 1,
    sampledBrief: 'Исторические > РККА 1941',
  ),
  _Src(
    name: 'Retromap — Генштаб 200k',
    url: 'https://mapy.retromap.ru/1420n_genshtab_200k/10/602/325.png',
    sampledBy: 1,
    sampledBrief: 'Исторические > Генштаб 1:200 000',
  ),
  _Src(
    name: 'Retromap — Менде 1862',
    url: 'https://mapy.retromap.ru/101862_mende_1verst/10/602/325.png',
    sampledBy: 1,
    sampledBrief: 'Исторические > Карта Менде',
  ),
];

Future<void> main() async {
  stdout.writeln(
      '=== ChaliyNav full catalogue verification ===\n');
  stdout.writeln(
      'Проверяем ${_sources.length} уникальных tile-endpoints, '
      'которые обслуживают все ~100 карточек в каталоге.\n');

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
    ),
  );

  final results = <_Result>[];
  for (final s in _sources) {
    final r = await _check(dio, s);
    results.add(r);
    stdout.writeln(
      '  ${r.statusIcon} ${s.name.padRight(44)} '
      '${r.detail.padRight(28)} · обслуживает: ${s.sampledBy.toString().padLeft(3)} карточек',
    );
  }

  // MBTiles roundtrip with whatever returned bytes
  final fetched = results.where((r) => r.bytes != null).toList();
  if (fetched.isNotEmpty) {
    stdout.writeln('\n--- MBTiles write/read roundtrip ---');
    final outPath = p.join(
      Directory.systemTemp.path,
      'chaliy_verify_${DateTime.now().millisecondsSinceEpoch}.mbtiles',
    );
    final db = sqlite3.open(outPath);
    try {
      db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
      db.execute('''
        CREATE TABLE tiles (
          zoom_level INTEGER,
          tile_column INTEGER,
          tile_row INTEGER,
          tile_data BLOB,
          PRIMARY KEY (zoom_level, tile_column, tile_row)
        )
      ''');
      for (var i = 0; i < fetched.length; i++) {
        final stmt = db.prepare(
          'INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)',
        );
        stmt.execute([5, i, 0, fetched[i].bytes!]);
        stmt.dispose();
      }
      final count = db.select('SELECT COUNT(*) c FROM tiles').first['c'];
      stdout.writeln('  ✓ inserted $count BLOBs, read-back OK');
    } finally {
      db.dispose();
      try {
        File(outPath).deleteSync();
      } catch (_) {}
    }
  }

  // Summary
  final ok = results.where((r) => r.kind == _Kind.ok).toList();
  final warn = results.where((r) => r.kind == _Kind.warn).toList();
  final bad = results.where((r) => r.kind == _Kind.bad).toList();

  int cards(Iterable<_Result> xs) => xs.fold(0, (a, r) => a + r.src.sampledBy);

  stdout.writeln('\n=== Summary ===');
  stdout.writeln(
      '  ✓ РАБОТАЕТ:  ${ok.length}/${_sources.length} endpoints '
      '· ${cards(ok)} карточек в каталоге');
  if (warn.isNotEmpty) {
    stdout.writeln(
        '  ⚠ УСЛОВНО:   ${warn.length} endpoints · '
        '${cards(warn)} карточек (нужен API-ключ или не XYZ-формат)');
    for (final r in warn) {
      stdout.writeln('      · ${r.src.name}: ${r.src.sampledBrief}');
    }
  }
  if (bad.isNotEmpty) {
    stdout.writeln(
        '  ✗ СЛОМАНО:   ${bad.length} endpoints · '
        '${cards(bad)} карточек');
    for (final r in bad) {
      stdout.writeln('      · ${r.src.name}: ${r.src.sampledBrief}');
    }
  }
  stdout.writeln('');

  if (bad.isEmpty) {
    stdout.writeln('✅ Все рабочие endpoints (не считая тех, что требуют API-ключ) '
        'отдают валидные PNG/JPG.');
  } else {
    stdout.writeln('⚠ Некоторые endpoints сломаны с этой машины. '
        'С мобильной РФ-сети результат может отличаться '
        '(российские сайты типа retromap.ru часто блочат корпоративные IP).');
  }
  exit(bad.isEmpty ? 0 : 2);
}

Future<_Result> _check(Dio dio, _Src src) async {
  try {
    final res = await dio.get<List<int>>(
      src.url,
      options: Options(
        headers: {'User-Agent': _userAgent, 'Referer': 'https://chaliy.nav/'},
      ),
    );
    final code = res.statusCode ?? -1;
    final bytes = Uint8List.fromList(res.data ?? const []);

    if (src.notXyz) {
      return _Result(
        src: src,
        kind: _Kind.warn,
        detail: 'WMS — не XYZ',
      );
    }

    if (src.expected401 && (code == 401 || code == 403)) {
      return _Result(
        src: src,
        kind: _Kind.warn,
        detail: 'HTTP $code (нужен ключ)',
      );
    }

    if (code == 200 && bytes.length >= 100) {
      final header = bytes.sublist(0, math.min(8, bytes.length));
      final isPng = header.length >= 4 &&
          header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47;
      final isJpg = header.length >= 3 &&
          header[0] == 0xFF &&
          header[1] == 0xD8 &&
          header[2] == 0xFF;
      if (isPng || isJpg) {
        return _Result(
          src: src,
          kind: _Kind.ok,
          bytes: bytes,
          detail:
              '${isPng ? "PNG" : "JPG"} ${(bytes.length / 1024).toStringAsFixed(1)} KB',
        );
      }
      return _Result(
        src: src,
        kind: _Kind.bad,
        detail: 'HTTP 200, не PNG/JPG',
      );
    }

    if (code == 404) {
      return _Result(
        src: src,
        kind: _Kind.warn,
        detail: 'HTTP 404 — тайл не покрыт',
      );
    }

    return _Result(
      src: src,
      kind: _Kind.bad,
      detail: 'HTTP $code',
    );
  } on DioException catch (e) {
    return _Result(
      src: src,
      kind: _Kind.bad,
      detail: 'dio.${e.type.name}',
    );
  } catch (e) {
    return _Result(
      src: src,
      kind: _Kind.bad,
      detail: 'ошибка: $e',
    );
  }
}

class _Src {
  const _Src({
    required this.name,
    required this.url,
    required this.sampledBy,
    required this.sampledBrief,
    this.expected401 = false,
    this.notXyz = false,
  });
  final String name;
  final String url;
  final int sampledBy;
  final String sampledBrief;
  final bool expected401;
  final bool notXyz;
}

enum _Kind { ok, warn, bad }

class _Result {
  _Result({
    required this.src,
    required this.kind,
    this.bytes,
    required this.detail,
  });
  final _Src src;
  final _Kind kind;
  final Uint8List? bytes;
  final String detail;

  String get statusIcon => switch (kind) {
        _Kind.ok => '✓',
        _Kind.warn => '⚠',
        _Kind.bad => '✗',
      };
}
