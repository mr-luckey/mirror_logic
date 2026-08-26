import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/domain/beam/beam_alignment.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/reflection_math.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';
import 'package:mirror_logic/infrastructure/analytics/analytics_service.dart';

enum GameplayPhase { loading, loadFailed, playing, paused, hint, solved }

sealed class GameplayEvent extends Equatable {
  const GameplayEvent();
  @override
  List<Object?> get props => [];
}

/// Loads level JSON then starts simulation — no widget FutureBuilder needed.
class GameplayLoadLevel extends GameplayEvent {
  const GameplayLoadLevel(this.levelId);
  final String levelId;
  @override
  List<Object?> get props => [levelId];
}

class GameplayStarted extends GameplayEvent {
  const GameplayStarted(this.level);
  final LevelModel level;
  @override
  List<Object?> get props => [level];
}

class GameplayMirrorDragStarted extends GameplayEvent {
  const GameplayMirrorDragStarted({
    required this.mirrorId,
    required this.grabPoint,
  });
  final String mirrorId;

  /// Where the finger landed, used as the zero reference for the rotation.
  final Vec2 grabPoint;
  @override
  List<Object?> get props => [mirrorId, grabPoint];
}

class GameplayMirrorDragged extends GameplayEvent {
  const GameplayMirrorDragged({
    required this.mirrorId,
    required this.worldPoint,
  });
  final String mirrorId;
  final Vec2 worldPoint;
  @override
  List<Object?> get props => [mirrorId, worldPoint];
}

class GameplayMirrorDragEnded extends GameplayEvent {
  const GameplayMirrorDragEnded();
}

class GameplayTick extends GameplayEvent {
  const GameplayTick(this.dtSeconds);
  final double dtSeconds;
  @override
  List<Object?> get props => [dtSeconds];
}

class GameplayPaused extends GameplayEvent {
  const GameplayPaused();
}

class GameplayResumed extends GameplayEvent {
  const GameplayResumed();
}

class GameplayRestarted extends GameplayEvent {
  const GameplayRestarted();
}

class GameplayUndoRequested extends GameplayEvent {
  const GameplayUndoRequested();
}

/// Lays the solved board over the current one as gold ghost mirrors.
class GameplayHintRequested extends GameplayEvent {
  const GameplayHintRequested();
}

/// Closes the hint panel. The ghost solution stays on the board: the player
/// paid for it, and it is the only record of what the hint said.
class GameplayHintDismissed extends GameplayEvent {
  const GameplayHintDismissed();
}

class GameplayState extends Equatable {
  const GameplayState({
    required this.phase,
    this.level,
    this.mirrorAngles = const {},
    this.beam = BeamSimulationResult.empty,
    this.chargeProgress = 0,
    this.powerOnProgress = 0,
    this.moves = 0,
    this.elapsedSeconds = 0,
    this.hintsUsed = 0,
    this.solutionRevealed = false,
    this.activeMirrorId,
    this.highlightedMirrorId,
    this.ghostAngles = const {},
    this.undoStack = const [],
    this.alignedTargetId,
    this.alignedTargetKind,
    this.alignmentPulse = 0,
    this.rejectedCrystalIds = const {},
  });

  final GameplayPhase phase;
  final LevelModel? level;
  final Map<String, double> mirrorAngles;
  final BeamSimulationResult beam;
  final double chargeProgress;
  final double powerOnProgress;
  final int moves;
  final double elapsedSeconds;
  final int hintsUsed;

  /// Whether the player has seen the solved board for this level.
  final bool solutionRevealed;

  final String? activeMirrorId;
  final String? highlightedMirrorId;
  final Map<String, double> ghostAngles;
  final List<Map<String, double>> undoStack;

  /// The mirror or crystal the beam is currently centred on, while dragging.
  final String? alignedTargetId;
  final AlignmentTargetKind? alignedTargetKind;

  /// Bumped every time the drag settles onto a new target, so the UI can fire
  /// one haptic tick per lock instead of one per frame.
  final int alignmentPulse;

  /// Crystals the beam is touching by a route the level does not accept — it
  /// skipped a mirror it was supposed to bounce off.
  final Set<String> rejectedCrystalIds;

  bool get isSolved => phase == GameplayPhase.solved;

  GameplayState copyWith({
    GameplayPhase? phase,
    LevelModel? level,
    Map<String, double>? mirrorAngles,
    BeamSimulationResult? beam,
    double? chargeProgress,
    double? powerOnProgress,
    int? moves,
    double? elapsedSeconds,
    int? hintsUsed,
    bool? solutionRevealed,
    String? activeMirrorId,
    String? highlightedMirrorId,
    Map<String, double>? ghostAngles,
    List<Map<String, double>>? undoStack,
    String? alignedTargetId,
    AlignmentTargetKind? alignedTargetKind,
    int? alignmentPulse,
    Set<String>? rejectedCrystalIds,
    bool clearActiveMirror = false,
    bool clearHighlight = false,
    bool clearAlignment = false,
  }) {
    return GameplayState(
      phase: phase ?? this.phase,
      level: level ?? this.level,
      mirrorAngles: mirrorAngles ?? this.mirrorAngles,
      beam: beam ?? this.beam,
      chargeProgress: chargeProgress ?? this.chargeProgress,
      powerOnProgress: powerOnProgress ?? this.powerOnProgress,
      moves: moves ?? this.moves,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      solutionRevealed: solutionRevealed ?? this.solutionRevealed,
      activeMirrorId: clearActiveMirror
          ? null
          : (activeMirrorId ?? this.activeMirrorId),
      highlightedMirrorId: clearHighlight
          ? null
          : (highlightedMirrorId ?? this.highlightedMirrorId),
      ghostAngles: ghostAngles ?? this.ghostAngles,
      undoStack: undoStack ?? this.undoStack,
      alignedTargetId: clearAlignment
          ? null
          : (alignedTargetId ?? this.alignedTargetId),
      alignedTargetKind: clearAlignment
          ? null
          : (alignedTargetKind ?? this.alignedTargetKind),
      alignmentPulse: alignmentPulse ?? this.alignmentPulse,
      rejectedCrystalIds: rejectedCrystalIds ?? this.rejectedCrystalIds,
    );
  }

  int computeStars() {
    // Being shown the answer caps the reward, however fast the finish was.
    if (solutionRevealed) return 1;
    final thresholds = level?.starThresholds;
    if (thresholds != null &&
        moves <= thresholds.threeStarMoveCount &&
        elapsedSeconds <= thresholds.threeStarTimeSeconds) {
      return 3;
    }
    return 2;
  }

  @override
  List<Object?> get props => [
    phase,
    level,
    mirrorAngles,
    beam,
    chargeProgress,
    powerOnProgress,
    moves,
    elapsedSeconds,
    hintsUsed,
    solutionRevealed,
    activeMirrorId,
    highlightedMirrorId,
    ghostAngles,
    undoStack,
    alignedTargetId,
    alignedTargetKind,
    alignmentPulse,
    rejectedCrystalIds,
  ];
}

class GameplayBloc extends Bloc<GameplayEvent, GameplayState> {
  GameplayBloc({
    required LevelRepository levelRepository,
    BeamSimulator? simulator,
    WinConditionEvaluator? winEvaluator,
    BeamAlignmentFinder? alignmentFinder,
    AnalyticsService? analytics,
  }) : _levelRepository = levelRepository,
       _analytics = analytics,
       _simulator = simulator ?? BeamSimulator(),
       _win = winEvaluator ?? const WinConditionEvaluator(),
       _alignment =
           alignmentFinder ??
           BeamAlignmentFinder(simulator: simulator ?? BeamSimulator()),
       super(const GameplayState(phase: GameplayPhase.loading)) {
    on<GameplayLoadLevel>(_onLoadLevel);
    on<GameplayStarted>(_onStarted);
    on<GameplayMirrorDragStarted>(_onDragStarted);
    on<GameplayMirrorDragged>(_onDragged);
    on<GameplayMirrorDragEnded>(_onDragEnded);
    on<GameplayTick>(_onTick);
    on<GameplayPaused>(_onPaused);
    on<GameplayResumed>(_onResumed);
    on<GameplayRestarted>(_onRestarted);
    on<GameplayUndoRequested>(_onUndo);
    on<GameplayHintRequested>(_onHint);
    on<GameplayHintDismissed>(_onHintDismissed);
  }

  static const int _tickMs = 16;
  static const double _powerOnSeconds = 0.4;

  /// Inside this radius `atan2` around the hinge is mostly noise.
  static const double _dragDeadRadius = 26;

  /// Radius at which the mirror tracks the finger one to one.
  static const double _dragFullRadius = 90;

  /// A larger jump between two updates means the finger crossed the post
  /// rather than swept around it.
  static const double _dragMaxStep = 60;

  /// How close the drag has to come before a detent grabs it.
  static const double _detentCapture = 2.5;

  /// How far past the detent the finger must sweep to pull free. Wider than
  /// the capture window so the mirror holds still for a moment instead of
  /// flickering in and out of the lock.
  static const double _detentRelease = 5.5;

  final LevelRepository _levelRepository;
  final AnalyticsService? _analytics;
  final BeamSimulator _simulator;
  final WinConditionEvaluator _win;
  final BeamAlignmentFinder _alignment;
  Timer? _tickTimer;
  double _elapsedSeconds = 0;

  double _dragPointerAngle = 0;
  double _dragAngle = 0;
  double _dragStartAngle = 0;
  Map<String, double>? _dragUndoSnapshot;
  List<BeamDetent> _dragDetents = const [];
  BeamDetent? _heldDetent;

  Future<void> _onLoadLevel(
    GameplayLoadLevel event,
    Emitter<GameplayState> emit,
  ) async {
    emit(const GameplayState(phase: GameplayPhase.loading));
    try {
      final level = await _levelRepository.loadLevel(event.levelId);
      if (isClosed) return;
      add(GameplayStarted(level));
    } catch (_) {
      if (isClosed) return;
      emit(const GameplayState(phase: GameplayPhase.loadFailed));
    }
  }

  Set<String> _rejectedFor(LevelModel level, BeamSimulationResult beam) =>
      _win.evaluate(level: level, beam: beam).rejectedCrystalIds;

  void _startTicker() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (_) => add(GameplayTick(_tickMs / 1000)),
    );
  }

  void _stopTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  @override
  Future<void> close() {
    _stopTicker();
    return super.close();
  }

  Future<void> _onStarted(
    GameplayStarted event,
    Emitter<GameplayState> emit,
  ) async {
    _elapsedSeconds = 0;
    final angles = {for (final m in event.level.mirrors) m.id: m.initialAngle};
    final beam = _simulator.simulate(level: event.level, mirrorAngles: angles);
    emit(
      GameplayState(
        phase: GameplayPhase.playing,
        level: event.level,
        mirrorAngles: angles,
        beam: beam,
        powerOnProgress: 0,
        rejectedCrystalIds: _rejectedFor(event.level, beam),
      ),
    );
    _startTicker();
    unawaited(
      _analytics?.logLevelStarted(
        levelNumber: GameConstants.displayLevelNumber(
          event.level.chapterId,
          event.level.levelIndex,
        ),
        difficulty: event.level.chapterId,
        source: 'gameplay',
      ),
    );
  }

  void _onDragStarted(
    GameplayMirrorDragStarted event,
    Emitter<GameplayState> emit,
  ) {
    if (state.phase != GameplayPhase.playing) return;
    final level = state.level;
    if (level == null) return;
    final matches = level.mirrors.where((m) => m.id == event.mirrorId);
    if (matches.isEmpty || matches.first.isLocked) return;
    final mirror = matches.first;

    _dragStartAngle = state.mirrorAngles[event.mirrorId] ?? mirror.initialAngle;
    _dragAngle = ReflectionMath.clampAngle(
      ReflectionMath.normalizeMirrorAngle(_dragStartAngle),
      mirror.minAngle,
      mirror.maxAngle,
    );
    _dragPointerAngle = ReflectionMath.angleFromHingeToPoint(
      mirror.hingePosition,
      event.grabPoint,
    );
    _dragUndoSnapshot = Map<String, double>.from(state.mirrorAngles);

    // The other mirrors hold still for the whole drag, so the angles worth
    // stopping at can be worked out once, here, instead of every frame.
    _heldDetent = null;
    _dragDetents = mirror.snapIncrement > 0
        ? const []
        : _alignment.detentsFor(
            level: level,
            mirrorAngles: state.mirrorAngles,
            mirrorId: event.mirrorId,
          );

    emit(state.copyWith(activeMirrorId: event.mirrorId, clearAlignment: true));
  }

  /// Magnetic capture with hysteresis: a detent grabs the drag from close in
  /// and only lets go once the finger has clearly swept past it.
  double _applyDetent(double rawAngle) {
    final held = _heldDetent;
    if (held != null) {
      if ((rawAngle - held.angleDegrees).abs() <= _detentRelease) {
        return held.angleDegrees;
      }
      _heldDetent = null;
    }

    BeamDetent? nearest;
    var nearestDistance = double.infinity;
    for (final detent in _dragDetents) {
      final distance = (rawAngle - detent.angleDegrees).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = detent;
      }
    }
    if (nearest == null || nearestDistance > _detentCapture) return rawAngle;

    _heldDetent = nearest;
    return nearest.angleDegrees;
  }

  void _onDragged(GameplayMirrorDragged event, Emitter<GameplayState> emit) {
    if (state.phase != GameplayPhase.playing) return;
    final level = state.level;
    if (level == null) return;
    final mirrorList = level.mirrors.where((m) => m.id == event.mirrorId);
    if (mirrorList.isEmpty) return;
    final mirror = mirrorList.first;
    if (mirror.isLocked) return;

    final offset = event.worldPoint - mirror.hingePosition;
    final pointer = ReflectionMath.degreesFromDirection(offset);
    final step = ReflectionMath.signedAngleDelta(_dragPointerAngle, pointer);
    _dragPointerAngle = pointer;

    // Keep following the finger through the noisy zone and across the post, but
    // don't turn either of those into rotation.
    final radius = offset.length;
    if (radius < _dragDeadRadius || step.abs() > _dragMaxStep) return;

    // Damping near the hinge keeps a small finger move a small rotation.
    final gain = math.min(1.0, radius / _dragFullRadius);
    _dragAngle = ReflectionMath.clampAngle(
      _dragAngle + step * gain,
      mirror.minAngle,
      mirror.maxAngle,
    );

    // Snap the reported angle only — the accumulator stays continuous so the
    // mirror doesn't stick when the finger reverses inside one detent.
    final previousDetent = _heldDetent;
    var angle = _dragAngle;
    if (mirror.snapIncrement > 0) {
      angle = ReflectionMath.clampAngle(
        (angle / mirror.snapIncrement).round() * mirror.snapIncrement,
        mirror.minAngle,
        mirror.maxAngle,
      );
    } else {
      angle = _applyDetent(angle);
    }

    final held = _heldDetent;
    final lockChanged = held != previousDetent;
    if (angle == state.mirrorAngles[event.mirrorId] && !lockChanged) return;

    final angles = Map<String, double>.from(state.mirrorAngles)
      ..[event.mirrorId] = angle;
    final beam = _simulator.simulate(level: level, mirrorAngles: angles);
    emit(
      state.copyWith(
        mirrorAngles: angles,
        beam: beam,
        chargeProgress: 0,
        rejectedCrystalIds: _rejectedFor(level, beam),
        clearAlignment: held == null,
        alignedTargetId: held?.targetId,
        alignedTargetKind: held?.kind,
        // Only a fresh lock pulses; holding one must not retrigger the haptic.
        alignmentPulse: held != null && lockChanged
            ? state.alignmentPulse + 1
            : state.alignmentPulse,
      ),
    );
  }

  void _onDragEnded(
    GameplayMirrorDragEnded event,
    Emitter<GameplayState> emit,
  ) {
    final active = state.activeMirrorId;
    final snapshot = _dragUndoSnapshot;
    _dragUndoSnapshot = null;
    _dragDetents = const [];
    _heldDetent = null;

    // Grabbing a mirror and letting go without turning it costs nothing.
    if (active == null ||
        snapshot == null ||
        state.mirrorAngles[active] == _dragStartAngle) {
      emit(state.copyWith(clearActiveMirror: true, clearAlignment: true));
      return;
    }

    emit(
      state.copyWith(
        clearActiveMirror: true,
        clearAlignment: true,
        moves: state.moves + 1,
        undoStack: List<Map<String, double>>.from(state.undoStack)
          ..add(snapshot),
      ),
    );
  }

  void _onTick(GameplayTick event, Emitter<GameplayState> emit) {
    final powerOn = state.powerOnProgress < 1
        ? math.min(
            1.0,
            state.powerOnProgress + event.dtSeconds / _powerOnSeconds,
          )
        : state.powerOnProgress;

    if (state.phase != GameplayPhase.playing || state.level == null) {
      if (powerOn != state.powerOnProgress) {
        emit(state.copyWith(powerOnProgress: powerOn));
      }
      return;
    }

    // Only playing time counts against the three-star threshold.
    _elapsedSeconds += event.dtSeconds;

    final verdict = _win.evaluate(level: state.level!, beam: state.beam);

    var charge = state.chargeProgress;
    if (verdict.satisfied) {
      charge += event.dtSeconds / GameConstants.holdTimeSeconds;
      if (charge >= 1) {
        _stopTicker();
        emit(
          state.copyWith(
            phase: GameplayPhase.solved,
            chargeProgress: 1,
            powerOnProgress: powerOn,
            elapsedSeconds: _elapsedSeconds,
          ),
        );
        final level = state.level!;
        unawaited(
          _analytics?.logLevelCompleted(
            levelNumber: GameConstants.displayLevelNumber(
              level.chapterId,
              level.levelIndex,
            ),
            difficulty: level.chapterId,
            moves: state.moves,
            timeSeconds: _elapsedSeconds.round(),
            source: 'gameplay',
          ),
        );
        return;
      }
    } else {
      charge = 0;
    }

    // Skip emit when only elapsed time advances (no visual change).
    if (powerOn == state.powerOnProgress && charge == state.chargeProgress) {
      return;
    }

    emit(
      state.copyWith(
        chargeProgress: charge,
        powerOnProgress: powerOn,
        elapsedSeconds: _elapsedSeconds,
      ),
    );
  }

  void _onPaused(GameplayPaused event, Emitter<GameplayState> emit) {
    if (state.phase == GameplayPhase.playing) {
      _stopTicker();
      emit(state.copyWith(phase: GameplayPhase.paused));
    }
  }

  void _onResumed(GameplayResumed event, Emitter<GameplayState> emit) {
    if (state.phase == GameplayPhase.paused ||
        state.phase == GameplayPhase.hint) {
      emit(state.copyWith(phase: GameplayPhase.playing));
      _startTicker();
    }
  }

  void _onRestarted(GameplayRestarted event, Emitter<GameplayState> emit) {
    final level = state.level;
    if (level == null) return;
    _elapsedSeconds = 0;
    _dragUndoSnapshot = null;
    _dragDetents = const [];
    _heldDetent = null;
    final angles = {for (final m in level.mirrors) m.id: m.initialAngle};
    final beam = _simulator.simulate(level: level, mirrorAngles: angles);
    emit(
      GameplayState(
        phase: GameplayPhase.playing,
        level: level,
        mirrorAngles: angles,
        beam: beam,
        powerOnProgress: 0,
        // Hints already spent stay spent — otherwise the solution could be
        // bought, memorised, and restarted away for a free three stars.
        hintsUsed: state.hintsUsed,
        solutionRevealed: state.solutionRevealed,
        // The ghosts are the answer to this board, so a restart keeps them.
        ghostAngles: state.ghostAngles,
        rejectedCrystalIds: _rejectedFor(level, beam),
      ),
    );
    _startTicker();
  }

  void _onUndo(GameplayUndoRequested event, Emitter<GameplayState> emit) {
    if (state.undoStack.isEmpty || state.level == null) return;
    final stack = List<Map<String, double>>.from(state.undoStack);
    final previous = stack.removeLast();
    final beam = _simulator.simulate(
      level: state.level!,
      mirrorAngles: previous,
    );
    emit(
      state.copyWith(
        mirrorAngles: previous,
        beam: beam,
        undoStack: stack,
        chargeProgress: 0,
        phase: GameplayPhase.playing,
        // The move being undone shouldn't keep counting against the star budget.
        moves: math.max(0, state.moves - 1),
        rejectedCrystalIds: _rejectedFor(state.level!, beam),
      ),
    );
  }

  void _onHint(GameplayHintRequested event, Emitter<GameplayState> emit) {
    final level = state.level;
    if (level == null) return;
    final solution = level.intendedSolution.mirrorAngles;
    if (solution.isEmpty) return;

    // The whole solved board at once. Anything less had the player buying
    // three separate nudges to work out one answer.
    final ghosts = <String, double>{};
    for (final mirror in level.mirrors) {
      final angle = solution[mirror.id];
      // A locked mirror is already where the solution wants it; ghosting it
      // just clutters the board.
      if (angle == null || mirror.isLocked) continue;
      ghosts[mirror.id] = angle;
    }
    if (ghosts.isEmpty) return;

    _stopTicker();
    emit(
      state.copyWith(
        phase: GameplayPhase.hint,
        ghostAngles: ghosts,
        hintsUsed: state.hintsUsed + 1,
        solutionRevealed: true,
        clearHighlight: true,
      ),
    );
    unawaited(
      _analytics?.logHintUsed(
        levelNumber: GameConstants.displayLevelNumber(
          level.chapterId,
          level.levelIndex,
        ),
        source: 'gameplay',
      ),
    );
  }

  void _onHintDismissed(
    GameplayHintDismissed event,
    Emitter<GameplayState> emit,
  ) {
    if (state.phase != GameplayPhase.hint) return;
    emit(state.copyWith(phase: GameplayPhase.playing));
    _startTicker();
  }
}
