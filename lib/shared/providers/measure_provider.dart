import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/geo_point.dart';
import '../services/compass_service.dart';

/// Runtime state for the on-map measurement tool.
///   - off: nothing to show
///   - distance: a polyline, total length grows with each tap
///   - area: closed polygon, planar area from spherical excess
/// Each vertex can be renamed (e.g. "Северный угол") or dragged.
final measureProvider =
    NotifierProvider<MeasureNotifier, MeasureState>(MeasureNotifier.new);

class MeasureNotifier extends Notifier<MeasureState> {
  @override
  MeasureState build() => const MeasureState.off();

  void enterDistance() => state = state.copyWith(
        mode: MeasureMode.distance,
        editingZoneId: null,
        editingZoneName: null,
      );
  void enterArea() => state = state.copyWith(
        mode: MeasureMode.area,
        editingZoneId: null,
        editingZoneName: null,
      );
  void turnOff() => state = const MeasureState.off();

  /// Start editing a previously-saved zone. The sheet will prefill its name
  /// and, on save, will overwrite the original zone instead of creating a new
  /// one. Works as long as the user doesn't call [enterDistance]/[enterArea]
  /// again (which clears the editing link).
  void loadZoneForEdit({
    required String zoneId,
    required String zoneName,
    required MeasureMode mode,
    required List<LatLng> points,
    Map<int, String> names = const {},
  }) {
    state = MeasureState(
      mode: mode,
      points: points,
      names: names,
      editingZoneId: zoneId,
      editingZoneName: zoneName,
    );
  }

  void addPoint(LatLng p) {
    if (state.mode == MeasureMode.off) return;
    final updated = [...state.points, p];
    state = state.copyWith(points: updated);
  }

  void updatePoint(int index, LatLng p) {
    if (index < 0 || index >= state.points.length) return;
    final list = [...state.points];
    list[index] = p;
    state = state.copyWith(points: list);
  }

  void removePoint(int index) {
    if (index < 0 || index >= state.points.length) return;
    final list = [...state.points]..removeAt(index);
    final names = {...state.names};
    names.remove(index);
    // Shift remaining name keys down by 1 where needed.
    final shifted = <int, String>{};
    names.forEach((k, v) {
      if (k > index) {
        shifted[k - 1] = v;
      } else {
        shifted[k] = v;
      }
    });
    state = state.copyWith(points: list, names: shifted);
  }

  void setName(int index, String name) {
    final names = {...state.names};
    if (name.trim().isEmpty) {
      names.remove(index);
    } else {
      names[index] = name.trim();
    }
    state = state.copyWith(names: names);
  }

  void undo() {
    if (state.points.isEmpty) return;
    final lastIndex = state.points.length - 1;
    removePoint(lastIndex);
  }

  void clear() => state = state.copyWith(
        points: const [],
        names: const {},
        // Keep editing link — user might be just resetting points.
      );
}

enum MeasureMode { off, distance, area }

class MeasureState {
  const MeasureState({
    required this.mode,
    required this.points,
    required this.names,
    this.editingZoneId,
    this.editingZoneName,
  });

  const MeasureState.off()
      : mode = MeasureMode.off,
        points = const [],
        names = const {},
        editingZoneId = null,
        editingZoneName = null;

  final MeasureMode mode;
  final List<LatLng> points;

  /// Optional per-vertex labels keyed by index.
  final Map<int, String> names;

  /// If set — we're editing a previously-saved Zone; save should overwrite.
  final String? editingZoneId;
  final String? editingZoneName;

  bool get isEditing => editingZoneId != null;

  bool get isActive => mode != MeasureMode.off;

  /// Total great-circle length of the polyline in meters.
  double get totalDistanceM {
    if (points.length < 2) return 0;
    double d = 0;
    for (var i = 1; i < points.length; i++) {
      d += Geo.distance(
        GeoPoint(lat: points[i - 1].latitude, lng: points[i - 1].longitude),
        GeoPoint(lat: points[i].latitude, lng: points[i].longitude),
      );
    }
    return d;
  }

  /// Geodesic area in m^2 for [MeasureMode.area].
  double get areaM2 {
    if (mode != MeasureMode.area || points.length < 3) return 0;
    final lat0 =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final coss = math.cos(lat0 * math.pi / 180);
    const r = Geo.earthRadiusM;
    final xs = points.map((p) => p.longitude * math.pi / 180 * r * coss).toList();
    final ys = points.map((p) => p.latitude * math.pi / 180 * r).toList();
    double sum = 0;
    for (var i = 0; i < xs.length; i++) {
      final j = (i + 1) % xs.length;
      sum += xs[i] * ys[j] - xs[j] * ys[i];
    }
    return sum.abs() / 2;
  }

  MeasureState copyWith({
    MeasureMode? mode,
    List<LatLng>? points,
    Map<int, String>? names,
    String? editingZoneId,
    String? editingZoneName,
  }) =>
      MeasureState(
        mode: mode ?? this.mode,
        points: points ?? this.points,
        names: names ?? this.names,
        editingZoneId: editingZoneId ?? this.editingZoneId,
        editingZoneName: editingZoneName ?? this.editingZoneName,
      );
}
