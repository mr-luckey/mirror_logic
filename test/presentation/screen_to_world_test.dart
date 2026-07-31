import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_painter.dart';

LevelModel _level() => LevelModel.fromJson(const {
  'levelId': 'test_001',
  'chapterId': 'ch1',
  'levelIndex': 1,
  'roomBounds': {'width': 1000.0, 'height': 1000.0},
  'lightSources': <Map<String, dynamic>>[],
  'mirrors': <Map<String, dynamic>>[],
  'obstacles': <Map<String, dynamic>>[],
  'targetCrystals': <Map<String, dynamic>>[],
  'intendedSolution': {'mirrorAngles': <String, double>{}},
  'starThresholds': <String, dynamic>{},
});

void main() {
  group('screenToWorld', () {
    final level = _level();
    const canvas = Size(1000, 1000);

    test('maps a touch inside the board', () {
      final world = screenToWorld(
        local: const Offset(250, 400),
        canvasSize: canvas,
        level: level,
      );
      expect(world!.x, closeTo(250, 0.001));
      expect(world.y, closeTo(400, 0.001));
    });

    test('bounded mapping rejects a touch well outside the board', () {
      expect(
        screenToWorld(
          local: const Offset(-300, 500),
          canvasSize: canvas,
          level: level,
        ),
        isNull,
      );
    });

    test('unbounded mapping keeps tracking a finger off the board', () {
      // Aiming is most precise with the finger far from the hinge, which puts
      // it outside the room; the drag must not freeze there.
      final world = screenToWorld(
        local: const Offset(-300, 1400),
        canvasSize: canvas,
        level: level,
        bounded: false,
      );
      expect(world, isNotNull);
      expect(world!.x, closeTo(-300, 0.001));
      expect(world.y, closeTo(1400, 0.001));
    });
  });
}
