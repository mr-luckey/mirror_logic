import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

enum AlignmentTargetKind { mirror, crystal }

/// An angle at which turning a mirror lands the beam on something useful:
/// the middle of another mirror, or the heart of a target crystal.
class BeamDetent extends Equatable {
  const BeamDetent({
    required this.angleDegrees,
    required this.targetId,
    required this.kind,
  });

  final double angleDegrees;
  final String targetId;
  final AlignmentTargetKind kind;

  @override
  List<Object?> get props => [angleDegrees, targetId, kind];
}

/// Finds the angles worth stopping at while a mirror is being dragged.
///
/// Aiming a reflection by hand is fiddly: a degree of finger travel can swing
/// the far end of the beam across half the room. Rather than making the player
/// hunt for the sweet spot, we work out where the sweet spots are and let the
/// drag settle into them.
///
/// The other mirrors hold still for the duration of a drag, so the whole set
/// can be computed once when the finger goes down.
class BeamAlignmentFinder {
  BeamAlignmentFinder({BeamSimulator? simulator})
      : _simulator = simulator ?? BeamSimulator();

  final BeamSimulator _simulator;

  /// Sweep resolution. Fine enough to catch every basin, coarse enough that a
  /// whole range costs well under a frame.
  static const double coarseStepDegrees = 1;

  /// A tenth of a degree moves the far end of a long beam by about four
  /// pixels, well inside every tolerance below, so refining past this only
  /// costs frames.
  static const double fineStepDegrees = 0.1;
  static const int maxSamples = 360;

  /// How far off a mirror's midpoint the beam may land and still count.
  static const double mirrorCentreTolerance = 24;

  /// Crystal tolerance as a fraction of its hit radius.
  static const double crystalToleranceRatio = 0.5;

  /// Never hand back so many detents that the drag feels like a ratchet.
  static const int maxDetents = 16;

  List<BeamDetent> detentsFor({
    required LevelModel level,
    required Map<String, double> mirrorAngles,
    required String mirrorId,
  }) {
    final mirror = level.mirrors.where((m) => m.id == mirrorId).firstOrNull;
    if (mirror == null || mirror.isLocked) return const [];

    final span = mirror.maxAngle - mirror.minAngle;
    if (span <= 0) return const [];

    final targets = <_Target>[
      for (final m in level.mirrors)
        if (m.id != mirrorId)
          _Target(
            id: m.id,
            kind: AlignmentTargetKind.mirror,
            point: m.hingePosition,
            tolerance: math.min(mirrorCentreTolerance, m.length * 0.3),
          ),
      for (final c in level.targetCrystals)
        _Target(
          id: c.id,
          kind: AlignmentTargetKind.crystal,
          point: c.position,
          tolerance: c.hitRadius * crystalToleranceRatio,
        ),
    ];
    if (targets.isEmpty) return const [];
    if (!_beamCanReach(level, mirrorAngles, mirror)) return const [];

    final step = math.max(coarseStepDegrees, span / maxSamples);
    final angles = <double>[];
    for (var a = mirror.minAngle; a < mirror.maxAngle; a += step) {
      angles.add(a);
    }
    angles.add(mirror.maxAngle);

    final misses = [
      for (final a in angles) _misses(level, mirrorAngles, mirrorId, a, targets),
    ];

    // A target is in play across a run of angles — the whole sweep where the
    // beam lands on it at all. The best angle in that run is the detent, and
    // only then do we ask whether it is close enough to the centre to be worth
    // stopping at. Gating on the tolerance first would miss distant targets,
    // whose usable window can be narrower than a single sample.
    final detents = <BeamDetent>[];
    for (var t = 0; t < targets.length; t++) {
      final target = targets[t];
      var i = 0;
      while (i < angles.length) {
        if (misses[i][t].isInfinite) {
          i++;
          continue;
        }
        var best = i;
        var j = i;
        while (j < angles.length && misses[j][t].isFinite) {
          if (misses[j][t] < misses[best][t]) best = j;
          j++;
        }
        final (angle, miss) = _refine(
          level: level,
          mirrorAngles: mirrorAngles,
          mirrorId: mirrorId,
          target: target,
          around: angles[best],
          window: step,
          minAngle: mirror.minAngle,
          maxAngle: mirror.maxAngle,
        );
        if (miss < target.tolerance) {
          detents.add(
            BeamDetent(
              angleDegrees: angle,
              targetId: target.id,
              kind: target.kind,
            ),
          );
        }
        i = j;
      }
    }

    detents.sort((a, b) => a.angleDegrees.compareTo(b.angleDegrees));
    return detents.length <= maxDetents
        ? detents
        : detents.sublist(0, maxDetents);
  }

  /// Whether any angle of [mirror] could put it in the beam's way.
  ///
  /// Turning a mirror cannot change the path that leads up to it, so one trace
  /// settles the question for the whole sweep. If the beam already strikes the
  /// mirror there is nothing to decide; otherwise the mirror is only in play if
  /// the beam passes within its reach, since rotating it sweeps a disc of half
  /// its length. Boards carry decoys the beam never comes near, and skipping
  /// their sweep is the difference between one simulation and a few hundred.
  bool _beamCanReach(
    LevelModel level,
    Map<String, double> mirrorAngles,
    MirrorDef mirror,
  ) {
    final result = _simulator.simulate(level: level, mirrorAngles: mirrorAngles);
    final reach = mirror.length / 2;
    for (final segment in result.segments) {
      if (segment.hitKind == BeamHitKind.mirror && segment.hitId == mirror.id) {
        return true;
      }
      if (_distanceToSegment(mirror.hingePosition, segment.start, segment.end) <=
          reach) {
        return true;
      }
    }
    return false;
  }

  static double _distanceToSegment(Vec2 point, Vec2 a, Vec2 b) {
    final along = b - a;
    final span = along.lengthSquared;
    if (span < 1e-9) return point.distanceTo(a);
    var t = ((point - a).dot(along)) / span;
    t = t.clamp(0.0, 1.0);
    return point.distanceTo(a + along * t);
  }

  /// How far the beam misses each target when the dragged mirror sits at
  /// [angle]. Targets the beam never reaches score infinity.
  List<double> _misses(
    LevelModel level,
    Map<String, double> baseAngles,
    String mirrorId,
    double angle,
    List<_Target> targets,
  ) {
    final angles = Map<String, double>.from(baseAngles)..[mirrorId] = angle;
    final result = _simulator.simulate(level: level, mirrorAngles: angles);

    // Only what happens after our bounce can change with our angle.
    final start = result.segments.indexWhere(
      (s) => s.hitKind == BeamHitKind.mirror && s.hitId == mirrorId,
    );
    if (start < 0) {
      return List<double>.filled(targets.length, double.infinity);
    }
    final downstream = result.segments.sublist(start + 1);

    return [
      for (final target in targets)
        downstream.fold<double>(
          double.infinity,
          (best, s) => math.min(best, _miss(target, s)),
        ),
    ];
  }

  /// A mirror is missed by however far off its midpoint the beam struck it; a
  /// crystal by how far the beam's line passes from its heart.
  double _miss(_Target target, BeamSegment segment) {
    if (segment.hitId != target.id) return double.infinity;
    switch (target.kind) {
      case AlignmentTargetKind.mirror:
        if (segment.hitKind != BeamHitKind.mirror) return double.infinity;
        return segment.end.distanceTo(target.point);
      case AlignmentTargetKind.crystal:
        if (segment.hitKind != BeamHitKind.crystal) return double.infinity;
        final along = segment.end - segment.start;
        final length = along.length;
        if (length < 1e-6) return double.infinity;
        final dir = along * (1 / length);
        final toTarget = target.point - segment.start;
        return (toTarget.x * dir.y - toTarget.y * dir.x).abs();
    }
  }

  /// Best angle in the window around [around], with how far it still misses.
  (double, double) _refine({
    required LevelModel level,
    required Map<String, double> mirrorAngles,
    required String mirrorId,
    required _Target target,
    required double around,
    required double window,
    required double minAngle,
    required double maxAngle,
  }) {
    final from = math.max(minAngle, around - window);
    final to = math.min(maxAngle, around + window);
    var bestAngle = around;
    var bestMiss = double.infinity;
    for (var a = from; a <= to + 1e-9; a += fineStepDegrees) {
      final miss = _misses(level, mirrorAngles, mirrorId, a, [target]).first;
      if (miss < bestMiss) {
        bestMiss = miss;
        bestAngle = a;
      }
    }
    return (bestAngle, bestMiss);
  }
}

class _Target {
  const _Target({
    required this.id,
    required this.kind,
    required this.point,
    required this.tolerance,
  });

  final String id;
  final AlignmentTargetKind kind;
  final Vec2 point;
  final double tolerance;
}
