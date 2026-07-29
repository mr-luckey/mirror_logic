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
  });

  final LevelModel level;
  final Map<String, double> mirrorAngles;
  final BeamSimulationResult beam;
  final double powerOnProgress;
  final double chargeProgress;
  final Map<String, double> ghostAngles;
  final String? highlightedMirrorId;
  final String? activeMirrorId;

  factory GameplayPaintSnapshot.fromState(GameplayState state) {
    return GameplayPaintSnapshot(
      level: state.level!,
      mirrorAngles: state.mirrorAngles,
      beam: state.beam,
      powerOnProgress: state.powerOnProgress,
      chargeProgress: state.chargeProgress,
      ghostAngles: state.ghostAngles,
      highlightedMirrorId: state.highlightedMirrorId,
      activeMirrorId: state.activeMirrorId,
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
      ];
}
