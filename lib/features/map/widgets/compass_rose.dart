import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Animated compass rose — floating disc that rotates so its red "N"
/// arrow always points at magnetic north, while a fixed pointer at
/// the top of the widget marks where the device is "facing". Used in
/// both the full compass screen and the optional expanded HUD pill.
///
/// Pure rendering — caller passes [headingDeg] (0 = North, 90 = East)
/// from [compassHeadingProvider]. [showPointer] controls whether the
/// little static triangle at the top is drawn (off in tiny HUD
/// versions where there's no room for it). [tickStyle] picks between
/// the rich tick / cardinal layout used on the full screen and the
/// minimal one for the small HUD.
class CompassRose extends StatelessWidget {
  const CompassRose({
    super.key,
    required this.headingDeg,
    this.showPointer = true,
    this.tickStyle = CompassRoseTickStyle.full,
  });

  final double headingDeg;
  final bool showPointer;
  final CompassRoseTickStyle tickStyle;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: headingDeg, end: headingDeg),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (_, value, __) => Stack(
        alignment: Alignment.center,
        children: [
          // The rose itself rotates OPPOSITE to heading so North
          // points wherever the world's actual North is. Effect: a
          // freely-floating physical disc the device hovers over.
          Transform.rotate(
            angle: -value * math.pi / 180.0,
            child: CustomPaint(
              painter: _RosePainter(style: tickStyle),
              size: Size.infinite,
            ),
          ),
          if (showPointer)
            CustomPaint(
              painter: _PointerPainter(),
              size: Size.infinite,
            ),
        ],
      ),
    );
  }
}

/// Density of tick marks / cardinal labels. The compact style drops
/// minor ticks and only labels N/E/S/W with single Cyrillic letters
/// so the whole rose stays legible at ~50 px diameter.
enum CompassRoseTickStyle { full, compact }

class _RosePainter extends CustomPainter {
  _RosePainter({required this.style});
  final CompassRoseTickStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final isFull = style == CompassRoseTickStyle.full;

    // Outer ring.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = AppColors.glassBorder,
    );

    // Inner ring — drawn at both sizes; helps the compact rose look
    // like a miniature of the full one rather than a sparse dial.
    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.glassBorder.withValues(alpha: 0.4),
    );

    // Tick marks. Full style draws every 5°; compact every 15° so a
    // small badge still has visible tick marks at the major axes.
    final tickStep = isFull ? 5.0 : 15.0;
    final tickCount = (360 / tickStep).round();
    for (var i = 0; i < tickCount; i++) {
      final isMajor = (i * tickStep) % 90 == 0;
      final isMid = (i * tickStep) % 45 == 0;
      final tickLen = isMajor
          ? (isFull ? 14.0 : radius * 0.16)
          : (isMid
              ? (isFull ? 8.0 : radius * 0.10)
              : (isFull ? 4.0 : radius * 0.06));
      final paint = Paint()
        ..strokeWidth = isMajor ? 2.0 : 1.0
        ..color = isMajor
            ? AppColors.textPrimary
            : (isMid
                ? AppColors.textTertiary
                : AppColors.textTertiary.withValues(alpha: 0.45));
      final ang = i * tickStep * math.pi / 180.0 - math.pi / 2;
      final p1 = Offset(
        center.dx + (radius - 2) * math.cos(ang),
        center.dy + (radius - 2) * math.sin(ang),
      );
      final p2 = Offset(
        center.dx + (radius - 2 - tickLen) * math.cos(ang),
        center.dy + (radius - 2 - tickLen) * math.sin(ang),
      );
      canvas.drawLine(p1, p2, paint);
    }

    // Cardinal letters. Full style places all four; compact only the
    // North marker (red triangle below already implies it, but we
    // keep "С" too for explicitness when text is legible).
    void cardinal(String letter, double angDeg, Color color, double fontSize) {
      final ang = angDeg * math.pi / 180.0 - math.pi / 2;
      final r = radius * (isFull ? 0.78 : 0.66);
      final tp = TextPainter(
        text: TextSpan(
          text: letter,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = Offset(
        center.dx + r * math.cos(ang) - tp.width / 2,
        center.dy + r * math.sin(ang) - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }

    // Cardinal letter sizing scales with the rose radius so the
    // compact (HUD-badge) variant gets readable С / В / Ю / З without
    // overlapping the tick marks. Full-screen variant keeps its
    // generous 20 px font.
    final cardinalFont = isFull ? 20.0 : math.max(7.0, radius * 0.22);
    cardinal('С', 0, AppColors.accentRose, cardinalFont);
    cardinal('В', 90, AppColors.textPrimary, cardinalFont);
    cardinal('Ю', 180, AppColors.textPrimary, cardinalFont);
    cardinal('З', 270, AppColors.textPrimary, cardinalFont);

    // Big red "N" arrow at the rose's actual north (rotates with it).
    final nPath = Path();
    final tipR = isFull ? 0.55 : 0.5;
    final baseR = isFull ? 0.32 : 0.18;
    final nTop = Offset(center.dx, center.dy - radius * tipR);
    final nLeft = Offset(
      center.dx - radius * (isFull ? 0.05 : 0.10),
      center.dy - radius * baseR,
    );
    final nRight = Offset(
      center.dx + radius * (isFull ? 0.05 : 0.10),
      center.dy - radius * baseR,
    );
    nPath
      ..moveTo(nTop.dx, nTop.dy)
      ..lineTo(nLeft.dx, nLeft.dy)
      ..lineTo(nRight.dx, nRight.dy)
      ..close();
    canvas.drawPath(
      nPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.accentRose,
    );

    // Centre hub.
    final hubR = isFull ? 6.0 : 2.5;
    canvas.drawCircle(
      center,
      hubR,
      Paint()..color = AppColors.bgDeepest,
    );
    canvas.drawCircle(
      center,
      hubR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.primaryGlow,
    );
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) =>
      oldDelegate.style != style;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final topY = center.dy - radius - 2;
    final triangle = Path()
      ..moveTo(center.dx, topY + 14)
      ..lineTo(center.dx - 9, topY + 32)
      ..lineTo(center.dx + 9, topY + 32)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.primaryBright,
    );
    canvas.drawPath(
      triangle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
