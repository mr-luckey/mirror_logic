import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/beam/beam_alignment.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

/// A light at the top-left firing right into m1, which can be turned to send
/// the beam down the board. A second mirror and a crystal sit below it.
LevelModel _level({
  required List<Map<String, dynamic>> mirrors,
  required List<Map<String, dynamic>> crystals,
}) {
  return LevelModel.fromJson({
    'levelId': 'align_001',
    'chapterId': 'ch1',
    'levelIndex': 1,
    'roomBounds': {'width': 1080.0, 'height': 1920.0},
    'lightSources': [
      {
        'id': 'ls1',
        'position': [100.0, 400.0],
        'direction': 0.0,
      },
    ],
    'mirrors': mirrors,
    'obstacles': <Map<String, dynamic>>[],
    'targetCrystals': crystals,
    'intendedSolution': {'mirrorAngles': <String, double>{}},
    'starThresholds': {'threeStarMoveCount': 3, 'threeStarTimeSeconds': 60},
  });
}

Map<String, dynamic> _mirror(
  String id,
  double x,
  double y, {
  double angle = 90,
  double min = 5,
  double max = 175,
  bool locked = false,
}) {
  return {
    'id': id,
    'hingePosition': [x, y],
    'length': 145.0,
    'initialAngle': angle,
    'minAngle': min,
    'maxAngle': max,
    'snapIncrement': 0.0,
    'isLocked': locked,
  };
}

void main() {
  final finder = BeamAlignmentFinder();

  group('BeamAlignmentFinder', () {
    test('finds the angle that sends the beam into a mirror centre', () {
      // m1 sits on the light's path; m2 is directly below it. Turning m1 to
      // 45° folds the horizontal beam straight down onto m2's midpoint.
      final level = _level(
        mirrors: [
          _mirror('m1', 500, 400),
          // Lying flat, so the beam folded downwards actually strikes it
          // rather than running along it.
          _mirror('m2', 500, 1200, angle: 0, locked: true),
        ],
        crystals: const [
          {
            'id': 'c1',
            'position': [1000.0, 1800.0],
            'hitRadius': 44.0,
            'groupId': 'g1',
          },
        ],
      );

      final detents = finder.detentsFor(
        level: level,
        mirrorAngles: {'m1': 90.0, 'm2': 0.0},
        mirrorId: 'm1',
      );

      final onM2 = detents.where((d) => d.targetId == 'm2').toList();
      expect(onM2, hasLength(1));
      expect(onM2.single.kind, AlignmentTargetKind.mirror);
      expect(onM2.single.angleDegrees, closeTo(45, 1.5));
    });

    test('finds the angle that centres the beam on a crystal', () {
      final level = _level(
        mirrors: [_mirror('m1', 500, 400)],
        crystals: const [
          {
            'id': 'c1',
            'position': [500.0, 1200.0],
            'hitRadius': 44.0,
            'groupId': 'g1',
          },
        ],
      );

      final detents = finder.detentsFor(
        level: level,
        mirrorAngles: {'m1': 90.0},
        mirrorId: 'm1',
      );

      final onCrystal = detents.where((d) => d.targetId == 'c1').toList();
      expect(onCrystal, hasLength(1));
      expect(onCrystal.single.kind, AlignmentTargetKind.crystal);
      expect(onCrystal.single.angleDegrees, closeTo(45, 1.5));
    });

    test('every detent lies inside the mirror rotation limits', () {
      final level = _level(
        mirrors: [
          _mirror('m1', 500, 400, min: 30, max: 60),
          _mirror('m2', 500, 1200),
        ],
        crystals: const [
          {
            'id': 'c1',
            'position': [500.0, 1600.0],
            'hitRadius': 44.0,
            'groupId': 'g1',
          },
        ],
      );

      final detents = finder.detentsFor(
        level: level,
        mirrorAngles: {'m1': 45.0, 'm2': 90.0},
        mirrorId: 'm1',
      );

      expect(detents, isNotEmpty);
      for (final d in detents) {
        expect(d.angleDegrees, inInclusiveRange(30, 60));
      }
    });

    test('the detent angle really does put the beam through the centre', () {
      final level = _level(
        mirrors: [_mirror('m1', 500, 400)],
        crystals: const [
          {
            'id': 'c1',
            'position': [900.0, 1700.0],
            'hitRadius': 44.0,
            'groupId': 'g1',
          },
        ],
      );

      final detent = finder
          .detentsFor(
            level: level,
            mirrorAngles: {'m1': 90.0},
            mirrorId: 'm1',
          )
          .singleWhere((d) => d.targetId == 'c1');

      final beam = BeamSimulator().simulate(
        level: level,
        mirrorAngles: {'m1': detent.angleDegrees},
      );
      final hit = beam.segments.lastWhere((s) => s.hitId == 'c1');

      // Perpendicular distance from the crystal's heart to the beam's line.
      final along = hit.end - hit.start;
      final dir = along * (1 / along.length);
      final crystal = level.targetCrystals.single;
      final toCentre = crystal.position - hit.start;
      final miss = (toCentre.x * dir.y - toCentre.y * dir.x).abs();
      // Within a tenth of the crystal's radius of dead centre. A refine that
      // stopped working would land tens of pixels out, not fractions.
      expect(miss, lessThan(crystal.hitRadius * 0.1));
    });

    test('a locked mirror offers nothing to settle into', () {
      final level = _level(
        mirrors: [
          _mirror('m1', 500, 400, locked: true),
          _mirror('m2', 500, 1200),
        ],
        crystals: const [
          {
            'id': 'c1',
            'position': [500.0, 1600.0],
            'hitRadius': 44.0,
            'groupId': 'g1',
          },
        ],
      );

      expect(
        finder.detentsFor(
          level: level,
          mirrorAngles: {'m1': 90.0, 'm2': 90.0},
          mirrorId: 'm1',
        ),
        isEmpty,
      );
    });

    test('a mirror the beam never reaches has no detents', () {
      final level = _level(
        mirrors: [
          _mirror('m1', 500, 400),
          // Far off the beam path, so rotating it changes nothing.
          _mirror('m2', 900, 100),
        ],
        crystals: const [
          {
            'id': 'c1',
            'position': [500.0, 1600.0],
            'hitRadius': 44.0,
            'groupId': 'g1',
          },
        ],
      );

      expect(
        finder.detentsFor(
          level: level,
          mirrorAngles: {'m1': 90.0, 'm2': 90.0},
          mirrorId: 'm2',
        ),
        isEmpty,
      );
    });
  });
}
