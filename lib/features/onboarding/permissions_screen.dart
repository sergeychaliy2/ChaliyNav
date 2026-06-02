import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_card.dart';

/// Shown once after onboarding (and reachable later from Settings).
/// Lists every permission the app can use with its current status and a
/// per-item "Allow" button — grants keep state updated live.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.showSkip = true});

  /// When this screen runs on first launch we want a "Later" escape hatch.
  /// When reached from Settings the user is there intentionally — hide it.
  final bool showSkip;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  static const _keyAsked = 'permissions_asked_v1';

  final _items = <_PermItem>[
    _PermItem(
      permission: Permission.location,
      icon: PhosphorIconsDuotone.mapPin,
      color: AppColors.primaryGlow,
      title: 'Геолокация',
      subtitle: 'Точка на карте, запись трека, навигация к POI.',
      required: true,
    ),
    _PermItem(
      permission: Permission.locationAlways,
      icon: PhosphorIconsDuotone.path,
      color: AppColors.accentCyan,
      title: 'Геолокация в фоне',
      subtitle: 'Запись трека при заблокированном экране.',
      hintAfter:
          'Android покажет «Разрешить в любом режиме» — нужно для фона.',
    ),
    _PermItem(
      permission: Permission.camera,
      icon: PhosphorIconsDuotone.camera,
      color: AppColors.accentAmber,
      title: 'Камера',
      subtitle: 'Фотографии к точкам прямо с камеры.',
    ),
    _PermItem(
      permission: Permission.microphone,
      icon: PhosphorIconsDuotone.microphone,
      color: AppColors.accentRose,
      title: 'Микрофон',
      subtitle: 'Голосовые заметки к точкам.',
    ),
    _PermItem(
      permission: Permission.photos,
      icon: PhosphorIconsDuotone.image,
      color: AppColors.accentViolet,
      title: 'Фото и медиа',
      subtitle: 'Прикрепить существующие снимки из галереи.',
    ),
    _PermItem(
      permission: Permission.notification,
      icon: PhosphorIconsDuotone.bellRinging,
      color: AppColors.info,
      title: 'Уведомления',
      subtitle: 'Статус записи трека и загрузок карт.',
    ),
  ];

  Map<Permission, PermissionStatus> _statuses = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final map = <Permission, PermissionStatus>{};
    for (final item in _items) {
      map[item.permission] = await item.permission.status;
    }
    if (!mounted) return;
    setState(() => _statuses = map);
  }

  Future<void> _requestOne(_PermItem item) async {
    setState(() => _busy = true);
    final status = await item.permission.request();
    _statuses[item.permission] = status;
    if (!mounted) return;
    setState(() => _busy = false);

    if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog(item);
    }
  }

  Future<void> _requestAll() async {
    setState(() => _busy = true);
    for (final item in _items) {
      final s = await item.permission.request();
      _statuses[item.permission] = s;
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _done({bool skipped = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAsked, true);
    if (!mounted) return;
    // If we came from settings, just pop. If first run — go to map.
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/map');
    }
  }

  void _showOpenSettingsDialog(_PermItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          '«${item.title}» заблокировано',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Разрешение отклонено навсегда. Откройте настройки Android и включите его вручную.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Позже'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grantedCount = _items
        .where((i) => _statuses[i.permission]?.isGranted == true)
        .length;

    return Scaffold(
      body: AnimatedBackground(
        intensity: 0.6,
        child: SafeArea(
          child: Column(
            children: [
              if (widget.showSkip)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14, top: 8),
                    child: TextButton(
                      onPressed: () => _done(skipped: true),
                      child: Text(
                        'Позже',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryBright.withValues(alpha: 0.35),
                            AppColors.primary.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Icon(
                        PhosphorIconsFill.shieldCheck,
                        color: AppColors.primaryGlow,
                        size: 36,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          duration: 2200.ms,
                          begin: const Offset(1, 1),
                          end: const Offset(1.08, 1.08),
                        ),
                    const SizedBox(height: 14),
                    const Text(
                      'Разрешения',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Предоставлено $grantedCount из ${_items.length}. Отдельно «в фоне» — для записи трека при заблокированном экране.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) => _PermTile(
                    item: _items[i],
                    status: _statuses[_items[i].permission],
                    onRequest: _busy ? null : () => _requestOne(_items[i]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    GlassButton(
                      label: _busy ? 'Запрашиваю…' : 'Разрешить всё',
                      icon: Icon(PhosphorIconsBold.check),
                      onPressed: _busy ? null : _requestAll,
                      expanded: true,
                    ),
                    const SizedBox(height: 8),
                    GlassButton(
                      label: widget.showSkip
                          ? 'Готово, на карту'
                          : 'Закрыть',
                      variant: GlassButtonVariant.secondary,
                      onPressed: () => _done(),
                      expanded: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exposed for splash_screen: was the permissions screen already shown
  /// at least once? We don't force it again if the user skipped.
  static Future<bool> wasAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAsked) ?? false;
  }
}

class _PermItem {
  const _PermItem({
    required this.permission,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.required = false,
    this.hintAfter,
  });
  final Permission permission;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool required;
  final String? hintAfter;
}

class _PermTile extends StatelessWidget {
  const _PermTile({
    required this.item,
    required this.status,
    required this.onRequest,
  });

  final _PermItem item;
  final PermissionStatus? status;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final (badgeText, badgeColor, icon) = _statusStyle(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color.withValues(alpha: 0.2),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (item.required)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentRose
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'НУЖНО',
                                style: TextStyle(
                                  color: AppColors.accentRose,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(icon, color: badgeColor, size: 13),
                const SizedBox(width: 6),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                if (status?.isGranted != true)
                  TextButton.icon(
                    onPressed: onRequest,
                    icon: Icon(PhosphorIconsBold.check, size: 14),
                    label: const Text('Разрешить'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGlow,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            if (item.hintAfter != null && status?.isGranted != true) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  item.hintAfter!,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, Color, IconData) _statusStyle(PermissionStatus? s) {
    if (s == null) {
      return (
        'ПРОВЕРКА…',
        AppColors.textTertiary,
        PhosphorIconsDuotone.clock,
      );
    }
    if (s.isGranted) {
      return (
        'РАЗРЕШЕНО',
        AppColors.success,
        PhosphorIconsDuotone.checkCircle,
      );
    }
    if (s.isPermanentlyDenied) {
      return (
        'ЗАБЛОКИРОВАНО',
        AppColors.error,
        PhosphorIconsDuotone.prohibit,
      );
    }
    if (s.isDenied) {
      return (
        'НЕ ВЫДАНО',
        AppColors.accentAmber,
        PhosphorIconsDuotone.warningCircle,
      );
    }
    return (
      s.toString().split('.').last.toUpperCase(),
      AppColors.textSecondary,
      PhosphorIconsDuotone.info,
    );
  }
}
