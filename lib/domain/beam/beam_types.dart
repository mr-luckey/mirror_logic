import 'package:mirror_logic/domain/beam/vec2.dart';

enum BeamHitKind { none, wall, mirror, crystal, bounds }

class BeamSegment {
  const BeamSegment({
    required this.start,
    required this.end,
    this.hitKind = BeamHitKind.none,
    this.hitId,
  });

  final Vec2 start;
  final Vec2 end;
  final BeamHitKind hitKind;
  final String? hitId;

  BeamSegment copyWith({
    Vec2? start,
    Vec2? end,
    BeamHitKind? hitKind,
    String? hitId,
  }) {
    return BeamSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      hitKind: hitKind ?? this.hitKind,
      hitId: hitId ?? this.hitId,
    );
  }
}

class BeamSimulationResult {
  const BeamSimulationResult({
    required this.segments,
    required this.litCrystalIds,
  });

  final List<BeamSegment> segments;
  final Set<String> litCrystalIds;

  static const empty = BeamSimulationResult(
    segments: [],
    litCrystalIds: {},
  );
}

/// Reusable segment list to reduce GC pressure while dragging.
class BeamSegmentPool {
  final List<BeamSegment> _buffer = [];

  List<BeamSegment> acquire() {
    _buffer.clear();
    return _buffer;
  }

  List<BeamSegment> freeze(List<BeamSegment> live) {
    return List<BeamSegment>.unmodifiable(List<BeamSegment>.from(live));
  }
}
