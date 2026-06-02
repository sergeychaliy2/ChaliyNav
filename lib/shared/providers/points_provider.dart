import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poi_category.dart';
import '../models/point_of_interest.dart';
import 'repositories_providers.dart';

final pointsProvider =
    AsyncNotifierProvider<PointsNotifier, List<PointOfInterest>>(
  PointsNotifier.new,
);

class PointsNotifier extends AsyncNotifier<List<PointOfInterest>> {
  @override
  Future<List<PointOfInterest>> build() async {
    return ref.read(pointsRepositoryProvider).loadAll();
  }

  Future<void> add(PointOfInterest point) async {
    await ref.read(pointsRepositoryProvider).save(point);
    state = AsyncValue.data(
      [point, ...state.valueOrNull ?? []],
    );
  }

  Future<void> upsert(PointOfInterest point) async {
    await ref.read(pointsRepositoryProvider).save(point);
    final list = [...?state.valueOrNull];
    final idx = list.indexWhere((p) => p.id == point.id);
    if (idx >= 0) {
      list[idx] = point;
    } else {
      list.insert(0, point);
    }
    state = AsyncValue.data(list);
  }

  Future<void> remove(String id) async {
    await ref.read(pointsRepositoryProvider).delete(id);
    state = AsyncValue.data(
      (state.valueOrNull ?? []).where((p) => p.id != id).toList(),
    );
  }

  Future<void> toggleFavorite(String id) async {
    final list = state.valueOrNull ?? [];
    final existing = list.firstWhere(
      (p) => p.id == id,
      orElse: () => throw StateError('Point $id not found'),
    );
    await upsert(existing.copyWith(favorite: !existing.favorite));
  }
}

/// Derived — filtered / searched view of points.
final pointsFilterProvider = StateProvider<PointsFilter>(
  (_) => const PointsFilter(),
);

final filteredPointsProvider = Provider<List<PointOfInterest>>((ref) {
  final list = ref.watch(pointsProvider).valueOrNull ?? const [];
  final filter = ref.watch(pointsFilterProvider);
  return filter.apply(list);
});

class PointsFilter {
  const PointsFilter({
    this.query = '',
    this.category,
    this.favoritesOnly = false,
    this.sort = PointsSort.newest,
  });

  final String query;
  final PoiCategory? category;
  final bool favoritesOnly;
  final PointsSort sort;

  PointsFilter copyWith({
    String? query,
    PoiCategory? category,
    bool clearCategory = false,
    bool? favoritesOnly,
    PointsSort? sort,
  }) =>
      PointsFilter(
        query: query ?? this.query,
        category: clearCategory ? null : (category ?? this.category),
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        sort: sort ?? this.sort,
      );

  List<PointOfInterest> apply(List<PointOfInterest> input) {
    var list = input;
    if (category != null) {
      list = list.where((p) => p.category == category).toList();
    }
    if (favoritesOnly) {
      list = list.where((p) => p.favorite).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      list = list
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.note.toLowerCase().contains(q))
          .toList();
    }
    list = [...list];
    switch (sort) {
      case PointsSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PointsSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case PointsSort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case PointsSort.category:
        list.sort((a, b) => a.category.index.compareTo(b.category.index));
        break;
    }
    return list;
  }
}

enum PointsSort {
  newest,
  oldest,
  title,
  category;

  String get label => switch (this) {
        PointsSort.newest => 'Сначала новые',
        PointsSort.oldest => 'Сначала старые',
        PointsSort.title => 'По названию',
        PointsSort.category => 'По категории',
      };
}
