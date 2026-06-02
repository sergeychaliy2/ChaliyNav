import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported UI languages. Full UI localization for RU; partial for EN / BE /
/// UK (key navigation + section titles — rest falls back to RU).
enum AppLocale {
  ru,
  en,
  be,
  uk;

  String get label => switch (this) {
        AppLocale.ru => 'Русский',
        AppLocale.en => 'English',
        AppLocale.be => 'Беларуская',
        AppLocale.uk => 'Українська',
      };

  String get nativeLabel => switch (this) {
        AppLocale.ru => 'Русский',
        AppLocale.en => 'English',
        AppLocale.be => 'Беларуская мова',
        AppLocale.uk => 'Українська мова',
      };

  String get flag => switch (this) {
        AppLocale.ru => '🇷🇺',
        AppLocale.en => '🇬🇧',
        AppLocale.be => '🇧🇾',
        AppLocale.uk => '🇺🇦',
      };

  Locale get locale => switch (this) {
        AppLocale.ru => const Locale('ru', 'RU'),
        AppLocale.en => const Locale('en', 'US'),
        AppLocale.be => const Locale('be', 'BY'),
        AppLocale.uk => const Locale('uk', 'UA'),
      };
}

const _key = 'app_locale_v1';

/// Pre-loaded from SharedPreferences during main() so there's no flash of
/// the default RU locale on first frame. Overridden in ProviderScope.
final initialLocaleProvider = Provider<AppLocale>((_) => AppLocale.ru);

class LocaleNotifier extends Notifier<AppLocale> {
  @override
  AppLocale build() => ref.read(initialLocaleProvider);

  Future<void> set(AppLocale value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);

/// Read the saved locale synchronously-ish at app startup. Call once in
/// main() before runApp() so the first MaterialApp build sees the correct
/// locale.
Future<AppLocale> loadSavedLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return AppLocale.ru;
  return AppLocale.values.firstWhere(
    (l) => l.name == raw,
    orElse: () => AppLocale.ru,
  );
}
