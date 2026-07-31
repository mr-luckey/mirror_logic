import 'dart:convert';
import 'dart:io';

import 'package:mirror_logic/domain/beam/beam_alignment.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

/// Detents are computed once per drag start, on the UI isolate, so the cost has
/// to stay well inside a frame. Run with `dart run tool/bench_alignment.dart`.
void main() {
  final raw = File('assets/levels/levels.json').readAsStringSync();
  final root = jsonDecode(raw) as Map<String, dynamic>;
  final levels = (root['levels'] as List)
      .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
      .toList();

  final finder = BeamAlignmentFinder();
  final simulator = BeamSimulator();
  var worstMicros = 0;
  var worstLevel = '';
  var totalMicros = 0;
  var drags = 0;
  var detentTotal = 0;
  var reachable = 0;
  var reachableWithDetent = 0;

  for (final level in levels) {
    final angles = {for (final m in level.mirrors) m.id: m.initialAngle};
    final lit = simulator
        .simulate(level: level, mirrorAngles: angles)
        .segments
        .where((s) => s.hitKind == BeamHitKind.mirror)
        .map((s) => s.hitId)
        .toSet();
    for (final mirror in level.mirrors) {
      if (mirror.isLocked) continue;
      final watch = Stopwatch()..start();
      final detents = finder.detentsFor(
        level: level,
        mirrorAngles: angles,
        mirrorId: mirror.id,
      );
      watch.stop();
      detentTotal += detents.length;
      if (lit.contains(mirror.id)) {
        reachable++;
        if (detents.isNotEmpty) reachableWithDetent++;
      }
      totalMicros += watch.elapsedMicroseconds;
      drags++;
      if (watch.elapsedMicroseconds > worstMicros) {
        worstMicros = watch.elapsedMicroseconds;
        worstLevel = '${level.levelId}/${mirror.id}';
      }
    }
  }

  stdout
    ..writeln('drags measured: $drags')
    ..writeln('average: ${(totalMicros / drags / 1000).toStringAsFixed(2)} ms')
    ..writeln('worst:   ${(worstMicros / 1000).toStringAsFixed(2)} ms '
        '($worstLevel)')
    ..writeln(
      'detents per drag: ${(detentTotal / drags).toStringAsFixed(2)}',
    )
    ..writeln('mirrors the beam reaches: $reachable, '
        'of which offer a detent: $reachableWithDetent');
}
