import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stone Castle ch1 pack', () {
    late List<LevelModel> levels;
    final validator = LevelValidator(simulator: BeamSimulator());
    const win = WinConditionEvaluator();
    final sim = BeamSimulator();

    setUpAll(() {
      final raw = File('assets/levels/levels.json').readAsStringSync();
      final root = jsonDecode(raw) as Map<String, dynamic>;
      levels = (root['levels'] as List)
          .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
          .where((l) => l.chapterId == 'ch1')
          .toList()
        ..sort((a, b) => a.levelIndex.compareTo(b.levelIndex));
    });

    test('catalog lists ch1 levels in order', () {
      expect(levels.length, greaterThanOrEqualTo(10));
      expect(levels.first.levelId, 'ch1_001');
    });

    test('each level has exactly one win crystal (relays optional)', () {
      for (final level in levels.take(10)) {
        final winCrystals =
            level.targetCrystals.where((c) => !c.relay).toList();
        expect(winCrystals.length, 1, reason: level.levelId);
        expect(level.crystalGroups.first.requiredCount, 1);
      }
    });

    test('each level is solvable at intendedSolution', () {
      for (final level in levels.take(10)) {
        expect(
          validator.isSolvable(level),
          isTrue,
          reason: '${level.levelId} (${level.title})',
        );
      }
    });

    test('each level is unsolved at initial angles', () {
      for (final level in levels.take(10)) {
        final angles = {
          for (final m in level.mirrors) m.id: m.initialAngle,
        };
        final result = sim.simulate(level: level, mirrorAngles: angles);
        expect(
          win.isSatisfied(
            level: level,
            litCrystalIds: result.litCrystalIds,
            segments: result.segments,
          ),
          isFalse,
          reason: level.levelId,
        );
      }
    });

    test('levels use wall obstacles not empty mazes only', () {
      for (final level in levels.skip(1).take(9)) {
        expect(
          level.obstacles.where((o) => !o.isDecorative).length,
          greaterThan(0),
          reason: level.levelId,
        );
      }
    });

    test('exact bounce levels hit mirror count', () {
      for (final level in levels.where((l) => l.requiredMirrorBounces != null)) {
        final required = level.requiredMirrorBounces!;
        final angles = {
          for (final m in level.mirrors) m.id: m.initialAngle,
          ...level.intendedSolution.mirrorAngles,
        };
        final result = sim.simulate(level: level, mirrorAngles: angles);
        final hits =
            result.segments.where((s) => s.hitKind == BeamHitKind.mirror).length;
        expect(hits, required, reason: level.levelId);
      }
    });

    test('objectives and hints present', () {
      for (final level in levels.take(10)) {
        expect(level.metadata.objective, isNotEmpty);
        expect(level.metadata.hints.length, greaterThanOrEqualTo(3));
      }
    });
  });
}
