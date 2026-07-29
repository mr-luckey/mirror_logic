import 'dart:math' as math;

/// Immutable 2D vector in world units.
class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  static const zero = Vec2(0, 0);

  double get length => math.sqrt(x * x + y * y);

  double get lengthSquared => x * x + y * y;

  Vec2 normalized() {
    final len = length;
    if (len < 1e-9) return Vec2.zero;
    return Vec2(x / len, y / len);
  }

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 o) => x * o.x + y * o.y;

  /// Perpendicular (rotated 90° CCW).
  Vec2 get perp => Vec2(-y, x);

  double distanceTo(Vec2 o) => (this - o).length;

  @override
  String toString() => 'Vec2($x, $y)';

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
