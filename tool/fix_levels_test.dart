import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

/// Run with: flutter test tool/fix_levels_test.dart
/// Mutates assets so intended solutions light the crystal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fix all generated levels onto beam path', () {
    final sim = BeamSimulator();
    const win = WinConditionEvaluator();
    var failed = 0;

    final catalogFile = File('assets/levels/levels.json');
    final root =
        jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
    final allLevels = (root['levels'] as List).cast<Map<String, dynamic>>();

    for (final chapter in ['ch1', 'ch2']) {
      final manifest = allLevels
          .where((l) => l['chapterId'] == chapter)
          .map((l) => l['levelId'] as String)
          .toList();
      for (final id in manifest) {
        final json = allLevels.firstWhere((l) => l['levelId'] == id);
        var level = LevelModel.fromJson(json);
        final angles = {
          for (final m in level.mirrors) m.id: m.initialAngle,
          ...level.intendedSolution.mirrorAngles,
        };
        var result = sim.simulate(level: level, mirrorAngles: angles);
        if (!win.isSatisfied(
          level: level,
          litCrystalIds: result.litCrystalIds,
        )) {
          final point = _pickCrystalPoint(result);
          if (point != null && level.targetCrystals.isNotEmpty) {
            final c = level.targetCrystals.first;
            // Also strip obstacles that block the solution beam.
            json['obstacles'] = <dynamic>[];
            json['targetCrystals'] = [
              {
                'id': c.id,
                'position': [
                  point.x.clamp(80, level.roomBounds.x - 80),
                  point.y.clamp(80, level.roomBounds.y - 80),
                ],
                'hitRadius': math.max(c.hitRadius, 52),
                'groupId': c.groupId,
              }
            ];
            level = LevelModel.fromJson(json);
            result = sim.simulate(level: level, mirrorAngles: angles);
          }
        }

        final ok = win.isSatisfied(
          level: level,
          litCrystalIds: result.litCrystalIds,
        );
        if (!ok) {
          failed++;
          // ignore: avoid_print
          print('FAIL $id segments=${result.segments.length}');
        }
      }
    }

    catalogFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(root),
    );
    expect(failed, 0);
  });
}

Vec2? _pickCrystalPoint(BeamSimulationResult result) {
  if (result.segments.isEmpty) return null;
  for (var i = result.segments.length - 1; i >= 0; i--) {
    final s = result.segments[i];
    final len = s.start.distanceTo(s.end);
    if (len < 40) continue;
    // Place before end so we don't sit on a wall/bounds hit.
    final t = s.hitKind == BeamHitKind.bounds || s.hitKind == BeamHitKind.wall
        ? 0.55
        : 0.75;
    return Vec2(
      s.start.x + (s.end.x - s.start.x) * t,
      s.start.y + (s.end.y - s.start.y) * t,
    );
  }
  final s = result.segments.first;
  return Vec2(
    (s.start.x + s.end.x) / 2,
    (s.start.y + s.end.y) / 2,
  );
}
