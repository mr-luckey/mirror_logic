import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

/// Cartoon gauntlet-glove hand used to demonstrate a drag on the board.
///
/// It is drawn rather than shipped as an image so it can sit on the board at
/// any size without a second asset to keep in step with the art pack. The
/// pointing fingertip is the anchor: callers place [fingertipOf] on the thing
/// the hand is meant to be touching.
class MedievalHand extends StatelessWidget {
  const MedievalHand({super.key, this.width = 46, this.pressing = false});

  final double width;

  /// Draws the fingertip pressed down, with a contact ring around it.
  final bool pressing;

  static const double _aspect = 1.34;

  /// Where the fingertip lands inside a hand of [width].
  static Offset fingertipOf(double width) =>
      Offset(width * 0.355, width * _aspect * 0.03);

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return SizedBox(
      width: width,
      height: width * _aspect,
      child: CustomPaint(painter: _HandPainter(pressing: pressing)),
    );
  }
}

class _HandPainter extends CustomPainter {
  const _HandPainter({required this.pressing});

  final bool pressing;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    Path box(double l, double t, double r, double b, double radius) =>
        Path()..addRRect(
          RRect.fromLTRBR(l * w, t * h, r * w, b * h, Radius.circular(radius * w)),
        );

    // One glove silhouette: pointing finger, curled knuckles, palm, thumb.
    var glove = Path.combine(
      PathOperation.union,
      box(0.25, 0.02, 0.47, 0.58, 0.11),
      box(0.16, 0.44, 0.88, 0.94, 0.18),
    );
    glove = Path.combine(
      PathOperation.union,
      glove,
      box(0.45, 0.31, 0.86, 0.62, 0.15),
    );
    glove = Path.combine(
      PathOperation.union,
      glove,
      box(0.0, 0.5, 0.3, 0.74, 0.12),
    );

    final fingertip = Offset(w * 0.355, h * 0.03);

    if (pressing) {
      canvas.drawCircle(
        fingertip,
        w * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05
          ..color = MedievalColors.laserGlow.withValues(alpha: 0.75),
      );
      canvas.drawCircle(
        fingertip,
        w * 0.2,
        Paint()
          ..color = MedievalColors.laserCore.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.14),
      );
    }

    canvas.drawPath(
      glove.shift(Offset(0, h * 0.03)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.1),
    );

    canvas.drawPath(
      glove,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF0D6), MedievalColors.parchment, MedievalColors.parchmentDark],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Bronze wrist cuff, kept inside the silhouette so it reads as worn.
    canvas.save();
    canvas.clipPath(glove);
    canvas.drawRect(
      Rect.fromLTRB(0, h * 0.8, w, h),
      Paint()
        ..shader = MedievalColors.bronzeMetal.createShader(
          Rect.fromLTRB(0, h * 0.8, w, h),
        ),
    );
    canvas.restore();

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..color = MedievalColors.parchmentInk;

    canvas.drawPath(glove, ink);

    // Creases: where the curled fingers fold, and the base of the thumb.
    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round
      ..color = MedievalColors.parchmentInk.withValues(alpha: 0.5);
    canvas.save();
    canvas.clipPath(glove);
    canvas.drawLine(
      Offset(w * 0.6, h * 0.34),
      Offset(w * 0.6, h * 0.58),
      crease,
    );
    canvas.drawLine(
      Offset(w * 0.74, h * 0.35),
      Offset(w * 0.74, h * 0.58),
      crease,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.36, h * 0.66), radius: w * 0.2),
      3.4,
      1.6,
      false,
      crease,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandPainter oldDelegate) =>
      oldDelegate.pressing != pressing;
}
