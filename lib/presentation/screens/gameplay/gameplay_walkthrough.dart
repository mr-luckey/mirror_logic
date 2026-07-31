import 'dart:math' as math;

import 'package:mirror_logic/domain/beam/reflection_math.dart';
import 'package:mirror_logic/domain/beam/vec2.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

/// One mirror of the walkthrough: turned from where it stands to the angle the
/// level's own solution puts it at.
///
/// The finger rides an arc around the post rather than jumping to the answer,
/// because the thing being taught is the gesture, not the angle.
class WalkthroughLesson {
  const WalkthroughLesson({
    required this.mirrorId,
    required this.hinge,
    required this.fromAngle,
    required this.toAngle,
  });

  final String mirrorId;
  final Vec2 hinge;
  final double fromAngle;
  final double toAngle;

  /// Distance from the post the finger is held at.
  ///
  /// Past the radius where the board tracks a drag one-to-one, so the mirror
  /// turns by exactly the arc the hand travels — a damped demonstration would
  /// stop short of the answer.
  static const double grabRadius = 108;

  double get sweepDegrees => toAngle - fromAngle;

  /// Where the fingertip sits when the mirror reads [angle]: out along the arm,
  /// so the hand looks like it is carrying the glass around the post.
  Vec2 pointAt(double angle) =>
      hinge + ReflectionMath.directionFromDegrees(angle) * grabRadius;

  Vec2 get grabPoint => pointAt(fromAngle);

  /// The mirror angle to show at progress [t] through the turn, 0 to 1.
  double angleAt(double t) => fromAngle + sweepDegrees * t;

  /// The arc sampled in small hops, the way a real finger arrives.
  List<Vec2> sweepPoints({double stepDegrees = 1.5}) {
    final steps = math.max(1, (sweepDegrees.abs() / stepDegrees).ceil());
    return [for (var i = 0; i <= steps; i++) pointAt(angleAt(i / steps))];
  }

  /// How long the turn should take on screen. Long enough to be followed, and
  /// paced by the distance so a small correction is not drawn out.
  Duration get turnDuration => Duration(
    milliseconds: (sweepDegrees.abs() * 26).clamp(750, 2000).round(),
  );
}

abstract final class Walkthrough {
  /// The mirrors worth demonstrating on [level], in board order.
  ///
  /// A mirror already sitting at its solved angle is skipped: turning it away
  /// and back would teach the gesture and undo the board at once.
  static List<WalkthroughLesson> lessonsFor({
    required LevelModel level,
    required Map<String, double> angles,
  }) {
    final solution = level.intendedSolution.mirrorAngles;
    final lessons = <WalkthroughLesson>[];

    for (final mirror in level.mirrors) {
      if (mirror.isLocked) continue;
      final target = solution[mirror.id];
      if (target == null) continue;

      final from = ReflectionMath.clampAngle(
        ReflectionMath.normalizeMirrorAngle(
          angles[mirror.id] ?? mirror.initialAngle,
        ),
        mirror.minAngle,
        mirror.maxAngle,
      );
      if ((target - from).abs() < 1) continue;

      lessons.add(
        WalkthroughLesson(
          mirrorId: mirror.id,
          hinge: mirror.hingePosition,
          fromAngle: from,
          toAngle: ReflectionMath.clampAngle(
            target,
            mirror.minAngle,
            mirror.maxAngle,
          ),
        ),
      );
    }

    return lessons;
  }
}
