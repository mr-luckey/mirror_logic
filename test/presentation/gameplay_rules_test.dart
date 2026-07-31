import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';

LevelModel _level({
  List<Map<String, dynamic>> mirrors = const [],
  List<Map<String, dynamic>> crystals = const [
    {
      'id': 'c1',
      'position': [500.0, 1400.0],
      'requiredHits': 1,
      'groupId': 'g1',
    },
  ],
  List<Map<String, dynamic>>? groups,
  Map<String, dynamic>? solution,
  int? requiredMirrorBounces,
}) {
  final json = <String, dynamic>{
    'levelId': 'test_001',
    'chapterId': 'ch1',
    'levelIndex': 1,
    'roomBounds': {'width': 1080.0, 'height': 1920.0},
    'lightSources': [
      {
        'id': 'l1',
        'position': [500.0, 200.0],
        'direction': 90.0,
      },
    ],
    'mirrors': mirrors,
    'obstacles': <Map<String, dynamic>>[],
    'targetCrystals': crystals,
    'intendedSolution': solution ?? {'mirrorAngles': <String, double>{}},
    'starThresholds': {'threeStarMoveCount': 3, 'threeStarTimeSeconds': 60.0},
  };
  if (groups != null) json['crystalGroups'] = groups;
  if (requiredMirrorBounces != null) {
    json['requiredMirrorBounces'] = requiredMirrorBounces;
  }
  return LevelModel.fromJson(json);
}

void main() {
  group('WinConditionEvaluator', () {
    const win = WinConditionEvaluator();

    BeamSimulationResult lighting(Set<String> ids) =>
        BeamSimulationResult(segments: const [], litCrystalIds: ids);

    test('a level with nothing to light is never solved', () {
      final level = _level(crystals: const []);
      expect(
        win.evaluate(level: level, beam: lighting(const {})).satisfied,
        isFalse,
      );
    });

    test('crystals outside every declared group still have to be lit', () {
      final level = _level(
        crystals: const [
          {
            'id': 'c1',
            'position': [500.0, 1400.0],
            'groupId': 'g1',
          },
          {
            'id': 'c2',
            'position': [700.0, 1400.0],
            'groupId': 'loose',
          },
        ],
        groups: const [
          {'groupId': 'g1', 'requiredCount': 1},
        ],
      );

      expect(
        win.evaluate(level: level, beam: lighting(const {'c1'})).satisfied,
        isFalse,
      );
      expect(
        win
            .evaluate(level: level, beam: lighting(const {'c1', 'c2'}))
            .satisfied,
        isTrue,
      );
    });

    test('a crystal reached without using every mirror is rejected', () {
      final level = _level(requiredMirrorBounces: 2);
      const beam = BeamSimulationResult(
        segments: [],
        litCrystalIds: {'c1'},
        mirrorsUsedToCrystal: {
          'c1': {'m1'},
        },
      );

      final verdict = win.evaluate(level: level, beam: beam);
      expect(verdict.satisfied, isFalse);
      expect(verdict.rejectedCrystalIds, {'c1'});
      expect(verdict.acceptedCrystalIds, isEmpty);
    });

    test('the same crystal wins once every mirror is in the route', () {
      final level = _level(requiredMirrorBounces: 2);
      const beam = BeamSimulationResult(
        segments: [],
        litCrystalIds: {'c1'},
        mirrorsUsedToCrystal: {
          'c1': {'m1', 'm2'},
        },
      );

      final verdict = win.evaluate(level: level, beam: beam);
      expect(verdict.satisfied, isTrue);
      expect(verdict.rejectedCrystalIds, isEmpty);
    });
  });

  group('mirror accounting', () {
    test('records which mirrors the route to the crystal used', () {
      // Beam runs down from (500,200); one mirror at 45° turns it right into a
      // crystal sitting on that new line.
      final level = _level(
        mirrors: const [
          {
            'id': 'm1',
            'hingePosition': [500.0, 800.0],
            'initialAngle': 45.0,
            'length': 160.0,
          },
        ],
        crystals: const [
          {
            'id': 'c1',
            'position': [900.0, 800.0],
            'requiredHits': 1,
          },
        ],
      );

      final beam = BeamSimulator().simulate(
        level: level,
        mirrorAngles: const {'m1': 45.0},
      );

      expect(beam.litCrystalIds, contains('c1'));
      expect(beam.mirrorsUsedToCrystal['c1'], {'m1'});
    });
  });

  group('solution hint', () {
    Map<String, dynamic> mirror(String id, double x, {bool locked = false}) => {
      'id': id,
      'hingePosition': [x, 800.0],
      'length': 160.0,
      'initialAngle': 10.0,
      'minAngle': 5.0,
      'maxAngle': 175.0,
      'isLocked': locked,
    };

    Future<GameplayBloc> hintingBloc({bool lockSecond = false}) async {
      final level = _level(
        mirrors: [
          mirror('m1', 400),
          mirror('m2', 600, locked: lockSecond),
        ],
        solution: const {
          'mirrorAngles': {'m1': 45.0, 'm2': 135.0},
          'toleranceDegrees': 4.0,
        },
      );
      final bloc = GameplayBloc(levelRepository: LevelRepository())
        ..add(GameplayStarted(level));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const GameplayHintRequested());
      await Future<void>.delayed(Duration.zero);
      return bloc;
    }

    test('ghosts every mirror the player still has to turn', () async {
      final bloc = await hintingBloc();

      expect(bloc.state.phase, GameplayPhase.hint);
      expect(bloc.state.ghostAngles, {'m1': 45.0, 'm2': 135.0});
      expect(bloc.state.solutionRevealed, isTrue);
      await bloc.close();
    });

    test('leaves out mirrors the player cannot move', () async {
      final bloc = await hintingBloc(lockSecond: true);

      expect(bloc.state.ghostAngles.keys, ['m1']);
      await bloc.close();
    });

    test('closing the panel keeps the ghosts on the board', () async {
      final bloc = await hintingBloc();

      bloc.add(const GameplayHintDismissed());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.phase, GameplayPhase.playing);
      expect(bloc.state.ghostAngles, isNotEmpty);
      await bloc.close();
    });

    test('a restart cannot wash the revealed solution away', () async {
      final bloc = await hintingBloc();

      bloc.add(const GameplayHintDismissed());
      bloc.add(const GameplayRestarted());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.solutionRevealed, isTrue);
      expect(bloc.state.ghostAngles, isNotEmpty);
      expect(bloc.state.computeStars(), 1);
      await bloc.close();
    });
  });

  group('LevelValidator', () {
    test('a locked mirror at the wrong angle makes the level unsolvable', () {
      Map<String, dynamic> mirror({required bool locked}) => {
        'id': 'm1',
        'hingePosition': [500.0, 800.0],
        'length': 160.0,
        'initialAngle': 0.0,
        'minAngle': 0.0,
        'maxAngle': 180.0,
        'isLocked': locked,
      };

      const solution = {
        'mirrorAngles': {'m1': 45.0},
        'toleranceDegrees': 4.0,
      };

      final validator = LevelValidator();

      // Unlocked: the player can turn m1 to 45° themselves.
      expect(
        validator.reachableSolution(
          _level(mirrors: [mirror(locked: false)], solution: solution),
        )['m1'],
        45.0,
      );
      // Locked: no drag will ever move it off its shipped angle.
      expect(
        validator.reachableSolution(
          _level(mirrors: [mirror(locked: true)], solution: solution),
        )['m1'],
        0.0,
      );
    });
  });

  group('relay crystals', () {
    test('a relay is not re-hit by the beam that just passed through it', () {
      final level = _level(
        crystals: const [
          {
            'id': 'r1',
            'position': [500.0, 800.0],
            'relay': true,
            'hitRadius': 40.0,
            'groupId': 'g1',
          },
          {
            'id': 'c1',
            'position': [500.0, 1400.0],
            'hitRadius': 40.0,
            'groupId': 'g1',
          },
        ],
      );

      final result = BeamSimulator().simulate(
        level: level,
        mirrorAngles: const {},
      );

      final relayHits = result.segments
          .where((s) => s.hitKind == BeamHitKind.crystal && s.hitId == 'r1')
          .length;
      expect(relayHits, 1);
      expect(result.litCrystalIds, containsAll(<String>['r1', 'c1']));
    });
  });

  group('GameplayState.computeStars', () {
    GameplayState stateWith({
      int moves = 0,
      double seconds = 0,
      int hintsUsed = 0,
      bool solutionRevealed = false,
    }) {
      return GameplayState(
        phase: GameplayPhase.playing,
        level: _level(),
        moves: moves,
        elapsedSeconds: seconds,
        hintsUsed: hintsUsed,
        solutionRevealed: solutionRevealed,
      );
    }

    test('opening the hint panel alone does not cost stars', () {
      expect(stateWith(hintsUsed: 1).computeStars(), 3);
    });

    test('seeing the solution drops the player to one star', () {
      expect(stateWith(hintsUsed: 1, solutionRevealed: true).computeStars(), 1);
    });

    test('going over the move budget drops to two stars', () {
      expect(stateWith(moves: 9).computeStars(), 2);
    });
  });

  group('BeamSimulationResult', () {
    test('compares by value so an unchanged beam does not force a repaint', () {
      const a = BeamSimulationResult(
        segments: [BeamSegment(start: Vec2(0, 0), end: Vec2(1, 1))],
        litCrystalIds: {'c1'},
      );
      final b = BeamSimulationResult(
        segments: [const BeamSegment(start: Vec2(0, 0), end: Vec2(1, 1))],
        litCrystalIds: const {'c1'},
      );
      expect(a, b);
    });
  });

  group('PlayerSave chapter matching', () {
    test('ch1 does not swallow ch10 progress', () {
      const save = PlayerSave(
        levelProgress: {
          'ch1_001': LevelProgress(
            levelId: 'ch1_001',
            stars: 3,
            completed: true,
          ),
          'ch10_001': LevelProgress(
            levelId: 'ch10_001',
            stars: 2,
            completed: true,
          ),
        },
      );

      expect(save.starsForChapter('ch1'), 3);
      expect(save.starsForChapter('ch10'), 2);
      expect(save.completedCountForChapter('ch1'), 1);
    });
  });
}
