import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_path.dart';
import 'repositories_providers.dart';

final routesProvider =
    AsyncNotifierProvider<RoutesNotifier, List<RoutePath>>(RoutesNotifier.new);

class RoutesNotifier extends AsyncNotifier<List<RoutePath>> {
  @override
  Future<List<RoutePath>> build() async {
    return ref.read(routesRepositoryProvider).loadAll();
  }

  Future<void> add(RoutePath route) async {
    await ref.read(routesRepositoryProvider).save(route);
    state = AsyncValue.data([route, ...state.valueOrNull ?? []]);
  }

  Future<void> remove(String id) async {
    await ref.read(routesRepositoryProvider).delete(id);
    state = AsyncValue.data(
      (state.valueOrNull ?? []).where((r) => r.id != id).toList(),
    );
  }
}
