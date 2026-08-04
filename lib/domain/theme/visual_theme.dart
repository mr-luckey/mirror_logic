import 'package:flutter/material.dart';

/// Visual pack for the whole app chrome + board paint.
///
/// Beam math, unlocks, and level JSON stay untouched — themes swap colors,
/// floor/wall textures, and atmosphere cutouts.
class VisualTheme {
  const VisualTheme({
    required this.id,
    required this.name,
    required this.unlockLevel,
    required this.coinPrice,
    required this.woodDeep,
    required this.woodMid,
    required this.woodPlank,
    required this.woodLight,
    required this.bronzeDark,
    required this.bronze,
    required this.bronzeMid,
    required this.bronzeLight,
    required this.bronzeHighlight,
    required this.stoneDark,
    required this.stone,
    required this.stoneLight,
    required this.stoneGrout,
    required this.laserCore,
    required this.laserMid,
    required this.laserGlow,
    required this.crystal,
    required this.crystalDeep,
    required this.parchment,
    required this.parchmentDark,
    required this.parchmentInk,
    required this.textGold,
    required this.textCream,
    required this.textMuted,
    required this.torchOrange,
    required this.torchYellow,
    required this.torchCore,
    required this.vineGreen,
    required this.wallTint,
    required this.floorAsset,
    required this.wallHAsset,
    required this.wallVAsset,
    this.atmosphereAsset,
    this.crystalAsset,
    this.accentGlow,
  });

  final String id;
  final String name;

  /// Continuous display level the player must reach before the theme can be
  /// bought (Level 1, 25, 50…).
  final int unlockLevel;

  /// Coin cost once unlocked. Zero for the starter theme.
  final int coinPrice;

  final Color woodDeep;
  final Color woodMid;
  final Color woodPlank;
  final Color woodLight;

  final Color bronzeDark;
  final Color bronze;
  final Color bronzeMid;
  final Color bronzeLight;
  final Color bronzeHighlight;

  final Color stoneDark;
  final Color stone;
  final Color stoneLight;
  final Color stoneGrout;

  final Color laserCore;
  final Color laserMid;
  final Color laserGlow;
  final Color crystal;
  final Color crystalDeep;

  final Color parchment;
  final Color parchmentDark;
  final Color parchmentInk;

  final Color textGold;
  final Color textCream;
  final Color textMuted;

  final Color torchOrange;
  final Color torchYellow;
  final Color torchCore;

  final Color vineGreen;

  /// Kept for soft accents; board walls now use dedicated sprites.
  final Color wallTint;

  /// Seamless board floor texture.
  final String floorAsset;

  /// Horizontal / vertical maze wall strips for this hall.
  final String wallHAsset;
  final String wallVAsset;

  /// Optional transparent overlay (moon, lava, vines…).
  final String? atmosphereAsset;

  /// Optional hall-specific target crystal sprite. Null uses the shared crystal.
  final String? crystalAsset;

  /// Soft ambient wash over the board / menus.
  final Color? accentGlow;

  bool get isFree => coinPrice <= 0;

  /// Premium carousel card art: `assets/images/themes/<id>/thumb.webp`.
  String get thumbAsset => _pack(id, 'thumb.webp');

  /// Short label for hero cards (`Golden Sun Temple` → `Golden Sun`).
  String get shortName {
    final trimmed = name.replaceAll(RegExp(r'\s+Temple$'), '').trim();
    return trimmed.isEmpty ? name : trimmed;
  }

  LinearGradient get bronzeMetal => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bronzeHighlight, bronzeLight, bronze, bronzeDark],
    stops: const [0.0, 0.25, 0.65, 1.0],
  );

  LinearGradient get woodPanel => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [woodLight, woodMid, woodDeep],
  );

  LinearGradient get laserGradient => LinearGradient(
    colors: [laserCore, laserMid, laserGlow],
  );

  static String _pack(String id, String file) =>
      'assets/images/themes/$id/$file';

  /// Shared path helpers so the catalog stays short.
  static String floorOf(String id) => _pack(id, 'floor.webp');
  static String wallHOf(String id) => _pack(id, 'wall_h.webp');
  static String wallVOf(String id) => _pack(id, 'wall_v.webp');
  static String atmosphereOf(String id) => _pack(id, 'atmosphere.webp');
}
