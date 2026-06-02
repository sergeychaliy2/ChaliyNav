import 'package:flutter/material.dart';

/// ChaliyNav color palette — dark glassmorphism forest.
/// Inspired by deep forest night + bioluminescence accents.
class AppColors {
  AppColors._();

  // === Base backgrounds ===
  static const Color bgDeepest = Color(0xFF0A1410);
  static const Color bgDeep = Color(0xFF0F1F18);
  static const Color bgSurface = Color(0xFF14261E);
  static const Color bgElevated = Color(0xFF1A3326);
  static const Color bgCard = Color(0xFF1F3B2C);

  // === Primary brand — forest green ===
  static const Color primary = Color(0xFF1B6B3A);
  static const Color primaryBright = Color(0xFF2ECC71);
  static const Color primaryGlow = Color(0xFF4ADE80);
  static const Color primaryDim = Color(0xFF134826);

  // === Accents ===
  static const Color accent = Color(0xFF2ECC71);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentAmber = Color(0xFFFBBF24);
  static const Color accentRose = Color(0xFFFB7185);
  static const Color accentViolet = Color(0xFFA78BFA);

  // === Track colors (different recording sessions) ===
  static const List<Color> trackColors = [
    Color(0xFF2ECC71), // green
    Color(0xFFFBBF24), // amber
    Color(0xFFFB7185), // rose
    Color(0xFF22D3EE), // cyan
    Color(0xFFA78BFA), // violet
    Color(0xFFF97316), // orange
    Color(0xFFEC4899), // pink
    Color(0xFF60A5FA), // blue
  ];

  // === POI category tint (for icon backgrounds) ===
  static const Color poiFishing = Color(0xFF22D3EE);
  static const Color poiHunting = Color(0xFFEF4444);
  static const Color poiTourism = Color(0xFF10B981);
  static const Color poiMushrooms = Color(0xFFF97316);
  static const Color poiTreasure = Color(0xFFFBBF24);
  static const Color poiInfra = Color(0xFF8B5CF6);
  static const Color poiDanger = Color(0xFFDC2626);
  static const Color poiOther = Color(0xFF64748B);

  // === Text ===
  static const Color textPrimary = Color(0xFFE8F5EE);
  static const Color textSecondary = Color(0xFF9FBFAE);
  static const Color textTertiary = Color(0xFF5F7A6D);
  static const Color textDisabled = Color(0xFF3A4F45);

  // === Semantic ===
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF22D3EE);

  // === Glass / borders ===
  static Color glassFill = Colors.white.withValues(alpha: 0.04);
  static Color glassFillStrong = Colors.white.withValues(alpha: 0.08);
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);
  static Color glassBorderStrong = Colors.white.withValues(alpha: 0.14);
  static Color divider = Colors.white.withValues(alpha: 0.06);

  // === Shadows ===
  static const Color shadowDeep = Color(0xCC000000);
  static const Color shadowSoft = Color(0x66000000);

  // === Gradients ===
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDeepest, bgDeep, bgSurface],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryBright],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1AFFFFFF),
      Color(0x05FFFFFF),
    ],
  );

  static const LinearGradient accentGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x552ECC71),
      Color(0x00000000),
    ],
  );
}
