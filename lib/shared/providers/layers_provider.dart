import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/map_layer.dart';
import 'repositories_providers.dart';

final layersProvider =
    AsyncNotifierProvider<LayersNotifier, List<MapLayer>>(LayersNotifier.new);

class LayersNotifier extends AsyncNotifier<List<MapLayer>> {
  @override
  Future<List<MapLayer>> build() async {
    return ref.read(layersRepositoryProvider).loadAll();
  }

  Future<void> add(MapLayer layer) async {
    await ref.read(layersRepositoryProvider).save(layer);
    state = AsyncValue.data([...?state.valueOrNull, layer]);
  }

  Future<void> upsert(MapLayer layer) async {
    await ref.read(layersRepositoryProvider).save(layer);
    final list = [...?state.valueOrNull];
    final i = list.indexWhere((l) => l.id == layer.id);
    if (i >= 0) {
      list[i] = layer;
    } else {
      list.add(layer);
    }
    state = AsyncValue.data(list);
  }

  Future<void> remove(String id) async {
    await ref.read(layersRepositoryProvider).delete(id);
    state = AsyncValue.data(
      (state.valueOrNull ?? []).where((l) => l.id != id).toList(),
    );
  }

  Future<void> setOpacity(String id, double opacity) async {
    final list = state.valueOrNull ?? [];
    final existing = list.firstWhere(
      (l) => l.id == id,
      orElse: () => throw StateError('Layer $id not found'),
    );
    await upsert(existing.copyWith(opacity: opacity));
  }

  Future<void> setVisible(String id, bool visible) async {
    final list = state.valueOrNull ?? [];
    final existing = list.firstWhere(
      (l) => l.id == id,
      orElse: () => throw StateError('Layer $id not found'),
    );
    await upsert(existing.copyWith(visible: visible));
  }
}
