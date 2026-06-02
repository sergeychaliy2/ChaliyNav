# ChaliyNav

[![CI](https://github.com/sergeychaliy2/chaliynav/actions/workflows/ci.yml/badge.svg)](https://github.com/sergeychaliy2/chaliynav/actions/workflows/ci.yml)
[![Release Build](https://github.com/sergeychaliy2/chaliynav/actions/workflows/release.yml/badge.svg)](https://github.com/sergeychaliy2/chaliynav/actions/workflows/release.yml)

**Your path. Your marks. Your legacy.**

Премиальное полевое GIS-приложение для Android (и iOS-ready) для рыбаков, охотников, туристов, грибников, кладоискателей и путешественников. Работает offline, бережёт батарею, не требует регистрации. Все данные хранятся локально.

---

## Содержание

1. [Для кого](#для-кого)
2. [Ключевые возможности](#ключевые-возможности)
3. [Импорт растровых карт](#импорт-растровых-карт)
4. [Технологический стек](#технологический-стек)
5. [Архитектура](#архитектура)
6. [Сборка и запуск](#сборка-и-запуск)
7. [Статус по фазам](#статус-по-фазам)
8. [Верификация загрузки карт](#верификация-загрузки-карт)
9. [Известные ограничения](#известные-ограничения)
10. [Дорожная карта](#дорожная-карта)

---

## Для кого

Универсальный инструмент для работы «в поле» с акцентом на Россию:

- **Рыбаки** — карты глубин, морские буи, точки заброса, аудио-заметки с клёва.
- **Охотники** — угодья, следы, засидки, кормушки, запретные зоны.
- **Туристы и лесники** — рельеф, стоянки, родники, кварталы.
- **Грибники и ягодники** — сезонные точки с фото, треки обходов.
- **Поисковики / кладоискатели** — исторические карты (Шуберт, РККА, Генштаб, Менде), перспективные места, находки.
- **Лесо- и природопользователи** — план-схемы лесонасаждений, таксационные карты, JNX-планы Garmin.
- **Все, кто ходит offline** — 75+ готовых регионов РФ для оффлайн-загрузки, приватность по умолчанию.

## Ключевые возможности

### Картография

- **5 базовых стилей**: Схема (OSM), Спутник (Esri), Гибрид, Рельеф (OpenTopoMap), Тёмная (CartoDB).
- **Каталог из 100+ готовых карт** с поиском и фильтром по категориям:
  - Топография: OpenTopoMap, CyclOSM.
  - Спутник: Esri World Imagery + подписи.
  - Исторические: Трёхверстовка Шуберта, РККА 1941, Генштаб 1:200000, Карта Менде.
  - Морские и глубины: OpenSeaMap, EMODnet Bathymetry, Esri Ocean Base + Reference.
  - Погода: облака и осадки OpenWeatherMap (требуется пользовательский API-ключ).
  - **Регионы РФ (offline)** — 75+ готовых bbox-регионов: от Адыгеи до Ярославля, плюс Байкал, Ладога, Онега, Рыбинское, Селигер, Телецкое.
- **Offline-загрузка** карт в `.mbtiles` с живым прогрессом, мини-индикатором и возможностью пользоваться приложением во время скачивания.
- **Импорт сторонних слоёв**: `.mbtiles`, произвольные XYZ-URL, **растровые сканы** в JPG / TIFF / PNG / **Garmin JNX** с авто-привязкой по сайдкарам или по встроенным координатам (см. [отдельный раздел](#импорт-растровых-карт)).
- **Привязка скана вручную** по 2 углам — fallback для растров без сайдкара.
- **Quick Layers Bar** — чипы слоёв на карте с тапом-переключателем видимости и live-слайдером прозрачности.
- **Шкала масштаба** с учётом широты (Web-Mercator), закреплённая внизу-слева.

### POI (точки)

- **8 категорий** с индивидуальными цветами: Рыбалка, Охота, Туризм, Грибы-ягоды, Поиск, Инфраструктура, Опасности, Прочее.
- **50+ иконок** с уникальной цветовой кодировкой (щука — оливковая, карп — золотой, медведь — чёрный и т.д.).
- **Способы создания**:
  - Long-press на карте → placeholder «Точка здесь».
  - Кнопка FAB «Новая точка» (текущая GPS).
  - Shake-to-save (настраиваемый порог и cooldown).
- **Контент точки**: название, категория, иконка, заметка, фото (до 10), голосовая аудио-заметка (AAC 96kbps).
- **Поиск, фильтр, сортировка, избранное**.
- **Метаданные** (опционально): высота, давление, фаза луны, погода.
- **Редактирование** через `/points/:id/edit` с предзаполнением.
- **Кластеризация** маркеров при отдалении с цветом по доминирующей категории.

### Треки

- **Запись** с адаптивным фильтром Kalman для сглаживания + отбрасывания выбросов > 150 м (важно при GPS-глушилках в РФ).
- **Background tracking** через `flutter_background_service` + persistent notification — продолжает писаться с заблокированным экраном.
- **3-state follow cycle** у кнопки центрирования: свободный → pan-only → track-up (rotate-by-heading).
- **Камера остаётся там, где её оставил пользователь** — авто-возврата к местоположению по таймауту нет, чтобы разметка кварталов / измерения не прерывались. Возврат строго по нажатию кнопки локации.
- **Анимированный трек**: soft glow подложка + main polyline + пульсирующая голова.
- **GPX import/export** + KML/KMZ (Google Earth, Яндекс.Карты, Maps.me, OrganicMaps) + GeoJSON (QGIS).

### Измерение и зоны

- **Инструменты**: Расстояние (polyline) и Площадь (polygon) с живым периметром / площадью в м², га, км².
- **Интерактивные вершины**: тап → переименовать / удалить; long-press → drag.
- **Сохранение как Zone** с именем и типом (Охотничье угодье, Лесной квартал, Аквазона, Грибное место, Запретная зона, Своя зона).
- **Редактирование существующей зоны** с перезаписью (не создаёт новую).
- **Отрисовка** на карте с центроидом-меткой через `PolygonLabelPlacement.polylabel`.

### Компас и навигация

- **HUD-пилюля компаса** в верхнем ряду: иконка + угол + сторона света («127° СВ»). Числа и подпись в фиксированных слотах — пилюля не «дёргается» при изменении значения.
- **Расширенный режим** (опция в настройках) — отдельный фикс-карточка 124×134 на левом краю под HUD-пилюлями: цифры + крутящаяся мини-роза с С / В / Ю / З и красной N-стрелкой. Слайдер прозрачности слоя автоматически опускается под бейдж компаса, чтобы не накладываться.
- **Полноэкранный компас** по тапу: большая роза 5°-делений, цифры 56 px, сторона света словом, и панель GPS-данных (широта, долгота, высота, точность, скорость).
- **Heading-конус** на маркере пользователя (как в Яндекс.Картах).
- **Track-up rotation** — карта целиком вращается под направление устройства в режиме `followWithHeading`.
- **Навигация к точке**: стрелка-азимут, live-расстояние, кардинальное направление, пунктир-маршрут на карте.
- **TTS голосовые подсказки** (`flutter_tts`) с cooldown и коротким / длинным режимом.

### Безопасность и приватность

- **AES-256-CBC шифрование** для sensitive-данных.
- **Биометрическая блокировка** приложения через `local_auth` (Face / Fingerprint / PIN).
- **Аварийный выход** из lock-screen после 2 неудачных попыток.
- **Зашифрованные бэкапы** `.chaliy` (AES-256 + пользовательский пароль, KDF: SHA-256 × 10 000 + salt).
- **Персистентность во всём**: SharedPreferences — точки, треки, маршруты, зоны, слои, настройки.
- **Никаких серверов**: всё локально. Регистрация не требуется.

### UX и оболочка

- **Онбординг** на первом запуске: 5 страниц swipe с анимированными иконками.
- **Permissions-экран** после онбординга со статусами и отдельными «Разрешить» для каждого permission.
- **4 языка UI**: 🇷🇺 Русский · 🇬🇧 English · 🇧🇾 Беларуская · 🇺🇦 Українська (основной UI; длинные тексты локализованы частично).
- **Wiki / Помощь** — 7 разделов с подробными how-to статьями.
- **Dark glassmorphism тема** (Inter + Phosphor Icons Duotone / Fill), 60 FPS, плавные микро-анимации.
- **Настройки отображения**: индивидуальные тогглы для шкалы, спидометра, точности, компаса, расширенного компаса, точек на карте, ориентации карты, режима «не гасить экран».

## Импорт растровых карт

### Что поддерживается

| Формат | Сайдкар (любой) | Координаты внутри файла |
|---|---|---|
| `.tif` / `.tiff` | `.tfw`, `.tfwx`, `.wld`, `<name>.tif.aux.xml` | — |
| `.jpg` / `.jpeg` | `.jgw`, `.jgwx`, `.wld`, `<name>.jpg.aux.xml` | — |
| `.png` | `.pgw`, `.wld`, `<name>.png.aux.xml` | — |
| `.jnx` (Garmin BirdsEye v3) | — | да, в заголовке + per tile |
| `.mbtiles` | — | да |

Поддерживаемые проекции для world-файлов: **WGS84 (EPSG:4326)** и **Web Mercator (EPSG:3857)**. Auto-detect по диапазону координат — если значения укладываются в `±180/±90` → WGS84, если в `±20 037 508 м` → Mercator. Для UTM / Гаусс-Крюгера и других → понятная ошибка с инструкцией перепривязки в QGIS.

### Парсер сайдкаров

- **Plain-text** world files (`.tfw`, `.jgw`, `.pgw`, `.wld`) — 6 чисел построчно. Поддерживает локальный десятичный разделитель: `0.5` (US) и `0,5` (RU локаль QGIS / GDAL).
- **XML world files** (`.tfwx`, `.jgwx`, `<name>.aux.xml`) — несколько вариантов в одном парсере:
  - GDAL PAM с `<GeoTransform>` (запятые или пробелы как разделители).
  - ESRI «SpatialReference» / ArcGIS variants с element-per-number: `PixelXSize / PixelYSize`, `XDim / YDim`, `PixelScaleX/Y`, `TiePointX/Y`, `ULX / ULY / XMin / YMax / Left / Top / TopLeftX / TopLeftY / UpperLeftX / UpperLeftY` и т.п.
- **Диагностика при сбое**: если ни один формат не распарсился, в снэкбаре показывается имя корневого XML-элемента и список первых child-элементов — пользователь может скопировать и прислать, парсер расширяется.

### Android-специфика выбора файлов

`file_picker` под Android Scoped Storage передаёт в приложение **только выделенные** файлы — соседние сайдкары на диске невидимы из-за санбокса. Поэтому в нашем диалоге включён `allowMultiple: true` и пользователь выделяет **растр + сайдкар одновременно**.

[`RasterImporter.stageSelection`](lib/shared/services/raster_importer.dart) собирает выделение, копирует растр и **все** найденные сайдкары в общую temp-папку (если они оказались в разных кэш-подкаталогах), затем передаёт путь дальше — `WorldFile.findSidecar` находит их по соседству. Если сайдкаров несколько (`.jgwx` + `.aux.xml`), приоритет у того, что фактически парсится.

### Тайлинг крупных растров

Android GPU-текстуры обычно ограничены **`GL_MAX_TEXTURE_SIZE = 4096`** (на старых устройствах). Сканы 6000×6000+ Skia при отрисовке тихо даун-семплит до этого предела — отсюда «мыло» на больших картах независимо от фильтра.

При импорте растр > 2048 px по любой оси автоматически нарезается на тайлы 2048×2048:

- **JPG / PNG / TIFF**: декодируется через `package:image` → нарезается на сетку → каждый кусок сохраняется как PNG `r{row}_c{col}.png` в `<layer_id>.tiled/`. Сохраняется `LayerTileGrid {rows, cols, tileWidth, tileHeight, srcWidth, srcHeight}`.
- **JNX (мозаика)**: тайлы по природе формата уже отдельные JPEG'и со своими bounds. Стримим **по одному** из исходного буфера на диск **без** промежуточного сшивания в `img.Image` — пиковая память ~1 МБ на тайл. Сохраняется `LayerTileMosaic {tiles: [{file, bounds}]}`.

При рендере (`SharpOverlayImageLayer` + `buildTiledOverlay` / `buildMosaicOverlay`) каждый тайл идёт в свою GPU-текстуру → **никакого даун-семпла** → разрешение источника сохраняется.

### Sharp overlay rendering

Стандартный `flutter_map.OverlayImageLayer` (v7.0.2) кладёт `filterQuality` только на внешний `Transform`, а внутренний `Image` рисуется с дефолтным `FilterQuality.medium` — отсюда мыльные сканы у всех, кто использует `OverlayImageLayer`.

Своя реализация [`SharpOverlayImageLayer`](lib/features/map/widgets/sharp_overlay_image_layer.dart) повторяет ту же проекционную математику, но прокидывает `filterQuality` **до самого `Image`**, а с `Transform` его убирает (чтобы не форсить `saveLayer` — он создавал офскрин-битмап размером с виджет, который при сильном зуме упирался в `GL_MAX_TEXTURE_SIZE` и снова даун-семплился). Нужный фильтр доезжает до GPU без потерь.

### Garmin JNX (BirdsEye v3)

Своя реализация [`JnxReader`](lib/shared/services/jnx_reader.dart) разбирает заголовок (48 байт), массив уровней (16 байт каждый) и записи тайлов (28 байт: width / height int16, jpeg_size / jpeg_offset int32, top / right / bottom / left как Garmin int32 со scale `180° / 2³¹`).

Особенности:
- **Только v3** (без шифрования).
- Выбирается **самый детальный уровень** (минимальный `scale`).
- Пустые слоты сетки (`width=0 && height=0 && size=0`) пропускаются — формат резервирует записи под нерегулярные границы покрытия.
- «Walked-off-the-end» детектор: `level.count` иногда заявлен с запасом — циклы прерываются на первой записи с невалидными dims или координатами вне общего bbox JNX.
- **JPEG-починка**: некоторые Garmin-кодеры режут SOI/APP0 префикс — добавляем канонический JFIF-заголовок при необходимости.
- Stream-подход: `JnxPlan.jpegBytesFor(tile)` возвращает `Uint8List.sublistView` (zero-copy view) → пишется на диск → ссылка отбрасывается. Без больших аллокаций → не падает на устройствах с heap < 256 МБ.
- В UI экрана привязки тайлы JNX можно перетаскивать / масштабировать как единый блок — handles переносят / меняют общий bbox, а live-трансформ ремаппит координаты каждого тайла относительно базового bbox при рендере и при сохранении.

### Поток импорта (overall)

```
PickedPaths → RasterImporter.stageSelection
            ↓ (raster + sidecar в одной temp-папке)
            
RasterImporter.importFile
  ├─ ext == .jnx                  → _importJnx → JnxReader (streaming) → tileMosaic
  ├─ raster ≤ 2048 px              → копия как single-file
  ├─ raster > 2048 px (JPG/PNG)    → копия + декод + tile grid
  └─ TIFF (любой)                  → декод + (single PNG | tile grid по размеру)
            
            ↓ MapLayer { source, bounds, tileGrid?, tileMosaic? }
            
Render:
  SharpOverlayImageLayer
    ├─ tileMosaic != null           → buildMosaicOverlay (per-tile bounds)
    ├─ tileGrid != null             → buildTiledOverlay (sub-bounds из bbox)
    └─ иначе                        → один SharpOverlayImage (3 угла)
```

## Технологический стек

### Ядро

| Технология | Версия | Роль |
|---|---|---|
| **Flutter** | 3.35+ (Dart SDK ^3.11.4) | UI фреймворк |
| **flutter_riverpod** | ^2.5.1 | State management |
| **go_router** | ^14.6.2 | Декларативный routing со StatefulShellRoute |

### Карты и геоданные

| Пакет | Назначение |
|---|---|
| `flutter_map ^7.0.2` | Рендеринг карт (Leaflet-like, tile-based) |
| `flutter_map_mbtiles ^1.0.4` | Offline `.mbtiles` слои |
| `flutter_map_marker_cluster ^1.4.0` | Кластеризация POI |
| `flutter_map_location_marker ^9.1.1` | Маркер местоположения |
| `latlong2 ^0.9.1` | Математика географии |
| `geolocator ^13.0.1` | GPS-поток и one-shot |
| `flutter_compass ^0.8.1` | Магнитный heading |
| `sensors_plus ^6.1.0` | Акселерометр для shake-детектора |
| `image ^4.3.0` | Декод TIFF / JPEG / PNG для тайлинга |

### Медиа и ввод

| Пакет | Назначение |
|---|---|
| `camera ^0.11.0` | Съёмка фото к точкам |
| `image_picker ^1.1.2` | Выбор из галереи |
| `record ^6.0.0` | Голосовые аудио-заметки (AAC) |
| `audioplayers ^6.1.0` | Воспроизведение |
| `flutter_tts ^4.2.0` | Синтез речи для голосовых подсказок |
| `permission_handler ^11.3.1` | Permissions flow |

### Offline и сеть

| Пакет | Назначение |
|---|---|
| `dio ^5.7.0` | HTTP для загрузки тайлов и будущей cloud-sync |
| `sqflite ^2.4.1` | Запись `.mbtiles` (SQLite) |
| `path_provider ^2.1.5` | Директории приложения |
| `file_picker ^8.1.4` | Импорт пользовательских файлов |
| `share_plus ^10.1.3` | Шеринг GPX и бэкапов |
| `connectivity_plus ^6.1.0` | Статус сети |
| `flutter_background_service ^5.1.0` + `flutter_local_notifications ^18.0.1` | Foreground service для фоновой записи треков |

### Парсеры и утилиты

| Пакет | Назначение |
|---|---|
| `xml ^6.5.0` | GPX / KML / world-file XML парсинг |
| `archive ^4.0.2` | ZIP для KMZ и бэкапов |
| `shared_preferences ^2.3.2` | Персистентность настроек и моделей |
| `uuid ^4.5.1` | Генерация ID |
| `intl ^0.20.1` | Форматирование дат |

### Безопасность

| Пакет | Назначение |
|---|---|
| `local_auth ^2.3.0` | Биометрия / PIN устройства |
| `crypto ^3.0.6` | SHA-256 KDF |
| `encrypt ^5.0.3` | AES-256-CBC обёртка |

### UI

| Пакет | Назначение |
|---|---|
| `google_fonts ^6.2.1` | Inter font |
| `flutter_animate ^4.5.0` | Декларативные анимации |
| `flutter_svg ^2.0.16` | SVG иконки (для будущих packs) |
| `phosphor_flutter ^2.1.0` | Современная библиотека иконок (Duotone + Fill) |

## Архитектура

**Паттерн**: Feature-based modular + Repository abstraction + Riverpod.

```
lib/
├── main.dart                    Pre-load locale + background service setup,
│                                image cache 500 MB / 2000 entries для крупных сканов
├── app.dart                     MaterialApp.router + GoRouter config
│
├── core/
│   ├── theme/                   AppColors, AppTheme (dark glassmorphism)
│   ├── constants/               AppConstants
│   ├── utils/                   Formatters (distance, duration, latLng)
│   ├── widgets/                 GlassCard, GlassButton, GlassAppBar (76 px,
│   │                            ellipsis-aware title/subtitle), AnimatedBackground,
│   │                            EmptyState
│   └── l10n/                    AppStrings (inline map-based i18n)
│
├── features/
│   ├── splash/                  Splash with locale + onboarded checks
│   ├── onboarding/              5-page swipe + PermissionsScreen
│   ├── auth/                    AppLockScreen with emergency exit
│   ├── shell/                   MainShell with bottom nav bar
│   │
│   ├── map/
│   │   ├── screens/             MapScreen, GeoreferenceScreen, CompassScreen
│   │   └── widgets/             AnimatedTrackLayer, MapHud (compass pill / expanded badge),
│   │                            MeasureOverlay, NavigationHud, QuickLayersBar, ScaleBar,
│   │                            ActiveLayerSlider, UserMarker, CompassRose,
│   │                            SharpOverlayImageLayer (sharp + tiled + mosaic),
│   │                            LayersSheet, ImportLayerSheet, DownloadAreaSheet,
│   │                            DownloadMiniIndicator, SaveZoneSheet, ZonesMapLayer,
│   │                            UserLayersStack
│   │
│   ├── points/                  List, Detail, NewPoint (edit-aware),
│   │                            PoiMarker, VoiceMemoRecorder, PoiListTile
│   ├── tracks/                  Tracks/Routes/Zones segmented list
│   ├── zones/                   Zone detail with vertex list + edit mode
│   ├── routes/                  (заложено; используется из Tracks tab)
│   ├── downloads/               DownloadsScreen
│   │
│   └── settings/
│       ├── SettingsScreen       Все секции + язык / помощь / данные / бэкап;
│       │                        тогглы шкалы, спидометра, точности, компаса,
│       │                        расширенного компаса, точек, ориентации
│       ├── LanguageScreen       4 locales with flags
│       ├── HelpScreen           7 how-to sections
│       ├── DataScreen           Import/export stats
│       └── BackupScreen         AES-256 .chaliy create/restore
│
└── shared/
    ├── models/                  GeoPoint, PointOfInterest, Track, RoutePath,
    │                            Zone, MapLayer (+ LayerTileGrid + LayerTileMosaic),
    │                            MapPreset, RfRegions, DownloadTask,
    │                            AppSettings (showCompass, compassExpanded, …),
    │                            PoiCategory, PoiIconLibrary
    ├── repositories/            Abstract + SharedPrefs/InMemory impls
    │                            for Points, Tracks, Routes, Zones,
    │                            Layers, Settings
    ├── providers/               Riverpod providers для каждой сущности,
    │                            + Measure, Location, Compass, Locale,
    │                            FocusRequest, NavigationTarget
    └── services/
        ├── KalmanFilter         GPS smoothing + outlier rejection
        ├── ShakeDetector        Accelerometer-based shake
        ├── CompassService       Heading stream + Geo helpers (bearing, cardinal)
        ├── TtsService           flutter_tts wrapper w/ cooldown
        ├── AudioMemoService     record wrapper
        ├── LayersService        MapLayer → TileLayer resolver
        ├── DownloadManager      Offline tile downloader → MBTiles
        ├── GpxService           GPX 1.1 parser + serializer
        ├── KmlService           KML/KMZ parser (Google, Яндекс, Maps.me)
        ├── GeoJsonService       GeoJSON FeatureCollection parser (QGIS)
        ├── ImportService        Unified file import dispatcher
        ├── WorldFile            .tfw/.tfwx/.jgw/.jgwx/.pgw/.wld/.aux.xml парсер
        │                        + WGS84 / EPSG:3857 auto-detect
        ├── RasterImporter       Pipeline: stageSelection → tile/copy → MapLayer
        ├── JnxReader            Garmin JNX v3 (streaming, mosaic-aware)
        ├── SecurityService      AES-256-CBC + KDF
        ├── AppLockService       local_auth wrapper
        ├── BackupService        Encrypted .chaliy zip+AES
        └── BackgroundTrackingService  Foreground service lifecycle
```

### Принципы

- **Repository abstraction** — вся персистентность через интерфейсы с in-memory и SharedPrefs-импл. Phase 5 добавит Isar-имплементацию без изменений UI.
- **No global state** — только Riverpod providers. Provider-ы autoDispose где уместно (location stream).
- **Separation of concerns** — UI слой не знает о HTTP / SQLite; сервисы не знают о widget-дереве.
- **Offline-first** — каждая фича работает без сети (кроме явно-онлайн пресетов карт).
- **Privacy-first** — никаких аналитик, никаких серверов, никаких обязательных аккаунтов.
- **Memory-conscious decoding** — тайлинг и стриминг JNX не позволяют пиковой памяти при импорте подскочить выше единиц мегабайт даже на 100+ MP сканах.

## Сборка и запуск

### Требования

- Flutter 3.35+ (Dart SDK ^3.11.4)
- Android SDK 35 + Android 13+ для тестирования background location
- JDK 17
- Android Studio или VS Code

### Быстрый старт

```bash
flutter pub get
flutter run -d <device-id>
```

### Release APK

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

APK подписан debug-ключом (для локального тестирования). Для Play Store нужно сгенерировать release-keystore и подключить его в `android/app/build.gradle.kts`.

### CI/CD (GitHub Actions)

| Workflow | Когда запускается | Что делает |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | каждый push/PR в `main` | `flutter analyze` (гейт) + `flutter test` (non-blocking) |
| [`release.yml`](.github/workflows/release.yml) | тег `v*` или вручную | `flutter build apk --release` → APK в **GitHub Releases** (по тегу) и в artifacts |

**Выпуск релиза:**
```bash
# подними version в pubspec.yaml, затем:
git tag v1.0.0
git push origin v1.0.0
# → release.yml соберёт APK и создаст GitHub Release
```

### Настройки проекта

- `applicationId`: `com.chaliy.nav`
- `minSdk`: 23 (Android 6.0)
- `targetSdk`: Flutter default (35)
- **Core library desugaring** включён (требуется `flutter_local_notifications`)
- `MainActivity` — `FlutterFragmentActivity` (требуется `local_auth` на Android 11+)

### Android permissions

- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` / `ACCESS_BACKGROUND_LOCATION`
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`
- `CAMERA`, `RECORD_AUDIO`, `READ_MEDIA_*`
- `USE_BIOMETRIC` / `USE_FINGERPRINT`
- `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`

## Статус по фазам

- **Phase 1 — Foundation** ✅ Тема, навигация, базовая карта + POI + треки + настройки.
- **Phase 2 — Content** ✅ Offline `.mbtiles`, XYZ импорт, каталог карт с поиском и фильтром по категориям, GPX/KML/KMZ/GeoJSON импорт/экспорт, 75+ регионов РФ, Quick Layers Bar, измерение с сохранением как Zone.
- **Phase 3 — Smart Tools** ✅ Shake-детектор, voice memo, TTS-навигация, компас, heading-конус, Kalman-фильтр GPS, background tracking с foreground service.
- **Phase 4 — Security & Real DB** ✅ (частично) AES-256-CBC, биометрическая блокировка с emergency exit, зашифрованные `.chaliy` бэкапы, локализация на 4 языка. Замена SharedPreferences → Isar — в Phase 5.
- **Phase 5 — Raster Power** ✅ Импорт TIFF / JPG / PNG / JNX с авто-привязкой по сайдкарам, мульти-выбор файлов на Android, EPSG:3857 / WGS84 auto-detect, **тайлинг и mosaic** для крупных сканов > 2048 px, sharp overlay rendering без даун-семпла GPU, полный экран компаса + расширенный HUD-бейдж.
- **Phase 6 — Polish** (план) Полная локализация длинных текстов, Isar-имплементация репозиториев, secure storage (Android Keystore / iOS Keychain), полное георефенсирование с 4 точками, vector tile support, JNX v4 (с XOR-обфускацией), spotlight-эффект прозрачности на слоях.

## Верификация загрузки карт

Standalone проверка всей tile-загрузки (без эмулятора / устройства):

```bash
dart run tool/verify_download.dart
```

Прогоняет все **19 уникальных tile-endpoints** каталога (они обслуживают все ~110 карточек):

- HTTP GET тайла для каждого источника
- Создание `.mbtiles` SQLite
- Запись BLOB / чтение обратно с проверкой побайтово

Типичный результат из РФ-сети: **12/19 endpoints работают без ключа + 140/149 карточек готовы к использованию**. OpenWeatherMap требует пользовательский API-ключ (ожидаемо), Retromap.ru из корпоративных сетей может timeout'иться.

## Известные ограничения

- **`flutter_secure_storage`** временно заменён на SharedPreferences для мастер-ключа — Gradle-артефакты пакета не тянутся из текущей build-среды (`dl.google.com` блок). Phase 6 вернёт его для хранения ключа в Android Keystore.
- **Полная локализация** — основной UI переведён на 4 языка; длинные тексты (онбординг, Wiki, описания пресетов) пока только на русском.
- **Карты глубин крупных озёр РФ** (Байкал, Ладога) — нет готовых open-source XYZ-endpoint'ов. В каталоге есть карточка-инструкция для привязки сканов PDF-атласов и импорта `.mbtiles` из эхолотов Lowrance / Humminbird.
- **Web Mercator конвертация** — пересчёт делается по 4 углам мозаики, что для одиночного скана даёт небольшую (метры на десятки метров) ошибку в средней зоне. Для идеальной точности экспорт из QGIS лучше делать в `EPSG:4326`.
- **JNX v4** (с шифрованием signature × XOR) — не поддерживается. v3 — работает.
- **TIFF embedded GeoTIFF tags** — внутри-файловые координаты GeoTIFF пока не читаются. Для TIFF нужен внешний world-файл / `.aux.xml` с `GeoTransform`.
- **iOS** — код написан кросс-платформенно и должен собраться, но не тестировался на iPhone. Info.plist содержит все нужные NSUsageDescription.
- **Release APK** подписан debug-ключом (для личного тестирования). Для публикации нужен release-keystore.

## Дорожная карта

- [ ] Isar-based репозитории (замена SharedPreferences для масштаба)
- [ ] Android Keystore / iOS Keychain для мастер-ключа (вернуть `flutter_secure_storage`)
- [ ] Полная ARB-локализация (генерация через `flutter gen-l10n`)
- [ ] Vector tiles (`.pbf`) support
- [ ] Full 4-point georeferencing с аффинной трансформацией
- [ ] GeoTIFF embedded tags reader (TIFF без сайдкара)
- [ ] JNX v4 deobfuscation
- [ ] Spotlight-эффект прозрачности слоёв (палец «убирает» альфу)
- [ ] E2EE облачная синхронизация (TLS 1.3 + sealed boxes)
- [ ] Publishing pipeline: Play Store release keystore + CI/CD

---

**Лицензия**: проприетарная — все права защищены. См. [`LICENSE`](LICENSE). Private project, 2026.
