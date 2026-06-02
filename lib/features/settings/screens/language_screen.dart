import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/providers/locale_provider.dart';

/// Dedicated full-screen language picker. Tap a language card → it applies
/// everywhere immediately (MaterialApp reads `localeProvider` live).
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final s = AppStrings.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: s.settingsLanguage,
        subtitle: current.nativeLabel,
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
          bottom: 32,
        ),
        children: [
          for (var i = 0; i < AppLocale.values.length; i++) ...[
            _LangCard(
              locale: AppLocale.values[i],
              selected: AppLocale.values[i] == current,
              onTap: () async {
                await ref
                    .read(localeProvider.notifier)
                    .set(AppLocale.values[i]);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Text(AppLocale.values[i].flag,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text('${s.langAppliedBanner}: '
                            '${AppLocale.values[i].label}'),
                      ],
                    ),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ).animate().fadeIn(
                  duration: 220.ms,
                  delay: (i * 40).ms,
                ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.info,
                    color: AppColors.textTertiary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.langPartialNotice,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
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

class _LangCard extends StatelessWidget {
  const _LangCard({
    required this.locale,
    required this.selected,
    required this.onTap,
  });
  final AppLocale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderColor: selected
          ? AppColors.primaryGlow.withValues(alpha: 0.6)
          : null,
      fillColor: selected
          ? AppColors.primary.withValues(alpha: 0.15)
          : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassFillStrong,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(locale.flag, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.nativeLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  locale.locale.toLanguageTag(),
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(PhosphorIconsFill.checkCircle,
                color: AppColors.primaryGlow, size: 22)
          else
            Icon(PhosphorIconsRegular.caretRight,
                color: AppColors.textTertiary, size: 16),
        ],
      ),
    );
  }
}
