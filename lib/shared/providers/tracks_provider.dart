import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../models/geo_point.dart';
import '../models/track.dart';
import 'repositories_providers.dart';

final tracksProvider =
    AsyncNotifierProvider<TracksNotifier, List<Track>>(TracksNotifier.new);

class TracksNotifier extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    return ref.read(tracksRepositoryProvider).loadAll();
  }

  Future<void> add(Track track) async {
    await ref.read(tracksRepositoryProvider).save(track);
    state = AsyncValue.data([track, ...state.valueOrNull ?? []]);
  }

  Future<void> upsert(Track track) async {
    await ref.read(tracksRepositoryProvider).save(track);
    final list = [...?state.valueOrNull];
    final idx = list.indexWhere((t) => t.id == track.id);
    if (idx >= 0) {
      list[idx] = track;
    } else {
      list.insert(0, track);
    }
    state = AsyncValue.data(list);
  }

  Future<void> remove(String id) async {
    await ref.read(tracksRepositoryProvider).delete(id);
    state = AsyncValue.data(
      (state.valueOrNull ?? []).where((t) => t.id != id).toList(),
    );
  }
}

/// Current recording state — lives above the Track list, updated live.
///
/// Also mirrored to SharedPreferences (every point + every 5 s) under
/// `_persistKey` so an accidental force-close, OS kill or crash during
/// recording doesn't lose the track. On the next app launch the
/// [recoverInterruptedRecording] helper picks up the mirror, promotes
/// it to a saved [Track] in the normal list, and clears the mirror.
final trackRecordingProvider =
    NotifierProvider<TrackRecordingNotifier, TrackRecordingState>(
  TrackRecordingNotifier.new,
);

const _persistKey = 'active_recording_v1';

class TrackRecordingNotifier extends Notifier<TrackRecordingState> {
  Timer? _periodicFlush;

  @override
  TrackRecordingState build() {
    ref.onDispose(() => _periodicFlush?.cancel());
    return const TrackRecordingState.idle();
  }

  void start({required int colorValue, String? title}) {
    state = TrackRecordingState(
      isRecording: true,
      isPaused: false,
      startedAt: DateTime.now(),
      colorValue: colorValue,
      title: title ??
          'Трек ${DateTime.now().toLocal().toString().substring(0, 16)}',
      points: const [],
      distanceM: 0,
    );
    _persist();
    // Belt-and-braces flush every 5 s even if no new points came
    // (e.g. stationary user, bad signal) — so finishedAt-style data
    // stays fresh in the mirror.
    _periodicFlush?.cancel();
    _periodicFlush =
        Timer.periodic(const Duration(seconds: 5), (_) => _persist());
  }

  void pause() {
    if (!state.isRecording) return;
    state = state.copyWith(isPaused: true);
    _persist();
  }

  void resume() {
    if (!state.isRecording) return;
    state = state.copyWith(isPaused: false);
    _persist();
  }

  void addPoint(GeoPoint p, {double addedMeters = 0}) {
    if (!state.isRecording || state.isPaused) return;
    state = state.copyWith(
      points: [...state.points, p],
      distanceM: state.distanceM + addedMeters,
    );
    _persist();
  }

  Track stopAndBuild({String? title}) {
    final finished = DateTime.now();
    final started = state.startedAt ?? finished;
    final durationSec =
        finished.difference(started).inSeconds.clamp(1, 1 << 30);
    final avg = state.distanceM / durationSec;
    final maxSpeed = state.points
        .map((p) => p.speed ?? 0)
        .fold<double>(0, (a, b) => b > a ? b : a);

    final track = Track(
      id: 't-${started.millisecondsSinceEpoch}',
      title: title ?? state.title,
      points: state.points,
      startedAt: started,
      finishedAt: finished,
      colorValue: state.colorValue,
      distanceM: state.distanceM,
      avgSpeedMps: avg,
      maxSpeedMps: maxSpeed,
    );
    state = const TrackRecordingState.idle();
    _periodicFlush?.cancel();
    _periodicFlush = null;
    _clearPersisted();
    return track;
  }

  void cancel() {
    state = const TrackRecordingState.idle();
    _periodicFlush?.cancel();
    _periodicFlush = null;
    _clearPersisted();
  }

  /// Serialize current state to SharedPreferences so a sudden death
  /// (force-close, OS OOM-kill, crash) leaves enough info behind for
  /// [recoverInterruptedRecording] to turn it into a saved Track on
  /// the next launch.
  ///
  /// Writes run asynchronously and are fire-and-forget — we don't
  /// stall the recording loop waiting for disk.
  Future<void> _persist() async {
    if (!state.isRecording) {
      await _clearPersisted();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        'title': state.title,
        'startedAt': state.startedAt?.toIso8601String(),
        'colorValue': state.colorValue,
        'distanceM': state.distanceM,
        'isPaused': state.isPaused,
        'points':
            state.points.map((p) => p.toJson()).toList(growable: false),
      };
      await prefs.setString(_persistKey, jsonEncode(json));
    } catch (_) {
      // Best-effort — if disk is full / prefs are unavailable, we
      // still don't want to kill the recording loop.
    }
  }

  Future<void> _clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_persistKey);
    } catch (_) {}
  }
}

/// Check SharedPreferences for an interrupted recording from a previous
/// session. If found, convert it to a saved [Track] (via the
/// [tracksProvider]) and clear the mirror. Call this once at app start.
///
/// Returns the recovered track (or null if none was found / it was too
/// small to be useful).
Future<Track?> recoverInterruptedRecording(ProviderContainer container) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_persistKey);
    if (raw == null) return null;
    await prefs.remove(_persistKey);

    final j = jsonDecode(raw) as Map<String, dynamic>;
    final pointsJson = (j['points'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    if (pointsJson.length < 2) return null;

    final points = pointsJson.map(GeoPoint.fromJson).toList();
    final startedAt = j['startedAt'] != null
        ? DateTime.tryParse(j['startedAt'] as String)
        : null;
    final started = startedAt ?? points.first.timestamp ?? DateTime.now();
    final finished = points.last.timestamp ?? DateTime.now();
    final distanceM = (j['distanceM'] as num?)?.toDouble() ?? 0.0;
    final durationSec =
        finished.difference(started).inSeconds.clamp(1, 1 << 30);
    final avg = distanceM / durationSec;
    final maxSpeed = points
        .map((p) => p.speed ?? 0)
        .fold<double>(0, (a, b) => b > a ? b : a);

    final recovered = Track(
      id: 't-${started.millisecondsSinceEpoch}-r',
      title:
          '${j['title'] as String? ?? 'Трек'} (восстановлен)',
      points: points,
      startedAt: started,
      finishedAt: finished,
      colorValue: (j['colorValue'] as num?)?.toInt() ??
          AppColors.trackColors.first.toARGB32(),
      distanceM: distanceM,
      avgSpeedMps: avg,
      maxSpeedMps: maxSpeed,
      note: 'Автоматически сохранён после неожиданного выхода из '
          'приложения во время записи.',
    );
    await container.read(tracksProvider.notifier).add(recovered);
    return recovered;
  } catch (_) {
    return null;
  }
}

class TrackRecordingState {
  const TrackRecordingState({
    required this.isRecording,
    required this.isPaused,
    required this.points,
    required this.distanceM,
    required this.colorValue,
    required this.title,
    this.startedAt,
  });

  const TrackRecordingState.idle()
      : isRecording = false,
        isPaused = false,
        points = const [],
        distanceM = 0,
        startedAt = null,
        colorValue = 0xFF2ECC71,
        title = '';

  final bool isRecording;
  final bool isPaused;
  final List<GeoPoint> points;
  final double distanceM;
  final DateTime? startedAt;
  final int colorValue;
  final String title;

  Duration get elapsed => startedAt == null
      ? Duration.zero
      : DateTime.now().difference(startedAt!);

  double get avgSpeedMps {
    final sec = elapsed.inSeconds;
    return sec <= 0 ? 0 : distanceM / sec;
  }

  TrackRecordingState copyWith({
    bool? isRecording,
    bool? isPaused,
    List<GeoPoint>? points,
    double? distanceM,
    DateTime? startedAt,
    int? colorValue,
    String? title,
  }) =>
      TrackRecordingState(
        isRecording: isRecording ?? this.isRecording,
        isPaused: isPaused ?? this.isPaused,
        points: points ?? this.points,
        distanceM: distanceM ?? this.distanceM,
        startedAt: startedAt ?? this.startedAt,
        colorValue: colorValue ?? this.colorValue,
        title: title ?? this.title,
      );
}

/// Convenience: next unused track color (cycles through palette).
final nextTrackColorProvider = Provider<int>((ref) {
  final tracks = ref.watch(tracksProvider).valueOrNull ?? [];
  final used = tracks.map((t) => t.colorValue).toSet();
  for (final c in AppColors.trackColors) {
    if (!used.contains(c.toARGB32())) return c.toARGB32();
  }
  return AppColors.trackColors[tracks.length % AppColors.trackColors.length]
      .toARGB32();
});
