import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';

enum MirrorType { standard, locked, oneWay, splitter }

class LightSource extends Equatable {
  const LightSource({
    required this.id,
    required this.position,
    required this.directionDegrees,
    this.locked = true,
  });

  final String id;
  final Vec2 position;
  final double directionDegrees;
  final bool locked;

  /// Beam nozzle origin, snapped to the room wall this source mounts on.
  /// Keeps the lateral axis from [position]; pushes onto the wall behind the beam.
  Vec2 mountedOrigin(Vec2 roomBounds, {double inset = 52}) {
    final rad = directionDegrees * math.pi / 180.0;
    final dx = math.cos(rad);
    final dy = math.sin(rad);
    final y = position.y.clamp(inset, roomBounds.y - inset);
    final x = position.x.clamp(inset, roomBounds.x - inset);
    if (dx.abs() >= dy.abs()) {
      if (dx >= 0) return Vec2(inset, y); // left wall → fire right
      return Vec2(roomBounds.x - inset, y); // right wall → fire left
    }
    if (dy >= 0) return Vec2(x, inset); // top wall → fire down
    return Vec2(x, roomBounds.y - inset); // bottom wall → fire up
  }

  factory LightSource.fromJson(Map<String, dynamic> json) {
    final pos = (json['position'] as List<dynamic>).cast<num>();
    return LightSource(
      id: json['id'] as String,
      position: Vec2(pos[0].toDouble(), pos[1].toDouble()),
      directionDegrees: (json['direction'] as num).toDouble(),
      locked: json['locked'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, position, directionDegrees, locked];
}

class MirrorDef extends Equatable {
  const MirrorDef({
    required this.id,
    required this.hingePosition,
    required this.length,
    required this.initialAngle,
    required this.minAngle,
    required this.maxAngle,
    this.snapIncrement = 0,
    this.isLocked = false,
    this.type = MirrorType.standard,
  });

  final String id;
  final Vec2 hingePosition;
  final double length;
  final double initialAngle;
  final double minAngle;
  final double maxAngle;
  final double snapIncrement;
  final bool isLocked;
  final MirrorType type;

  factory MirrorDef.fromJson(Map<String, dynamic> json) {
    final hinge = (json['hingePosition'] as List<dynamic>).cast<num>();
    return MirrorDef(
      id: json['id'] as String,
      hingePosition: Vec2(hinge[0].toDouble(), hinge[1].toDouble()),
      length: (json['length'] as num).toDouble(),
      initialAngle: (json['initialAngle'] as num).toDouble(),
      minAngle: (json['minAngle'] as num?)?.toDouble() ?? 5,
      maxAngle: (json['maxAngle'] as num?)?.toDouble() ?? 175,
      snapIncrement: (json['snapIncrement'] as num?)?.toDouble() ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
      type: _parseMirrorType(json['type'] as String?),
    );
  }

  static MirrorType _parseMirrorType(String? raw) {
    switch (raw) {
      case 'locked':
        return MirrorType.locked;
      case 'oneWay':
        return MirrorType.oneWay;
      case 'splitter':
        return MirrorType.splitter;
      default:
        return MirrorType.standard;
    }
  }

  @override
  List<Object?> get props => [
    id,
    hingePosition,
    length,
    initialAngle,
    minAngle,
    maxAngle,
    snapIncrement,
    isLocked,
    type,
  ];
}

/// How an obstacle should be drawn. Collision is unaffected — the beam always
/// tests the raw polygon edges.
enum ObstacleShape {
  /// A long run of stone, tiled along its dominant axis.
  wall,

  /// A square post where walls meet or a mirror hinge sits.
  pillar,
}

class ObstacleDef extends Equatable {
  const ObstacleDef({
    required this.id,
    required this.polygon,
    this.isDecorative = false,
    this.shape = ObstacleShape.wall,
  });

  final String id;
  final List<Vec2> polygon;
  final bool isDecorative;
  final ObstacleShape shape;

  static ObstacleShape _parseShape(String? raw) {
    return switch (raw) {
      'pillar' => ObstacleShape.pillar,
      _ => ObstacleShape.wall,
    };
  }

  factory ObstacleDef.fromJson(Map<String, dynamic> json) {
    final raw = json['polygon'] as List<dynamic>;
    final polygon = raw.map((p) {
      final pts = (p as List<dynamic>).cast<num>();
      return Vec2(pts[0].toDouble(), pts[1].toDouble());
    }).toList();
    return ObstacleDef(
      id: json['id'] as String,
      polygon: polygon,
      isDecorative: json['isDecorative'] as bool? ?? false,
      shape: _parseShape(json['shape'] as String?),
    );
  }

  @override
  List<Object?> get props => [id, polygon, isDecorative, shape];
}

class TargetCrystalDef extends Equatable {
  const TargetCrystalDef({
    required this.id,
    required this.position,
    this.hitRadius = GameConstants.defaultHitRadius,
    this.groupId = 'g1',
    this.relay = false,
    this.label = '',
  });

  final String id;
  final Vec2 position;
  final double hitRadius;
  final String groupId;

  /// Beam passes through without stopping (still marks lit).
  final bool relay;
  final String label;

  factory TargetCrystalDef.fromJson(Map<String, dynamic> json) {
    final pos = (json['position'] as List<dynamic>).cast<num>();
    return TargetCrystalDef(
      id: json['id'] as String,
      position: Vec2(pos[0].toDouble(), pos[1].toDouble()),
      hitRadius:
          (json['hitRadius'] as num?)?.toDouble() ??
          GameConstants.defaultHitRadius,
      groupId: json['groupId'] as String? ?? 'g1',
      relay: json['relay'] as bool? ?? false,
      label: json['label'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, position, hitRadius, groupId, relay, label];
}

class LevelMetadata extends Equatable {
  const LevelMetadata({
    this.objective = '',
    this.hints = const [],
    this.deviceLabels = const {},
  });

  final String objective;
  final List<String> hints;
  final Map<String, String> deviceLabels;

  factory LevelMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LevelMetadata();
    final rawHints = json['hints'] as List<dynamic>? ?? [];
    final rawLabels = json['deviceLabels'] as Map<String, dynamic>? ?? {};
    return LevelMetadata(
      objective: json['objective'] as String? ?? '',
      hints: rawHints.map((e) => e as String).toList(),
      deviceLabels: rawLabels.map((k, v) => MapEntry(k, v as String)),
    );
  }

  @override
  List<Object?> get props => [objective, hints, deviceLabels];
}

class CrystalGroupDef extends Equatable {
  const CrystalGroupDef({required this.groupId, required this.requiredCount});

  final String groupId;
  final int requiredCount;

  factory CrystalGroupDef.fromJson(Map<String, dynamic> json) {
    return CrystalGroupDef(
      groupId: json['groupId'] as String,
      requiredCount: (json['requiredCount'] as num?)?.round() ?? 1,
    );
  }

  @override
  List<Object?> get props => [groupId, requiredCount];
}

class StarThresholds extends Equatable {
  const StarThresholds({
    this.threeStarMoveCount = 5,
    this.threeStarTimeSeconds = 60,
  });

  final int threeStarMoveCount;
  final int threeStarTimeSeconds;

  factory StarThresholds.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StarThresholds();
    return StarThresholds(
      // Authored as `77` or `77.5` depending on the generator, and a cast
      // failure here fails the whole level load.
      threeStarMoveCount: (json['threeStarMoveCount'] as num?)?.round() ?? 5,
      threeStarTimeSeconds:
          (json['threeStarTimeSeconds'] as num?)?.round() ?? 60,
    );
  }

  @override
  List<Object?> get props => [threeStarMoveCount, threeStarTimeSeconds];
}

class IntendedSolution extends Equatable {
  const IntendedSolution({
    required this.mirrorAngles,
    this.toleranceDegrees = GameConstants.angleToleranceDegrees,
  });

  final Map<String, double> mirrorAngles;
  final double toleranceDegrees;

  factory IntendedSolution.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const IntendedSolution(mirrorAngles: {});
    }
    final raw = json['mirrorAngles'] as Map<String, dynamic>? ?? {};
    return IntendedSolution(
      mirrorAngles: raw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      toleranceDegrees:
          (json['toleranceDegrees'] as num?)?.toDouble() ??
          GameConstants.angleToleranceDegrees,
    );
  }

  @override
  List<Object?> get props => [mirrorAngles, toleranceDegrees];
}

class LevelModel extends Equatable {
  const LevelModel({
    required this.levelId,
    required this.chapterId,
    required this.roomBounds,
    required this.lightSources,
    required this.mirrors,
    required this.obstacles,
    required this.targetCrystals,
    required this.crystalGroups,
    required this.intendedSolution,
    required this.starThresholds,
    this.schemaVersion = 1,
    this.levelIndex = 1,
    this.title = '',
    this.requiredMirrorCount,
    this.metadata = const LevelMetadata(),
  });

  final String levelId;
  final String chapterId;
  final int schemaVersion;
  final Vec2 roomBounds;
  final List<LightSource> lightSources;
  final List<MirrorDef> mirrors;
  final List<ObstacleDef> obstacles;
  final List<TargetCrystalDef> targetCrystals;
  final List<CrystalGroupDef> crystalGroups;
  final IntendedSolution intendedSolution;
  final StarThresholds starThresholds;
  final int levelIndex;
  final String title;

  /// How many of the board's mirrors the beam must route through before it
  /// reaches a crystal (null = no constraint). Distinct mirrors, not bounces:
  /// the objective every level states is to use them all.
  final int? requiredMirrorCount;
  final LevelMetadata metadata;

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    final bounds = json['roomBounds'] as Map<String, dynamic>;
    return LevelModel(
      levelId: json['levelId'] as String,
      chapterId: json['chapterId'] as String,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      roomBounds: Vec2(
        (bounds['width'] as num).toDouble(),
        (bounds['height'] as num).toDouble(),
      ),
      lightSources: (json['lightSources'] as List<dynamic>)
          .map((e) => LightSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      mirrors: (json['mirrors'] as List<dynamic>)
          .map((e) => MirrorDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      obstacles: (json['obstacles'] as List<dynamic>? ?? [])
          .map((e) => ObstacleDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      targetCrystals: (json['targetCrystals'] as List<dynamic>)
          .map((e) => TargetCrystalDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      crystalGroups:
          (json['crystalGroups'] as List<dynamic>? ??
                  [
                    {'groupId': 'g1', 'requiredCount': 1},
                  ])
              .map((e) => CrystalGroupDef.fromJson(e as Map<String, dynamic>))
              .toList(),
      intendedSolution: IntendedSolution.fromJson(
        json['intendedSolution'] as Map<String, dynamic>?,
      ),
      starThresholds: StarThresholds.fromJson(
        json['starThresholds'] as Map<String, dynamic>?,
      ),
      levelIndex:
          json['levelIndex'] as int? ??
          int.tryParse((json['levelId'] as String).split('_').last) ??
          1,
      title: json['title'] as String? ?? '',
      requiredMirrorCount: (json['requiredMirrorBounces'] as num?)?.round(),
      metadata: LevelMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>?,
      ),
    );
  }

  @override
  List<Object?> get props => [
    levelId,
    chapterId,
    schemaVersion,
    roomBounds,
    lightSources,
    mirrors,
    obstacles,
    targetCrystals,
    crystalGroups,
    intendedSolution,
    starThresholds,
    levelIndex,
    title,
    requiredMirrorCount,
    metadata,
  ];
}
