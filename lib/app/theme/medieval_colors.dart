import 'package:flutter/material.dart';

/// Fantasy medieval wooden palette matching the gameplay screenshot.
abstract final class MedievalColors {
  static const Color woodDeep = Color(0xFF1A0F08);
  static const Color woodMid = Color(0xFF2D1B0D);
  static const Color woodPlank = Color(0xFF3D2B1F);
  static const Color woodLight = Color(0xFF4A3424);

  static const Color bronzeDark = Color(0xFF5C3A1E);
  static const Color bronze = Color(0xFF8B5E34);
  static const Color bronzeMid = Color(0xFFA8723C);
  static const Color bronzeLight = Color(0xFFD4AF37);
  static const Color bronzeHighlight = Color(0xFFF3CF7A);

  static const Color stoneDark = Color(0xFF1E1E1E);
  static const Color stone = Color(0xFF2B2B2B);
  static const Color stoneLight = Color(0xFF3A3A3A);
  static const Color stoneGrout = Color(0xFF141414);

  static const Color laserCore = Color(0xFFCCFFFF);
  static const Color laserMid = Color(0xFF00F2FF);
  static const Color laserGlow = Color(0xFF40C8FF);
  static const Color crystal = Color(0xFF80D0FF);
  static const Color crystalDeep = Color(0xFF2090C0);

  static const Color parchment = Color(0xFFD4C4A0);
  static const Color parchmentDark = Color(0xFFB8A47A);
  static const Color parchmentInk = Color(0xFF3A2A18);

  static const Color textGold = Color(0xFFF3CF7A);
  static const Color textCream = Color(0xFFE5E5E5);
  static const Color textMuted = Color(0xFFB8A888);

  static const Color torchOrange = Color(0xFFFF8C22);
  static const Color torchYellow = Color(0xFFFFD060);
  static const Color torchCore = Color(0xFFFFF0A0);

  static const Color greenPlus = Color(0xFF4CAF50);
  static const Color vineGreen = Color(0xFF2E5A2E);

  static const LinearGradient bronzeMetal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      bronzeHighlight,
      bronzeLight,
      bronze,
      bronzeDark,
    ],
    stops: [0.0, 0.25, 0.65, 1.0],
  );

  static const LinearGradient woodPanel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [woodLight, woodMid, woodDeep],
  );

  static const LinearGradient laserGradient = LinearGradient(
    colors: [laserCore, laserMid, laserGlow],
  );
}
