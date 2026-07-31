import 'package:equatable/equatable.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

/// The verdict on a beam: whether the level is won, and which crystals the
/// beam is touching without actually counting.
class WinEvaluation extends Equatable {
  const WinEvaluation({
    required this.satisfied,
    required this.acceptedCrystalIds,
    required this.rejectedCrystalIds,
  });

  static const none = WinEvaluation(
    satisfied: false,
    acceptedCrystalIds: {},
    rejectedCrystalIds: {},
  );

  final bool satisfied;

  /// Crystals reached by a path the level accepts.
  final Set<String> acceptedCrystalIds;

  /// Crystals the beam is hitting on a path the level rejects — it reached
  /// them without going through every mirror on the board. These read as a
  /// wrong answer, not a win.
  final Set<String> rejectedCrystalIds;

  @override
  List<Object?> get props =>
      [satisfied, acceptedCrystalIds, rejectedCrystalIds];
}

class WinConditionEvaluator {
  const WinConditionEvaluator();

  WinEvaluation evaluate({
    required LevelModel level,
    required BeamSimulationResult beam,
  }) {
    final accepted = <String>{};
    final rejected = <String>{};
    final required = level.requiredMirrorCount;

    for (final id in beam.litCrystalIds) {
      final used = beam.mirrorsUsedToCrystal[id];
      // Counted along the route that reached this crystal, so a beam that cut
      // the corner and left a mirror out lands here. Hitting one mirror twice
      // does not help and is not held against the player either.
      if (required != null && used != null && used.length < required) {
        rejected.add(id);
      } else {
        accepted.add(id);
      }
    }

    return WinEvaluation(
      satisfied: _satisfied(level, accepted),
      acceptedCrystalIds: Set<String>.unmodifiable(accepted),
      rejectedCrystalIds: Set<String>.unmodifiable(rejected),
    );
  }

  bool _satisfied(LevelModel level, Set<String> litCrystalIds) {
    // A level with nothing to light would otherwise win on the first tick.
    if (level.targetCrystals.isEmpty) return false;

    for (final group in level.crystalGroups) {
      final members = level.targetCrystals
          .where((c) => c.groupId == group.groupId)
          .map((c) => c.id)
          .toSet();
      final litCount = members.intersection(litCrystalIds).length;
      if (litCount < group.requiredCount) return false;
    }

    // Crystals outside every declared group still have to be lit; otherwise a
    // level could be won while ignoring most of its targets.
    final grouped = level.crystalGroups.map((g) => g.groupId).toSet();
    for (final crystal in level.targetCrystals) {
      if (grouped.contains(crystal.groupId)) continue;
      if (!litCrystalIds.contains(crystal.id)) return false;
    }

    return true;
  }
}

class LevelValidator {
  LevelValidator({BeamSimulator? simulator})
      : _simulator = simulator ?? BeamSimulator();

  final BeamSimulator _simulator;
  final _win = const WinConditionEvaluator();

  /// Angles the player can actually reach: locked mirrors keep whatever the
  /// level shipped them at, since no drag will ever move them.
  Map<String, double> reachableSolution(LevelModel level) {
    final solution = level.intendedSolution.mirrorAngles;
    return {
      for (final m in level.mirrors)
        m.id: m.isLocked
            ? m.initialAngle
            : (solution[m.id] ?? m.initialAngle),
    };
  }

  bool isSolvable(LevelModel level) {
    final beam = _simulator.simulate(
      level: level,
      mirrorAngles: reachableSolution(level),
    );
    return _win.evaluate(level: level, beam: beam).satisfied;
  }
}
