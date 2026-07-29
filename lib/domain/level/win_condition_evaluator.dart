import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

class WinConditionEvaluator {
  const WinConditionEvaluator();

  bool isSatisfied({
    required LevelModel level,
    required Set<String> litCrystalIds,
  }) {
    for (final group in level.crystalGroups) {
      final members = level.targetCrystals
          .where((c) => c.groupId == group.groupId)
          .map((c) => c.id)
          .toSet();
      final litCount = members.intersection(litCrystalIds).length;
      if (litCount < group.requiredCount) return false;
    }
    // Fallback: if no groups, require all crystals.
    if (level.crystalGroups.isEmpty) {
      return litCrystalIds.length >= level.targetCrystals.length;
    }
    return true;
  }
}

class LevelValidator {
  LevelValidator({BeamSimulator? simulator})
      : _simulator = simulator ?? BeamSimulator();

  final BeamSimulator _simulator;
  final _win = const WinConditionEvaluator();

  /// Returns true if intended solution lights all required crystals.
  bool isSolvable(LevelModel level) {
    if (level.intendedSolution.mirrorAngles.isEmpty) {
      // Allow levels that are already solved at initial angles.
      final result = _simulator.simulate(
        level: level,
        mirrorAngles: {
          for (final m in level.mirrors) m.id: m.initialAngle,
        },
      );
      return _win.isSatisfied(level: level, litCrystalIds: result.litCrystalIds);
    }

    final angles = {
      for (final m in level.mirrors) m.id: m.initialAngle,
      ...level.intendedSolution.mirrorAngles,
    };
    final result = _simulator.simulate(level: level, mirrorAngles: angles);
    return _win.isSatisfied(level: level, litCrystalIds: result.litCrystalIds);
  }
}
