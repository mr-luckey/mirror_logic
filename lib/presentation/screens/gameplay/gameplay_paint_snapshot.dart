import 'package:equatable/equatable.dart';
import 'package:mirror_logic/domain/beam/beam_types.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/presentation/blocs/gameplay/gameplay_bloc.dart';

/// Snapshot for canvas repaints — HUD does not rebuild every tick.
class GameplayPaintSnapshot extends Equatable {
  const GameplayPaintSnapshot({
    required this.level,
    required this.mirrorAngles,
    required this.beam,
    required this.powerOnProgress,
    required this.chargeProgress,
    required this.ghostAngles,
    required this.highlightedMirrorId,
    this.activeMirrorId,
    this.alignedTargetId,
    this.rejectedCrystalIds = const {},
    this.showAngleReadout = false,
    this.elapsedSeconds = 0,
  });

  final LevelModel level;
  final Map<String, double> mirrorAngles;
  final BeamSimulationResult beam;
  final double powerOnProgress;
  final double chargeProgress;
  final Map<String, double> ghostAngles;
  final String? highlightedMirrorId;
  final String? activeMirrorId;

  /// Mirror or crystal the beam is currently centred on, mid-drag.
  final String? alignedTargetId;

  /// Crystals the beam reaches by a route the level rejects — drawn red.
  final Set<String> rejectedCrystalIds;

  /// Print the live angle beside the mirror being turned.
  final bool showAngleReadout;
  final double elapsedSeconds;

  factory GameplayPaintSnapshot.fromState(
    GameplayState state, {
    bool showAngleReadout = false,
  }) {
    return GameplayPaintSnapshot(
      showAngleReadout: showAngleReadout,
      level: state.level!,
      mirrorAngles: state.mirrorAngles,
      beam: state.beam,
      powerOnProgress: state.powerOnProgress,
      chargeProgress: state.chargeProgress,
      ghostAngles: state.ghostAngles,
      highlightedMirrorId: state.highlightedMirrorId,
      activeMirrorId: state.activeMirrorId,
      alignedTargetId: state.alignedTargetId,
      rejectedCrystalIds: state.rejectedCrystalIds,
      elapsedSeconds: state.elapsedSeconds,
    );
  }

  @override
  List<Object?> get props => [
    level,
    mirrorAngles,
    beam,
    powerOnProgress,
    chargeProgress,
    ghostAngles,
    highlightedMirrorId,
    activeMirrorId,
    alignedTargetId,
    rejectedCrystalIds,
    showAngleReadout,
    // Quantize time so we don't repaint every microsecond unnecessarily
    // while still driving crystal/laser animations (~20fps visual).
    (elapsedSeconds * 20).floor(),
  ];
}
