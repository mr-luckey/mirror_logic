import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds
  static const Color primaryDark = Color(0xFF080810);
  static const Color secondaryDark = Color(0xFF12121F);
  static const Color panel = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF16213E);

  // Accent spectrum — electric violet → hot pink → neon mint
  static const Color accent = Color(0xFFBB86FC);
  static const Color accentBright = Color(0xFFE040FB);
  static const Color cyan = Color(0xFF00F5D4);
  static const Color crystal = Color(0xFF00E5FF);
  static const Color hotPink = Color(0xFFFF006E);
  static const Color laserRed = Color(0xFFFF2D55);

  // Gold / reward
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDeep = Color(0xFFFFAB00);

  // Utility
  static const Color glassBorder = Color(0x22FFFFFF);
  static const Color muted = Color(0xFF6B7394);
  static const Color textPrimary = Color(0xFFF0F0FF);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0F0C29),
      Color(0xFF302B63),
      Color(0xFF0F0C29),
    ],
  );

  static const LinearGradient accentButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBright, hotPink],
  );

  @Deprecated('Use accentButton instead')
  static const LinearGradient goldButton = accentButton;

  static const LinearGradient cyanGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, crystal],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
    ],
  );
}
