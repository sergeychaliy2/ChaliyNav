import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_layer.dart';

abstract class LayersRepository {
  Future<List<MapLayer>> loadAll();
  Future<void> save(MapLayer layer);
  Future<void> delete(String id);
  Future<void> saveAll(List<MapLayer> layers);
}

/// Persists layer list as JSON blob in SharedPreferences.
class SharedPrefsLayersRepository implements LayersRepository {
  static const _key = 'layers_v1';

  @override
  Future<List<MapLayer>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    // IMPORTANT: callers (save/delete/…) mutate the returned list in-place,
    // so always return a GROWABLE list — returning `const []` caused a
    // "Cannot add to an unmodifiable list" crash right after every first
    // offline-download (see Воронеж 4474/4474 regression).
    if (raw == null) return <MapLayer>[];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(MapLayer.fromJson)
          .toList();
    } catch (_) {
      return <MapLayer>[];
    }
  }

  @override
  Future<void> save(MapLayer layer) async {
    final all = await loadAll();
    final idx = all.indexWhere((l) => l.id == layer.id);
    if (idx >= 0) {
      all[idx] = layer;
    } else {
      all.add(layer);
    }
    await saveAll(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((l) => l.id == id);
    await saveAll(all);
  }

  @override
  Future<void> saveAll(List<MapLayer> layers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(layers.map((l) => l.toJson()).toList()),
    );
  }
}

// Retain old name to avoid breaking call sites in tests or dev scripts.
typedef InMemoryLayersRepository = SharedPrefsLayersRepository;
