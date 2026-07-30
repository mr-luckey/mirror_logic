import 'dart:math' as math;

import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/reflection_math.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

/// Deterministic geometric raycast beam simulator (no rigid-body engine).
class BeamSimulator {
  BeamSimulator({BeamSegmentPool? pool}) : _pool = pool ?? BeamSegmentPool();

  final BeamSegmentPool _pool;
  static const double _epsilon = 1e-6;
  static const double _maxRayLength = 5000;

  BeamSimulationResult simulate({
    required LevelModel level,
    required Map<String, double> mirrorAngles,
  }) {
    final segments = _pool.acquire();
    final lit = <String>{};

    for (final source in level.lightSources) {
      _traceSource(
        level: level,
        mirrorAngles: mirrorAngles,
        origin: source.mountedOrigin(level.roomBounds),
        direction: ReflectionMath.directionFromDegrees(source.directionDegrees),
        segments: segments,
        lit: lit,
      );
    }

    return BeamSimulationResult(
      segments: _pool.freeze(segments),
      litCrystalIds: Set<String>.unmodifiable(lit),
    );
  }

  void _traceSource({
    required LevelModel level,
    required Map<String, double> mirrorAngles,
    required Vec2 origin,
    required Vec2 direction,
    required List<BeamSegment> segments,
    required Set<String> lit,
  }) {
    var pos = origin;
    var dir = direction.normalized();
    if (dir.lengthSquared < _epsilon) return;

    for (var bounce = 0; bounce < GameConstants.maxBounces; bounce++) {
      final hit = _findNearestHit(
        level: level,
        mirrorAngles: mirrorAngles,
        origin: pos,
        direction: dir,
      );

      if (hit == null) {
        final end = pos + dir * _maxRayLength;
        segments.add(BeamSegment(start: pos, end: end));
        return;
      }

      segments.add(
        BeamSegment(
          start: pos,
          end: hit.point,
          hitKind: hit.kind,
          hitId: hit.id,
        ),
      );

      if (hit.kind == BeamHitKind.crystal) {
        lit.add(hit.id!);
        if (hit.relay) {
          pos = hit.point + dir * 0.5;
          continue;
        }
        return;
      }

      if (hit.kind == BeamHitKind.wall || hit.kind == BeamHitKind.bounds) {
        return;
      }

      if (hit.kind == BeamHitKind.mirror) {
        final reflected = ReflectionMath.reflect(dir, hit.normal!);
        // Nudge off surface to avoid re-hitting same mirror.
        pos = hit.point + reflected * 0.5;
        dir = reflected.normalized();
        continue;
      }

      return;
    }
  }

  _Hit? _findNearestHit({
    required LevelModel level,
    required Map<String, double> mirrorAngles,
    required Vec2 origin,
    required Vec2 direction,
  }) {
    _Hit? best;

    void consider(_Hit? candidate) {
      if (candidate == null) return;
      if (candidate.distance < _epsilon) return;
      if (best == null || candidate.distance < best!.distance) {
        best = candidate;
      }
    }

    // Room bounds as four walls.
    final w = level.roomBounds.x;
    final h = level.roomBounds.y;
    consider(
      _raySegment(origin, direction, const Vec2(0, 0), Vec2(w, 0), BeamHitKind.bounds, 'top'),
    );
    consider(
      _raySegment(origin, direction, Vec2(0, h), Vec2(w, h), BeamHitKind.bounds, 'bottom'),
    );
    consider(
      _raySegment(origin, direction, const Vec2(0, 0), Vec2(0, h), BeamHitKind.bounds, 'left'),
    );
    consider(
      _raySegment(origin, direction, Vec2(w, 0), Vec2(w, h), BeamHitKind.bounds, 'right'),
    );

    for (final obstacle in level.obstacles) {
      if (obstacle.isDecorative) continue;
      for (var i = 0; i < obstacle.polygon.length; i++) {
        final a = obstacle.polygon[i];
        final b = obstacle.polygon[(i + 1) % obstacle.polygon.length];
        consider(
          _raySegment(origin, direction, a, b, BeamHitKind.wall, obstacle.id),
        );
      }
    }

    for (final mirror in level.mirrors) {
      final angle = mirrorAngles[mirror.id] ?? mirror.initialAngle;
      final (a, b) = ReflectionMath.mirrorEndpoints(
        hinge: mirror.hingePosition,
        length: mirror.length,
        angleDegrees: angle,
      );
      final hit = _raySegment(
        origin,
        direction,
        a,
        b,
        BeamHitKind.mirror,
        mirror.id,
      );
      if (hit != null) {
        final normal = ReflectionMath.mirrorNormal(angle);
        // Ensure normal faces incoming ray.
        final facing = normal.dot(direction) > 0 ? -normal : normal;
        consider(
          _Hit(
            point: hit.point,
            distance: hit.distance,
            kind: BeamHitKind.mirror,
            id: mirror.id,
            normal: facing,
          ),
        );
      }
    }

    for (final crystal in level.targetCrystals) {
      final hit = _rayCircle(
        origin,
        direction,
        crystal.position,
        crystal.hitRadius,
      );
      if (hit != null) {
        consider(
          _Hit(
            point: hit.point,
            distance: hit.distance,
            kind: BeamHitKind.crystal,
            id: crystal.id,
            relay: crystal.relay,
          ),
        );
      }
    }

    return best;
  }

  _Hit? _raySegment(
    Vec2 origin,
    Vec2 direction,
    Vec2 a,
    Vec2 b,
    BeamHitKind kind,
    String id,
  ) {
    final v1 = origin - a;
    final v2 = b - a;
    final v3 = Vec2(-direction.y, direction.x);
    final dot = v2.dot(v3);
    if (dot.abs() < _epsilon) return null;

    final t1 = v2.perp.dot(v1) / dot;
    final t2 = v1.dot(v3) / dot;
    if (t1 >= _epsilon && t2 >= 0 && t2 <= 1) {
      final point = origin + direction * t1;
      return _Hit(point: point, distance: t1, kind: kind, id: id);
    }
    return null;
  }

  _Hit? _rayCircle(Vec2 origin, Vec2 direction, Vec2 center, double radius) {
    final oc = origin - center;
    final a = direction.dot(direction);
    final b = 2 * oc.dot(direction);
    final c = oc.dot(oc) - radius * radius;
    final disc = b * b - 4 * a * c;
    if (disc < 0) return null;
    final sqrtDisc = math.sqrt(disc);
    final t0 = (-b - sqrtDisc) / (2 * a);
    final t1 = (-b + sqrtDisc) / (2 * a);
    final t = t0 >= _epsilon ? t0 : (t1 >= _epsilon ? t1 : -1.0);
    if (t < _epsilon) return null;
    return _Hit(
      point: origin + direction * t,
      distance: t,
      kind: BeamHitKind.crystal,
      id: '',
    );
  }
}

class _Hit {
  const _Hit({
    required this.point,
    required this.distance,
    required this.kind,
    this.id,
    this.normal,
    this.relay = false,
  });

  final Vec2 point;
  final double distance;
  final BeamHitKind kind;
  final String? id;
  final Vec2? normal;
  final bool relay;
}
