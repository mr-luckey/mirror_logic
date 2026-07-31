import 'package:equatable/equatable.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';

enum BeamHitKind { none, wall, mirror, crystal, bounds }

class BeamSegment extends Equatable {
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

  @override
  List<Object?> get props => [start, end, hitKind, hitId];
}

/// Value equality matters here: this result is a prop of both the gameplay
/// state and the paint snapshot, so identity comparison would repaint the
/// canvas on every emit even when the beam is unchanged.
class BeamSimulationResult extends Equatable {
  const BeamSimulationResult({
    required this.segments,
    required this.litCrystalIds,
    this.mirrorsUsedToCrystal = const {},
  });

  final List<BeamSegment> segments;
  final Set<String> litCrystalIds;

  /// Which mirrors the beam actually bounced off on its way to each lit
  /// crystal. Distinct mirrors, not bounces: a level asks the player to route
  /// the beam through every mirror on the board, so grazing one of them twice
  /// is neither progress nor a mistake. This is what tells a real solution
  /// apart from a beam that skipped a mirror and stumbled onto the crystal.
  final Map<String, Set<String>> mirrorsUsedToCrystal;

  static const empty = BeamSimulationResult(segments: [], litCrystalIds: {});

  @override
  List<Object?> get props => [segments, litCrystalIds, mirrorsUsedToCrystal];
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
