import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/reflection_math.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

void main() {
  group('ReflectionMath', () {
    test('reflects 45° incidence about vertical mirror correctly', () {
      // Vertical mirror (angle 90°): surface along +Y, normal along +X or -X
      // Incoming rightward (+X), mirror at 90° (surface vertical)...
      // Mirror angle 90 means surface along direction(90)=+Y, normal = direction(180)=-X
      final d = const Vec2(1, -1).normalized();
      final n = const Vec2(0, 1); // horizontal surface normal up
      final r = ReflectionMath.reflect(d, n);
      expect(r.x, closeTo(d.x, 1e-9));
      expect(r.y, closeTo(-d.y, 1e-9));
    });

    test('clampAngle respects bounds', () {
      expect(ReflectionMath.clampAngle(0, 5, 175), 5);
      expect(ReflectionMath.clampAngle(200, 5, 175), 175);
      expect(ReflectionMath.clampAngle(90, 5, 175), 90);
    });

    test('mirror endpoints are centered on hinge', () {
      final (a, b) = ReflectionMath.mirrorEndpoints(
        hinge: const Vec2(100, 100),
        length: 100,
        angleDegrees: 0,
      );
      expect(a.x, closeTo(50, 1e-6));
      expect(b.x, closeTo(150, 1e-6));
      expect(a.y, closeTo(100, 1e-6));
      expect(b.y, closeTo(100, 1e-6));
    });
  });

  group('BeamSimulator', () {
    test('direct hit lights crystal with no mirrors', () {
      final level = LevelModel(
        levelId: 't1',
        chapterId: 'ch1',
        roomBounds: const Vec2(1080, 1920),
        lightSources: const [
          LightSource(id: 'ls1', position: Vec2(100, 200), directionDegrees: 0),
        ],
        mirrors: const [],
        obstacles: const [],
        targetCrystals: const [
          TargetCrystalDef(id: 'c1', position: Vec2(500, 200), hitRadius: 40),
        ],
        crystalGroups: const [CrystalGroupDef(groupId: 'g1', requiredCount: 1)],
        intendedSolution: const IntendedSolution(mirrorAngles: {}),
        starThresholds: const StarThresholds(),
      );

      final result = BeamSimulator().simulate(level: level, mirrorAngles: {});
      expect(result.litCrystalIds, contains('c1'));
      expect(result.segments, isNotEmpty);
    });

    test('wall absorbs beam', () {
      final level = LevelModel(
        levelId: 't2',
        chapterId: 'ch1',
        roomBounds: const Vec2(1080, 1920),
        lightSources: const [
          LightSource(id: 'ls1', position: Vec2(50, 200), directionDegrees: 0),
        ],
        mirrors: const [],
        obstacles: const [
          ObstacleDef(
            id: 'o1',
            polygon: [
              Vec2(200, 100),
              Vec2(260, 100),
              Vec2(260, 300),
              Vec2(200, 300),
            ],
          ),
        ],
        targetCrystals: const [
          TargetCrystalDef(id: 'c1', position: Vec2(800, 200)),
        ],
        crystalGroups: const [CrystalGroupDef(groupId: 'g1', requiredCount: 1)],
        intendedSolution: const IntendedSolution(mirrorAngles: {}),
        starThresholds: const StarThresholds(),
      );

      final result = BeamSimulator().simulate(level: level, mirrorAngles: {});
      expect(result.litCrystalIds, isEmpty);
      expect(result.segments.last.hitKind.name, 'wall');
    });

    test('single mirror reflection reaches crystal', () {
      // Light from left toward hinge, mirror at 45°, crystal along reflected path.
      const hinge = Vec2(400, 400);
      const mirrorAngle = 45.0;
      final incoming = ReflectionMath.directionFromDegrees(0);
      final normal = ReflectionMath.mirrorNormal(mirrorAngle);
      final facing = normal.dot(incoming) > 0 ? -normal : normal;
      final reflected = ReflectionMath.reflect(incoming, facing);
      final crystalPos = hinge + reflected * 350;

      final level = LevelModel(
        levelId: 't3',
        chapterId: 'ch1',
        roomBounds: const Vec2(1080, 1920),
        lightSources: [
          LightSource(
            id: 'ls1',
            position: hinge - incoming * 250,
            directionDegrees: 0,
          ),
        ],
        mirrors: const [
          MirrorDef(
            id: 'm1',
            hingePosition: hinge,
            length: 160,
            initialAngle: 20,
            minAngle: 5,
            maxAngle: 175,
          ),
        ],
        obstacles: const [],
        targetCrystals: [
          TargetCrystalDef(id: 'c1', position: crystalPos, hitRadius: 50),
        ],
        crystalGroups: const [CrystalGroupDef(groupId: 'g1', requiredCount: 1)],
        intendedSolution: const IntendedSolution(
          mirrorAngles: {'m1': mirrorAngle},
        ),
        starThresholds: const StarThresholds(),
      );

      final sim = BeamSimulator();
      final wrong = sim.simulate(level: level, mirrorAngles: {'m1': 20});
      final right = sim.simulate(
        level: level,
        mirrorAngles: {'m1': mirrorAngle},
      );

      expect(LevelValidator(simulator: sim).isSolvable(level), isTrue);
      // Wrong angle likely misses; correct hits.
      expect(right.litCrystalIds, contains('c1'));
      expect(wrong.litCrystalIds.contains('c1'), isFalse);
    });
  });

  group('WinConditionEvaluator', () {
    test('requires group count', () {
      const evaluator = WinConditionEvaluator();
      final level = LevelModel(
        levelId: 't4',
        chapterId: 'ch1',
        roomBounds: const Vec2(100, 100),
        lightSources: const [],
        mirrors: const [],
        obstacles: const [],
        targetCrystals: const [
          TargetCrystalDef(id: 'c1', position: Vec2(1, 1)),
          TargetCrystalDef(id: 'c2', position: Vec2(2, 2)),
        ],
        crystalGroups: const [CrystalGroupDef(groupId: 'g1', requiredCount: 2)],
        intendedSolution: const IntendedSolution(mirrorAngles: {}),
        starThresholds: const StarThresholds(),
      );
      BeamSimulationResult beamLighting(Set<String> ids) =>
          BeamSimulationResult(segments: const [], litCrystalIds: ids);

      expect(
        evaluator.evaluate(level: level, beam: beamLighting({'c1'})).satisfied,
        isFalse,
      );
      expect(
        evaluator
            .evaluate(level: level, beam: beamLighting({'c1', 'c2'}))
            .satisfied,
        isTrue,
      );
    });
  });
}
