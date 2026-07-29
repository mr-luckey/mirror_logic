import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';
import 'package:mirror_logic/presentation/widgets/glass_panel.dart';
import 'package:mirror_logic/presentation/widgets/gold_cta_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final time = args.timeSeconds;
    final timeLabel =
        '${time.floor() ~/ 60}:${(time.floor() % 60).toString().padLeft(2, '0')}';
    final gutter = Responsive.pageGutter(context);
    final starSize = Responsive.sp(context, 48).clamp(36.0, 56.0);

    return AtmosphericBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            AppColors.accentBright,
                            AppColors.gold,
                          ],
                        ).createShader(bounds),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'LEVEL COMPLETE!',
                            maxLines: 1,
                            style: AppTextStyles.orbitron(
                              size: Responsive.sp(context, 22),
                              weight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final filled = i < args.stars;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.star_rounded,
                              size: starSize,
                              color: filled
                                  ? AppColors.gold
                                  : AppColors.muted,
                              shadows: filled
                                  ? [
                                      Shadow(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.8),
                                        blurRadius: 18,
                                      ),
                                    ]
                                  : null,
                            )
                                .animate(delay: (150 * i).ms)
                                .scale(
                                  begin: const Offset(0.3, 0.3),
                                  end: const Offset(1, 1),
                                  curve: Curves.elasticOut,
                                  duration: 600.ms,
                                ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      GlassPanel(
                        child: Column(
                          children: [
                            _stat(context, 'Moves', '${args.moves}'),
                            Divider(
                                color: AppColors.accent
                                    .withValues(alpha: 0.15)),
                            _stat(context, 'Time', timeLabel),
                            Divider(
                                color: AppColors.accent
                                    .withValues(alpha: 0.15)),
                            _stat(
                              context,
                              'Reward',
                              '+${args.coinsEarned}',
                              highlight: true,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 24),
                      if (args.nextLevelId != null) ...[
                        GoldCtaButton(
                          label: 'Next Level',
                          width: double.infinity,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () =>
                              context.go('/play/${args.nextLevelId}'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: NeonOutlineButton(
                              label: 'Replay',
                              icon: Icons.refresh,
                              onPressed: () =>
                                  context.go('/play/${args.levelId}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NeonOutlineButton(
                              label: 'Levels',
                              icon: Icons.grid_view_rounded,
                              onPressed: () =>
                                  context.go('/levels/${args.chapterId}'),
                            ),
                          ),
                        ],
                      ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.exo2(
                color: AppColors.muted,
                size: Responsive.sp(context, 14),
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.exo2(
              weight: FontWeight.w700,
              size: Responsive.sp(context, 17),
              color: highlight ? AppColors.gold : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
