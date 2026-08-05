import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_walkthrough.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_walkthrough_layer.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_hand.dart';

import '../support/memory_box.dart';

/// The hand plays the opening board for real, through the same drag events a
/// finger sends. If the shipped first level ever stops being solvable that way,
/// the walkthrough is teaching a gesture that does not work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LevelModel first;

  setUpAll(() {
    final raw = File(
      'assets/levels/${GameConstants.firstLevelId}.json',
    ).readAsStringSync();
    first = LevelModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  Future<GameplayBloc> startedBloc(LevelModel level) async {
    final bloc = GameplayBloc(levelRepository: LevelRepository())
      ..add(GameplayStarted(level));
    await Future<void>.delayed(Duration.zero);
    return bloc;
  }

  Future<void> playLesson(GameplayBloc bloc, WalkthroughLesson lesson) async {
    final points = lesson.sweepPoints();
    bloc.add(
      GameplayMirrorDragStarted(
        mirrorId: lesson.mirrorId,
        grabPoint: lesson.grabPoint,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    for (final point in points.skip(1)) {
      bloc.add(
        GameplayMirrorDragged(mirrorId: lesson.mirrorId, worldPoint: point),
      );
      await Future<void>.delayed(Duration.zero);
    }
    bloc.add(const GameplayMirrorDragEnded());
    await Future<void>.delayed(Duration.zero);
  }

  test('the first level has mirrors left to demonstrate', () {
    final lessons = Walkthrough.lessonsFor(
      level: first,
      angles: {for (final m in first.mirrors) m.id: m.initialAngle},
    );
    expect(lessons, isNotEmpty);
    for (final lesson in lessons) {
      expect(lesson.sweepDegrees.abs(), greaterThan(1));
      expect(lesson.turnDuration.inMilliseconds, greaterThan(0));
    }
  });

  test('the demonstrated arc lands each mirror on its solved angle', () async {
    final bloc = await startedBloc(first);
    final lessons = Walkthrough.lessonsFor(
      level: first,
      angles: bloc.state.mirrorAngles,
    );

    for (final lesson in lessons) {
      await playLesson(bloc, lesson);
      expect(
        bloc.state.mirrorAngles[lesson.mirrorId],
        closeTo(lesson.toAngle, first.intendedSolution.toleranceDegrees),
        reason: '${lesson.mirrorId} stopped short of the solution',
      );
    }

    await bloc.close();
  });

  test('playing every lesson clears the board', () async {
    final bloc = await startedBloc(first);
    final lessons = Walkthrough.lessonsFor(
      level: first,
      angles: bloc.state.mirrorAngles,
    );

    for (final lesson in lessons) {
      await playLesson(bloc, lesson);
    }

    // The win needs the beam held on the crystal for a moment, so let the
    // board's own ticker run past the hold time.
    await Future<void>.delayed(
      Duration(
        milliseconds: (GameConstants.holdTimeSeconds * 1000).round() + 250,
      ),
    );

    expect(bloc.state.phase, GameplayPhase.solved);
    await bloc.close();
  });

  test('a mirror already solved is not demonstrated', () {
    final lessons = Walkthrough.lessonsFor(
      level: first,
      angles: first.intendedSolution.mirrorAngles,
    );
    expect(lessons, isEmpty);
  });

  group('the hand on the board', () {
    const canvas = Size(360, 620);

    setUpAll(() {
      // Otherwise every text style tries to fetch a font over the network.
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    /// Mounts the layer over a board that is already running, and hands back
    /// the two blocs the walkthrough talks to.
    ///
    /// The board is started without awaiting a real delay: inside a widget test
    /// the clock only moves when the tester pumps.
    Future<(GameplayBloc, ProgressBloc)> pumpLayer(WidgetTester tester) async {
      final saves = SaveRepository(LocalStorageService(MemoryBox()));
      final gameplay = GameplayBloc(levelRepository: LevelRepository())
        ..add(GameplayStarted(first));
      final progress = ProgressBloc(saveRepository: saves);
      addTearDown(gameplay.close);
      addTearDown(progress.close);
      // Tear-downs run last-registered first, so the hand comes off the tree
      // before the board it is driving is closed under it.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: gameplay),
            BlocProvider.value(value: progress),
          ],
          child: MaterialApp(
            home: Center(
              child: SizedBox(
                width: canvas.width,
                height: canvas.height,
                child: GameplayWalkthroughLayer(
                  level: first,
                  canvasSize: canvas,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return (gameplay, progress);
    }

    /// Runs the clock frame by frame: the hand feeds the board one drag update
    /// per frame, so a single long pump would skip the whole gesture.
    Future<void> advance(WidgetTester tester, Duration total) async {
      for (var ms = 0; ms < total.inMilliseconds; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('turns the first mirror on its own, then hands over', (
      tester,
    ) async {
      final (gameplay, _) = await pumpLayer(tester);
      final firstMirror = first.mirrors.first;

      await advance(tester, const Duration(milliseconds: 1600));
      expect(find.byType(MedievalHand), findsOneWidget);

      await advance(tester, const Duration(milliseconds: 2400));
      expect(
        gameplay.state.mirrorAngles[firstMirror.id],
        closeTo(
          first.intendedSolution.mirrorAngles[firstMirror.id]!,
          first.intendedSolution.toleranceDegrees,
        ),
      );
      // The board is not finished for them: the next mirror is an invitation.
      expect(find.text('Your turn — turn this mirror'), findsOneWidget);
    });

    testWidgets('gets out of the way the moment the player grabs a mirror', (
      tester,
    ) async {
      final (gameplay, progress) = await pumpLayer(tester);

      await advance(tester, const Duration(milliseconds: 1600));
      expect(find.byType(MedievalHand), findsOneWidget);

      final other = first.mirrors.last;
      gameplay.add(
        GameplayMirrorDragStarted(
          mirrorId: other.id,
          grabPoint: other.hingePosition + const Vec2(120, 0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MedievalHand), findsNothing);
      // And it does not come back for this player on the next board.
      await tester.pump(const Duration(milliseconds: 50));
      expect(progress.state.save.walkthroughSeen, isTrue);
    });
  });
}
