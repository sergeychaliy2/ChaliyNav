import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import 'repositories_providers.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return ref.read(settingsRepositoryProvider).load();
  }

  Future<void> mutate(
    AppSettings Function(AppSettings current) fn,
  ) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = fn(current);
    await ref.read(settingsRepositoryProvider).save(next);
    state = AsyncValue.data(next);
  }

  Future<void> replace(AppSettings next) async {
    await ref.read(settingsRepositoryProvider).save(next);
    state = AsyncValue.data(next);
  }
}
