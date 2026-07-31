import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/reflection_math.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/infrastructure/art/game_art.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_paint_snapshot.dart';

/// Medieval stone-board painter: tiles, bronze frame, laser, entities.
class GameplayPainter extends CustomPainter {
  GameplayPainter({required this.snapshot, required this.clock, this.art})
    : super(repaint: clock);

  final GameplayPaintSnapshot snapshot;

  /// Drives the idle shimmer. Passed as `repaint` so ticks reach the canvas
  /// without rebuilding a single widget.
  final Animation<double> clock;

  final GameArt? art;

  ui.Image? get crystalImage => art?.crystal;
  ui.Image? get emitterImage => art?.emitter;
  ui.Image? get wallHorizontalImage => art?.wallHorizontal;
  ui.Image? get wallVerticalImage => art?.wallVertical;

  double get animTime => clock.value * 8 * math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final level = snapshot.level;

    final scale = math.min(
      size.width / level.roomBounds.x,
      size.height / level.roomBounds.y,
    );
    final dx = (size.width - level.roomBounds.x * scale) / 2;
    final dy = (size.height - level.roomBounds.y * scale) / 2;

    // Outer ornate frame in screen space
    _drawOrnateFrame(canvas, size, dx, dy, scale, level);

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    _drawStoneTiles(canvas, level);
    _drawObstacles(canvas, level);
    // Floor stand first (below hinge) — never covers the reflection plane
    _drawMirrorPedestals(canvas, level, snapshot);
    _drawLightSources(canvas, level);
    // Beam travels at glass height, then glass paints over the impact
    _drawBeam(canvas, snapshot.beam);
    _drawMirrorGlass(canvas, level, snapshot);
    _drawCrystals(canvas, level, snapshot);
    canvas.restore();
  }

  void _drawOrnateFrame(
    Canvas canvas,
    Size size,
    double dx,
    double dy,
    double scale,
    LevelModel level,
  ) {
    final room = Rect.fromLTWH(
      dx,
      dy,
      level.roomBounds.x * scale,
      level.roomBounds.y * scale,
    );
    final outer = room.inflate(18);

    // Drop shadow under whole board (3D lift)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        outer.inflate(8).shift(const Offset(0, 10)),
        const Radius.circular(10),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Deep wood under-frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.inflate(6), const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MedievalColors.woodLight,
            MedievalColors.woodMid,
            MedievalColors.woodDeep,
          ],
        ).createShader(outer.inflate(6)),
    );

    // Outer bright bevel edge
    final stepped = _steppedRRect(outer, 14);
    canvas.drawPath(
      stepped,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MedievalColors.bronzeHighlight,
            MedievalColors.bronzeMid,
            MedievalColors.bronzeDark,
            const Color(0xFF3A2412),
          ],
          stops: const [0.0, 0.28, 0.65, 1.0],
        ).createShader(outer),
    );

    // Mid metal ridge
    final mid = _steppedRRect(outer.deflate(5), 11);
    canvas.drawPath(
      mid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MedievalColors.bronzeLight.withValues(alpha: 0.9),
            MedievalColors.bronzeDark,
          ],
        ).createShader(outer),
    );

    // Inner dark recess before tiles
    canvas.drawRRect(
      RRect.fromRectAndRadius(room.inflate(4), const Radius.circular(4)),
      Paint()..color = const Color(0xFF1A1008),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(room.inflate(2), const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MedievalColors.bronzeHighlight.withValues(alpha: 0.55),
            MedievalColors.bronzeDark,
          ],
        ).createShader(room)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Highlight rim stroke
    canvas.drawPath(
      stepped,
      Paint()
        ..color = MedievalColors.bronzeHighlight.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Rivets with 3D sphere look
    for (final p in [
      outer.topLeft + const Offset(12, 12),
      outer.topRight + const Offset(-12, 12),
      outer.bottomLeft + const Offset(12, -12),
      outer.bottomRight + const Offset(-12, -12),
      Offset(outer.center.dx, outer.top + 10),
      Offset(outer.center.dx, outer.bottom - 10),
      Offset(outer.left + 10, outer.center.dy),
      Offset(outer.right - 10, outer.center.dy),
    ]) {
      canvas.drawCircle(
        p.translate(1.2, 1.5),
        4.2,
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [
              MedievalColors.bronzeHighlight,
              MedievalColors.bronze,
              MedievalColors.bronzeDark,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: 4.5)),
      );
      canvas.drawCircle(
        p.translate(-1.2, -1.4),
        1.3,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }
  }

  Path _steppedRRect(Rect r, double step) {
    final path = Path();
    path.moveTo(r.left + step, r.top);
    path.lineTo(r.right - step, r.top);
    path.lineTo(r.right - step, r.top + step * 0.45);
    path.lineTo(r.right, r.top + step * 0.45);
    path.lineTo(r.right, r.bottom - step);
    path.lineTo(r.right - step * 0.45, r.bottom - step);
    path.lineTo(r.right - step * 0.45, r.bottom);
    path.lineTo(r.left + step, r.bottom);
    path.lineTo(r.left + step, r.bottom - step * 0.45);
    path.lineTo(r.left, r.bottom - step * 0.45);
    path.lineTo(r.left, r.top + step);
    path.lineTo(r.left + step * 0.45, r.top + step);
    path.lineTo(r.left + step * 0.45, r.top);
    path.close();
    return path;
  }

  void _drawStoneTiles(Canvas canvas, LevelModel level) {
    final w = level.roomBounds.x;
    final h = level.roomBounds.y;
    const cols = 10;
    const rows = 10;
    final tileW = w / cols;
    final tileH = h / rows;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final rect = Rect.fromLTWH(col * tileW, row * tileH, tileW, tileH);
        final base = ((row + col) % 2 == 0)
            ? MedievalColors.stone
            : MedievalColors.stoneLight;

        // Beveled stone face
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(base, Colors.white, 0.12)!,
                base,
                Color.lerp(base, Colors.black, 0.22)!,
              ],
            ).createShader(rect),
        );

        // Top/left highlight edge
        canvas.drawLine(
          rect.topLeft + const Offset(3, 3),
          rect.topRight + const Offset(-3, 3),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08)
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          rect.topLeft + const Offset(3, 3),
          rect.bottomLeft + const Offset(3, -3),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.06)
            ..strokeWidth = 2,
        );

        // Bottom/right shadow edge
        canvas.drawLine(
          rect.bottomLeft + const Offset(3, -3),
          rect.bottomRight + const Offset(-3, -3),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..strokeWidth = 2.5,
        );

        canvas.drawRect(
          rect,
          Paint()
            ..color = MedievalColors.stoneGrout
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.restore();
  }

  void _drawObstacles(Canvas canvas, LevelModel level) {
    for (final o in level.obstacles) {
      if (o.polygon.length < 3) continue;
      final bounds = _polygonBounds(o.polygon);

      if (o.shape == ObstacleShape.pillar && wallVerticalImage != null) {
        _drawPillar(canvas, bounds, wallVerticalImage!);
        continue;
      }

      // Walls (and any level authored before `shape` existed) pick their strip
      // sprite from the bounding box.
      final isHorizontal = bounds.width >= bounds.height * 1.12;
      final isVertical = bounds.height >= bounds.width * 1.12;

      if (isHorizontal && wallHorizontalImage != null) {
        _drawTiledWallStrip(
          canvas,
          bounds,
          wallHorizontalImage!,
          horizontal: true,
        );
        continue;
      }
      if (isVertical && wallVerticalImage != null) {
        _drawTiledWallStrip(
          canvas,
          bounds,
          wallVerticalImage!,
          horizontal: false,
        );
        continue;
      }

      _drawStoneWallFallback(canvas, o.polygon, bounds);
    }
  }

  /// A post is one sprite fitted to a square, never tiled into a strip.
  void _drawPillar(Canvas canvas, Rect bounds, ui.Image image) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (iw < 1 || ih < 1 || bounds.width < 1 || bounds.height < 1) return;

    final long = math.max(bounds.width, bounds.height);
    final short = math.min(bounds.width, bounds.height);
    assert(
      long <= short * 1.5,
      'Pillar bounds should be square-ish, got $bounds',
    );

    // Cap the drawn square so a mis-tagged strip degrades to a post instead of
    // covering the whole run.
    final side = math.min(long, short * 1.25);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromCenter(center: bounds.center, width: side, height: side),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  void _drawTiledWallStrip(
    Canvas canvas,
    Rect bounds,
    ui.Image image, {
    required bool horizontal,
  }) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (iw < 1 || ih < 1) return;

    if (horizontal) {
      final tileWidth = bounds.height * (iw / ih);
      if (tileWidth < 1) return;
      var x = bounds.left;
      while (x < bounds.right - 0.5) {
        final w = math.min(tileWidth, bounds.right - x);
        final srcW = iw * (w / tileWidth);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, srcW, ih),
          Rect.fromLTWH(x, bounds.top, w, bounds.height),
          paint,
        );
        x += w;
      }
      canvas.drawRect(
        Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 2),
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      );
      return;
    }

    final tileHeight = bounds.width * (ih / iw);
    if (tileHeight < 1) return;
    var y = bounds.top;
    while (y < bounds.bottom - 0.5) {
      final h = math.min(tileHeight, bounds.bottom - y);
      final srcH = ih * (h / tileHeight);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, iw, srcH),
        Rect.fromLTWH(bounds.left, y, bounds.width, h),
        paint,
      );
      y += h;
    }
    canvas.drawRect(
      Rect.fromLTWH(bounds.left, bounds.top, 2, bounds.height),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
  }

  void _drawStoneWallFallback(Canvas canvas, List<Vec2> polygon, Rect bounds) {
    final path = Path()..moveTo(polygon.first.x, polygon.first.y);
    for (var i = 1; i < polygon.length; i++) {
      path.lineTo(polygon[i].x, polygon[i].y);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MedievalColors.stoneLight, MedievalColors.stoneDark],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            MedievalColors.bronzeHighlight.withValues(alpha: 0.55),
            MedievalColors.bronzeDark,
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
  }

  Rect _polygonBounds(List<Vec2> poly) {
    var minX = poly.first.x, maxX = poly.first.x;
    var minY = poly.first.y, maxY = poly.first.y;
    for (final p in poly) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _drawBeam(Canvas canvas, BeamSimulationResult beam) {
    if (beam.segments.isEmpty || snapshot.powerOnProgress <= 0) return;

    final pulse = 0.85 + 0.15 * math.sin(animTime * 6);
    final visibleCount = math.max(
      1,
      (beam.segments.length * snapshot.powerOnProgress).ceil(),
    );

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

      final a = Offset(seg.start.x, seg.start.y);
      final b = Offset(end.x, end.y);

      // The stretch that lands on a rejected crystal goes red, so the player
      // can see at a glance that this hit is not the answer.
      final rejected =
          seg.hitKind == BeamHitKind.crystal &&
          snapshot.rejectedCrystalIds.contains(seg.hitId);
      final glowColor = rejected
          ? MedievalColors.rejectGlow
          : MedievalColors.laserGlow;
      final midColor = rejected
          ? MedievalColors.rejectMid
          : MedievalColors.laserMid;
      final coreColor = rejected
          ? MedievalColors.rejectCore
          : MedievalColors.laserCore;

      final glow = Paint()
        ..color = glowColor.withValues(alpha: 0.35 * pulse)
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      final mid = Paint()
        ..color = midColor.withValues(alpha: 0.75)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final core = Paint()
        ..color = coreColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(a, b, glow);
      canvas.drawLine(a, b, mid);
      canvas.drawLine(a, b, core);

      // Impact spark at segment end
      if (t >= 0.99) {
        canvas.drawCircle(
          b,
          10 + 3 * pulse,
          Paint()
            ..color = coreColor.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  void _drawLightSources(Canvas canvas, LevelModel level) {
    for (final ls in level.lightSources) {
      final tip = ls.mountedOrigin(level.roomBounds);
      final center = Offset(tip.x, tip.y);
      final dir = ReflectionMath.directionFromDegrees(ls.directionDegrees);
      final angle = math.atan2(dir.y, dir.x);

      // Wall mounting plate behind the nozzle
      _drawEmitterWallMount(canvas, level, tip, dir);

      // Soft cyan bloom at nozzle tip (beam start)
      canvas.drawCircle(
        center,
        36,
        Paint()
          ..color = MedievalColors.laserMid.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      if (emitterImage != null) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        // Sprite faces +X; tip of nozzle at local origin = beam start
        canvas.rotate(angle);
        const spriteW = 120.0;
        const spriteH = 72.0;
        const tipPad = 6.0; // nozzle lip just past beam origin
        final rect = Rect.fromLTWH(
          -spriteW + tipPad,
          -spriteH / 2,
          spriteW,
          spriteH,
        );
        paintImage(
          canvas: canvas,
          rect: rect,
          image: emitterImage!,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
        // Bright tip marker where beam leaves the source
        canvas.drawCircle(
          Offset.zero,
          7,
          Paint()
            ..color = MedievalColors.laserCore.withValues(alpha: 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          Offset.zero,
          3,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.restore();
      } else {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(-64, -18, 64, 36),
          const Radius.circular(8),
        );
        canvas.drawRRect(
          body,
          Paint()
            ..shader = const LinearGradient(
              colors: [
                MedievalColors.bronzeDark,
                MedievalColors.bronzeHighlight,
              ],
            ).createShader(body.outerRect),
        );
        canvas.drawCircle(
          Offset.zero,
          11,
          Paint()..color = MedievalColors.laserMid,
        );
        canvas.restore();
      }
    }
  }

  void _drawEmitterWallMount(
    Canvas canvas,
    LevelModel level,
    Vec2 tip,
    Vec2 dir,
  ) {
    final w = level.roomBounds.x;
    final h = level.roomBounds.y;
    final useX = dir.x.abs() >= dir.y.abs();

    late Rect plate;
    if (useX) {
      if (dir.x >= 0) {
        // Mounted on left wall
        plate = Rect.fromCenter(
          center: Offset(6, tip.y),
          width: 28,
          height: 88,
        );
      } else {
        plate = Rect.fromCenter(
          center: Offset(w - 6, tip.y),
          width: 28,
          height: 88,
        );
      }
    } else {
      if (dir.y >= 0) {
        plate = Rect.fromCenter(
          center: Offset(tip.x, 6),
          width: 88,
          height: 28,
        );
      } else {
        plate = Rect.fromCenter(
          center: Offset(tip.x, h - 6),
          width: 88,
          height: 28,
        );
      }
    }

    final rrect = RRect.fromRectAndRadius(plate, const Radius.circular(5));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MedievalColors.bronzeHighlight,
            MedievalColors.bronzeMid,
            MedievalColors.bronzeDark,
          ],
        ).createShader(plate),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = MedievalColors.bronzeHighlight.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Rivets on plate
    final rivets = useX
        ? [
            Offset(plate.center.dx, plate.top + 14),
            Offset(plate.center.dx, plate.bottom - 14),
          ]
        : [
            Offset(plate.left + 14, plate.center.dy),
            Offset(plate.right - 14, plate.center.dy),
          ];
    for (final p in rivets) {
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [MedievalColors.bronzeHighlight, MedievalColors.bronzeDark],
          ).createShader(Rect.fromCircle(center: p, radius: 3.5)),
      );
    }
  }

  void _drawMirrorPedestals(
    Canvas canvas,
    LevelModel level,
    GameplayPaintSnapshot snapshot,
  ) {
    for (final m in level.mirrors) {
      final hinge = Offset(m.hingePosition.x, m.hingePosition.y);
      _drawFixedMirrorPedestal(canvas, hinge, m.length);
    }
  }

  void _drawMirrorGlass(
    Canvas canvas,
    LevelModel level,
    GameplayPaintSnapshot snapshot,
  ) {
    final glint = (animTime * 0.85) % 1.0;

    for (final m in level.mirrors) {
      final angle = snapshot.mirrorAngles[m.id] ?? m.initialAngle;
      final highlighted = snapshot.highlightedMirrorId == m.id;
      final active = snapshot.activeMirrorId == m.id;
      final hinge = Offset(m.hingePosition.x, m.hingePosition.y);
      final rad = angle * math.pi / 180.0;

      if (highlighted || active) {
        canvas.drawCircle(
          hinge,
          m.length * 0.38,
          Paint()
            ..color = MedievalColors.bronzeHighlight.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }

      if (snapshot.alignedTargetId == m.id) {
        _drawAlignmentLock(canvas, hinge, m.length * 0.34);
      }

      if (active && snapshot.showAngleReadout) {
        _drawAngleReadout(canvas, hinge, m.length, angle);
      }

      // Reflective plate at hinge — ABOVE stand; beam strikes this face
      canvas.save();
      canvas.translate(hinge.dx, hinge.dy);
      canvas.rotate(rad);

      final half = m.length * 0.5;
      const thickness = 18.0;
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: m.length,
          height: thickness,
        ),
        const Radius.circular(3),
      );

      // Soft shadow toward floor stand (plate sits on top of post)
      canvas.drawRRect(
        plate.shift(const Offset(0, 6)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      canvas.drawRRect(
        plate.inflate(5),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MedievalColors.bronzeHighlight,
              MedievalColors.bronze,
              MedievalColors.bronzeDark,
            ],
          ).createShader(plate.outerRect.inflate(5)),
      );
      canvas.drawRRect(
        plate.inflate(2),
        Paint()..color = const Color(0xFF2A180C),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFFE8FFFF),
              Color(0xFF7AD8FF),
              Color(0xFF2A6A90),
              Color(0xFFA8ECFF),
            ],
            stops: const [0.0, 0.35, 0.7, 1.0],
          ).createShader(plate.outerRect),
      );

      final streakX = -half + glint * m.length;
      canvas.drawLine(
        Offset(streakX - 10, -thickness * 0.25),
        Offset(streakX + 10, thickness * 0.25),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.drawLine(
        Offset(-half + 4, -thickness * 0.5),
        Offset(half - 4, -thickness * 0.5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 1.5,
      );
      canvas.restore();

      // Hinge pin on top of glass
      canvas.drawCircle(
        hinge.translate(1, 1.5),
        8,
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );
      canvas.drawCircle(
        hinge,
        8,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.45),
            colors: [
              MedievalColors.bronzeHighlight,
              MedievalColors.bronze,
              MedievalColors.bronzeDark,
            ],
          ).createShader(Rect.fromCircle(center: hinge, radius: 8)),
      );
      canvas.drawCircle(
        hinge.translate(-2, -2),
        2,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );

      // Beam impact spark on glass when lit by a segment end near hinge
      _drawBeamImpactOnMirror(canvas, snapshot, hinge, m.length);

      _drawGhostMirror(canvas, snapshot, m, angle);
    }
  }

  /// The hint's gold outline of where this mirror has to end up.
  ///
  /// It fades out as the real mirror closes on it, so a board being solved
  /// clears itself of ghosts one mirror at a time and the player can see at a
  /// glance which posts they still owe.
  void _drawGhostMirror(
    Canvas canvas,
    GameplayPaintSnapshot snapshot,
    MirrorDef mirror,
    double currentAngle,
  ) {
    final target = snapshot.ghostAngles[mirror.id];
    if (target == null) return;

    const vanishDegrees = 3.0;
    const fullDegrees = 14.0;
    var offBy = (currentAngle - target).abs() % 180.0;
    if (offBy > 90) offBy = 180 - offBy;
    if (offBy <= vanishDegrees) return;

    final strength = ((offBy - vanishDegrees) / (fullDegrees - vanishDegrees))
        .clamp(0.0, 1.0);

    final (a, b) = ReflectionMath.mirrorEndpoints(
      hinge: mirror.hingePosition,
      length: mirror.length,
      angleDegrees: target,
    );
    final start = Offset(a.x, a.y);
    final end = Offset(b.x, b.y);

    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = MedievalColors.bronzeHighlight.withValues(
          alpha: 0.2 * strength,
        )
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = MedievalColors.textGold.withValues(alpha: 0.62 * strength)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBeamImpactOnMirror(
    Canvas canvas,
    GameplayPaintSnapshot snapshot,
    Offset hinge,
    double length,
  ) {
    final pulse = 0.85 + 0.15 * math.sin(animTime * 8);
    for (final seg in snapshot.beam.segments) {
      if (seg.hitKind != BeamHitKind.mirror) continue;
      final hit = Offset(seg.end.x, seg.end.y);
      if ((hit - hinge).distance > length * 0.55) continue;
      // Bright strike on the glass face (not on the floor base)
      canvas.drawCircle(
        hit,
        18 * pulse,
        Paint()
          ..color = MedievalColors.laserGlow.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(
        hit,
        9,
        Paint()
          ..color = MedievalColors.laserCore.withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(hit, 3.6, Paint()..color = Colors.white);
      // Radial spark lines — the "beam just struck" flash.
      for (var i = 0; i < 6; i++) {
        final a = animTime * 3 + i * math.pi / 3;
        final tip = hit + Offset(math.cos(a), math.sin(a)) * (16 + 4 * pulse);
        canvas.drawLine(
          hit,
          tip,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55 * pulse)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  /// Floor pedestal BELOW the hinge — beam hits glass above, not the base.
  void _drawFixedMirrorPedestal(Canvas canvas, Offset hinge, double length) {
    final rOuter = length * 0.2;
    final rMid = length * 0.14;
    final rInner = length * 0.08;
    // Push base well below hinge so disk never overlaps the glass plane
    final base = hinge.translate(0, rOuter * 1.35);

    // Contact shadow on floor
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, rOuter * 0.35),
        width: rOuter * 2.6,
        height: rOuter * 0.55,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Flattened bronze base (perspective oval — reads as floor stand)
    final baseOval = Rect.fromCenter(
      center: base,
      width: rOuter * 2.15,
      height: rOuter * 1.15,
    );
    canvas.drawOval(
      baseOval,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.45),
          colors: [
            MedievalColors.bronzeHighlight,
            MedievalColors.bronzeMid,
            MedievalColors.bronzeDark,
          ],
        ).createShader(baseOval),
    );
    canvas.drawOval(
      baseOval,
      Paint()
        ..color = MedievalColors.bronzeHighlight.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final midOval = Rect.fromCenter(
      center: base.translate(0, -1),
      width: rMid * 2.1,
      height: rMid * 1.1,
    );
    canvas.drawOval(
      midOval,
      Paint()..color = const Color(0xFF2A180C).withValues(alpha: 0.7),
    );
    canvas.drawOval(
      midOval,
      Paint()
        ..color = MedievalColors.bronzeLight.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Rivets around base rim
    for (var i = 0; i < 6; i++) {
      final ang = i * math.pi / 3;
      final rp = Offset(
        base.dx + math.cos(ang) * (rOuter * 0.82),
        base.dy + math.sin(ang) * (rOuter * 0.42),
      );
      canvas.drawCircle(
        rp,
        2.6,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [MedievalColors.bronzeHighlight, MedievalColors.bronzeDark],
          ).createShader(Rect.fromCircle(center: rp, radius: 2.6)),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -2),
        width: rInner * 2,
        height: rInner * 1.1,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            MedievalColors.woodLight.withValues(alpha: 0.45),
            MedievalColors.woodDeep,
          ],
        ).createShader(Rect.fromCircle(center: base, radius: rInner)),
    );

    // Tall thin post: glass mounts clearly ABOVE the floor base
    final postTop = hinge.dy + 6;
    final postBottom = base.dy - rOuter * 0.15;
    final postH = (postBottom - postTop).abs();
    if (postH > 4) {
      final post = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(hinge.dx, (postTop + postBottom) * 0.5),
          width: rInner * 1.35,
          height: postH,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        post,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              MedievalColors.bronzeDark,
              MedievalColors.bronzeHighlight,
              MedievalColors.bronzeDark,
            ],
          ).createShader(post.outerRect),
      );
      // Cap under hinge
      canvas.drawCircle(
        Offset(hinge.dx, postTop),
        rInner * 0.95,
        Paint()
          ..shader =
              RadialGradient(
                colors: [MedievalColors.bronzeLight, MedievalColors.bronzeDark],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(hinge.dx, postTop),
                  radius: rInner,
                ),
              ),
      );
    }
  }

  /// Ring that confirms the beam has settled dead-centre on this target — the
  /// visual half of the haptic tick the drag fires at the same moment.
  void _drawAlignmentLock(Canvas canvas, Offset center, double radius) {
    final beat = 0.5 + 0.5 * math.sin(animTime * 7);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = MedievalColors.laserCore.withValues(alpha: 0.5 + 0.4 * beat),
    );
    canvas.drawCircle(
      center,
      radius * (1 + 0.12 * beat),
      Paint()
        ..color = MedievalColors.laserCore.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  /// Live angle for the mirror being turned, parked above the hinge where the
  /// hand is least likely to be covering it.
  void _drawAngleReadout(
    Canvas canvas,
    Offset hinge,
    double length,
    double angle,
  ) {
    final text = TextPainter(
      text: TextSpan(
        text: '${angle.round()}°',
        style: const TextStyle(
          color: MedievalColors.textGold,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final center = hinge.translate(0, -length * 0.62 - 22);
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: text.width + 26,
        height: text.height + 12,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      box,
      Paint()..color = MedievalColors.woodDeep.withValues(alpha: 0.82),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = MedievalColors.bronzeLight.withValues(alpha: 0.7),
    );
    text.paint(canvas, center.translate(-text.width / 2, -text.height / 2));
  }

  /// Struck-through ring over a crystal the beam reached the wrong way.
  void _drawRejectedMark(Canvas canvas, Offset center, double radius) {
    final beat = 0.6 + 0.4 * math.sin(animTime * 5);
    final r = radius * 1.15;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = MedievalColors.rejectMid.withValues(alpha: 0.55 + 0.35 * beat);

    canvas.drawCircle(center, r, stroke);
    final d = r * 0.62;
    canvas.drawLine(center.translate(-d, -d), center.translate(d, d), stroke);
  }

  void _drawCrystals(
    Canvas canvas,
    LevelModel level,
    GameplayPaintSnapshot snapshot,
  ) {
    final pulse = 0.5 + 0.5 * math.sin(animTime * 2.4);

    for (final c in level.targetCrystals) {
      final rejected = snapshot.rejectedCrystalIds.contains(c.id);
      final lit = snapshot.beam.litCrystalIds.contains(c.id) && !rejected;
      final center = Offset(c.position.x, c.position.y);
      if (snapshot.alignedTargetId == c.id) {
        _drawAlignmentLock(canvas, center, c.hitRadius * 1.35);
      }
      final charge = lit ? snapshot.chargeProgress : 0.0;
      final aura =
          c.hitRadius * (1.6 + 0.3 * pulse) * (lit || rejected ? 1.2 : 0.9);

      // Magical bloom
      canvas.drawCircle(
        center,
        aura,
        Paint()
          ..color =
              (rejected ? MedievalColors.rejectMid : MedievalColors.laserMid)
                  .withValues(alpha: lit || rejected ? 0.4 * pulse : 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );

      // Contact shadow under pedestal
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, c.hitRadius * 1.05),
          width: c.hitRadius * 2.2,
          height: c.hitRadius * 0.55,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      if (crystalImage != null) {
        final h = c.hitRadius * 3.6;
        final w = c.hitRadius * 2.4;
        // Sit pedestal slightly below hit center so crystal tip is target.
        paintImage(
          canvas: canvas,
          rect: Rect.fromCenter(
            center: center.translate(0, c.hitRadius * 0.15),
            width: w,
            height: h,
          ),
          image: crystalImage!,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          colorFilter: rejected
              ? const ColorFilter.mode(
                  MedievalColors.rejectMid,
                  BlendMode.modulate,
                )
              : null,
        );
      } else {
        _drawFallbackCrystal(canvas, center, c.hitRadius, lit);
      }

      if (rejected) {
        _drawRejectedMark(canvas, center, c.hitRadius);
      }

      if (charge > 0) {
        canvas.drawCircle(
          center,
          c.hitRadius * (0.6 + charge * 0.8),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35 * charge)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
      }

      if (lit) {
        for (var i = 0; i < 4; i++) {
          final ang = animTime * 1.5 + i * math.pi / 2;
          final spark = Offset(
            center.dx + math.cos(ang) * c.hitRadius * 1.3,
            center.dy + math.sin(ang) * c.hitRadius * 0.9,
          );
          canvas.drawCircle(
            spark,
            3 + pulse * 2,
            Paint()..color = Colors.white.withValues(alpha: 0.7),
          );
        }
      }

      final label = c.label.isNotEmpty
          ? c.label
          : level.metadata.deviceLabels[c.id];
      if (label != null && label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: rejected
                  ? MedievalColors.rejectMid
                  : lit
                  ? MedievalColors.laserCore
                  : MedievalColors.textCream.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center.translate(-tp.width / 2, c.hitRadius * 1.1));
      }
    }
  }

  void _drawFallbackCrystal(
    Canvas canvas,
    Offset center,
    double radius,
    bool lit,
  ) {
    // Pedestal
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.85),
        width: radius * 1.8,
        height: radius * 0.55,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [MedievalColors.bronzeHighlight, MedievalColors.bronzeDark],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final path = Path();
    final tip = center.translate(0, -radius * 1.35);
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(center.dx + radius * 0.7, center.dy + radius * 0.3);
    path.lineTo(center.dx, center.dy + radius * 0.85);
    path.lineTo(center.dx - radius * 0.7, center.dy + radius * 0.3);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: lit
              ? [
                  MedievalColors.laserCore,
                  MedievalColors.laserMid,
                  MedievalColors.crystalDeep,
                ]
              : [
                  const Color(0xFF4A6A80),
                  MedievalColors.crystalDeep,
                  const Color(0xFF102030),
                ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.4)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = MedievalColors.laserCore.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  /// The clock repaints us on its own; this only covers board changes.
  @override
  bool shouldRepaint(covariant GameplayPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot || oldDelegate.art != art;
  }
}

/// Maps screen touch to world coordinates matching [GameplayPainter] transform.
///
/// Set [bounded] to false to keep tracking a finger that has wandered off the
/// board. Aiming a mirror is most precise when the finger is far from the
/// hinge, which routinely means outside the room, and dropping those updates
/// freezes the mirror mid-turn.
Vec2? screenToWorld({
  required Offset local,
  required Size canvasSize,
  required LevelModel level,
  bool bounded = true,
}) {
  final scale = math.min(
    canvasSize.width / level.roomBounds.x,
    canvasSize.height / level.roomBounds.y,
  );
  final dx = (canvasSize.width - level.roomBounds.x * scale) / 2;
  final dy = (canvasSize.height - level.roomBounds.y * scale) / 2;
  final wx = (local.dx - dx) / scale;
  final wy = (local.dy - dy) / scale;
  if (bounded &&
      (wx < -40 ||
          wy < -40 ||
          wx > level.roomBounds.x + 40 ||
          wy > level.roomBounds.y + 40)) {
    return null;
  }
  return Vec2(wx, wy);
}

/// Inverse of [screenToWorld]: place a world-space burst on the canvas.
Offset worldToScreen({
  required Vec2 world,
  required Size canvasSize,
  required LevelModel level,
}) {
  final scale = math.min(
    canvasSize.width / level.roomBounds.x,
    canvasSize.height / level.roomBounds.y,
  );
  final dx = (canvasSize.width - level.roomBounds.x * scale) / 2;
  final dy = (canvasSize.height - level.roomBounds.y * scale) / 2;
  return Offset(world.x * scale + dx, world.y * scale + dy);
}

String? hitTestMirror({
  required Vec2 world,
  required LevelModel level,
  required Map<String, double> angles,
  double padding = 42,
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
    // Also allow hitting near hinge base
    final hingeDist = world.distanceTo(m.hingePosition);
    final d = math.min(dist, hingeDist - 20);
    if (d < padding && d < bestDist) {
      bestDist = d;
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
