import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

/// These assert what must hold for *any* shipped catalog. The pack is
/// regenerated often, so nothing here hard-codes a level count or title.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shipped level catalog', () {
    late List<LevelModel> levels;
    final validator = LevelValidator();
    final sim = BeamSimulator();
    const win = WinConditionEvaluator();

    setUpAll(() {
      final raw = File('assets/levels/levels.json').readAsStringSync();
      final root = jsonDecode(raw) as Map<String, dynamic>;
      levels = (root['levels'] as List)
          .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('catalog is non-empty and every level id is unique', () {
      expect(levels, isNotEmpty);
      final ids = levels.map((l) => l.levelId).toSet();
      expect(ids, hasLength(levels.length));
    });

    test('level indices run 1..n within each chapter', () {
      final byChapter = <String, List<LevelModel>>{};
      for (final level in levels) {
        byChapter.putIfAbsent(level.chapterId, () => []).add(level);
      }
      expect(byChapter, isNotEmpty);

      for (final entry in byChapter.entries) {
        final indices = entry.value.map((l) => l.levelIndex).toList()..sort();
        expect(
          indices,
          List.generate(indices.length, (i) => i + 1),
          reason: entry.key,
        );
      }
    });

    test('every level has a light source and a win crystal', () {
      for (final level in levels) {
        expect(level.lightSources, isNotEmpty, reason: level.levelId);
        expect(
          level.targetCrystals.where((c) => !c.relay),
          isNotEmpty,
          reason: level.levelId,
        );
        expect(level.crystalGroups, isNotEmpty, reason: level.levelId);
      }
    });

    test('every intended solution is solvable', () {
      final failures = <String>[];
      for (final level in levels) {
        if (!validator.isSolvable(level)) failures.add(level.levelId);
      }
      expect(failures, isEmpty, reason: 'Unsolvable: $failures');
    });

    test('no level starts already solved', () {
      final failures = <String>[];
      for (final level in levels) {
        final angles = {
          for (final m in level.mirrors) m.id: m.initialAngle,
        };
        final result = sim.simulate(level: level, mirrorAngles: angles);
        final solved = win.isSatisfied(
          level: level,
          litCrystalIds: result.litCrystalIds,
          segments: result.segments,
        );
        if (solved) failures.add(level.levelId);
      }
      expect(failures, isEmpty, reason: 'Pre-solved: $failures');
    });

    test('every mirror can reach its solution angle', () {
      for (final level in levels) {
        for (final entry in level.intendedSolution.mirrorAngles.entries) {
          final mirror =
              level.mirrors.where((m) => m.id == entry.key).firstOrNull;
          expect(mirror, isNotNull, reason: '${level.levelId}/${entry.key}');
          expect(
            entry.value,
            inInclusiveRange(mirror!.minAngle, mirror.maxAngle),
            reason: '${level.levelId}/${entry.key}',
          );
        }
      }
    });

    test('obstacle shapes parse, defaulting to wall', () {
      for (final level in levels) {
        for (final o in level.obstacles) {
          expect(o.polygon.length, greaterThanOrEqualTo(3), reason: o.id);
          expect(ObstacleShape.values, contains(o.shape), reason: o.id);
        }
      }
    });
  });
}
