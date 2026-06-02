import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/layers_repository.dart';
import '../repositories/points_repository.dart';
import '../repositories/routes_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tracks_repository.dart';

/// Central point for swapping in-memory impls for persistent ones (Isar/Drift)
/// without touching UI. Override these at ProviderScope level for tests or DI.
final pointsRepositoryProvider = Provider<PointsRepository>(
  (_) => SharedPrefsPointsRepository(),
);

final tracksRepositoryProvider = Provider<TracksRepository>(
  (_) => SharedPrefsTracksRepository(),
);

final routesRepositoryProvider = Provider<RoutesRepository>(
  (_) => SharedPrefsRoutesRepository(),
);

final layersRepositoryProvider = Provider<LayersRepository>(
  (_) => SharedPrefsLayersRepository(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => SharedPrefsSettingsRepository(),
);
