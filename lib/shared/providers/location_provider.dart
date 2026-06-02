import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/geo_point.dart';
import '../services/kalman_filter.dart';

/// Streams the device location for the map ("where am I") — no foreground
/// notification here. Starts/stops as Riverpod listeners come and go.
///
/// Background tracking during trip recording is handled separately by
/// [recordingLocationStreamProvider] below (which DOES set a foreground
/// notification) + [BackgroundTrackingService]. Splitting keeps the map
/// from spawning a persistent "Track is being recorded" notification on
/// first launch, before the user has even pressed Record.
final locationStreamProvider =
    StreamProvider.autoDispose<GeoPoint?>((ref) async* {
  final permission = await _ensurePermission();
  if (!permission) {
    yield null;
    return;
  }

  final filter = GpsKalmanFilter();

  // Merges two sources into one stream:
  //  1. The GPS position stream (every fix, no distanceFilter so we still
  //     tick when standing still — this is why the speedometer used to
  //     freeze at "53.7 км/ч" after the user stopped: the old
  //     distanceFilter: 2 silenced the stream when motion stopped, so the
  //     HUD kept displaying the last in-motion speed).
  //  2. A 2-second heartbeat: if we've been silent for >5s we re-emit the
  //     last fix with speed=0 so the HUD visibly zeroes out.
  final controller = StreamController<GeoPoint?>();
  GeoPoint? last;
  DateTime lastEmit = DateTime.now();

  final posSub = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      // distanceFilter: 0 → emit every fix the platform produces, even
      // when the user barely moves. Crucial for "Yandex Navigator"-feel
      // responsiveness and for the speedometer to drop to 0 on stopping.
      distanceFilter: 0,
    ),
  ).listen((p) {
    final fix = GeoPoint(
      lat: p.latitude,
      lng: p.longitude,
      altitude: p.altitude,
      accuracy: p.accuracy,
      speed: p.speed,
      heading: p.heading,
      timestamp: p.timestamp,
    );
    final smoothed = filter.process(fix) ?? fix;
    last = smoothed;
    lastEmit = DateTime.now();
    controller.add(smoothed);
  });

  final heartbeat =
      Stream.periodic(const Duration(seconds: 2)).listen((_) {
    final l = last;
    if (l == null) return;
    // If the platform has been silent for 5+ seconds, force-zero the
    // speed so a stopped car no longer shows the last cruising speed.
    if (DateTime.now().difference(lastEmit).inSeconds >= 5) {
      final zeroed = GeoPoint(
        lat: l.lat,
        lng: l.lng,
        altitude: l.altitude,
        accuracy: l.accuracy,
        speed: 0,
        heading: l.heading,
        timestamp: DateTime.now(),
      );
      controller.add(zeroed);
    }
  });

  ref.onDispose(() {
    posSub.cancel();
    heartbeat.cancel();
    controller.close();
  });

  yield* controller.stream;
});

/// One-shot location (for "center on me" action).
final lastKnownLocationProvider = FutureProvider<GeoPoint?>((ref) async {
  final permission = await _ensurePermission();
  if (!permission) return null;
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return GeoPoint(
      lat: p.latitude,
      lng: p.longitude,
      altitude: p.altitude,
      accuracy: p.accuracy,
      speed: p.speed,
      heading: p.heading,
      timestamp: p.timestamp,
    );
  } catch (_) {
    return null;
  }
});

Future<bool> _ensurePermission() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) return false;

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  return perm == LocationPermission.whileInUse ||
      perm == LocationPermission.always;
}

/// Request background location separately when the user starts track recording.
/// On Android 10+ this is a distinct "Always" permission.
Future<bool> ensureBackgroundLocation() async {
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.whileInUse) {
    perm = await Geolocator.requestPermission();
  }
  return perm == LocationPermission.always;
}
