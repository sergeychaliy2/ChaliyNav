import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/services/download_manager.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final l10n = AppStrings.of(context);
    final active = tasks
        .where((t) =>
            t.status == DownloadStatus.running ||
            t.status == DownloadStatus.queued)
        .toList();
    final paused = tasks
        .where((t) => t.status == DownloadStatus.paused)
        .toList();
    final finished = tasks
        .where((t) =>
            t.status == DownloadStatus.completed ||
            t.status == DownloadStatus.failed ||
            t.status == DownloadStatus.cancelled)
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: l10n.downloadsTitle,
        subtitle: tasks.isEmpty
            ? null
            : '${active.length} ${l10n.downloadsActive.toLowerCase()} · '
                '${finished.length + paused.length} ${l10n.downloadsDone.toLowerCase()}',
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textPrimary),
        ),
      ),
      body: tasks.isEmpty
          ? Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
              ),
              child: EmptyState(
                icon: const Icon(PhosphorIconsDuotone.cloudArrowDown),
                title: l10n.downloadsEmpty,
                description: l10n.downloadAreaHint,
              ),
            )
          : ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 80,
                left: 16,
                right: 16,
                bottom: 32,
              ),
              children: [
                if (active.isNotEmpty) ...[
                  _header(l10n.downloadsActive.toUpperCase()),
                  ...active.map((t) => _TaskTile(task: t)),
                  const SizedBox(height: 16),
                ],
                if (paused.isNotEmpty) ...[
                  _header('НА ПАУЗЕ'),
                  ...paused.map((t) => _TaskTile(task: t)),
                  const SizedBox(height: 16),
                ],
                if (finished.isNotEmpty) ...[
                  _header(l10n.downloadsDone.toUpperCase()),
                  ...finished.map((t) => _TaskTile(task: t)),
                ],
              ],
            ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _TaskTile extends ConsumerStatefulWidget {
  const _TaskTile({required this.task});
  final DownloadTask task;

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> {
  String? _fileSize;

  @override
  void initState() {
    super.initState();
    _readFileSize();
  }

  @override
  void didUpdateWidget(covariant _TaskTile old) {
    super.didUpdateWidget(old);
    // Re-read when the path or progress changes.
    if (old.task.outputPath != widget.task.outputPath ||
        old.task.downloadedTiles != widget.task.downloadedTiles) {
      _readFileSize();
    }
  }

  Future<void> _readFileSize() async {
    final path = widget.task.outputPath;
    if (path == null) {
      if (mounted) setState(() => _fileSize = null);
      return;
    }
    try {
      final f = File(path);
      if (!await f.exists()) {
        if (mounted) setState(() => _fileSize = null);
        return;
      }
      final bytes = await f.length();
      if (mounted) setState(() => _fileSize = _formatBytes(bytes));
    } catch (_) {
      if (mounted) setState(() => _fileSize = null);
    }
  }

  static String _formatBytes(int b) {
    if (b < 1024) return '$b Б';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} КБ';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} МБ';
    }
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} ГБ';
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final pct = (task.progress * 100).round();
    final color = _statusColor(task.status);
    final isActive = task.status == DownloadStatus.running ||
        task.status == DownloadStatus.queued;
    final isResumable = task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.cancelled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(task.status), color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${task.status.label} · ${task.minZoom}–${task.maxZoom}'
                        '${_fileSize != null ? " · $_fileSize" : ""}',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  IconButton(
                    onPressed: () => ref
                        .read(downloadManagerProvider.notifier)
                        .cancel(task.id),
                    icon: Icon(PhosphorIconsBold.pause,
                        color: AppColors.accentAmber, size: 16),
                    tooltip: 'Пауза',
                    visualDensity: VisualDensity.compact,
                  ),
                if (isResumable)
                  IconButton(
                    onPressed: () => ref
                        .read(downloadManagerProvider.notifier)
                        .resume(task.id),
                    icon: Icon(PhosphorIconsBold.play,
                        color: AppColors.primaryGlow, size: 16),
                    tooltip: 'Возобновить',
                    visualDensity: VisualDensity.compact,
                  ),
                // Delete is always available (even during active download
                // — it safely cancels + removes file + layer).
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(PhosphorIconsDuotone.trash,
                      color: AppColors.error, size: 16),
                  tooltip: AppStrings.of(context).commonDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: task.status == DownloadStatus.completed
                    ? 1.0
                    : task.progress,
                backgroundColor: AppColors.glassFillStrong,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${task.downloadedTiles} / ${task.totalTiles} ${AppStrings.of(context).downloadsTiles}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  '$pct%',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (task.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(PhosphorIconsDuotone.info,
                        color: AppColors.error, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.error!,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Удалить «${widget.task.name}»?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Задача, скачанные тайлы на диске и соответствующий слой на '
          'карте будут удалены. Это действие нельзя отменить.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(downloadManagerProvider.notifier)
        .deleteTask(widget.task.id);
  }

  IconData _statusIcon(DownloadStatus s) => switch (s) {
        DownloadStatus.queued => PhosphorIconsDuotone.clock,
        DownloadStatus.running => PhosphorIconsDuotone.cloudArrowDown,
        DownloadStatus.paused => PhosphorIconsDuotone.pauseCircle,
        DownloadStatus.completed => PhosphorIconsDuotone.checkCircle,
        DownloadStatus.failed => PhosphorIconsDuotone.warningCircle,
        DownloadStatus.cancelled => PhosphorIconsDuotone.prohibit,
      };

  Color _statusColor(DownloadStatus s) => switch (s) {
        DownloadStatus.queued => AppColors.textSecondary,
        DownloadStatus.running => AppColors.primaryGlow,
        DownloadStatus.paused => AppColors.accentAmber,
        DownloadStatus.completed => AppColors.success,
        DownloadStatus.failed => AppColors.error,
        DownloadStatus.cancelled => AppColors.textTertiary,
      };
}
