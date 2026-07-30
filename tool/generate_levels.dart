import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'levels_catalog.dart';

/// Standalone level generator — crystals placed on the reflected ray so
/// intended mirror angles are solvable by construction.
/// Run from project root: dart run tool/generate_levels.dart
void main() {
  final ch1Levels = <Map<String, dynamic>>[];
  for (var i = 1; i <= 20; i++) {
    final id = 'ch1_${i.toString().padLeft(3, '0')}';
    ch1Levels.add(_ch1(i, id));
  }

  final ch2Levels = <Map<String, dynamic>>[];
  for (var i = 1; i <= 30; i++) {
    final id = 'ch2_${i.toString().padLeft(3, '0')}';
    ch2Levels.add(_ch2(i, id));
  }

  writeChapterLevels('ch1', ch1Levels);
  writeChapterLevels('ch2', ch2Levels);
  stdout.writeln(
    'OK: wrote ${ch1Levels.length} + ${ch2Levels.length} levels to '
    'assets/levels/levels.json',
  );
}

Map<String, dynamic> _ch1(int index, String id) {
  const roomW = 1080.0;
  const roomH = 1920.0;

  final hinge = V(540, 900);
  final mirrorAngle = 35.0 + index * 3.5;
  final length = 160.0;
  final incomingDeg = 0.0; // from left
  final light = hinge - dir(incomingDeg) * (280 + index * 5.0);
  final reflected = reflect(dir(incomingDeg), faceNormal(mirrorAngle, dir(incomingDeg)));
  final crystal = hinge + reflected * (420 + (index % 5) * 30.0);

  // Keep crystal in bounds
  final c = V(
    crystal.x.clamp(100, roomW - 100),
    crystal.y.clamp(100, roomH - 100),
  );

  final obstacles = <Map<String, dynamic>>[];
  if (index >= 8) {
    // Place block away from intended beam corridor (bottom-left).
    obstacles.add({
      'id': 'o1',
      'polygon': [
        [80, 1500],
        [220, 1500],
        [220, 1700],
        [80, 1700],
      ],
      'isDecorative': false,
    });
  }
  if (index >= 14) {
    obstacles.add({
      'id': 'o2',
      'polygon': [
        [860, 200],
        [1000, 200],
        [1000, 360],
        [860, 360],
      ],
      'isDecorative': false,
    });
  }

  final initial = (mirrorAngle - 25).clamp(5.0, 170.0);

  return _level(
    id: id,
    chapterId: 'ch1',
    index: index,
    title: 'Lab $index',
    light: light,
    lightDir: incomingDeg,
    mirrors: [
      _mirror('m1', hinge, length, initial, mirrorAngle),
    ],
    solution: {'m1': mirrorAngle},
    crystal: c,
    obstacles: obstacles,
    threeMoves: index <= 5 ? 2 : 3,
    threeTime: 30 + index * 2,
  );
}

Map<String, dynamic> _ch2(int index, String id) {
  const roomW = 1080.0;
  const roomH = 1920.0;

  final m1 = V(360, 520);
  final m1Angle = 45.0 + (index % 8) * 4;
  final m2 = V(760, 1180);
  final m2Angle = 130.0 + (index % 6) * 3;

  final incomingDeg = 0.0;
  final light = m1 - dir(incomingDeg) * 260;
  final r1 = reflect(dir(incomingDeg), faceNormal(m1Angle, dir(incomingDeg)));
  // Travel from m1 toward m2 roughly
  final mid = m1 + r1 * m1.distanceTo(m2) * 0.55;
  // Re-aim: place m2 on path, then second reflection to crystal
  final toM2 = (m2 - m1).normalized();
  // Use computed r1; crystal from m2
  final r2 = reflect(r1, faceNormal(m2Angle, r1));
  final crystal = m2 + r2 * (340 + (index % 7) * 20.0);
  final c = V(crystal.x.clamp(100, roomW - 100), crystal.y.clamp(100, roomH - 100));

  final obstacles = <Map<String, dynamic>>[
    {
      'id': 'wall1',
      'polygon': [
        [40, 900],
        [200, 900],
        [200, 1100],
        [40, 1100],
      ],
      'isDecorative': false,
    },
  ];
  if (index >= 10) {
    obstacles.add({
      'id': 'wall2',
      'polygon': [
        [880, 600],
        [1040, 600],
        [1040, 780],
        [880, 780],
      ],
      'isDecorative': false,
    });
  }

  final mirrors = [
    _mirror('m1', m1, 150, 20, m1Angle),
    _mirror(
      'm2',
      m2,
      160,
      90,
      m2Angle,
      snap: index >= 15 ? 15.0 : 0,
    ),
  ];
  if (index >= 25) {
    mirrors.add(
      _mirror('m3', V(200, 1500), 120, 60, 60, locked: true),
    );
  }

  return _level(
    id: id,
    chapterId: 'ch2',
    index: index,
    title: 'House $index',
    light: light,
    lightDir: incomingDeg,
    mirrors: mirrors,
    solution: {'m1': m1Angle, 'm2': m2Angle},
    crystal: c,
    obstacles: obstacles,
    threeMoves: 4 + index ~/ 10,
    threeTime: 45 + index,
  );
}

Map<String, dynamic> _level({
  required String id,
  required String chapterId,
  required int index,
  required String title,
  required V light,
  required double lightDir,
  required List<Map<String, dynamic>> mirrors,
  required Map<String, double> solution,
  required V crystal,
  required List<Map<String, dynamic>> obstacles,
  required int threeMoves,
  required int threeTime,
}) {
  return {
    'levelId': id,
    'chapterId': chapterId,
    'schemaVersion': 1,
    'levelIndex': index,
    'title': title,
    'roomBounds': {'width': 1080, 'height': 1920},
    'lightSources': [
      {
        'id': 'ls1',
        'position': [light.x, light.y],
        'direction': lightDir,
        'locked': true,
      }
    ],
    'mirrors': mirrors,
    'obstacles': obstacles,
    'targetCrystals': [
      {
        'id': 'c1',
        'position': [crystal.x, crystal.y],
        'hitRadius': 44,
        'groupId': 'g1',
      }
    ],
    'crystalGroups': [
      {'groupId': 'g1', 'requiredCount': 1},
    ],
    'doorPortals': [],
    'intendedSolution': {
      'mirrorAngles': solution,
      'toleranceDegrees': 5.0,
    },
    'starThresholds': {
      'threeStarMoveCount': threeMoves,
      'threeStarTimeSeconds': threeTime,
    },
    'metadata': {
      'designer': 'generator',
      'difficultyBand': chapterId,
      'newConceptsIntroduced': <String>[],
    },
  };
}

Map<String, dynamic> _mirror(
  String id,
  V hinge,
  double length,
  double initial,
  double intended, {
  double snap = 0,
  bool locked = false,
}) {
  return {
    'id': id,
    'hingePosition': [hinge.x, hinge.y],
    'length': length,
    'initialAngle': initial,
    'minAngle': 5.0,
    'maxAngle': 175.0,
    'snapIncrement': snap,
    'isLocked': locked,
    'type': locked ? 'locked' : 'standard',
  };
}

class V {
  V(this.x, this.y);
  final double x;
  final double y;
  V operator +(V o) => V(x + o.x, y + o.y);
  V operator -(V o) => V(x - o.x, y - o.y);
  V operator *(double s) => V(x * s, y * s);
  double get length => math.sqrt(x * x + y * y);
  V normalized() {
    final l = length;
    if (l < 1e-9) return V(0, 0);
    return V(x / l, y / l);
  }

  double distanceTo(V o) => (this - o).length;
  double dot(V o) => x * o.x + y * o.y;
}

V dir(double deg) {
  final r = deg * math.pi / 180;
  return V(math.cos(r), math.sin(r));
}

V normal(double mirrorDeg) => dir(mirrorDeg + 90);

V faceNormal(double mirrorDeg, V incoming) {
  final n = normal(mirrorDeg).normalized();
  return n.dot(incoming) > 0 ? V(-n.x, -n.y) : n;
}

V reflect(V d, V n) {
  final dn = d.dot(n);
  return d - n * (2 * dn);
}
