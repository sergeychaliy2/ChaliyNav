import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/track.dart';

abstract class TracksRepository {
  Future<List<Track>> loadAll();
  Future<void> save(Track track);
  Future<void> delete(String id);
  Future<void> clear();
}

class SharedPrefsTracksRepository implements TracksRepository {
  List<Track>? _cache;

  Future<List<Track>> _read() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.prefsKeyTracks);
    if (raw == null) return _cache = <Track>[];
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(Track.fromJson)
          .toList();
      return _cache = list;
    } catch (_) {
      return _cache = <Track>[];
    }
  }

  Future<void> _writeAll(List<Track> list) async {
    _cache = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefsKeyTracks,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<Track>> loadAll() async {
    final list = await _read();
    return [...list]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<void> save(Track track) async {
    final list = await _read();
    final idx = list.indexWhere((t) => t.id == track.id);
    if (idx >= 0) {
      list[idx] = track;
    } else {
      list.add(track);
    }
    await _writeAll(list);
  }

  @override
  Future<void> delete(String id) async {
    final list = await _read();
    list.removeWhere((t) => t.id == id);
    await _writeAll(list);
  }

  @override
  Future<void> clear() async => _writeAll(const []);
}

class InMemoryTracksRepository implements TracksRepository {
  final Map<String, Track> _store = {};

  @override
  Future<List<Track>> loadAll() async {
    final list = _store.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  @override
  Future<void> save(Track track) async => _store[track.id] = track;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<void> clear() async => _store.clear();
}
