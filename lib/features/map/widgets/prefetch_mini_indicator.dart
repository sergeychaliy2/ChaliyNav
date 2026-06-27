import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/tile_prefetcher.dart';

/// Compact pill shown on the map while the visible area is being saved to
/// the offline cache (auto zoom-range prefetch). Mirrors
/// [DownloadMiniIndicator] but in cyan, so the two are distinguishable, and
/// so the user always knows when background tile data is being used.
class PrefetchMiniIndicator extends ConsumerWidget {
  const PrefetchMiniIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(tilePrefetchProvider);
    if (!st.active || st.total == 0) return const SizedBox.shrink();
    final pct = (st.progress * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgDeepest.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withValues(alpha: 0.2),
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
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                  backgroundColor: AppColors.glassBorderStrong,
                ),
              ),
              const SizedBox(width: 8),
              Icon(PhosphorIconsDuotone.stack,
                  color: AppColors.accentCyan, size: 14),
              const SizedBox(width: 6),
              Text(
                'Кеш $pct%',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
