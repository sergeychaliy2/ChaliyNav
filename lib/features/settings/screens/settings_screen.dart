import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/map_layer.dart';
import '../../../shared/providers/locale_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/services/tile_cache_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final s = settingsAsync.valueOrNull ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppStrings.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: l10n.settingsTitle),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 72,
          bottom: MediaQuery.of(context).padding.bottom + 100,
          left: 16,
          right: 16,
        ),
        children: [
          _Section(
            icon: PhosphorIconsDuotone.path,
            title: l10n.settingsTrackRecord,
            children: [
              _Slider(
                icon: PhosphorIconsDuotone.ruler,
                label: l10n.settingsMinDistance,
                value: s.trackMinDistance,
                min: 1,
                max: 30,
                divisions: 29,
                unit: ' м',
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(trackMinDistance: v)),
              ),
              _Slider(
                icon: PhosphorIconsDuotone.clock,
                label: l10n.settingsMinInterval,
                value: s.trackMinInterval.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                unit: ' с',
                onChanged: (v) => notifier.mutate(
                    (c) => c.copyWith(trackMinInterval: v.round())),
              ),
              _Slider(
                icon: PhosphorIconsDuotone.target,
                label: l10n.settingsGpsAccuracy,
                value: s.gpsAccuracyThreshold,
                min: 5,
                max: 100,
                divisions: 19,
                unit: ' м',
                onChanged: (v) => notifier.mutate(
                    (c) => c.copyWith(gpsAccuracyThreshold: v)),
              ),
              _Slider(
                icon: PhosphorIconsDuotone.paintBrush,
                label: l10n.settingsTrackWidth,
                value: s.trackWidth,
                min: 2,
                max: 8,
                divisions: 12,
                unit: '',
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(trackWidth: v)),
              ),
            ],
          ),
          _Section(
            icon: PhosphorIconsDuotone.monitor,
            title: l10n.settingsDisplay,
            children: [
              _Switch(
                icon: PhosphorIconsDuotone.gauge,
                label: l10n.settingsSpeedometer,
                value: s.showSpeedometer,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(showSpeedometer: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.compass,
                label: l10n.settingsCompass,
                value: s.showCompass,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(showCompass: v)),
              ),
              if (s.showCompass)
                _Switch(
                  icon: PhosphorIconsDuotone.compassRose,
                  label: l10n.settingsCompassExpanded,
                  value: s.compassExpanded,
                  onChanged: (v) => notifier
                      .mutate((c) => c.copyWith(compassExpanded: v)),
                ),
              _Switch(
                icon: PhosphorIconsDuotone.crosshair,
                label: l10n.settingsAccuracy,
                value: s.showAccuracy,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(showAccuracy: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.mapPin,
                label: l10n.settingsPointsOnMap,
                value: s.showPointsOnMap,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(showPointsOnMap: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.sun,
                label: l10n.settingsKeepScreenOn,
                value: s.keepScreenOn,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(keepScreenOn: v)),
              ),
              _Picker<MapOrientation>(
                icon: PhosphorIconsDuotone.compassRose,
                label: l10n.settingsMapOrientation,
                value: s.mapOrientation,
                options: MapOrientation.values,
                labelBuilder: (o) => l10n.orientationLabel(o.name),
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(mapOrientation: v)),
              ),
            ],
          ),
          _Section(
            icon: PhosphorIconsDuotone.speakerHigh,
            title: l10n.settingsVoice,
            children: [
              _Switch(
                icon: PhosphorIconsDuotone.megaphone,
                label: l10n.settingsVoiceGuide,
                value: s.voiceGuideEnabled,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(voiceGuideEnabled: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.chatText,
                label: l10n.settingsShortHints,
                value: s.voiceShortHints,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(voiceShortHints: v)),
              ),
              _Slider(
                icon: PhosphorIconsDuotone.ruler,
                label: l10n.settingsHintStep,
                value: s.voiceStepMeters.toDouble(),
                min: 20,
                max: 500,
                divisions: 24,
                unit: ' м',
                onChanged: (v) => notifier
                    .mutate((c) => c.copyWith(voiceStepMeters: v.round())),
              ),
              _Slider(
                icon: PhosphorIconsDuotone.timer,
                label: l10n.settingsHintCooldown,
                value: s.voiceCooldownSec.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                unit: ' с',
                onChanged: (v) => notifier
                    .mutate((c) => c.copyWith(voiceCooldownSec: v.round())),
              ),
            ],
          ),
          _Section(
            icon: PhosphorIconsDuotone.vibrate,
            title: l10n.settingsShake,
            children: [
              _Switch(
                icon: PhosphorIconsDuotone.handWaving,
                label: l10n.settingsShakeSave,
                value: s.shakeToSavePoint,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(shakeToSavePoint: v)),
              ),
              _Slider(
                icon: PhosphorIconsDuotone.waveform,
                label: l10n.settingsSensitivity,
                value: s.shakeSensitivity,
                min: 5,
                max: 30,
                divisions: 25,
                unit: '',
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(shakeSensitivity: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.microphone,
                label: l10n.settingsAutoAudio,
                value: s.voiceMemoOnSave,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(voiceMemoOnSave: v)),
              ),
            ],
          ),
          _Section(
            icon: PhosphorIconsDuotone.thermometer,
            title: l10n.settingsMeta,
            children: [
              _Switch(
                icon: PhosphorIconsDuotone.mountains,
                label: l10n.settingsAltitude,
                value: s.captureAltitude,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(captureAltitude: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.gauge,
                label: l10n.settingsPressure,
                value: s.capturePressure,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(capturePressure: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.moon,
                label: l10n.settingsMoon,
                value: s.captureMoonPhase,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(captureMoonPhase: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.cloudSun,
                label: l10n.settingsWeather,
                value: s.captureWeather,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(captureWeather: v)),
              ),
            ],
          ),
          _Section(
            icon: PhosphorIconsDuotone.bellRinging,
            title: 'Уведомление записи трека',
            children: [
              _Switch(
                icon: PhosphorIconsDuotone.bell,
                label: 'Показывать подробности',
                value: s.recordingNotifEnabled,
                onChanged: (v) => notifier
                    .mutate((c) => c.copyWith(recordingNotifEnabled: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.clock,
                label: 'Время записи',
                value: s.recordingNotifShowTime,
                onChanged: s.recordingNotifEnabled
                    ? (v) => notifier.mutate(
                        (c) => c.copyWith(recordingNotifShowTime: v))
                    : (_) {},
              ),
              _Switch(
                icon: PhosphorIconsDuotone.ruler,
                label: 'Пройденное расстояние',
                value: s.recordingNotifShowDistance,
                onChanged: s.recordingNotifEnabled
                    ? (v) => notifier.mutate(
                        (c) => c.copyWith(recordingNotifShowDistance: v))
                    : (_) {},
              ),
              _Switch(
                icon: PhosphorIconsDuotone.gauge,
                label: 'Средняя скорость',
                value: s.recordingNotifShowSpeed,
                onChanged: s.recordingNotifEnabled
                    ? (v) => notifier.mutate(
                        (c) => c.copyWith(recordingNotifShowSpeed: v))
                    : (_) {},
              ),
              _Switch(
                icon: PhosphorIconsDuotone.dotsThreeOutline,
                label: 'Количество точек',
                value: s.recordingNotifShowPoints,
                onChanged: s.recordingNotifEnabled
                    ? (v) => notifier.mutate(
                        (c) => c.copyWith(recordingNotifShowPoints: v))
                    : (_) {},
              ),
            ],
          ),
          _Section(
            icon: PhosphorIconsDuotone.lock,
            title: l10n.settingsSecurity,
            children: [
              _Switch(
                icon: PhosphorIconsDuotone.lockKey,
                label: l10n.settingsAppLock,
                value: s.appLockEnabled,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(appLockEnabled: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.fingerprint,
                label: l10n.settingsBiometric,
                value: s.biometricLock,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(biometricLock: v)),
              ),
              _Switch(
                icon: PhosphorIconsDuotone.eyeSlash,
                label: l10n.settingsSecretCategory,
                value: s.secretCategoryLocked,
                onChanged: (v) =>
                    notifier.mutate((c) => c.copyWith(secretCategoryLocked: v)),
              ),
            ],
          ),
          const _MapCacheSection(),
          _LocaleSection(),
          _Section(
            icon: PhosphorIconsDuotone.question,
            title: l10n.settingsHelp,
            children: [
              _ActionRow(
                icon: PhosphorIconsDuotone.bookOpen,
                label: l10n.settingsHelpWiki,
                subtitle: l10n.settingsHelpWikiSub,
                onTap: () => context.push('/settings/help'),
              ),
              _ActionRow(
                icon: PhosphorIconsDuotone.graduationCap,
                label: l10n.settingsRepeatOnboarding,
                subtitle: l10n.settingsRepeatOnboardingSub,
                onTap: () => context.go('/onboarding'),
              ),
              _ActionRow(
                icon: PhosphorIconsDuotone.shieldCheck,
                label: l10n.settingsPermissions,
                subtitle: l10n.settingsPermissionsSub,
                onTap: () => context.push('/permissions'),
              ),
            ],
          ),
          _Section(
            icon: PhosphorIconsDuotone.cloud,
            title: l10n.settingsData,
            children: [
              _ActionRow(
                icon: PhosphorIconsDuotone.swap,
                label: l10n.settingsImportExport,
                subtitle: l10n.settingsImportExportSub,
                onTap: () => context.push('/settings/data'),
              ),
              _ActionRow(
                icon: PhosphorIconsDuotone.cloudArrowDown,
                label: l10n.settingsDownloads,
                subtitle: l10n.settingsDownloadsSub,
                onTap: () => context.push('/settings/downloads'),
              ),
              _ActionRow(
                icon: PhosphorIconsDuotone.cloudArrowUp,
                label: l10n.settingsCloudSync,
                subtitle: l10n.settingsCloudSyncSub,
                onTap: () {},
              ),
              _ActionRow(
                icon: PhosphorIconsDuotone.shieldCheck,
                label: l10n.settingsBackup,
                subtitle: l10n.settingsBackupSub,
                onTap: () => context.push('/settings/backup'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v${AppConstants.appVersion} · ${AppConstants.appTagline}',
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocaleSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final l10n = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.translate,
                    color: AppColors.primaryGlow, size: 18),
                const SizedBox(width: 8),
                Text(
                  l10n.settingsInterface,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                for (final locale in AppLocale.values)
                  InkWell(
                    onTap: () =>
                        ref.read(localeProvider.notifier).set(locale),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            locale.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              locale.label,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (current == locale)
                            Icon(PhosphorIconsBold.check,
                                color: AppColors.primaryGlow, size: 16),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 6),
            child: Text(
              l10n.settingsLocaleHint,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Map-tile cache: auto-prefetch controls (download the area you're
/// looking at across a zoom range) plus on-device size and a clear button.
/// Stateful so it can show the live cache size and refresh after a wipe.
class _MapCacheSection extends ConsumerStatefulWidget {
  const _MapCacheSection();

  @override
  ConsumerState<_MapCacheSection> createState() => _MapCacheSectionState();
}

class _MapCacheSectionState extends ConsumerState<_MapCacheSection> {
  int? _bytes;
  int? _tiles;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final b = await TileCacheStore.instance.sizeBytes();
    final t = await TileCacheStore.instance.count();
    if (!mounted) return;
    setState(() {
      _bytes = b;
      _tiles = t;
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Очистить кеш карт?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Будут удалены все автоматически сохранённые тайлы карт. '
          'Скачанные офлайн-области (раздел «Загрузки») не затрагиваются.\n\n'
          'Карты заново подгрузятся при наличии интернета.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Очистить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _clearing = true);
    await TileCacheStore.instance.clear();
    await _loadStats();
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Кеш карт очищен')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final n = ref.read(settingsProvider.notifier);
    final sizeText = _bytes == null
        ? 'Подсчёт…'
        : '${Formatters.bytes(_bytes!)} · ${_tiles ?? 0} тайлов';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.stack,
                    color: AppColors.primaryGlow, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Кеш карт',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Switch(
                  icon: PhosphorIconsDuotone.cloudArrowDown,
                  label: 'Подгружать детальные зумы',
                  value: s.tilePrefetchEnabled,
                  onChanged: (v) =>
                      n.mutate((c) => c.copyWith(tilePrefetchEnabled: v)),
                ),
                if (s.tilePrefetchEnabled) ...[
                  _StyleMultiSelect(
                    selected: s.tilePrefetchStyles,
                    onToggle: (style) {
                      final next = {...s.tilePrefetchStyles};
                      if (next.contains(style)) {
                        next.remove(style);
                      } else {
                        next.add(style);
                      }
                      n.mutate((c) => c.copyWith(tilePrefetchStyles: next));
                    },
                  ),
                  _ZoomRange(
                    min: s.tilePrefetchMinZoom,
                    max: s.tilePrefetchMaxZoom,
                    onChanged: (lo, hi) => n.mutate(
                      (c) => c.copyWith(
                        tilePrefetchMinZoom: lo,
                        tilePrefetchMaxZoom: hi,
                      ),
                    ),
                  ),
                  _Switch(
                    icon: PhosphorIconsDuotone.wifiHigh,
                    label: 'Только по Wi-Fi',
                    value: s.tilePrefetchWifiOnly,
                    onChanged: (v) =>
                        n.mutate((c) => c.copyWith(tilePrefetchWifiOnly: v)),
                  ),
                ],
                const Divider(height: 1, indent: 12, endIndent: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                  child: Row(
                    children: [
                      Icon(PhosphorIconsDuotone.database,
                          color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Сохранено на устройстве',
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14),
                            ),
                            Text(
                              sizeText,
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed:
                            (_clearing || (_bytes ?? 0) == 0) ? null : _clear,
                        child: _clearing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                'Очистить',
                                style: TextStyle(
                                  color: (_bytes ?? 0) == 0
                                      ? AppColors.textTertiary
                                      : AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 6),
            child: Text(
              !s.tilePrefetchEnabled
                  ? 'Просмотренные участки всё равно кешируются на тех зумах, '
                      'что были на экране. Включите подгрузку, чтобы офлайн-'
                      'приближение не было размытым.'
                  : s.tilePrefetchStyles.isEmpty
                      ? 'Не выбран ни один тип карт — подкачка ничего не '
                          'сохраняет. Отметьте «Карту» и/или «Спутник» выше.'
                      : 'Когда карта останавливается, видимый участок '
                          'докачивается для выбранных типов карт на выбранных '
                          'зумах и остаётся доступным без интернета. «Только по '
                          'Wi-Fi» бережёт мобильный трафик — выключите его, '
                          'чтобы качать всегда. Кеш не удаляется сам.',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-select of which base-map styles to prefetch offline. Tapping a
/// chip toggles it; an empty selection means nothing is prefetched (the
/// live cache still keeps whatever style is on screen).
class _StyleMultiSelect extends StatelessWidget {
  const _StyleMultiSelect({required this.selected, required this.onToggle});

  final Set<BaseMapStyle> selected;
  final void Function(BaseMapStyle) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsDuotone.mapTrifold,
                  color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Какие карты кешировать',
                  style:
                      TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final style in BaseMapStyle.values)
                _StyleChip(
                  label: style.label,
                  selected: selected.contains(style),
                  onTap: () => onToggle(style),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.22)
              : AppColors.glassBorder.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? AppColors.primaryGlow
                : AppColors.glassBorderStrong,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(PhosphorIconsBold.check,
                  color: AppColors.primaryGlow, size: 13),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dual-thumb zoom-range picker. Updates the label live while dragging and
/// only persists on release (onChangeEnd) to avoid a prefs write per pixel.
class _ZoomRange extends StatefulWidget {
  const _ZoomRange({
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int min;
  final int max;
  final void Function(int lo, int hi) onChanged;

  @override
  State<_ZoomRange> createState() => _ZoomRangeState();
}

class _ZoomRangeState extends State<_ZoomRange> {
  late RangeValues _v;

  @override
  void initState() {
    super.initState();
    _v = RangeValues(widget.min.toDouble(), widget.max.toDouble());
  }

  @override
  void didUpdateWidget(_ZoomRange old) {
    super.didUpdateWidget(old);
    if (old.min != widget.min || old.max != widget.max) {
      _v = RangeValues(widget.min.toDouble(), widget.max.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsDuotone.magnifyingGlassPlus,
                  color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Диапазон зумов',
                  style:
                      TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
              Text(
                'z${_v.start.round()}–z${_v.end.round()}',
                style: TextStyle(
                  color: AppColors.primaryGlow,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryGlow,
              inactiveTrackColor: AppColors.glassBorderStrong,
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: RangeSlider(
              values: _v,
              min: 3,
              max: 19,
              divisions: 16,
              labels: RangeLabels('z${_v.start.round()}', 'z${_v.end.round()}'),
              onChanged: (rv) => setState(() => _v = rv),
              onChangeEnd: (rv) =>
                  widget.onChanged(rv.start.round(), rv.end.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryGlow, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(value == value.round() ? 0 : 1)}$unit',
                style: TextStyle(
                  color: AppColors.primaryGlow,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryGlow,
              inactiveTrackColor: AppColors.glassBorderStrong,
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          DropdownButton<T>(
            value: value,
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.bgElevated,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            iconEnabledColor: AppColors.textSecondary,
            items: options
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(labelBuilder(o)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGlow, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.caretRight,
                color: AppColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
