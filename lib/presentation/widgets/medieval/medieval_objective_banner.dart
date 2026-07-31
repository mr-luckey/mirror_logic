import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';

/// Torn parchment objective banner pinned to the board.
class MedievalObjectiveBanner extends StatelessWidget {
  const MedievalObjectiveBanner({
    super.key,
    this.title = 'OBJECTIVE',
    this.message = 'Activate the Target Crystal',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: const _ParchmentPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 18, 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MedievalColors.laserCore,
                      MedievalColors.laserMid,
                      MedievalColors.crystalDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MedievalColors.laserMid.withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: MedievalTextStyles.cinzel(
                        size: 10,
                        letterSpacing: 1.4,
                        weight: FontWeight.w700,
                        color: MedievalColors.bronzeDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: MedievalTextStyles.imFell(
                        size: 12,
                        height: 1.2,
                        color: MedievalColors.parchmentInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParchmentPainter extends CustomPainter {
  const _ParchmentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _tornRect(size);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFE8D9B8),
          MedievalColors.parchment,
          MedievalColors.parchmentDark,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    final stroke = Paint()
      ..color = MedievalColors.bronzeDark.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, stroke);

    // Pins
    for (final c in [
      const Offset(8, 8),
      Offset(size.width - 10, 9),
      Offset(10, size.height - 10),
      Offset(size.width - 12, size.height - 11),
    ]) {
      canvas.drawCircle(c, 3.2, Paint()..color = MedievalColors.bronzeDark);
      canvas.drawCircle(
        c,
        1.6,
        Paint()..color = MedievalColors.bronzeHighlight,
      );
    }
  }

  Path _tornRect(Size size) {
    final path = Path();
    final rng = math.Random(7);
    path.moveTo(4, 6);
    // Top edge
    for (var x = 4.0; x < size.width - 4; x += 8) {
      path.lineTo(x, 4 + rng.nextDouble() * 3);
    }
    path.lineTo(size.width - 3, 8);
    // Right
    for (var y = 8.0; y < size.height - 6; y += 7) {
      path.lineTo(size.width - 2 - rng.nextDouble() * 4, y);
    }
    path.lineTo(size.width - 5, size.height - 4);
    // Bottom
    for (var x = size.width - 5; x > 4; x -= 8) {
      path.lineTo(x, size.height - 3 - rng.nextDouble() * 3);
    }
    path.lineTo(3, size.height - 6);
    // Left
    for (var y = size.height - 6; y > 6; y -= 7) {
      path.lineTo(2 + rng.nextDouble() * 4, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
