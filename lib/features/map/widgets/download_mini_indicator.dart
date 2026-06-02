import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/services/download_manager.dart';

/// Compact pill shown on the map top-right while downloads are active.
/// Tap → opens /settings/downloads.
class DownloadMiniIndicator extends ConsumerWidget {
  const DownloadMiniIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final active = tasks
        .where((t) =>
            t.status == DownloadStatus.running ||
            t.status == DownloadStatus.queued)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    // Overall progress = mean across active tasks.
    final avg = active.fold<double>(0, (a, t) => a + t.progress) / active.length;
    final pct = (avg * 100).round();

    return GestureDetector(
      onTap: () => context.push('/settings/downloads'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgDeepest.withValues(alpha: 0.75),
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
                    value: avg,
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGlow),
                    backgroundColor: AppColors.glassBorderStrong,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(PhosphorIconsDuotone.cloudArrowDown,
                    color: AppColors.primaryGlow, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${active.length} · $pct%',
                  style: TextStyle(
                    color: AppColors.primaryGlow,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
