import 'dart:math' as math;

import '../models/geo_point.dart';

/// Simple 2D Kalman filter tuned for GPS smoothing.
///
/// Reduces position jitter from jammed/weak GNSS (common in RU urban
/// environments) while still allowing real movement — including **vehicle
/// speeds** (the previous processNoiseMps=3.0 / maxJumpMeters=150 defaults
/// effectively froze the marker at highway speed, which caused a user to
/// drive 2 km before the dot moved 100 m).
///
/// Not a full-blown 6-state model — just position + variance, which is enough
/// for a hobbyist tracker and keeps CPU free.
class GpsKalmanFilter {
  GpsKalmanFilter({
    /// Baseline process noise used when the user is stationary or
    /// walking (< ~2 m/s). Low value → strong smoothing of GPS jitter,
    /// so a pedestrian's marker doesn't wiggle inside the accuracy
    /// circle.
    this.minProcessNoiseMps = 2.0,

    /// Upper cap on process noise used at vehicle speeds. High value →
    /// filter trusts new measurements almost entirely, so the marker
    /// tracks the car/bike without lag.
    this.maxProcessNoiseMps = 50.0,

    /// Multiplier applied to the raw GPS speed to derive the current
    /// process noise: `clamp(speed * scale, min, max)`. Scale 2 means
    /// "expect motion to deviate by ~2× current speed between fixes".
    this.processNoiseSpeedScale = 2.0,

    /// Time-based outlier speed cap. A fix is rejected only if getting
    /// there from the last accepted point would require > [maxSpeedMps].
    /// 80 m/s ≈ 288 km/h — faster than any ground vehicle, so we still
    /// catch GPS spikes but never reject a legitimate fix.
    this.maxSpeedMps = 80.0,

    /// After this many consecutive rejections we assume the filter's
    /// idea of "last position" is stale (tunnel exit, train, flight…)
    /// and force-adopt the next fix instead of freezing forever.
    this.rejectionsBeforeReset = 3,
  });

  /// Process noise floor (m/s) — applies when standing / walking.
  final double minProcessNoiseMps;

  /// Process noise ceiling (m/s) — applies at highway speeds.
  final double maxProcessNoiseMps;

  /// Multiplier from raw speed to process noise.
  final double processNoiseSpeedScale;

  /// Maximum plausible ground speed, m/s (used for outlier rejection).
  final double maxSpeedMps;

  /// Consecutive-rejection threshold before we force-reset.
  final int rejectionsBeforeReset;

  double _lat = 0;
  double _lng = 0;
  double _variance = -1; // -1 = not initialised yet
  DateTime? _lastTs;
  int _consecutiveRejections = 0;

  bool get isInitialised => _variance >= 0;

  /// Feed a raw GPS fix, get back a smoothed one. Returns `null` if the
  /// fix is rejected as an outlier (caller should just ignore it, or fall
  /// back to the raw value).
  GeoPoint? process(GeoPoint raw) {
    final accuracy = raw.accuracy ?? 50.0;
    final ts = raw.timestamp ?? DateTime.now();

    // First fix — just adopt it.
    if (!isInitialised) {
      _lat = raw.lat;
      _lng = raw.lng;
      _variance = accuracy * accuracy;
      _lastTs = ts;
      _consecutiveRejections = 0;
      return raw;
    }

    // Time-aware outlier rejection: what's the implied ground speed?
    final prev = GeoPoint(lat: _lat, lng: _lng);
    final jumpMeters = _distance(prev, raw);
    final dtSec = math.max(
      0.1,
      ts.difference(_lastTs ?? ts).inMilliseconds / 1000.0,
    );
    final impliedSpeed = jumpMeters / dtSec;

    if (impliedSpeed > maxSpeedMps) {
      _consecutiveRejections++;
      // Stuck-fix recovery: after N rejections the "last position" is
      // almost certainly stale. Adopt the new fix so the marker unfreezes.
      if (_consecutiveRejections >= rejectionsBeforeReset) {
        _lat = raw.lat;
        _lng = raw.lng;
        _variance = accuracy * accuracy;
        _lastTs = ts;
        _consecutiveRejections = 0;
        return raw;
      }
      return null;
    }
    _consecutiveRejections = 0;

    // Adaptive process noise: small when slow, large when fast.
    //
    // Walking (≈1.5 m/s): noise ~ 3 → strong smoothing, k ≈ 0.4.
    // City (≈10 m/s):     noise ~ 20 → tracks responsively, k ≈ 0.8.
    // Highway (≈30 m/s):  noise ~ 50 → near-full trust, k ≈ 0.96.
    // Stationary:         raw.speed is near 0, so noise = minProcessNoise
    //                      and the filter smooths GPS wander heavily.
    final rawSpeed = (raw.speed ?? 0).abs();
    final adaptiveNoise = (rawSpeed * processNoiseSpeedScale)
        .clamp(minProcessNoiseMps, maxProcessNoiseMps);

    // Predict: add process noise proportional to time since last fix.
    _variance += dtSec * adaptiveNoise * adaptiveNoise;

    // Update: blend raw measurement by Kalman gain.
    final measurementVariance = accuracy * accuracy;
    final k = _variance / (_variance + measurementVariance);
    _lat += k * (raw.lat - _lat);
    _lng += k * (raw.lng - _lng);
    _variance *= (1 - k);
    _lastTs = ts;

    final smoothedAccuracy = math.sqrt(_variance);
    return GeoPoint(
      lat: _lat,
      lng: _lng,
      altitude: raw.altitude,
      accuracy: smoothedAccuracy,
      speed: raw.speed,
      heading: raw.heading,
      timestamp: ts,
    );
  }

  void reset() {
    _variance = -1;
    _lastTs = null;
    _consecutiveRejections = 0;
  }

  static double _distance(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = (b.lat - a.lat) * math.pi / 180.0;
    final dLng = (b.lng - a.lng) * math.pi / 180.0;
    final la1 = a.lat * math.pi / 180.0;
    final la2 = b.lat * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(la1) *
            math.cos(la2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
