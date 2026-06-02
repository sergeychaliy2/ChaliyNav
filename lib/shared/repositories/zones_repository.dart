import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/zone.dart';

abstract class ZonesRepository {
  Future<List<Zone>> loadAll();
  Future<void> save(Zone zone);
  Future<void> delete(String id);
  Future<void> clear();
}

class SharedPrefsZonesRepository implements ZonesRepository {
  static const _key = 'zones_v1';
  List<Zone>? _cache;

  Future<List<Zone>> _read() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return _cache = <Zone>[];
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(Zone.fromJson)
          .toList();
      return _cache = list;
    } catch (_) {
      return _cache = <Zone>[];
    }
  }

  Future<void> _writeAll(List<Zone> list) async {
    _cache = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<Zone>> loadAll() async {
    final list = await _read();
    return [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> save(Zone zone) async {
    final list = await _read();
    final idx = list.indexWhere((z) => z.id == zone.id);
    if (idx >= 0) {
      list[idx] = zone;
    } else {
      list.add(zone);
    }
    await _writeAll(list);
  }

  @override
  Future<void> delete(String id) async {
    final list = await _read();
    list.removeWhere((z) => z.id == id);
    await _writeAll(list);
  }

  @override
  Future<void> clear() async => _writeAll(const []);
}
