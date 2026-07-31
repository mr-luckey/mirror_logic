import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/screens/splash/splash_screen.dart'
    show GameTitle;
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_exit_scope.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_resource_chip.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_star_row.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_torch.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.pageGutter(context);
    final short = Responsive.isShort(context);
    final crestSize =
        Responsive.wp(context, short ? 0.38 : 0.46).clamp(120.0, 210.0);

    return MedievalExitScope(
      child: MedievalWoodBackground(
        child: Stack(
          children: [
            const _WallTorches(),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 20),
                child: Column(
                  children: [
                    const _TopStatusBar(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MedievalArtwork(
                                    asset: MedievalArt.crest,
                                    size: crestSize,
                                    glow: MedievalColors.laserGlow,
                                    glowStrength: 0.26,
                                  )
                                      .animate()
                                      .fadeIn(duration: 550.ms)
                                      .scale(begin: const Offset(0.9, 0.9)),
                                  SizedBox(height: short ? 14 : 22),
                                  const GameTitle(),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Reflect  •  Align  •  Solve',
                                    textAlign: TextAlign.center,
                                    style: MedievalTextStyles.cinzel(
                                      color: MedievalColors.textMuted,
                                      letterSpacing: 2,
                                      size: Responsive.sp(context, 12),
                                    ),
                                  ),
                                  SizedBox(height: short ? 32 : 52),
                                  const _PlayButtons(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Continue where the player left off, or start the first hall.
class _PlayButtons extends StatelessWidget {
  const _PlayButtons();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressBloc, ProgressState>(
      buildWhen: (p, c) => p.save.lastPlayedLevelId != c.save.lastPlayedLevelId,
      builder: (context, progress) {
        final last = progress.save.lastPlayedLevelId;

        return Column(
          children: [
            MedievalButton(
              label: last == null ? 'Play' : 'Continue',
              style: MedievalButtonStyle.primary,
              icon: Icons.play_arrow_rounded,
              shimmer: true,
              onPressed: () => context.push(
                last == null ? '/chapters' : '/play/$last',
              ),
            ).animate().fadeIn(delay: 250.ms).slideY(
                  begin: 0.16,
                  end: 0,
                  curve: Curves.easeOutCubic,
                ),
            if (last != null) ...[
              const SizedBox(height: 11),
              MedievalButton(
                label: 'Chapters',
                icon: Icons.menu_book_rounded,
                onPressed: () => context.push('/chapters'),
              ).animate().fadeIn(delay: 380.ms).slideY(begin: 0.16, end: 0),
            ],
          ],
        );
      },
    );
  }
}

/// Torches bracketed to the wall behind the menu, flush with the screen edges.
class _WallTorches extends StatelessWidget {
  const _WallTorches();

  @override
  Widget build(BuildContext context) {
    final h = Responsive.hp(context, 0.16).clamp(90.0, 150.0);
    final top = Responsive.hp(context, 0.2);

    Widget torch({required bool flip}) => IgnorePointer(
          child: Opacity(
            opacity: 0.85,
            child: MedievalTorch(width: h * 0.55, height: h, flip: flip),
          ),
        );

    return Stack(
      children: [
        Positioned(left: -8, top: top, child: torch(flip: false)),
        Positioned(right: -8, top: top, child: torch(flip: true)),
      ],
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressBloc, ProgressState>(
      builder: (context, progress) {
        final stars = progress.save.levelProgress.values
            .fold<int>(0, (s, p) => s + p.stars);

        return MedievalPanel(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          // The rank plate is measured first and the slack goes to the gap, so
          // a narrow screen shrinks the space between groups, never the text.
          child: Row(
            children: [
              MedievalPanel(
                style: MedievalPanelStyle.inset,
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_moon_rounded,
                      color: MedievalColors.textGold,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Rank ${1 + (stars ~/ 9)}',
                      style: MedievalTextStyles.cinzel(
                        weight: FontWeight.w700,
                        size: Responsive.sp(context, 12),
                        color: MedievalColors.textGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const MedievalStarRow(filled: 3, size: 13, spacing: 1),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '$stars',
                  overflow: TextOverflow.ellipsis,
                  style: MedievalTextStyles.cinzel(
                    weight: FontWeight.w700,
                    size: Responsive.sp(context, 12),
                  ),
                ),
              ),
              const Spacer(),
              BlocBuilder<EconomyBloc, EconomyState>(
                builder: (context, eco) => MedievalResourceChip(
                  icon: Icons.monetization_on_rounded,
                  label: '${eco.coins}',
                  glowColor: MedievalColors.bronzeHighlight,
                ),
              ),
              const SizedBox(width: 8),
              MedievalBronzeButton(
                icon: Icons.settings_rounded,
                size: 34,
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}
