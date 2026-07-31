import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/domain/beam/beam_alignment.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_paint_snapshot.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_painter.dart';
import 'package:mirror_logic/presentation/screens/level_complete/level_complete_screen.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_gameplay_hud.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_objective_banner.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

/// Fantasy-medieval gameplay screen matching the production art reference.
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
    return MultiBlocListener(
      listeners: [
        // One tick per lock: the drag settling onto a mirror centre or a
        // crystal is the moment worth feeling.
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) => p.alignmentPulse != c.alignmentPulse,
          listener: (context, state) {
            if (!context.read<SettingsCubit>().state.haptics) return;
            if (state.alignedTargetKind == AlignmentTargetKind.crystal) {
              HapticFeedback.mediumImpact();
            } else {
              HapticFeedback.selectionClick();
            }
          },
        ),
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) =>
              p.phase != GameplayPhase.solved &&
              c.phase == GameplayPhase.solved,
          listener: _onSolved,
        ),
      ],
      child: BlocBuilder<GameplayBloc, GameplayState>(
        buildWhen: (p, c) =>
            p.phase != c.phase || p.level?.levelId != c.level?.levelId,
        builder: _buildBody,
      ),
    );
  }

  Future<void> _onSolved(BuildContext context, GameplayState state) async {
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

        // Replace rather than push: going back to a board that is already in
        // the solved phase leaves the player on a frozen level, and solving it
        // again would award the coins a second time.
        context.pushReplacement(
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
        );
  }

  Widget _buildBody(BuildContext context, GameplayState state) {
          if (state.phase == GameplayPhase.loading) {
            return const MedievalWoodBackground(
              child: Center(
                child: CircularProgressIndicator(
                  color: MedievalColors.bronzeHighlight,
                ),
              ),
            );
          }
          if (state.phase == GameplayPhase.loadFailed) {
            return MedievalWoodBackground(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load level',
                        style: MedievalTextStyles.cinzel(size: 16),
                      ),
                      const SizedBox(height: 16),
                      MedievalPressable(
                        onPressed: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: MedievalColors.bronzeMetal,
                          ),
                          child: Text(
                            'Back',
                            style: MedievalTextStyles.cinzel(
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return MedievalWoodBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      const _TopHud(),
                      const Expanded(child: _BoardArea()),
                    ],
                  ),
                  if (state.phase == GameplayPhase.paused)
                    const _PauseOverlay(),
                  if (state.phase == GameplayPhase.hint) const _HintOverlay(),
                ],
              ),
            ),
          );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud();

  static const _chapterTitles = {
    'ch1': 'Mirror Hall',
    'ch2': 'Hall of Reflections',
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameplayBloc, GameplayState>(
      buildWhen: (p, c) =>
          p.level?.levelId != c.level?.levelId ||
          p.isSolved != c.isSolved ||
          p.hintsUsed != c.hintsUsed,
      builder: (context, gameplay) {
        final level = gameplay.level;
        final chapterId = level?.chapterId ?? GameConstants.chapter1Id;
        final chapterNum =
            int.tryParse(chapterId.replaceFirst('ch', '')) ?? 1;
        final chapterLabel = 'Chapter $chapterNum';
        final levelTitle = (level?.title.isNotEmpty ?? false)
            ? level!.title
            : (_chapterTitles[chapterId] ?? 'Mirror Hall');
        final stars = gameplay.isSolved ? gameplay.computeStars() : 0;
        final coins = context.watch<EconomyBloc>().state.coins;
        final progress = context.watch<ProgressBloc>().state.save;
        final completed = progress.levelProgress.values
            .where((p) => p.completed)
            .length;
        final freeHint = completed < GameConstants.freeHintLevels;

        return MedievalGameplayHud(
          chapterLabel: chapterLabel,
          chapterTitle: levelTitle,
          levelIndex: level?.levelIndex ?? 1,
          stars: stars,
          coins: coins,
          hintsLabel: freeHint ? 'FREE' : 'HINT',
          onPause: () =>
              context.read<GameplayBloc>().add(const GameplayPaused()),
          onHint: () => _showHintSheet(context, freeHint),
          onAddCoins: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Earn coins by clearing levels',
                  style: MedievalTextStyles.cinzel(size: 13),
                ),
                backgroundColor: MedievalColors.woodDeep,
              ),
            );
          },
        );
      },
    );
  }
}

class _BoardArea extends StatelessWidget {
  const _BoardArea();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final short = h < 520;

        // Equal side padding so the board sits centered
        final padX = (w * 0.055).clamp(18.0, 36.0);
        final padT = (h * (short ? 0.065 : 0.075)).clamp(32.0, 52.0);
        final padB = (h * 0.035).clamp(14.0, 28.0);
        final bannerW = (w * 0.62).clamp(180.0, 260.0);

        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  padX - 6,
                  padT - 6,
                  padX - 6,
                  padB - 4,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                    border: Border.all(
                      color: MedievalColors.bronzeDark.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padX, padT, padX, padB),
                child: const _GameplayCanvas(),
              ),
            ),
            Positioned(
              left: padX + 4,
              top: 2,
              child: SizedBox(
                width: bannerW,
                child: const _ObjectiveBanner(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ObjectiveBanner extends StatelessWidget {
  const _ObjectiveBanner();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<GameplayBloc, GameplayState, (String, String)>(
      selector: (state) {
        final meta = state.level?.metadata.objective ?? '';
        return (
          state.level?.levelId ?? '',
          meta.isEmpty ? 'Activate the Target Crystal' : meta,
        );
      },
      builder: (context, data) {
        // Keyed on the level so every board starts the banner over.
        return _FadingBanner(key: ValueKey(data.$1), message: data.$2);
      },
    );
  }
}

/// The objective, shown long enough to read and then faded out.
///
/// The banner is pinned over the top-left of the board, so leaving it up hides
/// whatever the level put in that corner. It never accepts touches either way,
/// so a mirror underneath it stays draggable.
class _FadingBanner extends StatefulWidget {
  const _FadingBanner({super.key, required this.message});

  final String message;

  @override
  State<_FadingBanner> createState() => _FadingBannerState();
}

class _FadingBannerState extends State<_FadingBanner> {
  static const _hold = Duration(seconds: 4);
  static const _fade = Duration(milliseconds: 700);

  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: _fade,
        curve: Curves.easeOut,
        child: MedievalObjectiveBanner(message: widget.message),
      ),
    );
  }
}

class _GameplayCanvas extends StatefulWidget {
  const _GameplayCanvas();

  @override
  State<_GameplayCanvas> createState() => _GameplayCanvasState();
}

class _GameplayCanvasState extends State<_GameplayCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  ui.Image? _crystal;
  ui.Image? _emitter;
  ui.Image? _wallH;
  ui.Image? _wallV;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    unawaited(_loadImages());
  }

  Future<void> _loadImages() async {
    final results = await Future.wait<ui.Image?>([
      _decodeAsset('assets/images/medieval/crystal_cut.png'),
      _decodeAsset('assets/images/medieval/emitter_cut.png'),
      _decodeAsset('assets/images/medieval/wall_h_cut.png'),
      _decodeAsset('assets/images/medieval/wall_v_cut.png'),
    ]);
    if (!mounted) return;
    setState(() {
      _crystal = results[0];
      _emitter = results[1];
      _wallH = results[2];
      _wallV = results[3];
    });
  }

  Future<ui.Image?> _decodeAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAngle = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.angleReadout,
    );

    return BlocSelector<GameplayBloc, GameplayState, GameplayPaintSnapshot?>(
      selector: (state) {
        if (state.level == null) return null;
        return GameplayPaintSnapshot.fromState(
          state,
          showAngleReadout: showAngle,
        );
      },
      builder: (context, snapshot) {
        if (snapshot == null) return const SizedBox.shrink();
        final level = snapshot.level;

        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (details) {
                    final world = screenToWorld(
                      local: details.localPosition,
                      canvasSize: size,
                      level: level,
                    );
                    if (world == null) return;
                    final bloc = context.read<GameplayBloc>();
                    final settings = context.read<SettingsCubit>().state;
                    final id = hitTestMirror(
                      world: world,
                      level: level,
                      angles: bloc.state.mirrorAngles,
                      padding: settings.assistMode ? 72 : 42,
                    );
                    if (id == null) return;
                    if (settings.haptics) {
                      HapticFeedback.selectionClick();
                    }
                    bloc.add(
                      GameplayMirrorDragStarted(
                        mirrorId: id,
                        grabPoint: world,
                      ),
                    );
                  },
                  onPanUpdate: (details) {
                    final bloc = context.read<GameplayBloc>();
                    final active = bloc.state.activeMirrorId;
                    if (active == null) return;
                    final world = screenToWorld(
                      local: details.localPosition,
                      canvasSize: size,
                      level: level,
                      bounded: false,
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
                      painter: GameplayPainter(
                        snapshot: snapshot,
                        animTime: _anim.value * 8 * 3.14159,
                        crystalImage: _crystal,
                        emitterImage: _emitter,
                        wallHorizontalImage: _wallH,
                        wallVerticalImage: _wallV,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

void _showHintSheet(BuildContext context, bool freeHint) {
  final gameplay = context.read<GameplayBloc>();
  final economy = context.read<EconomyBloc>();
  final coins = economy.state.coins;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      Widget tile(IconData icon, String title, String cost, int tier, int price) {
        final canAfford =
            freeHint && tier == 1 || coins >= price || tier == 0;
        final free = tier == 0 || (freeHint && tier == 1);

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Opacity(
            opacity: canAfford ? 1 : 0.5,
            child: MedievalPressable(
              enabled: canAfford,
              onPressed: !canAfford
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
              child: MedievalPanel(
                style: MedievalPanelStyle.inset,
                radius: 10,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: MedievalColors.textGold),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: MedievalTextStyles.cinzel(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: MedievalColors.textCream,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cost,
                            style: MedievalTextStyles.cinzel(
                              size: 10.5,
                              letterSpacing: 0.8,
                              color: free
                                  ? MedievalColors.greenPlus
                                  : MedievalColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      canAfford ? Icons.chevron_right_rounded : Icons.lock,
                      size: 19,
                      color: MedievalColors.bronzeHighlight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.pageGutter(sheetContext),
            0,
            Responsive.pageGutter(sheetContext),
            12,
          ),
          child: MedievalPanel(
            radius: 16,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'COUNSEL',
                  style: MedievalTextStyles.cinzel(
                    size: 15,
                    weight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: MedievalColors.textGold,
                  ),
                ),
                const MedievalDivider(height: 16),
                tile(
                  Icons.flag_rounded,
                  'Objective reminder',
                  'Free',
                  0,
                  0,
                ),
                tile(
                  Icons.highlight_rounded,
                  'Highlight a key mirror',
                  freeHint
                      ? 'Free (early levels)'
                      : '${GameConstants.hintTier1Cost} coins',
                  1,
                  GameConstants.hintTier1Cost,
                ),
                tile(
                  Icons.blur_on_rounded,
                  'Show ghost target angle',
                  '${GameConstants.hintTier2Cost} coins',
                  2,
                  GameConstants.hintTier2Cost,
                ),
                tile(
                  Icons.auto_fix_high_rounded,
                  'Auto-set one mirror',
                  '${GameConstants.hintTier3Cost} coins',
                  3,
                  GameConstants.hintTier3Cost,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay();

  @override
  Widget build(BuildContext context) {
    final maxWidth = (Responsive.widthOf(context) * 0.86).clamp(240.0, 340.0);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pageGutter(context),
              vertical: 16,
            ),
            child: Container(
              width: maxWidth,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: MedievalColors.woodPanel,
                border: Border.all(
                  color: MedievalColors.bronzeLight,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PAUSED',
                    style: MedievalTextStyles.cinzel(
                      size: Responsive.sp(context, 22),
                      weight: FontWeight.w700,
                      letterSpacing: 2,
                      color: MedievalColors.textGold,
                    ),
                  ),
                  const MedievalDivider(height: 20),
                  MedievalButton(
                    label: 'Resume',
                    style: MedievalButtonStyle.primary,
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => context
                        .read<GameplayBloc>()
                        .add(const GameplayResumed()),
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Restart',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      context
                          .read<GameplayBloc>()
                          .add(const GameplayRestarted());
                    },
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Undo Move',
                    icon: Icons.undo_rounded,
                    onPressed: () {
                      context
                          .read<GameplayBloc>()
                          .add(const GameplayUndoRequested());
                      context
                          .read<GameplayBloc>()
                          .add(const GameplayResumed());
                    },
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Level Select',
                    icon: Icons.grid_view_rounded,
                    onPressed: () {
                      final chapter = context
                              .read<GameplayBloc>()
                              .state
                              .level
                              ?.chapterId ??
                          GameConstants.chapter1Id;
                      context.go('/levels/$chapter');
                    },
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintOverlay extends StatefulWidget {
  const _HintOverlay();

  @override
  State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay> {
  /// Long enough to read a sentence, short enough that it stops covering the
  /// board before the player wants to look at it again.
  static const _hold = Duration(seconds: 6);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, () {
      if (!mounted) return;
      // Guides stay: a timeout is not the player saying they are done with a
      // highlight they spent coins on.
      context
          .read<GameplayBloc>()
          .add(const GameplayHintDismissed(keepGuides: true));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<GameplayBloc, GameplayState, (String?, bool, int, List<String>)>(
      selector: (state) => (
        state.highlightedMirrorId,
        state.ghostAngles.isNotEmpty,
        state.maxHintTierUsed,
        state.level?.metadata.hints ?? const [],
      ),
      builder: (context, hint) {
        final highlighted = hint.$1;
        final hasGhost = hint.$2;
        final hints = hint.$4;

        String message;
        if (hasGhost && hints.length > 2) {
          message = hints[2];
        } else if (highlighted != null && hints.length > 1) {
          message = hints[1];
        } else if (hints.isNotEmpty) {
          message = hints[0];
        } else if (highlighted == null) {
          message = 'Guide the laser into the glowing crystal.';
        } else if (hasGhost) {
          message = 'Align the highlighted mirror with the gold ghost.';
        } else {
          message = 'Try rotating the highlighted mirror.';
        }

        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.pageGutter(context),
                90,
                Responsive.pageGutter(context),
                0,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: MedievalColors.parchment,
                  border: Border.all(
                    color: MedievalColors.bronze,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: MedievalTextStyles.imFell(
                        size: Responsive.sp(context, 14),
                        height: 1.35,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context
                          .read<GameplayBloc>()
                          .add(const GameplayHintDismissed()),
                      child: Text(
                        'Got it',
                        style: MedievalTextStyles.cinzel(
                          size: 13,
                          color: MedievalColors.bronzeDark,
                          weight: FontWeight.w700,
                        ),
                      ),
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
