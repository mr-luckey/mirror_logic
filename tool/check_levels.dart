import 'dart:convert';
import 'dart:io';

import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

void main() {
  final raw = File('assets/levels/levels.json').readAsStringSync();
  final root = jsonDecode(raw) as Map<String, dynamic>;
  final levels = (root['levels'] as List).cast<Map<String, dynamic>>();

  final sim = BeamSimulator();
  final win = WinConditionEvaluator();

  for (final json in levels) {
    final level = LevelModel.fromJson(json);
    final angles = {
      for (final m in level.mirrors) m.id: m.initialAngle,
      ...level.intendedSolution.mirrorAngles,
    };
    final r = sim.simulate(level: level, mirrorAngles: angles);
    final ok = win.isSatisfied(
      level: level,
      litCrystalIds: r.litCrystalIds,
      segments: r.segments,
    );
    print(
      '${level.levelId} ${ok ? "OK" : "FAIL"} lit=${r.litCrystalIds}',
    );
  }
}
