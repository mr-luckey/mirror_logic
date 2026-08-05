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
      final manifestRaw = File(
        'assets/levels/manifest.json',
      ).readAsStringSync();
      final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
      final entries = (manifest['levels'] as List).cast<Map<String, dynamic>>();
      levels = [
        for (final entry in entries)
          LevelModel.fromJson(
            jsonDecode(
                  File('assets/levels/${entry['file']}').readAsStringSync(),
                )
                as Map<String, dynamic>,
          ),
      ];
    });

    test('catalog is non-empty and every level id is unique', () {
      expect(levels, isNotEmpty);
      final ids = levels.map((l) => l.levelId).toSet();
      expect(ids, hasLength(levels.length));
    });

    test('chapters are bite-sized and their ids match their levels', () {
      final byChapter = <String, List<LevelModel>>{};
      for (final level in levels) {
        byChapter.putIfAbsent(level.chapterId, () => []).add(level);
      }

      // One giant chapter turns level select into an endless scroll and makes
      // the chapter screen pointless.
      expect(byChapter.length, greaterThan(1));
      for (final entry in byChapter.entries) {
        expect(
          entry.value.length,
          lessThanOrEqualTo(100),
          reason: '${entry.key} holds ${entry.value.length} levels',
        );
        for (final level in entry.value) {
          expect(
            level.levelId,
            startsWith('${entry.key}_'),
            reason: '${level.levelId} is filed under ${entry.key}',
          );
        }
      }
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
        final angles = {for (final m in level.mirrors) m.id: m.initialAngle};
        final result = sim.simulate(level: level, mirrorAngles: angles);
        final solved = win.evaluate(level: level, beam: result).satisfied;
        if (solved) failures.add(level.levelId);
      }
      expect(failures, isEmpty, reason: 'Pre-solved: $failures');
    });

    test('every mirror can reach its solution angle', () {
      for (final level in levels) {
        for (final entry in level.intendedSolution.mirrorAngles.entries) {
          final mirror = level.mirrors
              .where((m) => m.id == entry.key)
              .firstOrNull;
          expect(mirror, isNotNull, reason: '${level.levelId}/${entry.key}');
          expect(
            entry.value,
            inInclusiveRange(mirror!.minAngle, mirror.maxAngle),
            reason: '${level.levelId}/${entry.key}',
          );
        }
      }
    });

    // A locked mirror can never be dragged, so shipping one at any angle other
    // than the one the solution needs makes the level impossible to finish.
    test('locked mirrors already sit at their solution angle', () {
      final failures = <String>[];
      for (final level in levels) {
        final tolerance = level.intendedSolution.toleranceDegrees;
        for (final mirror in level.mirrors.where((m) => m.isLocked)) {
          final target = level.intendedSolution.mirrorAngles[mirror.id];
          if (target == null) continue;
          if ((target - mirror.initialAngle).abs() > tolerance) {
            failures.add('${level.levelId}/${mirror.id}');
          }
        }
      }
      expect(failures, isEmpty, reason: 'Stuck locked mirrors: $failures');
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
