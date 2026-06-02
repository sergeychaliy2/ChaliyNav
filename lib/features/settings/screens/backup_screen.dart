import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/providers/layers_provider.dart';
import '../../../shared/providers/points_provider.dart';
import '../../../shared/providers/routes_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/providers/tracks_provider.dart';
import '../../../shared/providers/zones_provider.dart';
import '../../../shared/services/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _createBackup() async {
    final password = await _askPassword(
      title: 'Пароль для нового бэкапа',
      hint: 'Минимум 6 символов',
    );
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final file = await BackupService.createBackup(password);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'ChaliyNav — зашифрованный бэкап',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Бэкап создан: ${file.path.split('/').last}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.chaliy')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите файл .chaliy'),
        ),
      );
      return;
    }

    final password = await _askPassword(
      title: 'Пароль бэкапа',
      hint: 'Тот же, что вы указали при создании',
    );
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final report = await BackupService.restoreBackup(File(path), password);
      // Force all providers to reload from the restored SharedPreferences.
      ref.invalidate(pointsProvider);
      ref.invalidate(tracksProvider);
      ref.invalidate(routesProvider);
      ref.invalidate(zonesProvider);
      ref.invalidate(layersProvider);
      ref.invalidate(settingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Восстановлено: ${report.restoredSections.join(", ")}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPassword({
    required String title,
    required String hint,
  }) async {
    final ctrl = TextEditingController();
    bool obscured = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text(
            title,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            obscureText: obscured,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: IconButton(
                onPressed: () => setInner(() => obscured = !obscured),
                icon: Icon(
                  obscured
                      ? PhosphorIconsDuotone.eye
                      : PhosphorIconsDuotone.eyeSlash,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final v = ctrl.text;
                if (v.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Минимум 6 символов')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(v);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Бэкап',
        subtitle: 'AES-256 с вашим паролем',
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 80,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 40,
        ),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsDuotone.shieldCheck,
                        color: AppColors.primaryGlow, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Зашифрованный бэкап',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Экспорт всех ваших данных (точки, треки, маршруты, зоны, слои, настройки) в один файл .chaliy, зашифрованный AES-256 вашим паролем. '
                  'Отдайте / перенесите на другое устройство — «Восстановить» примет тот же пароль.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'Создать',
                        icon: Icon(PhosphorIconsDuotone.downloadSimple),
                        onPressed: _busy ? null : _createBackup,
                        expanded: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassButton(
                        label: 'Восстановить',
                        icon: Icon(PhosphorIconsDuotone.uploadSimple),
                        variant: GlassButtonVariant.secondary,
                        onPressed: _busy ? null : _restoreBackup,
                        expanded: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsDuotone.info,
                        color: AppColors.accentAmber, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Что внутри бэкапа',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '✓ Точки, треки, маршруты, зоны\n'
                  '✓ Слои карт (ссылки, настройки прозрачности)\n'
                  '✓ Настройки приложения\n\n'
                  'Не включено (остаётся на устройстве):\n'
                  '✗ Фото и аудио-заметки\n'
                  '✗ Скачанные offline-карты (.mbtiles)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.warning,
                    color: AppColors.accentAmber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Запомните пароль — мы не сможем его восстановить. Без пароля бэкап превращается в шум.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
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
