import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'levels_catalog.dart';

/// Chapter 1 — Stone Castle: 10 thinking puzzles (grid walls, one win crystal).
/// Run: dart run tool/generate_unique_ch1.dart
void main() {
  final levels = <Map<String, dynamic>>[
    _level1(),
    _level2(),
    _level3(),
    _level4(),
    _level5(),
    _level6(),
    _level7(),
    _level8(),
    _level9(),
    _level10(),
  ];

  var failures = 0;
  for (final level in levels) {
    final id = level['levelId'] as String;
    if (!_validate(level)) {
      failures++;
      stderr.writeln('FAIL validate: $id');
    } else {
      stdout.writeln('OK  $id — ${level['title']}');
    }
  }

  if (failures > 0) exit(1);

  writeChapterLevels('ch1', levels);
  stdout.writeln(
    'Wrote ${levels.length} ch1 levels to assets/levels/levels.json',
  );
}

// ---------------------------------------------------------------------------
// Grid — 10×10 stone board (matches reference art)
// ---------------------------------------------------------------------------

const _gc = 10;
const _gr = 10;

// ---------------------------------------------------------------------------
// Levels — increasing mirrors, wall mazes, relays on harder stages
// ---------------------------------------------------------------------------

/// L1 — tutorial: one mirror, wall blocks the straight tunnel
Map<String, dynamic> _level1() {
  const a = 45.0;
  return _pack(
    index: 1,
    title: 'First Bounce',
    objective: 'Learn reflection: aim the mirror so the beam hits the crystal.',
    hints: [
      'The sconce fires straight across the hall.',
      'Stone blocks a direct shot — use the mirror.',
      'About 45° sends light down to the crystal.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 4)), 0)],
    mirrors: [_mirror('m1', _g(3, 4), 145, initial: 22, solution: a)],
    solution: {'m1': a},
    crystal: _g(3, 7),
    walls: _cells([[4, 4], [5, 4], [6, 4]]),
    moves: 3,
    time: 50,
    concepts: ['reflection'],
  );
}

/// L2 — rampart wall; mirror must sit past the stone bar
Map<String, dynamic> _level2() {
  const a = 45.0;
  return _pack(
    index: 2,
    title: 'The Rampart',
    objective: 'A rampart blocks the tunnel — route the beam past it, then down.',
    hints: [
      'You cannot shine through the rampart.',
      'Place the mirror east of the wall.',
      'One bounce drops the beam on the crystal.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 3)), 0)],
    mirrors: [_mirror('m1', _g(7, 3), 145, initial: 16, solution: a)],
    solution: {'m1': a},
    crystal: _g(7, 8),
    walls: _cells([
      [1, 5],
      [2, 5],
      [3, 5],
      [4, 5],
      [5, 5],
      [6, 5],
    ]),
    moves: 3,
    time: 55,
    concepts: ['wall_block'],
  );
}

/// L3 — zigzag halls (reference layout): 3 mirrors, maze walls
Map<String, dynamic> _level3() {
  const a1 = 45.0;
  const a2 = 80.0;
  const a3 = 35.0;
  return _pack(
    index: 3,
    title: 'Stone Crystal',
    objective: 'Direct the beam from the source to activate the crystal.',
    hints: [
      'Trace the full path before you rotate any mirror.',
      'Right, then down, then diagonally into the lower hall.',
      'The last mirror aims into the crystal chamber.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 2)), 0)],
    mirrors: [
      _mirror('m1', _g(5, 2), 145, initial: 18, solution: a1),
      _mirror('m2', _g(5, 5), 145, initial: 108, solution: a2),
      _mirror('m3', _g(6, 7), 145, initial: 125, solution: a3),
    ],
    solution: {'m1': a1, 'm2': a2, 'm3': a3},
    crystal: _g(8, 7),
    walls: _cells([
      [6, 0],
      [6, 1],
      [6, 2],
      [7, 2],
      [7, 3],
      [7, 4],
      [8, 4],
      [2, 5],
      [3, 5],
      [2, 6],
      [2, 7],
      [5, 8],
      [6, 8],
      [7, 8],
      [8, 8],
    ]),
    moves: 5,
    time: 90,
    concepts: ['triple_mirror', 'wall_maze'],
  );
}

/// L4 — winding corridors (reference): 4 mirrors serpentine through walls
Map<String, dynamic> _level4() {
  final hinges = [_g(6, 3), _g(6, 6), _g(1, 7), _g(7, 8)];
  final crystal = _g(8, 8);
  final angles = _solveChain(hinges, dir(0), crystal);
  final solution = {
    'm1': angles[0],
    'm2': angles[1],
    'm3': angles[2],
    'm4': angles[3],
  };

  return _pack(
    index: 4,
    title: 'Winding Halls',
    objective:
        'Thread the beam through the castle corridors to the distant crystal.',
    hints: [
      'Think before you rotate — every mirror has a purpose.',
      'The halls force a long S-shaped route.',
      'Four reflections weave through the stone maze.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 3)), 0)],
    mirrors: [
      _mirror('m1', hinges[0], 145, initial: 18, solution: solution['m1']!),
      _mirror('m2', hinges[1], 145, initial: 105, solution: solution['m2']!),
      _mirror('m3', hinges[2], 145, initial: 115, solution: solution['m3']!),
      _mirror('m4', hinges[3], 145, initial: 130, solution: solution['m4']!),
    ],
    solution: solution,
    crystal: crystal,
    walls: _cells([
      [1, 4],
      [1, 5],
      [1, 6],
      [1, 7],
      [2, 4],
      [8, 3],
      [8, 4],
      [8, 5],
      [8, 6],
    ]),
    decor: [[5, 4]],
    moves: 6,
    time: 120,
    concepts: ['serpentine', 'four_mirror'],
    difficulty: 'hard',
    reflectionsRequired: 4,
  );
}

/// L5 — relay gate (reference): beam must pass relay + narrow slot
Map<String, dynamic> _level5() {
  final hinges = [_g(4, 3), _g(4, 5), _g(6, 5), _g(7, 2)];
  final crystal = _g(8, 2);
  final relay = _g(4, 4);
  final angles = _solveChain(hinges, dir(0), crystal);
  final solution = {
    'm1': angles[0],
    'm2': angles[1],
    'm3': angles[2],
    'm4': angles[3],
  };

  return _pack(
    index: 5,
    title: 'Relay Gate',
    objective:
        'Thread the beam through the castle corridors to the distant crystal.',
    hints: [
      'Plan the path first — every device must activate in order.',
      'Light must pass through the relay node.',
      'The narrow slot only opens one lane east.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 3)), 0)],
    mirrors: [
      _mirror('m1', hinges[0], 145, initial: 18, solution: solution['m1']!),
      _mirror('m2', hinges[1], 145, initial: 108, solution: solution['m2']!),
      _mirror('m3', hinges[2], 145, initial: 115, solution: solution['m3']!),
      _mirror('m4', hinges[3], 145, initial: 125, solution: solution['m4']!),
    ],
    solution: solution,
    crystal: crystal,
    relays: [relay],
    relayLabels: {'relay0': 'Relay'},
    walls: [
      ..._cells([
        [2, 5],
        [2, 6],
        [2, 7],
        [3, 5],
        [5, 5],
        [6, 5],
        [5, 7],
        [6, 7],
        [7, 4],
        [7, 6],
        [8, 5],
        [8, 6],
        [8, 7],
        [8, 8],
        [9, 5],
        [9, 6],
        [9, 7],
      ]),
    ],
    decor: [[8, 8]],
    moves: 7,
    time: 150,
    concepts: ['relay', 'slot_gate'],
    difficulty: 'hard',
    reflectionsRequired: 4,
  );
}

/// L6 — ceiling sconce through funnel walls
Map<String, dynamic> _level6() {
  const a = 45.0;
  final m1 = _g(5, 5);
  final c = _g(8, 5);

  return _pack(
    index: 6,
    title: 'Ceiling Port',
    objective: 'Light falls from above — steer it through the gap in the walls.',
    hints: [
      'This sconce hangs from the top wall.',
      'Walls funnel the beam — only one gap is open.',
      'Bank the mirror to send light across to the crystal.',
    ],
    lights: [_light('ls1', V(_gridCx(_gc, 5), 160), 90)],
    mirrors: [_mirror('m1', m1, 150, initial: 28, solution: a)],
    solution: {'m1': a},
    crystal: c,
    walls: _cells([
      [2, 4],
      [2, 5],
      [2, 6],
    ]),
    moves: 4,
    time: 75,
    concepts: ['top_emitter', 'funnel'],
  );
}

/// L7 — exactly three mirror bounces through a barred hall
Map<String, dynamic> _level7() {
  final hinges = [_g(2, 2), _g(2, 5), _g(7, 5)];
  final crystal = _g(7, 8);
  final angles = _solveChain(hinges, dir(0), crystal);

  return _pack(
    index: 7,
    title: 'Triple Echo',
    objective: 'The crystal only accepts light that bounced exactly three times.',
    hints: [
      'Count every mirror the beam touches.',
      'Shortcuts that skip mirrors will not count.',
      'Down, across, then down again — three bounces.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 2)), 0)],
    mirrors: [
      _mirror('m1', hinges[0], 145, initial: 18, solution: angles[0]),
      _mirror('m2', hinges[1], 145, initial: 100, solution: angles[1]),
      _mirror('m3', hinges[2], 145, initial: 110, solution: angles[2]),
    ],
    solution: {'m1': angles[0], 'm2': angles[1], 'm3': angles[2]},
    crystal: crystal,
    walls: _cells([
      [4, 3],
      [5, 3],
      [6, 3],
      [4, 4],
      [6, 4],
    ]),
    requiredBounces: 3,
    moves: 6,
    time: 120,
    concepts: ['exact_bounces'],
    reflectionsRequired: 3,
  );
}

/// L8 — needle slot between parallel walls
Map<String, dynamic> _level8() {
  final hinges = [_g(3, 4), _g(6, 7)];
  final crystal = _g(8, 7);
  final angles = _solveChain(hinges, dir(0), crystal);

  return _pack(
    index: 8,
    title: 'The Needle Slot',
    objective: 'Only a thin gap between the walls — align the beam precisely.',
    hints: [
      'Wide shots hit stone; only the center gap is open.',
      'Drop the beam, then bank it through the slot.',
      'Stay between the parallel walls.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 4)), 0)],
    mirrors: [
      _mirror('m1', hinges[0], 145, initial: 18, solution: angles[0]),
      _mirror('m2', hinges[1], 145, initial: 100, solution: angles[1]),
    ],
    solution: {'m1': angles[0], 'm2': angles[1]},
    crystal: crystal,
    walls: [
      ..._cells([
        [5, 5],
        [5, 6],
        [5, 7],
        [5, 8],
        [5, 9],
        [7, 5],
        [7, 6],
        [7, 7],
        [7, 8],
        [7, 9],
      ]),
    ],
    moves: 5,
    time: 100,
    concepts: ['narrow_gap'],
  );
}

/// L9 — rusty hinge: tight angle arc in a walled alcove
Map<String, dynamic> _level9() {
  const a = 45.0;
  return _pack(
    index: 9,
    title: 'Rusty Hinge',
    objective: 'This mirror barely moves — find the only legal angle.',
    hints: [
      'The hinge is nearly seized; only a small arc is allowed.',
      'Snap clicks help — try each step carefully.',
      'About 45° threads the alcove to the crystal.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 5)), 0)],
    mirrors: [
      _mirror(
        'm1',
        _g(5, 5),
        145,
        initial: 38,
        solution: a,
        minA: 38,
        maxA: 52,
        snap: 5,
      ),
    ],
    solution: {'m1': a},
    crystal: _g(8, 5),
    walls: _cells([
      [3, 4],
      [3, 6],
      [3, 7],
      [4, 4],
      [4, 7],
    ]),
    moves: 5,
    time: 100,
    concepts: ['angle_limits'],
  );
}

/// L10 — master: locked mirror + relay + exact four bounces
Map<String, dynamic> _level10() {
  const a1 = 45.0;
  const lockedA = 45.0;
  final m1 = _g(3, 3);
  final locked = m1 +
      reflect(dir(0), faceNormal(a1, dir(0))).normalized() *
          (_gridCy(_gr, 6) - _gridCy(_gr, 3));
  final dLocked =
      reflect(dir(0), faceNormal(lockedA, dir(0))).normalized();
  final crystal = _g(8, 3);
  final relay = _g(3, 5);
  final tailAngles = _solveChain(
    [_g(7, 3)],
    dLocked,
    crystal,
  );

  return _pack(
    index: 10,
    title: 'Grand Atrium',
    objective: 'Master the atrium: relay, fixed glass, and three reflections.',
    hints: [
      'Aim the first mirror — the second is bolted in place.',
      'Activate the relay before the final crystal.',
      'Three mirror hits, one perfect route.',
    ],
    lights: [_light('ls1', V(160, _gridCy(_gr, 3)), 0)],
    mirrors: [
      _mirror('m1', m1, 145, initial: 18, solution: a1),
      _mirror(
        'm_locked',
        locked,
        150,
        initial: lockedA,
        solution: lockedA,
        locked: true,
      ),
      _mirror('m2', _g(7, 3), 145, initial: 108, solution: tailAngles[0]),
    ],
    solution: {
      'm1': a1,
      'm_locked': lockedA,
      'm2': tailAngles[0],
    },
    crystal: crystal,
    relays: [relay],
    relayLabels: {'relay0': 'Relay'},
    walls: _cells([
      [5, 2],
      [5, 3],
      [5, 4],
      [2, 6],
      [2, 7],
      [3, 7],
      [8, 5],
      [8, 6],
      [8, 7],
    ]),
    requiredBounces: 3,
    moves: 7,
    time: 160,
    concepts: ['master'],
    difficulty: 'hard',
    reflectionsRequired: 3,
  );
}

// ---------------------------------------------------------------------------
// Pack helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _pack({
  required int index,
  required String title,
  required String objective,
  required List<String> hints,
  required List<Map<String, dynamic>> lights,
  required List<Map<String, dynamic>> mirrors,
  required Map<String, double> solution,
  required V crystal,
  required List<Map<String, dynamic>> walls,
  required int moves,
  required int time,
  required List<String> concepts,
  List<V>? relays,
  Map<String, String>? relayLabels,
  List<List<int>>? decor,
  int? requiredBounces,
  String? difficulty,
  int? reflectionsRequired,
}) {
  final id = 'ch1_${index.toString().padLeft(3, '0')}';
  final crystals = <Map<String, dynamic>>[];
  final groups = <Map<String, dynamic>>[];
  final deviceLabels = <String, String>{...?relayLabels};

  if (relays != null && relays.isNotEmpty) {
    for (var i = 0; i < relays.length; i++) {
      final rid = 'relay$i';
      crystals.add({
        'id': rid,
        'position': [relays[i].x, relays[i].y],
        'hitRadius': 38,
        'groupId': 'relay',
        'relay': true,
        'label': deviceLabels[rid] ?? 'Relay',
      });
    }
    groups.add({'groupId': 'relay', 'requiredCount': relays.length});
  }

  crystals.add({
    'id': 'c1',
    'position': [crystal.x, crystal.y],
    'hitRadius': 44,
    'groupId': 'g1',
  });
  groups.add({'groupId': 'g1', 'requiredCount': 1});

  final obstacles = <Map<String, dynamic>>[...walls];
  if (decor != null) {
    for (var i = 0; i < decor.length; i++) {
      obstacles.add(
        _cellWall('decor$i', _gc, _gr, decor[i][0], decor[i][1],
            decorative: true),
      );
    }
  }

  final level = <String, dynamic>{
    'levelId': id,
    'chapterId': 'ch1',
    'schemaVersion': 1,
    'levelIndex': index,
    'title': title,
    'roomBounds': {'width': 1080, 'height': 1920},
    'lightSources': lights,
    'mirrors': mirrors,
    'obstacles': obstacles,
    'targetCrystals': crystals,
    'crystalGroups': groups,
    'doorPortals': [],
    'intendedSolution': {
      'mirrorAngles': solution,
      'toleranceDegrees': 5.0,
    },
    'starThresholds': {
      'threeStarMoveCount': moves,
      'threeStarTimeSeconds': time,
    },
    'metadata': {
      'designer': 'stone_castle_ch1',
      'difficultyBand': 'ch1',
      'newConceptsIntroduced': concepts,
      'objective': objective,
      'hints': hints,
      if (difficulty != null) 'difficulty': difficulty,
      if (reflectionsRequired != null)
        'reflectionsRequired': reflectionsRequired,
      if (deviceLabels.isNotEmpty) 'deviceLabels': deviceLabels,
    },
  };
  if (requiredBounces != null) {
    level['requiredMirrorBounces'] = requiredBounces;
  }
  return level;
}

Map<String, dynamic> _light(String id, V pos, double dirDeg) => {
      'id': id,
      'position': [pos.x, pos.y],
      'direction': dirDeg,
      'locked': true,
    };

Map<String, dynamic> _mirror(
  String id,
  V hinge,
  double length, {
  required double initial,
  required double solution,
  bool locked = false,
  double minA = 5,
  double maxA = 175,
  double snap = 0,
}) {
  return {
    'id': id,
    'hingePosition': [hinge.x, hinge.y],
    'length': length,
    'initialAngle': initial.clamp(minA, maxA),
    'minAngle': minA,
    'maxAngle': maxA,
    'snapIncrement': snap,
    'isLocked': locked,
    'type': locked ? 'locked' : 'standard',
  };
}

/// Horizontal stone wall (thick bar).
Map<String, dynamic> _wallH(String id, double x0, double x1, double y, double t) =>
    {
      'id': id,
      'polygon': [
        [x0, y],
        [x1, y],
        [x1, y + t],
        [x0, y + t],
      ],
      'isDecorative': false,
    };

/// Vertical stone wall (thick bar).
Map<String, dynamic> _wallV(String id, double x, double y0, double y1, double t) =>
    {
      'id': id,
      'polygon': [
        [x, y0],
        [x + t, y0],
        [x + t, y1],
        [x, y1],
      ],
      'isDecorative': false,
    };

double _gridCx(int cols, int col) => (col + 0.5) * 1080 / cols;

double _gridCy(int rows, int row) => (row + 0.5) * 1920 / rows;

V _g(int col, int row) => V(_gridCx(_gc, col), _gridCy(_gr, row));

List<Map<String, dynamic>> _cells(List<List<int>> cells) => [
      for (var i = 0; i < cells.length; i++)
        _cellWall('w$i', _gc, _gr, cells[i][0], cells[i][1]),
    ];

Map<String, dynamic> _cellWall(
  String id,
  int cols,
  int rows,
  int col,
  int row, {
  bool decorative = false,
}) {
  final cw = 1080 / cols;
  final ch = 1920 / rows;
  final x = col * cw;
  final y = row * ch;
  return {
    'id': id,
    'polygon': [
      [x, y],
      [x + cw, y],
      [x + cw, y + ch],
      [x, y + ch],
    ],
    'isDecorative': decorative,
  };
}

V _between(V from, V to) => (to - from).normalized();

List<double> _solveChain(List<V> hinges, V incoming, V target) {
  var d = incoming.normalized();
  final out = <double>[];
  for (var i = 0; i < hinges.length; i++) {
    final aim = i < hinges.length - 1
        ? _between(hinges[i], hinges[i + 1])
        : _between(hinges[i], target);
    final a = _solveAngle(d, aim);
    if (a == null) {
      throw StateError('no angle for hinge $i aim=$aim from $d');
    }
    out.add(a);
    d = reflect(d, faceNormal(a, d)).normalized();
  }
  return out;
}

double? _solveAngle(V incoming, V outgoing) {
  final i = incoming.normalized();
  final o = outgoing.normalized();
  for (double a = 5; a < 175; a += 0.25) {
    final r = reflect(i, faceNormal(a, i)).normalized();
    if (r.dot(o) > 0.9995) return a;
  }
  return null;
}

V _clamp(V p) => V(p.x.clamp(100, 980), p.y.clamp(100, 1820));

// ---------------------------------------------------------------------------
// Math
// ---------------------------------------------------------------------------

class V {
  const V(this.x, this.y);
  final double x;
  final double y;
  V operator +(V o) => V(x + o.x, y + o.y);
  V operator -(V o) => V(x - o.x, y - o.y);
  V operator *(double s) => V(x * s, y * s);
  double get length => math.sqrt(x * x + y * y);
  V normalized() {
    final l = length;
    if (l < 1e-9) return const V(0, 0);
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

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

bool _validate(Map<String, dynamic> level) {
  final room = level['roomBounds'] as Map<String, dynamic>;
  final roomW = (room['width'] as num).toDouble();
  final roomH = (room['height'] as num).toDouble();

  final solution =
      (level['intendedSolution'] as Map)['mirrorAngles'] as Map<String, dynamic>;
  final mirrors = (level['mirrors'] as List).cast<Map<String, dynamic>>();
  final angles = <String, double>{
    for (final m in mirrors) m['id'] as String: (m['initialAngle'] as num).toDouble(),
    for (final e in solution.entries) e.key: (e.value as num).toDouble(),
  };

  final lit = <String>{};
  var mirrorHits = 0;
  for (final ls in (level['lightSources'] as List).cast<Map<String, dynamic>>()) {
    final tip = _mountedOrigin(
      (ls['position'] as List).cast<num>(),
      (ls['direction'] as num).toDouble(),
      roomW,
      roomH,
    );
    mirrorHits += _trace(
      level: level,
      origin: tip,
      direction: dir((ls['direction'] as num).toDouble()),
      angles: angles,
      lit: lit,
      roomW: roomW,
      roomH: roomH,
    );
  }

  if (!lit.contains('c1')) {
    stderr.writeln('  crystal c1 not lit lit=$lit');
    return false;
  }

  final winCrystals =
      (level['targetCrystals'] as List).cast<Map<String, dynamic>>()
          .where((c) => c['relay'] != true);
  if (winCrystals.length != 1) {
    stderr.writeln('  expected 1 win crystal, got ${winCrystals.length}');
    return false;
  }

  for (final g in (level['crystalGroups'] as List).cast<Map<String, dynamic>>()) {
    final gid = g['groupId'] as String;
    final need = g['requiredCount'] as int;
    final members = (level['targetCrystals'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['groupId'] == gid)
        .map((c) => c['id'] as String);
    final got = members.where(lit.contains).length;
    if (got < need) {
      stderr.writeln('  group $gid need $need got $got lit=$lit');
      return false;
    }
  }

  final required = level['requiredMirrorBounces'] as int?;
  if (required != null && mirrorHits != required) {
    stderr.writeln('  bounce fail hits=$mirrorHits need=$required');
    return false;
  }

  final initialAngles = <String, double>{
    for (final m in mirrors) m['id'] as String: (m['initialAngle'] as num).toDouble(),
  };
  final lit0 = <String>{};
  var hits0 = 0;
  for (final ls in (level['lightSources'] as List).cast<Map<String, dynamic>>()) {
    final tip = _mountedOrigin(
      (ls['position'] as List).cast<num>(),
      (ls['direction'] as num).toDouble(),
      roomW,
      roomH,
    );
    hits0 += _trace(
      level: level,
      origin: tip,
      direction: dir((ls['direction'] as num).toDouble()),
      angles: initialAngles,
      lit: lit0,
      roomW: roomW,
      roomH: roomH,
    );
  }
  if (lit0.contains('c1') && (required == null || hits0 != required)) {
    stderr.writeln('  already solved at initial');
    return false;
  }
  return true;
}

V _mountedOrigin(List<num> pos, double dirDeg, double roomW, double roomH) {
  const inset = 52.0;
  final rad = dirDeg * math.pi / 180;
  final dx = math.cos(rad);
  final dy = math.sin(rad);
  final y = pos[1].toDouble().clamp(inset, roomH - inset);
  final x = pos[0].toDouble().clamp(inset, roomW - inset);
  if (dx.abs() >= dy.abs()) {
    if (dx >= 0) return V(inset, y);
    return V(roomW - inset, y);
  }
  if (dy >= 0) return V(x, inset);
  return V(x, roomH - inset);
}

int _trace({
  required Map<String, dynamic> level,
  required V origin,
  required V direction,
  required Map<String, double> angles,
  required Set<String> lit,
  required double roomW,
  required double roomH,
}) {
  var pos = origin;
  var d = direction.normalized();
  var mirrorHits = 0;
  for (var bounce = 0; bounce < 24; bounce++) {
    final hit = _nearestHit(level, pos, d, angles, roomW, roomH);
    if (hit == null) return mirrorHits;
    if (hit.kind == 'crystal') {
      lit.add(hit.id!);
      if (hit.relay) {
        pos = hit.point + d * 0.5;
        continue;
      }
      return mirrorHits;
    }
    if (hit.kind == 'wall' || hit.kind == 'bounds') return mirrorHits;
    if (hit.kind == 'mirror') {
      mirrorHits++;
      final reflected = reflect(d, hit.normal!);
      pos = hit.point + reflected * 0.5;
      d = reflected.normalized();
      continue;
    }
    return mirrorHits;
  }
  return mirrorHits;
}

class _Hit {
  _Hit({
    required this.point,
    required this.dist,
    required this.kind,
    this.id,
    this.normal,
    this.relay = false,
  });
  final V point;
  final double dist;
  final String kind;
  final String? id;
  final V? normal;
  final bool relay;
}

_Hit? _nearestHit(
  Map<String, dynamic> level,
  V origin,
  V direction,
  Map<String, double> angles,
  double roomW,
  double roomH,
) {
  _Hit? best;
  void consider(_Hit? h) {
    if (h == null || h.dist < 1e-6) return;
    if (best == null || h.dist < best!.dist) best = h;
  }

  consider(_raySeg(origin, direction, const V(0, 0), V(roomW, 0), 'bounds', 'top'));
  consider(_raySeg(origin, direction, V(0, roomH), V(roomW, roomH), 'bounds', 'bottom'));
  consider(_raySeg(origin, direction, const V(0, 0), V(0, roomH), 'bounds', 'left'));
  consider(_raySeg(origin, direction, V(roomW, 0), V(roomW, roomH), 'bounds', 'right'));

  for (final o in (level['obstacles'] as List).cast<Map<String, dynamic>>()) {
    if (o['isDecorative'] == true) continue;
    final poly = (o['polygon'] as List)
        .map((e) => V((e[0] as num).toDouble(), (e[1] as num).toDouble()))
        .toList();
    for (var i = 0; i < poly.length; i++) {
      consider(_raySeg(
        origin,
        direction,
        poly[i],
        poly[(i + 1) % poly.length],
        'wall',
        o['id'] as String,
      ));
    }
  }

  for (final m in (level['mirrors'] as List).cast<Map<String, dynamic>>()) {
    final id = m['id'] as String;
    final ang = angles[id] ?? (m['initialAngle'] as num).toDouble();
    final hinge = V(
      (m['hingePosition'][0] as num).toDouble(),
      (m['hingePosition'][1] as num).toDouble(),
    );
    final len = (m['length'] as num).toDouble();
    final half = dir(ang) * (len / 2);
    final hit = _raySeg(origin, direction, hinge - half, hinge + half, 'mirror', id);
    if (hit != null) {
      var n = normal(ang).normalized();
      if (n.dot(direction) > 0) n = V(-n.x, -n.y);
      consider(_Hit(
        point: hit.point,
        dist: hit.dist,
        kind: 'mirror',
        id: id,
        normal: n,
      ));
    }
  }

  for (final c in (level['targetCrystals'] as List).cast<Map<String, dynamic>>()) {
    final center = V(
      (c['position'][0] as num).toDouble(),
      (c['position'][1] as num).toDouble(),
    );
    final radius = (c['hitRadius'] as num?)?.toDouble() ?? 44;
    consider(_rayCircle(
      origin,
      direction,
      center,
      radius,
      c['id'] as String,
      c['relay'] as bool? ?? false,
    ));
  }
  return best;
}

_Hit? _raySeg(V origin, V direction, V a, V b, String kind, String id) {
  final v1 = origin - a;
  final v2 = b - a;
  final v3 = V(-direction.y, direction.x);
  final den = v2.dot(v3);
  if (den.abs() < 1e-9) return null;
  final t1 = V(-v2.y, v2.x).dot(v1) / den;
  final t2 = v1.dot(v3) / den;
  if (t1 < 1e-6 || t2 < 0 || t2 > 1) return null;
  return _Hit(point: origin + direction * t1, dist: t1, kind: kind, id: id);
}

_Hit? _rayCircle(
  V origin,
  V direction,
  V center,
  double radius,
  String id,
  bool relay,
) {
  final oc = origin - center;
  final a = direction.dot(direction);
  final b = 2 * oc.dot(direction);
  final c = oc.dot(oc) - radius * radius;
  final disc = b * b - 4 * a * c;
  if (disc < 0) return null;
  final s = math.sqrt(disc);
  final t0 = (-b - s) / (2 * a);
  final t1 = (-b + s) / (2 * a);
  final t = t0 > 1e-6 ? t0 : (t1 > 1e-6 ? t1 : -1.0);
  if (t < 0) return null;
  return _Hit(
    point: origin + direction * t,
    dist: t,
    kind: 'crystal',
    id: id,
    relay: relay,
  );
}
