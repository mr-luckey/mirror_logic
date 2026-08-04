import 'package:flutter/material.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/domain/theme/visual_theme.dart';

/// Fantasy palette for the active [VisualTheme].
///
/// Call sites stay as `MedievalColors.woodDeep` etc. Widgets that paint these
/// tokens must call [ThemeController.watch] so [ThemeScope] can rebuild them
/// when a hall is equipped — static getters alone do not register a dependency.
abstract final class MedievalColors {
  static VisualTheme get _t => ThemeController.current;

  static Color get woodDeep => _t.woodDeep;
  static Color get woodMid => _t.woodMid;
  static Color get woodPlank => _t.woodPlank;
  static Color get woodLight => _t.woodLight;

  static Color get bronzeDark => _t.bronzeDark;
  static Color get bronze => _t.bronze;
  static Color get bronzeMid => _t.bronzeMid;
  static Color get bronzeLight => _t.bronzeLight;
  static Color get bronzeHighlight => _t.bronzeHighlight;

  static Color get stoneDark => _t.stoneDark;
  static Color get stone => _t.stone;
  static Color get stoneLight => _t.stoneLight;
  static Color get stoneGrout => _t.stoneGrout;

  static Color get laserCore => _t.laserCore;
  static Color get laserMid => _t.laserMid;
  static Color get laserGlow => _t.laserGlow;
  static Color get crystal => _t.crystal;
  static Color get crystalDeep => _t.crystalDeep;

  static Color get parchment => _t.parchment;
  static Color get parchmentDark => _t.parchmentDark;
  static Color get parchmentInk => _t.parchmentInk;

  static Color get textGold => _t.textGold;
  static Color get textCream => _t.textCream;
  static Color get textMuted => _t.textMuted;

  static Color get torchOrange => _t.torchOrange;
  static Color get torchYellow => _t.torchYellow;
  static Color get torchCore => _t.torchCore;

  static const Color greenPlus = Color(0xFF4CAF50);
  static Color get vineGreen => _t.vineGreen;

  /// A hit that does not count: the beam reached the crystal by a route the
  /// puzzle rejects.
  static const Color rejectCore = Color(0xFFFFD6D6);
  static const Color rejectMid = Color(0xFFFF3B30);
  static const Color rejectGlow = Color(0xFFC01818);

  static LinearGradient get bronzeMetal => _t.bronzeMetal;
  static LinearGradient get woodPanel => _t.woodPanel;
  static LinearGradient get laserGradient => _t.laserGradient;

  static Color get wallTint => _t.wallTint;
  static Color? get accentGlow => _t.accentGlow;
  static String? get atmosphereAsset => _t.atmosphereAsset;
  static String get themeId => _t.id;
}
