import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/domain/beam/beam_alignment.dart';
import 'package:mirror_logic/domain/beam/reflection_math.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';

const hinge = Vec2(540, 960);

LevelModel buildLevel({
  double initialAngle = 90,
  double snapIncrement = 0,
  Vec2 crystal = const Vec2(540, 300),
}) {
  return LevelModel.fromJson({
    'levelId': 'test_001',
    'chapterId': 'ch1',
    'levelIndex': 1,
    'roomBounds': {'width': 1080.0, 'height': 1920.0},
    'lightSources': [
      {
        'id': 'ls1',
        'position': [80.0, 960.0],
        'direction': 0.0,
      },
    ],
    'mirrors': [
      {
        'id': 'm1',
        'hingePosition': [hinge.x, hinge.y],
        'length': 145.0,
        'initialAngle': initialAngle,
        'minAngle': 5.0,
        'maxAngle': 175.0,
        'snapIncrement': snapIncrement,
      },
    ],
    'obstacles': <dynamic>[],
    'targetCrystals': [
      {
        'id': 'c1',
        'position': [crystal.x, crystal.y],
        'hitRadius': 44.0,
        'groupId': 'g1',
      },
    ],
  });
}

/// A point [degrees] around the hinge at [radius], matching screen coordinates.
Vec2 around(double degrees, {double radius = 200}) {
  final rad = degrees * math.pi / 180;
  return Vec2(hinge.x + math.cos(rad) * radius, hinge.y + math.sin(rad) * radius);
}

Future<GameplayBloc> startedBloc(LevelModel level) async {
  final bloc = GameplayBloc(levelRepository: LevelRepository())
    ..add(GameplayStarted(level));
  await Future<void>.delayed(Duration.zero);
  return bloc;
}

Future<void> drag(
  GameplayBloc bloc,
  List<Vec2> points, {
  bool release = true,
}) async {
  bloc.add(GameplayMirrorDragStarted(mirrorId: 'm1', grabPoint: points.first));
  await Future<void>.delayed(Duration.zero);
  for (final p in points.skip(1)) {
    bloc.add(GameplayMirrorDragged(mirrorId: 'm1', worldPoint: p));
    await Future<void>.delayed(Duration.zero);
  }
  if (release) {
    bloc.add(const GameplayMirrorDragEnded());
    await Future<void>.delayed(Duration.zero);
  }
}

/// Sweeps from [from] to [to] in small steps, the way a real finger arrives.
List<Vec2> sweep(double from, double to, {double radius = 200}) {
  const stepSize = 5.0;
  final steps = ((to - from).abs() / stepSize).ceil();
  return [
    for (var i = 0; i <= steps; i++) around(from + (to - from) * i / steps, radius: radius),
  ];
}

void main() {
  group('ReflectionMath angle helpers', () {
    test('mirror angles fold into [0, 180)', () {
      expect(ReflectionMath.normalizeMirrorAngle(-45), closeTo(135, 1e-9));
      expect(ReflectionMath.normalizeMirrorAngle(-175), closeTo(5, 1e-9));
      expect(ReflectionMath.normalizeMirrorAngle(200), closeTo(20, 1e-9));
      expect(ReflectionMath.normalizeMirrorAngle(90), closeTo(90, 1e-9));
    });

    test('signed delta takes the short way around', () {
      expect(ReflectionMath.signedAngleDelta(170, -170), closeTo(20, 1e-9));
      expect(ReflectionMath.signedAngleDelta(-170, 170), closeTo(-20, 1e-9));
      expect(ReflectionMath.signedAngleDelta(10, 40), closeTo(30, 1e-9));
    });
  });

  group('mirror drag', () {
    test('grabbing above the hinge does not slam the mirror to minAngle', () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 135));
      // -135° is up and to the left: the old absolute mapping clamped this to 5.
      await drag(bloc, [around(-135), around(-134)], release: false);
      expect(bloc.state.mirrorAngles['m1'], greaterThan(100));
      await bloc.close();
    });

    test('mirror turns by how far the finger swept, not where it landed', () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 90));
      await drag(bloc, sweep(0, 40), release: false);
      expect(bloc.state.mirrorAngles['m1'], closeTo(130, 1.0));
      await bloc.close();
    });

    test('grabbing far from the current angle does not jump', () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 90));
      bloc.add(GameplayMirrorDragStarted(mirrorId: 'm1', grabPoint: around(20)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.mirrorAngles['m1'], closeTo(90, 1e-9));
      await bloc.close();
    });

    test('rotation past the limit does not leave a dead zone coming back',
        () async {
      // Crystal below the hinge, so its detent sits at 45° and stays out of
      // the way of what this test is measuring.
      final bloc = await startedBloc(
        buildLevel(initialAngle: 170, crystal: const Vec2(540, 1600)),
      );
      // Push 40° past the 175 limit, then come straight back 40°.
      await drag(bloc, [...sweep(0, 45), ...sweep(45, 0)], release: false);
      expect(bloc.state.mirrorAngles['m1'], closeTo(130, 2.0));
      await bloc.close();
    });

    test('rotation near the hinge is damped, not amplified', () async {
      final near = await startedBloc(buildLevel(initialAngle: 90));
      await drag(near, sweep(0, 40, radius: 30), release: false);
      final nearTurn = (near.state.mirrorAngles['m1']! - 90).abs();

      final far = await startedBloc(buildLevel(initialAngle: 90));
      await drag(far, sweep(0, 40, radius: 200), release: false);
      final farTurn = (far.state.mirrorAngles['m1']! - 90).abs();

      expect(nearTurn, lessThan(farTurn));
      await near.close();
      await far.close();
    });

    test('snapIncrement quantises the mirror without sticking', () async {
      final bloc = await startedBloc(
        buildLevel(initialAngle: 90, snapIncrement: 5),
      );
      await drag(bloc, sweep(0, 22), release: false);
      final angle = bloc.state.mirrorAngles['m1']!;
      expect(angle % 5, closeTo(0, 1e-9));
      expect(angle, greaterThan(90));
      await bloc.close();
    });
  });

  // The light fires right into the hinge and the crystal sits straight above
  // it, so 135° is the angle that puts the beam through the crystal's heart.
  group('alignment detents', () {
    test('the drag settles exactly on the crystal instead of near it',
        () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 90));
      // Sweep 44°, which on its own would land at 134 — just short.
      await drag(bloc, sweep(0, 44), release: false);

      expect(bloc.state.mirrorAngles['m1'], closeTo(135, 0.3));
      expect(bloc.state.alignedTargetId, 'c1');
      expect(bloc.state.alignedTargetKind, AlignmentTargetKind.crystal);
      expect(bloc.state.alignmentPulse, 1);
      await bloc.close();
    });

    test('one lock pulses once, however long it is held', () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 90));
      await drag(bloc, sweep(0, 46), release: false);

      expect(bloc.state.alignmentPulse, 1);
      expect(bloc.state.alignedTargetId, 'c1');
      await bloc.close();
    });

    test('sweeping well past the target breaks the lock', () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 90));
      await drag(bloc, sweep(0, 60), release: false);

      expect(bloc.state.mirrorAngles['m1'], greaterThan(140));
      expect(bloc.state.alignedTargetId, isNull);
      await bloc.close();
    });

    test('releasing the mirror clears the lock', () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 90));
      await drag(bloc, sweep(0, 44));

      expect(bloc.state.mirrorAngles['m1'], closeTo(135, 0.3));
      expect(bloc.state.alignedTargetId, isNull);
      await bloc.close();
    });

    test('a mirror with its own snap increment is left alone', () async {
      final bloc = await startedBloc(
        buildLevel(initialAngle: 90, snapIncrement: 5),
      );
      await drag(bloc, sweep(0, 44), release: false);

      expect(bloc.state.mirrorAngles['m1']! % 5, closeTo(0, 1e-9));
      expect(bloc.state.alignedTargetId, isNull);
      await bloc.close();
    });
  });

  group('move accounting', () {
    test('a grab with no rotation costs nothing', () async {
      final bloc = await startedBloc(buildLevel());
      await drag(bloc, [around(30)]);
      expect(bloc.state.moves, 0);
      expect(bloc.state.undoStack, isEmpty);
      await bloc.close();
    });

    test('a completed rotation costs one move and is undoable', () async {
      final bloc = await startedBloc(buildLevel(initialAngle: 90));
      await drag(bloc, sweep(0, 30));
      expect(bloc.state.moves, 1);
      expect(bloc.state.undoStack, hasLength(1));

      bloc.add(const GameplayUndoRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.mirrorAngles['m1'], closeTo(90, 1e-9));
      await bloc.close();
    });
  });
}
