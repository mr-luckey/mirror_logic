import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Board sprites decoded once for the whole session.
///
/// Every level used to decode these four PNGs again on entry, which cost a
/// visible hitch on low-end phones and threw the old frames away. They are
/// immutable and small, so one decode serves the entire run.
@immutable
class GameArt {
  const GameArt({
    this.crystal,
    this.emitter,
    this.wallHorizontal,
    this.wallVertical,
  });

  final ui.Image? crystal;
  final ui.Image? emitter;
  final ui.Image? wallHorizontal;
  final ui.Image? wallVertical;

  /// Latest decode, or null until [ensureLoaded] finishes. Listen to it so the
  /// board can paint immediately on later visits instead of waiting a frame.
  static final ValueNotifier<GameArt?> notifier = ValueNotifier(null);

  static Future<void>? _pending;

  static Future<void> ensureLoaded() => _pending ??= _load();

  static Future<void> _load() async {
    final images = await Future.wait<ui.Image?>([
      _decode('assets/images/medieval/crystal_cut.png'),
      _decode('assets/images/medieval/emitter_cut.png'),
      _decode('assets/images/medieval/wall_h_cut.png'),
      _decode('assets/images/medieval/wall_v_cut.png'),
    ]);
    notifier.value = GameArt(
      crystal: images[0],
      emitter: images[1],
      wallHorizontal: images[2],
      wallVertical: images[3],
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
