import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/route_path.dart';

abstract class RoutesRepository {
  Future<List<RoutePath>> loadAll();
  Future<void> save(RoutePath route);
  Future<void> delete(String id);
  Future<void> clear();
}

class SharedPrefsRoutesRepository implements RoutesRepository {
  List<RoutePath>? _cache;

  Future<List<RoutePath>> _read() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefsKeyRoutes);
    if (raw == null) return _cache = <RoutePath>[];
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(RoutePath.fromJson)
          .toList();
      return _cache = list;
    } catch (_) {
      return _cache = <RoutePath>[];
    }
  }

  Future<void> _writeAll(List<RoutePath> list) async {
    _cache = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefsKeyRoutes,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<RoutePath>> loadAll() async {
    final list = await _read();
    return [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> save(RoutePath route) async {
    final list = await _read();
    final idx = list.indexWhere((r) => r.id == route.id);
    if (idx >= 0) {
      list[idx] = route;
    } else {
      list.add(route);
    }
    await _writeAll(list);
  }

  @override
  Future<void> delete(String id) async {
    final list = await _read();
    list.removeWhere((r) => r.id == id);
    await _writeAll(list);
  }

  @override
  Future<void> clear() async => _writeAll(const []);
}

class InMemoryRoutesRepository implements RoutesRepository {
  final Map<String, RoutePath> _store = {};

  @override
  Future<List<RoutePath>> loadAll() async {
    final list = _store.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> save(RoutePath route) async => _store[route.id] = route;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<void> clear() async => _store.clear();
}
