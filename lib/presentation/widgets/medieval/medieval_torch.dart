import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Metal wall torch with a live flame sitting in the cup.
///
/// The flame is drawn, not an image: particle tongues that rise, flicker and
/// die so the home-screen lamps feel lit rather than stickered.
class MedievalTorch extends StatelessWidget {
  const MedievalTorch({
    super.key,
    this.width = 56,
    this.height = 96,
    this.flip = false,
  });

  final double width;
  final double height;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final torch = SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/medieval/torch_base_cut.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => Image.asset(
                'assets/images/medieval/torch_cut.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // The cup sits on the outer end of the arm (right side of the
          // sprite). Anchor the flame there so it reads as rising from the
          // bowl rather than floating in the middle of the bracket.
          Positioned(
            left: width * 0.40,
            right: width * 0.06,
            top: -height * 0.22,
            height: height * 0.52,
            child: const _TorchFlame(),
          ),
        ],
      ),
    );

    if (flip) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: torch,
      );
    }
    return torch;
  }
}

class _TorchFlame extends StatefulWidget {
  const _TorchFlame();

  @override
  State<_TorchFlame> createState() => _TorchFlameState();
}

class _TorchFlameState extends State<_TorchFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tick,
      builder: (_, _) => CustomPaint(
        painter: _FlamePainter(time: _tick.value * math.pi * 2),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.time});

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final baseY = size.height * 0.92;
    final rng = math.Random(7);

    // Soft amber glow under the flame so the bracket reads as lit metal.
    canvas.drawCircle(
      Offset(cx, baseY - size.height * 0.08),
      size.width * 0.55,
      Paint()
        ..color = const Color(0xFFFF8A2A).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Layered tongues: outer orange, mid yellow, core white-hot.
    _tongue(
      canvas,
      cx: cx,
      baseY: baseY,
      height: size.height * 0.88,
      width: size.width * 0.72,
      color: const Color(0xFFE85A10),
      wobble: 0.0,
      time: time,
      alpha: 0.9,
    );
    _tongue(
      canvas,
      cx: cx,
      baseY: baseY,
      height: size.height * 0.72,
      width: size.width * 0.48,
      color: const Color(0xFFFFB020),
      wobble: 1.7,
      time: time,
      alpha: 0.95,
    );
    _tongue(
      canvas,
      cx: cx,
      baseY: baseY,
      height: size.height * 0.48,
      width: size.width * 0.26,
      color: const Color(0xFFFFF4C8),
      wobble: 3.1,
      time: time,
      alpha: 0.85,
    );

    // Rising sparks — the detail that sells "real fire" at a glance.
    for (var i = 0; i < 7; i++) {
      final phase = (time * (0.7 + i * 0.11) + i * 0.9) % (math.pi * 2);
      final life = (math.sin(phase) + 1) * 0.5;
      if (life < 0.15) continue;
      final x = cx +
          math.sin(phase * 2.1 + i) * size.width * 0.22 * (0.4 + life);
      final y = baseY - size.height * (0.15 + life * 0.85);
      final r = 0.8 + rng.nextDouble() * 1.4 * (1 - life);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFEE88),
            const Color(0xFFFF4400),
            life,
          )!
              .withValues(alpha: 0.85 * (1 - life * 0.6)),
      );
    }
  }

  void _tongue(
    Canvas canvas, {
    required double cx,
    required double baseY,
    required double height,
    required double width,
    required Color color,
    required double wobble,
    required double time,
    required double alpha,
  }) {
    final tipSway = math.sin(time * 2.4 + wobble) * width * 0.18;
    final midSway = math.sin(time * 3.1 + wobble + 1.2) * width * 0.12;
    final breath = 1.0 + 0.06 * math.sin(time * 5.2 + wobble);

    final path = Path()
      ..moveTo(cx - width * 0.5 * breath, baseY)
      ..quadraticBezierTo(
        cx - width * 0.55 + midSway,
        baseY - height * 0.45,
        cx + tipSway,
        baseY - height,
      )
      ..quadraticBezierTo(
        cx + width * 0.55 + midSway,
        baseY - height * 0.45,
        cx + width * 0.5 * breath,
        baseY,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) =>
      oldDelegate.time != time;
}
