import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/models/poi_category.dart';
import '../../../shared/models/poi_icon_library.dart';
import '../../../shared/models/point_of_interest.dart';
import '../../../shared/providers/layers_provider.dart';
import '../../../shared/providers/location_provider.dart';
import '../../../shared/providers/map_focus_provider.dart';
import '../../../shared/providers/measure_provider.dart';
import '../../../shared/providers/navigation_target_provider.dart';
import '../../../shared/providers/points_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/providers/tracks_provider.dart';
import '../../../shared/services/background_tracking_service.dart';
import '../../../shared/services/cached_tile_provider.dart';
import '../../../shared/services/compass_service.dart';
import '../../../shared/services/tile_prefetcher.dart';
import '../../../shared/services/shake_detector.dart';
import '../../../shared/services/tts_service.dart';
import '../../points/widgets/poi_marker.dart';
import '../widgets/active_layer_slider.dart';
import '../widgets/animated_track_layer.dart';
import '../widgets/download_mini_indicator.dart';
import '../widgets/layers_sheet.dart';
import '../widgets/map_hud.dart';
import 'compass_screen.dart';
import '../widgets/measure_overlay.dart';
import '../widgets/navigation_hud.dart';
import '../widgets/prefetch_mini_indicator.dart';
import '../widgets/quick_layers_bar.dart';
import '../widgets/scale_bar.dart';
import '../widgets/tracks_map_layer.dart';
import '../widgets/user_layers_stack.dart';
import '../widgets/user_marker.dart';
import '../widgets/zones_map_layer.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  late final MapController _map;
  bool _centeredOnce = false;

  ShakeDetector? _shake;
  double _shakeThreshold = 15.0;
  final TtsService _tts = TtsService();
  Timer? _navTtsTimer;
  Timer? _uiRefreshTimer;

  /// Shown after a long-press: a glowing placeholder marker the user can
  /// tap ("Here") to create a POI at that exact lat/lng.
  LatLng? _pendingPoint;

  /// Follow-me cycle: none → follow → follow+rotate-by-heading → none…
  ///
  /// Starts in [_FollowMode.follow] so the map tracks the user from app
  /// launch (Yandex Navigator-style). A free-pan drops to [none], and
  /// after [autoFollowAfterIdleSec] seconds of no touches the timer
  /// re-engages follow automatically.
  _FollowMode _followMode = _FollowMode.follow;

  /// Last time the user actively interacted with the map (pan/zoom/tap).
  /// Used by the idle auto-follow timer so the camera snaps back to track-up
  /// after the user has stopped fiddling.
  DateTime _lastUserInteraction = DateTime.now();

  /// Set to true when auto-follow engages, so we can cleanly roll it back
  /// on the next user touch (rather than asking the user to manually tap
  /// the center button to turn it off). Initial true because we start
  /// auto-followed.
  bool _autoFollowEngaged = true;

  /// SharedPreferences key for the last-known camera position. Restored on
  /// cold start so the user opens the map where they left off — not at
  /// the default Moscow location, which might be outside their offline
  /// coverage and result in an empty gray screen when there's no network.
  static const _camKey = 'map_camera_v1';

  /// Debounce for persisting camera state — we get ~60 map events per
  /// second during a pan, and each one writing to SharedPreferences
  /// would be wasteful. Persist at most every 2 s.
  DateTime _lastCamSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// Pending camera to restore once the MapController is attached —
  /// can't move() the camera before the first FlutterMap.build().
  LatLng? _pendingRestoreCenter;
  double? _pendingRestoreZoom;

  /// Persistent-caching tile provider for the base map, memoised per
  /// [BaseMapStyle]. Recreated only when the user switches base style —
  /// the map screen rebuilds many times a second (location + 1 Hz tick),
  /// and minting a fresh provider (and HTTP client) on every build would
  /// churn connections needlessly. Disposed when the style changes or the
  /// screen is torn down.
  CachedTileProvider? _baseProvider;
  BaseMapStyle? _baseProviderStyle;

  /// Return the cached base-map tile provider for [style], (re)building it
  /// only when the style actually changed. Every tile it serves is written
  /// to disk so areas browsed online stay visible offline.
  /// Debounce for the "save what I'm looking at" prefetch — fires once the
  /// camera has been still for [_prefetchIdle]. While the user pans/zooms
  /// (or follow-me keeps re-centring on GPS) the timer keeps resetting, so
  /// we never prefetch mid-movement, only after the map settles.
  Timer? _prefetchTimer;
  static const _prefetchIdle = Duration(milliseconds: 1500);

  /// Centre of the area we last kicked a prefetch for — used to skip
  /// re-firing while effectively parked in one spot.
  LatLng? _lastPrefetchCenter;

  CachedTileProvider _baseTileProviderFor(BaseMapStyle style) {
    final existing = _baseProvider;
    if (existing != null && _baseProviderStyle == style) return existing;
    // No dispose of the old one needed: CachedTileProvider owns no
    // per-instance resources — its HTTP client is shared and long-lived —
    // so a superseded provider is simply garbage-collected.
    final provider = CachedTileProvider(sourceKey: style.tileUrl);
    _baseProvider = provider;
    _baseProviderStyle = style;
    return provider;
  }

  /// (Re)arm the idle timer. Called on every camera event; the prefetch
  /// only runs once movement has actually stopped.
  void _schedulePrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(_prefetchIdle, _runPrefetchIfNeeded);
  }

  /// Once the map has settled, download the visible area across the user's
  /// configured zoom range into the persistent cache — so zooming in here
  /// offline later is sharp, not an upscale. Honors the master toggle, the
  /// Wi-Fi-only guard, and a small stationary-dedupe.
  Future<void> _runPrefetchIfNeeded() async {
    if (!mounted) return;
    final s = ref.read(settingsProvider).valueOrNull;
    if (s == null || !s.tilePrefetchEnabled) return;

    // Which base styles to save offline (map / satellite / hybrid / …).
    // Deduped to URL templates — satellite & hybrid share one endpoint.
    final sources = s.tilePrefetchStyles.map((e) => e.tileUrl).toSet().toList();
    if (sources.isEmpty) return;

    final LatLng center;
    final LatLngBounds bounds;
    try {
      center = _map.camera.center;
      bounds = _map.camera.visibleBounds;
    } catch (_) {
      return; // camera not ready yet
    }

    // Skip if we're basically where we last prefetched (parked / tiny pan).
    final last = _lastPrefetchCenter;
    if (last != null &&
        const Distance().as(LengthUnit.Meter, last, center) < 60) {
      return;
    }

    // Wi-Fi-only guard: never spend mobile data unless the user opted in.
    if (s.tilePrefetchWifiOnly) {
      try {
        final conn = await Connectivity().checkConnectivity();
        final onFreeLink = conn.contains(ConnectivityResult.wifi) ||
            conn.contains(ConnectivityResult.ethernet);
        if (!onFreeLink) return;
      } catch (_) {
        return; // can't tell → err on the safe side
      }
      if (!mounted) return;
    }

    _lastPrefetchCenter = center;
    ref.read(tilePrefetchProvider.notifier).request(
          sources: sources,
          north: bounds.north,
          south: bounds.south,
          west: bounds.west,
          east: bounds.east,
          minZoom: s.tilePrefetchMinZoom,
          maxZoom: s.tilePrefetchMaxZoom,
        );
  }

  @override
  void initState() {
    super.initState();
    _map = MapController();
    _loadSavedCamera();
  }

  /// Read last-known camera from SharedPreferences. Don't block the
  /// first frame — use `addPostFrameCallback` so the MapController has
  /// been attached before we move it.
  Future<void> _loadSavedCamera() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_camKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final lat = (j['lat'] as num?)?.toDouble();
      final lng = (j['lng'] as num?)?.toDouble();
      final zoom = (j['zoom'] as num?)?.toDouble();
      if (lat == null || lng == null || zoom == null) return;
      if (!mounted) return;
      _pendingRestoreCenter = LatLng(lat, lng);
      _pendingRestoreZoom = zoom;
      // Apply after the next frame so MapController is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = _pendingRestoreCenter;
        final z = _pendingRestoreZoom;
        if (c == null || z == null) return;
        try {
          _map.move(c, z);
          // Mark "centered" so the first GPS fix doesn't jump the camera
          // back to the user's live location, overriding the restore.
          _centeredOnce = true;
        } catch (_) {}
        _pendingRestoreCenter = null;
        _pendingRestoreZoom = null;
      });
    } catch (_) {
      // No persisted position or corrupt JSON — ignore, start at defaults.
    }
  }

  /// Called from onMapEvent for any user-driven or animation camera
  /// change. Debounced — only writes every 2 s at most.
  void _savePositionDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastCamSave).inMilliseconds < 2000) return;
    _lastCamSave = now;
    _persistCameraNow();
  }

  Future<void> _persistCameraNow() async {
    try {
      final c = _map.camera.center;
      final z = _map.camera.zoom;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _camKey,
        jsonEncode({'lat': c.latitude, 'lng': c.longitude, 'zoom': z}),
      );
    } catch (_) {/* best effort, never blocks the UI */}
  }

  @override
  void dispose() {
    // Final flush so the camera as-of-close is saved even if the user
    // didn't pan in the last 2 s.
    // ignore: unawaited_futures
    _persistCameraNow();
    _map.dispose();
    _shake?.stop();
    _tts.dispose();
    _navTtsTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _prefetchTimer?.cancel();
    super.dispose();
  }

  /// Throttle for notification pushes — we don't need to update the
  /// OS notification every second, every ~3s is plenty and cheaper.
  DateTime _lastNotifPush = DateTime.fromMillisecondsSinceEpoch(0);

  void _ensureUiRefresh(bool needed) {
    // Runs a 1-Hz tick that triggers a rebuild so elapsed time stays
    // live and the recording-notification text updates. We do NOT
    // auto-re-engage follow-me here any more — pulling the camera
    // back after 5 s of idle interrupts every workflow that needs
    // the user to look at a different part of the map (drawing a
    // quartal, measuring distances, inspecting a faraway feature).
    // Re-centering on the user is now strictly manual via the
    // location button.
    if (needed) {
      _uiRefreshTimer ??=
          Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (!mounted) return;
        _maybePushRecordingNotif();
        setState(() {});
      });
    } else {
      _uiRefreshTimer?.cancel();
      _uiRefreshTimer = null;
    }
  }

  /// While a track is being recorded, push live distance + elapsed time
  /// into the persistent notification so the user can see progress
  /// without opening the app (Yandex-navigator style).
  ///
  /// Respects user's settings:
  ///  - `recordingNotifEnabled` — master switch. If off, we fall back
  ///    to a minimal "Запись трека" text (can't fully hide the
  ///    notification on Android — foreground service requires one).
  ///  - `recordingNotifShow*` — per-field toggles for what ends up in
  ///    the "content" line: time, distance, speed, point count.
  void _maybePushRecordingNotif() {
    final rec = ref.read(trackRecordingProvider);
    if (!rec.isRecording) return;
    final now = DateTime.now();
    if (now.difference(_lastNotifPush).inMilliseconds < 3000) return;
    _lastNotifPush = now;

    final s = ref.read(settingsProvider).valueOrNull;
    if (s == null || !s.recordingNotifEnabled) {
      BackgroundTrackingService.updateProgress(
        distanceText: 'Запись идёт',
        elapsedText: '',
      );
      return;
    }

    final elapsed = _formatElapsed(rec.elapsed);
    final distance = Formatters.distance(rec.distanceM);

    // Build the "content" line from enabled fields.
    final parts = <String>[];
    if (s.recordingNotifShowDistance) parts.add(distance);
    if (s.recordingNotifShowSpeed) {
      parts.add(Formatters.speed(rec.avgSpeedMps));
    }
    if (s.recordingNotifShowPoints) {
      parts.add('${rec.points.length} точек');
    }
    // If user turned EVERYTHING off but kept "enabled", fall back to
    // showing distance so there's at least something informative.
    if (parts.isEmpty) parts.add(distance);

    BackgroundTrackingService.updateProgress(
      distanceText: parts.join(' · '),
      elapsedText: s.recordingNotifShowTime ? elapsed : '',
    );
  }

  /// HH:MM:SS for long rides, MM:SS under an hour. Keeps the notification
  /// line compact.
  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _onUserMapInteraction() {
    _lastUserInteraction = DateTime.now();
    if (_autoFollowEngaged) {
      // User took over — drop out of follow mode cleanly.
      _autoFollowEngaged = false;
      setState(() => _followMode = _FollowMode.none);
      try {
        _map.rotate(0);
      } catch (_) {}
    }
  }

  // Auto-re-engagement of follow-me after idle was removed: it
  // ripped the camera out of whatever the user was doing every five
  // seconds, which made tasks like quartal drawing or distance
  // measurement effectively unusable far from one's GPS position.
  // Re-centering on the user is now manual via the location button.

  void _syncShakeDetector({
    required bool enabled,
    required double threshold,
    required int cooldownMs,
  }) {
    // Only recreate the detector if its parameters actually changed.
    if (_shake != null && _shake!.isActive) {
      if (!enabled) {
        _shake!.stop();
        return;
      }
      if (_shakeThreshold == threshold) return;
      _shake!.stop();
    }
    if (!enabled) return;
    _shakeThreshold = threshold;
    _shake = ShakeDetector(
      threshold: threshold,
      cooldown: Duration(milliseconds: cooldownMs),
      onShake: _onShake,
    )..start();
  }

  Future<void> _onShake() async {
    final loc = await ref.read(lastKnownLocationProvider.future);
    if (loc == null || !mounted) return;
    final l10n = AppStrings.of(context);
    final icon = PoiIconLibrary.defaultFor(PoiCategory.other);
    final point = PointOfInterest(
      id: const Uuid().v4(),
      title: '${l10n.pointsDefaultName} ${_time()}',
      coord: loc,
      iconId: icon.id,
      createdAt: DateTime.now(),
      meta: PoiMeta(altitude: loc.altitude),
    );
    await ref.read(pointsProvider.notifier).add(point);
    if (!mounted) return;
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings?.voiceGuideEnabled ?? true) {
      _tts.speak(l10n.pointsSaved, interrupt: true);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.waving_hand_outlined,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${l10n.mapShakeSaved} · ${point.title}'),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _time() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  void _scheduleNavTts() {
    _navTtsTimer?.cancel();
    _navTtsTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final target = ref.read(navigationTargetProvider);
      final loc = ref.read(locationStreamProvider).valueOrNull;
      final settings = ref.read(settingsProvider).valueOrNull;
      if (target == null ||
          loc == null ||
          !(settings?.voiceGuideEnabled ?? true)) return;
      final d = Geo.distance(loc, target.coord);
      final brng = Geo.bearing(loc, target.coord);
      final card = Geo.cardinal(brng);
      final dText = d < 1000
          ? '${d.round()} метров'
          : '${(d / 1000).toStringAsFixed(1)} километра';
      final hint = settings?.voiceShortHints ?? true
          ? '$dText, $card'
          : 'До цели $dText на $card, азимут ${brng.round()} градусов';
      _tts.speak(hint,
          cooldown: Duration(seconds: settings?.voiceCooldownSec ?? 15));
    });
  }

  void _animateTo(LatLng target, {double? zoom}) {
    // Guard against access before FlutterMap has built once.
    final LatLng begin;
    final double beginZoom;
    try {
      begin = _map.camera.center;
      beginZoom = _map.camera.zoom;
    } catch (_) {
      _map.move(target, zoom ?? AppConstants.defaultZoom);
      return;
    }
    final destZoom = zoom ?? beginZoom;
    final latAnim = Tween<double>(begin: begin.latitude, end: target.latitude);
    final lngAnim = Tween<double>(begin: begin.longitude, end: target.longitude);
    final zoomAnim = Tween<double>(begin: beginZoom, end: destZoom);
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    controller.addListener(() {
      _map.move(
        LatLng(latAnim.evaluate(curved), lngAnim.evaluate(curved)),
        zoomAnim.evaluate(curved),
      );
    });
    controller.forward().whenComplete(controller.dispose);
  }

  Future<void> _centerOnMe() async {
    // 3-state cycle:
    //   none → follow (pan to me, no rotation)
    //   follow → follow+rotate (track-up by compass)
    //   follow+rotate → none (stop following)
    final next = switch (_followMode) {
      _FollowMode.none => _FollowMode.follow,
      _FollowMode.follow => _FollowMode.followWithHeading,
      _FollowMode.followWithHeading => _FollowMode.none,
    };

    if (next == _FollowMode.none) {
      setState(() => _followMode = next);
      try {
        _map.rotate(0);
      } catch (_) {}
      return;
    }

    final loc = await ref.read(lastKnownLocationProvider.future);
    if (!mounted) return;
    if (loc == null) {
      final l10n = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mapNoGps)),
      );
      return;
    }
    double z = 16;
    try {
      z = math.max(_map.camera.zoom, 16);
    } catch (_) {}
    _animateTo(loc.latLng, zoom: z);

    if (next == _FollowMode.follow) {
      // Pan only, keep map oriented north.
      try {
        _map.rotate(0);
      } catch (_) {}
    }
    setState(() => _followMode = next);
  }

  Future<void> _toggleRecording() async {
    final l10n = AppStrings.of(context);
    final rec = ref.read(trackRecordingProvider);
    if (rec.isRecording) {
      final color = rec.colorValue;
      final track = ref.read(trackRecordingProvider.notifier).stopAndBuild();
      if (track.points.length >= 2) {
        await ref.read(tracksProvider.notifier).add(track);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.mapRecSaved}: ${track.points.length} · '
                    '${Formatters.distance(track.distanceM)} · '
                    '${Formatters.duration(track.duration)}',
                  ),
                ),
              ],
            ),
            backgroundColor: Color(color),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: l10n.commonOpen,
              textColor: Colors.white,
              onPressed: () => context.go('/tracks'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.mapRecStoppedShort),
          ),
        );
      }
      await BackgroundTrackingService.stop();
    } else {
      final color = ref.read(nextTrackColorProvider);
      ref.read(trackRecordingProvider.notifier).start(colorValue: color);
      await ensureBackgroundLocation();
      await BackgroundTrackingService.start();
      if (!mounted) return;

      // Auto-engage follow-mode so the map tracks the user as they move
      // — matches Yandex Navigator UX. The user can cycle it off with
      // the center button if they want free pan.
      setState(() {
        _followMode = _FollowMode.followWithHeading;
        _autoFollowEngaged = true;
        _lastUserInteraction = DateTime.now();
      });
      final loc = await ref.read(lastKnownLocationProvider.future);
      if (mounted && loc != null) {
        try {
          _animateTo(loc.latLng,
              zoom: math.max(_map.camera.zoom, 16.0));
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapRecStarted),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addPointHere() async {
    var loc = await ref.read(lastKnownLocationProvider.future);
    if (loc == null) {
      try {
        final c = _map.camera.center;
        loc = GeoPoint(lat: c.latitude, lng: c.longitude, timestamp: DateTime.now());
      } catch (_) {
        loc = GeoPoint(
          lat: AppConstants.defaultLat,
          lng: AppConstants.defaultLng,
          timestamp: DateTime.now(),
        );
      }
    }
    if (!mounted) return;
    context.push('/points/new', extra: loc);
  }

  void _openLayers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LayersSheet(),
    );
  }

  void _onMapTap(TapPosition _, LatLng point) {
    final m = ref.read(measureProvider);
    if (m.isActive) {
      ref.read(measureProvider.notifier).addPoint(point);
      return;
    }
    // Tap outside the pending-marker clears it.
    if (_pendingPoint != null) {
      setState(() => _pendingPoint = null);
    }
  }

  void _onMapLongPress(TapPosition _, LatLng point) {
    // Long-press places a pending marker the user can convert to a POI.
    setState(() => _pendingPoint = point);
  }

  void _confirmPendingPoint() {
    final p = _pendingPoint;
    if (p == null) return;
    final geo = GeoPoint(
      lat: p.latitude,
      lng: p.longitude,
      timestamp: DateTime.now(),
    );
    setState(() => _pendingPoint = null);
    context.push('/points/new', extra: geo);
  }

  void _openMeasureMenu() {
    final m = ref.read(measureProvider);
    if (m.isActive) {
      ref.read(measureProvider.notifier).turnOff();
      return;
    }
    final l10n = AppStrings.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.straighten,
                    color: AppColors.accentCyan),
                title: Text(l10n.mapMeasureDistance),
                subtitle: Text(l10n.mapMeasureDistanceHint),
                onTap: () {
                  ref.read(measureProvider.notifier).enterDistance();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.crop_square,
                    color: AppColors.accentAmber),
                title: Text(l10n.mapMeasureArea),
                subtitle: Text(l10n.mapMeasureAreaHint),
                onTap: () {
                  ref.read(measureProvider.notifier).enterArea();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationStreamProvider).valueOrNull;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final points = ref.watch(pointsProvider).valueOrNull ?? const [];
    // Pass ALL user layers (including invisible ones) down to
    // UserLayersStack — it handles visibility per-type internally:
    //  * online (tileUrl)    — unmounts when hidden (saves network)
    //  * offline (mbtiles)   — stays mounted with Opacity=0 (instant
    //                          toggle, SQLite handle stays warm)
    //  * image overlays      — unmounts when hidden
    // Pre-filtering here would defeat the caching in UserLayersStack.
    final userLayers = ref.watch(layersProvider).valueOrNull ?? const [];
    final rec = ref.watch(trackRecordingProvider);

    // Feed the recorder as we get new GPS fixes + update follow-me.
    ref.listen(locationStreamProvider, (prev, next) {
      final newLoc = next.valueOrNull;
      if (newLoc == null) return;
      _accumulateRecording(newLoc);
      if (!_centeredOnce) {
        _centeredOnce = true;
        _map.move(newLoc.latLng, 15);
      }
      // Follow-me: pan (and maybe rotate) the map to keep the user centred.
      if (_followMode != _FollowMode.none) {
        try {
          _map.move(newLoc.latLng, _map.camera.zoom);
        } catch (_) {}
      }
    });

    // Continuous rotation for "track-up" mode — compass stream triggers rotation.
    if (_followMode == _FollowMode.followWithHeading) {
      final heading = ref.watch(compassHeadingProvider).valueOrNull;
      if (heading != null) {
        try {
          _map.rotate(-heading);
        } catch (_) {}
      }
    }

    // Keep a 1-Hz tick alive while any time-dependent UI is on screen
    // (recording badge, follow-me, idle auto-follow).
    _ensureUiRefresh(true);

    // Sync shake detector with settings.
    _syncShakeDetector(
      enabled: settings?.shakeToSavePoint ?? true,
      threshold: settings?.shakeSensitivity ?? 15.0,
      cooldownMs: settings?.shakeCooldownMs ?? 1500,
    );

    // React to focus requests from list screens ("Show on map").
    ref.listen<FocusRequest?>(mapFocusRequestProvider, (prev, next) {
      if (next == null) return;
      _animateTo(next.target, zoom: next.zoom);
      // Reset after consuming.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mapFocusRequestProvider.notifier).state = null;
      });
    });

    // Start/stop periodic TTS hints based on navigation target.
    final l10nTts = AppStrings.of(context);
    ref.listen(navigationTargetProvider, (prev, next) {
      if (next != null && _navTtsTimer == null) {
        _scheduleNavTts();
        if (settings?.voiceGuideEnabled ?? true) {
          _tts.speak('${l10nTts.mapNavStartTo} ${next.title}', interrupt: true);
        }
      }
      if (next == null) {
        _navTtsTimer?.cancel();
        _navTtsTimer = null;
        _tts.stop();
      }
    });

    final baseStyle = settings?.baseMapStyle ?? BaseMapStyle.schema;
    final showPoints = settings?.showPointsOnMap ?? true;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: const LatLng(
                AppConstants.defaultLat,
                AppConstants.defaultLng,
              ),
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              backgroundColor: AppColors.bgDeep,
              onTap: _onMapTap,
              onLongPress: _onMapLongPress,
              onMapEvent: (event) {
                // Any user-driven camera event resets the idle timer.
                final src = event.source;
                const userSources = <MapEventSource>{
                  MapEventSource.dragStart,
                  MapEventSource.onDrag,
                  MapEventSource.dragEnd,
                  MapEventSource.flingAnimationController,
                  MapEventSource.multiFingerGestureStart,
                  MapEventSource.onMultiFinger,
                  MapEventSource.multiFingerEnd,
                  MapEventSource.scrollWheel,
                  MapEventSource.doubleTap,
                  MapEventSource.doubleTapHold,
                };
                if (userSources.contains(src)) {
                  _onUserMapInteraction();
                }
                // Persist camera on every move — debounced to at most
                // once per 2 s. Restored on next cold start so the user
                // doesn't open at Moscow-default when their offline pack
                // covers e.g. Voronezh.
                _savePositionDebounced();
                // Arm the "save what I'm looking at" prefetch — runs only
                // after the camera settles (see _schedulePrefetch).
                _schedulePrefetch();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: baseStyle.tileUrl,
                userAgentPackageName: 'com.chaliy.nav',
                // Persistent disk cache: tiles browsed online are stored
                // forever, so the base map keeps working offline for any
                // area the user has already visited.
                tileProvider: _baseTileProviderFor(baseStyle),
                maxNativeZoom: 19,
              ),
              // Stacked user layers (XYZ URL, MBTiles) with per-layer opacity.
              UserLayersStack(layers: userLayers),
              // Active (current) recording path — animated glow + pulsing head.
              AnimatedRecordingTrack(
                points: rec.points.map((p) => p.latLng).toList(),
                color: Color(rec.colorValue),
                width: (settings?.trackWidth ?? 4.0) + 1,
              ),
              // Saved zones (polygons + polylines) under POIs.
              const ZonesMapLayer(),
              // User-selected saved tracks (toggled from TrackDetailScreen).
              const TracksMapLayer(),
              // Measure tool overlay (polyline + vertex dots).
              MeasureMapLayer(mapController: _map),
              // Navigation route line — from current location to target.
              _navRouteLayer(location),
              // POI markers — clustered when zoomed out, labelled when zoomed in.
              if (showPoints && points.isNotEmpty)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 55,
                    disableClusteringAtZoom: 15,
                    size: const Size(44, 60),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(40),
                    rotate: true,
                    markers: [
                      for (final p in points)
                        Marker(
                          key: ValueKey('poi_${p.id}'),
                          point: p.coord.latLng,
                          width: 130,
                          height: 78,
                          alignment: Alignment.bottomCenter,
                          rotate: true,
                          child: GestureDetector(
                            onTap: () => context.push('/points/${p.id}'),
                            child: PoiMarkerPin(
                              icon: p.icon,
                              size: 40,
                              label: p.title,
                              showLabel: true,
                            ),
                          ),
                        ),
                    ],
                    builder: (ctx, list) {
                      // Cluster color = dominant category color among children.
                      final cats = <PoiCategory, int>{};
                      for (final m in list) {
                        final id = (m.key as ValueKey?)?.value as String?;
                        if (id == null) continue;
                        final pid = id.replaceFirst('poi_', '');
                        final p = points
                            .where((x) => x.id == pid)
                            .firstOrNull;
                        if (p == null) continue;
                        cats[p.category] = (cats[p.category] ?? 0) + 1;
                      }
                      final dominant = cats.entries
                          .fold<MapEntry<PoiCategory, int>?>(
                            null,
                            (max, e) =>
                                max == null || e.value > max.value ? e : max,
                          );
                      final color = dominant?.key.color ?? AppColors.primary;
                      return PoiClusterBadge(
                        count: list.length,
                        color: color,
                      );
                    },
                  ),
                ),
              // Pending long-press placeholder.
              if (_pendingPoint != null)
                MarkerLayer(
                  rotate: true,
                  markers: [
                    Marker(
                      point: _pendingPoint!,
                      width: 150,
                      height: 90,
                      alignment: Alignment.topCenter,
                      rotate: true,
                      child: _PendingMarker(
                        label: AppStrings.of(context).mapHereLabel,
                        onConfirm: _confirmPendingPoint,
                      ),
                    ),
                  ],
                ),
              // Current location — heading cone + pulsing dot (Yandex-style).
              if (location != null)
                MarkerLayer(
                  rotate: true,
                  markers: [
                    Marker(
                      point: location.latLng,
                      width: 80,
                      height: 80,
                      rotate: true,
                      child: const UserLocationMarker(),
                    ),
                  ],
                ),
            ],
          ),

          // Top HUD
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                MapTopHud(
                  location: location,
                  showSpeed: settings?.showSpeedometer ?? true,
                  showAccuracy: settings?.showAccuracy ?? true,
                  showCompass: settings?.showCompass ?? true,
                  compassExpanded: settings?.compassExpanded ?? false,
                  onCompassTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CompassScreen(),
                    ),
                  ),
                ),
                const Spacer(),
                const QuickLayersBar(),
              ],
            ),
          ),

          // Expanded compass badge — its own fixed slot under the
          // top HUD pill row on the left edge. Lives outside the
          // pill row on purpose: when many HUD pills are on, the
          // inline expanded pill got squeezed off-screen, and a
          // 4-digit value like "-179" used to widen the row and
          // shove the speed / accuracy capsules around. Rendered
          // only when the user opted into the expanded mode in
          // Settings → Display.
          if ((settings?.showCompass ?? true) &&
              (settings?.compassExpanded ?? false))
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 12,
              child: CompassExpandedBadge(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CompassScreen(),
                  ),
                ),
              ),
            ),

          // Navigation HUD — appears only when a target is selected.
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 12,
            right: 12,
            child: NavigationHud(currentLocation: location),
          ),

          // Measure panel (top center, shown only when measuring).
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 0,
            right: 0,
            child: const Center(child: MeasurePanel()),
          ),

          // Scale bar — pushed all the way down to the bottom edge,
          // sitting just above the system nav bar / SafeArea inset.
          // Used to live at +100 alongside the FAB column, but that
          // placed it visually inside the cluster of action buttons,
          // making it hard to read against busy map content. The
          // user wanted it lower, in the otherwise-empty strip above
          // the bottom tab bar.
          Positioned(
            left: 12,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            child: MapScaleBar(controller: _map),
          ),

          // Download mini-indicator — sits just above the scale bar.
          Positioned(
            left: 12,
            bottom: MediaQuery.of(context).padding.bottom + 48,
            child: const DownloadMiniIndicator(),
          ),

          // Tile-prefetch indicator — shows while the visible area is being
          // saved to the offline cache. Parked just above the download pill.
          Positioned(
            left: 12,
            bottom: MediaQuery.of(context).padding.bottom + 84,
            child: const PrefetchMiniIndicator(),
          ),

          // Active layer opacity slider — left edge, vertical.
          // Sits BELOW the expanded compass badge slot so the two
          // never overlap. When the badge is hidden the slider can
          // safely creep up; when the badge is on, top is pushed
          // past its bottom edge plus a small gap. The right edge
          // is occupied by the FAB column, so the left strip is
          // the only place either control fits.
          Positioned(
            left: 12,
            top: MediaQuery.of(context).padding.top +
                70 +
                ((settings?.showCompass ?? true) &&
                        (settings?.compassExpanded ?? false)
                    ? CompassExpandedBadge.height + 12
                    : 0),
            child: const ActiveLayerSlider(),
          ),

          // Bottom-right action column
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 100,
            child: MapActionsColumn(
              onLayers: _openLayers,
              onCenter: _centerOnMe,
              onRecord: _toggleRecording,
              onAddPoint: _addPointHere,
              onMeasure: _openMeasureMenu,
              isRecording: rec.isRecording,
              measureActive: ref.watch(measureProvider).isActive,
              followMode: _followMode.index,
            ),
          ),

          // Recording badge — parked just above the bottom nav bar (Scaffold
          // has extendBody: true, body reaches the screen bottom, nav bar
          // renders on top of the body in its ~(58 + safeArea) px slot).
          // The badge itself includes a Stop button so the user doesn't
          // have to reach for the action column on the right.
          if (rec.isRecording)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 64,
              child: Center(
                child: RecordingBadge(
                  distanceM: rec.distanceM,
                  elapsed: rec.elapsed,
                  color: Color(rec.colorValue),
                  onStop: _toggleRecording,
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
            ),
        ],
      ),
    );
  }

  void _accumulateRecording(GeoPoint newLoc) {
    final rec = ref.read(trackRecordingProvider);
    if (!rec.isRecording || rec.isPaused) return;
    final settings = ref.read(settingsProvider).valueOrNull;
    final minDist = settings?.trackMinDistance ?? 5.0;
    final accThreshold = settings?.gpsAccuracyThreshold ?? 20.0;

    if ((newLoc.accuracy ?? 100) > accThreshold) return;

    if (rec.points.isEmpty) {
      ref.read(trackRecordingProvider.notifier).addPoint(newLoc);
      return;
    }
    final last = rec.points.last;
    final d = const Distance().as(
      LengthUnit.Meter,
      last.latLng,
      newLoc.latLng,
    );
    if (d >= minDist) {
      ref.read(trackRecordingProvider.notifier).addPoint(newLoc, addedMeters: d);
    }
  }
}

Widget _navRouteLayer(GeoPoint? location) {
  // Rendered via a ConsumerWidget wrapper below so we can watch the target.
  return _NavRouteLine(location: location);
}

class _NavRouteLine extends ConsumerWidget {
  const _NavRouteLine({required this.location});
  final GeoPoint? location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(navigationTargetProvider);
    if (target == null || location == null) return const SizedBox.shrink();
    final color = target.icon.color;
    return Stack(
      children: [
        PolylineLayer(
          polylines: [
            Polyline(
              points: [location!.latLng, target.coord.latLng],
              color: color.withValues(alpha: 0.3),
              strokeWidth: 10,
            ),
          ],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [location!.latLng, target.coord.latLng],
              color: color,
              strokeWidth: 3.5,
              pattern:
                  StrokePattern.dashed(segments: const [14, 8]),
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingMarker extends StatelessWidget {
  const _PendingMarker({required this.label, required this.onConfirm});
  final String label;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onConfirm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBright,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBright.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 3,
          height: 14,
          color: AppColors.primaryBright,
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBright,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBright.withValues(alpha: 0.6),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Old _Me marker replaced by UserLocationMarker (see widgets/user_marker.dart).

/// How the camera currently follows the user's location.
enum _FollowMode {
  /// Free pan — the user drags the map manually.
  none,

  /// Camera pans to GPS, but keeps north up.
  follow,

  /// Camera pans AND rotates so the compass heading is always "up" ("track-up").
  followWithHeading,
}
