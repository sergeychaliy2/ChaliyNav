import 'package:flutter/material.dart';

/// Light-weight localization — a map of string keys to per-locale values.
/// Covers the primary UI surface (nav, settings, map chrome, points,
/// tracks, zones, downloads, lock, language, measure/layers widgets).
///
/// Fallback order: exact locale → ru → key name.
class AppStrings {
  AppStrings(this.locale);
  final Locale locale;

  static AppStrings of(BuildContext ctx) {
    final loc = Localizations.localeOf(ctx);
    return AppStrings(loc);
  }

  String get _code => locale.languageCode;

  String t(String key) {
    return _all[_code]?[key] ?? _all['ru']![key] ?? key;
  }

  // --- Shorthands (readable call-sites) ---
  String get appName => 'ChaliyNav';

  // Nav
  String get navMap => t('nav.map');
  String get navPoints => t('nav.points');
  String get navTracks => t('nav.tracks');
  String get navSettings => t('nav.settings');

  // Common
  String get commonSave => t('common.save');
  String get commonCancel => t('common.cancel');
  String get commonDelete => t('common.delete');
  String get commonEdit => t('common.edit');
  String get commonClose => t('common.close');
  String get commonOk => t('common.ok');
  String get commonLater => t('common.later');
  String get commonBack => t('common.back');
  String get commonDone => t('common.done');
  String get commonOpen => t('common.open');
  String get commonYes => t('common.yes');
  String get commonNo => t('common.no');
  String get commonRetry => t('common.retry');
  String get commonError => t('common.error');
  String get commonNotFound => t('common.not_found');
  String get commonSearch => t('common.search');
  String get commonEmpty => t('common.empty');
  String get commonAdd => t('common.add');
  String get commonRemove => t('common.remove');
  String get commonShare => t('common.share');
  String get commonStart => t('common.start');
  String get commonStop => t('common.stop');
  String get commonContinue => t('common.continue');

  // Settings sections
  String get settingsTitle => t('settings.title');
  String get settingsInterface => t('settings.interface');
  String get settingsLanguage => t('settings.language');
  String get settingsLanguageTap => t('settings.language_tap');
  String get settingsHelp => t('settings.help');
  String get settingsData => t('settings.data');
  String get settingsSecurity => t('settings.security');
  String get settingsTrackRecord => t('settings.track_record');
  String get settingsDisplay => t('settings.display');
  String get settingsVoice => t('settings.voice');
  String get settingsShake => t('settings.shake');
  String get settingsMeta => t('settings.meta');
  String get settingsLocaleHint => t('settings.locale_hint');

  // Settings > Track recording
  String get settingsMinDistance => t('settings.min_distance');
  String get settingsMinInterval => t('settings.min_interval');
  String get settingsGpsAccuracy => t('settings.gps_accuracy');
  String get settingsTrackWidth => t('settings.track_width');

  // Settings > Display
  String get settingsSpeedometer => t('settings.speedometer');
  String get settingsCompass => t('settings.compass');
  String get settingsCompassExpanded => t('settings.compass_expanded');
  String get settingsAccuracy => t('settings.accuracy');
  String get settingsPointsOnMap => t('settings.points_on_map');
  String get settingsKeepScreenOn => t('settings.keep_screen_on');
  String get settingsMapOrientation => t('settings.map_orientation');

  // Settings > Voice
  String get settingsVoiceGuide => t('settings.voice_guide');
  String get settingsShortHints => t('settings.short_hints');
  String get settingsHintStep => t('settings.hint_step');
  String get settingsHintCooldown => t('settings.hint_cooldown');

  // Settings > Shake
  String get settingsShakeSave => t('settings.shake_save');
  String get settingsSensitivity => t('settings.sensitivity');
  String get settingsAutoAudio => t('settings.auto_audio');

  // Settings > Meta
  String get settingsAltitude => t('settings.altitude');
  String get settingsPressure => t('settings.pressure');
  String get settingsMoon => t('settings.moon');
  String get settingsWeather => t('settings.weather');

  // Settings > Security
  String get settingsAppLock => t('settings.app_lock');
  String get settingsBiometric => t('settings.biometric');
  String get settingsSecretCategory => t('settings.secret_category');

  // Settings > Help rows
  String get settingsHelpWiki => t('settings.help_wiki');
  String get settingsHelpWikiSub => t('settings.help_wiki_sub');
  String get settingsRepeatOnboarding => t('settings.repeat_onboarding');
  String get settingsRepeatOnboardingSub =>
      t('settings.repeat_onboarding_sub');
  String get settingsPermissions => t('settings.permissions');
  String get settingsPermissionsSub => t('settings.permissions_sub');

  // Settings > Data rows
  String get settingsImportExport => t('settings.import_export');
  String get settingsImportExportSub => t('settings.import_export_sub');
  String get settingsDownloads => t('settings.downloads');
  String get settingsDownloadsSub => t('settings.downloads_sub');
  String get settingsCloudSync => t('settings.cloud_sync');
  String get settingsCloudSyncSub => t('settings.cloud_sync_sub');
  String get settingsBackup => t('settings.backup');
  String get settingsBackupSub => t('settings.backup_sub');

  // Map
  String get mapLayers => t('map.layers');
  String get mapDownloadArea => t('map.download_area');
  String get mapWeather => t('map.weather_map');
  String get mapWeatherOn => t('map.weather_on');
  String get mapMeasure => t('map.measure');
  String get mapCenter => t('map.center');
  String get mapRecord => t('map.record');
  String get mapRecordStop => t('map.record_stop');
  String get mapNewPoint => t('map.new_point');
  String get mapHereLabel => t('map.here_label');
  String get mapNoGps => t('map.no_gps');
  String get mapRecStarted => t('map.rec_started');
  String get mapRecStoppedShort => t('map.rec_stopped_short');
  String get mapRecSaved => t('map.rec_saved');
  String get mapMeasureDistance => t('map.measure_distance');
  String get mapMeasureDistanceHint => t('map.measure_distance_hint');
  String get mapMeasureArea => t('map.measure_area');
  String get mapMeasureAreaHint => t('map.measure_area_hint');
  String get mapBaseMapTitle => t('map.base_map_title');
  String get mapUserLayersTitle => t('map.user_layers_title');
  String get mapAddLayerHint => t('map.add_layer_hint');
  String get mapShakeSaved => t('map.shake_saved');
  String get mapNavStartTo => t('map.nav_start_to');
  String get mapNavStop => t('map.nav_stop');

  // Base map styles (localized)
  String get baseMapSchema => t('base.schema');
  String get baseMapSatellite => t('base.satellite');
  String get baseMapHybrid => t('base.hybrid');
  String get baseMapTerrain => t('base.terrain');
  String get baseMapDark => t('base.dark');
  String get baseMapYandexMap => t('base.yandex_map');
  String get baseMapYandexSat => t('base.yandex_sat');

  // Map orientation
  String get orientationAuto => t('orient.auto');
  String get orientationNorth => t('orient.north');
  String get orientationCourse => t('orient.course');

  // Points
  String get pointsAll => t('points.all');
  String get pointsEmptyTitle => t('points.empty_title');
  String get pointsEmptySub => t('points.empty_sub');
  String get pointsOpenMap => t('points.open_map');
  String get pointsSearch => t('points.search');
  String get pointsFilters => t('points.filters');
  String get pointsSort => t('points.sort');
  String get pointsSortNew => t('points.sort_new');
  String get pointsSortOld => t('points.sort_old');
  String get pointsSortAZ => t('points.sort_az');
  String get pointsSortDistance => t('points.sort_distance');
  String get pointsFavorite => t('points.favorite');
  String get pointsFavorites => t('points.favorites');
  String get pointsCategory => t('points.category');
  String get pointsCoordinates => t('points.coordinates');
  String get pointsCreated => t('points.created');
  String get pointsNote => t('points.note');
  String get pointsPhotos => t('points.photos');
  String get pointsAudio => t('points.audio');
  String get pointsMeta => t('points.meta');
  String get pointsNavigateHere => t('points.navigate_here');
  String get pointsStopNavigation => t('points.stop_navigation');
  String get pointsShowOnMap => t('points.show_on_map');
  String get pointsDeleteConfirm => t('points.delete_confirm');
  String get pointsDeleted => t('points.deleted');
  String get pointsSaved => t('points.saved');
  String get pointsDefaultName => t('points.default_name');

  // New point screen
  String get newPointTitle => t('new_point.title');
  String get newPointEditTitle => t('new_point.edit_title');
  String get newPointName => t('new_point.name');
  String get newPointNameHint => t('new_point.name_hint');
  String get newPointNote => t('new_point.note');
  String get newPointNoteHint => t('new_point.note_hint');
  String get newPointCategory => t('new_point.category');
  String get newPointIcon => t('new_point.icon');
  String get newPointAddPhoto => t('new_point.add_photo');
  String get newPointFromCamera => t('new_point.from_camera');
  String get newPointFromGallery => t('new_point.from_gallery');
  String get newPointVoiceMemo => t('new_point.voice_memo');
  String get newPointRecord => t('new_point.record');
  String get newPointRecording => t('new_point.recording');
  String get newPointPlay => t('new_point.play');
  String get newPointDeleteAudio => t('new_point.delete_audio');

  // Tracks / Routes / Zones tabs
  String get tracksTab => t('tracks.tab');
  String get routesTab => t('routes.tab');
  String get zonesTab => t('zones.tab');

  // Tracks
  String get tracksEmptyTitle => t('tracks.empty_title');
  String get tracksEmptySub => t('tracks.empty_sub');
  String get tracksDistance => t('tracks.distance');
  String get tracksDuration => t('tracks.duration');
  String get tracksPoints => t('tracks.points');
  String get tracksDeleteConfirm => t('tracks.delete_confirm');
  String get tracksExport => t('tracks.export');
  String get tracksRename => t('tracks.rename');
  String get tracksDefaultName => t('tracks.default_name');

  // Zones
  String get zonesEmptyTitle => t('zones.empty_title');
  String get zonesEmptySub => t('zones.empty_sub');
  String get zonesArea => t('zones.area');
  String get zonesPerimeter => t('zones.perimeter');
  String get zonesVertices => t('zones.vertices');
  String get zonesType => t('zones.type');
  String get zonesEditVertices => t('zones.edit_vertices');
  String get zonesDone => t('zones.done');
  String get zonesDeleteVertex => t('zones.delete_vertex');
  String get zonesRenameVertex => t('zones.rename_vertex');

  // Zone types
  String get zoneTypeHunt => t('zone.type.hunt');
  String get zoneTypeForest => t('zone.type.forest');
  String get zoneTypeWater => t('zone.type.water');
  String get zoneTypeMushroom => t('zone.type.mushroom');
  String get zoneTypeForbidden => t('zone.type.forbidden');
  String get zoneTypeCustom => t('zone.type.custom');

  // Downloads
  String get downloadsTitle => t('downloads.title');
  String get downloadsEmpty => t('downloads.empty');
  String get downloadsActive => t('downloads.active');
  String get downloadsDone => t('downloads.done');
  String get downloadsFailed => t('downloads.failed');
  String get downloadsPause => t('downloads.pause');
  String get downloadsResume => t('downloads.resume');
  String get downloadsCancel => t('downloads.cancel');
  String get downloadsTiles => t('downloads.tiles');
  String get downloadsSize => t('downloads.size');

  // Download area sheet
  String get downloadAreaTitle => t('download_area.title');
  String get downloadAreaZoom => t('download_area.zoom');
  String get downloadAreaTiles => t('download_area.tiles');
  String get downloadAreaSize => t('download_area.size');
  String get downloadAreaStart => t('download_area.start');
  String get downloadAreaSource => t('download_area.source');

  // Measure overlay
  String get measureDistance => t('measure.distance');
  String get measureArea => t('measure.area');
  String get measurePerimeter => t('measure.perimeter');
  String get measurePoints => t('measure.points');
  String get measureSaveAsZone => t('measure.save_as_zone');
  String get measureClear => t('measure.clear');
  String get measureExit => t('measure.exit');
  String get measureHint => t('measure.hint');
  String get measureAreaHint => t('measure.area_hint');

  // Save zone sheet
  String get saveZoneTitle => t('save_zone.title');
  String get saveZoneName => t('save_zone.name');
  String get saveZoneNameHint => t('save_zone.name_hint');
  String get saveZoneType => t('save_zone.type');

  // Layers sheet / import
  String get layersSheetTitle => t('layers.title');
  String get layersAdd => t('layers.add');
  String get layersImportTitle => t('layers.import_title');
  String get layersImportXyz => t('layers.import_xyz');
  String get layersImportFile => t('layers.import_file');
  String get layersImportXyzHint => t('layers.import_xyz_hint');
  String get layersImportUrl => t('layers.import_url');
  String get layersImportName => t('layers.import_name');
  String get layersOpacity => t('layers.opacity');

  // Lock
  String get lockTitle => t('lock.title');
  String get lockSubtitle => t('lock.subtitle');
  String get lockUnlock => t('lock.unlock');
  String get lockTestNow => t('lock.test_now');
  String get lockEmergencyExit => t('lock.emergency_exit');
  String get lockFailedTryAgain => t('lock.failed_try_again');

  // Language screen
  String get langAppliedBanner => t('lang.applied');
  String get langPartialNotice => t('lang.partial_notice');

  // App bars / titles
  String get dataTitle => t('data.title');
  String get backupTitle => t('backup.title');
  String get helpTitle => t('help.title');

  // POI categories
  String get catAll => t('cat.all');
  String get catFishing => t('cat.fishing');
  String get catHunting => t('cat.hunting');
  String get catTourism => t('cat.tourism');
  String get catMushrooms => t('cat.mushrooms');
  String get catTreasure => t('cat.treasure');
  String get catInfra => t('cat.infra');
  String get catDanger => t('cat.danger');
  String get catOther => t('cat.other');

  // Points list extras
  String get pointsFilterEmpty => t('points.filter_empty');
  String get pointsFilterEmptySub => t('points.filter_empty_sub');
  String get pointsEmptyEncourage => t('points.empty_encourage');
  String get pointsSearchPlaceholder => t('points.search_placeholder');
  String get pointsFavoritesOnly => t('points.favorites_only');
  String get pointsExportSoon => t('points.export_soon');

  // Sort names (for PointsSort enum)
  String get sortNewest => t('sort.newest');
  String get sortOldest => t('sort.oldest');
  String get sortTitle => t('sort.title');
  String get sortCategory => t('sort.category');

  // Tracks / Routes / Zones extras
  String get tracksRecordedSuffix => t('tracks.recorded_suffix');
  String get tracksCountShort => t('tracks.count_short');
  String get tracksImportExportTooltip => t('tracks.import_export_tooltip');
  String get tracksRecordingPrefix => t('tracks.recording_prefix');
  String get tracksPointsShort => t('tracks.points_short');
  String get tracksToMap => t('tracks.to_map');
  String get tracksEmptyTitle2 => t('tracks.empty_title2');
  String get tracksEmptyDesc2 => t('tracks.empty_desc2');
  String get routesEmptyTitle => t('routes.empty_title');
  String get routesEmptyDesc => t('routes.empty_desc');
  String get routesImportGpx => t('routes.import_gpx');
  String get zonesEmptyTitle2 => t('zones.empty_title2');
  String get zonesEmptyDesc2 => t('zones.empty_desc2');

  // Zone detail
  String get zoneNoteHint => t('zone.note_hint');
  String get zoneSaveChanges => t('zone.save_changes');
  String get zoneDeleteConfirmTitle => t('zone.delete_confirm_title');
  String get zoneDeleteConfirmBody => t('zone.delete_confirm_body');
  String get zoneVerticesHeader => t('zone.vertices_header');
  String get zoneKindArea => t('zone.kind_area');
  String get zoneKindDistance => t('zone.kind_distance');

  // Downloads screen
  String get downloadsDeleteConfirm => t('downloads.delete_confirm');
  String get downloadsProgressOf => t('downloads.progress_of');

  // App lock
  String get lockBiometricSub => t('lock.biometric_sub');

  // Map HUD / Navigation HUD / Measure / Quick layers
  String get hudSpeed => t('hud.speed');
  String get hudAlt => t('hud.alt');
  String get hudAccuracy => t('hud.accuracy');
  String get hudSearchingSignal => t('hud.searching_signal');
  String get hudRecordingBadge => t('hud.recording_badge');
  String get navHudTo => t('nav_hud.to');
  String get navHudStop => t('nav_hud.stop');
  String get quickLayersNoUserLayers => t('quick_layers.no_user_layers');

  // Point detail / new point extras
  String get newPointNameRequired => t('new_point.name_required');
  String get pointDetailNoNote => t('point.no_note');
  String get pointDetailShowRoute => t('point.show_route');
  String get pointDetailFavorite => t('point.favorite');
  String get pointDetailUnfavorite => t('point.unfavorite');

  // Import layer sheet
  String get importLayerTitle => t('import.title');
  String get importLayerXyzTab => t('import.xyz_tab');
  String get importLayerFileTab => t('import.file_tab');
  String get importLayerPickFile => t('import.pick_file');
  String get importLayerAdded => t('import.added');
  String get importLayerInvalid => t('import.invalid');

  // Download area sheet
  String get downloadAreaCurrentView => t('download_area.current_view');
  String get downloadAreaZoomMin => t('download_area.zoom_min');
  String get downloadAreaZoomMax => t('download_area.zoom_max');
  String get downloadAreaHint => t('download_area.hint');

  // --- Translations table ---
  static const _all = <String, Map<String, String>>{
    'ru': {
      // Nav
      'nav.map': 'Карта',
      'nav.points': 'Точки',
      'nav.tracks': 'Треки',
      'nav.settings': 'Настройки',
      // Common
      'common.save': 'Сохранить',
      'common.cancel': 'Отмена',
      'common.delete': 'Удалить',
      'common.edit': 'Редактировать',
      'common.close': 'Закрыть',
      'common.ok': 'OK',
      'common.later': 'Позже',
      'common.back': 'Назад',
      'common.done': 'Готово',
      'common.open': 'Открыть',
      'common.yes': 'Да',
      'common.no': 'Нет',
      'common.retry': 'Повторить',
      'common.error': 'Ошибка',
      'common.not_found': 'Не найдено',
      'common.search': 'Поиск',
      'common.empty': 'Пусто',
      'common.add': 'Добавить',
      'common.remove': 'Убрать',
      'common.share': 'Поделиться',
      'common.start': 'Старт',
      'common.stop': 'Стоп',
      'common.continue': 'Продолжить',
      // Settings
      'settings.title': 'Настройки',
      'settings.interface': 'Интерфейс',
      'settings.language': 'Язык',
      'settings.language_tap': 'Нажмите, чтобы выбрать',
      'settings.help': 'Помощь',
      'settings.data': 'Данные',
      'settings.security': 'Безопасность',
      'settings.track_record': 'Запись трека',
      'settings.display': 'Отображение',
      'settings.voice': 'Голосовые подсказки',
      'settings.shake': 'Сохранение встряхиванием',
      'settings.meta': 'Метаданные точек',
      'settings.locale_hint':
          'Выбранный язык применяется ко всему интерфейсу сразу. Длинные тексты (обучение, Wiki) пока только на русском.',
      'settings.min_distance': 'Мин. дистанция между точками',
      'settings.min_interval': 'Мин. интервал',
      'settings.gps_accuracy': 'Точность GPS (отсекать при хуже)',
      'settings.track_width': 'Толщина линии трека',
      'settings.speedometer': 'Спидометр',
      'settings.compass': 'Компас',
      'settings.compass_expanded': 'Расширенный компас (с розой)',
      'settings.accuracy': 'Индикатор точности',
      'settings.points_on_map': 'Точки на карте',
      'settings.keep_screen_on': 'Не выключать экран',
      'settings.map_orientation': 'Ориентация карты',
      'settings.voice_guide': 'Голосовое сопровождение',
      'settings.short_hints': 'Короткие подсказки',
      'settings.hint_step': 'Шаг подсказки',
      'settings.hint_cooldown': 'Пауза между подсказками',
      'settings.shake_save': 'Точка при встряхивании',
      'settings.sensitivity': 'Чувствительность',
      'settings.auto_audio': 'Автозапись аудио после точки',
      'settings.altitude': 'Высота',
      'settings.pressure': 'Давление',
      'settings.moon': 'Фаза луны',
      'settings.weather': 'Погода',
      'settings.app_lock': 'Блокировка приложения',
      'settings.biometric': 'Биометрия (Face/Fingerprint)',
      'settings.secret_category': '«Секретные места» под паролем',
      'settings.help_wiki': 'Инструкции и Wiki',
      'settings.help_wiki_sub': '7 разделов с подсказками',
      'settings.repeat_onboarding': 'Повторить обучение',
      'settings.repeat_onboarding_sub': '5-шаговый стартовый тур',
      'settings.permissions': 'Разрешения',
      'settings.permissions_sub': 'Проверить и выдать доступы',
      'settings.import_export': 'Импорт / экспорт GPX',
      'settings.import_export_sub': 'Треки, точки, маршруты, GeoJSON, KML',
      'settings.downloads': 'Загрузки карт',
      'settings.downloads_sub': 'Прогресс offline-скачиваний',
      'settings.cloud_sync': 'Синхронизация с облаком',
      'settings.cloud_sync_sub': 'Phase 4 — E2EE + TLS 1.3',
      'settings.backup': 'Зашифрованный бэкап',
      'settings.backup_sub': 'AES-256 + ваш пароль',
      // Map
      'map.layers': 'Слои',
      'map.download_area': 'Скачать область',
      'map.weather_map': 'Погода',
      'map.weather_on': 'Погодная карта включена',
      'map.measure': 'Измерение',
      'map.center': 'Центрировать',
      'map.record': 'Записать трек',
      'map.record_stop': 'Остановить трек',
      'map.new_point': 'Новая точка',
      'map.here_label': 'Точка здесь',
      'map.no_gps': 'Нет сигнала GPS',
      'map.rec_started':
          'Запись трека началась. Работает в фоне при заблокированном экране.',
      'map.rec_stopped_short':
          'Запись остановлена. Точек слишком мало — трек не сохранён.',
      'map.rec_saved': 'Трек сохранён',
      'map.measure_distance': 'Измерить расстояние',
      'map.measure_distance_hint': 'Тапайте по карте, чтобы поставить точки',
      'map.measure_area': 'Измерить площадь',
      'map.measure_area_hint': 'Замкнутый полигон (в га / км²)',
      'map.base_map_title': 'БАЗОВАЯ КАРТА',
      'map.user_layers_title': 'ПОЛЬЗОВАТЕЛЬСКИЕ СЛОИ',
      'map.add_layer_hint':
          'Добавьте свои карты: .mbtiles, .sqlitedb, .ozf2, .zmp или XYZ-URL',
      'map.shake_saved': 'Точка сохранена встряхиванием',
      'map.nav_start_to': 'Начинаю навигацию к',
      'map.nav_stop': 'Навигация завершена',
      // Base map
      'base.schema': 'Схема',
      'base.satellite': 'Спутник',
      'base.hybrid': 'Гибрид',
      'base.terrain': 'Рельеф',
      'base.dark': 'Тёмная',
      'base.yandex_map': 'Яндекс Карта',
      'base.yandex_sat': 'Яндекс Спутник',
      // Orientation
      'orient.auto': 'Авто',
      'orient.north': 'На север',
      'orient.course': 'По курсу',
      // Points
      'points.all': 'Все точки',
      'points.empty_title': 'Пока нет точек',
      'points.empty_sub':
          'Долгое нажатие на карте или кнопка «Новая точка» создадут первую',
      'points.open_map': 'Открыть карту',
      'points.search': 'Поиск по названию',
      'points.filters': 'Фильтры',
      'points.sort': 'Сортировка',
      'points.sort_new': 'Сначала новые',
      'points.sort_old': 'Сначала старые',
      'points.sort_az': 'По алфавиту',
      'points.sort_distance': 'По расстоянию',
      'points.favorite': 'Избранное',
      'points.favorites': 'Избранные',
      'points.category': 'Категория',
      'points.coordinates': 'Координаты',
      'points.created': 'Создано',
      'points.note': 'Заметка',
      'points.photos': 'Фото',
      'points.audio': 'Аудио',
      'points.meta': 'Метаданные',
      'points.navigate_here': 'Навигация сюда',
      'points.stop_navigation': 'Остановить навигацию',
      'points.show_on_map': 'Показать на карте',
      'points.delete_confirm': 'Удалить точку?',
      'points.deleted': 'Точка удалена',
      'points.saved': 'Точка сохранена',
      'points.default_name': 'Точка',
      // New point
      'new_point.title': 'Новая точка',
      'new_point.edit_title': 'Редактирование точки',
      'new_point.name': 'Название',
      'new_point.name_hint': 'Например: Старая лодка',
      'new_point.note': 'Заметка',
      'new_point.note_hint': 'Детали, подсказки, условия...',
      'new_point.category': 'Категория',
      'new_point.icon': 'Иконка',
      'new_point.add_photo': 'Добавить фото',
      'new_point.from_camera': 'С камеры',
      'new_point.from_gallery': 'Из галереи',
      'new_point.voice_memo': 'Голосовая заметка',
      'new_point.record': 'Записать',
      'new_point.recording': 'Идёт запись…',
      'new_point.play': 'Воспроизвести',
      'new_point.delete_audio': 'Удалить аудио',
      // Tracks / Routes / Zones
      'tracks.tab': 'Треки',
      'routes.tab': 'Маршруты',
      'zones.tab': 'Зоны',
      'tracks.empty_title': 'Ещё нет записанных треков',
      'tracks.empty_sub': 'Нажмите «Записать трек» на карте — начнётся запись',
      'tracks.distance': 'Дистанция',
      'tracks.duration': 'Время',
      'tracks.points': 'Точек',
      'tracks.delete_confirm': 'Удалить трек?',
      'tracks.export': 'Экспорт',
      'tracks.rename': 'Переименовать',
      'tracks.default_name': 'Трек',
      // Zones
      'zones.empty_title': 'Зоны не созданы',
      'zones.empty_sub':
          'Используйте инструмент «Измерение» и кнопку «Сохранить как зону»',
      'zones.area': 'Площадь',
      'zones.perimeter': 'Периметр',
      'zones.vertices': 'Вершин',
      'zones.type': 'Тип зоны',
      'zones.edit_vertices': 'Редактировать вершины',
      'zones.done': 'Готово',
      'zones.delete_vertex': 'Удалить вершину',
      'zones.rename_vertex': 'Переименовать вершину',
      'zone.type.hunt': 'Охотничье угодье',
      'zone.type.forest': 'Лесной квартал',
      'zone.type.water': 'Аквазона',
      'zone.type.mushroom': 'Грибное место',
      'zone.type.forbidden': 'Запретная зона',
      'zone.type.custom': 'Своя зона',
      // Downloads
      'downloads.title': 'Загрузки карт',
      'downloads.empty': 'Загрузок пока нет',
      'downloads.active': 'В процессе',
      'downloads.done': 'Готово',
      'downloads.failed': 'Ошибка',
      'downloads.pause': 'Пауза',
      'downloads.resume': 'Возобновить',
      'downloads.cancel': 'Отменить',
      'downloads.tiles': 'тайлов',
      'downloads.size': 'Размер',
      // Download area
      'download_area.title': 'Скачать область',
      'download_area.zoom': 'Уровень детализации',
      'download_area.tiles': 'Тайлов',
      'download_area.size': 'Размер',
      'download_area.start': 'Начать',
      'download_area.source': 'Источник',
      // Measure
      'measure.distance': 'Расстояние',
      'measure.area': 'Площадь',
      'measure.perimeter': 'Периметр',
      'measure.points': 'Точек',
      'measure.save_as_zone': 'Сохранить как зону',
      'measure.clear': 'Очистить',
      'measure.exit': 'Выйти',
      'measure.hint': 'Тапайте, чтобы поставить точки',
      'measure.area_hint': 'Поставьте ≥ 3 точек, чтобы замкнуть полигон',
      // Save zone
      'save_zone.title': 'Сохранить как зону',
      'save_zone.name': 'Название',
      'save_zone.name_hint': 'Например: Обход участка',
      'save_zone.type': 'Тип',
      // Layers
      'layers.title': 'Слои карты',
      'layers.add': 'Добавить слой',
      'layers.import_title': 'Импорт слоя',
      'layers.import_xyz': 'XYZ URL',
      'layers.import_file': 'Файл .mbtiles / .sqlitedb',
      'layers.import_xyz_hint':
          'Введите URL-шаблон с заполнителями {z}, {x}, {y}',
      'layers.import_url': 'URL',
      'layers.import_name': 'Название слоя',
      'layers.opacity': 'Прозрачность',
      // Lock
      'lock.title': 'Требуется аутентификация',
      'lock.subtitle':
          'Биометрия или PIN устройства — чтобы открыть ваши точки, треки и секретные места.',
      'lock.unlock': 'Разблокировать',
      'lock.test_now': 'Проверить сейчас',
      'lock.emergency_exit': 'Аварийный выход',
      'lock.failed_try_again': 'Не распознано. Попробуйте снова.',
      // Language
      'lang.applied': 'Язык применён',
      'lang.partial_notice':
          'Выбранный язык применяется ко всему интерфейсу сразу. Длинные тексты (обучение, Wiki) пока только на русском — остальные языки работают в режиме частичного перевода.',
      // App bars
      'data.title': 'Данные',
      'backup.title': 'Зашифрованный бэкап',
      'help.title': 'Помощь',
      // Categories
      'cat.all': 'Все',
      'cat.fishing': 'Рыбалка',
      'cat.hunting': 'Охота',
      'cat.tourism': 'Туризм',
      'cat.mushrooms': 'Грибы и ягоды',
      'cat.treasure': 'Поиск',
      'cat.infra': 'Инфраструктура',
      'cat.danger': 'Опасности',
      'cat.other': 'Прочее',
      // Points list
      'points.filter_empty': 'По фильтру ничего не найдено',
      'points.filter_empty_sub': 'Поменяйте фильтр или сбросьте поиск.',
      'points.empty_encourage':
          'Создавайте точки на карте — тапом, голосом или встряхиванием телефона. Рыба, грибы, родники, находки — всё здесь.',
      'points.search_placeholder': 'Искать точку…',
      'points.favorites_only': 'Только избранные',
      'points.export_soon': 'Экспорт / импорт — в следующей фазе',
      // Sort
      'sort.newest': 'Сначала новые',
      'sort.oldest': 'Сначала старые',
      'sort.title': 'По названию',
      'sort.category': 'По категории',
      // Tracks / Routes / Zones extras
      'tracks.recorded_suffix': 'записано',
      'tracks.count_short': 'шт.',
      'tracks.import_export_tooltip': 'Импорт / экспорт',
      'tracks.recording_prefix': 'Запись',
      'tracks.points_short': 'точек',
      'tracks.to_map': 'На карту',
      'tracks.empty_title2': 'У вас ещё нет треков',
      'tracks.empty_desc2':
          'Откройте карту и запустите запись — приложение сохранит весь ваш путь с адаптивной фильтрацией шума.',
      'routes.empty_title': 'Маршрутов пока нет',
      'routes.empty_desc':
          'Создайте маршрут из сохранённых точек или импортируйте GPX-файл из другой программы.',
      'routes.import_gpx': 'Импорт GPX',
      'zones.empty_title2': 'Зон пока нет',
      'zones.empty_desc2':
          'Включите измерение на карте, обведите квартал / угодье / аквазону и сохраните с именем и типом.',
      // Zone detail
      'zone.note_hint': 'Заметка',
      'zone.save_changes': 'Сохранить изменения',
      'zone.delete_confirm_title': 'Удалить зону?',
      'zone.delete_confirm_body': 'Действие нельзя отменить.',
      'zone.vertices_header': 'Вершины',
      'zone.kind_area': 'Полигон',
      'zone.kind_distance': 'Линия',
      // Downloads
      'downloads.delete_confirm': 'Удалить загрузку?',
      'downloads.progress_of': 'из',
      // App lock
      'lock.biometric_sub': 'Приложите палец или посмотрите в камеру',
      // HUD
      'hud.speed': 'Скорость',
      'hud.alt': 'Высота',
      'hud.accuracy': 'Точность',
      'hud.searching_signal': 'Поиск сигнала…',
      'hud.recording_badge': 'ЗАПИСЬ',
      'nav_hud.to': 'До цели',
      'nav_hud.stop': 'Остановить',
      'quick_layers.no_user_layers': 'Добавьте свои слои',
      // New point / point detail
      'new_point.name_required': 'Введите название точки',
      'point.no_note': 'Без заметки',
      'point.show_route': 'Маршрут',
      'point.favorite': 'В избранное',
      'point.unfavorite': 'Убрать из избранного',
      // Import layer
      'import.title': 'Импорт слоя',
      'import.xyz_tab': 'XYZ URL',
      'import.file_tab': 'Файл',
      'import.pick_file': 'Выбрать файл',
      'import.added': 'Слой добавлен',
      'import.invalid': 'Некорректный URL или файл',
      // Download area
      'download_area.current_view': 'Текущая область видимости',
      'download_area.zoom_min': 'Мин. zoom',
      'download_area.zoom_max': 'Макс. zoom',
      'download_area.hint':
          'Загрузка тайлов для offline-просмотра. Пока скачивается, можно продолжать пользоваться приложением.',
    },
    'en': {
      'nav.map': 'Map',
      'nav.points': 'Points',
      'nav.tracks': 'Tracks',
      'nav.settings': 'Settings',
      'common.save': 'Save',
      'common.cancel': 'Cancel',
      'common.delete': 'Delete',
      'common.edit': 'Edit',
      'common.close': 'Close',
      'common.ok': 'OK',
      'common.later': 'Later',
      'common.back': 'Back',
      'common.done': 'Done',
      'common.open': 'Open',
      'common.yes': 'Yes',
      'common.no': 'No',
      'common.retry': 'Retry',
      'common.error': 'Error',
      'common.not_found': 'Not found',
      'common.search': 'Search',
      'common.empty': 'Empty',
      'common.add': 'Add',
      'common.remove': 'Remove',
      'common.share': 'Share',
      'common.start': 'Start',
      'common.stop': 'Stop',
      'common.continue': 'Continue',
      'settings.title': 'Settings',
      'settings.interface': 'Interface',
      'settings.language': 'Language',
      'settings.language_tap': 'Tap to choose',
      'settings.help': 'Help',
      'settings.data': 'Data',
      'settings.security': 'Security',
      'settings.track_record': 'Track recording',
      'settings.display': 'Display',
      'settings.voice': 'Voice hints',
      'settings.shake': 'Shake to save',
      'settings.meta': 'POI metadata',
      'settings.locale_hint':
          'The chosen language applies to the whole UI immediately. Long-form content (onboarding, Wiki) is currently Russian-only.',
      'settings.min_distance': 'Min. distance between points',
      'settings.min_interval': 'Min. interval',
      'settings.gps_accuracy': 'GPS accuracy (reject worse than)',
      'settings.track_width': 'Track line width',
      'settings.speedometer': 'Speedometer',
      'settings.compass': 'Compass',
      'settings.compass_expanded': 'Expanded compass (with rose)',
      'settings.accuracy': 'Accuracy indicator',
      'settings.points_on_map': 'POIs on the map',
      'settings.keep_screen_on': 'Keep screen on',
      'settings.map_orientation': 'Map orientation',
      'settings.voice_guide': 'Voice guidance',
      'settings.short_hints': 'Short hints',
      'settings.hint_step': 'Hint step',
      'settings.hint_cooldown': 'Hint cooldown',
      'settings.shake_save': 'Point on shake',
      'settings.sensitivity': 'Sensitivity',
      'settings.auto_audio': 'Auto-record audio after point',
      'settings.altitude': 'Altitude',
      'settings.pressure': 'Pressure',
      'settings.moon': 'Moon phase',
      'settings.weather': 'Weather',
      'settings.app_lock': 'App lock',
      'settings.biometric': 'Biometrics (Face/Fingerprint)',
      'settings.secret_category': 'Lock the "Secret" category',
      'settings.help_wiki': 'Instructions & Wiki',
      'settings.help_wiki_sub': '7 how-to sections',
      'settings.repeat_onboarding': 'Replay onboarding',
      'settings.repeat_onboarding_sub': '5-step starter tour',
      'settings.permissions': 'Permissions',
      'settings.permissions_sub': 'Review and grant access',
      'settings.import_export': 'Import / export GPX',
      'settings.import_export_sub': 'Tracks, points, routes, GeoJSON, KML',
      'settings.downloads': 'Map downloads',
      'settings.downloads_sub': 'Offline download progress',
      'settings.cloud_sync': 'Cloud sync',
      'settings.cloud_sync_sub': 'Phase 4 — E2EE + TLS 1.3',
      'settings.backup': 'Encrypted backup',
      'settings.backup_sub': 'AES-256 + your password',
      'map.layers': 'Layers',
      'map.download_area': 'Download area',
      'map.weather_map': 'Weather',
      'map.weather_on': 'Weather map on',
      'map.measure': 'Measure',
      'map.center': 'Center on me',
      'map.record': 'Record track',
      'map.record_stop': 'Stop track',
      'map.new_point': 'New point',
      'map.here_label': 'Point here',
      'map.no_gps': 'No GPS signal',
      'map.rec_started':
          'Track recording started. Runs in the background when the screen is locked.',
      'map.rec_stopped_short':
          'Recording stopped. Too few points — track was not saved.',
      'map.rec_saved': 'Track saved',
      'map.measure_distance': 'Measure distance',
      'map.measure_distance_hint': 'Tap on the map to place points',
      'map.measure_area': 'Measure area',
      'map.measure_area_hint': 'Closed polygon (in ha / km²)',
      'map.base_map_title': 'BASE MAP',
      'map.user_layers_title': 'USER LAYERS',
      'map.add_layer_hint':
          'Add your own maps: .mbtiles, .sqlitedb, .ozf2, .zmp or an XYZ URL',
      'map.shake_saved': 'Point saved by shake',
      'map.nav_start_to': 'Starting navigation to',
      'map.nav_stop': 'Navigation stopped',
      'base.schema': 'Map',
      'base.satellite': 'Satellite',
      'base.hybrid': 'Hybrid',
      'base.terrain': 'Terrain',
      'base.dark': 'Dark',
      'base.yandex_map': 'Yandex Map',
      'base.yandex_sat': 'Yandex Satellite',
      'orient.auto': 'Auto',
      'orient.north': 'North up',
      'orient.course': 'Course up',
      'points.all': 'All points',
      'points.empty_title': 'No points yet',
      'points.empty_sub':
          'A long-press on the map or the "New point" button will create your first one',
      'points.open_map': 'Open map',
      'points.search': 'Search by name',
      'points.filters': 'Filters',
      'points.sort': 'Sort',
      'points.sort_new': 'Newest first',
      'points.sort_old': 'Oldest first',
      'points.sort_az': 'Alphabetical',
      'points.sort_distance': 'By distance',
      'points.favorite': 'Favorite',
      'points.favorites': 'Favorites',
      'points.category': 'Category',
      'points.coordinates': 'Coordinates',
      'points.created': 'Created',
      'points.note': 'Note',
      'points.photos': 'Photos',
      'points.audio': 'Audio',
      'points.meta': 'Metadata',
      'points.navigate_here': 'Navigate here',
      'points.stop_navigation': 'Stop navigation',
      'points.show_on_map': 'Show on map',
      'points.delete_confirm': 'Delete point?',
      'points.deleted': 'Point deleted',
      'points.saved': 'Point saved',
      'points.default_name': 'Point',
      'new_point.title': 'New point',
      'new_point.edit_title': 'Edit point',
      'new_point.name': 'Name',
      'new_point.name_hint': 'e.g. Old boat',
      'new_point.note': 'Note',
      'new_point.note_hint': 'Details, hints, conditions…',
      'new_point.category': 'Category',
      'new_point.icon': 'Icon',
      'new_point.add_photo': 'Add photo',
      'new_point.from_camera': 'From camera',
      'new_point.from_gallery': 'From gallery',
      'new_point.voice_memo': 'Voice memo',
      'new_point.record': 'Record',
      'new_point.recording': 'Recording…',
      'new_point.play': 'Play',
      'new_point.delete_audio': 'Delete audio',
      'tracks.tab': 'Tracks',
      'routes.tab': 'Routes',
      'zones.tab': 'Zones',
      'tracks.empty_title': 'No tracks recorded yet',
      'tracks.empty_sub':
          'Tap "Record track" on the map and recording will begin',
      'tracks.distance': 'Distance',
      'tracks.duration': 'Duration',
      'tracks.points': 'Points',
      'tracks.delete_confirm': 'Delete track?',
      'tracks.export': 'Export',
      'tracks.rename': 'Rename',
      'tracks.default_name': 'Track',
      'zones.empty_title': 'No zones created',
      'zones.empty_sub':
          'Use the Measure tool and "Save as zone" button',
      'zones.area': 'Area',
      'zones.perimeter': 'Perimeter',
      'zones.vertices': 'Vertices',
      'zones.type': 'Zone type',
      'zones.edit_vertices': 'Edit vertices',
      'zones.done': 'Done',
      'zones.delete_vertex': 'Delete vertex',
      'zones.rename_vertex': 'Rename vertex',
      'zone.type.hunt': 'Hunting ground',
      'zone.type.forest': 'Forest block',
      'zone.type.water': 'Water zone',
      'zone.type.mushroom': 'Mushroom spot',
      'zone.type.forbidden': 'No-go zone',
      'zone.type.custom': 'Custom zone',
      'downloads.title': 'Map downloads',
      'downloads.empty': 'No downloads yet',
      'downloads.active': 'In progress',
      'downloads.done': 'Done',
      'downloads.failed': 'Failed',
      'downloads.pause': 'Pause',
      'downloads.resume': 'Resume',
      'downloads.cancel': 'Cancel',
      'downloads.tiles': 'tiles',
      'downloads.size': 'Size',
      'download_area.title': 'Download area',
      'download_area.zoom': 'Detail level',
      'download_area.tiles': 'Tiles',
      'download_area.size': 'Size',
      'download_area.start': 'Start',
      'download_area.source': 'Source',
      'measure.distance': 'Distance',
      'measure.area': 'Area',
      'measure.perimeter': 'Perimeter',
      'measure.points': 'Points',
      'measure.save_as_zone': 'Save as zone',
      'measure.clear': 'Clear',
      'measure.exit': 'Exit',
      'measure.hint': 'Tap to place points',
      'measure.area_hint': 'Place ≥ 3 points to close a polygon',
      'save_zone.title': 'Save as zone',
      'save_zone.name': 'Name',
      'save_zone.name_hint': 'e.g. Patrol loop',
      'save_zone.type': 'Type',
      'layers.title': 'Map layers',
      'layers.add': 'Add layer',
      'layers.import_title': 'Import layer',
      'layers.import_xyz': 'XYZ URL',
      'layers.import_file': 'File .mbtiles / .sqlitedb',
      'layers.import_xyz_hint':
          'Enter a URL template with placeholders {z}, {x}, {y}',
      'layers.import_url': 'URL',
      'layers.import_name': 'Layer name',
      'layers.opacity': 'Opacity',
      'lock.title': 'Authentication required',
      'lock.subtitle':
          'Biometrics or device PIN — to unlock your points, tracks and secret places.',
      'lock.unlock': 'Unlock',
      'lock.test_now': 'Test now',
      'lock.emergency_exit': 'Emergency exit',
      'lock.failed_try_again': 'Not recognized. Try again.',
      'lang.applied': 'Language applied',
      'lang.partial_notice':
          'The chosen language is applied to the entire UI immediately. Long-form content (onboarding, Wiki) is currently Russian-only — other locales fall back partially.',
      'data.title': 'Data',
      'backup.title': 'Encrypted backup',
      'help.title': 'Help',
      'cat.all': 'All',
      'cat.fishing': 'Fishing',
      'cat.hunting': 'Hunting',
      'cat.tourism': 'Tourism',
      'cat.mushrooms': 'Mushrooms & berries',
      'cat.treasure': 'Treasure hunt',
      'cat.infra': 'Infrastructure',
      'cat.danger': 'Hazards',
      'cat.other': 'Other',
      'points.filter_empty': 'Nothing matches the filter',
      'points.filter_empty_sub': 'Change the filter or reset the search.',
      'points.empty_encourage':
          'Create points on the map — by tap, voice or shaking your phone. Fish, mushrooms, springs, finds — all in one place.',
      'points.search_placeholder': 'Search point…',
      'points.favorites_only': 'Favorites only',
      'points.export_soon': 'Export / import — next phase',
      'sort.newest': 'Newest first',
      'sort.oldest': 'Oldest first',
      'sort.title': 'By name',
      'sort.category': 'By category',
      'tracks.recorded_suffix': 'recorded',
      'tracks.count_short': 'items',
      'tracks.import_export_tooltip': 'Import / export',
      'tracks.recording_prefix': 'Recording',
      'tracks.points_short': 'points',
      'tracks.to_map': 'To map',
      'tracks.empty_title2': 'No tracks yet',
      'tracks.empty_desc2':
          'Open the map and start recording — the app will capture your whole path with adaptive noise filtering.',
      'routes.empty_title': 'No routes yet',
      'routes.empty_desc':
          'Build a route from saved points or import a GPX file from another app.',
      'routes.import_gpx': 'Import GPX',
      'zones.empty_title2': 'No zones yet',
      'zones.empty_desc2':
          'Turn on the Measure tool, outline a block / area / water zone and save it with a name and type.',
      'zone.note_hint': 'Note',
      'zone.save_changes': 'Save changes',
      'zone.delete_confirm_title': 'Delete zone?',
      'zone.delete_confirm_body': 'This action cannot be undone.',
      'zone.vertices_header': 'Vertices',
      'zone.kind_area': 'Polygon',
      'zone.kind_distance': 'Line',
      'downloads.delete_confirm': 'Delete download?',
      'downloads.progress_of': 'of',
      'lock.biometric_sub': 'Place your finger or look at the camera',
      'hud.speed': 'Speed',
      'hud.alt': 'Altitude',
      'hud.accuracy': 'Accuracy',
      'hud.searching_signal': 'Searching signal…',
      'hud.recording_badge': 'REC',
      'nav_hud.to': 'To target',
      'nav_hud.stop': 'Stop',
      'quick_layers.no_user_layers': 'Add your own layers',
      'new_point.name_required': 'Enter a point name',
      'point.no_note': 'No note',
      'point.show_route': 'Route',
      'point.favorite': 'Add to favorites',
      'point.unfavorite': 'Remove from favorites',
      'import.title': 'Import layer',
      'import.xyz_tab': 'XYZ URL',
      'import.file_tab': 'File',
      'import.pick_file': 'Pick file',
      'import.added': 'Layer added',
      'import.invalid': 'Invalid URL or file',
      'download_area.current_view': 'Current viewport',
      'download_area.zoom_min': 'Min. zoom',
      'download_area.zoom_max': 'Max. zoom',
      'download_area.hint':
          'Downloading tiles for offline use. You can keep using the app while it runs.',
    },
    'be': {
      'nav.map': 'Карта',
      'nav.points': 'Пункты',
      'nav.tracks': 'Трэкі',
      'nav.settings': 'Налады',
      'common.save': 'Захаваць',
      'common.cancel': 'Адмена',
      'common.delete': 'Выдаліць',
      'common.edit': 'Рэдагаваць',
      'common.close': 'Закрыць',
      'common.ok': 'OK',
      'common.later': 'Пазней',
      'common.back': 'Назад',
      'common.done': 'Гатова',
      'common.open': 'Адкрыць',
      'common.yes': 'Так',
      'common.no': 'Не',
      'common.retry': 'Паўтарыць',
      'common.error': 'Памылка',
      'common.not_found': 'Не знойдзена',
      'common.search': 'Пошук',
      'common.empty': 'Пуста',
      'common.add': 'Дадаць',
      'common.remove': 'Прыбраць',
      'common.share': 'Падзяліцца',
      'common.start': 'Старт',
      'common.stop': 'Стоп',
      'common.continue': 'Працягнуць',
      'settings.title': 'Налады',
      'settings.interface': 'Інтэрфейс',
      'settings.language': 'Мова',
      'settings.language_tap': 'Націсніце, каб выбраць',
      'settings.help': 'Дапамога',
      'settings.data': 'Дадзеныя',
      'settings.security': 'Бяспека',
      'settings.track_record': 'Запіс трэка',
      'settings.display': 'Адлюстраванне',
      'settings.voice': 'Галасавыя падказкі',
      'settings.shake': 'Захаванне страсаннем',
      'settings.meta': 'Метаданыя пунктаў',
      'settings.locale_hint':
          'Абраная мова ўжываецца да ўсяго інтэрфейсу адразу. Працяглыя тэксты (навучанне, Wiki) пакуль толькі на рускай.',
      'settings.min_distance': 'Мін. дыстанцыя паміж пунктамі',
      'settings.min_interval': 'Мін. інтэрвал',
      'settings.gps_accuracy': 'Дакладнасць GPS (адсякаць горш за)',
      'settings.track_width': 'Таўшчыня лініі трэка',
      'settings.speedometer': 'Спідометр',
      'settings.compass': 'Компас',
      'settings.compass_expanded': 'Пашыраны компас (з ружай)',
      'settings.accuracy': 'Індыкатар дакладнасці',
      'settings.points_on_map': 'Пункты на мапе',
      'settings.keep_screen_on': 'Не выключаць экран',
      'settings.map_orientation': 'Арыентацыя мапы',
      'settings.voice_guide': 'Галасавае суправаджэнне',
      'settings.short_hints': 'Кароткія падказкі',
      'settings.hint_step': 'Крок падказкі',
      'settings.hint_cooldown': 'Паўза паміж падказкамі',
      'settings.shake_save': 'Пункт пры страсанні',
      'settings.sensitivity': 'Адчувальнасць',
      'settings.auto_audio': 'Аўтазапіс аўдыя пасля пункта',
      'settings.altitude': 'Вышыня',
      'settings.pressure': 'Ціск',
      'settings.moon': 'Фаза месяца',
      'settings.weather': 'Надвор’е',
      'settings.app_lock': 'Блакіроўка прыкладання',
      'settings.biometric': 'Біяметрыя (Face/Fingerprint)',
      'settings.secret_category': '«Сакрэтныя месцы» пад паролем',
      'settings.help_wiki': 'Інструкцыі і Wiki',
      'settings.help_wiki_sub': '7 раздзелаў з падказкамі',
      'settings.repeat_onboarding': 'Паўтарыць навучанне',
      'settings.repeat_onboarding_sub': '5-крокавы стартавы тур',
      'settings.permissions': 'Дазволы',
      'settings.permissions_sub': 'Праверыць і выдаць доступы',
      'settings.import_export': 'Імпарт / экспарт GPX',
      'settings.import_export_sub':
          'Трэкі, пункты, маршруты, GeoJSON, KML',
      'settings.downloads': 'Загрузкі мап',
      'settings.downloads_sub': 'Прагрэс offline-спампоўванняў',
      'settings.cloud_sync': 'Сінхранізацыя з воблакам',
      'settings.cloud_sync_sub': 'Phase 4 — E2EE + TLS 1.3',
      'settings.backup': 'Зашыфраваны бэкап',
      'settings.backup_sub': 'AES-256 + ваш пароль',
      'map.layers': 'Пласты',
      'map.download_area': 'Спампаваць вобласць',
      'map.weather_map': 'Надвор’е',
      'map.weather_on': 'Карта надвор’я ўключана',
      'map.measure': 'Вымярэнне',
      'map.center': 'Цэнтраваць',
      'map.record': 'Запісаць трэк',
      'map.record_stop': 'Спыніць трэк',
      'map.new_point': 'Новы пункт',
      'map.here_label': 'Пункт тут',
      'map.no_gps': 'Няма сігналу GPS',
      'map.rec_started':
          'Запіс трэка пачаўся. Працуе ў фоне пры заблакаваным экране.',
      'map.rec_stopped_short':
          'Запіс спынены. Пунктаў замала — трэк не захаваны.',
      'map.rec_saved': 'Трэк захаваны',
      'map.measure_distance': 'Вымераць адлегласць',
      'map.measure_distance_hint':
          'Тапайце на мапе, каб паставіць пункты',
      'map.measure_area': 'Вымераць плошчу',
      'map.measure_area_hint': 'Замкнуты палігон (у га / км²)',
      'map.base_map_title': 'БАЗАВАЯ МАПА',
      'map.user_layers_title': 'КАРЫСТАЛЬНІЦКІЯ ПЛАСТЫ',
      'map.add_layer_hint':
          'Дадайце свае мапы: .mbtiles, .sqlitedb, .ozf2, .zmp ці XYZ-URL',
      'map.shake_saved': 'Пункт захаваны страсаннем',
      'map.nav_start_to': 'Пачынаю навігацыю да',
      'map.nav_stop': 'Навігацыю спынена',
      'base.schema': 'Схема',
      'base.satellite': 'Спадарожнік',
      'base.hybrid': 'Гібрыд',
      'base.terrain': 'Рэльеф',
      'base.dark': 'Цёмная',
      'base.yandex_map': 'Яндэкс Мапа',
      'base.yandex_sat': 'Яндэкс Спадарожнік',
      'orient.auto': 'Аўта',
      'orient.north': 'На поўнач',
      'orient.course': 'Па курсе',
      'points.all': 'Усе пункты',
      'points.empty_title': 'Пакуль няма пунктаў',
      'points.empty_sub':
          'Доўгае націсканне на мапе ці кнопка «Новы пункт» створаць першы',
      'points.open_map': 'Адкрыць мапу',
      'points.search': 'Пошук па назве',
      'points.filters': 'Фільтры',
      'points.sort': 'Сартаванне',
      'points.sort_new': 'Спачатку новыя',
      'points.sort_old': 'Спачатку старыя',
      'points.sort_az': 'Па алфавіце',
      'points.sort_distance': 'Па адлегласці',
      'points.favorite': 'Абранае',
      'points.favorites': 'Абраныя',
      'points.category': 'Катэгорыя',
      'points.coordinates': 'Каардынаты',
      'points.created': 'Створана',
      'points.note': 'Нататка',
      'points.photos': 'Фота',
      'points.audio': 'Аўдыя',
      'points.meta': 'Метаданыя',
      'points.navigate_here': 'Навігацыя сюды',
      'points.stop_navigation': 'Спыніць навігацыю',
      'points.show_on_map': 'Паказаць на мапе',
      'points.delete_confirm': 'Выдаліць пункт?',
      'points.deleted': 'Пункт выдалены',
      'points.saved': 'Пункт захаваны',
      'points.default_name': 'Пункт',
      'new_point.title': 'Новы пункт',
      'new_point.edit_title': 'Рэдагаванне пункта',
      'new_point.name': 'Назва',
      'new_point.name_hint': 'Напрыклад: Старая лодка',
      'new_point.note': 'Нататка',
      'new_point.note_hint': 'Дэталі, падказкі, умовы…',
      'new_point.category': 'Катэгорыя',
      'new_point.icon': 'Іконка',
      'new_point.add_photo': 'Дадаць фота',
      'new_point.from_camera': 'З камеры',
      'new_point.from_gallery': 'З галерэі',
      'new_point.voice_memo': 'Галасавая нататка',
      'new_point.record': 'Запісаць',
      'new_point.recording': 'Ідзе запіс…',
      'new_point.play': 'Прайграць',
      'new_point.delete_audio': 'Выдаліць аўдыя',
      'tracks.tab': 'Трэкі',
      'routes.tab': 'Маршруты',
      'zones.tab': 'Зоны',
      'tracks.empty_title': 'Няма запісаных трэкаў',
      'tracks.empty_sub':
          'Націсніце «Запісаць трэк» на мапе — пачнецца запіс',
      'tracks.distance': 'Адлегласць',
      'tracks.duration': 'Час',
      'tracks.points': 'Пунктаў',
      'tracks.delete_confirm': 'Выдаліць трэк?',
      'tracks.export': 'Экспарт',
      'tracks.rename': 'Перайменаваць',
      'tracks.default_name': 'Трэк',
      'zones.empty_title': 'Зоны не створаны',
      'zones.empty_sub':
          'Выкарыстоўвайце інструмент «Вымярэнне» і кнопку «Захаваць як зону»',
      'zones.area': 'Плошча',
      'zones.perimeter': 'Перыметр',
      'zones.vertices': 'Вяршынь',
      'zones.type': 'Тып зоны',
      'zones.edit_vertices': 'Рэдагаваць вяршыні',
      'zones.done': 'Гатова',
      'zones.delete_vertex': 'Выдаліць вяршыню',
      'zones.rename_vertex': 'Перайменаваць вяршыню',
      'zone.type.hunt': 'Паляўнічыя ўгоддзі',
      'zone.type.forest': 'Лясны квартал',
      'zone.type.water': 'Аквазона',
      'zone.type.mushroom': 'Грыбное месца',
      'zone.type.forbidden': 'Забароненая зона',
      'zone.type.custom': 'Свая зона',
      'downloads.title': 'Загрузкі мап',
      'downloads.empty': 'Загрузак пакуль няма',
      'downloads.active': 'У працэсе',
      'downloads.done': 'Гатова',
      'downloads.failed': 'Памылка',
      'downloads.pause': 'Паўза',
      'downloads.resume': 'Працягнуць',
      'downloads.cancel': 'Адмяніць',
      'downloads.tiles': 'тайлаў',
      'downloads.size': 'Памер',
      'download_area.title': 'Спампаваць вобласць',
      'download_area.zoom': 'Узровень дэталізацыі',
      'download_area.tiles': 'Тайлаў',
      'download_area.size': 'Памер',
      'download_area.start': 'Пачаць',
      'download_area.source': 'Крыніца',
      'measure.distance': 'Адлегласць',
      'measure.area': 'Плошча',
      'measure.perimeter': 'Перыметр',
      'measure.points': 'Пунктаў',
      'measure.save_as_zone': 'Захаваць як зону',
      'measure.clear': 'Ачысціць',
      'measure.exit': 'Выйсці',
      'measure.hint': 'Тапайце, каб паставіць пункты',
      'measure.area_hint':
          'Пастаўце ≥ 3 пунктаў, каб замкнуць палігон',
      'save_zone.title': 'Захаваць як зону',
      'save_zone.name': 'Назва',
      'save_zone.name_hint': 'Напрыклад: Абход участка',
      'save_zone.type': 'Тып',
      'layers.title': 'Пласты мапы',
      'layers.add': 'Дадаць пласт',
      'layers.import_title': 'Імпарт пласта',
      'layers.import_xyz': 'XYZ URL',
      'layers.import_file': 'Файл .mbtiles / .sqlitedb',
      'layers.import_xyz_hint':
          'Увядзіце шаблон URL з запаўняльнікамі {z}, {x}, {y}',
      'layers.import_url': 'URL',
      'layers.import_name': 'Назва пласта',
      'layers.opacity': 'Празрыстасць',
      'lock.title': 'Патрэбна аўтэнтыфікацыя',
      'lock.subtitle':
          'Біяметрыя або PIN прылады — каб адкрыць вашы пункты, трэкі і сакрэтныя месцы.',
      'lock.unlock': 'Разблакіраваць',
      'lock.test_now': 'Праверыць зараз',
      'lock.emergency_exit': 'Аварыйны выхад',
      'lock.failed_try_again': 'Не распазнана. Паспрабуйце зноў.',
      'lang.applied': 'Мова ўжыта',
      'lang.partial_notice':
          'Абраная мова ўжываецца да ўсяго інтэрфейсу адразу. Працяглыя тэксты (навучанне, Wiki) пакуль толькі на рускай — іншыя мовы працуюць у рэжыме частковага перакладу.',
      'data.title': 'Дадзеныя',
      'backup.title': 'Зашыфраваны бэкап',
      'help.title': 'Дапамога',
      'cat.all': 'Усе',
      'cat.fishing': 'Рыбалка',
      'cat.hunting': 'Паляванне',
      'cat.tourism': 'Турызм',
      'cat.mushrooms': 'Грыбы і ягады',
      'cat.treasure': 'Пошук',
      'cat.infra': 'Інфраструктура',
      'cat.danger': 'Небяспекі',
      'cat.other': 'Іншае',
      'points.filter_empty': 'Па фільтры нічога не знойдзена',
      'points.filter_empty_sub': 'Змяніце фільтр або скіньце пошук.',
      'points.empty_encourage':
          'Ствараеце пункты на мапе — тапам, голасам ці страсаннем тэлефона. Рыба, грыбы, крыніцы, знаходкі — усё тут.',
      'points.search_placeholder': 'Шукаць пункт…',
      'points.favorites_only': 'Толькі абраныя',
      'points.export_soon': 'Экспарт / імпарт — у наступнай фазе',
      'sort.newest': 'Спачатку новыя',
      'sort.oldest': 'Спачатку старыя',
      'sort.title': 'Па назве',
      'sort.category': 'Па катэгорыі',
      'tracks.recorded_suffix': 'запісана',
      'tracks.count_short': 'шт.',
      'tracks.import_export_tooltip': 'Імпарт / экспарт',
      'tracks.recording_prefix': 'Запіс',
      'tracks.points_short': 'пунктаў',
      'tracks.to_map': 'На мапу',
      'tracks.empty_title2': 'У вас яшчэ няма трэкаў',
      'tracks.empty_desc2':
          'Адкрыйце мапу і запусціце запіс — прыкладанне захавае ўвесь ваш шлях з адаптыўным фільтраваннем шуму.',
      'routes.empty_title': 'Маршрутаў пакуль няма',
      'routes.empty_desc':
          'Стварыце маршрут з захаваных пунктаў або імпартуйце GPX-файл з іншай праграмы.',
      'routes.import_gpx': 'Імпарт GPX',
      'zones.empty_title2': 'Зон пакуль няма',
      'zones.empty_desc2':
          'Уключыце вымярэнне на мапе, абвядзіце квартал / угоддзе / аквазону і захавайце з імем і тыпам.',
      'zone.note_hint': 'Нататка',
      'zone.save_changes': 'Захаваць змены',
      'zone.delete_confirm_title': 'Выдаліць зону?',
      'zone.delete_confirm_body': 'Дзеянне нельга адмяніць.',
      'zone.vertices_header': 'Вяршыні',
      'zone.kind_area': 'Палігон',
      'zone.kind_distance': 'Лінія',
      'downloads.delete_confirm': 'Выдаліць загрузку?',
      'downloads.progress_of': 'з',
      'lock.biometric_sub': 'Прыкладзіце палец або паглядзіце ў камеру',
      'hud.speed': 'Хуткасць',
      'hud.alt': 'Вышыня',
      'hud.accuracy': 'Дакладнасць',
      'hud.searching_signal': 'Пошук сігналу…',
      'hud.recording_badge': 'ЗАПІС',
      'nav_hud.to': 'Да мэты',
      'nav_hud.stop': 'Спыніць',
      'quick_layers.no_user_layers': 'Дадайце свае пласты',
      'new_point.name_required': 'Увядзіце назву пункта',
      'point.no_note': 'Без нататкі',
      'point.show_route': 'Маршрут',
      'point.favorite': 'У абранае',
      'point.unfavorite': 'Прыбраць з абранага',
      'import.title': 'Імпарт пласта',
      'import.xyz_tab': 'XYZ URL',
      'import.file_tab': 'Файл',
      'import.pick_file': 'Абраць файл',
      'import.added': 'Пласт дададзены',
      'import.invalid': 'Некарэктны URL ці файл',
      'download_area.current_view': 'Бягучая вобласць бачнасці',
      'download_area.zoom_min': 'Мін. zoom',
      'download_area.zoom_max': 'Макс. zoom',
      'download_area.hint':
          'Загрузка тайлаў для offline-прагляду. Пакуль спампоўваецца, можна працягваць карыстацца прыкладаннем.',
    },
    'uk': {
      'nav.map': 'Мапа',
      'nav.points': 'Точки',
      'nav.tracks': 'Треки',
      'nav.settings': 'Налаштування',
      'common.save': 'Зберегти',
      'common.cancel': 'Скасувати',
      'common.delete': 'Видалити',
      'common.edit': 'Редагувати',
      'common.close': 'Закрити',
      'common.ok': 'OK',
      'common.later': 'Пізніше',
      'common.back': 'Назад',
      'common.done': 'Готово',
      'common.open': 'Відкрити',
      'common.yes': 'Так',
      'common.no': 'Ні',
      'common.retry': 'Повторити',
      'common.error': 'Помилка',
      'common.not_found': 'Не знайдено',
      'common.search': 'Пошук',
      'common.empty': 'Порожньо',
      'common.add': 'Додати',
      'common.remove': 'Прибрати',
      'common.share': 'Поділитися',
      'common.start': 'Старт',
      'common.stop': 'Стоп',
      'common.continue': 'Продовжити',
      'settings.title': 'Налаштування',
      'settings.interface': 'Інтерфейс',
      'settings.language': 'Мова',
      'settings.language_tap': 'Натисніть, щоб обрати',
      'settings.help': 'Допомога',
      'settings.data': 'Дані',
      'settings.security': 'Безпека',
      'settings.track_record': 'Запис треку',
      'settings.display': 'Відображення',
      'settings.voice': 'Голосові підказки',
      'settings.shake': 'Збереження струшуванням',
      'settings.meta': 'Метадані точок',
      'settings.locale_hint':
          'Обрану мову застосовано до всього інтерфейсу відразу. Довгі тексти (навчання, Wiki) наразі лише російською.',
      'settings.min_distance': 'Мін. відстань між точками',
      'settings.min_interval': 'Мін. інтервал',
      'settings.gps_accuracy': 'Точність GPS (відсікати гірше)',
      'settings.track_width': 'Товщина лінії треку',
      'settings.speedometer': 'Спідометр',
      'settings.compass': 'Компас',
      'settings.compass_expanded': 'Розширений компас (з трояндою)',
      'settings.accuracy': 'Індикатор точності',
      'settings.points_on_map': 'Точки на мапі',
      'settings.keep_screen_on': 'Не вимикати екран',
      'settings.map_orientation': 'Орієнтація мапи',
      'settings.voice_guide': 'Голосовий супровід',
      'settings.short_hints': 'Короткі підказки',
      'settings.hint_step': 'Крок підказки',
      'settings.hint_cooldown': 'Пауза між підказками',
      'settings.shake_save': 'Точка при струшуванні',
      'settings.sensitivity': 'Чутливість',
      'settings.auto_audio': 'Автозапис аудіо після точки',
      'settings.altitude': 'Висота',
      'settings.pressure': 'Тиск',
      'settings.moon': 'Фаза місяця',
      'settings.weather': 'Погода',
      'settings.app_lock': 'Блокування застосунку',
      'settings.biometric': 'Біометрія (Face/Fingerprint)',
      'settings.secret_category': '«Секретні місця» під паролем',
      'settings.help_wiki': 'Інструкції та Wiki',
      'settings.help_wiki_sub': '7 розділів з підказками',
      'settings.repeat_onboarding': 'Повторити навчання',
      'settings.repeat_onboarding_sub': '5-кроковий стартовий тур',
      'settings.permissions': 'Дозволи',
      'settings.permissions_sub': 'Перевірити та надати доступи',
      'settings.import_export': 'Імпорт / експорт GPX',
      'settings.import_export_sub':
          'Треки, точки, маршрути, GeoJSON, KML',
      'settings.downloads': 'Завантаження мап',
      'settings.downloads_sub': 'Прогрес offline-завантажень',
      'settings.cloud_sync': 'Синхронізація з хмарою',
      'settings.cloud_sync_sub': 'Phase 4 — E2EE + TLS 1.3',
      'settings.backup': 'Зашифрований бекап',
      'settings.backup_sub': 'AES-256 + ваш пароль',
      'map.layers': 'Шари',
      'map.download_area': 'Завантажити область',
      'map.weather_map': 'Погода',
      'map.weather_on': 'Карта погоди увімкнена',
      'map.measure': 'Вимірювання',
      'map.center': 'Центрувати',
      'map.record': 'Записати трек',
      'map.record_stop': 'Зупинити трек',
      'map.new_point': 'Нова точка',
      'map.here_label': 'Точка тут',
      'map.no_gps': 'Немає сигналу GPS',
      'map.rec_started':
          'Запис треку розпочато. Працює у фоні при заблокованому екрані.',
      'map.rec_stopped_short':
          'Запис зупинено. Точок замало — трек не збережено.',
      'map.rec_saved': 'Трек збережено',
      'map.measure_distance': 'Виміряти відстань',
      'map.measure_distance_hint':
          'Тапайте на мапі, щоб поставити точки',
      'map.measure_area': 'Виміряти площу',
      'map.measure_area_hint': 'Замкнений полігон (у га / км²)',
      'map.base_map_title': 'БАЗОВА МАПА',
      'map.user_layers_title': 'ШАРИ КОРИСТУВАЧА',
      'map.add_layer_hint':
          'Додайте свої мапи: .mbtiles, .sqlitedb, .ozf2, .zmp або XYZ-URL',
      'map.shake_saved': 'Точку збережено струшуванням',
      'map.nav_start_to': 'Починаю навігацію до',
      'map.nav_stop': 'Навігацію зупинено',
      'base.schema': 'Схема',
      'base.satellite': 'Супутник',
      'base.hybrid': 'Гібрид',
      'base.terrain': 'Рельєф',
      'base.dark': 'Темна',
      'base.yandex_map': 'Яндекс Мапа',
      'base.yandex_sat': 'Яндекс Супутник',
      'orient.auto': 'Авто',
      'orient.north': 'На північ',
      'orient.course': 'За курсом',
      'points.all': 'Усі точки',
      'points.empty_title': 'Точок ще немає',
      'points.empty_sub':
          'Довге натискання на мапі або кнопка «Нова точка» створить першу',
      'points.open_map': 'Відкрити мапу',
      'points.search': 'Пошук за назвою',
      'points.filters': 'Фільтри',
      'points.sort': 'Сортування',
      'points.sort_new': 'Спочатку нові',
      'points.sort_old': 'Спочатку старі',
      'points.sort_az': 'За алфавітом',
      'points.sort_distance': 'За відстанню',
      'points.favorite': 'Обране',
      'points.favorites': 'Обрані',
      'points.category': 'Категорія',
      'points.coordinates': 'Координати',
      'points.created': 'Створено',
      'points.note': 'Нотатка',
      'points.photos': 'Фото',
      'points.audio': 'Аудіо',
      'points.meta': 'Метадані',
      'points.navigate_here': 'Навігація сюди',
      'points.stop_navigation': 'Зупинити навігацію',
      'points.show_on_map': 'Показати на мапі',
      'points.delete_confirm': 'Видалити точку?',
      'points.deleted': 'Точку видалено',
      'points.saved': 'Точку збережено',
      'points.default_name': 'Точка',
      'new_point.title': 'Нова точка',
      'new_point.edit_title': 'Редагування точки',
      'new_point.name': 'Назва',
      'new_point.name_hint': 'Напр.: Стара лодка',
      'new_point.note': 'Нотатка',
      'new_point.note_hint': 'Деталі, підказки, умови…',
      'new_point.category': 'Категорія',
      'new_point.icon': 'Іконка',
      'new_point.add_photo': 'Додати фото',
      'new_point.from_camera': 'З камери',
      'new_point.from_gallery': 'З галереї',
      'new_point.voice_memo': 'Голосова нотатка',
      'new_point.record': 'Записати',
      'new_point.recording': 'Йде запис…',
      'new_point.play': 'Відтворити',
      'new_point.delete_audio': 'Видалити аудіо',
      'tracks.tab': 'Треки',
      'routes.tab': 'Маршрути',
      'zones.tab': 'Зони',
      'tracks.empty_title': 'Записаних треків ще немає',
      'tracks.empty_sub':
          'Натисніть «Записати трек» на мапі — почнеться запис',
      'tracks.distance': 'Відстань',
      'tracks.duration': 'Час',
      'tracks.points': 'Точок',
      'tracks.delete_confirm': 'Видалити трек?',
      'tracks.export': 'Експорт',
      'tracks.rename': 'Перейменувати',
      'tracks.default_name': 'Трек',
      'zones.empty_title': 'Зон не створено',
      'zones.empty_sub':
          'Використовуйте інструмент «Вимірювання» та кнопку «Зберегти як зону»',
      'zones.area': 'Площа',
      'zones.perimeter': 'Периметр',
      'zones.vertices': 'Вершин',
      'zones.type': 'Тип зони',
      'zones.edit_vertices': 'Редагувати вершини',
      'zones.done': 'Готово',
      'zones.delete_vertex': 'Видалити вершину',
      'zones.rename_vertex': 'Перейменувати вершину',
      'zone.type.hunt': 'Мисливські угіддя',
      'zone.type.forest': 'Лісовий квартал',
      'zone.type.water': 'Аквазона',
      'zone.type.mushroom': 'Грибне місце',
      'zone.type.forbidden': 'Заборонена зона',
      'zone.type.custom': 'Своя зона',
      'downloads.title': 'Завантаження мап',
      'downloads.empty': 'Завантажень ще немає',
      'downloads.active': 'У процесі',
      'downloads.done': 'Готово',
      'downloads.failed': 'Помилка',
      'downloads.pause': 'Пауза',
      'downloads.resume': 'Продовжити',
      'downloads.cancel': 'Скасувати',
      'downloads.tiles': 'тайлів',
      'downloads.size': 'Розмір',
      'download_area.title': 'Завантажити область',
      'download_area.zoom': 'Рівень деталізації',
      'download_area.tiles': 'Тайлів',
      'download_area.size': 'Розмір',
      'download_area.start': 'Почати',
      'download_area.source': 'Джерело',
      'measure.distance': 'Відстань',
      'measure.area': 'Площа',
      'measure.perimeter': 'Периметр',
      'measure.points': 'Точок',
      'measure.save_as_zone': 'Зберегти як зону',
      'measure.clear': 'Очистити',
      'measure.exit': 'Вийти',
      'measure.hint': 'Тапайте, щоб поставити точки',
      'measure.area_hint':
          'Поставте ≥ 3 точок, щоб замкнути полігон',
      'save_zone.title': 'Зберегти як зону',
      'save_zone.name': 'Назва',
      'save_zone.name_hint': 'Напр.: Обхід ділянки',
      'save_zone.type': 'Тип',
      'layers.title': 'Шари мапи',
      'layers.add': 'Додати шар',
      'layers.import_title': 'Імпорт шару',
      'layers.import_xyz': 'XYZ URL',
      'layers.import_file': 'Файл .mbtiles / .sqlitedb',
      'layers.import_xyz_hint':
          'Введіть шаблон URL із заповнювачами {z}, {x}, {y}',
      'layers.import_url': 'URL',
      'layers.import_name': 'Назва шару',
      'layers.opacity': 'Прозорість',
      'lock.title': 'Потрібна автентифікація',
      'lock.subtitle':
          'Біометрія або PIN пристрою — щоб відкрити ваші точки, треки й секретні місця.',
      'lock.unlock': 'Розблокувати',
      'lock.test_now': 'Перевірити зараз',
      'lock.emergency_exit': 'Аварійний вихід',
      'lock.failed_try_again': 'Не розпізнано. Спробуйте знову.',
      'lang.applied': 'Мову застосовано',
      'lang.partial_notice':
          'Обрану мову застосовано до всього інтерфейсу відразу. Довгі тексти (навчання, Wiki) наразі лише російською — інші мови працюють у режимі часткового перекладу.',
      'data.title': 'Дані',
      'backup.title': 'Зашифрований бекап',
      'help.title': 'Допомога',
      'cat.all': 'Усі',
      'cat.fishing': 'Риболовля',
      'cat.hunting': 'Полювання',
      'cat.tourism': 'Туризм',
      'cat.mushrooms': 'Гриби та ягоди',
      'cat.treasure': 'Пошук',
      'cat.infra': 'Інфраструктура',
      'cat.danger': 'Небезпеки',
      'cat.other': 'Інше',
      'points.filter_empty': 'Нічого не знайдено за фільтром',
      'points.filter_empty_sub': 'Змініть фільтр або скиньте пошук.',
      'points.empty_encourage':
          'Створюйте точки на мапі — тапом, голосом або струшуванням телефона. Риба, гриби, джерела, знахідки — усе тут.',
      'points.search_placeholder': 'Шукати точку…',
      'points.favorites_only': 'Лише обрані',
      'points.export_soon': 'Експорт / імпорт — у наступній фазі',
      'sort.newest': 'Спочатку нові',
      'sort.oldest': 'Спочатку старі',
      'sort.title': 'За назвою',
      'sort.category': 'За категорією',
      'tracks.recorded_suffix': 'записано',
      'tracks.count_short': 'шт.',
      'tracks.import_export_tooltip': 'Імпорт / експорт',
      'tracks.recording_prefix': 'Запис',
      'tracks.points_short': 'точок',
      'tracks.to_map': 'На мапу',
      'tracks.empty_title2': 'Треків ще немає',
      'tracks.empty_desc2':
          'Відкрийте мапу та запустіть запис — застосунок збереже весь ваш шлях з адаптивним фільтром шуму.',
      'routes.empty_title': 'Маршрутів поки що немає',
      'routes.empty_desc':
          'Створіть маршрут зі збережених точок або імпортуйте GPX-файл з іншої програми.',
      'routes.import_gpx': 'Імпорт GPX',
      'zones.empty_title2': 'Зон поки що немає',
      'zones.empty_desc2':
          'Увімкніть вимірювання на мапі, обведіть квартал / угіддя / аквазону та збережіть з ім’ям і типом.',
      'zone.note_hint': 'Нотатка',
      'zone.save_changes': 'Зберегти зміни',
      'zone.delete_confirm_title': 'Видалити зону?',
      'zone.delete_confirm_body': 'Дію неможливо скасувати.',
      'zone.vertices_header': 'Вершини',
      'zone.kind_area': 'Полігон',
      'zone.kind_distance': 'Лінія',
      'downloads.delete_confirm': 'Видалити завантаження?',
      'downloads.progress_of': 'з',
      'lock.biometric_sub': 'Прикладіть палець або подивіться в камеру',
      'hud.speed': 'Швидкість',
      'hud.alt': 'Висота',
      'hud.accuracy': 'Точність',
      'hud.searching_signal': 'Пошук сигналу…',
      'hud.recording_badge': 'ЗАПИС',
      'nav_hud.to': 'До цілі',
      'nav_hud.stop': 'Зупинити',
      'quick_layers.no_user_layers': 'Додайте свої шари',
      'new_point.name_required': 'Введіть назву точки',
      'point.no_note': 'Без нотатки',
      'point.show_route': 'Маршрут',
      'point.favorite': 'В обране',
      'point.unfavorite': 'Прибрати з обраного',
      'import.title': 'Імпорт шару',
      'import.xyz_tab': 'XYZ URL',
      'import.file_tab': 'Файл',
      'import.pick_file': 'Обрати файл',
      'import.added': 'Шар додано',
      'import.invalid': 'Некоректний URL або файл',
      'download_area.current_view': 'Поточна область видимості',
      'download_area.zoom_min': 'Мін. zoom',
      'download_area.zoom_max': 'Макс. zoom',
      'download_area.hint':
          'Завантаження тайлів для offline-перегляду. Поки завантажується, можна продовжувати користуватися застосунком.',
    },
  };
}

/// Lookup helpers for enum labels. We keep the enums defined in their
/// respective models (they shouldn't depend on Flutter), so we use these
/// free functions wherever the UI needs a localized label.
extension BaseMapStyleL10n on AppStrings {
  String baseMapLabel(String enumName) => switch (enumName) {
        'schema' => baseMapSchema,
        'satellite' => baseMapSatellite,
        'hybrid' => baseMapHybrid,
        'terrain' => baseMapTerrain,
        'dark' => baseMapDark,
        _ => enumName,
      };

  String orientationLabel(String enumName) => switch (enumName) {
        'auto' => orientationAuto,
        'north' => orientationNorth,
        'course' => orientationCourse,
        _ => enumName,
      };

  String zoneTypeLabel(String enumName) => switch (enumName) {
        'hunt' => zoneTypeHunt,
        'forest' => zoneTypeForest,
        'water' => zoneTypeWater,
        'mushroom' => zoneTypeMushroom,
        'forbidden' => zoneTypeForbidden,
        'custom' => zoneTypeCustom,
        _ => enumName,
      };

  String poiCategoryLabel(String enumName) => switch (enumName) {
        'fishing' => catFishing,
        'hunting' => catHunting,
        'tourism' => catTourism,
        'mushrooms' => catMushrooms,
        'treasure' => catTreasure,
        'infra' => catInfra,
        'danger' => catDanger,
        'other' => catOther,
        _ => enumName,
      };

  String pointsSortLabel(String enumName) => switch (enumName) {
        'newest' => sortNewest,
        'oldest' => sortOldest,
        'title' => sortTitle,
        'category' => sortCategory,
        _ => enumName,
      };

  // Maps ZonePurpose.name (hunting/forestry/aqua/berry/danger/custom) onto
  // the l10n keys so the UI uses the right language.
  String zonePurposeLabel(String enumName) => switch (enumName) {
        'hunting' => zoneTypeHunt,
        'forestry' => zoneTypeForest,
        'aqua' => zoneTypeWater,
        'berry' => zoneTypeMushroom,
        'danger' => zoneTypeForbidden,
        'custom' => zoneTypeCustom,
        _ => enumName,
      };
}
