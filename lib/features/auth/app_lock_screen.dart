import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glass_button.dart';
import '../../shared/providers/settings_provider.dart';
import '../../shared/services/app_lock_service.dart';

/// Full-screen gate. Shown on launch if the user turned on appLock.
/// Provides an emergency exit after 2 failed biometric attempts so the
/// user doesn't get permanently locked out if the sensor breaks or the
/// OEM launcher has a buggy local_auth integration.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key, this.onUnlocked});
  final VoidCallback? onUnlocked;

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _running = false;
  String? _error;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    // Auto-prompt on open.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _prompt() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    final l10n = AppStrings.of(context);
    final ok = await AppLockService.instance.authenticate(
      reason: '${l10n.lockUnlock} ChaliyNav',
    );
    if (!mounted) return;
    if (ok) {
      if (widget.onUnlocked != null) {
        widget.onUnlocked!();
      } else {
        context.go('/map');
      }
      return;
    }
    setState(() {
      _running = false;
      _failures += 1;
      _error = l10n.lockFailedTryAgain;
    });
  }

  Future<void> _emergencyDisable() async {
    final l10n = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          l10n.lockEmergencyExit,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          l10n.lockBiometricSub,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(settingsProvider.notifier)
        .mutate((c) => c.copyWith(appLockEnabled: false));
    if (!mounted) return;
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    return Scaffold(
      body: AnimatedBackground(
        intensity: 0.7,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryBright.withValues(alpha: 0.35),
                        AppColors.primary.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Icon(
                    PhosphorIconsFill.fingerprintSimple,
                    color: AppColors.primaryGlow,
                    size: 50,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                      duration: 2400.ms,
                      begin: const Offset(1, 1),
                      end: const Offset(1.08, 1.08),
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 22),
                Text(
                  l10n.lockTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.lockSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                GlassButton(
                  label: l10n.lockUnlock,
                  icon: Icon(PhosphorIconsBold.fingerprint),
                  onPressed: _running ? null : _prompt,
                  expanded: true,
                ),
                // Emergency exit appears after the 2nd failed attempt so
                // the user can't brick the app if their biometric fails.
                if (_failures >= 2) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _emergencyDisable,
                    icon: Icon(PhosphorIconsDuotone.warning,
                        size: 16, color: AppColors.accentAmber),
                    label: Text(
                      l10n.lockEmergencyExit,
                      style: const TextStyle(color: AppColors.accentAmber),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
