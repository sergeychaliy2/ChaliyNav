import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum GlassButtonVariant { primary, secondary, ghost, danger }

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = GlassButtonVariant.primary,
    this.expanded = false,
    this.small = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final GlassButtonVariant variant;
  final bool expanded;
  final bool small;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final v = widget.variant;

    final bg = switch (v) {
      GlassButtonVariant.primary => AppColors.primaryBright,
      GlassButtonVariant.secondary => AppColors.glassFillStrong,
      GlassButtonVariant.ghost => Colors.transparent,
      GlassButtonVariant.danger => AppColors.error,
    };

    final fg = switch (v) {
      GlassButtonVariant.primary => Colors.white,
      GlassButtonVariant.secondary => AppColors.textPrimary,
      GlassButtonVariant.ghost => AppColors.textPrimary,
      GlassButtonVariant.danger => Colors.white,
    };

    final border = switch (v) {
      GlassButtonVariant.primary => null,
      GlassButtonVariant.secondary => AppColors.glassBorderStrong,
      GlassButtonVariant.ghost => AppColors.glassBorder,
      GlassButtonVariant.danger => null,
    };

    final hPad = widget.small ? 16.0 : 22.0;
    final vPad = widget.small ? 10.0 : 14.0;
    final radius = BorderRadius.circular(widget.small ? 14 : 16);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: enabled ? bg : bg.withValues(alpha: 0.4),
        borderRadius: radius,
        border: border != null ? Border.all(color: border, width: 1) : null,
        boxShadow: v == GlassButtonVariant.primary && enabled
            ? [
                BoxShadow(
                  color: AppColors.primaryBright.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            IconTheme(
              data: IconThemeData(color: fg, size: widget.small ? 16 : 18),
              child: widget.icon!,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: widget.small ? 13 : 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (v == GlassButtonVariant.ghost || v == GlassButtonVariant.secondary) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: content,
        ),
      );
    }

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: content,
    );
  }
}
