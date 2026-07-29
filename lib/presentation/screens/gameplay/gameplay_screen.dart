import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_paint_snapshot.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_painter.dart';
import 'package:mirror_logic/presentation/screens/level_complete/level_complete_screen.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';
import 'package:mirror_logic/presentation/widgets/glass_panel.dart';
import 'package:mirror_logic/presentation/widgets/gold_cta_button.dart';
import 'package:mirror_logic/presentation/widgets/neon_icon_button.dart';
import 'package:mirror_logic/presentation/widgets/star_row.dart';

/// Fully Stateless gameplay — level load + game loop live in [GameplayBloc].
class GameplayScreen extends StatelessWidget {
  const GameplayScreen({super.key, required this.levelId});

  final String levelId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameplayBloc(
        levelRepository: context.read<LevelRepository>(),
      )..add(GameplayLoadLevel(levelId)),
      child: const _GameplayBody(),
    );
  }
}

class _GameplayBody extends StatelessWidget {
  const _GameplayBody();

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameplayBloc, GameplayState>(
      listenWhen: (p, c) =>
          p.phase != GameplayPhase.solved && c.phase == GameplayPhase.solved,
      listener: (context, state) async {
        final level = state.level!;
        final stars = state.computeStars();
        final coins = context.read<EconomyRepository>().coinsForStars(stars);
        final nextId =
            await context.read<LevelRepository>().nextLevelId(level.levelId);

        if (!context.mounted) return;

        context.read<ProgressBloc>().add(
          ProgressLevelCompleted(
            levelId: level.levelId,
            stars: stars,
            timeSeconds: state.elapsedSeconds,
            coinsEarned: coins,
            nextLevelId: nextId,
          ),
        );
        context.read<EconomyBloc>().add(const EconomyStarted());

        unawaited(
          context.push(
            '/complete',
            extra: LevelCompleteArgs(
              levelId: level.levelId,
              chapterId: level.chapterId,
              levelIndex: level.levelIndex,
              stars: stars,
              moves: state.moves,
              timeSeconds: state.elapsedSeconds,
              coinsEarned: coins,
              nextLevelId: nextId,
            ),
          ),
        );
      },
      child: BlocBuilder<GameplayBloc, GameplayState>(
        buildWhen: (p, c) =>
            p.phase != c.phase || p.level?.levelId != c.level?.levelId,
        builder: (context, state) {
          if (state.phase == GameplayPhase.loading) {
            return const AtmosphericBackground(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.cyan),
              ),
            );
          }
          if (state.phase == GameplayPhase.loadFailed) {
            return AtmosphericBackground(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load level',
                        style: AppTextStyles.exo2(size: 16),
                      ),
                      const SizedBox(height: 16),
                      GoldCtaButton(
                        label: 'Back',
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final levelId = state.level?.levelId ?? '';
          return AtmosphericBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      const _TopBar(),
                      const Expanded(child: _GameplayCanvas()),
                      _BottomBar(levelId: levelId),
                    ],
                  ),
                  if (state.phase == GameplayPhase.paused)
                    const _PauseOverlay(),
                  if (state.phase == GameplayPhase.hint) const _HintOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameplayCanvas extends StatelessWidget {
  const _GameplayCanvas();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<GameplayBloc, GameplayState, GameplayPaintSnapshot?>(
      selector: (state) {
        if (state.level == null) return null;
        return GameplayPaintSnapshot.fromState(state);
      },
      builder: (context, snapshot) {
        if (snapshot == null) return const SizedBox.shrink();

        final level = snapshot.level;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isNarrow(context) ? 8 : 12,
            vertical: Responsive.isShort(context) ? 4 : 8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return GestureDetector(
                onPanStart: (details) {
                  final world = screenToWorld(
                    local: details.localPosition,
                    canvasSize: size,
                    level: level,
                  );
                  if (world == null) return;
                  final bloc = context.read<GameplayBloc>();
                  final id = hitTestMirror(
                    world: world,
                    level: level,
                    angles: bloc.state.mirrorAngles,
                  );
                  if (id == null) return;
                  if (context.read<SettingsCubit>().state.haptics) {
                    HapticFeedback.selectionClick();
                  }
                  bloc.add(GameplayMirrorDragStarted(id));
                },
                onPanUpdate: (details) {
                  final bloc = context.read<GameplayBloc>();
                  final active = bloc.state.activeMirrorId;
                  if (active == null) return;
                  final world = screenToWorld(
                    local: details.localPosition,
                    canvasSize: size,
                    level: level,
                  );
                  if (world == null) return;
                  bloc.add(
                    GameplayMirrorDragged(
                      mirrorId: active,
                      worldPoint: world,
                    ),
                  );
                },
                onPanEnd: (_) {
                  context
                      .read<GameplayBloc>()
                      .add(const GameplayMirrorDragEnded());
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: GameplayPainter(snapshot: snapshot),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<GameplayBloc, GameplayState, (int, int)>(
      selector: (state) => (
        state.level?.levelIndex ?? 0,
        state.isSolved ? state.computeStars() : 0,
      ),
      builder: (context, data) {
        final gutter = Responsive.pageGutter(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(gutter * 0.7, 4, gutter * 0.7, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'LEVEL ${data.$1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.orbitron(
                    size: Responsive.sp(context, 15).clamp(12.0, 17.0),
                    weight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              StarRow(
                filled: data.$2,
                size: Responsive.sp(context, 18).clamp(14.0, 22.0),
              ),
              const SizedBox(width: 8),
              NeonIconButton(
                icon: Icons.pause_rounded,
                size: Responsive.sp(context, 42).clamp(36.0, 48.0),
                onPressed: () =>
                    context.read<GameplayBloc>().add(const GameplayPaused()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.levelId});
  final String levelId;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressBloc>().state.save;
    final completedCount =
        progress.levelProgress.values.where((p) => p.completed).length;
    final freeHint = completedCount < GameConstants.freeHintLevels;
    final short = Responsive.isShort(context);
    final gutter = Responsive.pageGutter(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, short ? 2 : 4, gutter, short ? 8 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: NeonIconButton(
              icon: Icons.refresh_rounded,
              label: 'Restart',
              onPressed: () =>
                  context.read<GameplayBloc>().add(const GameplayRestarted()),
            ),
          ),
          Flexible(
            child: NeonIconButton(
              icon: Icons.lightbulb_outline,
              label: 'Hint',
              badge: freeHint ? 'FREE' : null,
              onPressed: () => _showHintSheet(context, freeHint),
            ),
          ),
          Flexible(
            child: NeonIconButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              onPressed: () =>
                  context.read<GameplayBloc>().add(const GameplayUndoRequested()),
            ),
          ),
        ],
      ),
    );
  }

  void _showHintSheet(BuildContext context, bool freeHint) {
    final gameplay = context.read<GameplayBloc>();
    final economy = context.read<EconomyBloc>();
    final coins = economy.state.coins;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.secondaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget tile(String title, String cost, int tier, int price) {
          final canAfford =
              freeHint && tier == 1 || coins >= price || tier == 0;
          return ListTile(
            title: Text(title, style: AppTextStyles.exo2(color: Colors.white)),
            subtitle: Text(cost, style: AppTextStyles.exo2(color: AppColors.muted)),
            trailing: Icon(
              canAfford ? Icons.chevron_right : Icons.lock,
              color: AppColors.cyan,
            ),
            onTap: !canAfford
                ? null
                : () async {
                    final progress = context.read<ProgressBloc>();
                    final ecoRepo = context.read<EconomyRepository>();
                    if (tier > 0 && !(freeHint && tier == 1)) {
                      final spent = await ecoRepo.spendCoins(price);
                      if (spent == null) return;
                      economy.add(EconomyCoinsChanged(spent.coins));
                      progress.add(const ProgressRefresh());
                    }
                    gameplay.add(GameplayHintRequested(tier));
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HINTS',
                  style: AppTextStyles.orbitron(
                    weight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                tile('Objective reminder', 'Free', 0, 0),
                tile(
                  'Highlight a key mirror',
                  freeHint
                      ? 'Free (early levels)'
                      : '${GameConstants.hintTier1Cost} coins',
                  1,
                  GameConstants.hintTier1Cost,
                ),
                tile(
                  'Show ghost target angle',
                  '${GameConstants.hintTier2Cost} coins',
                  2,
                  GameConstants.hintTier2Cost,
                ),
                tile(
                  'Auto-set one mirror',
                  '${GameConstants.hintTier3Cost} coins',
                  3,
                  GameConstants.hintTier3Cost,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay();

  @override
  Widget build(BuildContext context) {
    final maxWidth = (Responsive.widthOf(context) * 0.86).clamp(240.0, 340.0);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.65),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pageGutter(context),
              vertical: 16,
            ),
            child: GlassPanel(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PAUSED',
                      style: AppTextStyles.orbitron(
                        size: Responsive.sp(context, 20),
                        weight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GoldCtaButton(
                      label: 'Resume',
                      width: double.infinity,
                      onPressed: () => context
                          .read<GameplayBloc>()
                          .add(const GameplayResumed()),
                    ),
                    const SizedBox(height: 10),
                    NeonOutlineButton(
                      label: 'Restart',
                      onPressed: () {
                        context
                            .read<GameplayBloc>()
                            .add(const GameplayRestarted());
                      },
                    ),
                    const SizedBox(height: 10),
                    NeonOutlineButton(
                      label: 'Level Select',
                      onPressed: () {
                        final chapter = context
                                .read<GameplayBloc>()
                                .state
                                .level
                                ?.chapterId ??
                            'ch1';
                        context.go('/levels/$chapter');
                      },
                    ),
                    const SizedBox(height: 10),
                    NeonOutlineButton(
                      label: 'Settings',
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintOverlay extends StatelessWidget {
  const _HintOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<GameplayBloc, GameplayState, (String?, bool)>(
      selector: (state) => (
        state.highlightedMirrorId,
        state.ghostAngles.isNotEmpty,
      ),
      builder: (context, hint) {
        final message = hint.$1 == null
            ? 'Guide the laser into the glowing crystal.'
            : hint.$2
                ? 'Align the highlighted mirror with the gold ghost.'
                : 'Try rotating the highlighted mirror.';

        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.pageGutter(context),
                56,
                Responsive.pageGutter(context),
                0,
              ),
              child: GlassPanel(
                glow: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.exo2(
                        size: Responsive.sp(context, 14),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        textStyle: AppTextStyles.exo2(color: AppColors.cyan),
                      ),
                      onPressed: () => context
                          .read<GameplayBloc>()
                          .add(const GameplayHintDismissed()),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
