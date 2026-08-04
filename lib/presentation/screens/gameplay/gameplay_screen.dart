import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/ads_scope.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/domain/beam/beam_alignment.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/infrastructure/art/game_art.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_fx_layer.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_paint_snapshot.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_painter.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_walkthrough_layer.dart';
import 'package:mirror_logic/presentation/screens/level_complete/level_complete_screen.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_gameplay_hud.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_objective_banner.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

/// Fantasy-medieval gameplay screen matching the production art reference.
class GameplayScreen extends StatelessWidget {
  const GameplayScreen({super.key, required this.levelId});

  final String levelId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          GameplayBloc(levelRepository: context.read<LevelRepository>())
            ..add(GameplayLoadLevel(levelId)),
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
        // One cue per lock: the drag settling onto a mirror centre or a
        // crystal is the moment worth hearing and feeling.
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) => p.alignmentPulse != c.alignmentPulse,
          listener: (context, state) => context.playSfx(
            state.alignedTargetKind == AlignmentTargetKind.crystal
                ? Sfx.mirrorLock
                : Sfx.mirrorDetent,
          ),
        ),
        // The beam picking up another mirror is the clearest sign of progress
        // on the board, so it gets its own tick.
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) => _mirrorsInBeam(c) > _mirrorsInBeam(p),
          listener: (context, _) => context.playSfx(Sfx.beamHit),
        ),
        // Reaching a crystal the wrong way should sound wrong immediately.
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) =>
              c.rejectedCrystalIds.difference(p.rejectedCrystalIds).isNotEmpty,
          listener: (context, _) => context.playSfx(Sfx.reject),
        ),
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) =>
              c.beam.litCrystalIds.difference(p.beam.litCrystalIds).isNotEmpty,
          listener: (context, _) => context.playSfx(Sfx.crystalLit),
        ),
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) =>
              p.phase != GameplayPhase.solved &&
              c.phase == GameplayPhase.solved,
          listener: (context, state) {
            context.playSfx(Sfx.win);
            _onSolved(context, state);
          },
        ),
        // Pull the music back while an overlay is up so the panel reads as
        // being in front of the game rather than part of it.
        BlocListener<GameplayBloc, GameplayState>(
          listenWhen: (p, c) => _overlayUp(p) != _overlayUp(c),
          listener: (context, state) =>
              context.audio?.duckMusic(_overlayUp(state)),
        ),
      ],
      child: BlocBuilder<GameplayBloc, GameplayState>(
        buildWhen: (p, c) =>
            p.phase != c.phase || p.level?.levelId != c.level?.levelId,
        builder: _buildBody,
      ),
    );
  }

  static bool _overlayUp(GameplayState state) =>
      state.phase == GameplayPhase.paused || state.phase == GameplayPhase.hint;

  /// How many distinct mirrors the beam currently bounces off.
  static int _mirrorsInBeam(GameplayState state) {
    final ids = <String>{};
    for (final segment in state.beam.segments) {
      if (segment.hitKind == BeamHitKind.mirror && segment.hitId != null) {
        ids.add(segment.hitId!);
      }
    }
    return ids.length;
  }

  Future<void> _onSolved(BuildContext context, GameplayState state) async {
    final level = state.level!;
    final stars = state.computeStars();
    final coins = context.read<EconomyRepository>().coinsForClear();
    final nextId = await context.read<LevelRepository>().nextLevelId(
      level.levelId,
    );

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
        levelIndex: GameConstants.displayLevelNumber(
          level.chapterId,
          level.levelIndex,
        ),
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
                      style: MedievalTextStyles.cinzel(weight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Back mid-puzzle opens the pause menu rather than dumping the
    // player out of the level they are halfway through.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final bloc = context.read<GameplayBloc>();
        if (bloc.state.phase == GameplayPhase.playing) {
          bloc.add(const GameplayPaused());
        } else if (bloc.state.phase == GameplayPhase.paused) {
          bloc.add(const GameplayResumed());
        }
      },
      child: MedievalWoodBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // The banner strip is laid out for the whole app by
              // AdBannerHost, so the board no longer reserves room for
              // one itself.
              const Column(
                children: [
                  _TopHud(),
                  Expanded(child: _BoardArea()),
                ],
              ),
              if (state.phase == GameplayPhase.paused) const _PauseOverlay(),
              if (state.phase == GameplayPhase.hint) const _HintOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameplayBloc, GameplayState>(
      buildWhen: (p, c) =>
          p.level?.levelId != c.level?.levelId || p.isSolved != c.isSolved,
      builder: (context, gameplay) {
        final level = gameplay.level;
        final stars = gameplay.isSolved ? gameplay.computeStars() : 0;
        final coins = context.watch<EconomyBloc>().state.coins;

        return MedievalGameplayHud(
          levelIndex: level == null
              ? 1
              : GameConstants.displayLevelNumber(
                  level.chapterId,
                  level.levelIndex,
                ),
          stars: stars,
          coins: coins,
          onPause: () =>
              context.read<GameplayBloc>().add(const GameplayPaused()),
          onAddCoins: () {
            MedievalToast.show(
              context,
              'Earn coin by clearing levels',
              icon: Icons.monetization_on_rounded,
            );
          },
        );
      },
    );
  }
}

/// How the player is paying for the solved board.
/// Buys and shows the solved board.
///
/// The tiered counsel sheet is gone: the player wanted the answer, and making
/// them pick which fragment of it to buy only added a step. Picking *how* to pay
/// is a different question — one option costs the purse and the other costs
/// thirty seconds — so that one is worth asking.
Future<void> _requestHint(BuildContext context) async {
  final gameplay = context.read<GameplayBloc>();
  if (gameplay.state.phase == GameplayPhase.hint) return;

  // Charge once per board. Showing the same answer again costs nothing.
  if (!gameplay.state.solutionRevealed && !await _payForHint(context)) return;
  if (!context.mounted) return;

  context.playSfx(Sfx.hint);
  gameplay.add(const GameplayHintRequested());
}

/// Takes payment for the hint, and reports whether it was paid.
Future<bool> _payForHint(BuildContext context) async {
  final ads = context.ads;
  if (ads == null) return false;
  if (!await _hasInternetConnection()) {
    if (context.mounted) {
      MedievalToast.show(
        context,
        'No internet — connect to watch hint video',
        icon: Icons.wifi_off_rounded,
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  if (!ads.hasRewardedAd) ads.warmUp();
  return _watchForHint(context, ads);
}

/// Plays a rewarded video and pays out only if the player sat through it.
Future<bool> _watchForHint(BuildContext context, AdsService ads) async {
  final outcome = await ads.showRewarded();
  if (!context.mounted) return false;

  switch (outcome) {
    case RewardedAdOutcome.earned:
      return true;
    case RewardedAdOutcome.skipped:
      MedievalToast.show(
        context,
        'Video closed early — no hint given',
        icon: Icons.visibility_off_rounded,
      );
      return false;
    case RewardedAdOutcome.unavailable:
      MedievalToast.show(
        context,
        'No video ready — try again in a moment',
        icon: Icons.cloud_off_rounded,
      );
      return false;
  }
}

Future<bool> _hasInternetConnection() async {
  final status = await Connectivity().checkConnectivity();
  return status.any((s) => s != ConnectivityResult.none);
}

class _BoardArea extends StatelessWidget {
  const _BoardArea();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Fixed band above the board carrying the objective on the left and
        // the hint on the right, so neither ever sits on top of the puzzle.
        // Sized to the parchment banner, which is the taller of the two.
        const headerH = 56.0;
        const hintSize = 44.0;

        // Equal side padding so the board sits centered
        final padX = (w * 0.055).clamp(18.0, 36.0);
        const padT = headerH + 6;
        final padB = (h * 0.03).clamp(10.0, 22.0);
        final bannerW = (w * 0.58).clamp(160.0, 250.0);

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
              top: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bannerW),
                child: const _ObjectiveBanner(),
              ),
            ),
            // Resting on the top-right corner of the board frame, so the hint
            // reads as belonging to the puzzle rather than to the status bar.
            Positioned(
              right: padX + 2,
              top: headerH - hintSize,
              child: MedievalBronzeButton(
                icon: Icons.lightbulb,
                size: hintSize,
                onPressed: () => _requestHint(context),
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
        // The banner is pinned over the top-left of the board, so leaving it
        // up hides whatever the level put in that corner. Keyed on the level
        // so every board plays the fade again. It never accepts touches, so a
        // mirror underneath it stays draggable throughout.
        return IgnorePointer(
          key: ValueKey(data.$1),
          child: MedievalObjectiveBanner(
            message: data.$2,
          ).animate().fadeOut(delay: 4000.ms, duration: 700.ms),
        );
      },
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

  /// Whether this board should be played for the player by the hand.
  ///
  /// Read once, because the flag is written the moment the walkthrough ends and
  /// watching it would tear the hand off the board mid-gesture.
  late final bool _walkthrough;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _walkthrough = !context.read<ProgressBloc>().state.save.walkthroughSeen;
    unawaited(GameArt.ensureLoaded());
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
                context.playSfx(Sfx.mirrorGrab);
                bloc.add(
                  GameplayMirrorDragStarted(mirrorId: id, grabPoint: world),
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
                  GameplayMirrorDragged(mirrorId: active, worldPoint: world),
                );
              },
              onPanEnd: (_) {
                context.read<GameplayBloc>().add(
                  const GameplayMirrorDragEnded(),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The idle shimmer drives the painter directly. Rebuilding
                  // this subtree every frame instead would re-run the gesture
                  // detector and layout sixty times a second for nothing.
                  RepaintBoundary(
                    child: ValueListenableBuilder<GameArt?>(
                      valueListenable: GameArt.notifier,
                      builder: (context, art, _) => CustomPaint(
                        size: size,
                        painter: GameplayPainter(
                          snapshot: snapshot,
                          clock: _anim,
                          art: art,
                        ),
                      ),
                    ),
                  ),
                  GameplayFxLayer(canvasSize: size),
                  if (_walkthrough &&
                      level.levelId == GameConstants.firstLevelId)
                    GameplayWalkthroughLayer(level: level, canvasSize: size),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Runs a pause-menu action with an interstitial in front of it.
///
/// Every button in that menu except Resume is the player stepping away from the
/// board, which is the cheapest moment in the game to charge them: the puzzle is
/// already stopped and its clock with it, so the ad interrupts nothing they were
/// in the middle of. Resume stays clean — an ad standing between deciding to keep
/// playing and being allowed to is a toll on the wrong door.
///
/// The level cadence is waived throughout, because none of these are level
/// breaks. The three exits that actually leave the board go further and waive
/// the quiet period too — see [InterstitialPolicy.always].
Future<void> _leavePause(
  BuildContext context,
  VoidCallback action, {
  InterstitialPolicy policy = InterstitialPolicy.quietPeriod,
}) async {
  await context.ads?.showInterstitial(policy: policy);
  if (!context.mounted) return;
  action();
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
                border: Border.all(color: MedievalColors.bronzeLight, width: 2),
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
                    onPressed: () => context.read<GameplayBloc>().add(
                      const GameplayResumed(),
                    ),
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Restart',
                    icon: Icons.refresh_rounded,
                    onPressed: () => _leavePause(context, () {
                      context.read<GameplayBloc>().add(
                        const GameplayRestarted(),
                      );
                    }),
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Level Select',
                    icon: Icons.grid_view_rounded,
                    sfx: Sfx.back,
                    onPressed: () {
                      final chapter =
                          context.read<GameplayBloc>().state.level?.chapterId ??
                          GameConstants.chapter1Id;
                      unawaited(
                        _leavePause(
                          context,
                          () => context.go('/levels/$chapter'),
                          policy: InterstitialPolicy.always,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    onPressed: () => _leavePause(
                      context,
                      () => context.push('/settings'),
                      policy: InterstitialPolicy.always,
                    ),
                  ),
                  const SizedBox(height: 9),
                  MedievalButton(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    sfx: Sfx.back,
                    onPressed: () => _leavePause(
                      context,
                      () => context.go('/menu'),
                      policy: InterstitialPolicy.always,
                    ),
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

/// Parchment note explaining the gold ghost board the hint just laid down.
///
/// It sits over the board, so it retires itself after a few seconds rather
/// than waiting for a tap the player has no reason to give.
class _HintOverlay extends StatefulWidget {
  const _HintOverlay();

  @override
  State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay> {
  static const _hold = Duration(seconds: 5);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    context.read<GameplayBloc>().add(const GameplayHintDismissed());
  }

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.pageGutter(context);

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 90, gutter, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: MedievalColors.parchment,
              border: Border.all(color: MedievalColors.bronze, width: 2),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_fix_high_rounded,
                      size: 17,
                      color: MedievalColors.bronzeDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'THE SOLVED BOARD',
                      style: MedievalTextStyles.cinzel(
                        size: Responsive.sp(context, 12),
                        weight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: MedievalColors.bronzeDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Every mirror now shows a gold ghost at its finished angle. '
                  'Turn each one until it sits inside its ghost.',
                  textAlign: TextAlign.center,
                  style: MedievalTextStyles.imFell(
                    size: Responsive.sp(context, 13.5),
                    height: 1.35,
                  ),
                ),
                TextButton(
                  onPressed: _dismiss,
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
  }
}
