import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

class WinConditionEvaluator {
  const WinConditionEvaluator();

  bool isSatisfied({
    required LevelModel level,
    required Set<String> litCrystalIds,
    List<BeamSegment>? segments,
  }) {
    for (final group in level.crystalGroups) {
      final members = level.targetCrystals
          .where((c) => c.groupId == group.groupId)
          .map((c) => c.id)
          .toSet();
      final litCount = members.intersection(litCrystalIds).length;
      if (litCount < group.requiredCount) return false;
    }
    if (level.crystalGroups.isEmpty) {
      if (litCrystalIds.length < level.targetCrystals.length) return false;
    }

    final required = level.requiredMirrorBounces;
    if (required != null) {
      final bounces = segments
              ?.where((s) => s.hitKind == BeamHitKind.mirror)
              .length ??
          0;
      if (bounces != required) return false;
    }
    return true;
  }
}

class LevelValidator {
  LevelValidator({BeamSimulator? simulator})
      : _simulator = simulator ?? BeamSimulator();

  final BeamSimulator _simulator;
  final _win = const WinConditionEvaluator();

  bool isSolvable(LevelModel level) {
    final angles = level.intendedSolution.mirrorAngles.isEmpty
        ? {for (final m in level.mirrors) m.id: m.initialAngle}
        : {
            for (final m in level.mirrors) m.id: m.initialAngle,
            ...level.intendedSolution.mirrorAngles,
          };
    final result = _simulator.simulate(level: level, mirrorAngles: angles);
    return _win.isSatisfied(
      level: level,
      litCrystalIds: result.litCrystalIds,
      segments: result.segments,
    );
  }
}
