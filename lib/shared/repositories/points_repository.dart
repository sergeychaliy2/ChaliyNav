import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/point_of_interest.dart';

/// Abstract contract for persistence of points.
/// Swap implementations (in-memory, SharedPreferences, Isar, remote)
/// without touching the UI.
abstract class PointsRepository {
  Future<List<PointOfInterest>> loadAll();
  Future<void> save(PointOfInterest point);
  Future<void> delete(String id);
  Future<void> clear();
}

/// Persists the full POI list as a JSON blob. Fine for ≤10k points.
/// Phase 4: switch to Isar for large collections + encryption.
class SharedPrefsPointsRepository implements PointsRepository {
  List<PointOfInterest>? _cache;

  Future<List<PointOfInterest>> _read() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefsKeyPoints);
    if (raw == null) {
      return _cache = <PointOfInterest>[];
    }
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(PointOfInterest.fromJson)
          .toList();
      return _cache = list;
    } catch (_) {
      return _cache = <PointOfInterest>[];
    }
  }

  Future<void> _writeAll(List<PointOfInterest> list) async {
    _cache = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefsKeyPoints,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<PointOfInterest>> loadAll() async {
    final list = await _read();
    // Sorted newest first.
    return [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> save(PointOfInterest point) async {
    final list = await _read();
    final idx = list.indexWhere((p) => p.id == point.id);
    if (idx >= 0) {
      list[idx] = point;
    } else {
      list.add(point);
    }
    await _writeAll(list);
  }

  @override
  Future<void> delete(String id) async {
    final list = await _read();
    list.removeWhere((p) => p.id == id);
    await _writeAll(list);
  }

  @override
  Future<void> clear() async {
    await _writeAll(const []);
  }
}

/// Retained for tests / early dev. Not used in prod.
class InMemoryPointsRepository implements PointsRepository {
  final Map<String, PointOfInterest> _store = {};

  @override
  Future<List<PointOfInterest>> loadAll() async {
    final list = _store.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> save(PointOfInterest point) async => _store[point.id] = point;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<void> clear() async => _store.clear();
}
