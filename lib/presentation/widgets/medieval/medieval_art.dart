import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

/// Cut-out illustration assets used by the menus.
abstract final class MedievalArt {
  static const crest = 'assets/images/ui/crest.webp';
  static const tome = 'assets/images/ui/tome.webp';
  static const wreath = 'assets/images/ui/wreath.webp';
  static const padlock = 'assets/images/ui/padlock.webp';
  static const vine = 'assets/images/medieval/vine_cut.webp';
  static const torchBase = 'assets/images/medieval/torch_base_cut.webp';
  static const torch = 'assets/images/medieval/torch_cut.webp';

  /// Highest chapter with its own tome; beyond this the art repeats.
  static const lastTomeChapter = 10;

  /// One distinct tome per hall so the chapter list does not look copy-pasted.
  static String tomeForChapter(String chapterId) {
    final n = int.tryParse(chapterId.replaceFirst('ch', '')) ?? 1;
    final clamped = n.clamp(1, lastTomeChapter);
    return 'assets/images/ui/tome_ch$clamped.webp';
  }

  /// Every menu asset the game can ask for. Used by a test to check each one is
  /// on disk and bundled, since the widgets fall back silently when one is not.
  static List<String> get all => [
    crest,
    tome,
    wreath,
    padlock,
    vine,
    torchBase,
    torch,
    for (var i = 1; i <= lastTomeChapter; i++) tomeForChapter('ch$i'),
  ];
}

/// A cut-out asset with a warm halo behind it, so it reads as lit by the same
/// top-left source as the rest of the furniture.
class MedievalArtwork extends StatelessWidget {
  const MedievalArtwork({
    super.key,
    required this.asset,
    required this.size,
    this.glow,
    this.glowStrength = 0.35,
    this.opacity = 1,
  });

  final String asset;
  final double size;
  final Color? glow;
  final double glowStrength;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final halo = glow ?? MedievalColors.bronzeLight;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  halo.withValues(alpha: glowStrength),
                  halo.withValues(alpha: glowStrength * 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: SizedBox(width: size, height: size),
          ),
          Opacity(
            opacity: opacity,
            child: Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
