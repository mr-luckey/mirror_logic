import 'dart:convert';
import 'dart:io';

import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

/// Validates every level in the catalog against its intended solution.
/// Run: dart run tool/check_levels.dart
void main() {
  final raw = File('assets/levels/levels.json').readAsStringSync();
  final root = jsonDecode(raw) as Map<String, dynamic>;
  final levels = (root['levels'] as List).cast<Map<String, dynamic>>();

  final sim = BeamSimulator();
  const win = WinConditionEvaluator();

  final unsolvable = <String>[];
  final preSolved = <String>[];

  for (final json in levels) {
    final level = LevelModel.fromJson(json);

    final solved = sim.simulate(
      level: level,
      mirrorAngles: {
        for (final m in level.mirrors) m.id: m.initialAngle,
        ...level.intendedSolution.mirrorAngles,
      },
    );
    if (!win.isSatisfied(
      level: level,
      litCrystalIds: solved.litCrystalIds,
      segments: solved.segments,
    )) {
      unsolvable.add(level.levelId);
    }

    final initial = sim.simulate(
      level: level,
      mirrorAngles: {for (final m in level.mirrors) m.id: m.initialAngle},
    );
    if (win.isSatisfied(
      level: level,
      litCrystalIds: initial.litCrystalIds,
      segments: initial.segments,
    )) {
      preSolved.add(level.levelId);
    }
  }

  stdout
    ..writeln('levels: ${levels.length}')
    ..writeln('unsolvable at intended solution: ${unsolvable.length}')
    ..writeln('already solved at start: ${preSolved.length}');

  if (unsolvable.isNotEmpty) {
    stdout.writeln('  unsolvable: ${unsolvable.take(25).join(", ")}');
  }
  if (preSolved.isNotEmpty) {
    stdout.writeln('  pre-solved: ${preSolved.take(25).join(", ")}');
  }
  if (unsolvable.isNotEmpty || preSolved.isNotEmpty) exit(1);
}
