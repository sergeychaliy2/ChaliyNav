import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/animated_background.dart';
import '../../shared/models/app_settings.dart';
import '../../shared/models/map_layer.dart';
import '../../shared/providers/tracks_provider.dart';
import '../../shared/repositories/layers_repository.dart';
import '../../shared/repositories/settings_repository.dart';
import '../../shared/services/layers_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    // Warm up any MBTiles tile providers in the BACKGROUND while the
    // splash logo is still showing. Opening SQLite handles up front
    // means the first toggle-on on the map screen is instant instead
    // of blocking the UI while SQLite pages get paged in.
    //
    // Don't await this — it must not delay onboarding/map navigation.
    // ignore: unawaited_futures
    _prewarmOfflineLayers();

    // Recover any track that was being recorded when the app died
    // (force-close, crash, OS OOM-kill). Persists every point to
    // SharedPreferences; if that mirror exists here, we promote it to
    // a saved Track so the user doesn't lose their run.
    final recovered = await recoverInterruptedRecording(
      ProviderScope.containerOf(context, listen: false),
    );

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(AppConstants.prefsKeyOnboarded) ?? false;
    if (!onboarded) {
      if (!mounted) return;
      context.go('/onboarding');
      return;
    }
    // Check app-lock setting.
    final AppSettings settings =
        await SharedPrefsSettingsRepository().load();
    if (!mounted) return;
    if (settings.appLockEnabled) {
      context.go('/lock');
    } else {
      context.go('/map');
    }

    // After navigation, nudge the user with a snackbar summarising
    // what we recovered. We schedule it after the current frame so
    // the MapScreen's ScaffoldMessenger is the one that shows it.
    if (recovered != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Восстановлен трек после сбоя: '
                    '${Formatters.distance(recovered.distanceM)} · '
                    '${recovered.points.length} точек',
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }
  }

  Future<void> _prewarmOfflineLayers() async {
    try {
      final layers =
          await SharedPrefsLayersRepository().loadAll();
      // Pre-build providers for every existing MBTiles layer so the
      // SQLite handle is open + page cache is warm by the time the
      // map screen first mounts. We don't care about the returned
      // TileLayer here — LayersService caches the provider internally.
      for (final l in layers) {
        if (l.type == MapLayerType.mbtiles) {
          await LayersService.buildTileLayer(l);
        }
      }
    } catch (_) {
      // Best effort — prewarming failures must never block startup.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Logo()
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 28),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 10),
              Text(
                AppConstants.appTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0.4,
                  fontStyle: FontStyle.italic,
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 48),
              const _LoadingDot()
                  .animate()
                  .fadeIn(delay: 900.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatefulWidget {
  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final angle = _ctrl.value * 2 * math.pi;
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primaryBright.withValues(alpha: 0.35),
                AppColors.primary.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBright.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: angle,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryGlow.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment(0, -1),
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: AppColors.primaryGlow,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(
                  PhosphorIconsFill.compass,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingDot extends StatelessWidget {
  const _LoadingDot();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryGlow,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .fadeIn(duration: 400.ms, delay: (i * 150).ms)
            .then()
            .fadeOut(duration: 400.ms);
      }),
    );
  }
}
