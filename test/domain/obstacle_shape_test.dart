import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/beam/beam_simulator.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

Map<String, dynamic> square(String id, double cx, double cy, {String? shape}) {
  const half = 30.0;
  final json = <String, dynamic>{
    'id': id,
    'polygon': [
      [cx - half, cy - half],
      [cx + half, cy - half],
      [cx + half, cy + half],
      [cx - half, cy + half],
    ],
  };
  if (shape != null) json['shape'] = shape;
  return json;
}

/// Emitter on the left wall firing straight at a crystal on the same row.
Map<String, dynamic> levelJson({
  List<Map<String, dynamic>> obstacles = const [],
}) {
  return {
    'levelId': 'shape_001',
    'chapterId': 'ch_test',
    'roomBounds': {'width': 1080.0, 'height': 1920.0},
    'lightSources': [
      {
        'id': 'ls1',
        'position': [0.0, 960.0],
        'direction': 0.0,
      },
    ],
    'mirrors': <dynamic>[],
    'obstacles': obstacles,
    'targetCrystals': [
      {
        'id': 'c1',
        'position': [900.0, 960.0],
        'hitRadius': 44.0,
        'groupId': 'g1',
      },
    ],
  };
}

bool crystalLit(LevelModel level) {
  final result = BeamSimulator().simulate(level: level, mirrorAngles: const {});
  return result.litCrystalIds.contains('c1');
}

void main() {
  group('ObstacleDef.shape parsing', () {
    test('defaults to wall when the key is absent', () {
      final o = ObstacleDef.fromJson(square('w1', 100, 100));
      expect(o.shape, ObstacleShape.wall);
      expect(o.isDecorative, isFalse);
    });

    test('reads the pillar shape', () {
      final o = ObstacleDef.fromJson(square('p1', 100, 100, shape: 'pillar'));
      expect(o.shape, ObstacleShape.pillar);
    });

    test('reads an explicit wall shape', () {
      final o = ObstacleDef.fromJson(square('w1', 100, 100, shape: 'wall'));
      expect(o.shape, ObstacleShape.wall);
    });

    test('falls back to wall for an unknown shape', () {
      final o = ObstacleDef.fromJson(square('w1', 100, 100, shape: 'buttress'));
      expect(o.shape, ObstacleShape.wall);
    });

    test('shape takes part in equality', () {
      final wall = ObstacleDef.fromJson(square('x', 10, 10, shape: 'wall'));
      final pillar = ObstacleDef.fromJson(square('x', 10, 10, shape: 'pillar'));
      expect(wall, isNot(pillar));
      expect(wall, ObstacleDef.fromJson(square('x', 10, 10)));
    });
  });

  group('pillars block the beam', () {
    test('an unobstructed beam reaches the crystal', () {
      expect(crystalLit(LevelModel.fromJson(levelJson())), isTrue);
    });

    test('a pillar in the beam path blocks it like any wall', () {
      final withPillar = LevelModel.fromJson(
        levelJson(obstacles: [square('p1', 500, 960, shape: 'pillar')]),
      );
      expect(withPillar.obstacles.single.shape, ObstacleShape.pillar);
      expect(crystalLit(withPillar), isFalse);

      final withWall = LevelModel.fromJson(
        levelJson(obstacles: [square('w1', 500, 960)]),
      );
      expect(crystalLit(withWall), isFalse);
    });

    test('a pillar off the beam path does not block it', () {
      final level = LevelModel.fromJson(
        levelJson(obstacles: [square('p1', 500, 400, shape: 'pillar')]),
      );
      expect(crystalLit(level), isTrue);
    });

    test('a decorative pillar is ignored by collision', () {
      final json = square('p1', 500, 960, shape: 'pillar')
        ..['isDecorative'] = true;
      final level = LevelModel.fromJson(levelJson(obstacles: [json]));
      expect(level.obstacles.single.shape, ObstacleShape.pillar);
      expect(crystalLit(level), isTrue);
    });
  });
}
