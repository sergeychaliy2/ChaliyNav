import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Lightweight accelerometer-based shake detector.
/// Uses low-pass filter to strip gravity, then measures peak acceleration
/// magnitude. A shake fires when magnitude exceeds `threshold` and enough
/// time has passed since last fire (debounce via `cooldown`).
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = 15.0,
    this.cooldown = const Duration(milliseconds: 1500),
  });

  final VoidCallback onShake;
  final double threshold;
  final Duration cooldown;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isActive => _sub != null;

  void start() {
    if (_sub != null) return;
    _sub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) {
      final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (magnitude < threshold) return;
      final now = DateTime.now();
      if (now.difference(_lastFire) < cooldown) return;
      _lastFire = now;
      onShake();
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Update threshold without restarting the subscription.
  /// (Since threshold is `final`, callers must reconstruct the detector to
  ///  change it — kept simple for Phase 3. Settings screen will recreate
  ///  the detector when its values change.)
}

typedef VoidCallback = void Function();
