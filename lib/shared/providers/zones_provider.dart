import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/zone.dart';
import '../repositories/zones_repository.dart';

final zonesRepositoryProvider = Provider<ZonesRepository>(
  (_) => SharedPrefsZonesRepository(),
);

final zonesProvider =
    AsyncNotifierProvider<ZonesNotifier, List<Zone>>(ZonesNotifier.new);

class ZonesNotifier extends AsyncNotifier<List<Zone>> {
  @override
  Future<List<Zone>> build() {
    return ref.read(zonesRepositoryProvider).loadAll();
  }

  Future<void> add(Zone zone) async {
    await ref.read(zonesRepositoryProvider).save(zone);
    state = AsyncValue.data([zone, ...?state.valueOrNull]);
  }

  Future<void> upsert(Zone zone) async {
    await ref.read(zonesRepositoryProvider).save(zone);
    final list = [...?state.valueOrNull];
    final idx = list.indexWhere((z) => z.id == zone.id);
    if (idx >= 0) {
      list[idx] = zone;
    } else {
      list.insert(0, zone);
    }
    state = AsyncValue.data(list);
  }

  Future<void> remove(String id) async {
    await ref.read(zonesRepositoryProvider).delete(id);
    state = AsyncValue.data(
      (state.valueOrNull ?? []).where((z) => z.id != id).toList(),
    );
  }

  /// Toggle visibility is handled via a separate notifier so the saved zones
  /// don't need to be re-persisted when user hides/shows them on the map.
}

/// Which zones are currently visible on the map. Default: all visible.
/// Stored only in-memory — changes don't need to survive restart.
final hiddenZoneIdsProvider = StateProvider<Set<String>>((_) => const {});
