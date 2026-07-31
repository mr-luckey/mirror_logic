import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';

/// Dark carved-wood backdrop with depth, planks, and corner vines.
class MedievalWoodBackground extends StatelessWidget {
  const MedievalWoodBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Boundaried so a busy board above it never forces the planks,
        // gradients and grain to be rasterised again.
        const RepaintBoundary(
          child: CustomPaint(
            painter: _WoodPlankPainter(),
            child: SizedBox.expand(),
          ),
        ),
        // Top-right vine
        Positioned(
          top: -6,
          right: -4,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.78,
              child: Transform.rotate(
                angle: 0.28,
                child: Image.asset(
                  MedievalArt.vine,
                  width: MediaQuery.sizeOf(context).width * 0.28,
                  height: MediaQuery.sizeOf(context).width * 0.28,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        // Bottom-left vine
        Positioned(
          bottom: 8,
          left: -12,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.7,
              child: Transform.rotate(
                angle: math.pi + 0.15,
                child: Image.asset(
                  MedievalArt.vine,
                  width: MediaQuery.sizeOf(context).width * 0.26,
                  height: MediaQuery.sizeOf(context).width * 0.26,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        // Soft top light so HUD area feels lit
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  MedievalColors.bronzeHighlight.withValues(alpha: 0.07),
                  Colors.transparent,
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

class _WoodPlankPainter extends CustomPainter {
  const _WoodPlankPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4A3426),
            MedievalColors.woodMid,
            MedievalColors.woodDeep,
            const Color(0xFF0C0704),
          ],
          stops: const [0.0, 0.25, 0.7, 1.0],
        ).createShader(Offset.zero & size),
    );

    final plankW = size.width / 8;
    for (var i = 0; i < 9; i++) {
      final x = i * plankW;
      final tone = i.isEven ? MedievalColors.woodPlank : MedievalColors.woodMid;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, plankW, size.height),
        Paint()..color = tone.withValues(alpha: 0.28),
      );

      // Plank bevel highlight
      canvas.drawLine(
        Offset(x + 2, 0),
        Offset(x + 2, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        Offset(x + plankW - 1, 0),
        Offset(x + plankW - 1, size.height),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.4)
          ..strokeWidth = 2.5,
      );

      final grain = Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..strokeWidth = 1;
      for (var g = 0; g < 5; g++) {
        final gx = x + plankW * (0.18 + g * 0.15);
        canvas.drawLine(Offset(gx, 0), Offset(gx + 3, size.height), grain);
      }
    }

    // Outer carved frame shadow around screen edges
    final edge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.45),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.45),
        ],
        stops: const [0.0, 0.08, 0.92, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, edge);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.05),
          radius: 1.2,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
          stops: const [0.5, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
