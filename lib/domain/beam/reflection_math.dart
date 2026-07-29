import 'dart:math' as math;

import 'package:mirror_logic/domain/beam/vec2.dart';

/// Optical reflection mathematics (PRD §26).
/// Angle of incidence equals angle of reflection.
abstract final class ReflectionMath {
  /// Reflects unit direction [d] about unit normal [n].
  /// Formula: r = d − 2(d·n)n
  static Vec2 reflect(Vec2 d, Vec2 n) {
    final dn = d.dot(n);
    return d - n * (2 * dn);
  }

  /// Degrees to radians.
  static double degToRad(double degrees) => degrees * math.pi / 180;

  /// Radians to degrees.
  static double radToDeg(double radians) => radians * 180 / math.pi;

  /// Unit direction from angle in degrees (0° = +X, 90° = +Y).
  static Vec2 directionFromDegrees(double degrees) {
    final r = degToRad(degrees);
    return Vec2(math.cos(r), math.sin(r));
  }

  /// Angle in degrees of a direction vector.
  static double degreesFromDirection(Vec2 d) {
    return radToDeg(math.atan2(d.y, d.x));
  }

  /// Mirror surface normal from mirror angle (degrees).
  /// Mirror surface runs along the angle; normal is perpendicular.
  static Vec2 mirrorNormal(double mirrorAngleDegrees) {
    return directionFromDegrees(mirrorAngleDegrees + 90).normalized();
  }

  /// Endpoints of a mirror segment given hinge, length, and angle.
  static (Vec2, Vec2) mirrorEndpoints({
    required Vec2 hinge,
    required double length,
    required double angleDegrees,
  }) {
    final dir = directionFromDegrees(angleDegrees);
    final half = dir * (length / 2);
    return (hinge - half, hinge + half);
  }

  /// Clamp angle into [min, max].
  static double clampAngle(double angle, double min, double max) {
    if (angle < min) return min;
    if (angle > max) return max;
    return angle;
  }

  /// Angle from hinge to touch point, in degrees.
  static double angleFromHingeToPoint(Vec2 hinge, Vec2 point) {
    return degreesFromDirection(point - hinge);
  }

  /// Shortest absolute angular distance in degrees.
  static double angularDistance(double a, double b) {
    var d = (a - b).abs() % 360;
    if (d > 180) d = 360 - d;
    return d;
  }
}
