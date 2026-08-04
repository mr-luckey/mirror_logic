import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

/// Board sprites decoded once for the whole session, reloaded when the hall
/// changes so floor / wall / crystal textures match the equipped theme.
@immutable
class GameArt {
  const GameArt({
    this.crystal,
    this.emitter,
    this.wallHorizontal,
    this.wallVertical,
    this.floor,
    this.atmosphere,
    this.themeId = ThemeCatalog.starterId,
    this.usesThemeCrystal = false,
  });

  final ui.Image? crystal;
  final ui.Image? emitter;
  final ui.Image? wallHorizontal;
  final ui.Image? wallVertical;
  final ui.Image? floor;
  final ui.Image? atmosphere;
  final String themeId;

  /// True when [crystal] is a hall-specific sprite (skip generic tint).
  final bool usesThemeCrystal;

  /// Latest decode, or null until [ensureLoaded] finishes. Listen to it so the
  /// board can paint immediately on later visits instead of waiting a frame.
  static final ValueNotifier<GameArt?> notifier = ValueNotifier(null);

  static Future<void>? _pending;
  static String? _loadedThemeId;
  static ui.Image? _sharedCrystal;
  static ui.Image? _sharedEmitter;

  static Future<void> ensureLoaded() =>
      _pending ??= loadForTheme(ThemeController.current.id);

  /// Reload hall textures when the player equips a different theme.
  static Future<void> loadForTheme(String themeId) {
    if (_loadedThemeId == themeId && notifier.value != null) {
      return Future.value();
    }
    _pending = _load(themeId);
    return _pending!;
  }

  /// Every board / theme image the game can ask for.
  static List<String> get assetPaths {
    final paths = <String>{
      'assets/images/medieval/crystal_cut.webp',
      'assets/images/medieval/emitter_cut.webp',
    };
    for (final t in ThemeCatalog.all) {
      paths.add(t.floorAsset);
      paths.add(t.wallHAsset);
      paths.add(t.wallVAsset);
      paths.add(t.thumbAsset);
      if (t.atmosphereAsset != null) paths.add(t.atmosphereAsset!);
      if (t.crystalAsset != null) paths.add(t.crystalAsset!);
    }
    return paths.toList()..sort();
  }

  static Future<void> _load(String themeId) async {
    final theme = ThemeCatalog.byId(themeId);
    _sharedCrystal ??= await _decode(
      'assets/images/medieval/crystal_cut.webp',
    );
    _sharedEmitter ??= await _decode(
      'assets/images/medieval/emitter_cut.webp',
    );

    final themedCrystal = theme.crystalAsset != null
        ? await _decode(theme.crystalAsset!)
        : null;

    final images = await Future.wait<ui.Image?>([
      _decode(theme.wallHAsset),
      _decode(theme.wallVAsset),
      _decode(theme.floorAsset),
      if (theme.atmosphereAsset != null) _decode(theme.atmosphereAsset!),
    ]);

    _loadedThemeId = themeId;
    notifier.value = GameArt(
      crystal: themedCrystal ?? _sharedCrystal,
      emitter: _sharedEmitter,
      wallHorizontal: images[0],
      wallVertical: images[1],
      floor: images[2],
      atmosphere: theme.atmosphereAsset != null ? images[3] : null,
      themeId: themeId,
      usesThemeCrystal: themedCrystal != null,
    );
  }

  /// A missing sprite is not fatal — the painter has a drawn fallback for each.
  static Future<ui.Image?> _decode(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
