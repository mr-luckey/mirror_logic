import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

class LevelCompleteArgs {
  const LevelCompleteArgs({
    required this.levelId,
    required this.chapterId,
    required this.levelIndex,
    required this.stars,
    required this.moves,
    required this.timeSeconds,
    required this.coinsEarned,
    this.nextLevelId,
  });

  final String levelId;
  final String chapterId;
  final int levelIndex;
  final int stars;
  final int moves;
  final double timeSeconds;
  final int coinsEarned;
  final String? nextLevelId;
}

class LevelCompleteScreen extends StatelessWidget {
  const LevelCompleteScreen({super.key, required this.args});

  final LevelCompleteArgs args;

  static const _rank = ['Cleared', 'Well Struck', 'Masterful', 'Flawless'];

  @override
  Widget build(BuildContext context) {
    final time = args.timeSeconds;
    final timeLabel =
        '${time.floor() ~/ 60}:${(time.floor() % 60).toString().padLeft(2, '0')}';
    final gutter = Responsive.pageGutter(context);
    final short = Responsive.isShort(context);
    final wreath = Responsive.wp(context, short ? 0.5 : 0.6).clamp(180.0, 300.0);

    return MedievalWoodBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Trophy(size: wreath, stars: args.stars),
                      SizedBox(height: short ? 8 : 14),
                      Text(
                        _rank[args.stars.clamp(0, 3)].toUpperCase(),
                        maxLines: 1,
                        style: MedievalTextStyles.cinzelDecorative(
                          size: Responsive.sp(context, 21),
                          weight: FontWeight.w700,
                          letterSpacing: 2,
                          color: MedievalColors.textGold,
                        ).copyWith(
                          shadows: [
                            Shadow(
                              color: MedievalColors.bronzeHighlight
                                  .withValues(alpha: 0.6),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 550.ms).slideY(
                            begin: 0.25,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
                      const SizedBox(height: 4),
                      Text(
                        'Level ${args.levelIndex}',
                        style: MedievalTextStyles.cinzel(
                          size: Responsive.sp(context, 11),
                          letterSpacing: 2,
                          color: MedievalColors.textMuted,
                        ),
                      ).animate().fadeIn(delay: 650.ms),
                      SizedBox(height: short ? 14 : 20),
                      MedievalPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            _stat(context, 'Moves', '${args.moves}'),
                            const MedievalDivider(),
                            _stat(context, 'Time', timeLabel),
                            const MedievalDivider(),
                            _stat(
                              context,
                              'Coin',
                              '+${args.coinsEarned}',
                              highlight: true,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 750.ms).slideY(
                            begin: 0.1,
                            end: 0,
                          ),
                      SizedBox(height: short ? 16 : 24),
                      if (args.nextLevelId != null) ...[
                        MedievalButton(
                          label: 'Next Level',
                          style: MedievalButtonStyle.primary,
                          icon: Icons.arrow_forward_rounded,
                          shimmer: true,
                          onPressed: () => context
                              .pushReplacement('/play/${args.nextLevelId}'),
                        ).animate().fadeIn(delay: 900.ms),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: MedievalButton(
                              label: 'Replay',
                              icon: Icons.refresh_rounded,
                              onPressed: () => context
                                  .pushReplacement('/play/${args.levelId}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MedievalButton(
                              label: 'Levels',
                              icon: Icons.grid_view_rounded,
                              onPressed: () =>
                                  context.go('/levels/${args.chapterId}'),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 1000.ms),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: MedievalTextStyles.cinzel(
                color: MedievalColors.textMuted,
                letterSpacing: 1.6,
                size: Responsive.sp(context, 11),
              ),
            ),
          ),
          Text(
            value,
            style: MedievalTextStyles.cinzelDecorative(
              weight: FontWeight.w700,
              size: Responsive.sp(context, 17),
              color: highlight
                  ? MedievalColors.bronzeHighlight
                  : MedievalColors.textCream,
            ),
          ),
        ],
      ),
    );
  }
}

/// The laurel wreath with the earned stars set inside its opening.
class _Trophy extends StatelessWidget {
  const _Trophy({required this.size, required this.stars});

  final double size;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final starSize = size * 0.17;

    return SizedBox(
      width: size,
      height: size * 0.92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MedievalArtwork(
            asset: MedievalArt.wreath,
            size: size,
            glowStrength: 0.22,
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack)
              .then()
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.02, 1.02),
                duration: 2400.ms,
              ),
          Align(
            alignment: const Alignment(0, -0.18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final lit = i < stars;
                // The middle star sits proud of the other two.
                final scale = i == 1 ? 1.24 : 1.0;
                return Padding(
                  padding: EdgeInsets.only(
                    left: 2,
                    right: 2,
                    bottom: i == 1 ? starSize * 0.22 : 0,
                  ),
                  child: Icon(
                    lit ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: starSize * scale,
                    color: lit
                        ? MedievalColors.bronzeHighlight
                        : MedievalColors.bronzeDark,
                    shadows: lit
                        ? [
                            Shadow(
                              color: MedievalColors.bronzeHighlight
                                  .withValues(alpha: 0.85),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  )
                      .animate(delay: (320 + 170 * i).ms)
                      .scale(
                        begin: const Offset(0.2, 0.2),
                        end: const Offset(1, 1),
                        curve: Curves.elasticOut,
                        duration: 700.ms,
                      )
                      .fadeIn(duration: 200.ms),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
