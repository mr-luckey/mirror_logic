import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mobile-first layout helpers for standard phone sizes (~360–430dp wide).
abstract final class Responsive {
  static const double designWidth = 390;
  static const double designHeight = 844;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static double widthOf(BuildContext context) => sizeOf(context).width;

  static double heightOf(BuildContext context) => sizeOf(context).height;

  static EdgeInsets paddingOf(BuildContext context) =>
      MediaQuery.paddingOf(context);

  /// Scale factor clamped so tiny/huge phones don't break layout.
  static double scaleOf(BuildContext context) {
    final w = widthOf(context);
    return (w / designWidth).clamp(0.85, 1.15);
  }

  static double sp(BuildContext context, double size) =>
      size * scaleOf(context);

  static double hp(BuildContext context, double percent) =>
      heightOf(context) * percent;

  static double wp(BuildContext context, double percent) =>
      widthOf(context) * percent;

  static EdgeInsets screenPadding(BuildContext context) {
    final s = scaleOf(context);
    return EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s);
  }

  /// Horizontal inset that never exceeds comfortable phone margins.
  static double pageGutter(BuildContext context) {
    final w = widthOf(context);
    if (w < 340) return 12;
    if (w > 420) return 24;
    return 20;
  }

  static int gridCrossAxisCount(
    BuildContext context, {
    int compact = 4,
    int wide = 5,
  }) {
    return widthOf(context) >= 420 ? wide : compact;
  }

  static double clampFont(double size, {double min = 10, double max = 42}) =>
      size.clamp(min, max);

  static bool isShort(BuildContext context) => heightOf(context) < 700;

  static bool isNarrow(BuildContext context) => widthOf(context) < 360;

  static double menuTileExtent(BuildContext context) {
    final gutter = pageGutter(context);
    final available = widthOf(context) - gutter * 2 - 12 * 3;
    return math.max(64, available / 4);
  }
}
