import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glass_button.dart';

/// 5-slide onboarding tour. Shown on first launch (and replayable from
/// Settings → Помощь → «Показать обучение»).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = <_Slide>[
    _Slide(
      icon: PhosphorIconsFill.compass,
      title: 'Добро пожаловать в ChaliyNav',
      subtitle: 'Your path. Your marks. Your legacy.',
      description:
          'Полевая навигация для рыбаков, охотников, туристов, грибников и поисковиков. Работает offline и бережёт батарею.',
      color: AppColors.primaryGlow,
    ),
    _Slide(
      icon: PhosphorIconsFill.stack,
      title: 'Карты под вас',
      subtitle: '75+ пресетов РФ и мира',
      description:
          'Подключите OpenTopoMap, спутник Esri, глубины GEBCO, трёхверстовку Шуберта, РККА 1941 — или скачайте любой регион РФ в offline-режиме.',
      color: AppColors.accentCyan,
    ),
    _Slide(
      icon: PhosphorIconsFill.mapPin,
      title: 'Умные точки',
      subtitle: 'Shake / voice / long-press',
      description:
          'Ставьте точки встряхиванием, долгим тапом по карте или через меню. Категорируйте (рыбалка, охота, грибы…), прикрепляйте фото и аудио-заметки.',
      color: AppColors.accentAmber,
    ),
    _Slide(
      icon: PhosphorIconsFill.polygon,
      title: 'Зоны и квартал',
      subtitle: 'Измеряй, именуй, сохраняй',
      description:
          'Обводите кварталы, угодья, аквазоны. Именуйте каждую вершину, перетаскивайте пальцем, редактируйте готовые зоны с перезаписью.',
      color: AppColors.accentRose,
    ),
    _Slide(
      icon: PhosphorIconsFill.path,
      title: 'Треки и навигация',
      subtitle: 'Kalman + фоновая запись',
      description:
          'Точная запись пути даже с глушилками: фильтр Калмана сглаживает GPS, foreground-сервис продолжает запись при заблокированном экране.',
      color: AppColors.primaryBright,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsKeyOnboarded, true);
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    // Send the user to the permissions flow next — the map screen is
    // useless without at least fine-location.
    context.go('/permissions');
  }

  void _skip() => _finish();

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top — skip button
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14, top: 8),
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Пропустить',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (ctx, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              // Bottom — dots + next button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _page == i ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _page == i
                                  ? AppColors.primaryGlow
                                  : AppColors.glassBorderStrong,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GlassButton(
                      label: isLast ? 'Начать' : 'Далее',
                      icon: Icon(
                        isLast
                            ? PhosphorIconsBold.check
                            : PhosphorIconsBold.arrowRight,
                      ),
                      onPressed: _next,
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
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _OrbitIcon(color: slide.color, icon: slide.icon)
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          )
              .animate()
              .fadeIn(delay: 120.ms, duration: 400.ms)
              .slideY(begin: 0.15, end: 0),
          const SizedBox(height: 6),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: slide.color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 22),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.55,
            ),
          ).animate().fadeIn(delay: 280.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _OrbitIcon extends StatefulWidget {
  const _OrbitIcon({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  State<_OrbitIcon> createState() => _OrbitIconState();
}

class _OrbitIconState extends State<_OrbitIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))
        ..repeat();

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
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.35),
                      widget.color.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Rotating ring with satellite dot
              Transform.rotate(
                angle: angle,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Align(
                    alignment: const Alignment(0, -1),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: widget.color,
                      ),
                    ),
                  ),
                ),
              ),
              // Core
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color,
                      widget.color.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.55),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
