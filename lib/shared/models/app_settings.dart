import 'map_layer.dart';

/// User-facing configuration of the app. Serialised to SharedPreferences
/// via SettingsRepository.
class AppSettings {
  const AppSettings({
    // Track recording
    this.trackMinDistance = 5.0,
    this.trackMinInterval = 2,
    this.trackColorIndex = 0,
    this.trackWidth = 4.0,
    this.gpsAccuracyThreshold = 30.0,

    // Display
    this.showSpeedometer = true,
    this.showCompass = true,
    this.compassExpanded = false,
    this.showScaleBar = true,
    this.showAccuracy = true,
    this.keepScreenOn = true,
    this.screenAutoDim = true,
    this.showTaskPanel = true,
    this.mapOrientation = MapOrientation.auto,

    // Voice guide
    this.voiceGuideEnabled = true,
    this.voiceShortHints = true,
    this.voiceStepMeters = 100,
    this.voiceCooldownSec = 15,

    // Points on map
    this.showPointsOnMap = true,
    this.pointLabelSize = PointLabelSize.medium,
    this.pointRingDistance = true,

    // Shake detection.
    //
    // Off by default: enabling this spawns a POI on every threshold-
    // exceeding acceleration event, and at sensitivity=15 even normal
    // driving bumps trigger it. Users who want it can turn it on in
    // Settings → Сохранение встряхиванием.
    this.shakeToSavePoint = false,
    // Raised from 15.0 → 25.0 so even when the feature is enabled it
    // requires a deliberate shake, not just a pothole.
    this.shakeSensitivity = 25.0,
    this.shakeCooldownMs = 1500,
    this.voiceMemoOnSave = false,

    // Auto follow-me after idle (seconds). 0 = off.
    // Lowered 15 → 5 so the map snaps back to the user quickly after a
    // free-pan, matching Yandex Navigator feel.
    this.autoFollowAfterIdleSec = 5,

    // Base map
    this.baseMapStyle = BaseMapStyle.schema,

    // Offline tile prefetch — while browsing online, auto-download the
    // visible area across a zoom range into the persistent cache, so
    // zooming in offline later isn't a blurry upscale. Wi-Fi-only by
    // default so it never silently eats mobile data; flip that off for
    // "download everywhere I look". Range is clamped to 3..19.
    this.tilePrefetchEnabled = true,
    this.tilePrefetchWifiOnly = true,
    this.tilePrefetchMinZoom = 12,
    this.tilePrefetchMaxZoom = 16,
    // Which base-map styles to prefetch. Empty = nothing prefetched. The
    // live cache still always keeps whatever style is on screen. Note
    // satellite + hybrid resolve to the same Esri imagery URL, so picking
    // both downloads one set of tiles.
    this.tilePrefetchStyles = const {
      BaseMapStyle.schema,
      BaseMapStyle.satellite,
    },

    // Security
    this.appLockEnabled = false,
    this.biometricLock = false,
    this.secretCategoryLocked = false,

    // Metadata
    this.captureAltitude = true,
    this.capturePressure = false,
    this.captureMoonPhase = false,
    this.captureWeather = false,

    // Recording notification (persistent widget on status bar + lock screen
    // during an active track recording). See BackgroundTrackingService.
    this.recordingNotifEnabled = true,
    this.recordingNotifShowTime = true,
    this.recordingNotifShowDistance = true,
    this.recordingNotifShowSpeed = false,
    this.recordingNotifShowPoints = false,
  });

  // Track recording
  final double trackMinDistance;
  final int trackMinInterval;
  final int trackColorIndex;
  final double trackWidth;
  final double gpsAccuracyThreshold;

  // Display
  final bool showSpeedometer;
  final bool showCompass;

  /// When true, the on-map compass HUD shows a compact spinning rose
  /// under the numeric heading. False = the simple "127° СВ" pill.
  final bool compassExpanded;

  final bool showScaleBar;
  final bool showAccuracy;
  final bool keepScreenOn;
  final bool screenAutoDim;
  final bool showTaskPanel;
  final MapOrientation mapOrientation;

  // Voice guide
  final bool voiceGuideEnabled;
  final bool voiceShortHints;
  final int voiceStepMeters;
  final int voiceCooldownSec;

  // Points on map
  final bool showPointsOnMap;
  final PointLabelSize pointLabelSize;
  final bool pointRingDistance;

  // Shake detection
  final bool shakeToSavePoint;
  final double shakeSensitivity;
  final int shakeCooldownMs;
  final bool voiceMemoOnSave;

  /// If the user doesn't interact with the map for this many seconds, the
  /// map will automatically switch to "follow + track-up" mode. 0 disables.
  final int autoFollowAfterIdleSec;

  // Base map
  final BaseMapStyle baseMapStyle;

  // Offline tile prefetch
  final bool tilePrefetchEnabled;
  final bool tilePrefetchWifiOnly;
  final int tilePrefetchMinZoom;
  final int tilePrefetchMaxZoom;
  final Set<BaseMapStyle> tilePrefetchStyles;

  // Security
  final bool appLockEnabled;
  final bool biometricLock;
  final bool secretCategoryLocked;

  // Metadata
  final bool captureAltitude;
  final bool capturePressure;
  final bool captureMoonPhase;
  final bool captureWeather;

  // Recording notification (status bar / lock-screen widget).
  final bool recordingNotifEnabled;
  final bool recordingNotifShowTime;
  final bool recordingNotifShowDistance;
  final bool recordingNotifShowSpeed;
  final bool recordingNotifShowPoints;

  AppSettings copyWith({
    double? trackMinDistance,
    int? trackMinInterval,
    int? trackColorIndex,
    double? trackWidth,
    double? gpsAccuracyThreshold,
    bool? showSpeedometer,
    bool? showCompass,
    bool? compassExpanded,
    bool? showScaleBar,
    bool? showAccuracy,
    bool? keepScreenOn,
    bool? screenAutoDim,
    bool? showTaskPanel,
    MapOrientation? mapOrientation,
    bool? voiceGuideEnabled,
    bool? voiceShortHints,
    int? voiceStepMeters,
    int? voiceCooldownSec,
    bool? showPointsOnMap,
    PointLabelSize? pointLabelSize,
    bool? pointRingDistance,
    bool? shakeToSavePoint,
    double? shakeSensitivity,
    int? shakeCooldownMs,
    bool? voiceMemoOnSave,
    int? autoFollowAfterIdleSec,
    BaseMapStyle? baseMapStyle,
    bool? tilePrefetchEnabled,
    bool? tilePrefetchWifiOnly,
    int? tilePrefetchMinZoom,
    int? tilePrefetchMaxZoom,
    Set<BaseMapStyle>? tilePrefetchStyles,
    bool? appLockEnabled,
    bool? biometricLock,
    bool? secretCategoryLocked,
    bool? captureAltitude,
    bool? capturePressure,
    bool? captureMoonPhase,
    bool? captureWeather,
    bool? recordingNotifEnabled,
    bool? recordingNotifShowTime,
    bool? recordingNotifShowDistance,
    bool? recordingNotifShowSpeed,
    bool? recordingNotifShowPoints,
  }) =>
      AppSettings(
        trackMinDistance: trackMinDistance ?? this.trackMinDistance,
        trackMinInterval: trackMinInterval ?? this.trackMinInterval,
        trackColorIndex: trackColorIndex ?? this.trackColorIndex,
        trackWidth: trackWidth ?? this.trackWidth,
        gpsAccuracyThreshold: gpsAccuracyThreshold ?? this.gpsAccuracyThreshold,
        showSpeedometer: showSpeedometer ?? this.showSpeedometer,
        showCompass: showCompass ?? this.showCompass,
        compassExpanded: compassExpanded ?? this.compassExpanded,
        showScaleBar: showScaleBar ?? this.showScaleBar,
        showAccuracy: showAccuracy ?? this.showAccuracy,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        screenAutoDim: screenAutoDim ?? this.screenAutoDim,
        showTaskPanel: showTaskPanel ?? this.showTaskPanel,
        mapOrientation: mapOrientation ?? this.mapOrientation,
        voiceGuideEnabled: voiceGuideEnabled ?? this.voiceGuideEnabled,
        voiceShortHints: voiceShortHints ?? this.voiceShortHints,
        voiceStepMeters: voiceStepMeters ?? this.voiceStepMeters,
        voiceCooldownSec: voiceCooldownSec ?? this.voiceCooldownSec,
        showPointsOnMap: showPointsOnMap ?? this.showPointsOnMap,
        pointLabelSize: pointLabelSize ?? this.pointLabelSize,
        pointRingDistance: pointRingDistance ?? this.pointRingDistance,
        shakeToSavePoint: shakeToSavePoint ?? this.shakeToSavePoint,
        shakeSensitivity: shakeSensitivity ?? this.shakeSensitivity,
        shakeCooldownMs: shakeCooldownMs ?? this.shakeCooldownMs,
        voiceMemoOnSave: voiceMemoOnSave ?? this.voiceMemoOnSave,
        autoFollowAfterIdleSec:
            autoFollowAfterIdleSec ?? this.autoFollowAfterIdleSec,
        baseMapStyle: baseMapStyle ?? this.baseMapStyle,
        tilePrefetchEnabled: tilePrefetchEnabled ?? this.tilePrefetchEnabled,
        tilePrefetchWifiOnly: tilePrefetchWifiOnly ?? this.tilePrefetchWifiOnly,
        tilePrefetchMinZoom: tilePrefetchMinZoom ?? this.tilePrefetchMinZoom,
        tilePrefetchMaxZoom: tilePrefetchMaxZoom ?? this.tilePrefetchMaxZoom,
        tilePrefetchStyles: tilePrefetchStyles ?? this.tilePrefetchStyles,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        biometricLock: biometricLock ?? this.biometricLock,
        secretCategoryLocked: secretCategoryLocked ?? this.secretCategoryLocked,
        captureAltitude: captureAltitude ?? this.captureAltitude,
        capturePressure: capturePressure ?? this.capturePressure,
        captureMoonPhase: captureMoonPhase ?? this.captureMoonPhase,
        captureWeather: captureWeather ?? this.captureWeather,
        recordingNotifEnabled:
            recordingNotifEnabled ?? this.recordingNotifEnabled,
        recordingNotifShowTime:
            recordingNotifShowTime ?? this.recordingNotifShowTime,
        recordingNotifShowDistance:
            recordingNotifShowDistance ?? this.recordingNotifShowDistance,
        recordingNotifShowSpeed:
            recordingNotifShowSpeed ?? this.recordingNotifShowSpeed,
        recordingNotifShowPoints:
            recordingNotifShowPoints ?? this.recordingNotifShowPoints,
      );

  /// Parse the persisted list of style names back into a set, silently
  /// dropping any unknown entries. A missing key falls back to the default
  /// (map + satellite); an explicit empty list is honored as "none".
  static Set<BaseMapStyle> _parseStyles(dynamic raw) {
    if (raw is! List) {
      return const {BaseMapStyle.schema, BaseMapStyle.satellite};
    }
    final out = <BaseMapStyle>{};
    for (final e in raw) {
      for (final b in BaseMapStyle.values) {
        if (b.name == e) out.add(b);
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'trackMinDistance': trackMinDistance,
        'trackMinInterval': trackMinInterval,
        'trackColorIndex': trackColorIndex,
        'trackWidth': trackWidth,
        'gpsAccuracyThreshold': gpsAccuracyThreshold,
        'showSpeedometer': showSpeedometer,
        'showCompass': showCompass,
        'compassExpanded': compassExpanded,
        'showScaleBar': showScaleBar,
        'showAccuracy': showAccuracy,
        'keepScreenOn': keepScreenOn,
        'screenAutoDim': screenAutoDim,
        'showTaskPanel': showTaskPanel,
        'mapOrientation': mapOrientation.name,
        'voiceGuideEnabled': voiceGuideEnabled,
        'voiceShortHints': voiceShortHints,
        'voiceStepMeters': voiceStepMeters,
        'voiceCooldownSec': voiceCooldownSec,
        'showPointsOnMap': showPointsOnMap,
        'pointLabelSize': pointLabelSize.name,
        'pointRingDistance': pointRingDistance,
        'shakeToSavePoint': shakeToSavePoint,
        'shakeSensitivity': shakeSensitivity,
        'shakeCooldownMs': shakeCooldownMs,
        'voiceMemoOnSave': voiceMemoOnSave,
        'autoFollowAfterIdleSec': autoFollowAfterIdleSec,
        'baseMapStyle': baseMapStyle.name,
        'tilePrefetchEnabled': tilePrefetchEnabled,
        'tilePrefetchWifiOnly': tilePrefetchWifiOnly,
        'tilePrefetchMinZoom': tilePrefetchMinZoom,
        'tilePrefetchMaxZoom': tilePrefetchMaxZoom,
        'tilePrefetchStyles': tilePrefetchStyles.map((e) => e.name).toList(),
        'appLockEnabled': appLockEnabled,
        'biometricLock': biometricLock,
        'secretCategoryLocked': secretCategoryLocked,
        'captureAltitude': captureAltitude,
        'capturePressure': capturePressure,
        'captureMoonPhase': captureMoonPhase,
        'captureWeather': captureWeather,
        'recordingNotifEnabled': recordingNotifEnabled,
        'recordingNotifShowTime': recordingNotifShowTime,
        'recordingNotifShowDistance': recordingNotifShowDistance,
        'recordingNotifShowSpeed': recordingNotifShowSpeed,
        'recordingNotifShowPoints': recordingNotifShowPoints,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        trackMinDistance: (j['trackMinDistance'] as num?)?.toDouble() ?? 5.0,
        trackMinInterval: j['trackMinInterval'] as int? ?? 2,
        trackColorIndex: j['trackColorIndex'] as int? ?? 0,
        trackWidth: (j['trackWidth'] as num?)?.toDouble() ?? 4.0,
        gpsAccuracyThreshold:
            (j['gpsAccuracyThreshold'] as num?)?.toDouble() ?? 30.0,
        showSpeedometer: j['showSpeedometer'] as bool? ?? true,
        showCompass: j['showCompass'] as bool? ?? true,
        compassExpanded: j['compassExpanded'] as bool? ?? false,
        showScaleBar: j['showScaleBar'] as bool? ?? true,
        showAccuracy: j['showAccuracy'] as bool? ?? true,
        keepScreenOn: j['keepScreenOn'] as bool? ?? true,
        screenAutoDim: j['screenAutoDim'] as bool? ?? true,
        showTaskPanel: j['showTaskPanel'] as bool? ?? true,
        mapOrientation: MapOrientation.values.firstWhere(
          (m) => m.name == j['mapOrientation'],
          orElse: () => MapOrientation.auto,
        ),
        voiceGuideEnabled: j['voiceGuideEnabled'] as bool? ?? true,
        voiceShortHints: j['voiceShortHints'] as bool? ?? true,
        voiceStepMeters: j['voiceStepMeters'] as int? ?? 100,
        voiceCooldownSec: j['voiceCooldownSec'] as int? ?? 15,
        showPointsOnMap: j['showPointsOnMap'] as bool? ?? true,
        pointLabelSize: PointLabelSize.values.firstWhere(
          (p) => p.name == j['pointLabelSize'],
          orElse: () => PointLabelSize.medium,
        ),
        pointRingDistance: j['pointRingDistance'] as bool? ?? true,
        shakeToSavePoint: j['shakeToSavePoint'] as bool? ?? false,
        shakeSensitivity: (j['shakeSensitivity'] as num?)?.toDouble() ?? 25.0,
        shakeCooldownMs: j['shakeCooldownMs'] as int? ?? 1500,
        voiceMemoOnSave: j['voiceMemoOnSave'] as bool? ?? false,
        autoFollowAfterIdleSec: j['autoFollowAfterIdleSec'] as int? ?? 5,
        baseMapStyle: BaseMapStyle.values.firstWhere(
          (b) => b.name == j['baseMapStyle'],
          orElse: () => BaseMapStyle.schema,
        ),
        tilePrefetchEnabled: j['tilePrefetchEnabled'] as bool? ?? true,
        tilePrefetchWifiOnly: j['tilePrefetchWifiOnly'] as bool? ?? true,
        tilePrefetchMinZoom:
            (j['tilePrefetchMinZoom'] as int? ?? 12).clamp(3, 19),
        tilePrefetchMaxZoom:
            (j['tilePrefetchMaxZoom'] as int? ?? 16).clamp(3, 19),
        tilePrefetchStyles: _parseStyles(j['tilePrefetchStyles']),
        appLockEnabled: j['appLockEnabled'] as bool? ?? false,
        biometricLock: j['biometricLock'] as bool? ?? false,
        secretCategoryLocked: j['secretCategoryLocked'] as bool? ?? false,
        captureAltitude: j['captureAltitude'] as bool? ?? true,
        capturePressure: j['capturePressure'] as bool? ?? false,
        captureMoonPhase: j['captureMoonPhase'] as bool? ?? false,
        captureWeather: j['captureWeather'] as bool? ?? false,
        recordingNotifEnabled: j['recordingNotifEnabled'] as bool? ?? true,
        recordingNotifShowTime: j['recordingNotifShowTime'] as bool? ?? true,
        recordingNotifShowDistance:
            j['recordingNotifShowDistance'] as bool? ?? true,
        recordingNotifShowSpeed: j['recordingNotifShowSpeed'] as bool? ?? false,
        recordingNotifShowPoints:
            j['recordingNotifShowPoints'] as bool? ?? false,
      );
}

enum MapOrientation {
  auto,
  north,
  course;

  String get label => switch (this) {
        MapOrientation.auto => 'Авто',
        MapOrientation.north => 'На север',
        MapOrientation.course => 'По курсу',
      };
}

enum PointLabelSize {
  small,
  medium,
  large;

  String get label => switch (this) {
        PointLabelSize.small => 'Маленький',
        PointLabelSize.medium => 'Средний',
        PointLabelSize.large => 'Большой',
      };
}
