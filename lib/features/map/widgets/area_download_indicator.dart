import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/area_downloader.dart';

/// Compact pill shown on the map while a manual "download area" job runs.
/// Shows progress and a ✕ to cancel. Hidden when idle.
class AreaDownloadIndicator extends ConsumerWidget {
  const AreaDownloadIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(areaDownloadProvider);
    if (!st.active || st.total == 0) return const SizedBox.shrink();
    final pct = (st.progress * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.bgDeepest.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.primaryGlow.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGlow.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  value: st.progress,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGlow),
                  backgroundColor: AppColors.glassBorderStrong,
                ),
              ),
              const SizedBox(width: 8),
              Icon(PhosphorIconsDuotone.downloadSimple,
                  color: AppColors.primaryGlow, size: 14),
              const SizedBox(width: 6),
              Text(
                'Карта $pct%',
                style: TextStyle(
                  color: AppColors.primaryGlow,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      ref.read(areaDownloadProvider.notifier).cancel(),
                  borderRadius: BorderRadius.circular(100),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(PhosphorIconsBold.x,
                        color: AppColors.textSecondary, size: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
