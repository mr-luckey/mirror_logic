import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_painter.dart'
    show worldToScreen;
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_walkthrough.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_hand.dart';

/// Plays the opening board for the player with a cartoon hand.
///
/// A first-time player who has only read the rules still has to guess what a
/// mirror does when touched, so the hand takes the first mirror itself, turns it
/// on the real board, and then hands over: the next mirror is only demonstrated
/// if the player leaves it alone. Touching anything at any point ends the
/// walkthrough — someone who has started playing does not need to be shown.
class GameplayWalkthroughLayer extends StatefulWidget {
  const GameplayWalkthroughLayer({
    super.key,
    required this.level,
    required this.canvasSize,
  });

  final LevelModel level;
  final Size canvasSize;

  @override
  State<GameplayWalkthroughLayer> createState() =>
      _GameplayWalkthroughLayerState();
}

enum _Stage { opening, reaching, turning, holding, lifting, inviting, done }

class _GameplayWalkthroughLayerState extends State<GameplayWalkthroughLayer>
    with SingleTickerProviderStateMixin {
  static const _openHold = Duration(milliseconds: 900);
  static const _reach = Duration(milliseconds: 480);
  static const _hold = Duration(milliseconds: 420);
  static const _lift = Duration(milliseconds: 320);

  /// How long the invitation waits before the hand does it after all.
  static const _inviteHold = Duration(seconds: 5);

  late final Ticker _ticker = createTicker(_onFrame);
  late final List<WalkthroughLesson> _lessons;

  _Stage _stage = _Stage.opening;
  Duration _stageStart = Duration.zero;
  Duration _stageLength = _openHold;

  Duration _elapsed = Duration.zero;
  int _index = 0;

  /// The mirror the hand is holding, so a grab on any other one reads as the
  /// player taking over.
  String? _driving;

  Vec2? _hand;
  double _handOpacity = 0;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<GameplayBloc>();
    _lessons = Walkthrough.lessonsFor(
      level: widget.level,
      angles: bloc.state.mirrorAngles,
    );
    if (_lessons.isEmpty) {
      _stage = _Stage.done;
      return;
    }
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  WalkthroughLesson get _lesson => _lessons[_index];

  void _enter(_Stage stage, Duration length) {
    _stage = stage;
    _stageStart = _elapsed;
    _stageLength = length;
  }

  void _onFrame(Duration elapsed) {
    _elapsed = elapsed;
    final since = elapsed - _stageStart;
    final progress = _stageLength.inMicroseconds == 0
        ? 1.0
        : (since.inMicroseconds / _stageLength.inMicroseconds).clamp(0.0, 1.0);

    switch (_stage) {
      case _Stage.opening:
        if (progress >= 1) _beginDemo();
      case _Stage.reaching:
        final t = Curves.easeOutCubic.transform(progress);
        _hand = _lerp(_approachPoint(_lesson), _lesson.grabPoint, t);
        _handOpacity = math.min(1, progress * 2.2);
        if (progress >= 1) _press();
      case _Stage.turning:
        final t = Curves.easeInOutCubic.transform(progress);
        _hand = _lesson.pointAt(_lesson.angleAt(t));
        _drive(_hand!);
        if (progress >= 1) _enter(_Stage.holding, _hold);
      case _Stage.holding:
        if (progress >= 1) _release();
      case _Stage.lifting:
        _hand = _lerp(
          _lesson.pointAt(_lesson.toAngle),
          _lesson.pointAt(_lesson.toAngle) + const Vec2(30, 130),
          Curves.easeOut.transform(progress),
        );
        _handOpacity = 1 - progress;
        if (progress >= 1) _nextLesson();
      case _Stage.inviting:
        // A small rock back and forth along the arc: the shape of the gesture
        // being asked for, without turning the mirror.
        final bob = math.sin(since.inMilliseconds / 460 * math.pi) * 7;
        _hand = _lesson.pointAt(_lesson.fromAngle + bob);
        _handOpacity = math.min(1, since.inMilliseconds / 300);
        _pressing = bob.abs() > 3.5;
        if (since >= _inviteHold) _beginDemo();
      case _Stage.done:
        return;
    }

    if (mounted) setState(() {});
  }

  Vec2 _approachPoint(WalkthroughLesson lesson) =>
      lesson.grabPoint + const Vec2(70, 170);

  static Vec2 _lerp(Vec2 a, Vec2 b, double t) =>
      Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

  void _beginDemo() {
    _pressing = false;
    _hand = _approachPoint(_lesson);
    _enter(_Stage.reaching, _reach);
  }

  void _press() {
    _driving = _lesson.mirrorId;
    _pressing = true;
    context.read<GameplayBloc>().add(
      GameplayMirrorDragStarted(
        mirrorId: _lesson.mirrorId,
        grabPoint: _lesson.grabPoint,
      ),
    );
    _enter(_Stage.turning, _lesson.turnDuration);
  }

  void _drive(Vec2 point) {
    context.read<GameplayBloc>().add(
      GameplayMirrorDragged(mirrorId: _lesson.mirrorId, worldPoint: point),
    );
  }

  void _release() {
    context.read<GameplayBloc>().add(const GameplayMirrorDragEnded());
    _driving = null;
    _pressing = false;
    _enter(_Stage.lifting, _lift);
  }

  void _nextLesson() {
    if (_index + 1 >= _lessons.length) {
      _finish(release: false);
      return;
    }
    _index++;
    _handOpacity = 0;
    _pressing = false;
    _enter(_Stage.inviting, _inviteHold);
  }

  /// Packs the hand away for good. [release] closes a drag the hand still has
  /// hold of; it must stay false when the player has grabbed a mirror, because
  /// the board only tracks one drag and that one is now theirs.
  void _finish({required bool release}) {
    if (_stage == _Stage.done) return;
    if (release && _driving != null) {
      context.read<GameplayBloc>().add(const GameplayMirrorDragEnded());
    }
    _driving = null;
    _stage = _Stage.done;
    if (_ticker.isActive) _ticker.stop();
    context.read<ProgressBloc>().add(const ProgressWalkthroughSeen());
    if (mounted) {
      setState(() {
        _hand = null;
        _pressing = false;
      });
    }
  }

  void _onGameplay(GameplayState state) {
    if (_stage == _Stage.done) return;
    if (state.phase == GameplayPhase.solved) {
      _finish(release: false);
      return;
    }
    // Paused or reading a hint: the board is frozen under the hand.
    if (state.phase != GameplayPhase.playing) {
      _finish(release: true);
      return;
    }
    final active = state.activeMirrorId;
    if (active != null && active != _driving) _finish(release: false);
  }

  String? get _caption {
    switch (_stage) {
      case _Stage.opening:
      case _Stage.done:
        return null;
      case _Stage.reaching:
      case _Stage.turning:
      case _Stage.holding:
      case _Stage.lifting:
        return _index == 0
            ? 'Watch — drag a mirror to swing it round'
            : 'Like this — swing it round';
      case _Stage.inviting:
        return 'Your turn — turn this mirror';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hand = _hand;
    final caption = _caption;

    return BlocListener<GameplayBloc, GameplayState>(
      listenWhen: (p, c) =>
          p.phase != c.phase || p.activeMirrorId != c.activeMirrorId,
      listener: (_, state) => _onGameplay(state),
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hand != null && _stage == _Stage.inviting)
              _halo(_lessons[_index].hinge),
            if (hand != null) _handAt(hand),
            if (caption != null) _captionStrip(caption),
          ],
        ),
      ),
    );
  }

  Offset _toScreen(Vec2 world) => worldToScreen(
    world: world,
    canvasSize: widget.canvasSize,
    level: widget.level,
  );

  double get _handWidth =>
      (widget.canvasSize.shortestSide * 0.14).clamp(38.0, 66.0);

  Widget _handAt(Vec2 world) {
    final screen = _toScreen(world);
    final tip = MedievalHand.fingertipOf(_handWidth);
    return Positioned(
      left: screen.dx - tip.dx,
      top: screen.dy - tip.dy,
      child: Opacity(
        opacity: _handOpacity.clamp(0.0, 1.0),
        child: MedievalHand(width: _handWidth, pressing: _pressing),
      ),
    );
  }

  /// Ring around the post the player is being asked to turn.
  Widget _halo(Vec2 hinge) {
    final screen = _toScreen(hinge);
    final pulse =
        0.5 +
        0.5 * math.sin((_elapsed - _stageStart).inMilliseconds / 460 * math.pi);
    final radius = _handWidth * (0.85 + pulse * 0.2);

    return Positioned(
      left: screen.dx - radius,
      top: screen.dy - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: MedievalColors.bronzeHighlight.withValues(
              alpha: 0.25 + pulse * 0.4,
            ),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _captionStrip(String text) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 8,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: MedievalColors.parchment.withValues(alpha: 0.94),
            border: Border.all(color: MedievalColors.bronze, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: MedievalTextStyles.cinzel(
              size: Responsive.sp(context, 12),
              weight: FontWeight.w700,
              color: MedievalColors.parchmentInk,
            ),
          ),
        ),
      ),
    );
  }
}
