import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_painter.dart'
    show worldToScreen;

/// Short-lived sparks and bursts painted over the board.
///
/// Driven by gameplay events rather than the continuous painter loop, so a
/// crystal lighting up feels like a moment, not a permanent glow change.
class GameplayFxLayer extends StatefulWidget {
  const GameplayFxLayer({super.key, required this.canvasSize});

  final Size canvasSize;

  @override
  State<GameplayFxLayer> createState() => _GameplayFxLayerState();
}

class _GameplayFxLayerState extends State<GameplayFxLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  final List<_Burst> _bursts = [];
  Set<String> _lit = {};
  Set<String> _rejected = {};
  int _mirrorHits = 0;
  bool _won = false;

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  void _spawn({
    required Offset origin,
    required _BurstKind kind,
    int count = 14,
  }) {
    final now = _tick.lastElapsedDuration?.inMilliseconds ?? 0;
    _bursts.add(
      _Burst(
        origin: origin,
        kind: kind,
        bornMs: now.toDouble(),
        seeds: List.generate(count, (i) => i * 17 + kind.index * 31),
      ),
    );
    // Cap so a long drag cannot accumulate forever.
    if (_bursts.length > 12) {
      _bursts.removeRange(0, _bursts.length - 12);
    }
  }

  Offset? _toScreen(LevelModel level, Vec2 world) {
    return worldToScreen(
      world: world,
      canvasSize: widget.canvasSize,
      level: level,
    );
  }

  void _onState(GameplayState state) {
    final level = state.level;
    if (level == null) return;

    final lit = state.beam.litCrystalIds;
    for (final id in lit.difference(_lit)) {
      final crystal = level.targetCrystals.where((c) => c.id == id);
      if (crystal.isEmpty) continue;
      final screen = _toScreen(level, crystal.first.position);
      if (screen != null) {
        _spawn(origin: screen, kind: _BurstKind.crystal, count: 22);
      }
    }
    _lit = Set.of(lit);

    final rejected = state.rejectedCrystalIds;
    for (final id in rejected.difference(_rejected)) {
      final crystal = level.targetCrystals.where((c) => c.id == id);
      if (crystal.isEmpty) continue;
      final screen = _toScreen(level, crystal.first.position);
      if (screen != null) {
        _spawn(origin: screen, kind: _BurstKind.reject, count: 12);
      }
    }
    _rejected = Set.of(rejected);

    var hits = 0;
    for (final seg in state.beam.segments) {
      if (seg.hitKind == BeamHitKind.mirror) hits++;
    }
    if (hits > _mirrorHits) {
      for (final seg in state.beam.segments.reversed) {
        if (seg.hitKind != BeamHitKind.mirror) continue;
        final screen = _toScreen(level, seg.end);
        if (screen != null) {
          _spawn(origin: screen, kind: _BurstKind.spark, count: 10);
        }
        break;
      }
    }
    _mirrorHits = hits;

    if (!_won && state.phase == GameplayPhase.solved) {
      _won = true;
      final centre = Offset(
        widget.canvasSize.width * 0.5,
        widget.canvasSize.height * 0.45,
      );
      _spawn(origin: centre, kind: _BurstKind.win, count: 36);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameplayBloc, GameplayState>(
      listener: (context, state) => _onState(state),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _tick,
          builder: (_, _) {
            final now =
                (_tick.lastElapsedDuration?.inMilliseconds ?? 0).toDouble();
            _bursts.removeWhere((b) => now - b.bornMs > b.kind.lifeMs);
            return CustomPaint(
              size: widget.canvasSize,
              painter: _FxPainter(bursts: List.of(_bursts), nowMs: now),
            );
          },
        ),
      ),
    );
  }
}

enum _BurstKind {
  spark(420),
  crystal(900),
  reject(650),
  win(1400);

  const _BurstKind(this.lifeMs);
  final double lifeMs;
}

class _Burst {
  _Burst({
    required this.origin,
    required this.kind,
    required this.bornMs,
    required this.seeds,
  });

  final Offset origin;
  final _BurstKind kind;
  final double bornMs;
  final List<int> seeds;
}

class _FxPainter extends CustomPainter {
  _FxPainter({required this.bursts, required this.nowMs});

  final List<_Burst> bursts;
  final double nowMs;

  @override
  void paint(Canvas canvas, Size size) {
    for (final burst in bursts) {
      final age = ((nowMs - burst.bornMs) / burst.kind.lifeMs).clamp(0.0, 1.0);
      final fade = 1.0 - age;
      switch (burst.kind) {
        case _BurstKind.spark:
          _paintSparks(canvas, burst, age, fade);
        case _BurstKind.crystal:
          _paintCrystal(canvas, burst, age, fade);
        case _BurstKind.reject:
          _paintReject(canvas, burst, age, fade);
        case _BurstKind.win:
          _paintWin(canvas, burst, age, fade);
      }
    }
  }

  void _paintSparks(Canvas canvas, _Burst burst, double age, double fade) {
    for (final seed in burst.seeds) {
      final rng = math.Random(seed);
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = 8 + age * (28 + rng.nextDouble() * 40);
      final p = burst.origin + Offset(math.cos(angle), math.sin(angle)) * dist;
      canvas.drawCircle(
        p,
        1.2 + rng.nextDouble() * 2.2 * fade,
        Paint()
          ..color = Color.lerp(
            Colors.white,
            MedievalColors.laserMid,
            rng.nextDouble(),
          )!
              .withValues(alpha: 0.85 * fade),
      );
      if (age < 0.45) {
        canvas.drawLine(
          burst.origin,
          p,
          Paint()
            ..color = MedievalColors.laserGlow.withValues(alpha: 0.45 * fade)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintCrystal(Canvas canvas, _Burst burst, double age, double fade) {
    final ring = 20 + age * 90;
    canvas.drawCircle(
      burst.origin,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * fade
        ..color = MedievalColors.laserGlow.withValues(alpha: 0.7 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      burst.origin,
      ring * 0.55,
      Paint()
        ..color = MedievalColors.laserCore.withValues(alpha: 0.35 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    _paintSparks(canvas, burst, age, fade);
  }

  void _paintReject(Canvas canvas, _Burst burst, double age, double fade) {
    final ring = 16 + age * 55;
    canvas.drawCircle(
      burst.origin,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade
        ..color = MedievalColors.rejectMid.withValues(alpha: 0.8 * fade),
    );
    for (final seed in burst.seeds) {
      final rng = math.Random(seed);
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = 6 + age * (20 + rng.nextDouble() * 30);
      final p = burst.origin + Offset(math.cos(angle), math.sin(angle)) * dist;
      canvas.drawCircle(
        p,
        1.5 + rng.nextDouble(),
        Paint()
          ..color = MedievalColors.rejectCore.withValues(alpha: 0.85 * fade),
      );
    }
  }

  void _paintWin(Canvas canvas, _Burst burst, double age, double fade) {
    for (var i = 0; i < 3; i++) {
      final ring = 30 + age * (120 + i * 50);
      canvas.drawCircle(
        burst.origin,
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4 - i) * fade
          ..color = MedievalColors.bronzeHighlight
              .withValues(alpha: (0.55 - i * 0.12) * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(
      burst.origin,
      40 + age * 80,
      Paint()
        ..color = MedievalColors.laserGlow.withValues(alpha: 0.22 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    _paintSparks(canvas, burst, age * 0.7, fade);
  }

  @override
  bool shouldRepaint(covariant _FxPainter oldDelegate) => true;
}
