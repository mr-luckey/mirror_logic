import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/reflection_math.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_paint_snapshot.dart';

class GameplayPainter extends CustomPainter {
  GameplayPainter({required this.snapshot});

  final GameplayPaintSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final level = snapshot.level;

    final scale = math.min(
      size.width / level.roomBounds.x,
      size.height / level.roomBounds.y,
    );
    final dx = (size.width - level.roomBounds.x * scale) / 2;
    final dy = (size.height - level.roomBounds.y * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    _drawRoom(canvas, level);
    _drawObstacles(canvas, level);
    _drawBeam(canvas, snapshot.beam);
    _drawLightSources(canvas, level);
    _drawMirrors(canvas, level, snapshot);
    _drawCrystals(canvas, level, snapshot);
    canvas.restore();
  }

  void _drawRoom(Canvas canvas, LevelModel level) {
    final rect = Rect.fromLTWH(0, 0, level.roomBounds.x, level.roomBounds.y);
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, level.roomBounds.y),
        [
          const Color(0xFF0D0D1A),
          const Color(0xFF080812),
        ],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      bg,
    );

    final grid = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.04)
      ..strokeWidth = 1.5;
    const step = 60.0;
    for (var x = 0.0; x <= level.roomBounds.x; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, level.roomBounds.y), grid);
    }
    for (var y = 0.0; y <= level.roomBounds.y; y += step) {
      canvas.drawLine(Offset(0, y), Offset(level.roomBounds.x, y), grid);
    }

    final border = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      border,
    );
  }

  void _drawObstacles(Canvas canvas, LevelModel level) {
    final fill = Paint()..color = const Color(0xFF1A1A30);
    final stroke = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final o in level.obstacles) {
      if (o.polygon.length < 3) continue;
      final path = Path()
        ..moveTo(o.polygon.first.x, o.polygon.first.y);
      for (var i = 1; i < o.polygon.length; i++) {
        path.lineTo(o.polygon[i].x, o.polygon[i].y);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  void _drawBeam(Canvas canvas, BeamSimulationResult beam) {
    if (beam.segments.isEmpty || snapshot.powerOnProgress <= 0) return;

    final visibleCount =
        math.max(1, (beam.segments.length * snapshot.powerOnProgress).ceil());

    for (var i = 0; i < visibleCount && i < beam.segments.length; i++) {
      final seg = beam.segments[i];
      var t = 1.0;
      if (i == visibleCount - 1 && snapshot.powerOnProgress < 1) {
        t = (snapshot.powerOnProgress * beam.segments.length) - i;
        t = t.clamp(0.0, 1.0);
      }
      final end = Vec2(
        seg.start.x + (seg.end.x - seg.start.x) * t,
        seg.start.y + (seg.end.y - seg.start.y) * t,
      );

      final glow = Paint()
        ..color = AppColors.hotPink.withValues(alpha: 0.3)
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      final mid = Paint()
        ..color = AppColors.hotPink.withValues(alpha: 0.6)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final core = Paint()
        ..color = const Color(0xFFFFE0F0)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final a = Offset(seg.start.x, seg.start.y);
      final b = Offset(end.x, end.y);
      canvas.drawLine(a, b, glow);
      canvas.drawLine(a, b, mid);
      canvas.drawLine(a, b, core);
    }
  }

  void _drawLightSources(Canvas canvas, LevelModel level) {
    for (final ls in level.lightSources) {
      final center = Offset(ls.position.x, ls.position.y);
      canvas.drawCircle(
        center,
        30,
        Paint()
          ..color = AppColors.hotPink.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(center, 18, Paint()..color = AppColors.hotPink);
      canvas.drawCircle(center, 7, Paint()..color = Colors.white);

      final dir = ReflectionMath.directionFromDegrees(ls.directionDegrees);
      final tip = Offset(
        ls.position.x + dir.x * 42,
        ls.position.y + dir.y * 42,
      );
      canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = AppColors.hotPink
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawMirrors(
    Canvas canvas,
    LevelModel level,
    GameplayPaintSnapshot snapshot,
  ) {
    for (final m in level.mirrors) {
      final angle = snapshot.mirrorAngles[m.id] ?? m.initialAngle;
      final (a, b) = ReflectionMath.mirrorEndpoints(
        hinge: m.hingePosition,
        length: m.length,
        angleDegrees: angle,
      );
      final highlighted = snapshot.highlightedMirrorId == m.id;
      final active = snapshot.activeMirrorId == m.id;

      final glowColor =
          highlighted ? AppColors.gold : AppColors.accent;
      final glow = Paint()
        ..color = glowColor.withValues(alpha: active || highlighted ? 0.5 : 0.2)
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      final frame = Paint()
        ..color = highlighted ? AppColors.gold : AppColors.accent
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final glass = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final p1 = Offset(a.x, a.y);
      final p2 = Offset(b.x, b.y);
      canvas.drawLine(p1, p2, glow);
      canvas.drawLine(p1, p2, frame);
      canvas.drawLine(p1, p2, glass);

      // Hinge
      canvas.drawCircle(
        Offset(m.hingePosition.x, m.hingePosition.y),
        10,
        Paint()..color = AppColors.accentBright,
      );
      canvas.drawCircle(
        Offset(m.hingePosition.x, m.hingePosition.y),
        4,
        Paint()..color = AppColors.primaryDark,
      );

      // Ghost angle hint
      final ghost = snapshot.ghostAngles[m.id];
      if (ghost != null) {
        final (ga, gb) = ReflectionMath.mirrorEndpoints(
          hinge: m.hingePosition,
          length: m.length,
          angleDegrees: ghost,
        );
        canvas.drawLine(
          Offset(ga.x, ga.y),
          Offset(gb.x, gb.y),
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.45)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  void _drawCrystals(
    Canvas canvas,
    LevelModel level,
    GameplayPaintSnapshot snapshot,
  ) {
    for (final c in level.targetCrystals) {
      final lit = snapshot.beam.litCrystalIds.contains(c.id);
      final center = Offset(c.position.x, c.position.y);
      final charge = lit ? snapshot.chargeProgress : 0.0;

      canvas.drawCircle(
        center,
        c.hitRadius + 20,
        Paint()
          ..color = AppColors.cyan.withValues(alpha: lit ? 0.35 : 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );

      final path = Path();
      const sides = 6;
      for (var i = 0; i < sides; i++) {
        final ang = -math.pi / 2 + i * 2 * math.pi / sides;
        final r = c.hitRadius * (lit ? 1.05 : 0.95);
        final p = Offset(
          center.dx + math.cos(ang) * r,
          center.dy + math.sin(ang) * r,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            c.hitRadius,
            [
              lit ? const Color(0xFFB8FFFF) : const Color(0xFF1A2A4A),
              lit ? AppColors.cyan : const Color(0xFF0E1A35),
            ],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );

      if (charge > 0) {
        canvas.drawCircle(
          center,
          c.hitRadius * charge,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GameplayPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot;
  }
}

/// Maps screen touch to world coordinates matching [GameplayPainter] transform.
Vec2? screenToWorld({
  required Offset local,
  required Size canvasSize,
  required LevelModel level,
}) {
  final scale = math.min(
    canvasSize.width / level.roomBounds.x,
    canvasSize.height / level.roomBounds.y,
  );
  final dx = (canvasSize.width - level.roomBounds.x * scale) / 2;
  final dy = (canvasSize.height - level.roomBounds.y * scale) / 2;
  final wx = (local.dx - dx) / scale;
  final wy = (local.dy - dy) / scale;
  if (wx < -40 ||
      wy < -40 ||
      wx > level.roomBounds.x + 40 ||
      wy > level.roomBounds.y + 40) {
    return null;
  }
  return Vec2(wx, wy);
}

String? hitTestMirror({
  required Vec2 world,
  required LevelModel level,
  required Map<String, double> angles,
  double padding = 36,
}) {
  String? best;
  var bestDist = double.infinity;
  for (final m in level.mirrors) {
    if (m.isLocked) continue;
    final angle = angles[m.id] ?? m.initialAngle;
    final (a, b) = ReflectionMath.mirrorEndpoints(
      hinge: m.hingePosition,
      length: m.length,
      angleDegrees: angle,
    );
    final dist = _distToSegment(world, a, b);
    if (dist < padding && dist < bestDist) {
      bestDist = dist;
      best = m.id;
    }
  }
  return best;
}

double _distToSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final len2 = ab.lengthSquared;
  if (len2 < 1e-9) return p.distanceTo(a);
  var t = ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2;
  t = t.clamp(0.0, 1.0);
  final proj = a + ab * t;
  return p.distanceTo(proj);
}
