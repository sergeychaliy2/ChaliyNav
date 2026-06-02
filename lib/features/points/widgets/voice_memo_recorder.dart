import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/services/audio_memo_service.dart';

/// Tappable mic button that records an audio memo on press-hold.
/// Emits the resulting file path to [onRecorded].
class VoiceMemoRecorderButton extends StatefulWidget {
  const VoiceMemoRecorderButton({
    super.key,
    required this.onRecorded,
    this.existingPath,
    this.onCleared,
  });

  final ValueChanged<String> onRecorded;
  final String? existingPath;
  final VoidCallback? onCleared;

  @override
  State<VoiceMemoRecorderButton> createState() =>
      _VoiceMemoRecorderButtonState();
}

class _VoiceMemoRecorderButtonState extends State<VoiceMemoRecorderButton> {
  final _service = AudioMemoService();
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _service.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      final path = await _service.stop();
      _ticker?.cancel();
      setState(() {
        _recording = false;
        _elapsed = Duration.zero;
      });
      if (path != null) widget.onRecorded(path);
      return;
    }

    final start = await _service.start();
    if (start == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нужно разрешение на микрофон'),
        ),
      );
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(milliseconds: 250));
    });
    setState(() => _recording = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      final mm = _elapsed.inMinutes.toString().padLeft(2, '0');
      final ss = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
      return GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentRose.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.accentRose.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentRose,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(
                    duration: 600.ms,
                  ),
              const SizedBox(width: 8),
              Text(
                '$mm:$ss',
                style: const TextStyle(
                  color: AppColors.accentRose,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Icon(PhosphorIconsFill.stopCircle,
                  color: AppColors.accentRose, size: 18),
            ],
          ),
        ),
      );
    }

    if (widget.existingPath != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsFill.microphone,
              color: AppColors.primaryGlow, size: 18),
          const SizedBox(width: 6),
          Text(
            'Есть аудио',
            style: TextStyle(
              color: AppColors.primaryGlow,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.onCleared != null)
            IconButton(
              onPressed: widget.onCleared,
              icon: Icon(PhosphorIconsBold.x,
                  color: AppColors.textTertiary, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              visualDensity: VisualDensity.compact,
            ),
        ],
      );
    }

    return IconButton(
      onPressed: _toggle,
      icon: Icon(PhosphorIconsDuotone.microphone,
          color: AppColors.primaryGlow),
      tooltip: 'Записать аудио-заметку',
    );
  }
}
